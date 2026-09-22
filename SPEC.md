# Rayvy

macOS向けの軽量ランチャー。

Raycastのような多機能プラットフォームではなく、日常的に必要なOS操作だけを高速に呼び出せる小さな常駐アプリを目指す。

## 目的

* アプリを素早く検索・起動する
* グローバルショートカットから直接アプリを起動する
* Clipboard Historyを利用する
* 起動中アプリやシステム操作を素早く実行する
* 設定・同期・配布周辺をRayvy自身で抱え込まない

## 対象

* macOS専用
* Apple Siliconを主対象
* 実装言語はSwiftのみ

## 主要機能

### Command Palette

グローバルホットキーからRayvyを表示する。

例:

```text
⌥ Space
```

検索対象:

* インストール済みアプリ
* Rayvyのシステムコマンド
* Clipboard History

検索は高度なfuzzy searchではなく、単純な文字列一致を基本とする。

### Application Launcher

macOSにインストールされているアプリを取得し、一覧・検索・起動する。

主に `NSWorkspace` を利用する。

### Direct Hotkeys

設定ファイルから、

```text
⌥T → Terminal
⌥B → Browser
```

のようなグローバルショートカットを登録できる。

Command Paletteを開かず直接アプリを起動できる。

### Application Management

* 指定アプリを終了
* 起動中アプリを一覧表示
* アプリの一括終了

Rayvy自身や必要なシステムプロセスは対象外とする。

### System Actions

以下をCommand Paletteから実行可能にする。

* Sleep
* Restart
* Shutdown

### Clipboard History

初期実装ではテキストのみ対応する。

機能:

* Clipboard変更監視
* 履歴保存
* 履歴検索
* 選択した項目の再コピー
* 重複排除
* 最大保持件数
* 必要に応じて特定アプリを除外

画像・ファイル等のClipboard対応は初期スコープ外。

## 常駐方式

Rayvyはログイン後バックグラウンドで常駐する。

通常は、

* Dockに表示しない
* メニューバーアイコンも表示しない

グローバルホットキーが押されたときだけCommand Paletteを表示する。

macOSのAgent Appとして構成する。

Rayvy終了用のコマンドはCommand Palette内に用意する。

## 設定

Source of Truthは単一のTOMLファイルとする。

```text
~/.config/rayvy/config.toml
```

例:

```toml
[launcher]
hotkey = "option+space"

[clipboard]
enabled = true
max_items = 100

[[hotkeys]]
key = "option+t"
bundle_id = "com.mitchellh.ghostty"

[[hotkeys]]
key = "option+b"
bundle_id = "com.apple.Safari"
```

設定ファイルの変更は監視し、RayvyへHot Reloadする。

汎用のGUI設定画面は作らない。唯一の例外として、Command PaletteのApp項目で⌘Kから開くアクションメニューに
「Assign Hotkey」を用意し、キー入力を1つ受け取ってDirect Hotkey(`[[hotkeys]]`)をconfig.tomlへ書き戻せるようにする。
それ以外の設定項目(launcher/clipboardのhotkeyや個別の設定値の編集など)はGUIから変更できるようにしない。

## ローカル状態

設定とランタイムデータは分離する。

```text
~/.config/rayvy/
└── config.toml

~/Library/Application Support/Rayvy/
├── clipboard.*
└── cache.*
```

ローカル状態は同期対象にしない。

Clipboard Historyは小規模なため、初期段階ではJSONやplist等の単純な保存方式でよい。

必要になった場合のみSQLite等へ変更する。

## 設定同期

Rayvy自身には同期機能を実装しない。

以下のような外部手段に任せる。

* mise
* dotfiles repository
* Git
* その他ユーザーが選択した同期方法

Rayvyは同期方法を意識しない。

## 配布

GitHub Releasesで `Rayvy.app` を配布する。

想定:

```text
GitHub Releases
      ↓
Rayvy.app
      ↓
mise bootstrap packages
      ↓
/Applications/Rayvy.app
```

mise側で、

* インストール
* バージョン固定
* 更新
* 新しいMacへの環境復元

を管理する。

Rayvy自身には独自Updaterを持たせない。

## Rayvy Docs

ユーザー向けドキュメントは `README.md` に集約する。複数のDocsページや独自のヘルプUIは持たない。
`SPEC.md` は開発者・Agent向けの内部仕様として残し、ユーザー向けドキュメントとは分離する。

Command Paletteに `Rayvy Docs` コマンドを用意し、選択するとGitHub上のREADMEをブラウザで開く。
初期実装では `main` ブランチのREADMEを参照する。

```text
https://github.com/Mkamono/rayvy#readme
```

Rayvy自身ではブラウザを選択せず、`NSWorkspace.shared.open` でURLを開いてmacOSのデフォルトブラウザに任せる。

```text
Command Palette
      ↓
Rayvy Docs
      ↓
NSWorkspace.open(URL)
      ↓
macOS default browser
      ↓
GitHub README
```

やらないこと:

* 独自Docs画面・内蔵Markdown Viewer
* 複数のDocs Command
* ブラウザ指定
* Docsサイト・Docs用の独自ナビゲーション
* README以外とのドキュメント同期

インストール済みRayvyとドキュメントの内容差異が問題になった場合のみ、現在のアプリバージョンに対応した
tagのREADME(例: `/blob/v0.3.1/README.md`)を開くよう変更する。初期段階では不要。

## 実装構成

Swiftのみで実装する。

```text
Rayvy
├── App
│   ├── AppLifecycle
│   └── WindowController
├── Palette
│   ├── PaletteView
│   ├── Search
│   └── Command
├── Applications
│   ├── AppIndex
│   └── AppLauncher
├── Hotkeys
│   └── HotkeyManager
├── Clipboard
│   ├── ClipboardMonitor
│   └── ClipboardHistory
├── Config
│   ├── Config
│   ├── ConfigLoader
│   └── ConfigWatcher
└── System
    └── SystemActions
```

利用する主なmacOS API:

* SwiftUI
* AppKit
* Foundation
* `NSWorkspace`
* `NSPasteboard`
* ServiceManagement
* macOS Global Hotkey API

外部依存はできるだけ少なくする。

必要なら、

* TOML parser
* Global Hotkey用の薄いSwift Package

程度に留める。

## CLI

初期実装では不要。

将来的に必要になった場合のみ、

```text
rayvy reload
rayvy open
rayvy quit
```

などのCLIをSwiftで追加する。

GoやRustは導入しない。

GUI・CLIで共通化したい処理が増えた場合は `RayvyCore` のSwift Packageとして切り出す。

## 初期スコープ外

以下は実装しない。

* Shell Command実行
* mise task連携
* 高度なfuzzy search
* Usage Ranking
* 汎用のGUI設定画面(Direct HotkeyのAssign Hotkeyアクションのみ例外)
* 独自Cloud Sync
* 設定Migration
* 設定Schema Versioning
* Extension API
* Extension Store
* AI
* File Search
* Window Management
* Calendar
* Snippets
* Browser integration
* Themes
* Clipboard画像対応
* 独自Auto Update

## 設計方針

Rayvyは機能追加よりも小ささを優先する。

基本構造は、

```text
Global Hotkey
      ↓
Command Palette
      ↓
Apps / Clipboard / System
```

だけに保つ。

設定・同期・配布・バージョン管理など既存ツールで解決できるものはRayvy自身に持たせない。

目標は、

**小さく、高速で、透明性の高いmacOSランチャー。**
