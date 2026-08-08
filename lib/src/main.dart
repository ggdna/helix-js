// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// JavaScript bridge entry point.
///
/// `dart compile wasm` runs `main()` once when the module is loaded. We
/// attach a single object — `dartBridge` — to the globalThis scope. The
/// TypeScript wrapper picks it up from there.
///
/// The gg_dna engine core is host-agnostic: every file-system and git
/// access goes through the [DnaHost] seam. Here the seam is implemented by
/// [CallbackDnaHost], which forwards each call to a plain JS object whose
/// methods the TypeScript side implements with `node:fs` / `git`.
///
/// IMPORTANT: only the io-free engine core is imported
/// (`src/engine/instantiate.dart`, `src/util/dna_fs.dart`) — the gg_dna
/// barrel `lib/gg_dna.dart` exports `dart:io`/`dart:isolate` code
/// (IoDnaHost, runDnaTest) that does not compile to wasm.

// coverage:ignore-file

// The src imports below are deliberate: the gg_dna barrel is not
// wasm-compatible, only the io-free engine core is.
// ignore_for_file: implementation_imports

library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:gg_dna/src/engine/instantiate.dart';
import 'package:gg_dna/src/util/dna_fs.dart';

// .............................................................................
// JS-side object shapes.

/// JS view of the callback host injected by the TypeScript side:
///
/// ```
/// {
///   existsFile(path: string): boolean
///   existsDir(path: string): boolean
///   readBytes(path: string): Uint8Array          // throws on missing
///   writeBytes(path: string, bytes: Uint8Array): void
///   deleteFile(path: string): void
///   deleteDir(path: string): void
///   createDir(path: string): void
///   rename(from: string, to: string): void
///   listFilesRecursive(dir: string): string[]    // relative posix, files
///   uncommittedPaths(repoRoot: string): string[] // relative posix
///   commitPaths(repoRoot: string, paths: string[], message: string): void
/// }
/// ```
extension type JsDnaHost._(JSObject _) implements JSObject {
  /// Whether a file exists at `path`.
  external bool existsFile(String path);

  /// Whether a directory exists at `path`.
  external bool existsDir(String path);

  /// Reads the file at `path` as bytes; throws on missing files.
  external JSUint8Array readBytes(String path);

  /// Writes `bytes` to `path`, creating parent directories.
  external void writeBytes(String path, JSUint8Array bytes);

  /// Deletes the file at `path`; missing files are ignored.
  external void deleteFile(String path);

  /// Deletes the directory at `path` recursively; missing dirs are ignored.
  external void deleteDir(String path);

  /// Creates the directory at `path` recursively.
  external void createDir(String path);

  /// Renames/moves a file or directory from `from` to `to`.
  external void rename(String from, String to);

  /// Lists all files below `dir` recursively as relative posix paths
  /// (files only, symlinks not followed).
  external JSArray<JSString> listFilesRecursive(String dir);

  /// All paths below `repoRoot` carrying uncommitted work, relative to
  /// `repoRoot`.
  external JSArray<JSString> uncommittedPaths(String repoRoot);

  /// Commits exactly `paths` with `message`; throws when impossible.
  external void commitPaths(
    String repoRoot,
    JSArray<JSString> paths,
    String message,
  );
}

/// JS view of a failed run: `{ error: string }`. Errors are reported as a
/// value instead of being thrown — see [_guard].
extension type _BridgeErrorJs._(JSObject _) implements JSObject {
  external _BridgeErrorJs({required String error});
}

/// JS view of a [DnaInstantiationResult]: `{ messages, warnings,
/// modifiedInstances, updated, uncommittedTargets, sources }`.
extension type _InstantiationResultJs._(JSObject _) implements JSObject {
  external _InstantiationResultJs({
    required JSArray<JSString> messages,
    required JSArray<JSString> warnings,
    required JSArray<JSString> modifiedInstances,
    required JSArray<JSString> updated,
    required JSArray<JSString> uncommittedTargets,
    required JSObject sources,
    required bool committed,
  });
}

// .............................................................................
/// [DnaHost] implementation that delegates every access to the JS callback
/// object injected by the TypeScript side ([JsDnaHost]).
///
/// Byte payloads cross the boundary as `Uint8Array` ↔ [Uint8List]
/// (`.toDart`/`.toJS`), path lists as `string[]` ↔ `List<String>`.
class CallbackDnaHost implements DnaHost {
  /// Creates the host around the JS callback object [js].
  CallbackDnaHost(this.js);

  /// The JS callback object.
  final JsDnaHost js;

