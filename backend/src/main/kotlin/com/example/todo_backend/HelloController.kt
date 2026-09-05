package com.example.todo_backend

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RequestMapping


data class HelloResponse(val message: String)

@RestController
@RequestMapping("/api")
class HelloController {

    @GetMapping("/hello")
    fun helloWorld() = HelloResponse("Hello, World")

}
