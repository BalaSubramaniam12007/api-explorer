import 'dart:io';
import 'dart:convert';

const _encoder = JsonEncoder.withIndent('  ');

/// Generate immutable CDN pointer file.
void generateCurrentPointer(String outputDir, String commitSha) {
  final now = DateTime.now().toUtc();
  final pointer = {
    'sha': commitSha,
    'updatedAt': now.toIso8601String(),
    'message': 'Pointer to latest immutable CDN URLs at commit',
  };

  final pointerFile = File('$outputDir/current.json');
  pointerFile.writeAsStringSync(_encoder.convert(pointer));
  print('Generated: ${pointerFile.path}');
}

/// Get the next version string using date (YYYY-MM-DD).
String getNextVersion(String apiDir) {
  final now = DateTime.now().toUtc();
  final dateStr = now.toIso8601String().split('T')[0];
  return dateStr;
}

/// Write/update the per-API index file.
void updateApiIndex(
    String apiDir, String sourceId, String name, String version) {
  final indexFile = File('$apiDir/index.json');

  Map<String, dynamic> index;
  if (indexFile.existsSync()) {
    index = jsonDecode(indexFile.readAsStringSync());
  } else {
    index = {'id': sourceId, 'name': name, 'versions': []};
  }

  final versions = index['versions'] as List;
  versions.add({
    'version': version,
    'templatesPath': '$version/templates.json',
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  });

  indexFile.writeAsStringSync(_encoder.convert(index));
  print('Updated: ${indexFile.path}');
}

/// Rebuild the global index from all per-API indexes + sources.json.
void updateGlobalIndex(String outputDir, String sourcesFile) {
  final sourcesJson = jsonDecode(File(sourcesFile).readAsStringSync());
  final sourcesList = sourcesJson['sources'] as List;

  final apis = <Map<String, dynamic>>[];
  final categories = <String>{};

  final apisDir = Directory('$outputDir/apis');
  if (!apisDir.existsSync()) return;

  for (final apiFolder in apisDir.listSync()) {
    if (apiFolder is! Directory) continue;
    final id = apiFolder.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final apiIndex = File('${apiFolder.path}/index.json');
    if (!apiIndex.existsSync()) continue;

    final apiData = jsonDecode(apiIndex.readAsStringSync());
    final versions = apiData['versions'] as List;
    final latestVersion = versions.isNotEmpty ? versions.last['version'] : 'v1';

    // Get category from sources.json
    final source = sourcesList.firstWhere(
      (s) => s['id'] == id,
      orElse: () => null,
    );
    final category = source?['category'] ?? 'Uncategorized';
    final description = source?['description'] ?? '';
    categories.add(category);

    // Count endpoints from latest template
    int endpointCount = 0;
    final templateFile =
        File('${apiFolder.path}/$latestVersion/templates.json');
    if (templateFile.existsSync()) {
      final tmpl = jsonDecode(templateFile.readAsStringSync());
      endpointCount = (tmpl['requests'] as List?)?.length ?? 0;
    }

    apis.add({
      'id': id,
      'name': apiData['name'],
      'category': category,
      'description': description,
      'latestVersion': latestVersion,
      'endpointCount': endpointCount,
    });
  }

  final globalIndex = {
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'apis': apis,
    'categories': categories.toList()..sort(),
  };

  final indexFile = File('$outputDir/index.json');
  indexFile.writeAsStringSync(_encoder.convert(globalIndex));
  print('Updated: ${indexFile.path}');
}
