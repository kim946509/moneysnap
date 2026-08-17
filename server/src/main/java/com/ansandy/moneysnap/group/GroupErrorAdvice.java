package com.ansandy.moneysnap.group;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.CannotCreateTransactionException;
import org.springframework.transaction.TransactionSystemException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

@RestControllerAdvice(assignableTypes = {GroupController.class, ShareController.class, InviteController.class})
class GroupErrorAdvice {

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiErrorResponse invalidRequest() {
        return ApiErrorResponse.of(ApiErrorCode.INVALID_REQUEST);
    }

    @ExceptionHandler(GroupMutationConflictException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    ApiErrorResponse mutationConflict() {
        return ApiErrorResponse.of(ApiErrorCode.MUTATION_CONFLICT);
    }

    @ExceptionHandler(GroupNotAccessibleException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    ApiErrorResponse notAccessible() {
        return ApiErrorResponse.of(ApiErrorCode.NOT_ACCESSIBLE);
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
