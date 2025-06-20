#!/usr/bin/env bash
set -euo pipefail

### ─────────────────────────────
### 0. 事前チェック
### ─────────────────────────────
[[ -z "${VERCEL_TOKEN:-}"      ]] && { echo "❌ VERCEL_TOKEN is missing"; exit 1; }
[[ -z "${GH_TOKEN:-}"          ]] && { echo "❌ GH_TOKEN is missing"; exit 1; }

PROJECT_NAME=$(basename "$PWD")      # カレント dir 名 = プロジェクト名
TEAM="shos-projects-04e8fb17"        # Vercel Team Slug（固定で良い）

echo "📦  Setup for \`$PROJECT_NAME\` …"

### ─────────────────────────────
### 1. Vercel プロジェクトを確保
### ─────────────────────────────
if ! vercel projects ls --token "$VERCEL_TOKEN" | grep -q "$PROJECT_NAME"; then
  vercel projects add "$PROJECT_NAME" \
      --framework other \
      --token "$VERCEL_TOKEN" \
      --yes
fi

### ─────────────────────────────
### 2. Deploy Hook を自動作成 (初回のみ)
### ─────────────────────────────
HOOK_URL=$(vercel deploy-hooks ls "$PROJECT_NAME" \
              --team "$TEAM" --token "$VERCEL_TOKEN" --json \
           | jq -r '.[0].url?')

if [[ -z "$HOOK_URL" || "$HOOK_URL" == "null" ]]; then
  HOOK_URL=$(vercel deploy-hooks add "$PROJECT_NAME" github-trigger main \
              --team "$TEAM" --token "$VERCEL_TOKEN" --json \
           | jq -r '.url')
  echo "  🔑  Deploy Hook created"
fi

### ─────────────────────────────
### 3. GitHub Webhook を自動登録 (初回のみ)
### ─────────────────────────────
GH_API="https://api.github.com"
REPO=$(git config --get remote.origin.url | sed -E 's|.*github\.com[/:](.*)\.git|\1|')

# 既存 Webhook 一覧を取得
if ! curl -s -H "Authorization: token $GH_TOKEN" \
           "$GH_API/repos/$REPO/hooks" | jq -e '.[] | select(.config.url=="'"$HOOK_URL"'")' >/dev/null; then
  curl -s -X POST -H "Authorization: token $GH_TOKEN" \
       -H "Content-Type: application/json" \
       -d '{
             "name":"web",
             "active":true,
             "events":["push"],
             "config":{
               "url":"'"$HOOK_URL"'",
               "content_type":"json"
             }
           }' \
       "$GH_API/repos/$REPO/hooks" >/dev/null
  echo "  🔗  GitHub Webhook added"
fi

### ─────────────────────────────
### 4. 初回デプロイ
### ─────────────────────────────
vercel --prod --yes --token "$VERCEL_TOKEN"
echo "🎉  Setup finished! https://$PROJECT_NAME.vercel.app"
