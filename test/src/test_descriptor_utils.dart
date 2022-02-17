// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:yaml/yaml.dart' as yaml;

export 'package:test_descriptor/test_descriptor.dart';

const _defaultPubspec = '''
name: test_package
version: 0.0.1
environment:
  sdk: '>=2.12.0 <3.0.0'
''';

/// Creates a pub package in a directory named [name].
Future<d.DirectoryDescriptor> createPackage(
  String name, {
  String pubspec = _defaultPubspec,
  String? dartdocOptions,
  String? analysisOptions,
  List<d.Descriptor> libFiles = const [],
  List<d.Descriptor> files = const [],
}) async {
  final parsedYaml = yaml.loadYaml(pubspec) as Map;
  final packageName = parsedYaml['name'];
  final versionConstraint = (parsedYaml['environment'] as Map)['sdk'];
  final languageVersion =
      RegExp(r'>=(\S*)\.0(-0)? ').firstMatch(versionConstraint)!.group(1);
  final packagesInfo = StringBuffer('''{
  "name": "$packageName",
  "rootUri": "../",
  "packageUri": "lib/",
  "languageVersion": "$languageVersion"
}''');
  if (parsedYaml.containsKey('dependencies')) {
    final dependencies = parsedYaml['dependencies'] as Map;
    for (var dep in dependencies.keys) {
      // This only accepts 'path' deps.
      final depConfig = dependencies[dep] as Map;
      final pathDep = depConfig['path'];

      packagesInfo.writeln(''',{
  "name": "$dep",
  "rootUri": "../$pathDep",
  "packageUri": "lib/"
}''');
    }
  }

  final packageDir = d.dir(name, [
    d.file('pubspec.yaml', pubspec),
    if (dartdocOptions != null) d.file('dartdoc_options.yaml', dartdocOptions),
    if (analysisOptions != null)
      d.file('analysis_options.yaml', analysisOptions),
    d.dir('lib', [...libFiles]),
    ...files,
    // Write out '.dart_tool/package_config.json' to avoid needing `pub get`.
    d.dir(
      '.dart_tool',
      [
        d.file('package_config.json', '''
{
  "configVersion": 2,
  "packages": [
    $packagesInfo
  ],
  "generated": "2021-09-14T20:36:04.604099Z",
  "generator": "pub",
  "generatorVersion": "2.14.1"
}
''')
      ],
    ),
  ]);
  await packageDir.create();
  return packageDir;
}