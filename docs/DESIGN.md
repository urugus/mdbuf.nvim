# mdbuf.nvim 実装計画

## 概要

**mdbuf.nvim** - sixel対応ターミナル上のNeovimで、ブラウザ同等品質のマークダウンプレビューをバッファ内に表示するプラグイン。

**名前の由来**: md (markdown) + buf (buffer) = バッファ内でmarkdownを見る

## 要件

| 項目 | 内容 |
|------|------|
| 表示方式 | 垂直分割（左：ソース、右：プレビュー） |
| 更新トリガー | ファイル保存時 |
| 対象 | 長文ドキュメント、埋め込み画像 |
| ターミナル | sixel対応（Ghostty/WezTerm） |

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                    Neovim (Lua)                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │ autocmd     │───▶│ RPC Client  │───▶│ image.nvim  │ │
│  │ BufWritePost│    │ (stdio)     │    │ (sixel)     │ │
│  └─────────────┘    └──────┬──────┘    └─────────────┘ │
└────────────────────────────┼────────────────────────────┘
                             │ JSON-RPC
                             ▼
┌─────────────────────────────────────────────────────────┐
│              Render Server (TypeScript)                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │ markdown    │───▶│ Playwright  │───▶│ PNG Output  │ │
│  │ → HTML      │    │ (常駐)      │    │             │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 技術スタック

| レイヤー | 技術 | 役割 |
|----------|------|------|
| Neovim側 | Lua | プラグイン本体、UI制御 |
| 通信 | JSON-RPC over stdio | Neovim ↔ Server |
| サーバー | TypeScript + Node.js | レンダリング処理 |
| HTML変換 | marked | Markdown → HTML |
| 画像化 | Playwright | HTML → PNG |
| 表示 | image.nvim | PNG → sixel → バッファ |

## 実装フェーズ

### Phase 1: PoC（最小動作確認）

**目標**: パイプライン全体が動作することを確認

#### 1.1 レンダリングサーバー（TypeScript）
- [ ] Node.jsプロジェクト初期化
- [ ] marked でMarkdown → HTML変換
- [ ] Playwright でHTML → PNG変換
- [ ] CLIとして動作確認（`render.ts input.md output.png`）

#### 1.2 Neovimプラグイン（Lua）
- [ ] プラグイン基本構造作成
- [ ] `:MdPreview` コマンド実装
- [ ] 外部プロセス呼び出し（vim.fn.jobstart）
- [ ] image.nvim で画像表示

#### 1.3 統合テスト
- [ ] 保存 → レンダリング → 表示の一連動作確認
- [ ] パフォーマンス計測（目標: 1秒以内）

### Phase 2: 実用化

#### 2.1 サーバー常駐化
- [ ] JSON-RPC サーバー実装
- [ ] Playwright インスタンス再利用
- [ ] ヘルスチェック・自動再起動

#### 2.2 長文対応
- [ ] ビューポート方式レンダリング
  - カーソル位置から表示領域を計算
  - 該当範囲のみHTMLをレンダリング
- [ ] ソース行 ↔ レンダリング位置のマッピング
- [ ] スクロール同期（オプション）

#### 2.3 UX改善
- [ ] プレビューウィンドウ自動管理
- [ ] 画像キャッシュ（変更がない場合は再利用）
- [ ] エラーハンドリング・通知

### Phase 3: 拡張機能

- [ ] カスタムCSS対応
- [ ] シンタックスハイライト（コードブロック）
- [ ] Mermaid図表対応
- [ ] LaTeX数式対応（KaTeX）
- [ ] GitHub Flavored Markdown完全対応

## ディレクトリ構成

