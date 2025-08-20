#Requires -Version 5.1
<#
.SYNOPSIS
    Setup script for Windows agents (Windows Server, Windows 11, minimal images)

.DESCRIPTION
    This script ensures all prerequisites are installed on a fresh Windows agent.
    Handles Python installation, PowerShell module installation, and environment setup.
    Designed for CI/CD agents that may not have all tools pre-installed.

.PARAMETER SkipPythonCheck
    Skip Python installation check (assumes Python is already installed)

.PARAMETER PythonVersion
    Python version to install if not found (default: 3.11.0)

.EXAMPLE
    .\Setup-Agent.ps1
    Sets up the agent with all prerequisites
#>

[CmdletBinding()]
param(
    [switch]$SkipPythonCheck,
    [string]$PythonVersion = '3.11.0'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-StepHeader {
    param([string]$Message)
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Python {
    try {
        $pythonVersion = & python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python found: $pythonVersion"
            return $true
        }
    } catch {}
    
    try {
        $pythonVersion = & python3 --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Python3 found: $pythonVersion"
            return $true
        }
    } catch {}
    
    return $false
}

function Install-Python {
    Write-StepHeader "Installing Python $PythonVersion"
    
    if (Test-Python) {
        Write-Success "Python is already installed"
        return
    }
    
    # Download Python installer
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"
    $installerPath = "$env:TEMP\python-installer.exe"
    
    Write-Host "Downloading Python from $pythonUrl..."
    try {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-Warning "Failed to download Python. Please install manually."
        throw
    }
    
    # Install Python silently
    Write-Host "Installing Python..."
    $installArgs = @(
        '/quiet',
        'InstallAllUsers=1',
        'PrependPath=1',
        'Include_test=0',
        'Include_pip=1'
    )
    
    Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -NoNewWindow
    
    # Clean up installer
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Test-Python) {
        Write-Success "Python installed successfully"
    } else {
        throw "Python installation failed"
    }
}

function Install-NuGet {
    Write-StepHeader "Checking NuGet provider"
    
    if (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue) {
        Write-Success "NuGet provider already installed"
        return
    }
    
    Write-Host "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Write-Success "NuGet provider installed"
}

function Set-PSRepository {
    Write-StepHeader "Configuring PowerShell Gallery"
    
    # Set PSGallery as trusted
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Write-Success "PSGallery configured as trusted repository"
}

function Install-RequiredPowerShellModules {
    Write-StepHeader "Installing PowerShell modules"
    
    $modules = @(
        @{Name = 'Microsoft.Graph'; MinimumVersion = '2.10.0'},
        @{Name = 'PackageManagement'; MinimumVersion = '1.4.8.1'}
    )
    
    foreach ($module in $modules) {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | 
            Where-Object { $_.Version -ge [version]$module.MinimumVersion } | 
            Select-Object -First 1
        
        if ($installedModule) {
            Write-Success "$($module.Name) v$($installedModule.Version) already installed"
        } else {
            Write-Host "Installing $($module.Name)..."
            try {
                Install-Module -Name $module.Name -MinimumVersion $module.MinimumVersion -Force -AllowClobber -Scope CurrentUser
                Write-Success "$($module.Name) installed"
            } catch {
                Write-Warning "Failed to install $($module.Name): $_"
            }
        }
    }
}

function Test-GitInstalled {
    try {
        $gitVersion = & git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git found: $gitVersion"
            return $true
        }
    } catch {}
    return $false
}

function Set-EnvironmentReady {
    Write-StepHeader "Verifying environment"
    
    # Check Python
    if (-not (Test-Python)) {
        Write-Warning "Python not found after installation"
        return $false
    }
    
    # Check pip
    try {
        & python -m pip --version | Out-Null
        Write-Success "pip is available"
    } catch {
        Write-Warning "pip not found"
        return $false
    }
    
    # Check PowerShell version
    Write-Success "PowerShell version: $($PSVersionTable.PSVersion)"
    
    # Check Git (optional but recommended)
    if (-not (Test-GitInstalled)) {
        Write-Warning "Git not found - version control operations will not work"
    }
    
    return $true
}

# Main execution
Write-Host @"
===============================================
Intune Backup Restore - Agent Setup
===============================================
This script prepares a Windows agent for running
the Intune backup solution.
===============================================
"@ -ForegroundColor Cyan

try {
    # Check if running as administrator (recommended but not required)
    if (-not (Test-Administrator)) {
        Write-Warning "Not running as administrator. Some operations may fail."
        Write-Warning "For best results, run this script as administrator."
    }
    
    # Install Python if needed and not skipped
    if (-not $SkipPythonCheck) {
        if (-not (Test-Python)) {
            Install-Python
        }
    }
    
    # Configure PowerShell environment
    Install-NuGet
    Set-PSRepository
    Install-RequiredPowerShellModules
    
    # Verify environment
    if (Set-EnvironmentReady) {
        Write-Success "`nAgent setup completed successfully!"
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "  1. Run: .\build.ps1 -Task Install" -ForegroundColor White
        Write-Host "  2. Configure your .env file with Azure AD credentials" -ForegroundColor White
        Write-Host "  3. Run: .\build.ps1 -Task ExportAll" -ForegroundColor White
    } else {
        Write-Warning "`nAgent setup completed with warnings. Please review the output above."
    }
    
} catch {
    Write-Host "`n[✗] Agent setup failed: $_" -ForegroundColor Red
    exit 1
}
