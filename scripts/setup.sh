#!/usr/bin/env bash
set -euo pipefail

# ── 0. 必要な環境変数チェック
: "${VERCEL_TOKEN:?ERROR: VERCEL_TOKEN を設定してください}"
: "${GH_TOKEN:?ERROR: GH_TOKEN を設定してください}"

PROJECT_NAME=$(basename "$PWD")    # 現在のディレクトリ名をプロジェクト名に
TEAM="shos-projects-04e8fb17"      # 固定の Team / scope

echo "📦 Setup for '${PROJECT_NAME}' …"

# ── 1. Vercel プロジェクトの存在確認／新規作成
if ! vercel projects ls --token "$VERCEL_TOKEN" --scope "$TEAM" \
   | awk '{print $1}' | grep -qx "$PROJECT_NAME"; then
  vercel projects add "$PROJECT_NAME" \
    --token "$VERCEL_TOKEN" \
    --scope "$TEAM"
fi

# ── 2. Deploy Hook の自動作成（初回のみ）
HOOK_URL=$(vercel deploy-hooks ls "$PROJECT_NAME" \
  --team "$TEAM" --token "$VERCEL_TOKEN" --json \
  | jq -r '.[0].url // empty')

if [ -z "$HOOK_URL" ]; then
  HOOK_URL=$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
    --team "$TEAM" --token "$VERCEL_TOKEN" --json \
    | jq -r '.[0].url')
  echo "🔗 Deploy Hook created: $HOOK_URL"
else
  echo "✅ Deploy Hook exists: $HOOK_URL"
fi

# ── 3. GitHub Webhook の自動登録（初回のみ）
#    リポジトリ情報を origin.url から動的に取得
REPO=$(git config --get remote.origin.url \
  | sed -E 's#.*[:/](.+/[^/.]+)(\.git)?#\1#')
GH_API="https://api.github.com"

if ! curl -s -H "Authorization: token $GH_TOKEN" \
       "$GH_API/repos/$REPO/hooks" \
    | jq -e --arg url "$HOOK_URL" '.[] | select(.config.url==$url)' \
    > /dev/null; then

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
    && echo "✅ GitHub Webhook added"
else
  echo "✅ GitHub Webhook already exists"
fi

# ── 4. 初回プロダクションデプロイ
vercel deploy --prod --token "$VERCEL_TOKEN" --scope "$TEAM"
echo "🎉 Setup finished! https://${PROJECT_NAME}.vercel.app"
