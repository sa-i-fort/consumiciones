import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'models.dart';

class Repo {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference _r(String path) => _db.ref(path);

  // Cada llamada crea un stream nuevo (los de Firebase son broadcast y no repiten el último
  // valor a quien se suscribe tarde): cada pantalla debe guardar el suyo en su State.
  Stream<List<Product>> products() => _r('products').onValue.map((e) {
    final list = asMap(e.snapshot.value)
        .entries
        .map((x) => Product.fromMap(x.key, asMap(x.value)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });

  /// Solo admin.
  Stream<List<Member>> whitelist() => _r('whitelist').onValue.map((e) {
    final list = asMap(e.snapshot.value)
        .entries
        .map((x) => Member.fromMap(x.key, asMap(x.value)))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  });

  /// Solo admin.
  Stream<Map<String, ConsumptionTab>> allTabs() => _r('tabs').onValue.map(
        (e) => asMap(e.snapshot.value).map((k, v) => MapEntry(k, ConsumptionTab.fromMap(asMap(v)))),
      );

  Stream<ConsumptionTab> tab(String uid) =>
      _r('tabs/$uid').onValue.map((e) => ConsumptionTab.fromMap(asMap(e.snapshot.value)));

  /// Admin: todos los pagos. Socio: solo los suyos (la regla exige filtrar por userId).
  Stream<List<Payment>> payments({String? uid}) {
    final Query q = uid == null
        ? _r('payments_history')
        : _r('payments_history').orderByChild('userId').equalTo(uid);
    return q.onValue.map((e) {
      final list = asMap(e.snapshot.value)
          .entries
          .map((x) => Payment.fromMap(x.key, asMap(x.value)))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // ---- Acceso ----

  Future<Member?> whitelistEntry(String email) async {
    final key = emailKey(email);
    final snap = await _r('whitelist/$key').get();
    if (!snap.exists) return null;
    return Member.fromMap(key, asMap(snap.value));
  }

  /// ¿Tiene el email la marca de admin promovido? (cada usuario puede leer solo la suya)
  Future<bool> hasAdminFlag(String email) async =>
      (await _r('admins/${emailKey(email)}').get()).value == true;

  /// Solo admin: claves de email (emailKey) de los admins promovidos.
  Stream<Set<String>> admins() => _r('admins').onValue.map((e) => asMap(e.snapshot.value).keys.toSet());

  /// Solo el owner. Promueve o revierte a un socio.
  Future<void> setAdmin(String key, bool admin) =>
      admin ? _r('admins/$key').set(true) : _r('admins/$key').remove();

  Future<void> registerUser(User user, {required bool isAdmin, required bool isOwner}) async {
    final email = (user.email ?? '').toLowerCase();
    await _r('users/${user.uid}').set({
      'email': email,
      'displayName': user.displayName ?? '',
      'role': isAdmin ? 'admin' : 'user',
    });
    // El owner no está en la whitelist; los demás (admins promovidos incluidos) guardan su uid.
    if (!isOwner) await _r('whitelist/${emailKey(email)}/uid').set(user.uid);
  }

  // ---- Consumiciones ----

  /// Suma (delta > 0) o resta (delta < 0) unidades. El precio se fija al actual del catálogo.
  Future<void> adjust(String uid, Product p, int delta) async {
    await _r('tabs/$uid').runTransaction((current) {
      final tab = ConsumptionTab.fromMap(asMap(current));
      final items = Map<String, TabItem>.from(tab.items);
      final qty = (items[p.id]?.quantity ?? 0) + delta;
      if (qty <= 0) {
        items.remove(p.id);
      } else {
        items[p.id] = TabItem(productId: p.id, name: p.name, quantity: qty, unitPrice: p.price);
      }
      if (items.isEmpty) return Transaction.success(null);
      final total = round2(items.values.fold<double>(0, (s, i) => s + i.subtotal));
      return Transaction.success({
        'totalAmount': total,
        'items': items.map((k, v) => MapEntry(k, v.toMap())),
        'lastUpdated': ServerValue.timestamp,
      });
    });
  }

  /// Registra el pago en el historial y pone la deuda a 0.
  Future<void> settle(String uid, String markedBy) async {
    final snap = await _r('tabs/$uid').get();
    final tab = ConsumptionTab.fromMap(asMap(snap.value));
    if (tab.totalAmount <= 0) return;
    final payId = _r('payments_history').push().key!;
    await _db.ref().update({
      'tabs/$uid': null,
      'payments_history/$payId': {
        'userId': uid,
        'amountPaid': tab.totalAmount,
        'timestamp': ServerValue.timestamp,
        'markedBy': markedBy,
      },
    });
  }

  /// Solo admin. Las reglas solo permiten escribir por pago, así que se borra por ids en un único update.
  Future<void> deletePayments(Iterable<String> ids) =>
      _db.ref().update({for (final id in ids) 'payments_history/$id': null});

  // ---- Catálogo (admin) ----

  Future<void> saveProduct(Product p) async {
    final id = p.id.isEmpty ? _r('products').push().key! : p.id;
    await _r('products/$id').set(p.toMap());
  }

  Future<void> deleteProduct(String id) => _r('products/$id').remove();

  // ---- Whitelist (admin) ----

  Future<void> addMember(String email, String name) => _r('whitelist/${emailKey(email)}').update({
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'approved': true,
        'createdAt': ServerValue.timestamp,
      });

  /// Si lo hace el owner también limpia la marca de admin (un admin promovido no puede tocar esa ruta).
  Future<void> removeMember(String key, {required bool clearAdmin}) => _db.ref().update({
        'whitelist/$key': null,
        if (clearAdmin) 'admins/$key': null,
      });
}
