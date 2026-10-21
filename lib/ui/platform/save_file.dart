/// Saves a text file for the player: a browser download on the web, and
/// unsupported elsewhere (the Android build has no tester mode).
library;

export 'save_file_stub.dart' if (dart.library.js_interop) 'save_file_web.dart';
