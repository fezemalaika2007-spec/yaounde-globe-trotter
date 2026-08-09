import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/image_paths.dart';
import '../widgets/auth_background.dart';

/// Screen shown after registration where the user enters the 6-digit email
/// verification code returned by the backend (for local/dev). On success the
/// user is taken to the login screen.
class VerifyEmailScreen extends StatefulWidget {
  final String username;
  final String initialCode;
  final void Function(Locale) onLocaleChanged;
  const VerifyEmailScreen({
    super.key,
    required this.username,
    required this.initialCode,
    required this.onLocaleChanged,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthProvider().verifyEmail(widget.username, _codeCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verified successfully! Please log in.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacementNamed(
          context,
          '/login',
          arguments: widget.onLocaleChanged,
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to verify email. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final newCode = await ApiService().resendVerificationCodeAndGet(
        identifier: widget.username,
      );
      if (mounted) {
        if (newCode.isNotEmpty) {
          _codeCtrl.text = newCode;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A new code was generated: $newCode'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new 6-digit code has been sent to your email!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthBackground(
      backgroundPath: ImagePaths.registerBackground,
      title: 'Yaounde.Trip · Verify Email',
      onLocaleChanged: widget.onLocaleChanged,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_read,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Verify Your Email',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to your email for ${widget.username}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.trim().length != 6) {
                    return 'Enter the 6-digit code';
                  }
                  return null;
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Verify'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading ? null : _resendCode,
                  child: const Text('Resend Code'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/login',
                      arguments: widget.onLocaleChanged,
                    );
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
