/*
 * FLauncher
 * Copyright (C) 2026 Meddouri Badis
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class WallpaperWebBackground extends StatefulWidget {
  const WallpaperWebBackground({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<WallpaperWebBackground> createState() => _WallpaperWebBackgroundState();
}

class _WallpaperWebBackgroundState extends State<WallpaperWebBackground> with WidgetsBindingObserver {
  static const Duration _retryDelay = Duration(seconds: 15);

  WebViewController? _controller;
  Timer? _retryTimer;
  // The launcher starts before the network is up at boot, so a failed load is
  // retried and the WebView's error page stays hidden in the meantime.
  bool _failed = false;
  bool _errorInCurrentLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(WallpaperWebBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stop();
      _start();
    }
  }

  void _start() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) return;

    final controller = WebViewController();
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!_errorInCurrentLoad && _failed && mounted) {
            setState(() => _failed = false);
          }
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == false || !mounted) return;
          _errorInCurrentLoad = true;
          setState(() => _failed = true);
          _retryTimer?.cancel();
          _retryTimer = Timer(_retryDelay, () {
            _errorInCurrentLoad = false;
            controller.loadRequest(uri);
          });
        },
      ))
      ..loadRequest(uri);
    _controller = controller;
  }

  void _stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _failed = false;
    _errorInCurrentLoad = false;
    // Leave the page before dropping the controller so media and timers stop now
    // rather than whenever the WebView gets garbage collected.
    _controller?.loadRequest(Uri.parse("about:blank"));
    _controller = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the page while another app is in front: the sticks this runs on
    // have little memory to spare next to a streaming app.
    if (state == AppLifecycleState.resumed) {
      if (_controller == null) setState(_start);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_controller != null) setState(_stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(color: Colors.black);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          child: IgnorePointer(
            child: WebViewWidget(controller: controller),
          ),
        ),
        if (_failed) const ColoredBox(color: Colors.black),
      ],
    );
  }
}
