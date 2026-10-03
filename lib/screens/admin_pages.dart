import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../repo.dart';
import 'common.dart';
import 'history_page.dart';
import 'tab_view.dart';

// ---------------------------------------------------------------- Socios

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final Stream<List<Member>> _members = context.read<Repo>().whitelist();
  late final Stream<Map<String, ConsumptionTab>> _tabs = context.read<Repo>().allTabs();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final app = context.read<AppState>();

    return StreamBuilder<List<Member>>(
      stream: _members,
      builder: (context, ms) => StreamBuilder<Map<String, ConsumptionTab>>(
        stream: _tabs,
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        money(m.uid == null ? 0 : (tabs[m.uid]?.totalAmount ?? 0)),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: 'Marcar como pagado',
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: (tabs[m.uid]?.totalAmount ?? 0) > 0
                            ? () async {
                                final amount = tabs[m.uid]!.totalAmount;
                                final ok = await confirm(
                                  context,
                                  'Marcar como pagado',
                                  '${m.label}: se registrará un pago de ${money(amount)} y su deuda volverá a 0.',
                                  action: 'Pagado',
                                );
                                if (ok && context.mounted) {
                                  await guarded(context, () => repo.settle(m.uid!, app.uid));
                                }
                              }
                            : null,
                      ),
                    ],
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
                                body: TabView(uid: m.uid!),
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

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final Stream<List<Product>> _products = context.read<Repo>().products();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, repo, null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
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

class WhitelistPage extends StatefulWidget {
  const WhitelistPage({super.key});

  @override
  State<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends State<WhitelistPage> {
  late final Stream<List<Member>> _members = context.read<Repo>().whitelist();
  late final Stream<Set<String>> _admins = context.read<Repo>().admins();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repo>();
    final isOwner = context.read<AppState>().isOwner;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, repo),
        child: const Icon(Icons.person_add_alt),
      ),
      body: StreamBuilder<List<Member>>(
        stream: _members,
        builder: (context, s) => StreamBuilder<Set<String>>(
          stream: _admins,
          builder: (context, a) {
            if (s.hasError || a.hasError) return ErrorBox(s.error ?? a.error);
            if (!s.hasData || !a.hasData) return loading;
            final list = s.data!;
            final admins = a.data!;
            if (list.isEmpty) return const Center(child: Text('Nadie en la whitelist. Pulsa para añadir un socio.'));
            return ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final m in list)
                  ListTile(
                    title: Row(
                      children: [
                        Flexible(child: Text(m.label, overflow: TextOverflow.ellipsis)),
                        if (admins.contains(m.key)) ...[
                          const SizedBox(width: 8),
                          const Chip(
                            label: Text('Admin'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(m.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Solo el owner nombra o revierte admins.
                        if (isOwner)
                          IconButton(
                            tooltip: admins.contains(m.key) ? 'Quitar admin' : 'Hacer admin',
                            icon: Icon(
                              admins.contains(m.key) ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined,
                            ),
                            onPressed: () async {
                              final makeAdmin = !admins.contains(m.key);
                              final ok = await confirm(
                                context,
                                makeAdmin ? 'Hacer administrador' : 'Quitar administrador',
                                makeAdmin
                                    ? '${m.label} podrá gestionar catálogo, socios, deudas e historial.'
                                    : '${m.label} volverá a ser un socio normal.',
                                action: makeAdmin ? 'Hacer admin' : 'Quitar admin',
                              );
                              if (ok && context.mounted) await guarded(context, () => repo.setAdmin(m.key, makeAdmin));
                            },
                          ),
                        IconButton(
                          tooltip: 'Dar de baja',
                          icon: const Icon(Icons.person_remove_outlined),
                          // Un admin promovido no puede dar de baja a otro admin (las reglas también lo impiden).
                          onPressed: !isOwner && admins.contains(m.key)
                              ? null
                              : () async {
                                  final ok = await confirm(
                                    context,
                                    'Dar de baja',
                                    '${m.email} perderá el acceso a la aplicación. Su consumo actual se conserva.',
                                    action: 'Dar de baja',
                                  );
                                  if (ok && context.mounted) {
                                    await guarded(context, () => repo.removeMember(m.key, clearAdmin: isOwner));
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
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
