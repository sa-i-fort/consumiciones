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

Como `firebase_options.dart` no está en claro en el repo, el workflow lo descifra con git-secret (ver [Seguridad de los secrets](#seguridad-de-los-secrets-git-secret)).

## Build y publicación Android (Google Play)

El workflow `.github/workflows/android-release.yml` compila el AAB (para Play) y el APK, y los sube como artefacto de la ejecución. Se lanza al subir un tag `v*` o a mano desde Actions. Con un tag `v*`, o marcando `publish` al lanzarlo a mano, el job `publish` sube el AAB a la pista **interna** de Google Play.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

- El `versionCode` es el nº de ejecución del workflow (`--build-number=${{ github.run_number }}`), así que siempre crece, como exige Play.
- La release se firma con `android/key.properties` si existe (en CI lo genera el workflow desde los secrets). Sin ese fichero, en local se firma con la clave de debug.
- No hace falta `google-services.json`: la config de Firebase va en `firebase_options.dart`. Está ignorado por git por si `flutterfire configure` lo genera.

### Secrets de GitHub Actions

Se guardan como **environment secrets** del environment `production` (Settings → Environments → production). Ver [Seguridad de los secrets](#seguridad-de-los-secrets-git-secret).

| Secret | Contenido | Usado en |
|---|---|---|
| `GPG_PRIVATE_KEY` | Clave privada GPG de CI en base64 (descifra `firebase_options.dart` y `google-services.json`) | Web y Android |
| `ANDROID_KEYSTORE_BASE64` | El `.jks` codificado en base64 | Android |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del keystore | Android |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave | Android |
| `ANDROID_KEY_ALIAS` | Alias de la clave (p. ej. `upload`) | Android |
| `PLAY_SERVICE_ACCOUNT_JSON` | JSON completo de la cuenta de servicio de Play | Publicación |

Crear el keystore (guárdalo **fuera del repo** y haz copia de seguridad; si lo pierdes no podrás actualizar la app):

```powershell
keytool -genkeypair -v -keystore $HOME\upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Copiar al portapapeles el keystore en base64 (para `ANDROID_KEYSTORE_BASE64`):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
```

Cuenta de servicio de Play: créala en Google Cloud, descarga su clave JSON e invita su email en Play Console → Usuarios y permisos con permiso de **publicar versiones** en la app. Pega el JSON completo en `PLAY_SERVICE_ACCOUNT_JSON`.

### Antes de la primera publicación automática

- **La primera versión se sube a mano.** Play exige crear la app (`com.saifort.consumiciones`) y hacer la primera subida desde la consola; a partir de ahí la API ya puede publicar.
- **SHA-1 en Firebase.** Google Sign-In necesita el SHA-1 de la firma. Añade el de tu keystore de subida (`keytool -list -v -keystore $HOME\upload-keystore.jks -alias upload`) y, si usas Play App Signing, también el del certificado de firma de la app (Play Console → Integridad de la app). Sin esto el login falla en la app instalada desde Play.

## Seguridad de los secrets (git-secret)

El repo es público, así que `lib/firebase_options.dart` y `android/app/google-services.json` **nunca** se commitean en claro (están en `.gitignore`). Se versionan sus copias cifradas con [git-secret](https://git-secret.io) (`*.secret`) y solo pueden abrirlas las claves GPG registradas:

| Clave | Dónde vive | Para qué |
|---|---|---|
| Personal (`damarur92@gmail.com`, con contraseña) | Tu keyring local | Descifrar y recifrar en tu máquina |
| CI (`ci@saifort.local`, sin contraseña) | Secret `GPG_PRIVATE_KEY` de GitHub | Descifrar en Actions |

Quién tiene acceso en cada momento: `git secret whoknows`.

### Uso diario (Git Bash)

```bash
git secret reveal      # descifra los ficheros reales (pide tu contraseña GPG)
# ...editas lib/firebase_options.dart si hace falta...
git secret hide        # vuelve a cifrar -> commitea los *.secret
```

Si cambias un fichero secreto, ejecuta `git secret hide` y commitea los `.secret` actualizados; si no, CI descifrará la versión antigua. Añadir otro fichero: `git secret add <fichero>` y `git secret hide`.

### Dar o quitar acceso a alguien

```bash
gpg --import clave-publica-de-la-persona.asc
git secret tell su@email.com      # dar acceso
git secret killperson su@email.com # quitar acceso
git secret hide -d                # recifra (-d borra los .secret antiguos) y commitea
```

Quitar a alguien **no invalida** lo que ya pudo descifrar ni las versiones antiguas del historial: si esa persona se lleva la config, regenera la apiKey de Firebase (restringida por dominio/paquete) y vuelve a cifrar.

### Configurar GitHub (una vez)

1. Settings → Environments → **New environment** → `production`.
2. *Deployment branches and tags* → **Selected branches and tags** → `main` y el patrón de tag `v*`. Solo esas refs podrán leer los secrets.
3. (Opcional) *Required reviewers* → tú, para aprobar cada despliegue. Pide un clic por push a `main`; déjalo vacío si trabajas solo.
4. Crea ahí el *Environment secret* `GPG_PRIVATE_KEY` con la clave privada de CI en base64. Con la CLI de GitHub:
   ```bash
   gh secret set GPG_PRIVATE_KEY --env production < ~/saifort-ci-gpg-private.b64
   ```
   Sin CLI: pega el contenido del fichero en Settings → Environments → production → *Add environment secret*.
5. Borra `~/saifort-ci-gpg-private.b64` en cuanto lo hayas subido; desde GitHub no se puede volver a leer. Si se pierde, genera otra clave de CI, ejecuta `git secret tell` con la nueva, `killperson` con la antigua y `git secret hide`.
6. Protege `main` (Settings → Rules: exigir PR, bloquear force-push) y mantén cerrados los colaboradores con permiso de escritura: quien pueda cambiar un workflow podría hacerle imprimir la clave de CI.

Los workflows usan la acción `.github/actions/reveal-secrets`, que instala git-secret v0.5.0 (fijado por commit), importa `GPG_PRIVATE_KEY` y ejecuta `git secret reveal`.

## Notas de diseño

- Whitelist indexada por email en minúsculas con `.` → `,` (p. ej. `socio@email,com`), así las reglas pueden comprobar el acceso sin conocer el uid.
- El **owner** es `damarur92@gmail.com` (email verificado), fijado en `database.rules.json`. Es el único que puede nombrar o revertir admins (pestaña Whitelist → icono de escudo).
- Los admins promovidos se guardan en `admins/<email-clave>` y tienen los mismos poderes de gestión que el owner, pero solo mientras sigan en la whitelist. No pueden nombrar admins ni tocar la entrada de otro admin. Cambiar de rol requiere que el usuario vuelva a abrir la app.
- Al cambiar `database.rules.json` hay que volver a desplegarlo (`firebase deploy --only database`).
- Solo los admins pueden borrar pagos del historial; borrar un pago no modifica ninguna deuda.
- Cada vez que un socio abre la app se guarda `lastLogin` en su entrada de la whitelist (visible para el admin). El nombre de un socio se puede editar siempre; su email solo antes de que acceda por primera vez, porque es la clave de la entrada y el enlace con su consumo.

- Al añadir una consumición, el precio unitario de la línea se fija al precio actual del catálogo.
- Los socios pueden sumar y restar unidades de su propio consumo (por si se equivocan); solo el admin gestiona el de otros socios.
- Un socio aparece con su deuda en el panel de admin cuando ya ha iniciado sesión al menos una vez (necesitamos su `uid`).

## Iconos

El icono de la app y el favicon son la cerveza del login (`Icons.sports_bar`, naranja `#D84315`). Para regenerarlos:

```bash
flutter test tool/generate_icons_test.dart   # renderiza assets/icon/*.png
dart run flutter_launcher_icons              # genera Android (adaptive) y web
```
