import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/locale_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String asRole;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.asRole,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _codeVerified = false;
  bool _showPassword = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  Future<void> _verifyCode() async {
    final l10n = AppLocalizations.of(context);
    if (_code.length != 6) {
      setState(() => _error = l10n.enter6DigitCode);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final valid = await api.verifyResetCode(email: widget.email, code: _code);

      if (!mounted) return;

      if (valid) {
        setState(() {
          _codeVerified = true;
          _loading = false;
          _success = l10n.codeVerified;
        });
      } else {
        setState(() {
          _error = l10n.invalidOrExpiredCode;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('Trop de tentatives')
            ? l10n.tooManyAttempts
            : l10n.verificationError;
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty) {
      setState(() => _error = l10n.enterNewPassword);
      return;
    }

    if (password.length < 8) {
      setState(() => _error = l10n.passwordMinLength);
      return;
    }

    if (password != confirm) {
      setState(() => _error = l10n.passwordsNotMatch);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final result = await api.resetPassword(
        email: widget.email,
        code: _code,
        newPassword: password,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Show success message and go to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(l10n.passwordChangedSuccess),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/auth/login?as=${widget.asRole}');
      } else {
        setState(() {
          _error = result['message'] ?? l10n.passwordChangeError;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.passwordChangeError;
        _loading = false;
      });
    }
  }

  Future<void> _resendCode() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiProvider);
      await api.forgotPassword(email: widget.email);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _success = '${l10n.newCodeSent} ${widget.email}';
      });

      // Clear the code fields
      for (var c in _codeControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.sendCodeError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeProvider) == AppThemeMode.dark;
    final coral = const Color(0xFFF36C6C);
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _codeVerified ? l10n.newPassword : l10n.verify,
          style: TextStyle(color: textColor),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            if (!_codeVerified) ...[
              // Step 1: Enter verification code
              Text(
                l10n.enterVerificationCode,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: subtextColor, fontSize: 15),
                  children: [
                    TextSpan(text: '${l10n.codeSentTo} '),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 6-digit code input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _codeControllers[i],
                      focusNode: _focusNodes[i],
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: coral, width: 2),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (v.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        // Auto-verify when all 6 digits entered
                        if (_code.length == 6) {
                          _verifyCode();
                        }
                      },
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Resend code link
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _resendCode,
                  child: Text(
                    l10n.resendCode,
                    style: TextStyle(color: coral, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              // Step 2: Enter new password
              Text(
                l10n.createNewPassword,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.newPasswordDesc,
                style: TextStyle(color: subtextColor, fontSize: 15),
              ),
              const SizedBox(height: 32),

              // New password field
              Text(
                l10n.newPassword,
                style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: l10n.minCharacters,
                  hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.lock_outline, color: subtextColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: subtextColor,
                    ),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: coral, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm password field
              Text(
                l10n.confirmNewPassword,
                style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                obscureText: !_showPassword,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: l10n.repeatPassword,
                  hintStyle: TextStyle(color: subtextColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.lock_outline, color: subtextColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subtextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: coral, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                ),
                onSubmitted: (_) => _resetPassword(),
              ),
            ],

            const SizedBox(height: 16),

            // Success message
            if (_success != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _success!,
                        style: const TextStyle(color: Colors.green, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: _loading
                    ? null
                    : _codeVerified
                        ? _resetPassword
                        : _verifyCode,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_codeVerified ? l10n.changePassword : l10n.verify),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