```
~/private/mdbuf.nvim/
├── lua/
│   └── mdbuf/
│       ├── init.lua          # プラグインエントリポイント
│       ├── config.lua        # 設定管理
│       ├── render.lua        # レンダリング制御
│       ├── window.lua        # ウィンドウ管理
│       └── rpc.lua           # サーバー通信
├── server/
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts          # エントリポイント
│       ├── rpc.ts            # JSON-RPC ハンドラ
│       ├── renderer.ts       # Playwright制御
│       └── markdown.ts       # Markdown→HTML変換
├── plugin/
│   └── mdbuf.vim             # Vimコマンド定義
├── docs/
│   └── DESIGN.md             # 設計ドキュメント（この計画ファイル）
└── README.md
```

## リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| Playwright起動が遅い | 初回表示に3-5秒 | サーバー常駐化で初回以降は高速 |
| 長文のスクロール同期 | 位置ずれ | ソースマップ生成、段階的改善 |
| image.nvim動的更新 | ちらつき | 画像差し替え方法を検証 |
| sixel非対応環境 | 動作しない | 起動時にチェック、警告表示 |

## 依存関係

**Neovim側:**
- Neovim 0.9+
- image.nvim
- (optional) nvim-treesitter

**サーバー側:**
- Node.js 18+
- playwright
- marked

## 詳細設計

### JSON-RPC プロトコル

**通信方式**: stdio（標準入出力）
- Neovimがサーバープロセスを起動・管理
- 改行区切りのJSON-RPCメッセージ

**メソッド定義:**

```typescript
// サーバー → クライアント応答
interface RenderResponse {
  imagePath: string;      // 生成された画像のパス
  sourceMap: SourceMap;   // 行マッピング情報
  renderTime: number;     // レンダリング時間(ms)
}

interface SourceMap {
  // ソース行番号 → 画像内Y座標(px)
  lineToY: Record<number, number>;
  totalHeight: number;
}

// リクエストメソッド
interface Methods {
  // マークダウンをレンダリング
  "render": {
    params: {
      markdown: string;
      filePath: string;      // 画像参照の解決用
      viewport: {
        width: number;       // レンダリング幅(px)
        startLine?: number;  // ビューポート開始行
        endLine?: number;    // ビューポート終了行
      };
      options?: {
        css?: string;        // カスタムCSS
        theme?: "light" | "dark";
      };
    };
    result: RenderResponse;
  };

  // サーバー状態確認
  "ping": {
    params: {};
    result: { status: "ok"; version: string };
  };

  // サーバー終了
  "shutdown": {
    params: {};
    result: {};
  };
}
```

### データフロー詳細

```
[保存イベント発生]
       │
       ▼
┌──────────────────┐
│ BufWritePost     │
│ autocmd発火      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ バッファ内容取得  │
│ カーソル位置取得  │
│ ウィンドウ幅取得  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│ サーバー起動確認  │────▶│ 未起動なら起動   │
└────────┬─────────┘     └──────────────────┘
         │
         ▼
┌──────────────────┐
│ render RPC送信   │
│ - markdown本文   │
│ - viewport情報   │
└────────┬─────────┘
         │
         ▼ (サーバー側)
┌──────────────────┐
│ Markdown→HTML    │
│ (marked)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ HTML→PNG         │
│ (Playwright)     │
│ + SourceMap生成  │
└────────┬─────────┘
         │
         ▼ (Neovim側)
┌──────────────────┐
│ 画像パス受信     │
│ SourceMap受信    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ image.nvim で    │
│ プレビュー更新   │
└──────────────────┘
```

### Lua モジュール設計

```lua
-- mdbuf/init.lua
local M = {}

M.config = {
  server_cmd = nil,  -- 自動検出
  auto_preview = true,
  split_direction = "vertical",
  split_width_percent = 50,
  theme = "light",
  custom_css = nil,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  -- autocmd登録、コマンド定義
end

function M.open_preview()
  -- プレビューウィンドウを開く
end

function M.close_preview()
  -- プレビューウィンドウを閉じる
end

function M.toggle_preview()
  -- 開閉トグル
end

function M.refresh()
  -- 手動更新
end

return M
```

