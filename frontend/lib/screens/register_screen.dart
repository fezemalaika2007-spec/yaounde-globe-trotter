import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';

/// All possible preference tags the backend understands.
const _allTags = [
  'beach',
  'food',
  'culture',
  'nature',
  'adventure',
  'history',
  'romantic',
  'wellness',
  'photography',
  'outdoors',
  'city',
];

class RegisterScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const RegisterScreen({super.key, required this.onLocaleChanged});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _selectedTags = <String>[];
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTags.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).selectAtLeastOneTag;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthProvider().register(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
        List.from(_selectedTags),
      );
      // AuthGate listens to AuthProvider and auto-switches to MainShell
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
        title: Text('GlobeTrotter — ${l10n.register}'),
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
                const Icon(Icons.person_add, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  l10n.createAccount,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l10n.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.confirmYourPassword;
                    if (v != _passwordCtrl.text) {
                      return l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.selectInterests,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _allTags.map((tag) {
                    final selected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                          _error = null;
                        });
                      },
                    );
                  }).toList(),
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
                        : Text(l10n.register),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/login',
                      arguments: widget.onLocaleChanged,
                    );
                  },
                  child: Text(l10n.alreadyHaveAccount),
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
      itemBuilder: (ctx) => [
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
