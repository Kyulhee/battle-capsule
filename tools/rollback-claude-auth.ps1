$credPath    = "C:\Users\hgh97\.claude\.credentials.json"
$backupPath  = "C:\Users\hgh97\.claude\.credentials.json.backup_20260426"

Write-Host "=== Rolling back to Claude Pro ===" -ForegroundColor Yellow

# 1. ANTHROPIC 환경변수 제거
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", $null, "User")
[System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_USE_OPENAI", $null, "User")
[System.Environment]::SetEnvironmentVariable("OPENAI_BASE_URL", $null, "User")
[System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $null, "User")
[System.Environment]::SetEnvironmentVariable("OPENAI_MODEL", $null, "User")

Write-Host "OK: environment variables cleared" -ForegroundColor Green

# 2. OAuth 토큰 복구
if (Test-Path $backupPath) {
    Copy-Item $backupPath $credPath -Force
    Write-Host "OK: credentials.json restored from backup" -ForegroundColor Green
} else {
    Write-Host "WARNING: backup not found at $backupPath" -ForegroundColor Red
    Write-Host "You will need to log in to Claude.ai again after restart." -ForegroundColor Yellow
}

# 3. 상태 확인
Write-Host ""
Write-Host "=== Final state ===" -ForegroundColor Cyan
Write-Host "ANTHROPIC_BASE_URL : $([System.Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL', 'User'))"
Write-Host "ANTHROPIC_API_KEY  : $([System.Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'User'))"
$cred = Get-Content $credPath | ConvertFrom-Json
Write-Host "credentials.json has OAuth: $($null -ne $cred.claudeAiOauth)"
Write-Host ""
Write-Host "DONE. Restart Antigravity to log back in with Claude Pro." -ForegroundColor Green
