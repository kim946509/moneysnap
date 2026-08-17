package com.ansandy.moneysnap.media;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

@RestControllerAdvice(assignableTypes = MediaController.class)
class MediaErrorAdvice {

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiErrorResponse invalidRequest() {
        return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
    }

    @ExceptionHandler(MediaNotAccessibleException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    ApiErrorResponse notAccessible() {
        return ApiErrorResponse.of(ApiErrorCode.NOT_ACCESSIBLE);
    }

    @ExceptionHandler(MediaQuotaException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiErrorResponse quota() {
        return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
    }
}
