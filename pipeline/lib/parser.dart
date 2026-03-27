import 'dart:convert';
import 'package:openapi_spec/openapi_spec.dart';
import 'package:yaml/yaml.dart';

/// Parse a raw OpenAPI spec string into an OpenApi object.
/// Handles both JSON and YAML formats.
OpenApi? parseSpec(String raw, String format) {
  try {
    String jsonStr;
    if (format == 'yaml') {
      final yamlMap = loadYaml(raw);
      jsonStr = jsonEncode(yamlMap);
    } else {
      jsonStr = raw;
    }

    // Try parsing directly
    try {
      return OpenApi.fromString(source: jsonStr, format: null);
    } catch (_) {}

    // Workaround: remove empty security arrays that crash openapi_spec
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (map.containsKey('security') && map['security'] is List) {
        final sec = map['security'] as List;
        if (sec.any((item) => item is List && item.isEmpty)) {
          map.remove('security');
          final fixed = jsonEncode(map);
          return OpenApi.fromString(source: fixed, format: null);
        }
      }
    } catch (_) {}

    return null;
  } catch (e) {
    print('Parse error: $e');
    return null;
  }
}
