# Rayvy

<img src="Resources/AppIcon-1024.png" width="128" alt="Rayvy icon" />

macOS向けの軽量ランチャー。`⌥Space` → Command Palette → アプリ / Clipboard History / システム操作。

## 概要

Rayvyは常駐型(Dock・メニューバーなし)の小さなmacOSアプリで、次の1本のフローだけを軸にしている。

```text
Global Hotkey → Command Palette → Apps / Clipboard History / System Commands
```

意図的に小さく保っている — 高度なfuzzy searchも、GUI設定画面も、プラグインも、Cloud Syncもない。
詳しい設計と明示的なスコープ外一覧は [`SPEC.md`](SPEC.md) を参照。

## インストール

[mise](https://mise.jdx.dev) 経由:

```bash
cp mise.example.toml mise.toml   # または [bootstrap.packages] の項目だけ自分のmise.tomlにマージ
mise bootstrap
```

または [Releases](https://github.com/Mkamono/rayvy/releases) から `Rayvy-<version>-arm64.zip` をダウンロードし、
解凍して `Rayvy.app` を `/Applications` に移動する。

Rayvy.appはad-hoc署名(notarizeなし)のため、初回起動時にGatekeeperにブロックされる。
[トラブルシューティング](#トラブルシューティング)を参照。

Rayvy自身にはログイン時自動起動の仕組みは無い。必要なら `mise.example.toml` の
`[bootstrap.macos.launchd.agents.rayvy]` を有効にすると、mise側でLaunchAgentとして登録できる。

同様に `[dotfiles]` の `"~/.config/rayvy/config.toml" = { mode = "track" }` を有効にすると、
`config.toml` の変更履歴を `mise dot` (`mise dot save`/`mise dot history`など) で追跡できる。

## 使い方

ランチャーのホットキー(デフォルト `⌥Space`)でCommand Paletteを開く。アプリ・System Commands・Clipboard
Historyをまとめて検索できる(fuzzyではない単純な文字列一致)。矢印キーとReturnで選択、Escapeで閉じる。

⌘Kのヒントが出ている項目(アプリ、Clipboard Historyの各項目)は `⌘K` でアクションメニューを開ける(Quit、
Reveal in Finder、Copy Bundle ID、Assign Hotkey…など)。

パレットが開いている間は、日本語IME等が検索の邪魔をしないよう自動的にRoman/アルファベット入力に切り替わり、
閉じると元の入力ソースに戻る。

## 設定

設定は単一のTOMLファイルにまとまっており、初回起動時にデフォルト値で作成される。

```text
~/.config/rayvy/config.toml
```

保存すると再起動なしでHot Reloadされる。例:

```toml
[launcher]
hotkey = "option+space"

[clipboard]
enabled = true
max_items = 100
excluded_bundle_ids = []
hotkey = "cmd+shift+v"

[[hotkeys]]
key = "option+t"
bundle_id = "com.mitchellh.ghostty"
```

Hotkeyの文字列は修飾キー(`cmd`/`command`、`option`/`alt`、`shift`、`control`/`ctrl`)とキーを `+` で
つなげる(例: `"cmd+shift+t"`)。不正な値にすると、以前の割り当てをそのまま残さず解除する。

## Direct Hotkeys

`[[hotkeys]]` の各エントリは、パレットを開かずにbundle ID指定でアプリへ直接グローバルショートカットを割り当
てる。押すと、未起動なら起動、バックグラウンドなら前面化、既にフォアグラウンドなら隠す、という動作になる。

設定方法は2通り:

- **アプリ内から**: Command Paletteでアプリを選択し `⌘K` → 「Assign Hotkey…」(既に設定済みなら
  「Change Hotkey…」)を選び、割り当てたいキーを押す。これはRayvyが`config.toml`に書き込む唯一の設定項目。
- **手動で**: `config.toml` に `[[hotkeys]]` エントリを自分で追加する。bundle IDはアプリの `⌘K` →
  「Copy Bundle ID」で取得できる。

## Clipboard History

Rayvyはシステムのペーストボードを監視し、重複排除済みの履歴をメモリ上に保持する(テキストのみ、
`~/Library/Application Support/Rayvy/clipboard.json` に永続化)。専用ホットキー(デフォルト
`cmd+shift+v`)でClipboard History専用のパレット表示に直接ジャンプでき、項目を選ぶと再コピーした上で
直前までフォアグラウンドだったアプリへペーストする。

`[clipboard]` で設定可能: `enabled`、`max_items`、`excluded_bundle_ids`(これらのアプリがフォアグラウンド
の間のコピーは無視する — パスワードマネージャーなど)、`hotkey`。

ペーストにはAccessibility権限が必要([トラブルシューティング](#トラブルシューティング)参照)。権限が無く
ても項目自体はペーストボードに残るので、手動での `⌘V` は可能。

## System Commands

パレットの「Commands」セクションから: Sleep、Restart、Shut Down、Quit All Applications、
Quit `<起動中のアプリ>`(起動中アプリごと)、Open Rayvy Settings(`config.toml`を開く)、
Rayvy Docs(このREADMEをGitHubで開く)、Quit Rayvy。

## トラブルシューティング

**初回起動時にGatekeeperにブロックされる**(「"Rayvy.app"は壊れているため開けません」など) —
Rayvy.appはad-hoc署名でnotarizeされていないため。Finderでアプリを右クリックして「開く」を選ぶか、
quarantine属性を外す:

```bash
xattr -d com.apple.quarantine /Applications/Rayvy.app
```

**Accessibility権限を許可したのにClipboard Historyがペーストできない** — 権限チェックはRayvyの起動時にしか
再評価されない。System Settings → プライバシーとセキュリティ → アクセシビリティで許可した後、Rayvyを
再起動する。

**`config.toml`を編集したらHotkeyが効かなくなった** — Hotkeyの文字列にtypoがないか確認する。認識できない
修飾キーやキーを指定すると、以前の値を残さずその場でバインドが解除される(上記「設定」参照)。
