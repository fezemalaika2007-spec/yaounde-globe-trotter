/// Centralized asset paths under assets/images/.
class ImagePaths {
  static const String loginBackground = 'assets/images/auth/login_bg.jpg';
  static const String registerBackground = 'assets/images/auth/register_bg.jpg';
  static const String homeBanner = 'assets/images/home/hero_1.jpg';

  static const int _destinationPoolSize = 6;

  /// Destination images — shared across Destinations, Recommendations, and
  /// Itineraries screens. Upload images to assets/images/destinations/ as
  /// destination_1.jpg through destination_6.jpg.
  /// When no image is available, AssetImageWidget shows a graceful icon fallback.
  static String destination(int index) =>
      'assets/images/destinations/destination_${(index % _destinationPoolSize) + 1}.jpg';

  /// Reuse destination images for recommendations.
  static String recommendation(int index) => destination(index);

  /// Reuse destination images for itineraries.
  static String itinerary(int index) => destination(index);

  /// Hero images for the home screen carousel.
  static String homeHero(int index) =>
      'assets/images/home/hero_${(index % 9) + 1}.jpg';
}
