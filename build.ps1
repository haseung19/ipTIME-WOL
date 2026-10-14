# Run from the repository root. Requires Go 1.23+.
$ErrorActionPreference = 'Stop'

Set-Location -LiteralPath $PSScriptRoot
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw 'Go SDK is not installed or go.exe is not on PATH.'
}

$previousOS = $env:GOOS
$previousARCH = $env:GOARCH
$previousCGO = $env:CGO_ENABLED
try {
    $env:GOOS = 'windows'
    $env:GOARCH = 'amd64'
    $env:CGO_ENABLED = '0'
    New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'dist') | Out-Null
    & go build -trimpath -ldflags '-H=windowsgui -s -w' -o (Join-Path $PSScriptRoot 'dist\ipTIME-WOL.exe') ./src
    if ($LASTEXITCODE -ne 0) { throw 'go build failed.' }
    Write-Host 'Build complete: dist\ipTIME-WOL.exe'
    Get-FileHash -Algorithm SHA256 -Path (Join-Path $PSScriptRoot 'dist\ipTIME-WOL.exe') | Format-List
} finally {
    $env:GOOS = $previousOS
    $env:GOARCH = $previousARCH
    $env:CGO_ENABLED = $previousCGO
}
