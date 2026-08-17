package com.ansandy.moneysnap.media;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.util.Objects;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.core.checksums.RequestChecksumCalculation;
import software.amazon.awssdk.core.checksums.ResponseChecksumValidation;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

final class R2ObjectStore implements ObjectStore {

	private final S3Client s3;
	private final String bucket;

	R2ObjectStore(S3Client s3, String bucket) {
		this.s3 = Objects.requireNonNull(s3);
		if (bucket == null || bucket.isBlank()) {
			throw new IllegalArgumentException("R2 bucket is required");
		}
		this.bucket = bucket;
	}

	static R2ObjectStore connect(String endpoint, String bucket, String accessKey, String secret) {
		S3Client client = S3Client.builder()
				.endpointOverride(URI.create(endpoint))
				.region(Region.of("auto"))
				.credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(accessKey, secret)))
				.serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
				.httpClientBuilder(UrlConnectionHttpClient.builder())
				.requestChecksumCalculation(RequestChecksumCalculation.WHEN_REQUIRED)
				.responseChecksumValidation(ResponseChecksumValidation.WHEN_REQUIRED)
				.build();
		return new R2ObjectStore(client, bucket);
	}

	@Override
	public void put(String key, byte[] bytes) {
		s3.putObject(
				PutObjectRequest.builder()
						.bucket(bucket)
						.key(key)
						.contentType("image/jpeg")
						.contentLength((long) bytes.length)
						.build(),
				RequestBody.fromBytes(bytes));
	}

	@Override
	public byte[] get(String key, int maxBytes) {
		try (InputStream stream = s3.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build())) {
			return readBounded(stream, maxBytes);
		}
		catch (NoSuchKeyException exception) {
			return null;
		}
		catch (S3Exception exception) {
			if (exception.statusCode() == 404) {
				return null;
			}
			throw exception;
		}
		catch (IOException exception) {
			throw new IllegalStateException("Unable to read R2 object", exception);
		}
	}

	@Override
	public void delete(String key) {
		s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
	}

	@Override
	public boolean exists(String key) {
		try {
			s3.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());
			return true;
		}
		catch (NoSuchKeyException exception) {
			return false;
		}
		catch (S3Exception exception) {
			if (exception.statusCode() == 404) {
				return false;
			}
			throw exception;
		}
	}

	private static byte[] readBounded(InputStream stream, int maxBytes) throws IOException {
		ByteArrayOutputStream buffer = new ByteArrayOutputStream();
		byte[] chunk = new byte[8_192];
		int total = 0;
		int read;
		while ((read = stream.read(chunk)) != -1) {
			total += read;
			if (total > maxBytes) {
				throw new IllegalArgumentException("Object exceeds bounded read");
			}
			buffer.write(chunk, 0, read);
		}
		return buffer.toByteArray();
	}
}
