// Genera los recursos de Google Play en store/ (icono 512, gráfico de funciones y capturas)
// renderizando las pantallas reales de la app con datos ficticios.
// Uso: flutter test tool/generate_store_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:consumiciones/app_state.dart';
import 'package:consumiciones/models.dart';
import 'package:consumiciones/repo.dart';
import 'package:consumiciones/screens/auth_screens.dart';
import 'package:consumiciones/screens/home_shell.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _orange = Color(0xFFD84315);

// ---------------------------------------------------------------- dobles de prueba

class FakeRepo extends Repo {
  static const _products = [
    Product(id: 'p1', name: 'Cerveza', price: 1.5, active: true),
    Product(id: 'p2', name: 'Refresco', price: 1.0, active: true),
    Product(id: 'p3', name: 'Agua', price: 0.8, active: true),
    Product(id: 'p4', name: 'Vermut', price: 2.0, active: true),
    Product(id: 'p5', name: 'Chupito', price: 1.2, active: true),
  ];

  static final _members = [
    Member(key: 'ana@example,com', email: 'ana@example.com', name: 'Ana', approved: true, uid: 'u1', lastLogin: DateTime(2026, 10, 6, 21, 12)),
    Member(key: 'jordi@example,com', email: 'jordi@example.com', name: 'Jordi', approved: true, uid: 'u2', lastLogin: DateTime(2026, 10, 5, 18, 40)),
    Member(key: 'marta@example,com', email: 'marta@example.com', name: 'Marta', approved: true, uid: 'me', lastLogin: DateTime(2026, 10, 7, 9, 5)),
    Member(key: 'pau@example,com', email: 'pau@example.com', name: 'Pau', approved: true, uid: 'u4', lastLogin: DateTime(2026, 9, 28, 22, 15)),
    Member(key: 'laia@example,com', email: 'laia@example.com', name: 'Laia', approved: true, uid: 'u5', lastLogin: DateTime(2026, 10, 2, 20, 30)),
  ];

  static ConsumptionTab _tab(Map<String, int> qty) {
    final items = {
      for (final e in qty.entries)
        e.key: TabItem(
          productId: e.key,
          name: _products.firstWhere((p) => p.id == e.key).name,
          quantity: e.value,
          unitPrice: _products.firstWhere((p) => p.id == e.key).price,
        ),
    };
    final total = items.values.fold<double>(0, (s, i) => s + i.subtotal);
    return ConsumptionTab(totalAmount: total, items: items);
  }

  static final _tabs = {
    'me': _tab({'p1': 4, 'p2': 2, 'p4': 1}),
    'u1': _tab({'p1': 3, 'p3': 2}),
    'u2': _tab({'p1': 6, 'p5': 3, 'p4': 2}),
    'u4': _tab({'p2': 1}),
  };

  @override
  Stream<List<Product>> products() => Stream.value(_products);

  @override
  Stream<ConsumptionTab> tab(String uid) => Stream.value(_tabs[uid] ?? const ConsumptionTab());

  @override
  Stream<List<Member>> whitelist() => Stream.value(_members);

  @override
  Stream<Map<String, ConsumptionTab>> allTabs() => Stream.value(_tabs);

  @override
  Stream<Set<String>> admins() => Stream.value({'ana@example,com'});

  @override
  Stream<List<Payment>> payments({String? uid}) => Stream.value([
        Payment(id: 'a', userId: 'me', amountPaid: 12.5, timestamp: DateTime(2026, 8, 16, 21, 40), markedBy: 'me'),
        Payment(id: 'b', userId: 'me', amountPaid: 8.3, timestamp: DateTime(2026, 8, 15, 23, 5), markedBy: 'me'),
        Payment(id: 'c', userId: 'me', amountPaid: 15.0, timestamp: DateTime(2026, 7, 26, 20, 15), markedBy: 'me'),
        Payment(id: 'd', userId: 'me', amountPaid: 6.9, timestamp: DateTime(2026, 7, 25, 22, 30), markedBy: 'me'),
      ]);
}

