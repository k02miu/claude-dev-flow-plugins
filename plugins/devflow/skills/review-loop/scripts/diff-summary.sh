#!/usr/bin/env bash
# diff-summary.sh — ブランチの変更差分から CHANGED_FILES / DIFF_SUMMARY を標準出力に出す
#
# 対象: コミット済み差分（ベースブランチとのマージベースから HEAD まで）+ 未コミット差分（staged / unstaged / untracked）
#
# Usage:
#   bash diff-summary.sh [BASE_BRANCH]
#
#   BASE_BRANCH: 省略時は origin/HEAD から自動検出
#                （フォールバック: origin/main → origin/master → main → master）
set -euo pipefail

# 出力パスをリポジトリルート相対に統一する（git diff はルート相対、ls-files は cwd 相対のため）
cd "$(git rev-parse --show-toplevel)"

base="${1:-}"

# ベースブランチの自動検出
if [[ -z "$base" ]]; then
  base="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
fi
if [[ -z "$base" ]]; then
  for cand in origin/main origin/master main master; do
    if git rev-parse --verify --quiet "$cand" >/dev/null 2>&1; then
      base="$cand"
      break
    fi
  done
fi
if [[ -z "$base" ]]; then
  echo "ERROR: ベースブランチを自動検出できませんでした。引数で指定してください: bash diff-summary.sh <base-branch>" >&2
  exit 1
fi

merge_base="$(git merge-base "$base" HEAD)"

echo "## BASE_BRANCH"
echo "${base} (merge-base: ${merge_base})"
echo

echo "## CHANGED_FILES"
{
  # コミット済み（マージベースから HEAD）
  git diff --name-only "${merge_base}" HEAD
  # 未コミット（staged + unstaged）
  git diff --name-only --cached
  git diff --name-only
  # 未追跡ファイル
  git ls-files --others --exclude-standard
} | sort -u
echo

echo "## DIFF_SUMMARY"
echo
echo "### コミット済み（merge-base から HEAD）"
git diff --stat "${merge_base}" HEAD
echo
echo "### 未コミット（staged）"
git diff --stat --cached
echo
echo "### 未コミット（unstaged）"
git diff --stat
echo
echo "### 未追跡ファイル"
git ls-files --others --exclude-standard
