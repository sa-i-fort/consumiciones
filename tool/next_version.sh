#!/usr/bin/env bash
# Calcula la siguiente versión semántica a partir de los Conventional Commits desde el último tag vX.Y.Z.
#
#   feat:                     -> minor
#   fix: / perf: / revert:    -> patch
#   tipo!: / BREAKING CHANGE  -> major
#   docs, style, refactor, test, build, ci, chore -> no generan versión
#
# Uso: tool/next_version.sh [rev]        (rev por defecto: HEAD)
# Variables opcionales:
#   OUTPUT_FILE    donde escribir previous=, bump=, next= (por defecto stdout; en Actions: $GITHUB_OUTPUT)
#   NOTES_FILE     escribe aquí las notas de la release (Markdown)
#   WHATSNEW_FILE  escribe aquí las novedades para Google Play (máx. 6 líneas de 80 caracteres)
set -euo pipefail
export LC_ALL=C.UTF-8

rev="${1:-HEAD}"
out="${OUTPUT_FILE:-/dev/stdout}"

prev_tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' "$rev" 2>/dev/null || true)"
if [ -z "$prev_tag" ]; then
  echo "::warning::No hay ningún tag vX.Y.Z como base. Crea el de la versión ya publicada (p. ej. v1.0.0) para activar las releases automáticas."
  { echo "previous="; echo "bump=none"; echo "next="; } >> "$out"
  exit 0
fi

re='^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$'
major=0; minor=0; patch=0
breaks=(); feats=(); fixes=(); perfs=()

while IFS= read -r -d '' rec; do
  rec="${rec#$'\n'}"   # git log deja un salto de línea entre registros
  sha="${rec%%$'\x1f'*}"
  rest="${rec#*$'\x1f'}"
  subject="${rest%%$'\x1f'*}"
  body="${rest#*$'\x1f'}"

  if [[ "$subject" =~ $re ]]; then
    type="${BASH_REMATCH[1]}"; scope="${BASH_REMATCH[3]}"; bang="${BASH_REMATCH[4]}"; desc="${BASH_REMATCH[5]}"
    line="$desc"
    [ -n "$scope" ] && line="**$scope:** $desc"

    # Un cambio incompatible solo aparece en su sección, no repetido en Novedades/Correcciones.
    if [ -n "$bang" ] || grep -Eq '^BREAKING[ -]CHANGE(:| )' <<<"$body"; then
      major=1; breaks+=("$line")
      continue
    fi
    case "$type" in
      feat)         minor=1; feats+=("$line") ;;
      fix | revert) patch=1; fixes+=("$line") ;;
      perf)         patch=1; perfs+=("$line") ;;
    esac
  elif [[ ! "$subject" =~ ^(Merge|Revert\ \") ]]; then
    echo "::warning::El commit $sha no sigue Conventional Commits y no cuenta para la versión: $subject"
  fi
done < <(git log --no-merges --format='%h%x1f%s%x1f%b%x00' "$prev_tag..$rev")

IFS=. read -r v_major v_minor v_patch <<<"${prev_tag#v}"

if   [ "$major" = 1 ]; then bump=major; next="$((v_major + 1)).0.0"
elif [ "$minor" = 1 ]; then bump=minor; next="$v_major.$((v_minor + 1)).0"
elif [ "$patch" = 1 ]; then bump=patch; next="$v_major.$v_minor.$((v_patch + 1))"
else bump=none; next=""
fi

{ echo "previous=$prev_tag"; echo "bump=$bump"; echo "next=$next"; } >> "$out"

[ "$bump" = none ] && exit 0

if [ -n "${NOTES_FILE:-}" ]; then
  section() { # título, elementos...
    local title="$1"; shift
    [ "$#" -eq 0 ] && return 0
    printf '### %s\n\n' "$title"
    printf -- '- %s\n' "$@"
    printf '\n'
  }
  {
    section "Cambios incompatibles" "${breaks[@]}"
    section "Novedades" "${feats[@]}"
    section "Correcciones" "${fixes[@]}"
    section "Rendimiento" "${perfs[@]}"
    printf 'Cambios desde %s.\n' "$prev_tag"
  } > "$NOTES_FILE"
fi

if [ -n "${WHATSNEW_FILE:-}" ]; then
  n=0
  : > "$WHATSNEW_FILE"
  for l in "${breaks[@]}" "${feats[@]}" "${fixes[@]}" "${perfs[@]}"; do
    l="${l#\*\*}"; l="${l/:\*\* /: }"      # quita el negrita del ámbito: "**ui:** x" -> "ui: x"
    printf '• %s\n' "${l:0:78}" >> "$WHATSNEW_FILE"
    n=$((n + 1)); [ "$n" -ge 6 ] && break
  done
fi
