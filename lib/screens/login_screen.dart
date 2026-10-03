import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import 'auth_gate.dart';

// Login / register screen (Juan Felipe Ochoa)
// The Figma prototype has no login view, so it reuses the app's own components:
// cream background, Poppins headline, rounded white fields with orange focus, and the orange primary button
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isRegister = false; // false = "Log in", true = "Create account"
  bool _loading = false; // true while waiting for the backend (disables the button)
  bool _hidePassword = true;
  String? _error; // message shown under the form

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Checks the fields on the phone first, so obvious mistakes don't need a trip to the server
  String? _validate() {
    final email = _email.text.trim().toLowerCase();
    if (_isRegister && _name.text.trim().isEmpty) return 'Write your name';
    if (!email.endsWith('@uniandes.edu.co') || email.startsWith('@')) {
      return 'Use your institutional email (@uniandes.edu.co)';
    }
    if (_password.text.length < 8) return 'The password must have at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _isRegister
          ? await AuthService.register(
              name: _name.text.trim(), email: _email.text.trim(), password: _password.text)
          : await AuthService.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      AuthGate.enterApp(context, user, isNewUser: _isRegister);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Text(
              'UNIVERSIDAD DE LOS ANDES',
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text('Campus Eats', style: AppTextStyles.headline.copyWith(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              _isRegister ? 'Create your account to start' : 'Log in to continue',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 32),

            if (_isRegister) ...[
              _AuthField(controller: _name, hint: 'Your name', icon: Icons.person_outline),
              const SizedBox(height: 12),
            ],
            _AuthField(
              controller: _email,
              hint: 'name@uniandes.edu.co',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _AuthField(
              controller: _password,
              hint: 'Password (min. 8 characters)',
              icon: Icons.lock_outline,
              obscure: _hidePassword,
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18, color: AppColors.muted),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 24),

            _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : AppPrimaryButton(label: _isRegister ? 'Create account' : 'Log in', onTap: _submit),
            const SizedBox(height: 16),

            // Switches between "Log in" and "Create account"
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _isRegister = !_isRegister;
                          _error = null;
                        }),
                child: Text(
                  _isRegister ? 'I already have an account' : 'Create an account',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Rounded white field with an icon, same look as the app's text fields (orange border when focused)
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: AppTextStyles.body.copyWith(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.mutedLight, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.accent),
      ),
    );
  }
}
