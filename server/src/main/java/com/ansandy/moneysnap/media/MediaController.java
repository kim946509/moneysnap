package com.ansandy.moneysnap.media;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ansandy.moneysnap.shared.AuthenticatedUser;

import tools.jackson.databind.JsonNode;

@RestController
@RequestMapping("/api/v1/media")
class MediaController {

    private final MediaVault vault;

    MediaController(MediaVault vault) {
        this.vault = vault;
    }

    @PostMapping("/intents")
    MediaIntent createIntent(Authentication authentication, @Valid @RequestBody IntentRequest request) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return vault.createIntent(
                actor.userId(),
                request.requireByteSize(),
                request.requireContentType(),
                request.requireChecksum());
    }

    @PutMapping("/{mediaId}/upload")
    ResponseEntity<Void> upload(
            Authentication authentication,
            @PathVariable UUID mediaId,
            @RequestBody byte[] body) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        vault.upload(actor.userId(), mediaId, body);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{mediaId}/abort")
    ResponseEntity<Void> abort(Authentication authentication, @PathVariable UUID mediaId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        vault.abort(actor.userId(), mediaId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{mediaId}/complete")
    MediaRef complete(Authentication authentication, @PathVariable UUID mediaId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        return vault.complete(actor.userId(), mediaId);
    }

    @GetMapping(path = "/{mediaId}", produces = MediaType.IMAGE_JPEG_VALUE)
    ResponseEntity<byte[]> read(Authentication authentication, @PathVariable UUID mediaId) {
        AuthenticatedUser actor = (AuthenticatedUser) authentication.getPrincipal();
        MediaReadGrant grant = vault.read(actor.userId(), mediaId);
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .body(grant.bytes());
    }

    private record IntentRequest(
            @NotNull JsonNode byteSize,
            @NotNull JsonNode contentType,
            @NotNull JsonNode checksumSha256) {

        @JsonAnySetter
        void rejectUnknownProperty(String name, Object value) {
            throw new IllegalArgumentException("Unknown media property");
        }

        int requireByteSize() {
            if (!byteSize.isIntegralNumber() || !byteSize.canConvertToInt()) {
                throw new IllegalArgumentException("byteSize must be an integer");
            }
            return byteSize.intValue();
        }

        String requireContentType() {
            if (!contentType.isString()) {
                throw new IllegalArgumentException("contentType must be a string");
            }
            return contentType.stringValue();
        }

        String requireChecksum() {
            if (!checksumSha256.isString()) {
                throw new IllegalArgumentException("checksumSha256 must be a string");
            }
            return checksumSha256.stringValue();
        }
    }
}
