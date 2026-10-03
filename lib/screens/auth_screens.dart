import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_bar, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('Sa i Fort', style: Theme.of(context).textTheme.headlineMedium),
                const Text('Gestor de consumiciones'),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: app.signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar con Google'),
                ),
                if (app.error != null) ...[
                  const SizedBox(height: 16),
                  Text(app.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeniedScreen extends StatelessWidget {
  const DeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 16),
                Text('Acceso restringido', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  app.error ?? '${app.email} no está en la lista de socios. Pide al administrador que te dé de alta.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: app.signOut, child: const Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
