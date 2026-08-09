/// Centralized asset paths under assets/images/.
///
/// NOTE: Only authentication background images remain as local assets.
/// Destination images now come dynamically from the backend (Wikimedia or
/// category-based placeholders via the Recommendation Service).
/// Home page images also come from live destination records.
class ImagePaths {
  static const String loginBackground = 'assets/images/auth/images.jpg';
  static const String registerBackground = 'assets/images/auth/images.jpg';
}
