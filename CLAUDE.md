# CLAUDE.md — WezTerm 設定

このリポジトリ（Windows / PowerShell 7）は **Neovim(LazyVim) 設定と密結合**している。
どちらか一方を変更したら、必ずもう一方への影響を確認すること。

## 対になるリポジトリ
- Neovim 設定: `C:\Users\hakuu\AppData\Local\nvim`（GitHub: `kakanzler/neovim`）
- 変更前に相手側の最新挙動/履歴を確認: `git -C C:/Users/hakuu/AppData/Local/nvim log --oneline -10`

## 相互依存（変更時に確認する点）
- **キー競合**: WezTerm のキーは nvim 側マップと衝突しうる。
  - `Ctrl+HJKL` … `split_nav`。nvim 実行中は同キーを nvim へ転送、それ以外はペイン移動
    （nvim 側 `lua/plugins/smart-splits.lua` と対）。
  - 予約済み: `Ctrl+Shift+HJKL`（ペイン移動）/ `Ctrl+Alt+HJKL`（サイズ調整）/ `Ctrl+Shift+R/D/E/W/O/B`。
  - 新規キーを足す前に nvim 側（LazyVim 既定 + `lua/config/keymaps.lua` + 各 plugin の `keys`）と突き合わせる。
- **IS_NVIM ユーザ変数の契約**: `is_nvim(pane)` は nvim が OSC 1337 で立てる `IS_NVIM=true` を最優先で見る
  （フォールバックで前面プロセス名 `n?vim`）。**変数名や判定ロジックを変えたら nvim 側
  `lua/config/autocmds.lua` の送出も直す**。Windows では前面プロセス名判定が外れやすい点に注意。
- **背景透過**: `window_background_opacity` は nvim 側の透過（`transparent = true`）と合わせて見た目が決まる。
  片方だけ変えると崩れる。
- **既定シェル**は `pwsh.exe`。`is_nvim` のプロセス名判定はこのシェル前提。

## 動作確認
- 設定リロード: WezTerm 上で `Ctrl+Shift+R`。設定変更後に必須。
- キー横断（Ctrl+HJKL）や透過は **実 WezTerm でしか最終確認できない**。ユーザーに再現手順を依頼する。
- `is_nvim` などの不具合は WezTerm デバッグオーバーレイ（`Ctrl+Shift+L`）のログで切り分ける。
- 相互影響が疑われる不具合は、両リポジトリの直近コミットを突き合わせて切り分ける。
