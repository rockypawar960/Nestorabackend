package com.nestora.common.constants;

public final class AppConstants {

    private AppConstants() {
        // Prevent instantiation
    }

    public static final int MAX_LISTING_IMAGES = 8;
    public static final int OTP_LENGTH = 6;
    public static final int OTP_MAX_ATTEMPTS = 5;
    public static final long MAX_IMAGE_SIZE_BYTES = 5_242_880L; // 5 MB

    public static final String BEARER_PREFIX = "Bearer ";
    public static final String AUTHORIZATION_HEADER = "Authorization";

    public static final String ROLE_PREFIX = "ROLE_";
    public static final String ROLE_ADMIN = "ROLE_ADMIN";
    public static final String ROLE_OWNER = "ROLE_OWNER";
    public static final String ROLE_TENANT = "ROLE_TENANT";

    public static final int DEFAULT_PAGE_SIZE = 10;
    public static final int MAX_PAGE_SIZE = 50;

    public static final String SORT_CREATED_AT_DESC = "createdAt,desc";
    public static final String SORT_RENT_ASC = "rent,asc";
    public static final String SORT_RENT_DESC = "rent,desc";
}
