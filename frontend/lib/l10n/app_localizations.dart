import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static const supportedLocales = [Locale('en'), Locale('fr')];

  // App
  String get appName => _t('Yaounde.Trip');

  // Auth
  String get login => _t('Login');
  String get register => _t('Register');
  String get welcomeBack => _t('Welcome back!');
  String get createAccount => _t('Create your account');
  String get username => _t('Username');
  String get password => _t('Password');
  String get confirmPassword => _t('Confirm password');
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
  String get forgotPassword => _t('Forgot Password');
  String get forgotPasswordSubtitle => _t(
    "Enter your username or email address and we'll send you a reset link.",
  );
  String get usernameOrEmail => _t('Username or Email');
  String get enterUsernameOrEmail => _t('Enter your username or email');
  String get resetPassword => _t('Reset Password');
  String get resetLinkSent => _t('Reset link sent');
  String get resetLinkSentMessage => _t(
    'If an account exists with that email, you will receive a password reset link shortly.',
  );
  String get resetUINotice => _t(
    'This is a UI-only flow. The backend reset endpoint is not connected.',
  );
  String get backToLogin => _t('Back to Login');
  String get orContinueAsGuest => _t('Or continue as guest');
  String get registrationSuccess =>
      _t('Registration successful! Please log in.');

  // Navigation
  String get home => _t('Home');
  String get destinations => _t('Destinations');
  String get recommendations => _t('Recommendations');
  String get itineraries => _t('Itineraries');
  String get favorites => _t('Favorites');
  String get logout => _t('Logout');
  String get profile => _t('Profile');

  // Home
  String get welcomeToYaounde => _t('Welcome to Yaoundé');
  String get exploreSubtitle => _t(
    'Discover the best places to visit, eat, and explore in Cameroon\'s vibrant capital.',
  );
  String get featuredDestinations => _t('Featured Destinations');
  String get startExploring => _t('Start Exploring');
  String get viewAll => _t('View All');
  String get homeIntroText => _t(
    'Yaounde.Trip is your smart travel companion for exploring Cameroon\'s vibrant capital. Discover the best destinations, get personalized recommendations based on your interests, plan and manage your itineraries, and save your favorite spots — all in one place.',
  );
  String get homeWhatYouCanDo => _t('What you can do');
  String get homeGlimpseYaounde => _t('A glimpse of Yaoundé');
  String get homeFeatureDiscoverTitle => _t('Discover Destinations');
  String get homeFeatureDiscoverDesc => _t(
    'Browse Yaoundé\'s top attractions — from Mont Fébé to Mefou National Park — with photos, ratings, costs, and tags.',
  );
  String get homeFeatureRecommendTitle =>
      _t('Get Personalized Recommendations');
  String get homeFeatureRecommendDesc => _t(
    'Let our smart matching engine suggest destinations based on your interests and preferences.',
  );
  String get homeFeaturePlanTitle => _t('Plan & Manage Itineraries');
  String get homeFeaturePlanDesc => _t(
    'Create custom trip itineraries, add destinations, set dates, and keep all your travel plans in one place.',
  );
  String get homeFeatureSaveTitle => _t('Save Favorite Locations');
  String get homeFeatureSaveDesc => _t(
    'Tap the heart icon on any destination to bookmark it and build your personal travel list for easy access later.',
  );

  // Destinations
  String get search => _t('Search');
  String get tagFilter => _t('Tag filter');
  String get maxCost => _t('Max cost');
  String get noDestinations => _t('No destinations found');
  String get avgCostPerDay => _t('Avg. cost / day');
  String get filterByTag => _t('Filter by tag');
  String get allTags => _t('All');
  String get viewDetails => _t('View Details');
  String get perDay => _t('/day');

  // Recommendations
  String get refresh => _t('Refresh');
  String get noRecommendations => _t('No recommendations available');
  String get matchScore => _t('Match score');
  String get personalizedForYou => _t('Personalized for you');
  String get recommendationsComingSoon => _t('Coming Soon');
  String get recommendationsPlaceholder => _t(
    'Your personalized recommendations will appear here soon. They will be based on your searches, favorites, and popular destinations that match your taste.',
  );

  // Itineraries
  String get createItinerary => _t('Create Itinerary');
  String get title => _t('Title');
  String get destinationsList => _t('Destinations (comma separated)');
  String get startDate => _t('Start date');
  String get endDate => _t('End date');
  String get notes => _t('Notes');
  String get cancel => _t('Cancel');
  String get save => _t('Save');
  String get required => _t('Required');
  String get noItineraries => _t('No itineraries yet');
  String get enterTitle => _t('Enter a title');
  String get enterDestinations => _t('Enter at least one destination');
  String get newItinerary => _t('New Itinerary');
  String get create => _t('Create');

  // Settings
  String get settings => _t('Settings');
  String get appearance => _t('Appearance');
  String get language => _t('Language');
  String get darkMode => _t('Dark mode');
  String get lightMode => _t('Light mode');
  String get english => _t('English');
  String get french => _t('French');
  String get loggedInAs => _t('Logged in as');

  // Additional strings
  String get yourItineraries => _t('Your itineraries');
  String get createFirstItinerary =>
      _t("Create your first itinerary to start planning your trip.");

  // Empty states
  String get nothingHere => _t('Nothing here yet');
  String get tryAgain => _t('Try again');
  String get noFavorites => _t('No favorites yet');
  String get noFavoritesMessage =>
      _t('Tap the heart icon on any destination to save it here.');

  String get failedToLoad => _t('Failed to load data');

  // Footer
  String get footerTagline =>
      _t('Your smart travel companion for exploring Yaoundé and beyond.');
  String get footerQuickLinks => _t('Quick Links');
  String get footerContact => _t('Contact');
  String get footerAddress => _t('Yaoundé, Centre Region, Cameroon');
  String get footerAbout => _t('About');
  String get footerAboutText => _t(
    'Yaounde.Trip is a smart travel planner that helps you discover the best destinations, create itineraries, and get personalized recommendations for Yaoundé, Cameroon.',
  );
  String get footerCopyright => _t('© 2026 Yaounde.Trip. All rights reserved.');
  String get footerPrivacy => _t('Privacy Policy');
  String get footerTerms => _t('Terms of Service');
  String get footerCookies => _t('Cookie Policy');
  String get footerMadeWith => _t('Made with');
  String get footerInCameroon => _t('in Cameroon');

  // ---- Lookup helper -----------------------------------------------------

  String _t(String key) {
    if (locale.languageCode == 'fr') {
      return _frenchTranslations[key] ?? key;
    }
    return _englishTranslations[key] ?? key;
  }

  static const _englishTranslations = <String, String>{};

  static const _frenchTranslations = <String, String>{
    // App
    'Yaounde.Trip': 'Yaounde.Trip',

    // Auth
    'Login': 'Connexion',
    'Register': "S'inscrire",
    'Welcome back!': 'Bon retour !',
    'Create your account': 'Créez votre compte',
    'Username': "Nom d'utilisateur",
    'Password': 'Mot de passe',
    'Confirm password': 'Confirmer le mot de passe',
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
    'Forgot Password': 'Mot de passe oublié',
    "Enter your username or email address and we'll send you a reset link.":
        'Entrez votre nom d\'utilisateur ou votre email et nous vous enverrons un lien de réinitialisation.',
    'Username or Email': "Nom d'utilisateur ou Email",
    'Enter your username or email': 'Entrez votre nom d\'utilisateur ou email',
    'Reset Password': 'Réinitialiser le mot de passe',
    'Reset link sent': 'Lien de réinitialisation envoyé',
    'If an account exists with that email, you will receive a password reset link shortly.':
        'Si un compte existe avec cet email, vous recevrez un lien de réinitialisation sous peu.',
    'This is a UI-only flow. The backend reset endpoint is not connected.':
        'Ceci est un flux UI uniquement. Le point de terminaison de réinitialisation du backend n\'est pas connecté.',
    'Back to Login': 'Retour à la connexion',
    'Or continue as guest': 'Ou continuer en tant qu\'invité',
    'Registration successful! Please log in.':
        'Inscription réussie ! Veuillez vous connecter.',

    // Navigation
    'Home': 'Accueil',
    'Destinations': 'Destinations',
    'Recommendations': 'Recommandations',
    'Itineraries': 'Itinéraires',
    'Favorites': 'Favoris',
    'Logout': 'Déconnexion',
    'Profile': 'Profil',

    // Home
    'Welcome to Yaoundé': 'Bienvenue à Yaoundé',
    'Discover the best places to visit, eat, and explore in Cameroon\'s vibrant capital.':
        'Découvrez les meilleurs endroits à visiter, manger et explorer dans la vibrante capitale du Cameroun.',
    'Featured Destinations': 'Destinations en vedette',
    'Start Exploring': 'Commencer à explorer',
    'View All': 'Voir tout',
    'Yaounde.Trip is your smart travel companion for exploring Cameroon\'s vibrant capital. Discover the best destinations, get personalized recommendations based on your interests, plan and manage your itineraries, and save your favorite spots — all in one place.':
        'Yaounde.Trip est votre compagnon de voyage intelligent pour explorer la vibrante capitale du Cameroun. Découvrez les meilleures destinations, obtenez des recommandations personnalisées selon vos centres d\'intérêt, planifiez et gérez vos itinéraires, et enregistrez vos lieux préférés — tout en un seul endroit.',
    'What you can do': 'Ce que vous pouvez faire',
    'A glimpse of Yaoundé': 'Un aperçu de Yaoundé',
    'Discover Destinations': 'Découvrir les destinations',
    'Browse Yaoundé\'s top attractions — from Mont Fébé to Mefou National Park — with photos, ratings, costs, and tags.':
        'Parcourez les meilleures attractions de Yaoundé — du Mont Fébé au Parc National de la Mefou — avec photos, notes, coûts et tags.',
    'Get Personalized Recommendations':
        'Obtenir des recommandations personnalisées',
    'Let our smart matching engine suggest destinations based on your interests and preferences.':
        'Laissez notre moteur de recommandation intelligent vous suggérer des destinations selon vos centres d\'intérêt et vos préférences.',
    'Plan & Manage Itineraries': 'Planifier & gérer des itinéraires',
    'Create custom trip itineraries, add destinations, set dates, and keep all your travel plans in one place.':
        'Créez des itinéraires de voyage sur mesure, ajoutez des destinations, définissez des dates et conservez tous vos projets au même endroit.',
    'Save Favorite Locations': 'Enregistrer vos lieux préférés',
    'Tap the heart icon on any destination to bookmark it and build your personal travel list for easy access later.':
        'Appuyez sur l\'icône cœur d\'une destination pour la mettre en favori et constituer votre liste de voyage personnelle.',

    // Destinations
    'Search': 'Rechercher',
    'Tag filter': 'Filtre par tag',
    'Max cost': 'Coût max',
    'No destinations found': 'Aucune destination trouvée',
    'Avg. cost / day': 'Coût moyen / jour',
    'Filter by tag': 'Filtrer par tag',
    'All': 'Tous',
    'View Details': 'Voir les détails',
    '/day': '/jour',

    // Recommendations
    'Refresh': 'Actualiser',
    'No recommendations available': 'Aucune recommandation disponible',
    'Match score': 'Score de correspondance',
    'Personalized for you': 'Personnalisé pour vous',
    'Coming Soon': 'Bientôt disponible',
    'Your personalized recommendations will appear here soon. They will be based on your searches, favorites, and popular destinations that match your taste.':
        'Vos recommandations personnalisées apparaîtront bientôt ici. Elles seront basées sur vos recherches, vos favoris et les destinations populaires qui correspondent à vos goûts.',

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
    'Required': 'Requis',
    'No itineraries yet': 'Aucun itinéraire pour le moment',
    'Enter a title': 'Entrez un titre',
    'Enter at least one destination': 'Entrez au moins une destination',
    'New Itinerary': 'Nouvel itinéraire',
    'Create': 'Créer',

    // Settings
    'Settings': 'Paramètres',
    'Appearance': 'Apparence',
    'Language': 'Langue',
    'Dark mode': 'Mode sombre',
    'Light mode': 'Mode clair',
    'English': 'Anglais',
    'French': 'Français',
    'Logged in as': 'Connecté en tant que',

    // Empty states
    'Nothing here yet': 'Rien ici pour le moment',
    'Try again': 'Réessayer',
    'No favorites yet': 'Pas de favoris pour le moment',
    'Tap the heart icon on any destination to save it here.':
        'Touchez l\'icône cœur sur n\'importe quelle destination pour l\'enregistrer ici.',

    // Error
    'An unexpected error occurred': 'Une erreur inattendue s\'est produite',
    'Failed to load data': 'Échec du chargement des données',

    // Footer
    'Your smart travel companion for exploring Yaoundé and beyond.':
        'Votre compagnon de voyage intelligent pour explorer Yaoundé et au-delà.',
    'Quick Links': 'Liens rapides',
    'Contact': 'Contact',
    'Yaoundé, Centre Region, Cameroon': 'Yaoundé, Région du Centre, Cameroun',
    'About': 'À propos',
    'Yaounde.Trip is a smart travel planner that helps you discover the best destinations, create itineraries, and get personalized recommendations for Yaoundé, Cameroon.':
        'Yaounde.Trip est un planificateur de voyage intelligent qui vous aide à découvrir les meilleures destinations, créer des itinéraires et obtenir des recommandations personnalisées pour Yaoundé, Cameroun.',
    '© 2026 Yaounde.Trip. All rights reserved.':
        '© 2026 Yaounde.Trip. Tous droits réservés.',
    'Privacy Policy': 'Politique de confidentialité',
    'Terms of Service': "Conditions d'utilisation",
    'Cookie Policy': 'Politique des cookies',
    'Made with': 'Fait avec',
    'in Cameroon': 'au Cameroun',
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
