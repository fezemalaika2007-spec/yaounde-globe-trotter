import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/auth_provider.dart';
import 'services/favorites_provider.dart';
import 'services/theme_provider.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_shell.dart';
import 'screens/analytics_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthProvider();
  ThemeProvider();
  await AnalyticsService().initialize();
  runApp(const YaoundeTripApp());
}

class YaoundeTripApp extends StatefulWidget {
  const YaoundeTripApp({super.key});

  @override
  State<YaoundeTripApp> createState() => _YaoundeTripAppState();
}

class _YaoundeTripAppState extends State<YaoundeTripApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: load the persisted locale/theme in the background.
    // The app renders immediately with defaults; when storage responds the
    // values are applied via setState without ever blocking the first frame.
    _loadPersistedSettings();
    ThemeProvider().addListener(_onThemeChange);
  }

  @override
  void dispose() {
    ThemeProvider().removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPersistedSettings() async {
    try {
      final prefs = await AppLocalizations.getPersistedLocale().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => const Locale('en'),
      );
      if (mounted && _locale != prefs) {
        setState(() => _locale = prefs);
      }
      await ThemeProvider().loadTheme().timeout(
        const Duration(milliseconds: 1500),
      );
    } catch (e) {
      debugPrint('Error loading persisted settings: $e');
    }
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    AnalyticsService().logChangeLanguage(languageCode: locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final observer = AnalyticsService().observer;

    return MaterialApp(
      title: 'Yaounde.Trip',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeProvider().themeMode,
      navigatorObservers: [
        ?observer,
      ],
      onGenerateRoute: (settings) {
        final args = settings.arguments as void Function(Locale)?;
        final localeCallback = args ?? _setLocale;
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(
              builder: (_) => LoginScreen(onLocaleChanged: localeCallback),
            );
          case '/register':
            return MaterialPageRoute(
              builder: (_) => RegisterScreen(onLocaleChanged: localeCallback),
            );
          case '/forgot-password':
            return MaterialPageRoute(
              builder: (_) =>
                  ForgotPasswordScreen(onLocaleChanged: localeCallback),
            );
          case '/analytics':
            return MaterialPageRoute(
              builder: (_) => const AnalyticsDashboardScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => _AppContents(onLocaleChanged: _setLocale),
            );
        }
      },
      home: _AppContents(onLocaleChanged: _setLocale),
    );
  }
}

/// Internal widget that handles locale propagation to children.
class _AppContents extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const _AppContents({required this.onLocaleChanged});

  @override
  State<_AppContents> createState() => _AppContentsState();
}

class _AppContentsState extends State<_AppContents> {
  @override
  void initState() {
    super.initState();
    AuthProvider().addListener(_onAuthChange);
  }

  @override
  void dispose() {
    AuthProvider().removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AuthGate(onLocaleChanged: widget.onLocaleChanged);
  }
}

/// Watches authentication state and shows the appropriate screen.
class AuthGate extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const AuthGate({super.key, required this.onLocaleChanged});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    AuthProvider().addListener(_onAuthChange);
    _resolveAuthStatus();
  }

  @override
  void dispose() {
    AuthProvider().removeListener(_onAuthChange);
    super.dispose();
  }

  Future<void> _resolveAuthStatus() async {
    try {
      await AuthProvider().checkAuthStatus().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      if (AuthProvider().isLoggedIn) {
        await FavoritesProvider().loadFavorites().catchError((e) {
          debugPrint('Error loading favorites after auth check: $e');
        });
      }
    } catch (e) {
      debugPrint('Error during auth check: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingAuth = false;
        });
      }
    }
  }

  void _onAuthChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = AuthProvider();
    if (auth.isLoggedIn) {
      return MainShell(onLocaleChanged: widget.onLocaleChanged);
    }
    return LoginScreen(onLocaleChanged: widget.onLocaleChanged);
  }
}
