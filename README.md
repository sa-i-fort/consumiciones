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
4. Conecta la app. `lib/firebase_options.dart` **no se sube a git** (está en `.gitignore`); la plantilla es `lib/firebase_options.dart.example`:
   ```bash
   flutterfire configure
   ```
   (o copia el `.example` a `lib/firebase_options.dart` y rellena los valores a mano).
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

Como `firebase_options.dart` no está en el repo, el workflow lo genera desde un secret: en Settings → Secrets and variables → Actions crea `FIREBASE_OPTIONS_DART` con el **contenido completo** de tu `lib/firebase_options.dart` local.

## Build y publicación Android (Google Play)

El workflow `.github/workflows/android-release.yml` compila el AAB (para Play) y el APK, y los sube como artefacto de la ejecución. Se lanza al subir un tag `v*` o a mano desde Actions. Con un tag `v*`, o marcando `publish` al lanzarlo a mano, el job `publish` sube el AAB a la pista **interna** de Google Play.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

- El `versionCode` es el nº de ejecución del workflow (`--build-number=${{ github.run_number }}`), así que siempre crece, como exige Play.
- La release se firma con `android/key.properties` si existe (en CI lo genera el workflow desde los secrets). Sin ese fichero, en local se firma con la clave de debug.
- No hace falta `google-services.json`: la config de Firebase va en `firebase_options.dart`. Está ignorado por git por si `flutterfire configure` lo genera.

### Secrets de GitHub Actions

En Settings → Secrets and variables → Actions → **New repository secret** (deben ser secrets de repositorio, no de environment):

| Secret | Contenido | Usado en |
|---|---|---|
| `FIREBASE_OPTIONS_DART` | Contenido completo de `lib/firebase_options.dart` | Web y Android |
| `ANDROID_KEYSTORE_BASE64` | El `.jks` codificado en base64 | Android |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore | Android |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave | Android |
| `ANDROID_KEY_ALIAS` | Alias de la clave (p. ej. `upload`) | Android |
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON completo de la cuenta de servicio de Play | Publicación |

Crear el keystore (guárdalo **fuera del repo** y haz copia de seguridad; si lo pierdes no podrás actualizar la app):

```powershell
keytool -genkeypair -v -keystore $HOME\upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Copiar al portapapeles el keystore en base64 (para `ANDROID_KEYSTORE_BASE64`) y el Dart (para `FIREBASE_OPTIONS_DART`):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
Get-Content lib\firebase_options.dart -Raw | Set-Clipboard
```

Cuenta de servicio de Play: créala en Google Cloud, descarga su clave JSON e invita su email en Play Console → Usuarios y permisos con permiso de **publicar versiones** en la app. Pega el JSON completo en `PLAY_SERVICE_ACCOUNT_JSON`.

### Antes de la primera publicación automática

- **La primera versión se sube a mano.** Play exige crear la app (`com.saifort.consumiciones`) y hacer la primera subida desde la consola; a partir de ahí la API ya puede publicar.
- **SHA-1 en Firebase.** Google Sign-In necesita el SHA-1 de la firma. Añade el de tu keystore de subida (`keytool -list -v -keystore $HOME\upload-keystore.jks -alias upload`) y, si usas Play App Signing, también el del certificado de firma de la app (Play Console → Integridad de la app). Sin esto el login falla en la app instalada desde Play.

## Notas de diseño

- Whitelist indexada por email en minúsculas con `.` → `,` (p. ej. `socio@email,com`), así las reglas pueden comprobar el acceso sin conocer el uid.
- El administrador es `damarur92@gmail.com` (email verificado), fijado en `database.rules.json`.
- Al añadir una consumición, el precio unitario de la línea se fija al precio actual del catálogo.
- Los socios solo pueden sumar unidades; restar y gestionar a otros socios es exclusivo del admin.
- Un socio aparece con su deuda en el panel de admin cuando ya ha iniciado sesión al menos una vez (necesitamos su `uid`).
