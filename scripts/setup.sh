#!/usr/bin/env bash
set -euo pipefail

# —— 0. 必須トークンチェック ——————————
: "${VERCEL_TOKEN:?❌ Need to set VERCEL_TOKEN}"
: "${GH_TOKEN:?❌ Need to set GH_TOKEN}"

# —— プロジェクト名／チームスコープ設定 ——————————
PROJECT_NAME="$(basename "$PWD")"
# Team slug → ご自分のチームスコープ(以前は --team で渡していた値)
SCOPE="shos-projects-04e8fb17"

echo "📦 Setup for \`$PROJECT_NAME\` …"

# —— 1. Vercel プロジェクトを確保 ——————————
if ! vercel projects ls --token "$VERCEL_TOKEN" | grep -q "^$PROJECT_NAME "; then
  vercel projects add "$PROJECT_NAME" \
    --scope "$SCOPE" \
    --token "$VERCEL_TOKEN"
fi

# —— 2. Deploy Hook の自動生成（初回のみ） ——————————
HOOK_URL=$(vercel deploy-hooks ls "$PROJECT_NAME" \
  --scope "$SCOPE" \
  --token "$VERCEL_TOKEN" \
  --format json \
  | jq -r '.[0].url')

if [[ -z "$HOOK_URL" || "$HOOK_URL" == "null" ]]; then
  HOOK_URL=$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
    --scope "$SCOPE" \
    --token "$VERCEL_TOKEN" \
    --format json \
    | jq -r '.url')
  echo "🔓 Deploy Hook created: $HOOK_URL"
else
  echo "✅ Deploy Hook exists: $HOOK_URL"
fi

# —— 3. GitHub Webhook を自動登録（初回のみ） ——————————
GH_API="https://api.github.com"
REPO=$(git config --get remote.origin.url \
  | sed -E 's|.*github\.com[:/](.*)\.git|\1|')

if ! curl -s -H "Authorization: token $GH_TOKEN" \
    "$GH_API/repos/$REPO/hooks" \
    | jq -e --arg url "$HOOK_URL" '.[] | select(.config.url == $url)'; then

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
    }' \
    "$GH_API/repos/$REPO/hooks" \
    >/dev/null

  echo "✅ GitHub Webhook added"
else
  echo "✅ GitHub Webhook exists"
fi

# —— 4. 初回デプロイ ——————————
vercel deploy --prod --token "$VERCEL_TOKEN"
echo "🎉 Setup finished! https://$PROJECT_NAME.vercel.app"
