// Shared, pure helper functions for validating, deduplicating and
// normalizing destinations across the app (Destinations tab, Home
// featured list, Recommendations, Favorites).
//
// Extracted into an importable library so the same rules are used
// everywhere and can be unit-tested without a widget tree.

const List<String> kBadNamePatterns = [
  'unnamed',
  'no name',
  'road',
  'street',
  'path',
  'route',
  'way',
  'voie',
  'chemin',
  'ligne',
  'line',
  'unknown',
  'null',
  'drainage',
  'track',
  'bridge',
  'interchange',
  'poi',
  'point of interest',
];

const List<String> kBadDescriptionPatterns = [
  'no description',
  'n/a',
  'none',
  'unknown',
  'no details',
  'no info',
];

/// True when [name] looks like a real destination name (not a generic
/// OSM label such as "Road" or "Bridge").
bool hasGoodName(String name) {
  final normalized = name.toLowerCase();
  if (normalized.length < 4) return false;
  return !kBadNamePatterns.any(normalized.contains);
}

/// Validates a candidate image URL. Accepts any http(s) URL string.
bool isValidImageUrl(String image) {
  final trimmed = image.trim();
  if (trimmed.isEmpty) return false;
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return false;
  }
  final lower = trimmed.toLowerCase();
  final pathOnly = lower.split('?').first.split('#').first;
  if (pathOnly.endsWith('.html') || pathOnly.endsWith('.htm') || pathOnly.endsWith('.php')) {
    return false;
  }
  return true;
}

/// Normalizes and formats an image URL for reliable rendering across Web and mobile.
String formatImageUrl(String image) {
  final trimmed = image.trim();
  if (trimmed.isEmpty) return '';
  // lh3.googleusercontent.com URLs load directly in browsers — no proxy needed.
  return trimmed;
}


/// True when the destination references Yaoundé / Cameroon somewhere
/// (area, city, name and/or tags).
bool hasGoodLocation(Map<String, dynamic> destination) {
  final area = (destination['area'] ?? '').toString().toLowerCase();
  final city = (destination['city'] ?? '').toString().toLowerCase();
  final tags = ((destination['tags'] as List<dynamic>?) ?? [])
      .map((tag) => tag.toString().toLowerCase())
      .toList();
  final name = (destination['name'] ?? '').toString().toLowerCase();

  if (area.contains('yaound') || city.contains('yaound')) return true;
  if (name.contains('yaound')) return true;
  if (tags.any((tag) => tag.contains('yaound') || tag.contains('cameroon'))) {
    return true;
  }
  return false;
}

/// True when the destination has a meaningful description or enough
/// tags/category info to be useful on a card.
bool hasGoodDescription(Map<String, dynamic> destination) {
  final desc = (destination['description'] ?? '').toString().trim();
  if (desc.isEmpty) {
    final tags = (destination['tags'] as List<dynamic>?) ?? [];
    final category = (destination['category'] ?? '').toString().trim();
    return tags.length >= 2 || category.isNotEmpty;
  }
  if (desc.length < 30) return false;
  return !kBadDescriptionPatterns.any(desc.toLowerCase().contains);
}

bool isDestinationValid(Map<String, dynamic> destination) {
  final name = (destination['name'] ?? '').toString().trim();
  return name.isNotEmpty;
}

/// Normalizes a string for stable key comparisons.
String normalizeString(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Normalizes an image URL for duplicate detection: strips query strings
/// and fragments, lowercases scheme/netloc, and removes a trailing slash.
String normalizeImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return '';
  final withoutQuery = trimmed.split('?').first.split('#').first;
  final uri = Uri.tryParse(withoutQuery);
  if (uri == null) return withoutQuery.replaceAll(RegExp(r'/+$'), '');
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  return '$scheme://$host$path';
}

/// Builds a stable dedup key for a destination.
String normalizeDestinationKey(Map<String, dynamic> destination) {
  final id = destination['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return id;
  final fsqId = destination['fsq_id']?.toString().trim();
  if (fsqId != null && fsqId.isNotEmpty) return fsqId;
  final image = destination['image']?.toString().trim();
  if (image != null && image.isNotEmpty) return normalizeImageUrl(image);
  final name = (destination['name'] ?? '').toString().trim();
  return normalizeString(name);
}

/// Deduplicates a list of destination maps, dropping invalid entries.
///
/// Entries are kept in original order; the first occurrence of a key wins.
List<dynamic> deduplicateDestinations(List<dynamic> destinations) {
  final seenKeys = <String>{};
  final unique = <dynamic>[];
  for (final destination in destinations) {
    if (destination is! Map<String, dynamic>) continue;
    if (!isDestinationValid(destination)) continue;
    final key = normalizeDestinationKey(destination);
    if (key.isEmpty || seenKeys.contains(key)) continue;
    seenKeys.add(key);
    unique.add(destination);
  }
  return unique;
}

/// Returns a list of unique gallery image URLs from [images], using the
/// [fallback] image when nothing usable is present.
///
/// Deduplication is *normalized* (query strings/fragments stripped,
/// scheme/netloc lowercased) so the same photo served with different URL
/// parameters never appears twice.
List<String> uniqueImages(List<dynamic> images, {String fallback = ''}) {
  final seen = <String>{};
  final unique = <String>[];
  void addIfUnique(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return;
    final key = normalizeImageUrl(url);
    if (key.isEmpty || seen.contains(key)) return;
    seen.add(key);
    unique.add(url);
  }

  for (final image in images) {
    addIfUnique(image.toString());
  }
  if (unique.isEmpty && fallback.isNotEmpty) {
    addIfUnique(fallback);
  }
  return unique;
}
