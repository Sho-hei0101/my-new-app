#!/usr/bin/env bash
set -euo pipefail

# ─── 0. 事前チェック ─────────────────────────────────────────
: "${VERCEL_TOKEN:?❌ VERCEL_TOKEN is missing}"
: "${GH_TOKEN:?❌ GH_TOKEN is missing}"

PROJECT_NAME="$(basename "$PWD")"    # カレントディレクトリ名をプロジェクト名に
TEAM="shos-projects-04e8fb17"       # Vercel のチーム／スコープ名

echo "📦 Setup for \`$PROJECT_NAME\` …"

# ─── 1. Vercel プロジェクトを確保 ─────────────────────────────
if ! vercel projects ls --token "$VERCEL_TOKEN" | grep -qw "$PROJECT_NAME"; then
  vercel projects add "$PROJECT_NAME" \
    --scope "$TEAM" \
    --token "$VERCEL_TOKEN"
  echo "✅ Vercel project created"
else
  echo "✅ Vercel project exists"
fi

# ─── 2. Deploy Hook を自動作成 (初回のみ) ────────────────────────
HOOK_URL="$(vercel deploy-hooks ls "$PROJECT_NAME" --token "$VERCEL_TOKEN" | awk 'NR==1{print $2}')"
if [[ -z "$HOOK_URL" ]]; then
  HOOK_URL="$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
    --scope "$TEAM" \
    --token "$VERCEL_TOKEN")"
  echo "🔗 Deploy Hook created: $HOOK_URL"
else
  echo "✅ Deploy Hook exists: $HOOK_URL"
fi

# ─── 3. GitHub Webhook を自動登録 (初回のみ) ───────────────────────
GH_API="https://api.github.com"
# repo URL を https://api.github.com/repos/USER/REPO に変換
REPO_RAW="$(git config --get remote.origin.url | sed -E 's#.*github.com[:/](.*)\.git#\1#')"
API_REPO="$GH_API/repos/$REPO_RAW"
# 既存フックをチェック
if ! curl -s -H "Authorization: token $GH_TOKEN" "$API_REPO/hooks" \
    | jq -e '.[] | select(.config.url=="'"$HOOK_URL"'")' >/dev/null; then

  curl -s -X POST "$API_REPO/hooks" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "web",
      "active": true,
      "events": ["push"],
      "config": {
        "url": "'"$HOOK_URL"'",
        "content_type": "json"
      }
    }'
  echo "✅ GitHub Webhook added"
else
  echo "✅ GitHub Webhook exists"
fi

# ─── 4. 初回デプロイ ─────────────────────────────────────────
vercel --prod \
  --scope "$TEAM" \
  --token "$VERCEL_TOKEN"

echo "🎉 Setup finished! https://$PROJECT_NAME.vercel.app"
