import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const LoginScreen({super.key, required this.onLocaleChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthProvider().login(_usernameCtrl.text.trim(), _passwordCtrl.text);
      // AuthGate (in main.dart) listens to AuthProvider and will
      // automatically switch to MainShell when isLoggedIn becomes true.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = AppLocalizations.of(context).loginFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('GlobeTrotter — ${l10n.login}'),
        actions: [_SettingsButton(onLocaleChanged: widget.onLocaleChanged)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight_takeoff, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  l10n.welcomeBack,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.enterUsername : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.enterPassword : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.login),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/register',
                      arguments: widget.onLocaleChanged,
                    );
                  },
                  child: Text(l10n.noAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable settings button shown in the AppBar.
class _SettingsButton extends StatelessWidget {
  final void Function(Locale) onLocaleChanged;
  const _SettingsButton({required this.onLocaleChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeProvider();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings),
      onSelected: (value) async {
        if (value == 'en') {
          await AppLocalizations.persistLocale(const Locale('en'));
          onLocaleChanged(const Locale('en'));
        } else if (value == 'fr') {
          await AppLocalizations.persistLocale(const Locale('fr'));
          onLocaleChanged(const Locale('fr'));
        } else if (value == 'toggle_theme') {
          await theme.toggleTheme();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle_theme',
          child: Row(
            children: [
              Icon(theme.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              const SizedBox(width: 8),
              Text(theme.isDarkMode ? l10n.lightMode : l10n.darkMode),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: 8),
              Text(l10n.english),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'fr',
          child: Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: 8),
              Text(l10n.french),
            ],
          ),
        ),
      ],
    );
  }
}
