import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../repo.dart';
import 'common.dart';

/// Consumo de un socio: catálogo con botones +/-, desglose, total y botón de pago.
/// [canRemove] permite restar unidades (solo administrador).
class TabView extends StatefulWidget {
  const TabView({super.key, required this.uid, this.canRemove = false});

  final String uid;
  final bool canRemove;

  @override
  State<TabView> createState() => _TabViewState();
}

class _TabViewState extends State<TabView> {
  late final Stream<ConsumptionTab> _tab = context.read<Repo>().tab(widget.uid);

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final app = context.read<AppState>();

    return StreamBuilder<List<Product>>(
      stream: repo.products,
      builder: (context, ps) => StreamBuilder<ConsumptionTab>(
        stream: _tab,
        builder: (context, ts) {
          if (ps.hasError || ts.hasError) return ErrorBox(ps.error ?? ts.error);
          if (!ps.hasData || !ts.hasData) return loading;

          final tab = ts.data!;
          final active = ps.data!.where((p) => p.active).toList();
          final activeIds = active.map((p) => p.id).toSet();
          // Líneas del consumo cuyo producto ya no está activo en el catálogo.
          final orphans = tab.items.values.where((i) => !activeIds.contains(i.productId)).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Total a pagar'),
                      Text(money(tab.totalAmount), style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: tab.totalAmount > 0
                            ? () async {
                                final ok = await confirm(
                                  context,
                                  'Marcar como pagado',
                                  'Se registrará un pago de ${money(tab.totalAmount)} y la deuda volverá a 0.',
                                  action: 'Pagado',
                                );
                                if (ok && context.mounted) {
                                  await guarded(context, () => repo.settle(widget.uid, app.uid));
                                }
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Marcar como pagado'),
                      ),
                    ],
                  ),
                ),
              ),
              if (active.isEmpty && orphans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No hay productos en el catálogo.')),
                ),
              for (final p in active) _line(context, repo, p, tab.items[p.id]),
              if (orphans.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Productos retirados del catálogo'),
                ),
                for (final i in orphans)
                  ListTile(
                    title: Text(i.name),
                    subtitle: Text('${i.quantity} × ${money(i.unitPrice)}'),
                    trailing: Text(money(i.subtotal)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, Repo repo, Product p, TabItem? item) {
    final qty = item?.quantity ?? 0;
    return ListTile(
      title: Text(p.name),
      subtitle: Text(qty > 0 ? '${money(p.price)} · $qty = ${money(qty * p.price)}' : money(p.price)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.canRemove)
            IconButton(
              onPressed: qty > 0 ? () => guarded(context, () => repo.adjust(widget.uid, p, -1)) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          SizedBox(
            width: 28,
            child: Text('$qty', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton.filledTonal(
            onPressed: () => guarded(context, () => repo.adjust(widget.uid, p, 1)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
