import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'es_ES', symbol: '€');
String money(double v) => _money.format(v);

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Confirmar'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return res ?? false;
}

/// Ejecuta una acción y muestra el error en un SnackBar si falla.
Future<void> guarded(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.error, {super.key});
  final Object? error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

const loading = Center(child: CircularProgressIndicator());
