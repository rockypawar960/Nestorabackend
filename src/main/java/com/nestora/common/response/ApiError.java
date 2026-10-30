package com.nestora.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiError {

    @Builder.Default
    private boolean success = false;

    private String code;

    private String message;

    private Map<String, String> errors;

    public static ApiError of(String code, String message) {
        return ApiError.builder()
                .success(false)
                .code(code)
                .message(message)
                .build();
    }

    public static ApiError of(String code, String message, Map<String, String> errors) {
        return ApiError.builder()
                .success(false)
                .code(code)
                .message(message)
                .errors(errors)
                .build();
    }
}
