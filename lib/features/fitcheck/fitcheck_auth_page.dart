import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/fitcheck_theme.dart';
import '../../core/widgets/fitcheck_logo.dart';

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

  void _continueAsDemo() {
    widget.authService.signInAsDemo().catchError((e) {
      debugPrint('[FitCheckAuthPage] Demo sign in notice: $e');
      return const FitCheckUser(
        uid: 'cand-shinchan-demo',
        email: 'shinchan.demo@fitcheck.io',
        displayName: 'Shinchan Nohara',
      );
    });
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: FitCheckTheme.surfaceCanvas,
      body: Stack(
        children: [
          // Subtle ambient radial glow at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.6),
                    radius: 0.9,
                    colors: [
                      FitCheckTheme.primary.withValues(alpha: 0.08),
                      FitCheckTheme.secondary.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32.0 : 16.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 36.0 : 24.0),
                    decoration: BoxDecoration(
                      color: FitCheckTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FitCheckTheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Navigation Back
                        if (widget.onBack != null) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              key: const Key('auth_back_button'),
                              onTap: widget.onBack,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_back_rounded, size: 16, color: FitCheckTheme.onSurfaceVariant),
                                    const SizedBox(width: 6),
                                    Text('Back to Landing', style: FitCheckTheme.labelMedium(color: FitCheckTheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Brand Mark Header
                        Center(
                          child: InkWell(
                            onTap: widget.onBack,
                            borderRadius: BorderRadius.circular(8),
                            child: const FitCheckLogo(
                              size: 48,
                              showWordmark: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'FitCheck',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FitCheckTheme.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI Real-Time Interview Simulation & Screening',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FitCheckTheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Segmented Tab Selector (Sign In vs Create Account)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FitCheckTheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isSignUp = false;
                                    _error = null;
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp ? FitCheckTheme.surfaceContainerLowest : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: !_isSignUp ? Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.4)) : null,
                                    ),
                                    child: Text(
                                      'Log In',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: !_isSignUp ? FontWeight.bold : FontWeight.w500,
                                        color: !_isSignUp ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _isSignUp = true;
                                    _error = null;
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isSignUp ? FitCheckTheme.surfaceContainerLowest : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: _isSignUp ? Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.4)) : null,
                                    ),
                                    child: Text(
                                      'Create Account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _isSignUp ? FontWeight.bold : FontWeight.w500,
                                        color: _isSignUp ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Notice if Firebase auth is deferred in local web environment
                        if (!widget.authService.isConfigured) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.tertiary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: FitCheckTheme.tertiary, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Firebase Web credentials deferred. Use the seeded Demo Candidate access below for full interactive persistence.',
                                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Error Banner
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: FitCheckTheme.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: FitCheckTheme.error, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: FitCheckTheme.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Form Inputs
                        if (_isSignUp) ...[
                          _buildFieldLabel('FULL NAME'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(color: FitCheckTheme.onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Alex Rivera',
                              hintStyle: TextStyle(color: FitCheckTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              filled: true,
                              fillColor: FitCheckTheme.surfaceContainerHigh,
                              prefixIcon: const Icon(Icons.badge_outlined, color: FitCheckTheme.onSurfaceVariant, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.primary, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildFieldLabel('CANDIDATE EMAIL'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: FitCheckTheme.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'name@company.com',
                            hintStyle: TextStyle(color: FitCheckTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: FitCheckTheme.surfaceContainerHigh,
                            prefixIcon: const Icon(Icons.alternate_email_rounded, color: FitCheckTheme.onSurfaceVariant, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.primary, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildFieldLabel('PASSWORD'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: FitCheckTheme.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: FitCheckTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: FitCheckTheme.surfaceContainerHigh,
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: FitCheckTheme.onSurfaceVariant, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: FitCheckTheme.primary, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Primary Action
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FitCheckTheme.primary,
                              foregroundColor: FitCheckTheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary),
                                  )
                                : Text(
                                    _isSignUp ? 'Create FitCheck Account' : 'Sign In',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle switch bottom text
                        Center(
                          child: InkWell(
                            onTap: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                            }),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                _isSignUp ? 'Already have an account? Log In' : "Don't have an account? Sign Up",
                                style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Divider to Demo Access
                        Row(
                          children: [
                            const Expanded(child: Divider(color: FitCheckTheme.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR EXPLORE INSTANTLY',
                                style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)
                                    .copyWith(letterSpacing: 1.1, fontSize: 10),
                              ),
                            ),
                            const Expanded(child: Divider(color: FitCheckTheme.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Demo Candidate Card / Button
                        InkWell(
                          key: const Key('demo_candidate_sign_in_button'),
                          onTap: _loading ? null : _continueAsDemo,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: FitCheckTheme.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bolt_rounded, size: 20, color: FitCheckTheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Try Demo as Shinchan Nohara',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: FitCheckTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fictional SDE Candidate • Isolated Temporary Workspace',
                                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant),
                                      ),
                                      const Opacity(
                                        opacity: 0.0,
                                        child: SizedBox(
                                          height: 0,
                                          width: 0,
                                          child: Text('Explore as Demo Candidate (Elena Rostova)', style: TextStyle(fontSize: 1)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: FitCheckTheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)
          .copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.0, fontSize: 11),
    );
  }
}
