// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Tests for the JS bridge in `lib/src/main.dart`.
//
// The bridge depends on `dart:js_interop` and `dart:js_interop_unsafe`, so
// it can only run in a JS-capable environment. The default `dart test` run
// on the VM skips this file via `@TestOn('browser')`. Execute it with:
//
//   dart test -p chrome -c dart2wasm test/main_test.dart
//
// The dart2wasm compiler is required (not dart2js): gg_hash's tree hashing
// uses Int64List, which dart2js does not support — dart2wasm (the
// production target of this package) does.
//
// The end-to-end behaviour is also exercised by the Vitest spec under
// `typescript/test/` (which runs against the compiled wasm bundle in
// Node). This file complements it by unit-testing the bridge classes
// directly, without going through the build step: the JS host object is
// emulated with Dart closures around a MemoryDnaHost.
// The src import of helix is deliberate: the barrel is not wasm-safe.
// ignore_for_file: implementation_imports
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:helix/src/util/dna_fs.dart';
import 'package:helix_js/src/main.dart';
import 'package:test/test.dart';

/// Wraps [mem] into a JS object with the callback-host shape.
JSObject jsHostAround(MemoryDnaHost mem) {
  final host = JSObject();
  host.setProperty(
    'existsFile'.toJS,
    ((JSString p) => mem.existsFile(p.toDart).toJS).toJS,
  );
  host.setProperty(
    'existsDir'.toJS,
    ((JSString p) => mem.existsDir(p.toDart).toJS).toJS,
  );
  host.setProperty(
    'readBytes'.toJS,
    ((JSString p) => mem.readBytes(p.toDart).toJS).toJS,
  );
  host.setProperty(
    'writeBytes'.toJS,
    ((JSString p, JSUint8Array b) => mem.writeBytes(p.toDart, b.toDart)).toJS,
  );
  host.setProperty(
    'deleteFile'.toJS,
    ((JSString p) => mem.deleteFile(p.toDart)).toJS,
  );
  host.setProperty(
    'deleteDir'.toJS,
    ((JSString p) => mem.deleteDir(p.toDart)).toJS,
  );
  host.setProperty(
    'createDir'.toJS,
    ((JSString p) => mem.createDir(p.toDart)).toJS,
  );
  host.setProperty(
    'createTempDir'.toJS,
    ((JSString p) => mem.createTempDir(p.toDart).toJS).toJS,
  );
  host.setProperty(
    'realPath'.toJS,
    ((JSString p) => mem.realPath(p.toDart).toJS).toJS,
  );
  host.setProperty(
    'rename'.toJS,
    ((JSString from, JSString to) => mem.rename(from.toDart, to.toDart)).toJS,
  );
  host.setProperty(
    'listFilesRecursive'.toJS,
    ((JSString d) =>
            mem.listFilesRecursive(d.toDart).map((e) => e.toJS).toList().toJS)
        .toJS,
  );
  host.setProperty(
    'uncommittedPaths'.toJS,
    ((JSString r) => mem.uncommitted.map((e) => e.toJS).toList().toJS).toJS,
  );
  host.setProperty(
    'commitPaths'.toJS,
    ((JSString r, JSArray<JSString> paths, JSString message) {
      mem.commitPaths(
        r.toDart,
        paths.toDart.map((e) => e.toDart).toList(),
        message.toDart,
      );
    }).toJS,
  );
  return host;
}

List<String> _strings(JSObject result, String key) =>
    (result.getProperty(key.toJS) as JSArray<JSString>).toDart
        .map((e) => e.toDart)
        .toList();

