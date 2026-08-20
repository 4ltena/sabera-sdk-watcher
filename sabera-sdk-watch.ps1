<#
.SYNOPSIS
    sabera-sdk リポジトリを1分おきにポーリングし、更新があれば自動で pull する（Windows 用）。

.DESCRIPTION
    使い方:
      初回:   .\sabera-sdk-watch.ps1 -SdkPath "C:\path\to\sabera-sdk"
              （省略すると対話的に尋ねる。以後は設定ファイルへ保存され、
                次回からは引数なしで前回のパスを自動で使う）
      以降:   .\sabera-sdk-watch.ps1
      パスの再設定: .\sabera-sdk-watch.ps1 -SetPath "C:\new\path"

      フォアグラウンドで動き続ける。止めるには Ctrl-C。
      バックグラウンドで動かしたい場合はタスクスケジューラに登録するか、
        Start-Process powershell -ArgumentList '-File', '.\sabera-sdk-watch.ps1' -WindowStyle Hidden
      で起動する。

      実行ポリシーでブロックされる場合は、次のいずれかで解除する。
        Unblock-File .\sabera-sdk-watch.ps1
        powershell -ExecutionPolicy Bypass -File .\sabera-sdk-watch.ps1

.NOTES
    安全のための方針:
      - 変更するのはこのスクリプト自身の設定ファイル（%USERPROFILE%\.config 以下）
        だけで、sabera-sdk 側の作業ツリーには pull 以外の書き込みを一切行わない。
      - 取得は git fetch と git pull --ff-only のみ。force pull や reset は
        行わない。fast-forward できない場合、または作業ツリーに変更がある場合は
        そのサイクルをスキップしてログに残すだけで、何も変更しない。
      - git for Windows がインストール済みで、git が PATH 上にあることが前提。
#>

param(
    [string]$SdkPath,
    [string]$SetPath
)

$PollIntervalSeconds = 60
$ConfigDir = Join-Path $env:USERPROFILE ".config\sabera-sdk-watcher"
$ConfigFile = Join-Path $ConfigDir "sdk_path.txt"
$LogFile = Join-Path $ConfigDir "watch.log"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    Add-Content -Path $LogFile -Value $line
}

function Test-Repo {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Write-Error "エラー: ディレクトリが存在しません: $Path"
        return $false
    }
    git -C $Path rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "エラー: git リポジトリではありません: $Path"
        return $false
    }
    return $true
}

function Save-SdkPath {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    Set-Content -Path $ConfigFile -Value $Path -NoNewline
}

function Read-SavedPath {
    if (Test-Path -LiteralPath $ConfigFile) {
        return (Get-Content -Path $ConfigFile -Raw).Trim()
    }
    return $null
}

if ($SetPath) {
    if (-not (Test-Repo -Path $SetPath)) { exit 1 }
    Save-SdkPath -Path $SetPath
    Write-Host "保存しました: $SetPath"
    exit 0
}

if ($SdkPath) {
    if (-not (Test-Repo -Path $SdkPath)) { exit 1 }
    Save-SdkPath -Path $SdkPath
} else {
    $SdkPath = Read-SavedPath
    if (-not $SdkPath) {
        $SdkPath = Read-Host "sabera-sdk フォルダの場所を入力してください"
        if (-not (Test-Repo -Path $SdkPath)) { exit 1 }
        Save-SdkPath -Path $SdkPath
    } elseif (-not (Test-Repo -Path $SdkPath)) {
        Write-Error "保存済みのパスが無効です。.\sabera-sdk-watch.ps1 -SetPath C:\path\to\sabera-sdk で設定し直してください。"
        exit 1
    }
}

Write-Log "監視を開始します: $SdkPath（${PollIntervalSeconds}秒おき）"

while ($true) {
    git -C $SdkPath fetch --quiet 2>> $LogFile
    if ($LASTEXITCODE -ne 0) {
        Write-Log "fetch に失敗しました。ネットワークを確認してください"
    } else {
        $status = git -C $SdkPath status --porcelain
        if ($status) {
            Write-Log "作業ツリーに変更があるため、今回の pull をスキップしました"
        } else {
            $localRev = git -C $SdkPath rev-parse '@' 2>$null
            $remoteRev = git -C $SdkPath rev-parse '@{u}' 2>$null
            if (-not $localRev -or -not $remoteRev) {
                Write-Log "ブランチの追跡状態を確認できませんでした（upstream 未設定の可能性）"
            } elseif ($localRev -ne $remoteRev) {
                git -C $SdkPath pull --ff-only --quiet 2>> $LogFile
                if ($LASTEXITCODE -eq 0) {
                    $newHash = git -C $SdkPath rev-parse --short HEAD
                    Write-Log "更新を取り込みました: $newHash"
                } else {
                    Write-Log "fast-forward できませんでした。手動での確認が必要です"
                }
            }
        }
    }
    Start-Sleep -Seconds $PollIntervalSeconds
}
