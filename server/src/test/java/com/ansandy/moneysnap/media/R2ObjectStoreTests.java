package com.ansandy.moneysnap.media;

import java.io.ByteArrayInputStream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.http.AbortableInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectResponse;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class R2ObjectStoreTests {

	private static final byte[] JPEG = new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};

	@Mock
	private S3Client s3;

	@Test
	void putWritesExactBytesToTheConfiguredBucketAndKey() {
		R2ObjectStore store = new R2ObjectStore(s3, "moneysnap-media-dev");

		store.put("users/a/photo.jpg", JPEG);

		ArgumentCaptor<PutObjectRequest> request = ArgumentCaptor.forClass(PutObjectRequest.class);
		verify(s3).putObject(request.capture(), any(RequestBody.class));
		assertThat(request.getValue().bucket()).isEqualTo("moneysnap-media-dev");
		assertThat(request.getValue().key()).isEqualTo("users/a/photo.jpg");
		assertThat(request.getValue().contentType()).isEqualTo("image/jpeg");
		assertThat(request.getValue().contentLength()).isEqualTo((long) JPEG.length);
	}

	@Test
	void getReturnsNullWhenTheObjectIsMissing() {
		when(s3.getObject(any(GetObjectRequest.class)))
				.thenThrow(NoSuchKeyException.builder().message("missing").build());

		assertThat(new R2ObjectStore(s3, "moneysnap-media-dev").get("users/a/missing.jpg", 100)).isNull();
	}

	@Test
	void getRejectsObjectsLargerThanTheBound() {
		when(s3.getObject(any(GetObjectRequest.class))).thenReturn(stream(new byte[8]));

		assertThatThrownBy(() -> new R2ObjectStore(s3, "moneysnap-media-dev").get("users/a/big.jpg", 4))
				.isInstanceOf(IllegalArgumentException.class)
				.hasMessageContaining("exceeds bounded read");
	}

	@Test
	void existsIsFalseWhenHeadReportsNoSuchKey() {
		when(s3.headObject(any(HeadObjectRequest.class)))
				.thenThrow(NoSuchKeyException.builder().message("missing").build());

		assertThat(new R2ObjectStore(s3, "moneysnap-media-dev").exists("users/a/missing.jpg")).isFalse();
	}

	@Test
	void deleteSendsTheBucketAndKey() {
		new R2ObjectStore(s3, "moneysnap-media-dev").delete("users/a/photo.jpg");

		ArgumentCaptor<DeleteObjectRequest> request = ArgumentCaptor.forClass(DeleteObjectRequest.class);
		verify(s3).deleteObject(request.capture());
		assertThat(request.getValue().bucket()).isEqualTo("moneysnap-media-dev");
		assertThat(request.getValue().key()).isEqualTo("users/a/photo.jpg");
	}

	@Test
	void existsIsTrueWhenHeadSucceeds() {
		when(s3.headObject(any(HeadObjectRequest.class))).thenReturn(HeadObjectResponse.builder().build());

		assertThat(new R2ObjectStore(s3, "moneysnap-media-dev").exists("users/a/photo.jpg")).isTrue();
	}

	@Test
	void getReturnsObjectBytesWithinTheBound() {
		when(s3.getObject(any(GetObjectRequest.class))).thenReturn(stream(JPEG));

		assertThat(new R2ObjectStore(s3, "moneysnap-media-dev").get("users/a/photo.jpg", 16)).isEqualTo(JPEG);
	}

	private static ResponseInputStream<GetObjectResponse> stream(byte[] bytes) {
		return new ResponseInputStream<>(
				GetObjectResponse.builder().contentLength((long) bytes.length).build(),
				AbortableInputStream.create(new ByteArrayInputStream(bytes)));
	}
}
