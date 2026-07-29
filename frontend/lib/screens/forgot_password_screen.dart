import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/auth_background.dart';
import '../utils/image_paths.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const ForgotPasswordScreen({super.key, required this.onLocaleChanged});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AuthBackground(
      backgroundPath: ImagePaths.loginBackground,
      title: 'Yaounde.Trip · ${l10n.forgotPassword}',
      onLocaleChanged: widget.onLocaleChanged,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_reset, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.forgotPassword,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.forgotPasswordSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_submitted) ...[
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: l10n.usernameOrEmail,
                  prefixIcon: const Icon(Icons.email_outlined),
                  hintText: l10n.enterUsernameOrEmail,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.enterUsername : null,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                child: Text(l10n.resetPassword),
              ),
            ),
          ] else ...[
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.resetLinkSent,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.resetLinkSentMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.resetUINotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
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
    );
  }
}
