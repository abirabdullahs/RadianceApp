# Writes secrets-fcm.env as UTF-8 WITHOUT BOM (Supabase CLI rejects BOM).
# Usage: .\scripts\set-fcm-secret.ps1 [path\to\firebase-adminsdk.json]
# Then: npx supabase secrets set --env-file .\secrets-fcm.env

param(
    [string]$JsonPath = ".\radiancebdapp-firebase-adminsdk-fbsvc-444e1bd4fd.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $JsonPath)) {
    Write-Error "File not found: $JsonPath"
}

$j = Get-Content -Raw -LiteralPath $JsonPath | ConvertFrom-Json
$line = $j | ConvertTo-Json -Compress -Depth 100
$content = "FCM_SERVICE_ACCOUNT_JSON=$line"

$outPath = Join-Path (Get-Location) "secrets-fcm.env"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outPath, $content, $utf8NoBom)

Write-Host "Wrote $outPath (UTF-8, no BOM). Run:"
Write-Host "  npx supabase secrets set --env-file .\secrets-fcm.env"
Write-Host "Then delete: Remove-Item .\secrets-fcm.env -Force"
