import 'dart:convert';
import 'package:openapi_spec/openapi_spec.dart';

/// Generates an ApiTemplate JSON map from a parsed OpenAPI spec.
/// Output matches API Dash's RequestModel.fromJson() format exactly.
Map<String, dynamic> generateTemplate({
  required OpenApi spec,
  required String sourceId,
  required String name,
  required String description,
  required String category,
}) {
  final servers = spec.servers ?? [];
  final baseUrl = servers.isNotEmpty ? (servers.first.url ?? '') : '';
  final tags = <String>{};
  final requests = <Map<String, dynamic>>[];

  (spec.paths ?? {}).forEach((path, item) {
    final ops = {
      'get': item.get,
      'post': item.post,
      'put': item.put,
      'delete': item.delete,
      'patch': item.patch,
      'head': item.head,
      'options': item.options,
    };

    ops.forEach((method, op) {
      if (op == null) return;

      // Collect tags
      for (final t in op.tags ?? []) {
        if (t != null && t.trim().isNotEmpty) tags.add(t.trim());
      }

      // Build URL
      final url = baseUrl.endsWith('/')
          ? '${baseUrl.substring(0, baseUrl.length - 1)}$path'
          : '$baseUrl$path';

      // Build endpoint ID
      final endpointId = _buildId(sourceId, method, path);

      // Extract headers from parameters
      final headers = <Map<String, dynamic>>[];
      final params = <Map<String, dynamic>>[];

      for (final p in op.parameters ?? []) {
        if (p is ParameterHeader && p.name != null) {
          headers.add({'name': p.name!, 'value': ''});
        } else if (p is ParameterQuery && p.name != null) {
          params.add({'name': p.name!, 'value': ''});
        }
      }

      // Extract body
      String? body;
      String bodyContentType = 'json';
      if (op.requestBody != null) {
        final content = op.requestBody!.content;
        if (content != null && content.containsKey('application/json')) {
          bodyContentType = 'json';
          final media = content['application/json'];
          if (media?.example != null) {
            body = jsonEncode(media!.example);
          }
          // Add Content-Type header
          headers.add({'name': 'Content-Type', 'value': 'application/json'});
        } else if (content != null &&
            (content.containsKey('application/x-www-form-urlencoded') ||
                content.containsKey('multipart/form-data'))) {
          bodyContentType = 'formdata';
        }
      }

      // Build RequestModel-compatible JSON
      final request = <String, dynamic>{
        'id': endpointId,
        'apiType': 'rest',
        'name': op.summary ?? '${method.toUpperCase()} $path',
        'description': op.description ?? '',
        'httpRequestModel': {
          'method': method,
          'url': url,
          'headers': headers.isNotEmpty ? headers : null,
          'params': params.isNotEmpty ? params : null,
          'isHeaderEnabledList':
              headers.isNotEmpty ? List.filled(headers.length, true) : null,
          'isParamEnabledList':
              params.isNotEmpty ? List.filled(params.length, true) : null,
          'authModel': {'type': 'none'},
          'bodyContentType': bodyContentType,
          'body': body,
          'query': null,
          'formData': null,
        },
        'responseStatus': null,
        'message': null,
        'httpResponseModel': null,
        'preRequestScript': null,
        'postRequestScript': null,
        'aiRequestModel': null,
      };

      requests.add(request);
    });
  });

  return {
    'info': {
      'title': spec.info.title.isNotEmpty ? spec.info.title : name,
      'description': spec.info.description?.isNotEmpty == true
          ? spec.info.description
          : description,
      'tags': tags.toList(),
    },
    'requests': requests,
  };
}

/// Generate a slug-style ID: "catfacts-get-fact"
String _buildId(String sourceId, String method, String path) {
  final cleanPath = path
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll('/', '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '$sourceId-$method-$cleanPath';
}
