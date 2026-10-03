import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../repo.dart';
import 'common.dart';

/// Historial de pagos. [uid] null = todos (admin); [names] resuelve uid -> nombre.
/// Solo el admin puede borrar pagos (individualmente o todos los mostrados).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.uid, this.names = const {}});

  final String? uid;
  final Map<String, String> names;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final Stream<List<Payment>> _stream = context.read<Repo>().payments(uid: widget.uid);
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final isAdmin = context.read<AppState>().isAdmin;

    return StreamBuilder<List<Payment>>(
      stream: _stream,
      builder: (context, s) {
        final list = s.data ?? const <Payment>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Historial de pagos'),
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Limpiar historial',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: list.isEmpty
                      ? null
                      : () async {
                          final ok = await confirm(
                            context,
                            'Limpiar historial',
                            'Se borrarán ${list.length} pagos del historial. No se puede deshacer y no afecta a las deudas actuales.',
                            action: 'Borrar todo',
                          );
                          if (ok && context.mounted) {
                            await guarded(context, () => repo.deletePayments(list.map((p) => p.id)));
                          }
                        },
                ),
            ],
          ),
          body: () {
            if (s.hasError) return ErrorBox(s.error);
            if (!s.hasData) return loading;
            if (list.isEmpty) return const Center(child: Text('Sin pagos registrados.'));
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                final who = widget.uid == null ? '${widget.names[p.userId] ?? p.userId} · ' : '';
                final by = p.markedBy == p.userId ? '' : ' (marcado por ${widget.names[p.markedBy] ?? 'admin'})';
                return ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(money(p.amountPaid)),
                  subtitle: Text('$who${_fmt.format(p.timestamp)}$by'),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: 'Borrar pago',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              'Borrar pago',
                              'Se borrará el pago de ${money(p.amountPaid)} del ${_fmt.format(p.timestamp)}. No se puede deshacer.',
                              action: 'Borrar',
                            );
                            if (ok && context.mounted) await guarded(context, () => repo.deletePayments([p.id]));
                          },
                        )
                      : null,
                );
              },
            );
          }(),
        );
      },
    );
  }
}
