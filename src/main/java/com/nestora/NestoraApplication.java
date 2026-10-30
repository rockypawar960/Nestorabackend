package com.nestora;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.core.env.Environment;

@Slf4j
@SpringBootApplication
public class NestoraApplication {

    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(NestoraApplication.class);
        Environment env = app.run(args).getEnvironment();
        String activeProfile = env.getActiveProfiles().length > 0 ? String.join(", ", env.getActiveProfiles()) : "default";
        log.info("Nestora backend started successfully — active profile: {}", activeProfile);
    }
}
