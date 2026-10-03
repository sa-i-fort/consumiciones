import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../repo.dart';
import 'common.dart';
import 'history_page.dart';
import 'tab_view.dart';

// ---------------------------------------------------------------- Socios

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final app = context.read<AppState>();

    return StreamBuilder<List<Member>>(
      stream: repo.whitelist,
      builder: (context, ms) => StreamBuilder<Map<String, ConsumptionTab>>(
        stream: repo.allTabs,
        builder: (context, ts) {
          if (ms.hasError || ts.hasError) return ErrorBox(ms.error ?? ts.error);
          if (!ms.hasData || !ts.hasData) return loading;

          final members = ms.data!;
          final tabs = ts.data!;
          final total = tabs.values.fold<double>(0, (s, t) => s + t.totalAmount);
          final names = {for (final m in members) if (m.uid != null) m.uid!: m.label};
          final debtors = tabs.entries.where((e) => e.value.totalAmount > 0).toList();

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Deuda global'),
                      Text(money(total), style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: debtors.isEmpty
                                ? null
                                : () async {
                                    final ok = await confirm(
                                      context,
                                      'Marcar todo como pagado',
                                      'Se registrarán ${debtors.length} pagos por ${money(total)} y todas las deudas volverán a 0.',
                                      action: 'Pagar todo',
                                    );
                                    if (ok && context.mounted) {
                                      await guarded(context, () async {
                                        for (final d in debtors) {
                                          await repo.settle(d.key, app.uid);
                                        }
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.done_all),
                            label: const Text('Pagar todo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HistoryPage(names: {...names, app.uid: 'admin'})),
                            ),
                            icon: const Icon(Icons.history),
                            label: const Text('Historial'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Añade socios en la pestaña Whitelist.')),
                ),
              for (final m in members)
                ListTile(
                  leading: CircleAvatar(child: Text(m.label.characters.first.toUpperCase())),
                  title: Text(m.label),
                  subtitle: Text(m.uid == null ? '${m.email} · aún no ha accedido' : m.email),
                  trailing: Text(
                    money(m.uid == null ? 0 : (tabs[m.uid]?.totalAmount ?? 0)),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: m.uid == null
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Este socio aún no ha iniciado sesión.')),
                          )
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(m.label)),
                                body: TabView(uid: m.uid!, canRemove: true),
                              ),
                            ),
                          ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------- Catálogo

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, repo, null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Product>>(
        stream: repo.products,
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error);
          if (!s.hasData) return loading;
          final list = s.data!;
          if (list.isEmpty) return const Center(child: Text('Catálogo vacío. Pulsa + para añadir productos.'));
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final p in list)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.active ? money(p.price) : '${money(p.price)} · inactivo'),
                  onTap: () => _edit(context, repo, p),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        'Eliminar producto',
                        '¿Eliminar "${p.name}"? Las consumiciones ya registradas se conservan.',
                        action: 'Eliminar',
                      );
                      if (ok && context.mounted) await guarded(context, () => repo.deleteProduct(p.id));
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Repo repo, Product? p) async {
    final name = TextEditingController(text: p?.name ?? '');
    final price = TextEditingController(text: p == null ? '' : p.price.toStringAsFixed(2));
    var active = p?.active ?? true;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(p == null ? 'Nuevo producto' : 'Editar producto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                TextFormField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Precio unitario (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final x = double.tryParse((v ?? '').replaceAll(',', '.'));
                    return (x == null || x < 0) ? 'Precio no válido' : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && context.mounted) {
      await guarded(
        context,
        () => repo.saveProduct(Product(
          id: p?.id ?? '',
          name: name.text.trim(),
          price: round2(double.parse(price.text.replaceAll(',', '.'))),
          active: active,
        )),
      );
    }
  }
}

// -------------------------------------------------------------- Whitelist

class WhitelistPage extends StatelessWidget {
  const WhitelistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, repo),
        child: const Icon(Icons.person_add_alt),
      ),
      body: StreamBuilder<List<Member>>(
        stream: repo.whitelist,
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error);
          if (!s.hasData) return loading;
          final list = s.data!;
          if (list.isEmpty) return const Center(child: Text('Nadie en la whitelist. Pulsa para añadir un socio.'));
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final m in list)
                ListTile(
                  title: Text(m.label),
                  subtitle: Text(m.email),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        'Dar de baja',
                        '${m.email} perderá el acceso a la aplicación. Su consumo actual se conserva.',
                        action: 'Dar de baja',
                      );
                      if (ok && context.mounted) await guarded(context, () => repo.removeMember(m.key));
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context, Repo repo) async {
    final email = TextEditingController();
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alta de socio'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email (cuenta de Google)'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final x = (v ?? '').trim();
                  final valid = RegExp(r'^[^\s@#$\[\]/]+@[^\s@#$\[\]/]+\.[^\s@#$\[\]/]+$').hasMatch(x);
                  return valid ? null : 'Email no válido';
                },
              ),
              TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await guarded(context, () => repo.addMember(email.text, name.text));
    }
  }
}