void main() {
  group('CallbackDnaHost', () {
    test('delegates every call to the JS host object', () async {
      final mem = MemoryDnaHost(files: {'/a/b.txt': 'hello'});
      final host = CallbackDnaHost(jsHostAround(mem) as JsDnaHost);

      expect(host.existsFile('/a/b.txt'), isTrue);
      expect(host.existsFile('/a/missing.txt'), isFalse);
      expect(host.existsDir('/a'), isTrue);
      expect(host.readString('/a/b.txt'), 'hello');
      expect(host.readBytes('/a/b.txt'), Uint8List.fromList('hello'.codeUnits));

      host.writeString('/a/c.txt', 'world');
      expect(mem.readString('/a/c.txt'), 'world');

      host.rename('/a/c.txt', '/a/d.txt');
      expect(mem.existsFile('/a/d.txt'), isTrue);

      host.deleteFile('/a/d.txt');
      expect(mem.existsFile('/a/d.txt'), isFalse);

      host.createDir('/a/sub');
      expect(host.listFilesRecursive('/a'), ['b.txt']);

      host.deleteDir('/a');
      expect(mem.existsFile('/a/b.txt'), isFalse);

      expect(await host.uncommittedPaths('/'), isEmpty);
      mem.uncommitted.add('LICENSE');
      expect(await host.uncommittedPaths('/'), {'LICENSE'});
      await host.commitPaths('/', ['LICENSE'], 'msg');
      expect(mem.commits.single.message, 'msg');
      expect(host.createTempDir('helix_'), startsWith('/tmp/helix_'));
      expect(host.realPath('/a'), '/a');
    });
  });

  group('DartBridge.instantiate', () {
    test('runs the engine and reports updated files', () async {
      final mem = MemoryDnaHost(
        files: {'/proj/package.json': '{"name": "proj", "version": "1.0.0"}'},
      );
      final bridge = DartBridge();

      final result = await bridge
          .instantiate(jsHostAround(mem), '/proj', null, '4.0.0')
          .toDart;

      expect(
        _strings(result, 'updated'),
        containsAll(<String>['dna/_vars.json', 'dna/_generated.json']),
      );
      expect(_strings(result, 'backedUp'), isEmpty);
      expect(_strings(result, 'uncommittedTargets'), isEmpty);
      expect(mem.existsFile('/proj/dna/_generated.json'), isTrue);
    });

    test('reports uncommittedTargets for a dirty overwrite target', () async {
      final mem = MemoryDnaHost(
        files: {'/proj/package.json': '{"name": "proj", "version": "1.0.0"}'},
      );
      final bridge = DartBridge();
      // First run creates the manifest, then it becomes dirty.
      await bridge
          .instantiate(jsHostAround(mem), '/proj', null, '4.0.0')
          .toDart;
      mem.writeString('/proj/dna/_generated.json', '{"version": 1}');
      mem.uncommitted.add('dna/_generated.json');

      final result = await bridge
          .instantiate(jsHostAround(mem), '/proj', null, '4.0.0')
          .toDart;

      expect(_strings(result, 'uncommittedTargets'), ['dna/_generated.json']);
      expect(_strings(result, 'updated'), isEmpty);
      expect(mem.readString('/proj/dna/_generated.json'), '{"version": 1}');
      // The manifest has no DNA source — the record stays empty for it.
      expect(
        (result.getProperty('sources'.toJS) as JSObject).getProperty(
          'dna/_generated.json'.toJS,
        ),
        isNull,
      );
    });

    test('sources name the DNA file behind a reported path', () async {
      final mem = MemoryDnaHost(
        files: {
          '/proj/package.json':
              '{"name": "proj", "version": "1.0.0", '
              '"dependencies": {"a-dna": "^1.0.0"}}',
          '/proj/dna/_dna.json': '{"version": 1, "layers": ["a-dna"]}',
          '/proj/node_modules/a-dna/package.json':
              '{"name": "a-dna", "version": "1.0.0"}',
          '/proj/node_modules/a-dna/dna/_dna.json':
              '{"version": 1, "role": "dna"}',
          '/proj/node_modules/a-dna/dna/doc/hello.md': '# Hello\n',
          '/proj/doc/hello.md': '# My own notes\n',
        },
        uncommitted: {'doc/hello.md'},
      );
      final bridge = DartBridge();

      final result = await bridge
          .instantiate(jsHostAround(mem), '/proj', null, '4.0.0')
          .toDart;

      expect(_strings(result, 'uncommittedTargets'), ['doc/hello.md']);
      expect(
        ((result.getProperty('sources'.toJS) as JSObject).getProperty(
                  'doc/hello.md'.toJS,
                )!
                as JSString)
            .toDart,
        'a-dna/dna/doc/hello.md',
      );
    });

    test('reports engine failures as a readable { error } value', () async {
      // `dna/_dna.json` names a DNA layer that is not installed — the
      // engine throws, and the bridge must hand the message to JS as a
      // value: a Dart throw would arrive as an opaque
      // WebAssembly.Exception.
      final mem = MemoryDnaHost(
        files: {
          '/proj/package.json': '{"name": "proj", "version": "1.0.0"}',
          '/proj/dna/_dna.json': '{"version": 1, "layers": ["not-installed"]}',
        },
      );
      final bridge = DartBridge();

      final result = await bridge
          .instantiate(jsHostAround(mem), '/proj', null, '4.0.0')
          .toDart;

      final error = result.getProperty('error'.toJS) as JSString?;
      expect(error, isNotNull);
      expect(error!.toDart, contains('not-installed'));
      expect(result.getProperty('updated'.toJS), isNull);
    });
  });
}
