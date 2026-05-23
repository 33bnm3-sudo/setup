Write-Host "=== Claude Desktop Google Drive 연동 ===" -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Find-GoogleDrivePath {
    $found = 65..90 | ForEach-Object {
        $root = [char]$_ + ":\"
        if (-not (Test-Path $root)) { return }
        foreach ($name in @("내 드라이브", "My Drive")) {
            if (Test-Path "${root}${name}") { return "${root}${name}" }
        }
    } | Where-Object { $_ } | Select-Object -First 1
    if ($found) { return $found }

    @(
        "$env:USERPROFILE\Google Drive\My Drive",
        "$env:USERPROFILE\Google Drive\내 드라이브",
        "$env:USERPROFILE\My Drive",
        "$env:USERPROFILE\내 드라이브"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$claudeData = "$env:APPDATA\Claude"
$gdPath     = Find-GoogleDrivePath

if (-not $gdPath) {
    Write-Host "Google Drive를 찾을 수 없습니다." -ForegroundColor Yellow
    Write-Host "Google Drive에 로그인 후 Enter를 누르세요..." -ForegroundColor Yellow
    Read-Host
    $gdPath = Find-GoogleDrivePath
}

if (-not $gdPath) {
    Write-Host "[!] Google Drive 경로를 찾을 수 없습니다. Google Drive가 실행 중인지 확인하세요." -ForegroundColor Red
    exit 1
}

$gdClaudeConfig = "$gdPath\claude-config"
Write-Host "Google Drive 경로: $gdPath" -ForegroundColor Gray

# 이미 연동됐는지 확인
$existing = Get-Item $claudeData -ErrorAction SilentlyContinue
if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    Write-Host "[v] 이미 Google Drive에 연동되어 있습니다." -ForegroundColor Green
    Write-Host "    $claudeData -> $gdClaudeConfig" -ForegroundColor Gray
    exit 0
}

# Google Drive에 claude-config 폴더 생성
if (-not (Test-Path $gdClaudeConfig)) {
    New-Item -ItemType Directory -Force -Path $gdClaudeConfig | Out-Null
    Write-Host "[OK] Google Drive에 claude-config 폴더 생성됨" -ForegroundColor Green
} else {
    Write-Host "[v] Google Drive에 claude-config 폴더 이미 있음" -ForegroundColor Green
}

# 기존 로컬 설정 있으면 Google Drive로 이동
if (Test-Path $claudeData) {
    Write-Host "기존 설정을 Google Drive로 이동 중..." -ForegroundColor Yellow
    Copy-Item "$claudeData\*" $gdClaudeConfig -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $claudeData -Recurse -Force
}

# 심볼릭 링크 생성
New-Item -ItemType SymbolicLink -Path $claudeData -Target $gdClaudeConfig | Out-Null
Write-Host "[OK] 연동 완료!" -ForegroundColor Green
Write-Host "     $claudeData" -ForegroundColor Gray
Write-Host "     -> $gdClaudeConfig" -ForegroundColor Gray
Write-Host "`nClaude Desktop을 재시작하면 적용됩니다." -ForegroundColor Cyan
