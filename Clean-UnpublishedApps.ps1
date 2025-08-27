#Requires -Version 5.1
<#
.SYNOPSIS
    Clean up unpublished apps from Intune
    
.DESCRIPTION
    This script removes apps that were created but never had content uploaded
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

Write-Host "Cleaning up unpublished apps from Intune" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

# Load environment variables if needed
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

Write-Host "Connected successfully!" -ForegroundColor Green

# Get all Win32 apps
Write-Host "`nFetching all Win32 apps..." -ForegroundColor Cyan
$uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
$apps = (Invoke-MgGraphRequest -Uri $uri -Method GET).value

# Filter for Win32 apps that are not published
$unpublishedApps = $apps | Where-Object { 
    $_.'@odata.type' -eq '#microsoft.graph.win32LobApp' -and 
    ($_.uploadState -ne 'commitFileSuccess' -or $_.publishingState -ne 'published')
}

if ($unpublishedApps.Count -eq 0) {
    Write-Host "`nNo unpublished apps found!" -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($unpublishedApps.Count) unpublished app(s):" -ForegroundColor Yellow
$unpublishedApps | ForEach-Object {
    Write-Host "  - $($_.displayName) (ID: $($_.id))" -ForegroundColor White
    Write-Host "    Upload State: $($_.uploadState)" -ForegroundColor Gray
    Write-Host "    Publishing State: $($_.publishingState)" -ForegroundColor Gray
}

if ($WhatIf) {
    Write-Host "`n[WhatIf] Would delete these apps. Run without -WhatIf to actually delete." -ForegroundColor Yellow
    exit 0
}

# Confirm deletion
$confirm = Read-Host "`nDo you want to delete these unpublished apps? (Y/N)"
if ($confirm -ne 'Y') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete apps
Write-Host "`nDeleting unpublished apps..." -ForegroundColor Red
$deleted = 0
$failed = 0

foreach ($app in $unpublishedApps) {
    Write-Host "  Deleting: $($app.displayName)..." -NoNewline
    try {
        $deleteUri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$($app.id)"
        Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE
        Write-Host " OK" -ForegroundColor Green
        $deleted++
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Deleted: $deleted" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor Red

Write-Host "`nDone!" -ForegroundColor Green
