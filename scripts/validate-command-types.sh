#!/bin/bash
# Validates that all ~/.claude/commands/*.md have a command-type field
# with value in {diagnostic, mutation, meta}.
# Exit 0 if all pass, 1 if any fail.

COMMANDS_DIR="${HOME}/.claude/commands"
VALID_TYPES=("diagnostic" "mutation" "meta")
errors=0
total=0

shopt -s nullglob
files=("${COMMANDS_DIR}"/*.md)

if [ ${#files[@]} -eq 0 ]; then
  echo "No .md files found in ${COMMANDS_DIR}"
  echo "Total: 0 files, 0 errors"
  exit 0
fi

for file in "${files[@]}"; do
  total=$((total+1))
  fname=$(basename "${file}")
  type=$(awk '
    /^---$/ {
      if (count == 0) { count=1; next }
      if (count == 1) { exit }
    }
    count == 1 && /^command-type:[[:space:]]*/ {
      sub(/^command-type:[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print; exit
    }
  ' "${file}")

  if [ -z "${type}" ]; then
    echo "MISS  ${fname}: no command-type field"
    errors=$((errors+1))
    continue
  fi

  if [[ ! " ${VALID_TYPES[*]} " =~ " ${type} " ]]; then
    echo "BAD   ${fname}: invalid value '${type}'"
    errors=$((errors+1))
    continue
  fi

  echo "OK    ${fname}: ${type}"
done

echo ""
echo "Total: ${total} files, ${errors} errors"
[ "${errors}" -eq 0 ] && exit 0 || exit 1
