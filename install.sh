#!/bin/sh
# agents-skills の導入スクリプト（Linux ・ macOS）。
# 使い方: curl -fsSL https://raw.githubusercontent.com/daidaiiro-519/agents-skills/main/install.sh | sh -s -- semantic-agent-schema [版] [--no-setup]
set -eu

OWNER_REPO="${AGENTS_SKILLS_REPO:-daidaiiro-519/agents-skills}"
BASE_URL="${AGENTS_SKILLS_BASE_URL:-https://github.com/$OWNER_REPO/releases/download}"
API_URL="${AGENTS_SKILLS_API_URL:-https://api.github.com/repos/$OWNER_REPO/releases?per_page=50}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

die() { echo "エラー: $*" >&2; exit 1; }

product=""; version=""; setup=1
for arg in "$@"; do
  case "$arg" in
    --no-setup) setup=0 ;;
    -*) die "知らない旗: $arg" ;;
    *) if [ -z "$product" ]; then product="$arg"; else version="$arg"; fi ;;
  esac
done
[ -n "$product" ] || die "導入する名前を指定する（例: semantic-agent-schema）"
[ "$product" = "semantic-agent-schema" ] || die "知らない名前: $product（いま導入できるのは semantic-agent-schema）"

case "$(uname -s)" in
  Linux)
    case "$(uname -m)" in
      x86_64|amd64) target="x86_64-unknown-linux-musl" ;;
      *) die "この CPU（$(uname -m)）の実行ファイルは、まだ無い" ;;
    esac ;;
  Darwin) target="universal2-apple-darwin" ;;
  *) die "このOS（$(uname -s)）では install.sh を使えない。Windows は install.ps1 を使う" ;;
esac

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1"; }
  fetch_to() { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
  fetch_to() { wget -qO "$2" "$1"; }
else
  die "curl か wget が必要"
fi

if [ -z "$version" ]; then
  version="$(fetch "$API_URL" | grep -o "\"tag_name\": *\"$product-v[^\"]*\"" | head -1 | sed "s/.*\"$product-v\([^\"]*\)\"/\1/")" || true
  [ -n "$version" ] || die "$product の公開された版が見つからない"
fi
version="${version#v}"
tag="$product-v$version"
archive="$product-$version-$target.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "取得: $tag（$target）"
fetch_to "$BASE_URL/$tag/$archive" "$tmp/$archive" || die "$archive を取得できない"
fetch_to "$BASE_URL/$tag/SHA256SUMS" "$tmp/SHA256SUMS" || die "SHA256SUMS を取得できない"

expected="$(grep " $archive\$" "$tmp/SHA256SUMS" | awk '{print $1}')"
[ -n "$expected" ] || die "SHA256SUMS に $archive の行が無い"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/$archive" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"
else
  die "sha256sum か shasum が必要"
fi
[ "$expected" = "$actual" ] || die "SHA256 が一致しない（期待 $expected ／ 実際 $actual）。導入を中止する"
echo "SHA256 が一致した"

mkdir -p "$INSTALL_DIR"
tar -xzf "$tmp/$archive" -C "$tmp"
for bin in "$product" "$product-mcp"; do
  [ -f "$tmp/$bin" ] || die "アーカイブに $bin が無い"
  install -m 0755 "$tmp/$bin" "$INSTALL_DIR/$bin"
done
echo "配置: $INSTALL_DIR/$product ・ $INSTALL_DIR/$product-mcp"
"$INSTALL_DIR/$product" --version

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "注意: $INSTALL_DIR が PATH に無い。シェルの設定に次の行を足す:"
     echo "  export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
esac

[ "$setup" = 1 ] || { echo "セットアップは省略した（--no-setup）"; exit 0; }

mcp="$INSTALL_DIR/$product-mcp"
if command -v claude >/dev/null 2>&1; then
  if claude mcp get "$product" >/dev/null 2>&1; then
    echo "Claude Code: $product は登録済み（変更しない）"
  else
    claude mcp add --scope user "$product" -- "$mcp" && echo "Claude Code: $product を登録した（ユーザーの範囲）"
  fi
else
  echo "Claude Code: claude コマンドが無いので登録しない。使うときは: claude mcp add --scope user $product -- $mcp"
fi
if command -v codex >/dev/null 2>&1; then
  if codex mcp get "$product" >/dev/null 2>&1; then
    echo "Codex: $product は登録済み（変更しない）"
  else
    codex mcp add "$product" -- "$mcp" && echo "Codex: $product を登録した"
  fi
  cat <<MSG
Codex は、MCP のツールを呼ぶたびに承認を求める。承認なしで使うには、~/.codex/config.toml の
[mcp_servers.$product] の表に、次の 1 行を足す（この設定は自動では書き換えない）:
  default_tools_approval_mode = "approve"
MSG
else
  echo "Codex: codex コマンドが無いので登録しない。使うときは: codex mcp add $product -- $mcp"
fi
