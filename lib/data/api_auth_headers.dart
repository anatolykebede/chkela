import '../features/auth/auth_session_store.dart';

/// Headers for social API calls that require a user session JWT.
Future<Map<String, String>> apiAuthHeaders({
  bool json = true,
}) async {
  final headers = <String, String>{};
  if (json) headers['Content-Type'] = 'application/json';
  final token = await AuthSessionStore.loadSessionToken();
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}
