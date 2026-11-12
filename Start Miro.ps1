$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
# Keys stay outside the build and are inherited privately by the game process.
$envFile = Join-Path $project '.env'
if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*(?:export\s+)?(JEV_API_KEY|TYPESAFE_API_KEY)\s*=\s*(.*?)\s*$') {
            $value = $matches[2].Trim().Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($matches[1], $value, 'Process')
        }
    }
}
$exe = Join-Path $project 'build\windows\Miro.exe'
if (Test-Path -LiteralPath (Join-Path $project 'Miro.exe')) { $exe = Join-Path $project 'Miro.exe' }
# Warm the small local model so its first assignment does not pay load latency.
try {
    $payload = @{model='qwen3:0.6b'; prompt=''; stream=$false; keep_alive='30m';options=@{num_ctx=1024}} | ConvertTo-Json
    Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/generate' -Method Post -ContentType 'application/json' -Body $payload -TimeoutSec 15 | Out-Null
} catch { Write-Output 'Local guard model unavailable; Godot assignments remain active.' }
$log = Join-Path $project 'tmp\guard-security-runtime.log'
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -ArgumentList @('--log-file', ('"' + $log + '"'), '--', '--local-guard-model', '--jev-guard-shadow')
