# agents-skills

AI エージェント（Claude Code ・ Codex）で使う道具を、実行ファイルで配るリポジトリ。ソースは公開していない。

| 名前 | 何をするか | 導入 |
|---|---|---|
| [semantic-agent-schema](semantic-agent-schema/README.md) | JSON Schema と文書（JSON）を、意味まで検証して AI に渡す | 下の 1 行 |

## 導入

Linux ・ macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/daidaiiro-519/agents-skills/main/install.sh | sh -s -- semantic-agent-schema
```

Windows（PowerShell）:

```powershell
irm https://raw.githubusercontent.com/daidaiiro-519/agents-skills/main/install.ps1 | iex
```

導入スクリプトがすることは、次の 4 つである。

1. OS を判定して、Releases から実行ファイルを取得する
2. `SHA256SUMS` と照合し、一致しなければ中止する
3. 実行ファイルを `~/.local/bin`（Windows は `%LOCALAPPDATA%\agents-skills\bin`）に置く
4. `claude` ・ `codex` コマンドがあれば、MCP サーバーとして登録する

登録を省くときは、`--no-setup`（Windows は `-NoSetup`）を付ける。更新は、同じコマンドをもう一度実行する。

## ライセンス

[LICENSE](LICENSE) を参照する。
