# stop-litellm.ps1
# LiteLLM 프록시 강제 종료

$procs = Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*litellm*"
}

if ($procs) {
    $procs | Stop-Process -Force
    Write-Host "✅ LiteLLM 프로세스 종료 완료" -ForegroundColor Green
} else {
    Write-Host "LiteLLM 프로세스가 실행 중이지 않습니다." -ForegroundColor Yellow
}
