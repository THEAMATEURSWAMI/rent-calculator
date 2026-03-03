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
  static const bool isPortfolioMode = false;

  static const List<DefaultUser> users = [
    DefaultUser(
      name: 'Roommate A',
      email: 'a@rentcalc.app',
      password: 'password123',
      initials: 'RA',
      colorValue: 0xFF4A90D9, // Blue
    ),
    DefaultUser(
      name: 'Roommate B',
      email: 'b@rentcalc.app',
      password: 'password123',
      initials: 'RB',
      colorValue: 0xFF27AE60, // Green
    ),
    DefaultUser(
      name: 'Roommate C',
      email: 'c@rentcalc.app',
      password: 'password123',
      initials: 'RC',
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
