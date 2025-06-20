# Shichifuku Monorepo Scaffold 🚀

このリポジトリは **新規サブプロジェクトを 2 分で公開** できる  
テンプレートです。Fork / Use this template して ↓ 手順を実行するだけ。

---

## 使い方

```bash
# 1. テンプレートを複製したら…
git clone git@github.com:<your-account>/<your-project>.git
cd <your-project>

# 2. 必要なトークンを環境変数にセット
export VERCEL_TOKEN="***"          # Personal Token (Vercel > Account > Tokens)
export GH_TOKEN="***"              # GitHub PAT (repo + admin:repo_hook)

# 3. 初期セットアップ & 初回デプロイ
bash scripts/setup.sh