  @override
  bool existsFile(String path) => js.existsFile(path);

  @override
  bool existsDir(String path) => js.existsDir(path);

  @override
  Uint8List readBytes(String path) => js.readBytes(path).toDart;

  @override
  String readString(String path) => utf8.decode(readBytes(path));

  @override
  void writeBytes(String path, Uint8List bytes) =>
      js.writeBytes(path, bytes.toJS);

  @override
  void writeString(String path, String content) =>
      writeBytes(path, Uint8List.fromList(utf8.encode(content)));

  @override
  void deleteFile(String path) => js.deleteFile(path);

  @override
  void deleteDir(String path) => js.deleteDir(path);

  @override
  void createDir(String path) => js.createDir(path);

  @override
  void rename(String from, String to) => js.rename(from, to);

  @override
  List<String> listFilesRecursive(String dir) =>
      js.listFilesRecursive(dir).toDart.map((e) => e.toDart).toList();

  @override
  Set<String> uncommittedPaths(String repoRoot) =>
      js.uncommittedPaths(repoRoot).toDart.map((e) => e.toDart).toSet();

  @override
  void commitPaths(String repoRoot, List<String> paths, String message) =>
      js.commitPaths(repoRoot, _toJsStrings(paths), message);
}

// .............................................................................
// Public API exposed to JS

/// JS-facing wrapper around the gg_dna engine. Marked with [JSExport] so
/// `createJSInteropWrapper` produces a JS object whose own methods delegate
/// to the Dart instance methods below.
@JSExport()
class DartBridge {
  /// Construct the bridge.
  DartBridge();

  /// Runs one DNA instantiation over `targetRoot` using the injected
  /// callback [host] and returns `{ messages, warnings,
  /// modifiedInstances, updated, uncommittedTargets, sources }`.
  ///
  /// [baseDnaRoot] points at the bundled copy of gg_dna's own package root
  /// (its `dna/` subfolder is the implicit base layer); pass `null` to run
  /// without a base layer. [baseVersion] is the gg_dna version recorded in
  /// the manifest.
  ///
  /// A failed run returns `{ error: string }` instead — see [_guard].
  JSObject instantiate(
    JSObject host,
    String targetRoot,
    String? baseDnaRoot,
    String baseVersion,
  ) {
    return _guard(() {
      final result = instantiateDna(
        host: CallbackDnaHost(host as JsDnaHost),
        targetRoot: targetRoot,
        baseDnaRoot: baseDnaRoot,
        baseVersion: baseVersion,
      );
      return _InstantiationResultJs(
        messages: _toJsStrings(result.messages),
        warnings: _toJsStrings(result.warnings),
        modifiedInstances: _toJsStrings(result.modifiedInstances),
        updated: _toJsStrings(result.updated),
        uncommittedTargets: _toJsStrings(result.uncommittedTargets),
        sources: _toJsRecord(result.sources),
        committed: result.committed,
      );
    });
  }
}

// .............................................................................
/// Converts a Dart string map into a plain JS object (`Record<string,
/// string>`).
JSObject _toJsRecord(Map<String, String> map) {
  final object = JSObject();
  map.forEach((key, value) => object.setProperty(key.toJS, value.toJS));
  return object;
}

// .............................................................................
JSArray<JSString> _toJsStrings(List<String> list) =>
    list.map((s) => s.toJS).toList().toJS;

// .............................................................................
// Error guard: report Dart exceptions (FormatException from config /
// collision errors, Exception from the engine) as a `{ error }` value.
//
// Errors must not be *thrown* across the wasm boundary: dart2wasm turns
// every Dart throw — including `throw someJsValue` — into an opaque
// `WebAssembly.Exception` whose payload JS cannot read, so the caller sees
// nothing but "[object WebAssembly.Exception]". Returning the message keeps
// it readable; the TypeScript side turns it back into a real `Error`.

JSObject _guard(JSObject Function() body) {
  try {
    return body();
  } catch (e, st) {
    return _BridgeErrorJs(error: _describeError(e, st));
  }
}

/// Renders [e] for the JS caller. Engine failures carry their own message
/// and are reported plainly; anything else is a bug in the bridge or the
/// engine and keeps its stack trace.
String _describeError(Object e, StackTrace st) =>
    e is Exception || e is String ? '$e' : '$e\n$st';

// .............................................................................
// Bind to globalThis. The TypeScript wrapper reads `globalThis.dartBridge`
// after the module's `main()` has run.

void main() {
  final bridge = createJSInteropWrapper(DartBridge());
  globalContext.setProperty('dartBridge'.toJS, bridge);
}
