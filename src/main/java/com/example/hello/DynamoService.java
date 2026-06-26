package com.example.hello;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

import java.util.HashMap;
import java.util.Map;


import software.amazon.awssdk.services.dynamodb.model.GetItemResponse;

@Service
public class DynamoService {

    private final DynamoDbClient dynamoDbClient;
    private static final String TABLE_NAME = "assurance-dynamo";

    public DynamoService(DynamoDbClient dynamoDbClient) {
        this.dynamoDbClient = dynamoDbClient;
    }

    public String save(String id, String nome) {
        Map<String, AttributeValue> item = new HashMap<>();
        item.put("id", AttributeValue.builder().n(id).build());
        item.put("nome", AttributeValue.builder().s(nome).build());

        PutItemRequest request = PutItemRequest.builder()
                .tableName(TABLE_NAME)
                .item(item)
                .build();

        dynamoDbClient.putItem(request);
        return "Item salvo com sucesso";
    }

    public Map<String, String> find(String id) {
        Map<String, AttributeValue> key = new HashMap<>();
        key.put("id", AttributeValue.builder().n(id).build());

        GetItemRequest request = GetItemRequest.builder()
                .tableName(TABLE_NAME)
                .key(key)
                .build();

        GetItemResponse response = dynamoDbClient.getItem(request);

        // item inexistente -> retorna vazio (controller pode tratar como 404)
        if (!response.hasItem() || response.item().isEmpty()) {
            return Map.of();
        }

        Map<String, AttributeValue> item = response.item();

        // Converte AttributeValue -> String tratando cada tipo (N, S, bool)
        Map<String, String> result = new HashMap<>();
        item.forEach((k, v) -> result.put(k, attributeToString(v)));
        return result;
    }

    public String delete(String id) {
        Map<String, AttributeValue> key = new HashMap<>();
        key.put("id", AttributeValue.builder().n(id).build());

        DeleteItemRequest request = DeleteItemRequest.builder()
                .tableName(TABLE_NAME)
                .key(key)
                .build();

        dynamoDbClient.deleteItem(request);
        return "Item removido com sucesso";
    }

    // helper: extrai o valor textual seja qual for o tipo do atributo
    private String attributeToString(AttributeValue v) {
        if (v.s() != null) return v.s();           // String
        if (v.n() != null) return v.n();           // Number  <- resolve o id null
        if (v.bool() != null) return v.bool().toString();
        return "";
    }
}