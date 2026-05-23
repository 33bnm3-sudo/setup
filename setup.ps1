Write-Host "=== 환경 설치 시작 ===" -ForegroundColor Cyan
$temp = $env:TEMP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ── 설치 여부 확인 ─────────────────────────────────────────────
Write-Host "`n── 현재 설치 상태 확인 중... ──" -ForegroundColor Cyan

function Test-Registry($name) {
    [bool](
        Get-ItemProperty `
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
            -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$name*" }
    )
}

$hasVSCode     = (Test-Registry "Visual Studio Code") -or
                 (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or
                 (Test-Path "$env:ProgramFiles\Microsoft VS Code\Code.exe")
$hasGit        = [bool](Get-Command git -ErrorAction SilentlyContinue)
$hasNode       = [bool](Get-Command node -ErrorAction SilentlyContinue)
$hasPlasticity = Test-Registry "Plasticity"
$hasClaudeCode = [bool](Get-Command claude -ErrorAction SilentlyContinue)
$hasGDrive     = (Test-Registry "Google Drive") -or
                 (Test-Path "$env:ProgramFiles\Google\Drive File Stream\GoogleDriveFS.exe") -or
                 (Test-Path "${env:ProgramFiles(x86)}\Google\Drive File Stream\GoogleDriveFS.exe")
$hasAHK        = Test-Path "$env:USERPROFILE\ahk-portable\AutoHotkeyU64.exe"

$installList = @(
    @{ Name = "VS Code";      Has = $hasVSCode     },
    @{ Name = "Git";          Has = $hasGit        },
    @{ Name = "Node.js";      Has = $hasNode       },
    @{ Name = "Plasticity";   Has = $hasPlasticity },
    @{ Name = "Claude Code";  Has = $hasClaudeCode },
    @{ Name = "Google Drive"; Has = $hasGDrive     },
    @{ Name = "캡스락 한영키"; Has = $hasAHK        }
)

$alreadyInstalled = $installList | Where-Object { $_.Has }
$toInstall        = $installList | Where-Object { -not $_.Has }

if ($alreadyInstalled) {
    Write-Host "`n  ── 건너뜀 (이미 설치됨) ──" -ForegroundColor Green
    $alreadyInstalled | ForEach-Object { Write-Host "  [v] $($_.Name)" -ForegroundColor Green }
}
if ($toInstall) {
    Write-Host "`n  ── 새로 설치할 항목 ──" -ForegroundColor Yellow
    $toInstall | ForEach-Object { Write-Host "  [ ] $($_.Name)" -ForegroundColor Yellow }
}
Write-Host ""

# ── 다운로드 목록 구성 ─────────────────────────────────────────
$downloads = @()

if (-not $hasVSCode) {
    $downloads += @{ Url = "https://update.code.visualstudio.com/latest/win32-x64/stable"; Out = "$temp\vscode.exe"; Name = "VS Code" }
}

if (-not $hasGit) {
    Write-Host "`nGit 최신 버전 URL 확인 중..." -ForegroundColor Gray
    try {
        $gitAssets = (Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets
        $gitUrl = ($gitAssets | Where-Object { $_.name -match "^Git-[\d.]+-64-bit\.exe$" } | Select-Object -First 1).browser_download_url
        if ($gitUrl) { $downloads += @{ Url = $gitUrl; Out = "$temp\git.exe"; Name = "Git" } }
        else         { Write-Host "  Git URL을 찾을 수 없습니다." -ForegroundColor Red }
    } catch {
        Write-Host "  Git URL 확인 실패: $_" -ForegroundColor Red
    }
}

if (-not $hasNode) {
    try {
        $nodeVer = (Invoke-RestMethod "https://nodejs.org/dist/index.json" | Where-Object { $_.lts -is [string] } | Select-Object -First 1).version
        $downloads += @{ Url = "https://nodejs.org/dist/$nodeVer/node-$nodeVer-x64.msi"; Out = "$temp\node.msi"; Name = "Node.js" }
    } catch {
        Write-Host "  Node.js URL 확인 실패: $_" -ForegroundColor Red
    }
}

if (-not $hasPlasticity) {
    $downloads += @{ Url = "https://github.com/nkallen/plasticity/releases/download/v26.1.3/Plasticity.msi"; Out = "$temp\plasticity.msi"; Name = "Plasticity" }
}

if (-not $hasGDrive) {
    $downloads += @{ Url = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"; Out = "$temp\gdrive.exe"; Name = "Google Drive" }
}

if (-not $hasAHK) {
    $downloads += @{ Url = "https://www.autohotkey.com/download/ahk.zip"; Out = "$temp\ahk.zip"; Name = "AutoHotkey" }
}

# ── 다운로드 ───────────────────────────────────────────────────
if ($downloads.Count -eq 0) {
    Write-Host "`n모든 프로그램이 이미 설치되어 있습니다!" -ForegroundColor Green
} else {
    Write-Host "`n$($downloads.Count)개 파일 동시 다운로드 중..." -ForegroundColor Yellow
    $jobs = $downloads | ForEach-Object {
        $d = $_
        Start-Job -ScriptBlock {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($using:d.Url, $using:d.Out)
                "[OK] $($using:d.Name) 완료"
            } catch {
                "[실패] $($using:d.Name): $($_.Exception.Message)"
            }
        }
    }
    while ($jobs | Where-Object { $_.State -eq 'Running' }) {
        $done = ($jobs | Where-Object { $_.State -ne 'Running' }).Count
        Write-Host "`r  다운로드 $done / $($jobs.Count) 완료..." -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    $jobs | Receive-Job | ForEach-Object {
        if ($_ -like "[실패]*") { Write-Host "  $_" -ForegroundColor Red }
        else                    { Write-Host "  $_" -ForegroundColor Green }
    }
    $jobs | Remove-Job
}

# ── 설치 ───────────────────────────────────────────────────────
Write-Host "`n=== 설치 시작 ===" -ForegroundColor Cyan
$step = 1

if (-not $hasVSCode) {
    Write-Host "[$step] VS Code 설치 중..." -ForegroundColor Yellow
    Start-Process "$temp\vscode.exe" -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=desktopicon,!runcode" -Wait
    $step++
}

if (-not $hasGit -and (Test-Path "$temp\git.exe")) {
    Write-Host "[$step] Git 설치 중..." -ForegroundColor Yellow
    Start-Process "$temp\git.exe" -ArgumentList "/VERYSILENT /NORESTART" -Wait
    $step++
}

if (-not $hasNode -and (Test-Path "$temp\node.msi")) {
    Write-Host "[$step] Node.js 설치 중..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i `"$temp\node.msi`" /quiet /norestart" -Wait
    $step++
}

if (-not $hasPlasticity) {
    Write-Host "[$step] Plasticity 설치 중..." -ForegroundColor Yellow
    Start-Process msiexec.exe -ArgumentList "/i `"$temp\plasticity.msi`" /quiet /norestart" -Wait
    $step++
}

if (-not $hasGDrive) {
    Write-Host "[$step] Google Drive 설치 중..." -ForegroundColor Yellow
    Start-Process "$temp\gdrive.exe" -ArgumentList "--silent" -Wait
    $step++
}

if (-not $hasClaudeCode) {
    Write-Host "[$step] Claude Code 설치 중..." -ForegroundColor Yellow
    # 방금 설치된 Node.js 포함해서 PATH 갱신
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    # npm 위치 탐색 (PATH 갱신 후에도 못 찾으면 직접 경로 시도)
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $npmCmd) {
        $npmCmd = @(
            "$env:ProgramFiles\nodejs\npm.cmd",
            "$env:ProgramW6432\nodejs\npm.cmd"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if ($npmCmd) {
        & $npmCmd install -g @anthropic-ai/claude-code
    } else {
        Write-Host "  npm을 찾을 수 없습니다. PowerShell 재시작 후 실행하세요: npm install -g @anthropic-ai/claude-code" -ForegroundColor Red
    }
    $step++
}

# ── 캡스락 한영키 ─────────────────────────────────────────────
if (-not $hasAHK) {
    Write-Host "[$step] 캡스락 한영키 설정 중..." -ForegroundColor Yellow
    $ahkDir = "$env:USERPROFILE\ahk-portable"
    New-Item -ItemType Directory -Force -Path $ahkDir | Out-Null
    # 실행 중인 AHK 종료 (파일 잠금 방지)
    Get-Process | Where-Object { $_.Name -like "*AutoHotkey*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Expand-Archive "$temp\ahk.zip" -DestinationPath $ahkDir -Force
    @"
#NoEnv
#SingleInstance Force
CapsLock::vk15
"@ | Out-File "$ahkDir\hangul.ahk" -Encoding UTF8
    Copy-Item "$ahkDir\hangul.ahk" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hangul.ahk" -Force
    Start-Process "$ahkDir\AutoHotkeyU64.exe" "$ahkDir\hangul.ahk"
}

# ── 바탕화면 바로가기 생성 ────────────────────────────────────
Write-Host "`n── 바탕화면 바로가기 확인 중... ──" -ForegroundColor Cyan
$ws      = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath("Desktop")

@(
    @{
        Name   = "Visual Studio Code"
        Target = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "$env:ProgramFiles\Microsoft VS Code\Code.exe"
        )
    },
    @{
        Name   = "Google Drive"
        Target = @(
            "$env:ProgramFiles\Google\Drive File Stream\GoogleDriveFS.exe",
            "${env:ProgramFiles(x86)}\Google\Drive File Stream\GoogleDriveFS.exe"
        )
    }
) | ForEach-Object {
    $lnk = "$desktop\$($_.Name).lnk"
    if (Test-Path $lnk) {
        Write-Host "  [v] $($_.Name) 바로가기 이미 있음" -ForegroundColor Green
        return
    }
    $target = $_.Target | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($target) {
        $sc = $ws.CreateShortcut($lnk)
        $sc.TargetPath = $target
        $sc.Save()
        Write-Host "  [OK] $($_.Name) 바로가기 생성됨" -ForegroundColor Green
    } else {
        Write-Host "  [!] $($_.Name) 실행 파일 없음 (설치 확인 필요)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 완료! ===" -ForegroundColor Green
