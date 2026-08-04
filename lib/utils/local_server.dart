import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;

class LocalServer {
  static HttpServer? _server;
  static int? _port;
  static String? _basePath;

  static int get port => _port ?? 0;

  static Future<void> start() async {
    if (_server != null) return;
    
    try {
      // 1. Extract assets to a temporary directory
      final tempDir = await getTemporaryDirectory();
    final amllDir = Directory(path.join(tempDir.path, 'amll_web_assets'));
    
    if (await amllDir.exists()) {
      await amllDir.delete(recursive: true);
    }
    await amllDir.create(recursive: true);
    
    _basePath = amllDir.path;

    final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> assets = assetManifest.listAssets();
    
    // Copy each asset
    for (String assetPath in assets) {
      if (assetPath.startsWith('assets/amll/')) {
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer;
        
        // Relative path inside amll/
        final relativePath = assetPath.substring('assets/amll/'.length);
        final file = File(path.join(amllDir.path, relativePath));
        
        await file.parent.create(recursive: true);
        await file.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }
    }

    // 2. Start local server
    final staticHandler = createStaticHandler(amllDir.path, defaultDocument: 'index.html');
    
    // Proxy handler for CORS bypass
    Future<Response> proxyHandler(Request request) async {
      if (request.url.path == 'proxy-image') {
        final targetUrl = request.url.queryParameters['url'];
        if (targetUrl == null || targetUrl.isEmpty) {
          return Response.badRequest(body: 'Missing url parameter');
        }
        try {
          final client = HttpClient();
          final req = await client.getUrl(Uri.parse(targetUrl));
          final res = await req.close();
          final bytes = await res.expand((b) => b).toList();
          return Response.ok(bytes, headers: {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'image/jpeg',
            'Cache-Control': 'public, max-age=31536000',
          });
        } catch (e) {
          return Response.internalServerError(body: e.toString());
        }
      }
      return staticHandler(request);
    }

    final pipeline = const Pipeline().addHandler(proxyHandler);
    
    // Bind to any available port
    _server = await io.serve(pipeline, InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    print('AMLL Local server started on port $_port serving from ${amllDir.path}');
    } catch (e) {
      print('AMLL LocalServer failed to start: $e');
    }
  }

  static Future<void> stop() async {
    await _server?.close();
    _server = null;
    _port = null;
  }
}
