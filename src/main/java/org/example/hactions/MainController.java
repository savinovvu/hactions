package org.example.hactions;


import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class MainController {

    @GetMapping("/")
    public String hello() {
        return "hello bla bla new world";
    }
}
