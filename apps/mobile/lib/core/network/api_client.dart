import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Dio client, interceptors, API contract types — per mobile-structure.md
/// §1. This is the first mobile feature to call this project's own backend
/// directly (every prior network call was to Supabase Auth); every future
/// feature that talks to `/api/v1/*` should reuse this client, not build its
/// own Dio instance.
///
/// Sprint 56 (docs/11-api/authentication.md §4, docs/12-security/owasp-checklist.md A01) —
/// [clientDeviceId] is sent as `X-Device-Id` on every request once known (`null` only ever
/// happens for the brief window before `main.dart`'s bootstrap resolves it, which no real request
/// is issued during). [onDeviceRevoked] is called whenever the server rejects a request with
/// `401 DEVICE_REVOKED` — a missing/unregistered/revoked device all reject identically server-side
/// (`devices/service.ts`'s own `assertDeviceUsable`), so this client doesn't distinguish them
/// either; the caller's response is the same regardless (force a local sign-out).
Dio buildApiClient({String? clientDeviceId, void Function()? onDeviceRevoked}) {
  final dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (clientDeviceId != null) {
          options.headers['X-Device-Id'] = clientDeviceId;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (isDeviceRevokedError(error)) {
          onDeviceRevoked?.call();
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}

/// Extracted as its own top-level function, not inlined in the interceptor, so it can be tested
/// directly against a constructed `DioException` — no real network call needed, the same
/// no-mocking-a-platform-channel spirit this codebase's testing convention already established
/// elsewhere (Sprint 47's `SecureKeyValueStore`), applied here to a network response shape instead.
bool isDeviceRevokedError(DioException error) {
  final data = error.response?.data;
  if (data is! Map) return false;
  final errorBody = data['error'];
  if (errorBody is! Map) return false;
  return errorBody['code'] == 'DEVICE_REVOKED';
}
