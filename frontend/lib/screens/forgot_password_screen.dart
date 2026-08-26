import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/auth_background.dart';
import '../utils/image_paths.dart';

enum ResetStep { request, verify, success }

class ForgotPasswordScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const ForgotPasswordScreen({super.key, required this.onLocaleChanged});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _identifierCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  ResetStep _step = ResetStep.request;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestResetCode() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService().forgotPassword(_identifierCtrl.text.trim());
      if (mounted) {
        setState(() {
          _step = ResetStep.verify;
        });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to send reset code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService().resetPassword(
        identifier: _identifierCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _newPasswordCtrl.text,
      );
      if (mounted) {
        setState(() {
          _step = ResetStep.success;
        });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to reset password. Please check your code.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AuthBackground(
      backgroundPath: ImagePaths.loginBackground,
      title: 'Yaounde.Trip · ${l10n.forgotPassword}',
      onLocaleChanged: widget.onLocaleChanged,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _step == ResetStep.success ? Icons.check_circle_outline : Icons.lock_reset,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _step == ResetStep.success ? 'Password Reset Complete' : l10n.forgotPassword,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _step == ResetStep.request
                  ? l10n.forgotPasswordSubtitle
                  : _step == ResetStep.verify
                      ? 'Enter the 6-digit reset code sent to your email and choose a new password.'
                      : 'Your password has been reset successfully. You can now log in with your new password.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_step == ResetStep.request) ...[
              Form(
                key: _requestFormKey,
                child: TextFormField(
                  controller: _identifierCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.usernameOrEmail,
                    prefixIcon: const Icon(Icons.email_outlined),
                    hintText: l10n.enterUsernameOrEmail,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _requestResetCode(),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.enterUsernameOrEmail : null,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _requestResetCode,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Send Reset Code'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.backToLogin),
              ),
            ] else if (_step == ResetStep.verify) ...[
              Form(
                key: _resetFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '6-Digit Reset Code',
                        prefixIcon: Icon(Icons.pin_outlined),
                        counterText: '',
                      ),
                      validator: (v) =>
                          v == null || v.trim().length != 6 ? 'Enter 6-digit code' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? l10n.enterPassword : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.confirmYourPassword;
                        if (v != _newPasswordCtrl.text) return l10n.passwordsDoNotMatch;
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.resetPassword),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _step = ResetStep.request),
                    child: const Text('Resend Code'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.backToLogin),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.backToLogin),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
