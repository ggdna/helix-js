// @license
// Copyright (c) 2026 ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// The gg_dna DNA engine compiled to WebAssembly — instantiates and
/// verifies a project's DNA from TypeScript test runs.
///
/// This library is JS-only: it depends on `dart:js_interop` and can only
/// be compiled with `dart compile wasm` (see `build.dart`) or imported
/// from browser-platform tests.
library;

export 'src/main.dart';
