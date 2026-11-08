# semantic-agent-schema

JSON Schema で、AI が扱う文書（JSON）の形と意味を決め、検証する道具。実行ファイルは 2 つある。

| 実行ファイル | 使い方 |
|---|---|
| `semantic-agent-schema` | コマンドライン。`create` ・ `update` ・ `validate` ・ `search` ・ `log` ・ `render` |
| `semantic-agent-schema-mcp` | MCP サーバー（stdio）。同じ 6 つをツールとして持つ |

```sh
semantic-agent-schema --version
semantic-agent-schema --help
```

## Claude Code に登録する

導入スクリプトが登録する。手で行うときは次の 1 行である。

```sh
claude mcp add --scope user semantic-agent-schema -- ~/.local/bin/semantic-agent-schema-mcp
```

## Codex に登録する

```sh
codex mcp add semantic-agent-schema -- ~/.local/bin/semantic-agent-schema-mcp
```

Codex は、MCP のツールを呼ぶたびに承認を求める。承認なしで使うには、`~/.codex/config.toml` に次の 1 行を足す。

```toml
[mcp_servers.semantic-agent-schema]
default_tools_approval_mode = "approve"
```

## 対応する環境

| OS | 実行ファイル |
|---|---|
| Linux（x86_64） | 静的リンク（musl）。ライブラリに依存しない |
| macOS | universal2（Intel と Apple シリコン） |
| Windows（x86_64） | VC++ の再頒布パッケージに依存しない |
