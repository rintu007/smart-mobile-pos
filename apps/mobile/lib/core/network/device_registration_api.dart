import 'package:dio/dio.dart';

/// `POST /api/v1/auth/register-device` — docs/11-api/endpoints/identity.md#devices,
/// docs/11-api/authentication.md §2. Idempotent server-side (a second call with the same
/// `client_device_id` updates `last_seen_at` rather than duplicating) — safe to call on every app
/// launch that already has a session, not just once ever per install.
Future<void> registerDevice(Dio dio, String clientDeviceId) {
  return dio.post<void>(
    '/api/v1/auth/register-device',
    data: {'client_device_id': clientDeviceId},
  );
}
