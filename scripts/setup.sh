#!/usr/bin/env bash
set -euo pipefail

### 0. 事前チェック
[[ -z "${VERCEL_TOKEN:-}" ]] && { echo "❌ VERCEL_TOKEN が設定されていません"; exit 1; }
[[ -z "${GH_TOKEN:-}"    ]] && { echo "❌ GH_TOKEN が設定されていません";    exit 1; }

PROJECT_NAME=$(basename "$PWD")          # カレントディレクトリ名をプロジェクト名に
TEAM="shos-projects-04e8fb17"            # Vercel チームスラッグ

echo "📦 Setup for \`$PROJECT_NAME\` …"

### 1. Vercel プロジェクトを確保（なければ作る）
if ! vercel projects ls --token "$VERCEL_TOKEN" \
     | grep -q "^$PROJECT_NAME\s"; then
  vercel projects add "$PROJECT_NAME" \
    --team  "$TEAM" \
    --token "$VERCEL_TOKEN" \
    --confirm
fi

### 2. Deploy Hook を自動作成（初回のみ）
HOOK_URL=$(vercel deploy-hooks ls "$PROJECT_NAME" \
    --team  "$TEAM" \
    --token "$VERCEL_TOKEN" \
  | jq -r '.[0].url')

if [[ -z "$HOOK_URL" || "$HOOK_URL" == "null" ]]; then
  HOOK_URL=$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
      --team  "$TEAM" \
      --token "$VERCEL_TOKEN" \
    | jq -r '.url')
  echo "🔗 Deploy Hook created: $HOOK_URL"
fi

### 3. GitHub Webhook を自動登録（初回のみ）
GH_API="https://api.github.com"
REPO=$(git config --get remote.origin.url \
  | sed -E 's|.*github\.com[:/](.*)\.git|\1|')

if ! curl -s -H "Authorization: token $GH_TOKEN" \
     "$GH_API/repos/$REPO/hooks" \
   | jq -e --arg url "$HOOK_URL" \
       '.[] | .config.url == $url' \
     >/dev/null; then
  curl -s -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name":   "web",
      "active": true,
      "events": ["push"],
      "config": {
        "url":          "'"$HOOK_URL"'",
        "content_type": "json"
      }
    }' \
    "$GH_API/repos/$REPO/hooks" >/dev/null
  echo "✅ GitHub Webhook added"
fi

### 4. 初回デプロイ
# 「.」を指定して確実に１パスだけ渡す
vercel deploy --prod \
  --token "$VERCEL_TOKEN" \
  --scope "$TEAM"

echo "🎉 Setup finished! https://$PROJECT_NAME.vercel.app"
