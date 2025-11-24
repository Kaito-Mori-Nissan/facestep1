#!/usr/bin/env bash
set -euo pipefail

PROJECTS_FILE="${PROJECTS_FILE:-.github/projects_file.json}"
CHANGED_FILES_RULES="${CHANGED_FILES_RULES:-changed-files.yml}"

# 出力ファイルを空にする
: > "$CHANGED_FILES_RULES"

# include 配列内の project_id 一覧を取得
mapfile -t project_ids < <(jq -r '.include[].project_id' "$PROJECTS_FILE")

if ((${#project_ids[@]} == 0)); then
  echo "No projects (project_id) found in $PROJECTS_FILE" >&2
  exit 1
fi

for pid in "${project_ids[@]}"; do
  echo "$pid:" >> "$CHANGED_FILES_RULES"

  # project_id が pid の要素の FILES_CHANGED_TRIGGER を列挙
  # FILES_CHANGED_TRIGGER が無い / null の場合は空配列扱い
  jq -r --arg pid "$pid" '
    .include[]
    | select(.project_id == $pid)
    | (.FILES_CHANGED_TRIGGER // [])
    | .[]
  ' "$STRUCTURE_FILE" | while IFS= read -r pattern; do
      echo "  - \"$pattern\"" >> "$CHANGED_FILES_RULES"
    done
done

# デバッグ用に生成結果を表示
cat "$CHANGED_FILES_RULES"