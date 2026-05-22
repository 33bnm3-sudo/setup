Write-Host "=== 환경 설치 시작 ===" -ForegroundColor Cyan

$apps = @(
    @{ id = "Microsoft.VisualStudioCode"; name = "VS Code" },
    @{ id = "Git.Git";                   name = "Git" },
    @{ id = "Codice.PlasticSCM";         name = "Plastic SCM" },
    @{ id = "OpenJS.NodeJS.LTS";         name = "Node.js" }
)

foreach ($app in $apps) {
    Write-Host "$($app.name) 설치 중..." -ForegroundColor Yellow
    winget install --id $app.id -e --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Claude Code 설치 중..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
npm install -g @anthropic-ai/claude-code

Write-Host "캡스락 한영키 설정 중..." -ForegroundColor Yellow
$ahkDir = "$env:USERPROFILE\ahk-portable"
New-Item -ItemType Directory -Force -Path $ahkDir | Out-Null
Invoke-WebRequest "https://www.autohotkey.com/download/ahk.zip" -OutFile "$env:TEMP\ahk.zip"
Expand-Archive "$env:TEMP\ahk.zip" -DestinationPath $ahkDir -Force
@"
#NoEnv
#SingleInstance Force
CapsLock::vk15
"@ | Out-File "$ahkDir\hangul.ahk" -Encoding UTF8
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hangul.ahk"
Copy-Item "$ahkDir\hangul.ahk" $startupPath -Force
Start-Process "$ahkDir\AutoHotkeyU64.exe" "$ahkDir\hangul.ahk"

Write-Host "=== 완료! ===" -ForegroundColor Green