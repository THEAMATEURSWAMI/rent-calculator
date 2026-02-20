import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/plaid_account.dart';

/// Thin client that talks to the Firebase Cloud Functions backend.
///
/// Default [baseUrl] points to the Firebase project's Cloud Functions;
/// override it if you deploy somewhere else.
class PlaidService {
  final String baseUrl;

  /// Your Firebase project's Cloud Functions base URL.
  /// Replace with your actual project URL after deploying functions.
  static const String _defaultBaseUrl =
      'https://us-central1-rent-calculator-bedd3.cloudfunctions.net';

  const PlaidService({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'Backend error ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
        'Backend error ${response.statusCode}: ${response.body}');
  }

  // ── API ────────────────────────────────────────────────────────────────────

  /// Creates a Plaid link_token for the given user.
  Future<String> createLinkToken(String userId) async {
    final data = await _post('/createLinkToken', {'userId': userId});
    final token = data['link_token'] as String?;
    if (token == null) throw Exception('No link_token in response');
    return token;
  }

  /// Exchanges a Plaid public_token for account data.
  /// Returns institution info + accounts list.
  Future<Map<String, dynamic>> exchangePublicToken({
    required String publicToken,
    required String userId,
  }) async {
    return _post('/exchangePublicToken', {
      'publicToken': publicToken,
      'userId': userId,
    });
  }

  /// Fetches the current account balances from the backend.
  Future<List<PlaidAccount>> getAccounts(String userId) async {
    final data = await _get('/getAccounts', {'userId': userId});
    final raw = data['accounts'] as List? ?? [];
    return raw.map((a) => PlaidAccount.fromJson(a as Map<String, dynamic>)).toList();
  }

  /// Syncs the latest transactions to Firestore expenses.
  Future<void> syncTransactions(String userId) async {
    await _post('/syncTransactions', {'userId': userId});
  }

  /// Disconnects the bank account (removes stored token on backend).
  Future<void> disconnect(String userId) async {
    await _post('/disconnect', {'userId': userId});
  }

  /// Health check — returns true if the backend is reachable.
  Future<bool> ping() async {
    try {
      final uri = Uri.parse('$baseUrl/ping');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
