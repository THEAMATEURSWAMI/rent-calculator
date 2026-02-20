import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../services/remember_me_service.dart';
import '../../utils/default_users.dart';

class UserLoginScreen extends StatefulWidget {
  final String userName;

  const UserLoginScreen({super.key, required this.userName});

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  // Separate controllers so browser can read both fields for credential saving
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _showResetOption = false;

  late final DefaultUser? _user;

  @override
  void initState() {
    super.initState();
    _user = DefaultUsers.users.cast<DefaultUser?>().firstWhere(
          (u) => u!.name.toLowerCase() == widget.userName.toLowerCase(),
          orElse: () => null,
        );
    // Pre-fill email so browser password managers can read it
    if (_user != null) {
      _emailController.text = _user!.email;
    }
    _loadRememberMeState();
  }

  Future<void> _loadRememberMeState() async {
    final remembered = await RememberMeService.getRememberedUser();
    if (mounted) {
      setState(() {
        // Pre-check "Remember Me" if this user was previously remembered
        _rememberMe = remembered?.toLowerCase() ==
            widget.userName.toLowerCase();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }
    if (_user == null) {
      setState(() => _errorMessage = 'User not found');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showResetOption = false;
    });

    try {
      // Set Firebase Auth persistence BEFORE signing in
      // LOCAL  → session survives browser close (Remember Me ON)
      // SESSION → session ends when tab is closed (Remember Me OFF)
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final firebaseService = context.read<FirebaseService>();
      await firebaseService.signInWithEmail(
        _user!.email,
        _passwordController.text,
      );

      // Save or clear "remember me" preference
      if (_rememberMe) {
        await RememberMeService.setRemembered(_user!.name);
      } else {
        await RememberMeService.clearRemembered();
      }

      // Tell the browser to offer to save these credentials
      TextInput.finishAutofillContext(shouldSave: true);

      if (mounted) {
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      bool showReset = false;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect password. Would you like to reset it?';
          showReset = true;
          break;
        case 'user-not-found':
          message = 'Account not set up yet. Please contact your admin.';
          break;
        case 'too-many-requests':
          message =
              'Too many failed attempts. Please try again later or reset your password.';
          showReset = true;
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'Login failed. Please try again.';
          showReset = true;
      }

      // Tell browser not to save these (wrong) credentials
      TextInput.finishAutofillContext(shouldSave: false);

      setState(() {
        _errorMessage = message;
        _showResetOption = showReset;
        _isLoading = false;
      });
    } catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
      setState(() {
        _errorMessage = 'Incorrect password. Would you like to reset it?';
        _showResetOption = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_user == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _user!.email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _showResetOption = false;
        });
        _showResetSentDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send reset email. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showResetSentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.mark_email_read, size: 48, color: Colors.green[600]),
        title: const Text('Reset Email Sent'),
        content: Text(
          'A password reset link has been sent to:\n\n${_user!.email}\n\nCheck your inbox and follow the instructions.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _passwordController.clear();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('User not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final color = Color(_user!.colorValue);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // AutofillGroup tells the browser this is a credential form
            // — enabling Chrome/Firefox/Safari/Edge to:
            //   • offer to fill saved passwords
            //   • prompt to save new credentials on success
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Switch user'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User avatar
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _user!.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name
                  Text(
                    _user!.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Email — selectable so it can be copied
                  SelectableText(
                    _user!.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // ── Hidden username field ────────────────────────────────
                  // Browsers (Chrome, Safari, Firefox, Edge) need to see a
                  // username/email input BEFORE the password input to:
                  //   • correctly associate saved passwords with this account
                  //   • prompt "Save password?" after successful login
                  // It is hidden visually but fully accessible to the browser.
                  SizedBox(
                    height: 0,
                    child: Opacity(
                      opacity: 0,
                      child: TextFormField(
                        controller: _emailController,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        // Skip this in tab order — it's only for the browser
                        focusNode: FocusNode(skipTraversal: true),
                        enableInteractiveSelection: false,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  // ── Password field ───────────────────────────────────────
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    // Tells browser this is the password for the above email
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    // Allow paste from clipboard / password managers
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) =>
                        AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      // Copy-paste hint in the helper text
                      helperText: 'You can paste your password here',
                      helperStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 8),

                  // ── Remember Me ─────────────────────────────────────────
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (val) =>
                            setState(() => _rememberMe = val ?? false),
                        activeColor: color,
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _rememberMe = !_rememberMe),
                        child: const Text('Remember me on this device'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Password reset (only on wrong password)
                  if (_showResetOption) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _sendPasswordReset,
                      icon: const Icon(Icons.email_outlined),
                      label: Text('Send reset link to ${_user!.email}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        side: BorderSide(color: Colors.orange[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sign in button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Quick-copy credentials tip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your browser\'s password manager can auto-fill or save your password. You can also right-click the password field to paste.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
