import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/html.dart' as html;
import '../util/js_util.dart' as js_util;


class PdfTexture extends StatefulWidget {
  final int textureId;
  PdfTexture({required this.textureId, Key? key}) : super(key: key);
  @override
  _PdfTextureState createState() => _PdfTextureState();

  html.CanvasElement get canvas => js_util.getProperty(html.window, 'pdf_render_texture_$textureId') as html.CanvasElement;
}

class _PdfTextureState extends State<PdfTexture> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _WebTextureManager.instance.register(widget.textureId, this);
  }

  @override
  void dispose() {
    _WebTextureManager.instance.unregister(widget.textureId, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawImage(image: _image);
  }

  void _requestUpdate() async {
    final canvas = widget.canvas;
    final data = canvas.context2D.getImageData(0, 0, canvas.width!, canvas.height!);
    final comp = Completer<ui.Image>();
    ui.decodeImageFromPixels(data.data.buffer.asUint8List(), canvas.width!, canvas.height!, ui.PixelFormat.bgra8888,
      (image) => comp.complete(image));
    _image = await comp.future;
    if (mounted) setState(() {});
  }
}

/// Receiving WebTexture update event from JS side.
class _WebTextureManager {
  static final instance = _WebTextureManager._();

  final _id2state = Map<int, List<_PdfTextureState>>();
  final _events = EventChannel('jp.espresso3389.pdf_render/web_texture_events');

  _WebTextureManager._() {
    _events.receiveBroadcastStream().listen((event) {
      if (event is int) {
        notify(event);
      }
    });
  }

  void register(int id, _PdfTextureState state) => _id2state.putIfAbsent(id, () => []).add(state);
  void unregister(int id, _PdfTextureState state) => _id2state[id]!.remove(state);
  void notify(int id) {
    final list = _id2state[id];
    if (list != null) {
      for (final s in list) {
        s._requestUpdate();
      }
    }
  }
}
