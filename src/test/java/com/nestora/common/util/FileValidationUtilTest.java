package com.nestora.common.util;

import com.nestora.exception.BadRequestException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import static org.assertj.core.api.Assertions.assertThatNoException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FileValidationUtilTest {

    private static final long MAX_SIZE = 5 * 1024 * 1024L; // 5 MB

    @Test
    void validJpeg_passesValidation() {
        byte[] jpegMagic = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0,
                0x00, 0x10, 0x4A, 0x46};
        MockMultipartFile file = new MockMultipartFile(
                "image", "photo.jpg", "image/jpeg",
                buildFileBytes(jpegMagic, 1024));

        assertThatNoException().isThrownBy(() -> FileValidationUtil.validateImageFile(file, MAX_SIZE));
    }

    @Test
    void validPng_passesValidation() {
        byte[] pngMagic = {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
        MockMultipartFile file = new MockMultipartFile(
                "image", "photo.png", "image/png",
                buildFileBytes(pngMagic, 1024));

        assertThatNoException().isThrownBy(() -> FileValidationUtil.validateImageFile(file, MAX_SIZE));
    }

    @Test
    void pdfMasqueradingAsJpeg_throwsBadRequestException() {
        byte[] pdfMagic = {0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x00};
        MockMultipartFile file = new MockMultipartFile(
                "image", "fake.jpg", "image/jpeg",
                buildFileBytes(pdfMagic, 1024));

        assertThatThrownBy(() -> FileValidationUtil.validateImageFile(file, MAX_SIZE))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("JPEG");
    }

    @Test
    void fileExceedingMaxSize_throwsBadRequestException() {
        byte[] jpegMagic = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0,
                0x00, 0x10, 0x4A, 0x46};
        long tooLarge = MAX_SIZE + 1;
        MockMultipartFile file = new MockMultipartFile(
                "image", "large.jpg", "image/jpeg",
                buildFileBytes(jpegMagic, (int) tooLarge));

        assertThatThrownBy(() -> FileValidationUtil.validateImageFile(file, MAX_SIZE))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("exceeds maximum allowed size");
    }

    @Test
    void emptyFile_throwsBadRequestException() {
        MockMultipartFile file = new MockMultipartFile(
                "image", "empty.jpg", "image/jpeg", new byte[0]);

        assertThatThrownBy(() -> FileValidationUtil.validateImageFile(file, MAX_SIZE))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("empty");
    }

    private byte[] buildFileBytes(byte[] magic, int targetSize) {
        byte[] data = new byte[Math.max(targetSize, magic.length)];
        System.arraycopy(magic, 0, data, 0, magic.length);
        return data;
    }
}
