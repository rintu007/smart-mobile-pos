import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Dio client, interceptors, API contract types — per mobile-structure.md
/// §1. This is the first mobile feature to call this project's own backend
/// directly (every prior network call was to Supabase Auth); every future
/// feature that talks to `/api/v1/*` should reuse this client, not build its
/// own Dio instance.
Dio buildApiClient() {
  final dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
