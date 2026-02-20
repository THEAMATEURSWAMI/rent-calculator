class DefaultUser {
  final String name;
  final String email;
  final String password;
  final String initials;
  final int colorValue;

  const DefaultUser({
    required this.name,
    required this.email,
    required this.password,
    required this.initials,
    required this.colorValue,
  });
}

class DefaultUsers {
  static const List<DefaultUser> users = [
    DefaultUser(
      name: 'Jacob',
      email: 'jacob@rentcalc.app',
      password: '46464061',
      initials: 'JA',
      colorValue: 0xFF4A90D9, // Blue
    ),
    DefaultUser(
      name: 'Nico',
      email: 'nico@rentcalc.app',
      password: '46464061',
      initials: 'NI',
      colorValue: 0xFF27AE60, // Green
    ),
    DefaultUser(
      name: 'Eddy',
      email: 'eddy@rentcalc.app',
      password: '46464061',
      initials: 'ED',
      colorValue: 0xFFE67E22, // Orange
    ),
  ];

  static DefaultUser? findByEmail(String email) {
    try {
      return users.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }
}
