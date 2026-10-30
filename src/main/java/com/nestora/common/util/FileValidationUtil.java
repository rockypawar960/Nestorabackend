package com.nestora.common.util;

import com.nestora.exception.BadRequestException;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.io.IOUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;

@Slf4j
public final class FileValidationUtil {

    private static final byte[] JPEG_MAGIC = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = new byte[]{
            (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    };

    private FileValidationUtil() {
        // Prevent instantiation
    }

    public static void validateImageFile(MultipartFile file, long maxSizeBytes) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Image file must not be empty");
        }

        if (file.getSize() > maxSizeBytes) {
            throw new BadRequestException(String.format(
                    "File exceeds maximum allowed size of %d bytes", maxSizeBytes));
        }

        byte[] headerBytes = new byte[8];
        int bytesRead;
        try (InputStream is = file.getInputStream()) {
            bytesRead = IOUtils.read(is, headerBytes, 0, 8);
        } catch (Exception ex) {
            throw new BadRequestException("Failed to inspect file content", ex);
        }

        if (bytesRead < 3) {
            throw new BadRequestException("Invalid or truncated image file");
        }

        boolean isJpeg = headerBytes[0] == JPEG_MAGIC[0]
                && headerBytes[1] == JPEG_MAGIC[1]
                && headerBytes[2] == JPEG_MAGIC[2];

        boolean isPng = bytesRead >= 8
                && headerBytes[0] == PNG_MAGIC[0]
                && headerBytes[1] == PNG_MAGIC[1]
                && headerBytes[2] == PNG_MAGIC[2]
                && headerBytes[3] == PNG_MAGIC[3]
                && headerBytes[4] == PNG_MAGIC[4]
                && headerBytes[5] == PNG_MAGIC[5]
                && headerBytes[6] == PNG_MAGIC[6]
                && headerBytes[7] == PNG_MAGIC[7];

        if (!isJpeg && !isPng) {
            throw new BadRequestException("Only JPEG and PNG images are allowed");
        }
    }
}
