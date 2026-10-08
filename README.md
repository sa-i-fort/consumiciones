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

### Versionado automático y releases

Con **cada push a `main`**, el workflow `.github/workflows/android-release.yml` mira los commits desde el último tag `vX.Y.Z` y decide la versión según [Conventional Commits](https://www.conventionalcommits.org/es/) (lo calcula `tool/next_version.sh`):

| Tipo de commit | Efecto | Ejemplo |
|---|---|---|
| `feat:` | sube **minor** (1.0.1 → 1.1.0) | `feat(whitelist): permite editar el email` |
| `fix:` · `perf:` · `revert:` | sube **patch** (1.0.0 → 1.0.1) | `fix(ui): corrige el borde del botón` |
| `tipo!:` o pie `BREAKING CHANGE:` | sube **major** (1.4.2 → 2.0.0) | `feat!: cambia el modelo de datos` |
| `docs` · `style` · `refactor` · `test` · `build` · `ci` · `chore` | **no publica nada** | `docs: actualiza el README` |

Si entre dos tags hay varios commits, manda el cambio más grande. Si ninguno es publicable, el run termina en verde sin compilar ni publicar. Un commit sin formato convencional no rompe nada: se ignora y el run lo señala con un aviso.

Si hay versión nueva, el workflow:

1. **Compila** el AAB firmado (descifra la config con git-secret, prepara el keystore, `flutter analyze`).
2. **Publica** en Google Play (pista `internal`), con las novedades sacadas de los commits.
3. **Solo si Play acepta la versión**, crea el tag `vX.Y.Z` sobre ese commit y una release en GitHub con las notas. Si algo falla antes, no queda ningún tag huérfano y la siguiente ejecución recalcula el mismo número.

- **`versionName`** es la versión calculada; **`versionCode`** es el nº de ejecución del workflow (siempre creciente, como exige Play, y mayor que el de la primera versión subida a mano). La `version` de `pubspec.yaml` solo cuenta en builds locales.
- **Notas de Play:** hasta 6 líneas de 80 caracteres, con las descripciones de los commits `feat`/`fix`/`perf`. Conviene redactarlos pensando en quien lee la ficha de la tienda.
- **Estado en Play:** por defecto la release queda como **borrador** (Play lo exige mientras la app no tenga ninguna versión publicada) y hay que darle a *Lanzar* en la consola. Cuando ya tenga una versión publicada, crea la **variable** de repositorio `PLAY_RELEASE_STATUS = completed` (Settings → Secrets and variables → Actions → Variables) para que se publique sola.
- **Ejecución manual:** Actions → *Release Android* → *Run workflow*. Sin marcar `publish` solo compila y deja el `.aab` como artefacto (30 días); marcándolo, publica en la pista elegida.
- **Una release a la vez:** si entra otro push mientras corre una, espera y calcula la versión sobre el tag recién creado.

#### Configuración inicial (una sola vez)

1. **Tag base.** Hace falta un tag `vX.Y.Z` sobre el commit de la versión que ya está en Play, para contar desde ahí. Sin él, el workflow avisa y no publica. Con la 1.0.0 subida a mano (commit `3234141`):
   ```bash
   git tag v1.0.0 3234141
   git push origin v1.0.0
   ```
   El siguiente `fix:` publicará la **1.0.1**.
2. **Activa el hook local** que rechaza commits sin formato (una vez por clon):
   ```bash
   git config core.hooksPath .githooks
   ```
   Los pull requests también se validan en `.github/workflows/ci.yml`.
3. **La primera versión de la app se sube a mano** en Play Console; la API no puede crear la app.

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

## Actualización automática de dependencias (Renovate)

[Renovate](https://docs.renovatebot.com) abre pull requests para actualizar las dependencias; su configuración está en `renovate.json`.

**Para activarlo (una vez):** instala la [app de Renovate](https://github.com/apps/renovate) en GitHub (gratis para repos públicos) y dale acceso solo a este repositorio. No hace falta ningún token.

- **Qué vigila:** paquetes de `pubspec.yaml` (y `pubspec.lock`, que ahora se versiona para que los builds sean reproducibles), las Actions de los workflows (las fija por commit, porque manejan la clave de firma) y Gradle/plugin de Android.
- **Cuándo:** todos los días antes de las 9:00 (Madrid), con un máximo de 5 PRs abiertos y esperando 3 días desde la publicación de cada versión (protege de versiones recién publicadas con problemas). Las actualizaciones minor/patch de las dependencias de la app van juntas en **un solo PR** ("dependencias de la app"), así que como mucho hay una release diaria.
- **Fusión automática** (solo si el CI pasa: `flutter analyze` y compilación debug, en `.github/workflows/ci.yml`): únicamente para actualizaciones **minor y patch de paquetes pub**. Quedan **con revisión manual** los *major*, Gradle/plugin de Android y las Actions de GitHub.

Sus commits siguen Conventional Commits, y eso decide si fusionarlos publica una versión en Play:

| Qué actualiza | Commit | ¿Publica versión al fusionar? |
|---|---|---|
| Dependencias de la app (`dependencies`) | `fix(deps): …` | Sí, **patch** |
| Dependencias de desarrollo | `chore(deps): …` | No |
| Actions de GitHub | `ci(deps): …` | No |
| Gradle / plugin de Android | `build(deps): …` | No |

Una actualización fusionada con `fix(deps)` publica una release sin que nadie la revise, y el CI solo comprueba que compila (no hay tests de comportamiento). Si prefieres que las dependencias no publiquen nada hasta la próxima versión real, cambia `semanticCommitType` de `fix` a `chore` en `renovate.json`.

**Por qué no se fusionan solas las Actions ni los major:** las Actions se ejecutan con tus secrets (clave de firma, cuenta de Play) al fusionar a `main`, así que una versión comprometida sería lo más grave que podría colarse; y un major puede compilar pero cambiar el comportamiento (Firebase Auth o Database, por ejemplo). Para ampliar la fusión automática, añade `"automerge": true` a la regla correspondiente de `renovate.json`.

**Opcional, para que la espera del CI sea a prueba de fallos:** en Settings → Rules crea un ruleset sobre `main` que exija los checks `check` y `commits`, y **añade tu usuario a la lista de bypass** para poder seguir haciendo push directo. Con "Allow auto-merge" activado en Settings → General, Renovate usará entonces la fusión automática de GitHub, que espera a los checks obligatorios.

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
2. *Deployment branches and tags* → **Selected branches and tags** → solo la rama `main`. Cualquier workflow lanzado desde otra rama o desde un fork no podrá leer los secrets.
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
