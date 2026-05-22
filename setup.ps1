Write-Host "=== 환경 설치 시작 ===" -ForegroundColor Cyan
$temp = $env:TEMP
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# URL 미리 가져오기
Write-Host "다운로드 URL 확인 중..." -ForegroundColor Gray
$nodeVer = (Invoke-RestMethod "https://nodejs.org/dist/index.json" | Where-Object { $_.lts -is [string] } | Select-Object -First 1).version
$gitUrl  = ((Invoke-RestMethod "https://api.github.com/repos/git-for-windows/git/releases/latest").assets | Where-Object { $_.name -like "*64-bit.exe" }).browser_download_url

# 모든 파일 동시 다운로드
Write-Host "모든 파일 동시 다운로드 중..." -ForegroundColor Yellow
$downloads = @(
    @{ Url = "https://update.code.visualstudio.com/latest/win32-x64/stable";                               Out = "$temp\vscode.exe";     Name = "VS Code"     },
    @{ Url = $gitUrl;                                                                                       Out = "$temp\git.exe";        Name = "Git"         },
    @{ Url = "https://nodejs.org/dist/$nodeVer/node-$nodeVer-x64.msi";                                     Out = "$temp\node.msi";       Name = "Node.js"     },
    @{ Url = "https://github.com/nkallen/plasticity/releases/download/v26.1.3/Plasticity.msi";             Out = "$temp\plasticity.msi"; Name = "Plasticity"  },
    @{ Url = "https://www.autohotkey.com/download/ahk.zip";                                                Out = "$temp\ahk.zip";        Name = "AutoHotkey"  }
)

$jobs = $downloads | ForEach-Object {
    $d = $_
    Start-Job -ScriptBlock {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $using:d.Url -OutFile $using:d.Out
        "$($using:d.Name) 완료"
    }
}

# 완료될 때까지 진행상황 표시
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $done = ($jobs | Where-Object { $_.State -ne 'Running' }).Count
    Write-Host "`r  다운로드 $done / $($jobs.Count) 완료..." -NoNewline
    Start-Sleep -Seconds 1
}
$jobs | Receive-Job | ForEach-Object { Write-Host "  [OK] $_" -ForegroundColor Green }
$jobs | Remove-Job

# 순서대로 설치
Write-Host "`n=== 설치 시작 ===" -ForegroundColor Cyan

Write-Host "[1/5] VS Code 설치 중..." -ForegroundColor Yellow
Start-Process "$temp\vscode.exe" -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode" -Wait

Write-Host "[2/5] Git 설치 중..." -ForegroundColor Yellow
Start-Process "$temp\git.exe" -ArgumentList "/VERYSILENT /NORESTART" -Wait

Write-Host "[3/5] Node.js 설치 중..." -ForegroundColor Yellow
Start-Process msiexec.exe -ArgumentList "/i `"$temp\node.msi`" /quiet /norestart" -Wait

Write-Host "[4/5] Plasticity 설치 중..." -ForegroundColor Yellow
Start-Process msiexec.exe -ArgumentList "/i `"$temp\plasticity.msi`" /quiet /norestart" -Wait

Write-Host "[5/5] Claude Code 설치 중..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
npm install -g @anthropic-ai/claude-code

# 캡스락 한영키
Write-Host "캡스락 한영키 설정 중..." -ForegroundColor Yellow
$ahkDir = "$env:USERPROFILE\ahk-portable"
New-Item -ItemType Directory -Force -Path $ahkDir | Out-Null
Expand-Archive "$temp\ahk.zip" -DestinationPath $ahkDir -Force
@"
#NoEnv
#SingleInstance Force
CapsLock::vk15
"@ | Out-File "$ahkDir\hangul.ahk" -Encoding UTF8
Copy-Item "$ahkDir\hangul.ahk" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\hangul.ahk" -Force
Start-Process "$ahkDir\AutoHotkeyU64.exe" "$ahkDir\hangul.ahk"

Write-Host "=== 완료! ===" -ForegroundColor Green