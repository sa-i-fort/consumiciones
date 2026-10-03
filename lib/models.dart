const adminEmail = 'damarur92@gmail.com';

/// Clave de la whitelist: email en minúsculas con '.' -> ',' (RTDB no admite '.').
String emailKey(String email) => email.trim().toLowerCase().replaceAll('.', ',');

Map<String, dynamic> asMap(Object? v) =>
    v is Map ? v.map((k, x) => MapEntry(k.toString(), x)) : <String, dynamic>{};

double _d(Object? v) => v is num ? v.toDouble() : 0;
int _i(Object? v) => v is num ? v.toInt() : 0;
double round2(double v) => (v * 100).round() / 100;

class Product {
  final String id;
  final String name;
  final double price;
  final bool active;

  const Product({required this.id, required this.name, required this.price, required this.active});

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        name: (m['name'] ?? '') as String,
        price: _d(m['price']),
        active: m['active'] != false,
      );

  Map<String, dynamic> toMap() => {'name': name, 'price': price, 'active': active};
}

class TabItem {
  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;

  const TabItem({required this.productId, required this.name, required this.quantity, required this.unitPrice});

  double get subtotal => round2(quantity * unitPrice);

  factory TabItem.fromMap(String id, Map<String, dynamic> m) => TabItem(
        productId: id,
        name: (m['name'] ?? id).toString(),
        quantity: _i(m['quantity']),
        unitPrice: _d(m['unitPrice']),
      );

  Map<String, dynamic> toMap() => {'name': name, 'quantity': quantity, 'unitPrice': unitPrice};
}

class ConsumptionTab {
  final double totalAmount;
  final Map<String, TabItem> items;

  const ConsumptionTab({this.totalAmount = 0, this.items = const {}});

  factory ConsumptionTab.fromMap(Map<String, dynamic> m) {
    final items = asMap(m['items']).map((k, v) => MapEntry(k, TabItem.fromMap(k, asMap(v))));
    return ConsumptionTab(totalAmount: _d(m['totalAmount']), items: items);
  }
}

class Member {
  final String key;
  final String email;
  final String name;
  final bool approved;
  final String? uid;

  const Member({required this.key, required this.email, required this.name, required this.approved, this.uid});

  factory Member.fromMap(String key, Map<String, dynamic> m) => Member(
        key: key,
        email: (m['email'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        approved: m['approved'] == true,
        uid: m['uid'] as String?,
      );

  String get label => name.isNotEmpty ? name : email;
}

class Payment {
  final String id;
  final String userId;
  final double amountPaid;
  final DateTime timestamp;
  final String markedBy;

  const Payment({
    required this.id,
    required this.userId,
    required this.amountPaid,
    required this.timestamp,
    required this.markedBy,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> m) => Payment(
        id: id,
        userId: (m['userId'] ?? '') as String,
        amountPaid: _d(m['amountPaid']),
        timestamp: DateTime.fromMillisecondsSinceEpoch(_i(m['timestamp'])),
        markedBy: (m['markedBy'] ?? '') as String,
      );
}
