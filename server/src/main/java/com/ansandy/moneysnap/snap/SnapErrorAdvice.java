package com.ansandy.moneysnap.snap;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.CannotCreateTransactionException;
import org.springframework.transaction.TransactionSystemException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

@RestControllerAdvice(assignableTypes = SnapRecordController.class)
class SnapErrorAdvice {

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiErrorResponse invalidRequest() {
        return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
    }

    @ExceptionHandler(SnapMutationConflictException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    ApiErrorResponse mutationConflict() {
        return ApiErrorResponse.of(ApiErrorCode.MUTATION_CONFLICT);
    }

    @ExceptionHandler({
            DataAccessException.class,
            CannotCreateTransactionException.class,
            TransactionSystemException.class
    })
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    ApiErrorResponse internalError() {
        return ApiErrorResponse.of(ApiErrorCode.INTERNAL_ERROR);
    }
}
