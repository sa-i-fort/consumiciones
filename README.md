# Sa i Fort · Gestor de Consumiciones

App Flutter (Android + Web) con Firebase Realtime Database y autenticación con Google. Ver [CLAUDE.md](CLAUDE.md) para el contexto funcional.

## Puesta en marcha

1. Instala Flutter (estable) y, si no los tienes, `firebase-tools` y `flutterfire_cli`.
2. Genera las carpetas de plataforma (el código de `lib/` ya está escrito):
   ```bash
   flutter create . --project-name consumiciones --org com.saifort --platforms android,web
   flutter pub get
   ```
3. Crea el proyecto en Firebase y activa:
   - **Authentication → Google** como proveedor.
   - **Realtime Database** (plan gratuito).
4. Conecta la app (sobrescribe `lib/firebase_options.dart`):
   ```bash
   flutterfire configure
   ```
5. Publica las reglas de seguridad:
   ```bash
   firebase deploy --only database
   ```
6. (Opcional) Escribe `config/admin_email` en la consola de Firebase con `damarur92@gmail.com`.
7. Android: añade la huella **SHA-1** de tu keystore en la configuración de la app Android en Firebase (necesario para Google Sign-In).
8. Web: en Authentication → Settings → Dominios autorizados, añade `<usuario>.github.io`.

```bash
flutter run -d chrome   # web
flutter run             # android
```

## Despliegue web (GitHub Pages)

En el repo: Settings → Pages → Source: **GitHub Actions**. Cada push a `main` ejecuta `.github/workflows/deploy-web.yml` (requiere haber commiteado la carpeta `web/`).

## Notas de diseño

- Whitelist indexada por email en minúsculas con `.` → `,` (p. ej. `socio@email,com`), así las reglas pueden comprobar el acceso sin conocer el uid.
- El administrador es `damarur92@gmail.com` (email verificado), fijado en `database.rules.json`.
- Al añadir una consumición, el precio unitario de la línea se fija al precio actual del catálogo.
- Los socios solo pueden sumar unidades; restar y gestionar a otros socios es exclusivo del admin.
- Un socio aparece con su deuda en el panel de admin cuando ya ha iniciado sesión al menos una vez (necesitamos su `uid`).
