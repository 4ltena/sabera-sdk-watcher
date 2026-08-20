# sabera-sdk-watcher

`sabera-sdk`（GitHub: jig-SABERA/sabera-sdk）を1分おきにポーリングし、更新があれば自動で `git pull` するだけのツール。開発機に置いた `sabera-sdk` フォルダを、手動で pull し続けなくても最新に保つ。

## 中身

macOS/Linux 用と Windows 用、それぞれ単一ファイルのスクリプト。

- `sabera-sdk-watch.sh`（bash）
- `sabera-sdk-watch.ps1`（PowerShell）

どちらも動きは同じ。設定ファイルとログは `sabera-sdk` のフォルダの外（ホームディレクトリ配下の `.config/sabera-sdk-watcher/`）に置き、リポジトリ自体には何も書き込まない。

## 使い方

### macOS / Linux

```bash
# 初回（パスを渡すとその場で保存される）
./sabera-sdk-watch.sh /path/to/sabera-sdk

# 2回目以降（保存済みのパスを自動で使う）
./sabera-sdk-watch.sh

# パスだけ登録・変更したいとき
./sabera-sdk-watch.sh --set-path /new/path
```

バックグラウンドで動かす場合:

```bash
nohup ./sabera-sdk-watch.sh > /dev/null 2>&1 &
```

macOS で PC 再起動後も自動起動させたい場合は launchd の LaunchAgent に登録する。

### Windows

```powershell
# 初回
.\sabera-sdk-watch.ps1 -SdkPath "C:\path\to\sabera-sdk"

# 2回目以降
.\sabera-sdk-watch.ps1

# パスだけ登録・変更したいとき
.\sabera-sdk-watch.ps1 -SetPath "C:\new\path"
```

実行ポリシーでブロックされる場合:

```powershell
Unblock-File .\sabera-sdk-watch.ps1
# または
powershell -ExecutionPolicy Bypass -File .\sabera-sdk-watch.ps1
```

バックグラウンドで動かしたい場合はタスクスケジューラに登録するか、`Start-Process -WindowStyle Hidden` で起動する。

いずれの OS でも git for Windows / Xcode Command Line Tools 等、`git` コマンドが PATH 上にあることが前提。

## 安全のための方針

- 取得は `git fetch` と `git pull --ff-only` のみ。force pull・reset・stash は一切行わない。
- 作業ツリーに変更がある、または fast-forward できない場合は、そのサイクルをスキップしてログに残すだけで、リポジトリには何も書き込まない。次に自分で `git status` を見て手動で解決する前提。
- ネットワーク障害時も同様にログへ記録して次のサイクルへ進む。プロセスは落ちない。

止めるには Ctrl-C。
