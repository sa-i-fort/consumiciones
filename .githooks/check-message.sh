#!/usr/bin/env bash
# Valida la primera línea de un mensaje de commit contra Conventional Commits.
# Uso: check-message.sh "feat(ui): añade botón"   -> exit 0 si es válido, 1 si no.
subject="$1"

# Merges y reverts automáticos de git no se validan.
[[ "$subject" =~ ^(Merge|Revert\ \") ]] && exit 0

re='^(feat|fix|perf|revert|docs|style|refactor|test|build|ci|chore)(\([a-z0-9._/-]+\))?!?: .+'
[[ "$subject" =~ $re ]]
