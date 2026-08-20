# Changelog

## [v0.2] - 2026-08-20

- 起動時に発生していた `unbound variable` クラッシュを修正。全角括弧が変数展開に直接隣接していた箇所（`$SDK_PATH（...）` など）を、ファイルの取得経路によっては壊れやすい書き方だったため、全て半角括弧に置き換え、`${VAR}` の明示ブレース化も行った。
- 対話的なパス入力を、無効なパスを入力しても即終了せず、有効なパスが入力されるまで再入力を促すループに変更した。

## [v0.1] - 2026-08-20

- 初版。`sabera-sdk-watch.sh`（macOS / Linux）と `sabera-sdk-watch.ps1`（Windows）を追加。
- `sabera-sdk` リポジトリを60秒おきにポーリングし、更新があれば `git fetch` + `git pull --ff-only` で取り込む。
- 初回起動時に `sabera-sdk` フォルダの場所を設定ファイル（`$HOME/.config/sabera-sdk-watcher/` 以下）へ保存し、以降は自動で使う。
- 作業ツリーに変更がある、または fast-forward できない場合はそのサイクルをスキップしてログに残すだけに留め、force pull・reset・stash は行わない。
