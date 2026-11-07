import 'dart:io';

import 'package:cyclephotos/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kAppVersion é igual à versão do pubspec.yaml', () {
    final linha = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(linha.split(':')[1].trim().split('+')[0], kAppVersion);
  });
}
