package com.nestora.common.response;

import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class ApiResponseTest {

    @Test
    void successWithData_setsFieldsCorrectly() {
        ApiResponse<String> response = ApiResponse.success("Operation successful", "payload");
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getMessage()).isEqualTo("Operation successful");
        assertThat(response.getData()).isEqualTo("payload");
    }

    @Test
    void successWithoutData_hasNullData() {
        ApiResponse<Void> response = ApiResponse.success("Action completed");
        assertThat(response.isSuccess()).isTrue();
        assertThat(response.getMessage()).isEqualTo("Action completed");
        assertThat(response.getData()).isNull();
    }

    @Test
    void apiError_hasSuccessFalse() {
        ApiError error = ApiError.of("NOT_FOUND", "Resource not found");
        assertThat(error.isSuccess()).isFalse();
        assertThat(error.getCode()).isEqualTo("NOT_FOUND");
        assertThat(error.getMessage()).isEqualTo("Resource not found");
        assertThat(error.getErrors()).isNull();
    }

    @Test
    void apiError_withFieldErrors_includesErrorsMap() {
        Map<String, String> fieldErrors = Map.of("email", "Invalid email format");
        ApiError error = ApiError.of("VALIDATION_ERROR", "Validation failed", fieldErrors);
        assertThat(error.isSuccess()).isFalse();
        assertThat(error.getCode()).isEqualTo("VALIDATION_ERROR");
        assertThat(error.getMessage()).isEqualTo("Validation failed");
        assertThat(error.getErrors()).containsEntry("email", "Invalid email format");
    }

    @Test
    void pageResponse_mapsPageFieldsCorrectly() {
        List<String> items = List.of("item1", "item2");
        Page<String> page = new PageImpl<>(items, PageRequest.of(0, 10), 25);
        PageResponse<String> response = PageResponse.from(page);

        assertThat(response.getContent()).hasSize(2);
        assertThat(response.getPage()).isZero();
        assertThat(response.getSize()).isEqualTo(10);
        assertThat(response.getTotalElements()).isEqualTo(25);
        assertThat(response.getTotalPages()).isEqualTo(3);
        assertThat(response.isFirst()).isTrue();
        assertThat(response.isLast()).isFalse();
    }
}
