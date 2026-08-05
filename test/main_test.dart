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
// The src import of gg_dna is deliberate: the barrel is not wasm-safe.
// ignore_for_file: implementation_imports
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:gg_dna/src/util/dna_fs.dart';
import 'package:gg_dna_js_bridge/src/main.dart';
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
    'rename'.toJS,
    ((JSString from, JSString to) => mem.rename(from.toDart, to.toDart)).toJS,
  );
  host.setProperty(
    'listFilesRecursive'.toJS,
    ((JSString d) =>
        mem.listFilesRecursive(d.toDart).map((e) => e.toJS).toList().toJS).toJS,
  );
  host.setProperty(
    'uncommittedPaths'.toJS,
    ((JSString r) =>
        mem.uncommittedPaths(r.toDart).map((e) => e.toJS).toList().toJS).toJS,
  );
  return host;
}

List<String> _strings(JSObject result, String key) =>
    (result.getProperty(key.toJS) as JSArray<JSString>)
        .toDart
        .map((e) => e.toDart)
        .toList();

void main() {
  group('CallbackDnaHost', () {
    test('delegates every call to the JS host object', () {
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

      expect(host.uncommittedPaths('/'), isEmpty);
      mem.uncommitted.add('LICENSE');
      expect(host.uncommittedPaths('/'), {'LICENSE'});
    });
  });

  group('DartBridge.instantiate', () {
    test('runs the engine and reports updated files', () {
      final mem = MemoryDnaHost(
        files: {'/proj/package.json': '{"name": "proj", "version": "1.0.0"}'},
      );
      final bridge = DartBridge();

      final result = bridge.instantiate(
        jsHostAround(mem),
        '/proj',
        null,
        '5.0.0',
      );

      expect(
        _strings(result, 'updated'),
        containsAll(<String>[
          'dna/_vars.json',
          'dna/_dna.json',
          'dna/.instances.json',
        ]),
      );
      expect(_strings(result, 'modifiedInstances'), isEmpty);
      expect(_strings(result, 'uncommittedTargets'), isEmpty);
      expect(mem.existsFile('/proj/dna/_dna.json'), isTrue);
    });

    test('reports uncommittedTargets for a dirty overwrite target', () {
      final mem = MemoryDnaHost(
        files: {'/proj/package.json': '{"name": "proj", "version": "1.0.0"}'},
      );
      final bridge = DartBridge();
      // First run creates the manifest, then it becomes dirty.
      bridge.instantiate(jsHostAround(mem), '/proj', null, '5.0.0');
      mem.writeString('/proj/dna/_dna.json', '{"version": 5}');
      mem.uncommitted.add('dna/_dna.json');

      final result = bridge.instantiate(
        jsHostAround(mem),
        '/proj',
        null,
        '5.0.0',
      );

      expect(_strings(result, 'uncommittedTargets'), ['dna/_dna.json']);
      expect(_strings(result, 'updated'), isEmpty);
      expect(mem.readString('/proj/dna/_dna.json'), '{"version": 5}');
      // The manifest has no DNA source — the record stays empty for it.
      expect(
        (result.getProperty('sources'.toJS) as JSObject)
            .getProperty('dna/_dna.json'.toJS),
        isNull,
      );
    });

    test('sources name the DNA file behind a reported path', () {
      final mem = MemoryDnaHost(
        files: {
          '/proj/package.json': '{"name": "proj", "version": "1.0.0", '
              '"devDependencies": {"a-dna": "^1.0.0"}}',
          '/proj/node_modules/a-dna/package.json':
              '{"name": "a-dna", "version": "1.0.0"}',
          '/proj/node_modules/a-dna/dna/doc/hello.md': '# Hello\n',
          '/proj/doc/hello.md': '# My own notes\n',
        },
        uncommitted: {'doc/hello.md'},
      );
      final bridge = DartBridge();

      final result = bridge.instantiate(
        jsHostAround(mem),
        '/proj',
        null,
        '5.0.0',
      );

      expect(_strings(result, 'uncommittedTargets'), ['doc/hello.md']);
      expect(
        ((result.getProperty('sources'.toJS) as JSObject)
                .getProperty('doc/hello.md'.toJS)! as JSString)
            .toDart,
        'a-dna/dna/doc/hello.md',
      );
    });
  });
}
