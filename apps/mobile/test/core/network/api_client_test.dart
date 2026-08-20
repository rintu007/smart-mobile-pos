import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';

void main() {
  RequestOptions requestOptions() => RequestOptions(path: '/api/v1/products');

  DioException errorWithBody(dynamic body, {int statusCode = 401}) {
    return DioException(
      requestOptions: requestOptions(),
      response: Response(
        requestOptions: requestOptions(),
        statusCode: statusCode,
        data: body,
      ),
    );
  }

  group('isDeviceRevokedError', () {
    test('true for a real DEVICE_REVOKED error body', () {
      final error = errorWithBody({
        'error': {'code': 'DEVICE_REVOKED', 'message': 'This device has been revoked.'},
      });

      expect(isDeviceRevokedError(error), isTrue);
    });

    test('false for a different error code (e.g. PERMISSION_DENIED)', () {
      final error = errorWithBody({
        'error': {'code': 'PERMISSION_DENIED', 'message': 'Nope.'},
      }, statusCode: 403);

      expect(isDeviceRevokedError(error), isFalse);
    });

    test('false when there is no response at all (e.g. a connection timeout)', () {
      final error = DioException(
        requestOptions: requestOptions(),
        type: DioExceptionType.connectionTimeout,
      );

      expect(isDeviceRevokedError(error), isFalse);
    });

    test('false when the response body is not the expected shape', () {
      expect(isDeviceRevokedError(errorWithBody('not json')), isFalse);
      expect(isDeviceRevokedError(errorWithBody(<String, dynamic>{})), isFalse);
      expect(
        isDeviceRevokedError(errorWithBody({'error': 'not a map'})),
        isFalse,
      );
    });
  });

  group('isUnauthenticatedError', () {
    test('true for a real UNAUTHENTICATED error body', () {
      final error = errorWithBody({
        'error': {'code': 'UNAUTHENTICATED', 'message': 'No valid session token presented.'},
      });

      expect(isUnauthenticatedError(error), isTrue);
    });

    test('false for a different error code, including the other 401 (DEVICE_REVOKED)', () {
      final deviceRevoked = errorWithBody({
        'error': {'code': 'DEVICE_REVOKED', 'message': 'This device has been revoked.'},
      });
      final permissionDenied = errorWithBody({
        'error': {'code': 'PERMISSION_DENIED', 'message': 'Nope.'},
      }, statusCode: 403);

      expect(isUnauthenticatedError(deviceRevoked), isFalse);
      expect(isUnauthenticatedError(permissionDenied), isFalse);
    });

    test('false when there is no response at all (e.g. a connection timeout)', () {
      final error = DioException(
        requestOptions: requestOptions(),
        type: DioExceptionType.connectionTimeout,
      );

      expect(isUnauthenticatedError(error), isFalse);
    });

    test('false when the response body is not the expected shape', () {
      expect(isUnauthenticatedError(errorWithBody('not json')), isFalse);
      expect(isUnauthenticatedError(errorWithBody(<String, dynamic>{})), isFalse);
      expect(
        isUnauthenticatedError(errorWithBody({'error': 'not a map'})),
        isFalse,
      );
    });
  });
}
