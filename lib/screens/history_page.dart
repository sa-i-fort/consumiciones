import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../repo.dart';
import 'common.dart';

/// Historial de pagos. [uid] null = todos (admin); [names] resuelve uid -> nombre.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: StreamBuilder<List<Payment>>(
        stream: _stream,
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error);
          if (!s.hasData) return loading;
          final list = s.data!;
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
              );
            },
          );
        },
      ),
    );
  }
}
