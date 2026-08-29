import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../config/google_auth_config.dart';
import '../services/auth_provider.dart';
import '../services/favorites_provider.dart';
import '../utils/image_paths.dart';
import '../widgets/auth_background.dart';
import '../widgets/google_logo_widget.dart';

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
      await FavoritesProvider().loadFavorites().catchError((e) {
        debugPrint('Error loading favorites after login: $e');
      });
      // Ensure the login route is removed and return to app root so
      // `AuthGate` can rebuild and show `MainShell` when auth state changes.
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = AppLocalizations.of(context).loginFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (!GoogleAuthConfig.isConfigured) {
      setState(() {
        _error =
            'Google Sign-In requires a Google OAuth Client ID. '
            'Please configure your Client ID in lib/config/google_auth_config.dart. '
            'You can log in directly using your username & password!';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn(
        clientId: GoogleAuthConfig.clientId.isNotEmpty
            ? GoogleAuthConfig.clientId
            : null,
        scopes: const ['email', 'profile'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw ApiException(400, 'Could not retrieve authentication token from Google.');
      }
      await AuthProvider().googleLogin(
        idToken: idToken,
        accessToken: accessToken,
      );
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Google sign-in failed: ${e.toString()}');
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
      title: 'Yaounde.Trip · ${l10n.login}',
      onLocaleChanged: widget.onLocaleChanged,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.welcomeBack,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? l10n.enterUsername : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.enterPassword : null,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  : Text(l10n.login),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading ? null : _googleLogin,
            icon: const GoogleLogoWidget(size: 20),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/forgot-password',
                arguments: widget.onLocaleChanged,
              );
            },
            child: Text(l10n.forgotPassword),
          ),
          const SizedBox(height: 4),
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
    );
  }
}
