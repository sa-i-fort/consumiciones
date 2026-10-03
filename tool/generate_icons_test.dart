// Genera los PNG base del icono (la cerveza del login) en assets/icon/.
// Uso: flutter test tool/generate_icons_test.dart
// Después: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _orange = Color(0xFFD84315);
const _size = 1024.0;

Future<void> _render(WidgetTester tester, String path, {required Color? background, required double glyph}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(_size, _size);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: _size,
          height: _size,
          color: background,
          alignment: Alignment.center,
          child: Icon(Icons.sports_bar, size: glyph, color: _orange),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

/// En los tests no se cargan los glifos reales de Material Icons: se leen del SDK de Flutter.
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT no definido');
  final font = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets('genera iconos', (tester) async {
    await tester.runAsync(_loadMaterialIcons);
    // Icono completo (legacy / web): fondo blanco.
    await _render(tester, 'assets/icon/icon.png', background: Colors.white, glyph: 760);
    // Primer plano del adaptive icon: transparente. flutter_launcher_icons ya le aplica un
    // margen del 16 % (zona segura), así que el glifo va grande.
    await _render(tester, 'assets/icon/icon_foreground.png', background: null, glyph: 900);
  });
}
