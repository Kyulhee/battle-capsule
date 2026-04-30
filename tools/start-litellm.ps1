$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "litellm-config.yaml"
$litellmPath = "C:\Users\hgh97\miniconda3\envs\ai_env\Scripts\litellm.exe"

Write-Host "LiteLLM Proxy starting (game_dev -> NVIDIA Kimi K2.5)" -ForegroundColor Cyan
Write-Host "Port  : 4000 (http://localhost:4000)"
Write-Host "Model : moonshotai/kimi-k2.5"
Write-Host "Stop  : Ctrl+C"
Write-Host ""

$portInUse = Get-NetTCPConnection -LocalPort 4000 -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "WARNING: Port 4000 already in use. Stop existing process first." -ForegroundColor Red
    exit 1
}

& $litellmPath --config $configPath --port 4000
