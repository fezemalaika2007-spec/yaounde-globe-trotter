import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Eagerly initialise singletons.
  AuthProvider();
  ThemeProvider();
  runApp(const GlobeTrotterApp());
}

class GlobeTrotterApp extends StatefulWidget {
  const GlobeTrotterApp({super.key});

  @override
  State<GlobeTrotterApp> createState() => _GlobeTrotterAppState();
}

class _GlobeTrotterAppState extends State<GlobeTrotterApp> {
  Locale _locale = const Locale('en');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
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

  Future<void> _init() async {
    final locale = await AppLocalizations.getPersistedLocale();
    await ThemeProvider().loadTheme();
    if (mounted) {
      setState(() {
        _locale = locale;
        _ready = true;
      });
    }
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'GlobeTrotter',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeProvider().themeMode,
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
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
    AuthProvider().addListener(_onAuthChange);
  }

  @override
  void dispose() {
    AuthProvider().removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _check() async {
    await AuthProvider().checkAuthStatus();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = AuthProvider();
    if (auth.isLoggedIn) {
      return MainShell(onLocaleChanged: widget.onLocaleChanged);
    }
    return LoginScreen(onLocaleChanged: widget.onLocaleChanged);
  }
}
