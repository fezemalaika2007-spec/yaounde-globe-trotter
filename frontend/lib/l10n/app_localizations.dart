import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple in-app translation for English and French.
///
/// Call [AppLocalizations.of(context)] to get the localized strings
/// for the current locale.  The locale is persisted via
/// [SharedPreferences] so it survives app restarts.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const _localeKey = 'app_locale';

  /// Persisted locale, or `const Locale('en')` if never set.
  static Future<Locale> getPersistedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == 'fr') return const Locale('fr');
    return const Locale('en');
  }

  /// Persist a new locale choice.
  static Future<void> persistLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _delegates = [AppLocalizationsDelegate()];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      _delegates;

  static const supportedLocales = [Locale('en'), Locale('fr')];

  // ---- Translation keys ---------------------------------------------------

  String get appTitle => _t('GlobeTrotter');

  // Auth
  String get login => _t('Login');
  String get register => _t('Register');
  String get username => _t('Username');
  String get password => _t('Password');
  String get confirmPassword => _t('Confirm password');
  String get welcomeBack => _t('Welcome back!');
  String get createAccount => _t('Create your account');
  String get enterUsername => _t('Enter username');
  String get enterPassword => _t('Enter password');
  String get confirmYourPassword => _t('Confirm your password');
  String get passwordsDoNotMatch => _t('Passwords do not match');
  String get selectInterests => _t('Select your interests:');
  String get selectAtLeastOneTag =>
      _t('Please select at least one interest tag');
  String get alreadyHaveAccount => _t('Already have an account? Login');
  String get noAccount => _t("Don't have an account? Register");
  String get loginFailed => _t('Connection failed. Is the server running?');
  String get invalidCredentials => _t('Invalid credentials');

  // Navigation
  String get destinations => _t('Destinations');
  String get recommendations => _t('Recommendations');
  String get itineraries => _t('Itineraries');
  String get logout => _t('Logout');

  // Destinations
  String get search => _t('Search');
  String get tagFilter => _t('Tag filter');
  String get maxCost => _t('Max cost');
  String get noDestinations => _t('No destinations found');
  String get avgCostPerDay => _t('Avg. cost / day');

  // Recommendations
  String get refresh => _t('Refresh');
  String get noRecommendations => _t('No recommendations available');
  String get matchScore => _t('Match score');

  // Itineraries
  String get createItinerary => _t('Create Itinerary');
  String get title => _t('Title');
  String get destinationsList => _t('Destinations (comma separated)');
  String get startDate => _t('Start date');
  String get endDate => _t('End date');
  String get notes => _t('Notes');
  String get cancel => _t('Cancel');
  String get save => _t('Save');
  String get noItineraries => _t('No itineraries yet');
  String get enterTitle => _t('Enter a title');
  String get enterDestinations => _t('Enter at least one destination');

  // Settings
  String get appearance => _t('Appearance');
  String get language => _t('Language');
  String get darkMode => _t('Dark mode');
  String get lightMode => _t('Light mode');
  String get english => _t('English');
  String get french => _t('French');

  // ---- Lookup helper -----------------------------------------------------

  String _t(String key) {
    if (locale.languageCode == 'fr') {
      return _frenchTranslations[key] ?? key;
    }
    return _englishTranslations[key] ?? key;
  }

  static const _englishTranslations = <String, String>{};

  static const _frenchTranslations = <String, String>{
    // Auth
    'GlobeTrotter': 'GlobeTrotter',
    'Login': 'Connexion',
    'Register': "S'inscrire",
    'Username': "Nom d'utilisateur",
    'Password': 'Mot de passe',
    'Confirm password': 'Confirmer le mot de passe',
    'Welcome back!': 'Bon retour !',
    'Create your account': 'Créez votre compte',
    'Enter username': "Entrez votre nom d'utilisateur",
    'Enter password': 'Entrez votre mot de passe',
    'Confirm your password': 'Confirmez votre mot de passe',
    'Passwords do not match': 'Les mots de passe ne correspondent pas',
    'Select your interests:': 'Sélectionnez vos centres d\'intérêt :',
    'Please select at least one interest tag':
        'Veuillez sélectionner au moins un centre d\'intérêt',
    'Already have an account? Login': 'Déjà un compte ? Connectez-vous',
    "Don't have an account? Register": 'Pas de compte ? Inscrivez-vous',
    'Connection failed. Is the server running?':
        'Échec de connexion. Le serveur est-il en cours d\'exécution ?',
    'Invalid credentials': 'Identifiants invalides',

    // Navigation
    'Destinations': 'Destinations',
    'Recommendations': 'Recommandations',
    'Itineraries': 'Itinéraires',
    'Logout': 'Déconnexion',

    // Destinations
    'Search': 'Rechercher',
    'Tag filter': 'Filtre par tag',
    'Max cost': 'Coût max',
    'No destinations found': 'Aucune destination trouvée',
    'Avg. cost / day': 'Coût moyen / jour',

    // Recommendations
    'Refresh': 'Actualiser',
    'No recommendations available': 'Aucune recommandation disponible',
    'Match score': 'Score de correspondance',

    // Itineraries
    'Create Itinerary': 'Créer un itinéraire',
    'Title': 'Titre',
    'Destinations (comma separated)':
        'Destinations (séparées par des virgules)',
    'Start date': 'Date de début',
    'End date': 'Date de fin',
    'Notes': 'Notes',
    'Cancel': 'Annuler',
    'Save': 'Enregistrer',
    'No itineraries yet': 'Aucun itinéraire pour le moment',
    'Enter a title': 'Entrez un titre',
    'Enter at least one destination': 'Entrez au moins une destination',

    // Settings
    'Appearance': 'Apparence',
    'Language': 'Langue',
    'Dark mode': 'Mode sombre',
    'Light mode': 'Mode clair',
    'English': 'Anglais',
    'French': 'Français',
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'fr';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
