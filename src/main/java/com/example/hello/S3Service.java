package com.example.hello;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

@Service
public class S3Service {

    private final S3Client s3Client;

    private static final String BUCKET =
            "assurance-bucket-840986438181-us-east-2-an";

    public S3Service(S3Client s3Client) {
        this.s3Client = s3Client;
    }

    // Upload de arquivo. prefix opcional, ex: "Aula-Java/"
    public void upload(MultipartFile file, String prefix) throws IOException {

        String key = (prefix == null || prefix.isBlank())
                ? file.getOriginalFilename()
                : normalizePrefix(prefix) + file.getOriginalFilename();

        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(BUCKET)
                .key(key)
                .contentType(file.getContentType())
                .build();

        s3Client.putObject(
                request,
                software.amazon.awssdk.core.sync.RequestBody
                        .fromBytes(file.getBytes())
        );
    }

    // Lista arquivos e "pastas" (common prefixes) num dado nível.
    // prefix vazio = raiz do bucket
    public ListResult list(String prefix) {

        String normalized = (prefix == null || prefix.isBlank())
                ? ""
                : normalizePrefix(prefix);

        ListObjectsV2Request request = ListObjectsV2Request.builder()
                .bucket(BUCKET)
                .prefix(normalized)
                .delimiter("/")   // faz o S3 agrupar "pastas"
                .build();

        ListObjectsV2Response response = s3Client.listObjectsV2(request);

        // Pastas (subprefixos)
        List<String> folders = response.commonPrefixes()
                .stream()
                .map(CommonPrefix::prefix)
                .toList();

        // Arquivos (ignora a própria pasta listada como objeto vazio)
        List<String> files = new ArrayList<>();
        for (S3Object obj : response.contents()) {
            if (!obj.key().equals(normalized)) {
                files.add(obj.key());
            }
        }

        return new ListResult(folders, files);
    }

    // Obtém os bytes do arquivo
    public ResponseInputStream<GetObjectResponse> getFile(String key) {
        GetObjectRequest request = GetObjectRequest.builder()
                .bucket(BUCKET)
                .key(key)
                .build();

        return s3Client.getObject(request);
    }

    // Obtém metadados do arquivo (tamanho, content-type, etc.) sem baixar
    public HeadObjectResponse getMetadata(String key) {
        HeadObjectRequest request = HeadObjectRequest.builder()
                .bucket(BUCKET)
                .key(key)
                .build();

        return s3Client.headObject(request);
    }

    private String normalizePrefix(String prefix) {
        return prefix.endsWith("/") ? prefix : prefix + "/";
    }

    public record ListResult(List<String> folders, List<String> files) {}
}