package com.example.hello;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class SqsService {

    private final SqsClient sqsClient;

    private static final String QUEUE_URL =
            "https://sqs.sa-east-1.amazonaws.com/447197207642/AWS-SQS-CLASS";

    public SqsService(SqsClient sqsClient) {
        this.sqsClient = sqsClient;
    }

    public String sendMessage(String message) {

        SendMessageRequest request = SendMessageRequest.builder()
                .queueUrl(QUEUE_URL)
                .messageBody(message)
                .build();

        SendMessageResponse response = sqsClient.sendMessage(request);

        return "Mensagem enviada com sucesso. ID: " + response.messageId();
    }

    public List<Map<String, String>> receiveAndProcess() {

        ReceiveMessageRequest request = ReceiveMessageRequest.builder()
                .queueUrl(QUEUE_URL)
                .maxNumberOfMessages(10)
                .waitTimeSeconds(2)
                .visibilityTimeout(30) // 30s para processar antes de a msg reaparecer
                .build();

        List<Message> messages = sqsClient.receiveMessage(request).messages();

        List<Map<String, String>> processed = new ArrayList<>();

        for (Message message : messages) {
            try {
                processMessage(message);
                deleteMessage(message.receiptHandle());

                processed.add(Map.of(
                        "messageId", message.messageId(),
                        "body", message.body(),
                        "status", "PROCESSADA E REMOVIDA"
                ));

            } catch (Exception e) {
                processed.add(Map.of(
                        "messageId", message.messageId(),
                        "body", message.body(),
                        "status", "FALHA - SERÁ REPROCESSADA",
                        "erro", e.getMessage()
                ));
            }
        }

        return processed;
    }

    public List<String> peekMessages() {

        ReceiveMessageRequest request = ReceiveMessageRequest.builder()
                .queueUrl(QUEUE_URL)
                .maxNumberOfMessages(10)
                .waitTimeSeconds(2)
                .build();

        return sqsClient.receiveMessage(request).messages()
                .stream()
                .map(Message::body)
                .toList();
    }

    private void processMessage(Message message) {
        System.out.println("Processando mensagem: " + message.body());
    }

    private void deleteMessage(String receiptHandle) {
        DeleteMessageRequest request = DeleteMessageRequest.builder()
                .queueUrl(QUEUE_URL)
                .receiptHandle(receiptHandle)
                .build();

        sqsClient.deleteMessage(request);
    }
}