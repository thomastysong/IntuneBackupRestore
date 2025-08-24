#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for intune-uploader integration
    
.DESCRIPTION
    Verifies that the intune-uploader integration is properly set up and functional
#>

[CmdletBinding()]
param(
    [switch]$SkipPythonCheck,
    [switch]$SkipModuleCheck,
    [switch]$TestImport
)

$ErrorActionPreference = 'Stop'

Write-Host "IntuneBackupRestore - intune-uploader Integration Test" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Check submodule
Write-Host "`nChecking intune-uploader submodule..." -NoNewline
$submodulePath = Join-Path -Path $PSScriptRoot -ChildPath "external" | Join-Path -ChildPath "intune-uploader"
if (Test-Path $submodulePath) {
    if (Test-Path (Join-Path $submodulePath ".git")) {
        Write-Host " OK" -ForegroundColor Green
        
        # Check if initialized
        $uploaderPath = Join-Path -Path (Join-Path -Path $submodulePath -ChildPath "IntuneUploader") -ChildPath "IntuneAppUploader.py"
        if (-not (Test-Path $uploaderPath)) {
            Write-Host "  Submodule not initialized. Run: git submodule init && git submodule update" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host " NOT A GIT SUBMODULE" -ForegroundColor Yellow
        Write-Host "  Run: git submodule add https://github.com/almenscorner/intune-uploader.git external/intune-uploader" -ForegroundColor Yellow
    }
}
else {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Host "  Run: git submodule add https://github.com/almenscorner/intune-uploader.git external/intune-uploader" -ForegroundColor Yellow
    exit 1
}

# Check Python
if (-not $SkipPythonCheck) {
    Write-Host "`nChecking Python installation..." -NoNewline
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $version = & python --version 2>&1
        if ($version -match "Python 3\.([8-9]|1[0-9])") {
            Write-Host " OK ($version)" -ForegroundColor Green
        }
        else {
            Write-Host " UNSUPPORTED VERSION" -ForegroundColor Red
            Write-Host "  Found: $version" -ForegroundColor Yellow
            Write-Host "  Required: Python 3.8 or higher" -ForegroundColor Yellow
        }
        
        # Check pip
        Write-Host "`nChecking pip..." -NoNewline
        $pip = & python -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
            
            # Check requirements
            $requirementsPath = Join-Path -Path (Join-Path -Path $submodulePath -ChildPath "IntuneUploader") -ChildPath "requirements.txt"
            if (Test-Path $requirementsPath) {
                Write-Host "`nChecking Python dependencies..." -NoNewline
                $missingPackages = @()
                
                # Read requirements
                $requirements = Get-Content $requirementsPath | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '\S' }
                
                # Simple check for main packages
                $mainPackages = @('requests', 'autopkglib', 'cryptography')
                foreach ($package in $mainPackages) {
                    try {
                        $null = & python -c "import $package" 2>&1
                        if ($LASTEXITCODE -ne 0) {
                            $missingPackages += $package
                        }
                    }
                    catch {
                        $missingPackages += $package
                    }
                }
                
                if ($missingPackages.Count -eq 0) {
                    Write-Host " OK" -ForegroundColor Green
                }
                else {
                    Write-Host " MISSING PACKAGES" -ForegroundColor Yellow
                    Write-Host "  Missing: $($missingPackages -join ', ')" -ForegroundColor Yellow
                    Write-Host "  Run: pip install -r $requirementsPath" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Host " NOT FOUND" -ForegroundColor Red
            Write-Host "  pip is required for Python package management" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host " NOT FOUND" -ForegroundColor Red
        Write-Host "  Python 3.8+ is required for intune-uploader integration" -ForegroundColor Yellow
        Write-Host "  Download from: https://www.python.org/downloads/" -ForegroundColor Yellow
    }
}

# Check PowerShell modules
if (-not $SkipModuleCheck) {
    Write-Host "`nChecking PowerShell modules..." -ForegroundColor Cyan
    
    $wrapperPath = Join-Path -Path $PSScriptRoot -ChildPath "src" | Join-Path -ChildPath "modules" | Join-Path -ChildPath "powershell" | Join-Path -ChildPath "wrappers"
    $wrappers = @(
        "Invoke-IntuneAppUploader.ps1"
        "Invoke-IntuneAppIconGetter.ps1"
    )
    
    foreach ($wrapper in $wrappers) {
        Write-Host "  $wrapper..." -NoNewline
        $path = Join-Path $wrapperPath $wrapper
        if (Test-Path $path) {
            Write-Host " OK" -ForegroundColor Green
        }
        else {
            Write-Host " NOT FOUND" -ForegroundColor Red
        }
    }
    
    # Check enhanced import module
    Write-Host "  Import-Applications-Enhanced.ps1..." -NoNewline
    $enhancedPath = Join-Path -Path $PSScriptRoot -ChildPath "src" | Join-Path -ChildPath "modules" | Join-Path -ChildPath "powershell" | Join-Path -ChildPath "Import-Applications-Enhanced.ps1"
    if (Test-Path $enhancedPath) {
        Write-Host " OK" -ForegroundColor Green
    }
    else {
        Write-Host " NOT FOUND" -ForegroundColor Red
    }
}

# Test import functionality
if ($TestImport) {
    Write-Host "`nTesting import functionality..." -ForegroundColor Cyan
    
    try {
        # Load module
        Import-Module $enhancedPath -Force -ErrorAction Stop
        Write-Host "  Module loaded successfully" -ForegroundColor Green
        
        # Check if connected to Graph
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-Host "  Graph API connected" -ForegroundColor Green
        }
        else {
            Write-Host "  Not connected to Graph API" -ForegroundColor Yellow
            Write-Host "  Run: .\src\modules\powershell\Connect-GraphAPI.ps1" -ForegroundColor Yellow
        }
        
        # Check for test manifests
        $testManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "exports" | Join-Path -ChildPath "Applications"
        if (Test-Path $testManifestPath) {
            $manifests = Get-ChildItem -Path $testManifestPath -Filter "*.json"
            Write-Host "  Found $($manifests.Count) test manifest(s)" -ForegroundColor Green
        }
        else {
            Write-Host "  No test manifests found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

Write-Host "`nIntegration test complete!" -ForegroundColor Cyan

# Summary
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Initialize submodule if needed: git submodule init && git submodule update"
Write-Host "2. Install Python dependencies: pip install -r external/intune-uploader/IntuneUploader/requirements.txt"
Write-Host "3. Connect to Graph API: .\src\modules\powershell\Connect-GraphAPI.ps1"
Write-Host "4. Test enhanced import: Import-Applications-Enhanced -ImportPath '.\exports\Applications' -SourceFilesPath 'C:\AppSources'"
