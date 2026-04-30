#!/bin/bash
# Validates that all ~/.claude/commands/*.md have a command-type field
# with value in {diagnostic, mutation, meta}.
# Exit 0 if all pass, 1 if any fail.

set -e

COMMANDS_DIR="${HOME}/.claude/commands"
VALID_TYPES=("diagnostic" "mutation" "meta")
errors=0
total=0

for file in "${COMMANDS_DIR}"/*.md; do
  total=$((total+1))
  basename=$(basename "${file}")
  type=$(awk '/^---$/{f=!f; next} f && /^command-type:[[:space:]]*/{
    sub(/^command-type:[[:space:]]*/, ""); print; exit
  }' "${file}")

  if [ -z "${type}" ]; then
    echo "MISS  ${basename}: no command-type field"
    errors=$((errors+1))
    continue
  fi

  if [[ ! " ${VALID_TYPES[*]} " =~ " ${type} " ]]; then
    echo "BAD   ${basename}: invalid value '${type}'"
    errors=$((errors+1))
    continue
  fi

  echo "OK    ${basename}: ${type}"
done

echo ""
echo "Total: ${total} files, ${errors} errors"
[ "${errors}" -eq 0 ] && exit 0 || exit 1
