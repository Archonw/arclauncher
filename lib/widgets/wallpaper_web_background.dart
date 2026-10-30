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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows [url] in the native WebWallpaperView, which also handles load retries
/// and releasing the page while another app is in front.
class WallpaperWebBackground extends StatelessWidget {
  const WallpaperWebBackground({
    super.key,
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: IgnorePointer(
        child: AndroidView(
          key: ValueKey(url),
          viewType: "com.omeda.arc/web_wallpaper",
          creationParams: {"url": url},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
