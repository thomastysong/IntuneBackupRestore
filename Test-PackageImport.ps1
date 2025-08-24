#Requires -Version 5.1
<#
.SYNOPSIS
    Test the package import functionality locally
    
.DESCRIPTION
    This script tests the Import-Applications-Package function
    with the example manifests
#>

[CmdletBinding()]
param(
    [string]$ManifestPath = ".\packages\manifests\chrome.json",
    [switch]$ImportAll
)

Write-Host "Package Import Test" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

# Load environment variables if .env exists
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Write-Host "`nLoading environment variables..." -ForegroundColor Yellow
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '^["'']|["'']$', ''
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

# Connect to Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
. (Join-Path $PSScriptRoot "src\modules\powershell\Connect-GraphAPI.ps1")

if (-not (Connect-GraphAPI)) {
    Write-Error "Failed to connect to Graph API"
    exit 1
}

$context = Get-MgContext
Write-Host "Connected as: $($context.ClientId)" -ForegroundColor Green

# Load the package import module
Write-Host "`nLoading Import-Applications-Package module..." -ForegroundColor Cyan
. (Join-Path $PSScriptRoot "src\modules\powershell\Import-Applications-Package.ps1")

# Determine what to import
if ($ImportAll) {
    $ManifestPath = ".\packages\manifests"
    Write-Host "`nImporting all manifests from: $ManifestPath" -ForegroundColor Yellow
}
else {
    Write-Host "`nImporting single manifest: $ManifestPath" -ForegroundColor Yellow
}

# Check if manifest exists
if (!(Test-Path $ManifestPath)) {
    Write-Error "Manifest path not found: $ManifestPath"
    Write-Host "`nAvailable manifests:" -ForegroundColor Yellow
    Get-ChildItem -Path ".\packages\manifests" -Filter "*.json" | 
        ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
    exit 1
}

# Run the import
Write-Host "`nStarting import..." -ForegroundColor Cyan
try {
    Import-Applications-Package `
        -ManifestPath $ManifestPath `
        -UpdateExisting $true `
        -CreateIntunewinPackages $true `
        -Verbose
    
    Write-Host "`nImport completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Import failed: $_"
    exit 1
}

# Show current apps
Write-Host "`nCurrent apps in Intune:" -ForegroundColor Cyan
$uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
$apps = Invoke-MgGraphRequest -Uri $uri -Method GET

$apps.value | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.win32LobApp' } | 
    Select-Object displayName, id, uploadState | 
    Format-Table -AutoSize

Write-Host "`nDone!" -ForegroundColor Green
