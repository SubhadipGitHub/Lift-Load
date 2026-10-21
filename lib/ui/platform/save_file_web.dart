import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether [saveTextFile] can save on this platform.
const bool canSaveFile = true;

/// Starts a browser download of [text] as [name].
Future<bool> saveTextFile(String name, String text) async {
  try {
    final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name
      ..style.display = 'none';
    web.document.body?.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } on Object {
    return false;
  }
}
