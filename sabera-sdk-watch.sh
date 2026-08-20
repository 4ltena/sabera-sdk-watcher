#!/usr/bin/env bash
#
# sabera-sdk-watch.sh — sabera-sdk リポジトリを1分おきにポーリングし、
# 更新があれば自動で pull する(macOS / Linux 用)。
#
# 使い方:
#   初回:   ./sabera-sdk-watch.sh /path/to/sabera-sdk
#           (パスを省略すると対話的に尋ねる。以後は設定ファイルへ保存され、
#             次回からは引数なしで前回のパスを自動で使う)
#   以降:   ./sabera-sdk-watch.sh
#   パスの再設定: ./sabera-sdk-watch.sh --set-path /new/path
#
#   フォアグラウンドで動き続ける。止めるには Ctrl-C。
#   バックグラウンドで動かしたい場合は
#     nohup ./sabera-sdk-watch.sh > /dev/null 2>&1 &
#   か、macOS では launchd(LaunchAgent)に登録する。
#
# 安全のための方針:
#   - 変更するのはこのスクリプト自身の設定ファイル($HOME/.config 以下)だけで、
#     sabera-sdk 側の作業ツリーには pull 以外の書き込みを一切行わない。
#   - 取得は git fetch と git pull --ff-only のみ。force pull や reset は
#     行わない。fast-forward できない場合、または作業ツリーに変更がある場合は
#     そのサイクルをスキップしてログに残すだけで、何も変更しない。

set -u

POLL_INTERVAL_SECONDS=60
CONFIG_DIR="${HOME}/.config/sabera-sdk-watcher"
CONFIG_FILE="${CONFIG_DIR}/sdk_path"
LOG_FILE="${CONFIG_DIR}/watch.log"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$line"
    mkdir -p "$CONFIG_DIR"
    echo "$line" >>"$LOG_FILE"
}

usage() {
    echo "使い方: $0 [/path/to/sabera-sdk]"
    echo "        $0 --set-path /path/to/sabera-sdk"
}

save_path() {
    mkdir -p "$CONFIG_DIR"
    printf '%s' "$1" >"$CONFIG_FILE"
}

load_path() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    fi
}

validate_repo() {
    local path="$1"
    if [ ! -d "$path" ]; then
        echo "エラー: ディレクトリが存在しません: $path" >&2
        return 1
    fi
    if ! git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "エラー: git リポジトリではありません: $path" >&2
        return 1
    fi
    return 0
}

SDK_PATH=""

if [ "${1:-}" = "--set-path" ]; then
    if [ -z "${2:-}" ]; then
        usage
        exit 1
    fi
    SDK_PATH="$2"
    if ! validate_repo "$SDK_PATH"; then
        exit 1
    fi
    save_path "$SDK_PATH"
    echo "保存しました: $SDK_PATH"
    exit 0
elif [ -n "${1:-}" ]; then
    SDK_PATH="$1"
    if ! validate_repo "$SDK_PATH"; then
        exit 1
    fi
    save_path "$SDK_PATH"
else
    SDK_PATH="$(load_path)"
    if [ -z "$SDK_PATH" ]; then
        while true; do
            printf 'sabera-sdk フォルダの場所を入力してください: '
            read -r SDK_PATH
            if [ -z "$SDK_PATH" ]; then
                echo "入力が空です。中断します。" >&2
                exit 1
            fi
            if validate_repo "$SDK_PATH"; then
                break
            fi
            echo "もう一度入力してください。"
        done
        save_path "$SDK_PATH"
    elif ! validate_repo "$SDK_PATH"; then
        echo "保存済みのパスが無効です。$0 --set-path /path/to/sabera-sdk で設定し直してください。" >&2
        exit 1
    fi
fi

log "監視を開始します: ${SDK_PATH} (${POLL_INTERVAL_SECONDS}秒おき)"

while true; do
    if ! git -C "$SDK_PATH" fetch --quiet 2>>"$LOG_FILE"; then
        log "fetch に失敗しました。ネットワークを確認してください"
    else
        if [ -n "$(git -C "$SDK_PATH" status --porcelain 2>/dev/null)" ]; then
            log "作業ツリーに変更があるため、今回の pull をスキップしました"
        else
            LOCAL="$(git -C "$SDK_PATH" rev-parse @ 2>/dev/null)"
            REMOTE="$(git -C "$SDK_PATH" rev-parse '@{u}' 2>/dev/null)"
            if [ -z "$LOCAL" ] || [ -z "$REMOTE" ]; then
                log "ブランチの追跡状態を確認できませんでした(upstream 未設定の可能性)"
            elif [ "$LOCAL" != "$REMOTE" ]; then
                if git -C "$SDK_PATH" pull --ff-only --quiet 2>>"$LOG_FILE"; then
                    NEW="$(git -C "$SDK_PATH" rev-parse --short HEAD 2>/dev/null)"
                    log "更新を取り込みました: $NEW"
                else
                    log "fast-forward できませんでした。手動での確認が必要です"
                fi
            fi
        fi
    fi
    sleep "$POLL_INTERVAL_SECONDS"
done