```lua
-- mdbuf/rpc.lua
local M = {}

local job_id = nil
local request_id = 0
local pending_requests = {}

function M.start_server()
  -- サーバープロセス起動
end

function M.stop_server()
  -- サーバー終了
end

function M.request(method, params, callback)
  -- JSON-RPC リクエスト送信
end

function M.is_running()
  return job_id ~= nil
end

return M
```

```lua
-- mdbuf/window.lua
local M = {}

local preview_win = nil
local preview_buf = nil

function M.create_split()
  -- 垂直分割でプレビューウィンドウ作成
end

function M.update_image(image_path, source_map)
  -- image.nvimで画像更新
end

function M.sync_scroll(source_line, source_map)
  -- スクロール同期
end

function M.close()
  -- ウィンドウ削除
end

return M
```

### TypeScript モジュール設計

```typescript
// server/src/index.ts
import { createRpcServer } from './rpc';
import { Renderer } from './renderer';

async function main() {
  const renderer = new Renderer();
  await renderer.init();

  const server = createRpcServer({
    render: (params) => renderer.render(params),
    ping: () => ({ status: 'ok', version: '0.1.0' }),
    shutdown: () => process.exit(0),
  });

  server.listen(process.stdin, process.stdout);
}
```

```typescript
// server/src/renderer.ts
import { chromium, Browser, Page } from 'playwright';
import { marked } from 'marked';

export class Renderer {
  private browser: Browser | null = null;
  private page: Page | null = null;

  async init() {
    this.browser = await chromium.launch();
    this.page = await this.browser.newPage();
  }

  async render(params: RenderParams): Promise<RenderResponse> {
    const html = this.markdownToHtml(params.markdown);
    const { imagePath, sourceMap } = await this.htmlToImage(html, params);
    return { imagePath, sourceMap, renderTime: /* ... */ };
  }

  private markdownToHtml(markdown: string): string {
    // marked + カスタムrenderer（行番号埋め込み）
  }

  private async htmlToImage(html: string, params: RenderParams) {
    // Playwright screenshot + SourceMap生成
  }
}
```

### SourceMap 生成戦略

HTMLレンダリング時に各要素にdata属性で行番号を埋め込み：

```html
<p data-source-line="1">最初の段落</p>
<h2 data-source-line="3">見出し</h2>
<p data-source-line="5">次の段落</p>
```

スクリーンショット後、JavaScript で各要素の `offsetTop` を取得：

```typescript
const sourceMap = await page.evaluate(() => {
  const elements = document.querySelectorAll('[data-source-line]');
  const lineToY: Record<number, number> = {};
  elements.forEach(el => {
    const line = parseInt(el.getAttribute('data-source-line')!);
    lineToY[line] = (el as HTMLElement).offsetTop;
  });
  return { lineToY, totalHeight: document.body.scrollHeight };
});
```

### 設定オプション

```lua
require('mdbuf').setup({
  -- サーバー設定
  server = {
    cmd = nil,  -- nil=自動検出, or {"node", "path/to/server"}
    timeout = 10000,  -- 起動タイムアウト(ms)
  },

  -- 表示設定
  preview = {
    split = "vertical",  -- "vertical" | "horizontal"
    width = 50,          -- 垂直分割時の幅(%)
    height = 50,         -- 水平分割時の高さ(%)
  },

  -- レンダリング設定
  render = {
    theme = "light",     -- "light" | "dark"
    width = 800,         -- レンダリング幅(px)
    custom_css = nil,    -- カスタムCSSファイルパス
  },

  -- 動作設定
  behavior = {
    auto_open = true,    -- mdファイルで自動オープン
    auto_close = true,   -- ソース閉じたらプレビューも閉じる
    sync_scroll = true,  -- スクロール同期
  },
})
```

## 次のアクション

1. プロジェクトディレクトリ `~/private/mdbuf.nvim/` を作成
2. この設計ドキュメントを `docs/DESIGN.md` としてリポジトリに追加
3. TypeScriptサーバーの基本構造を実装
4. Luaプラグインの基本構造を実装
5. JSON-RPC通信の動作確認
6. レンダリングパイプライン実装
