import 'dart:convert';
import 'package:openapi_spec/openapi_spec.dart';
import 'package:yaml/yaml.dart';

/// Parse a raw OpenAPI spec string into an OpenApi object.
/// Handles both JSON and YAML formats.
OpenApi? parseSpec(String raw, String format) {
  try {
    String jsonStr;
    if (format == 'yaml') {
      final yamlNode = loadYaml(raw);
      final dartMap = _yamlToJson(yamlNode);
      jsonStr = jsonEncode(dartMap);
    } else {
      jsonStr = raw;
    }

    // Clean the spec before parsing
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    _cleanSpec(map);
    jsonStr = jsonEncode(map);

    try {
      return OpenApi.fromString(source: jsonStr, format: null);
    } catch (e) {
      print('Parse failed: $e');
    }

    return null;
  } catch (e) {
    print('Parse error: $e');
    return null;
  }
}

/// Deep-convert YamlMap/YamlList to regular Dart Map/List
dynamic _yamlToJson(dynamic node) {
  if (node is YamlMap) {
    return node.map((k, v) => MapEntry(k.toString(), _yamlToJson(v)));
  }
  if (node is YamlList) {
    return node.map(_yamlToJson).toList();
  }
  return node;
}

/// Clean spec of all known problematic fields before parsing.
void _cleanSpec(Map<String, dynamic> spec) {
  // Remove top-level empty security arrays
  _removeEmptySecurity(spec);

  // Remove examples that crash openapi_spec type casting
  _removeExamples(spec);

  // Strip fields that crash openapi_spec strict type casting 
  _stripDangerousFields(spec);

  // Remove $ref parameters without 'in' which crash openapi_spec
  _removeRefParameters(spec);

  // Remove x- extensions that may cause issues
  spec.remove('x-tagGroups');

  // Clean individual path operations
  final paths = spec['paths'];
  if (paths is Map) {
    for (final pathItem in paths.values) {
      if (pathItem is! Map) continue;
      for (final op in pathItem.values) {
        if (op is! Map) continue;
        _removeEmptySecurity(op);
      }
    }
  }
}

void _removeEmptySecurity(Map spec) {
  if (spec.containsKey('security') && spec['security'] is List) {
    final sec = spec['security'] as List;
    if (sec.any((item) =>
        (item is List && item.isEmpty) || (item is Map && item.isEmpty))) {
      spec.remove('security');
    }
  }
}

/// Recursively remove 'example' and 'examples' fields from all schemas.
/// openapi_spec crashes when example values don't match declared types.
void _removeExamples(dynamic node) {
  if (node is Map) {
    node.remove('example');
    node.remove('examples');
    for (final v in node.values) {
      _removeExamples(v);
    }
  } else if (node is List) {
    for (final item in node) {
      _removeExamples(item);
    }
  }
}

/// Recursively remove fields that frequently crash the parser with mixed types or unsupported structures.
void _stripDangerousFields(dynamic node) {
  if (node is Map) {
    node.remove('enum');
    node.remove('default');
    node.remove('anyOf');
    node.remove('allOf');
    node.remove('oneOf');
    for (final v in node.values) {
      _stripDangerousFields(v);
    }
  } else if (node is List) {
    for (final item in node) {
      _stripDangerousFields(item);
    }
  }
}

/// Recursively remove $ref parameters that lack an 'in' field, which crash the parser.
void _removeRefParameters(dynamic node) {
  if (node is Map) {
    if (node.containsKey('parameters') && node['parameters'] is List) {
      final params = node['parameters'] as List;
      params.removeWhere((p) => p is Map && p.containsKey(r'$ref') && !p.containsKey('name'));
    }
    for (final v in node.values) {
      _removeRefParameters(v);
    }
  } else if (node is List) {
    for (final item in node) {
      _removeRefParameters(item);
    }
  }
}
