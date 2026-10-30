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

package com.omeda.arc;

import android.content.Context;
import android.graphics.Color;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewRenderProcess;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * Web page shown as the home screen background. The WebView is destroyed while the
 * activity is stopped, which releases its renderer process for the app in front:
 * Flutter renders no frames at that point, so this cannot be driven from Dart.
 */
public class WebWallpaperView implements PlatformView {
    public static final String VIEW_TYPE = "com.omeda.arc/web_wallpaper";

    private static final long RETRY_DELAY_MS = 15000;
    private static final Set<WebWallpaperView> instances = new HashSet<>();

    private final Context context;
    private final String url;
    private final FrameLayout container;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WebView webView;
    // The launcher starts before the network is up at boot, so a failed load is
    // retried and the WebView's error page stays hidden in the meantime.
    private boolean failed = false;

    public static class Factory extends PlatformViewFactory {
        public Factory() {
            super(StandardMessageCodec.INSTANCE);
        }

        @NonNull
        @Override
        public PlatformView create(Context context, int viewId, Object args) {
            return new WebWallpaperView(context, (String) ((Map<?, ?>) args).get("url"));
        }
    }

    public static void stopAll() {
        for (WebWallpaperView instance : instances) {
            instance.destroyWebView();
        }
    }

    public static void startAll() {
        for (WebWallpaperView instance : instances) {
            if (instance.webView == null) {
                instance.createWebView();
            }
        }
    }

    private WebWallpaperView(Context context, String url) {
        this.context = context;
        this.url = url;
        container = new FrameLayout(context);
        container.setBackgroundColor(Color.BLACK);
        container.setFocusable(false);
        container.setDescendantFocusability(ViewGroup.FOCUS_BLOCK_DESCENDANTS);
        instances.add(this);
        createWebView();
    }

    private void createWebView() {
        WebView view = new WebView(context);
        view.setBackgroundColor(Color.BLACK);
        view.setFocusable(false);
        view.setFocusableInTouchMode(false);
        WebSettings settings = view.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        view.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView finished, String finishedUrl) {
                if (finished == webView && !failed) {
                    finished.setVisibility(View.VISIBLE);
                }
            }

            @Override
            public void onReceivedError(WebView errored, WebResourceRequest request, WebResourceError error) {
                if (errored != webView || !request.isForMainFrame()) return;
                failed = true;
                errored.setVisibility(View.INVISIBLE);
                handler.removeCallbacksAndMessages(null);
                handler.postDelayed(() -> {
                    failed = false;
                    errored.loadUrl(url);
                }, RETRY_DELAY_MS);
            }

            @Override
            public boolean onRenderProcessGone(WebView gone, RenderProcessGoneDetail detail) {
                // Without this the whole launcher would crash along with the renderer.
                if (gone == webView) {
                    destroyWebView();
                    createWebView();
                }
                return true;
            }
        });
        webView = view;
        container.addView(view, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        view.loadUrl(url);
    }

    private void destroyWebView() {
        handler.removeCallbacksAndMessages(null);
        failed = false;
        if (webView == null) return;
        WebView view = webView;
        webView = null;
        container.removeView(view);
        // destroy() alone leaves the renderer process running with its memory.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            WebViewRenderProcess renderProcess = view.getWebViewRenderProcess();
            if (renderProcess != null) {
                renderProcess.terminate();
            }
        }
        view.destroy();
    }

    @Override
    public View getView() {
        return container;
    }

    @Override
    public void dispose() {
        instances.remove(this);
        destroyWebView();
    }
}
