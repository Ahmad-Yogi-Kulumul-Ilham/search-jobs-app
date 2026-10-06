import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_windows/webview_windows.dart';

/// The in-app browser that shows an application form, behind an interface
/// so pages can be tested without a real browser.
abstract class FormBrowser {
  /// Prepares the browser; must finish before anything else is called.
  /// Throws when no browser engine is available.
  Future<void> initialize();

  Future<void> open(String url);

  /// Runs [script] in the page and returns its result.
  Future<Object?> run(String script);

  Future<void> back();

  Future<void> reload();

  Stream<String> get url;

  Stream<bool> get loading;

  Widget view();

  Future<void> dispose();
}

/// The Windows implementation, on Microsoft Edge WebView2.
class WebviewFormBrowser implements FormBrowser {
  final _controller = WebviewController();

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    // Pop-ups, such as "sign in with LinkedIn", open in the same view.
    await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
  }

  @override
  Future<void> open(String url) => _controller.loadUrl(url);

  @override
  Future<Object?> run(String script) => _controller.executeScript(script);

  @override
  Future<void> back() => _controller.goBack();

  @override
  Future<void> reload() => _controller.reload();

  @override
  Stream<String> get url => _controller.url;

  @override
  Stream<bool> get loading =>
      _controller.loadingState.map((state) => state == LoadingState.loading);

  @override
  Widget view() => Webview(_controller);

  @override
  Future<void> dispose() => _controller.dispose();
}
