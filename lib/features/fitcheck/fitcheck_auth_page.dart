import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/fitcheck_theme.dart';

class FitCheckAuthPage extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAuthenticated;
  final VoidCallback? onBack;

  const FitCheckAuthPage({
    super.key,
    required this.authService,
    required this.onAuthenticated,
    this.onBack,
  });

  @override
  State<FitCheckAuthPage> createState() => _FitCheckAuthPageState();
}

class _FitCheckAuthPageState extends State<FitCheckAuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        await widget.authService.signUpWithEmailAndPassword(
          email: email,
          password: password,
          displayName: _nameController.text.trim(),
        );
      } else {
        await widget.authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e
            .toString()
            .replaceFirst('AuthException: ', '')
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _continueAsDemo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Explicit demo mode enters the client-side interactive simulation
    // without attempting false authentication credentials.
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitCheckTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onBack != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('auth_back_button'),
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, size: 16, color: FitCheckTheme.textSecondary),
                        label: const Text('Back to Landing', style: TextStyle(color: FitCheckTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Logo & Brand Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        color: FitCheckTheme.primary,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FitCheck',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FitCheckTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'AI Real-Time Interview Simulation & Screening',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FitCheckTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!widget.authService.isConfigured) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FitCheckTheme.warning),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: FitCheckTheme.warning, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Firebase Authentication is not yet configured for web. '
                              'You can test the full experience instantly using Demo Candidate access below.',
                              style: TextStyle(color: FitCheckTheme.warning, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FitCheckTheme.error),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: FitCheckTheme.error, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Fields
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: FitCheckTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: FitCheckTheme.textSecondary),
                        filled: true,
                        fillColor: FitCheckTheme.surface,
                        prefixIcon: const Icon(Icons.person_outline, color: FitCheckTheme.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: FitCheckTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Work / Candidate Email',
                      labelStyle: const TextStyle(color: FitCheckTheme.textSecondary),
                      filled: true,
                      fillColor: FitCheckTheme.surface,
                      prefixIcon: const Icon(Icons.email_outlined, color: FitCheckTheme.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: FitCheckTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: FitCheckTheme.textSecondary),
                      filled: true,
                      fillColor: FitCheckTheme.surface,
                      prefixIcon: const Icon(Icons.lock_outline, color: FitCheckTheme.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Action Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FitCheckTheme.primary,
                        foregroundColor: FitCheckTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.background),
                            )
                          : Text(
                              _isSignUp ? 'Create FitCheck Account' : 'Sign In',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Toggle Sign Up / Sign In
                  TextButton(
                    onPressed: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                    }),
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                      style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Demo Candidate Access
                  Row(
                    children: [
                      const Expanded(child: Divider(color: FitCheckTheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: FitCheckTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                      ),
                      const Expanded(child: Divider(color: FitCheckTheme.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  OutlinedButton.icon(
                    key: const Key('demo_candidate_sign_in_button'),
                    onPressed: _loading ? null : _continueAsDemo,
                    icon: const Icon(Icons.flash_on_rounded, size: 18, color: FitCheckTheme.primary),
                    label: const Text(
                      'Explore as Demo Candidate (Elena Rostova)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: FitCheckTheme.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: FitCheckTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
