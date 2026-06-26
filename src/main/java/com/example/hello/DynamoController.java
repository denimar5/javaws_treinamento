package com.example.hello;


import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/dynamodb")
public class DynamoController {

    private final DynamoService service;

    public DynamoController(DynamoService service) {
        this.service = service;
    }

    @PostMapping("/save")
    public ResponseEntity<String> save(
            @RequestParam String id,
            @RequestParam String nome
    ) {
        return ResponseEntity.ok(service.save(id, nome));
    }

    @GetMapping("/find/{id}")
    public ResponseEntity<Map<String, String>> find(@PathVariable String id) {
        return ResponseEntity.ok(service.find(id));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<String> delete(
            @PathVariable String id
    ) {
        return ResponseEntity.ok(service.delete(id));
    }
}