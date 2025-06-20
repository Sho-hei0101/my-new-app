#!/usr/bin/env bash
set -euo pipefail

### 0. 事前チェック
if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo "❌ VERCEL_TOKEN is missing"
  exit 1
fi
if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "❌ GH_TOKEN is missing"
  exit 1
fi

# プロジェクト名はカレントディレクトリ名から取得
PROJECT_NAME="$(basename "$PWD")"
# 固定のチームスラッグ（必要に応じ書き換え）
TEAM="shos-projects-04e8fb17"

echo "📦 Setup for \`$PROJECT_NAME\` …"

### 1. Vercel プロジェクトを確保（存在しなければ自動作成）
if ! vercel projects ls --token="$VERCEL_TOKEN" | grep -q "^$PROJECT_NAME "; then
  vercel projects add "$PROJECT_NAME" \
    --scope="$TEAM" \
    --token="$VERCEL_TOKEN"
  echo "✅ Vercel project \`$PROJECT_NAME\` created"
fi

### 2. Deploy Hook を自動作成（初回のみ）
HOOK_URL=$(vercel deploy-hooks ls "$PROJECT_NAME" \
  --scope="$TEAM" \
  --token="$VERCEL_TOKEN" | jq -r '.[0].url')

if [[ -z "$HOOK_URL" || "$HOOK_URL" == "null" ]]; then
  HOOK_URL=$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
    --scope="$TEAM" \
    --token="$VERCEL_TOKEN" | jq -r '.url')
  echo "✅ Deploy Hook created"
else
  echo "✅ Deploy Hook exists"
fi

### 3. GitHub Webhook を自動登録（初回のみ）
GH_API="https://api.github.com"
REPO=$(git config --get remote.origin.url \
  | sed -E 's|.*[:/](.+)\.git|\1|')

EXISTS=$(curl -s -H "Authorization: token $GH_TOKEN" \
    "$GH_API/repos/$REPO/hooks" \
  | jq '.[] | select(.config.url=="'"$HOOK_URL"'")')

if [[ -z "$EXISTS" || "$EXISTS" == "null" ]]; then
  curl -s -X POST -H "Authorization: token $GH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "web",
      "active": true,
      "events": ["push"],
      "config": {
        "url": "'"$HOOK_URL"'",
        "content_type": "json"
      }
    }' "$GH_API/repos/$REPO/hooks" >/dev/null
  echo "✅ GitHub Webhook added"
else
  echo "✅ GitHub Webhook exists"
fi

### 4. 初回デプロイ
 ### 4. 初回デプロイ
- vercel deploy . --prod --yes --token="$VERCEL_TOKEN"
+ vercel deploy --prod --confirm --token="$VERCEL_TOKEN"
 echo "🎉 Setup finished! https://$PROJECT_NAME.$TEAM.vercel.app"
