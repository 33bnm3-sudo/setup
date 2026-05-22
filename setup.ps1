Write-Host "=== 환경 설치 시작 ===" -ForegroundColor Cyan
$temp = $env:TEMP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# VS Code
Write-Host "[1/5] VS Code 다운로드 중..." -ForegroundColor Yellow
Invoke-WebRequest "https://update.code.visualstudio.com/latest/win32-x64/stable" -OutFile "$temp\vscode.exe"
Start-Process "$temp\vscode.exe" -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait

# Git
Write-Host "[2/5] Git 다운로드 중..." -ForegroundColor Yellow
$gitRelease = Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest"
$gitUrl = ($gitRelease.assets | Where-Object { $_.name -like "*64-bit.exe" }).browser_download_url
Invoke-WebRequest $gitUrl -OutFile "$temp\git.exe"
Start-Process "$temp\git.exe" -ArgumentList "/VERYSILENT /NORESTART" -Wait

# Node.js LTS
Write-Host "[3/5] Node.js 다운로드 중..." -ForegroundColor Yellow
$nodeIndex = Invoke-RestMethod "https://nodejs.org/dist/index.json"
$nodeVer = ($nodeIndex | Where-Object { $_.lts -is [string] } | Select-Object -First 1).version
Invoke-WebRequest "https://nodejs.org/dist/$nodeVer/node-$nodeVer-x64.msi" -OutFile "$temp\node.msi"
Start-Process msiexec.exe -ArgumentList "/i `"$temp\node.msi`" /quiet /norestart" -Wait

# Plasticity
Write-Host "[4/5] Plasticity 다운로드 중..." -ForegroundColor Yellow
Invoke-WebRequest "https://github.com/nkallen/plasticity/releases/download/v26.1.3/Plasticity.msi" -OutFile "$temp\plasticity.msi"
Start-Process msiexec.exe -ArgumentList "/i `"$temp\plasticity.msi`" /quiet /norestart" -Wait

# Claude Code
Write-Host "[5/5] Claude Code 설치 중..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
npm install -g @anthropic-ai/claude-code

# 캡스락 한영키
Write-Host "캡스락 한영키 설정 중..." -ForegroundColor Yellow
$ahkDir = "$env:USERPROFILE\ahk-portable"
New-Item -ItemType Directory -Force -Path $ahkDir | Out-Null
Invoke-WebRequest "https://www.autohotkey.com/download/ahk.zip" -OutFile "$temp\ahk.zip"
Expand-Archive "$temp\ahk.zip" -DestinationPath $ahkDir -Force
@"
#NoEnv
#SingleInstance Force
CapsLock::vk15
"@ | Out-File "$ahkDir\hangul.ahk" -Encoding UTF8
Copy-Item "$ahkDir\hangul.ahk" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hangul.ahk" -Force
Start-Process "$ahkDir\AutoHotkeyU64.exe" "$ahkDir\hangul.ahk"

Write-Host "=== 완료! ===" -ForegroundColor Green