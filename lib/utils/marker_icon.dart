import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'dart:ui' as ui;

class MarkerIconGenerator {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> generate(String type,
      {bool isSelected = false}) async {
    final cacheKey = '$type${isSelected ? '_selected' : ''}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final assetName = _getAssetName(type);
    try {
      final ByteData data = await rootBundle.load(assetName);
      final Uint8List bytes = data.buffer.asUint8List();
      final descriptor = BitmapDescriptor.fromBytes(bytes);
      _cache[cacheKey] = descriptor;
      return descriptor;
    } catch (e) {
      debugPrint('加载图片失败: $assetName, 使用文字图标');
      final fallback = await _generateTextIcon(type, isSelected);
      _cache[cacheKey] = fallback;
      return fallback;
    }
  }

  static Future<BitmapDescriptor> _generateTextIcon(
      String type, bool isSelected) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 60.0;

    Color bgColor;
    String displayText;
    switch (type) {
      case '谷店':
        bgColor = const Color(0xFF908070);
        displayText = '谷';
        break;
      case '牌店':
        bgColor = Colors.purple.shade700;
        displayText = '牌';
        break;
      case '快闪':
        bgColor = Colors.cyan.shade700;
        displayText = '闪';
        break;
      case '主题餐厅':
        bgColor = Colors.red.shade700;
        displayText = '餐';
        break;
      case '主题咖啡厅':
        bgColor = Colors.brown.shade700;
        displayText = '咖';
        break;
      case '桌游店':
        bgColor = Colors.green.shade700;
        displayText = '桌';
        break;
      case '扭蛋':
        bgColor = Colors.indigo.shade700;
        displayText = '扭';
        break;
      case '吧唧':
        bgColor = Colors.pink.shade700;
        displayText = '吧';
        break;
      case 'Lolita':
        bgColor = Colors.purple.shade400;
        displayText = 'Lo';
        break;
      case '汉服':
        bgColor = Colors.teal.shade700;
        displayText = '汉';
        break;
      case 'jk制服':
        bgColor = const Color(0xFF807090);
        displayText = 'JK';
        break;
      default:
        bgColor = Colors.grey.shade600;
        displayText = type.length > 2 ? type.substring(0, 2) : type;
    }

    if (isSelected) {
      canvas.drawCircle(
          const Offset(size / 2, size / 2),
          size / 2,
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
    }

    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 4,
        Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill);

    final textSpan = TextSpan(
      text: displayText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    canvas.drawCircle(
        const Offset(size / 2, size - 8), 4, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static String _getAssetName(String type) {
    switch (type) {
      case '谷店':
        return 'assets/icons/shop.png';
      case '牌店':
        return 'assets/icons/card.png';
      case '快闪':
        return 'assets/icons/popup.png';
      case '主题餐厅':
        return 'assets/icons/restaurant.png';
      case '主题咖啡厅':
        return 'assets/icons/cafe.png';
      case '桌游店':
        return 'assets/icons/boardgame.png';
      case '扭蛋':
        return 'assets/icons/gacha.png';
      case '吧唧':
        return 'assets/icons/badge.png';
      case 'Lolita':
        return 'assets/icons/lolita.png';
      case '汉服':
        return 'assets/icons/hanfu.png';
      case 'jk制服':
        return 'assets/icons/jk.png';
      default:
        return 'assets/icons/default.png';
    }
  }
}
