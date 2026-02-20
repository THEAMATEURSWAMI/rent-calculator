import 'package:shared_preferences/shared_preferences.dart';

/// Handles "Remember Me" state across app sessions.
/// Stores the last remembered user name so the login screen
/// can highlight them with a "Welcome back" badge.
class RememberMeService {
  static const _keyRememberedUser = 'remembered_user';
  static const _keyRememberMe    = 'remember_me_enabled';

  /// Save the remembered user after a successful login.
  static Future<void> setRemembered(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRememberedUser, userName);
    await prefs.setBool(_keyRememberMe, true);
  }

  /// Clear remembered state — call on logout or when Remember Me is unchecked.
  static Future<void> clearRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRememberedUser);
    await prefs.setBool(_keyRememberMe, false);
  }

  /// Returns the name of the last remembered user, or null if none.
  static Future<String?> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyRememberMe) ?? false;
    if (!enabled) return null;
    return prefs.getString(_keyRememberedUser);
  }

  /// Whether remember me is currently active.
  static Future<bool> isRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }
}