class FakeAppState extends ChangeNotifier implements AppState {
  FakeAppState({this.isAdmin = false});

  @override
  AuthStatus status = AuthStatus.ready;
  @override
  User? user;
  @override
  bool isAdmin;
  @override
  bool isOwner = true;
  @override
  String? error;
  @override
  String get uid => 'me';
  @override
  String get email => 'marta@example.com';
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------- utilidades

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT no definido');
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String f) async => ByteData.sublistView(File('$dir/$f').readAsBytesSync());

  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf'))).load();
  await (FontLoader('Roboto')
        ..addFont(read('roboto-regular.ttf'))
        ..addFont(read('roboto-medium.ttf'))
        ..addFont(read('roboto-bold.ttf'))
        ..addFont(read('roboto-light.ttf')))
      .load();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path, double pixelRatio) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

// En flutter_test las sombras de elevación se pintan como trazos negros sólidos; se anulan aquí
// (solo afecta a las capturas, no a la app).
ThemeData get _theme => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _orange).copyWith(shadow: Colors.transparent),
      useMaterial3: true,
    );

/// Captura [home] como pantalla de móvil (360x640 lógicos x3 = 1080x1920, relación 9:16).
Future<void> _phoneShot(
  WidgetTester tester,
  String file,
  Widget home, {
  bool admin = false,
  Future<void> Function()? before,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<Repo>.value(value: FakeRepo()),
        ChangeNotifierProvider<AppState>.value(value: FakeAppState(isAdmin: admin)),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: _theme, home: home),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (before != null) {
    await before();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  await _capture(tester, key, 'store/screenshots/$file', 3);
}

Future<void> _plainShot(WidgetTester tester, String path, Size size, Widget child, {double ratio = 1}) async {
  final key = GlobalKey();
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      // Sin un Material encima, el texto usaría la fuente de pruebas (bloques).
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
  await tester.pump();
  await _capture(tester, key, path, ratio);
}

// ---------------------------------------------------------------- generación

void main() {
  testWidgets('recursos de Google Play', (tester) async {
    await tester.runAsync(_loadFonts);

    // Icono 512x512 (a pantalla completa; Play aplica su propia máscara).
    await _plainShot(
      tester,
      'store/icon-512.png',
      const Size(512, 512),
      Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: const Icon(Icons.sports_bar, size: 380, color: _orange),
      ),
    );

    // Gráfico de funciones 1024x500.
    await _plainShot(
      tester,
      'store/feature-graphic-1024x500.png',
      const Size(1024, 500),
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE64A19), Color(0xFFBF360C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.sports_bar, size: 190, color: _orange),
            ),
            const SizedBox(width: 56),
            const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sa i Fort',
                    style: TextStyle(fontSize: 104, fontWeight: FontWeight.bold, color: Colors.white, height: 1.05)),
                Text('Las cuentas de la peña,\nsiempre claras',
                    style: TextStyle(fontSize: 38, color: Colors.white, height: 1.25)),
              ],
            ),
          ],
        ),
      ),
    );

    // Capturas de móvil.
    await _phoneShot(tester, '01-login.png', const LoginScreen());
    await _phoneShot(tester, '02-mi-consumo.png', const HomeShell());
    await _phoneShot(
      tester,
      '04-admin-socios.png',
      const HomeShell(),
      admin: true,
      before: () async {
        await tester.tap(find.text('Socios').last);
      },
    );
    await _phoneShot(
      tester,
      '05-admin-catalogo.png',
      const HomeShell(),
      admin: true,
      before: () async {
        await tester.tap(find.text('Catálogo').last);
      },
    );
    await _phoneShot(
      tester,
      '06-admin-whitelist.png',
      const HomeShell(),
      admin: true,
      before: () async {
        await tester.tap(find.text('Whitelist').last);
      },
    );
  });
}
