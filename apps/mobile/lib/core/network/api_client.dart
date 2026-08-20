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
///
/// Sprint 57 (docs/13-offline-sync/failure-scenarios.md's last unverified scenario, "Token expired
/// while queued") — a `401 UNAUTHENTICATED` response (this codebase's own server never distinguishes
/// "expired" from any other invalid-token case, per `core/auth/session.ts`; there is no separate
/// `TOKEN_EXPIRED` code to check for) triggers exactly one `refreshSession()` call, then a single
/// retry of the same request — invisible to the Cashier if the refresh succeeds, surfaced only if
/// the refresh itself also fails (a genuinely expired refresh token, not just an expired access
/// token). `_retriedAfterRefreshKey` guards against retrying more than once per request, so a
/// refresh that "succeeds" but is immediately followed by another 401 doesn't loop forever.
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
      onError: (error, handler) async {
        if (isDeviceRevokedError(error)) {
          onDeviceRevoked?.call();
          handler.next(error);
          return;
        }

        final alreadyRetried = error.requestOptions.extra[_retriedAfterRefreshKey] == true;
        if (isUnauthenticatedError(error) && !alreadyRetried) {
          try {
            await Supabase.instance.client.auth.refreshSession();
            final retryOptions = error.requestOptions
              ..extra[_retriedAfterRefreshKey] = true;
            handler.resolve(await dio.fetch(retryOptions));
            return;
          } catch (_) {
            // Refresh itself failed (e.g. the refresh token has also expired) — fall through and
            // surface the original error, per error-catalogue.md's "only surfaced to the user if
            // refresh itself also fails" rule.
          }
        }

        handler.next(error);
      },
    ),
  );

  return dio;
}

const _retriedAfterRefreshKey = 'smartpos_retried_after_refresh';

/// Extracted as its own top-level function, not inlined in the interceptor, so it can be tested
/// directly against a constructed `DioException` — no real network call needed, the same
/// no-mocking-a-platform-channel spirit this codebase's testing convention already established
/// elsewhere (Sprint 47's `SecureKeyValueStore`), applied here to a network response shape instead.
bool isDeviceRevokedError(DioException error) => _errorCode(error) == 'DEVICE_REVOKED';

/// Same extraction, same reasoning, for the `UNAUTHENTICATED` retry-after-refresh path above.
bool isUnauthenticatedError(DioException error) => _errorCode(error) == 'UNAUTHENTICATED';

String? _errorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map) return null;
  final errorBody = data['error'];
  if (errorBody is! Map) return null;
  return errorBody['code'] as String?;
}
