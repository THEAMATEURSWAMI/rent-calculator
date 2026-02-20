class PlaidAccount {
  final String accountId;
  final String name;
  final String type; // e.g., "depository", "credit", "loan"
  final String? subtype; // e.g., "checking", "savings", "credit card"
  final double? balance;
  final String? mask; // Last 4 digits of account
  final String institutionName;
  final DateTime? lastSynced;

  PlaidAccount({
    required this.accountId,
    required this.name,
    required this.type,
    this.subtype,
    this.balance,
    this.mask,
    required this.institutionName,
    this.lastSynced,
  });

  factory PlaidAccount.fromJson(Map<String, dynamic> json) {
    return PlaidAccount(
      accountId: json['account_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      subtype: json['subtype'],
      balance: json['balances'] != null
          ? (json['balances']['available'] ?? json['balances']['current'])
          : null,
      mask: json['mask'],
      institutionName: json['institution_name'] ?? '',
      lastSynced: json['last_synced'] != null
          ? DateTime.parse(json['last_synced'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'name': name,
      'type': type,
      'subtype': subtype,
      'balance': balance,
      'mask': mask,
      'institution_name': institutionName,
      'last_synced': lastSynced?.toIso8601String(),
    };
  }
}
