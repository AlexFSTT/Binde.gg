/// Maps CS2 map names to local asset image paths.
/// Images should be placed in assets/maps/ as JPG files.
///
/// Naming convention: assets/maps/{map_name}.jpg
/// Example: assets/maps/de_mirage.jpg
class MapAssets {
  MapAssets._();

  static const String _basePath = 'assets/maps';

  /// Get the asset path for a map. Returns null if no image exists.
  static String? getImagePath(String mapName) {
    final normalized = mapName.toLowerCase().trim();
    if (_knownMaps.contains(normalized)) {
      return '$_basePath/$normalized.jpg';
    }
    return null;
  }

  /// All maps we have images for.
  static const Set<String> _knownMaps = {
    'de_mirage',
    'de_inferno',
    'de_dust2',
    'de_nuke',
    'de_overpass',
    'de_ancient',
    'de_anubis',
    'de_vertigo',
    'de_train',
  };
}
