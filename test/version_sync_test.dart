// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Guards the version contract of the bridge: pubspec.yaml is the source of
// truth and `dart run scripts/sync_version.dart` copies it into
// package.json. This VM test fails when the two run out of sync.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('package.json version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    final pkg =
        json.decode(File('package.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      pkg['version'],
      match!.group(1),
      reason: 'Run: dart run scripts/sync_version.dart',
    );
  });
}
