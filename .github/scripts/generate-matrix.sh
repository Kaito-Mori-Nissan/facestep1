#!/usr/bin/env bash
set -euo pipefail

PROJECTS_FILE="${PROJECTS_FILE:-.github/projects_file.json}"

# 対象プロジェクト (project_id) の一覧を決定
targets=()

if [[ "${GITHUB_REF_NAME:-}" =~ ^release ]]; then
  echo "Run release workflow..."
  echo "All projects will be selected as deploy target."

  # include 配列内の全 project_id を取得
  mapfile -t targets < <(jq -r '.include[].project_id' "$PROJECTS_FILE")
else
  # changed-files アクションの出力 (changed_keys) を配列化
  read -r -a targets <<< "${CHANGED_KEYS:-}"

  echo "The following projects will be triggered."
  if ((${#targets[@]} > 0)); then
    printf '  %s\n' "${targets[@]}"
  else
    echo "  (no projects detected from changed files)"
  fi
fi

# マトリクス用 JSON を生成
if ((${#targets[@]} == 0)); then
  json="[]"
else
  tmpfile="$(mktemp)"
  # project_id ごとに {PROJECT_NAME, PROJECT_DIR} を 1行1オブジェクト JSON で出力
  for pid in "${targets[@]}"; do
    jq -r --arg pid "$pid" '
      .include[]
      | select(.project_id == $pid)
      | {PROJECT_NAME, PROJECT_DIR}
    ' "$PROJECTS_FILE" >> "$tmpfile"
  done

  # オブジェクトが1つも出なかった場合も考慮
  if [[ ! -s "$tmpfile" ]]; then
    json="[]"
  else
    json="$(jq -s '.' "$tmpfile")"
  fi

  rm -f "$tmpfile"
fi

echo "Generated matrix JSON:"
echo "$json"

# GitHub Actions のステップ出力へ書き込み
echo "matrix=$json" >> "$GITHUB_OUTPUT"