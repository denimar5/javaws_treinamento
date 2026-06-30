package com.example.hello;

import com.aws.class3.sqs.service.SqsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/sqs")
public class SqsController {

    private final SqsService service;

    public SqsController(SqsService service) {
        this.service = service;
    }

    @PostMapping("/send")
    public ResponseEntity<String> send(@RequestParam String message) {
        return ResponseEntity.ok(service.sendMessage(message));
    }

    @GetMapping("/process")
    public ResponseEntity<List<Map<String, String>>> process() {
        return ResponseEntity.ok(service.receiveAndProcess());
    }

    @GetMapping("/peek")
    public ResponseEntity<List<String>> peek() {
        return ResponseEntity.ok(service.peekMessages());
    }
}