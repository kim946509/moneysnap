package com.ansandy.moneysnap.identity;

import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
class ApiErrorAdvice {

	@ExceptionHandler({MethodArgumentNotValidException.class, HttpMessageNotReadableException.class})
	@ResponseStatus(HttpStatus.BAD_REQUEST)
	ApiErrorResponse invalidRequest() {
		return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
	}
}
