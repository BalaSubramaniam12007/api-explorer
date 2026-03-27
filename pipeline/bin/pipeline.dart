import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import '../lib/parser.dart';
import '../lib/template_generator.dart';
import '../lib/index_manager.dart';

void main(List<String> arguments) {
  final argParser = ArgParser()
    ..addOption('source-id', mandatory: true)
    ..addOption('spec-file', mandatory: true)
    ..addOption('category', mandatory: true)
    ..addOption('sources-file', mandatory: true)
    ..addOption('output-dir', mandatory: true);

  final args = argParser.parse(arguments);
  final sourceId = args['source-id'] as String;
  final specFilePath = args['spec-file'] as String;
  final category = args['category'] as String;
  final sourcesFile = args['sources-file'] as String;
  final outputDir = args['output-dir'] as String;

  // Read source metadata
  final sourcesJson = jsonDecode(File(sourcesFile).readAsStringSync());
  final source =
      (sourcesJson['sources'] as List).firstWhere((s) => s['id'] == sourceId);
  final name = source['name'] as String;
  final description = source['description'] as String;
  final specFormat = source['specFormat'] as String;

  // Read raw spec
  final rawSpec = File(specFilePath).readAsStringSync();

  // Parse spec
  final spec = parseSpec(rawSpec, specFormat);
  if (spec == null) {
    stderr.writeln('Failed to parse spec for $sourceId');
    exit(1);
  }

  // Generate template
  final template = generateTemplate(
    spec: spec,
    sourceId: sourceId,
    name: name,
    description: description,
    category: category,
  );

  // Determine version
  final apiDir = '$outputDir/apis/$sourceId';
  final version = getNextVersion(apiDir);
  final versionDir = '$apiDir/$version';
  Directory(versionDir).createSync(recursive: true);

  // Write template
  final templateFile = File('$versionDir/templates.json');
  templateFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(template),
  );
  print('Wrote: ${templateFile.path}');

  // Update per-API index
  updateApiIndex(apiDir, sourceId, name, version);

  // Update global index
  updateGlobalIndex(outputDir, sourcesFile);

  print('Done: $sourceId $version');
}
