// BillingApiService — future auto-fetch integration layer.
//
// PLANNED INTEGRATIONS
// ────────────────────
// • Utility provider APIs (e.g. SureBill, Urjanet, UtilityAPI)
//   – Auto-import electricity, water, gas, trash amounts each month
// • Payment processor webhooks (e.g. Stripe, Zelle callbacks)
//   – Mark splits as paid automatically when detected
// • Plaid Transactions (already wired) cross-referenced with utility merchants
//   – Auto-match Chase/BofA transactions to open utility splits
//
// HOW TO ACTIVATE
// ───────────────
// 1. Sign up for a utility data provider (UtilityAPI.com is a good start)
// 2. Set your API key: firebase functions:config:set billing.api_key="..."
// 3. Deploy the Cloud Function that calls the provider and writes to
//    utility_bills/{year}/{month}  (same structure this app already reads)
// 4. Flip [isEnabled] to true once the backend is live

class BillingApiService {
  // Toggle once backend integration is deployed
  static const bool isEnabled = false;

  // Backend endpoint — set once Cloud Functions are deployed
  // ignore: unused_field
  static const String _baseUrl =
      'https://us-central1-rent-calculator-bedd3.cloudfunctions.net';

  // ── Fetch this month's bills from provider ────────────────────────────────

  /// Returns a list of raw bill maps ready to import as [UtilityBill]s.
  /// Each map matches the shape expected by [UtilityBill.fromFirestore].
  ///
  /// Throws if [isEnabled] is false — call site should guard with that flag.
  Future<List<Map<String, dynamic>>> fetchBillsForMonth({
    required int month,
    required int year,
  }) async {
    if (!isEnabled) {
      throw UnsupportedError(
          'BillingApiService is not yet enabled. '
          'Deploy the Cloud Functions backend and set isEnabled = true.');
    }

    // TODO: implement once backend is live
    // final uri = Uri.parse('$_baseUrl/fetchBills')
    //     .replace(queryParameters: {'month': '$month', 'year': '$year'});
    // final response = await http.get(uri).timeout(const Duration(seconds: 20));
    // if (response.statusCode == 200) {
    //   return List<Map<String, dynamic>>.from(jsonDecode(response.body)['bills']);
    // }
    // throw Exception('fetchBills failed: ${response.body}');

    return [];
  }

  // ── Provider account linking ──────────────────────────────────────────────

  /// Opens the provider OAuth flow to link a utility account.
  /// Returns the linked account ID, or null if the user cancelled.
  Future<String?> linkProviderAccount({
    required String userId,
    required String providerSlug, // e.g. 'pge', 'austin-water', 'spectrum'
  }) async {
    if (!isEnabled) return null;

    // TODO: launch provider link URL and handle OAuth callback
    // final linkUrl = '$_baseUrl/billingProviderLink?provider=$providerSlug&userId=$userId';
    // ... open in browser, await callback ...

    return null;
  }

  // ── Linked accounts ───────────────────────────────────────────────────────

  /// Returns slugs of providers already linked for [userId].
  Future<List<String>> getLinkedProviders(String userId) async {
    if (!isEnabled) return [];

    // TODO: GET $baseUrl/billingProviders?userId=$userId
    return [];
  }
}
