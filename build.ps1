#Requires -Version 5.1
<#
.SYNOPSIS
    Build and dependency management script for Intune Backup Restore

.DESCRIPTION
    This script handles dependency installation and common tasks for the Intune Backup solution.
    Designed to work on Windows Server, Windows 11, and minimal Windows images.

.PARAMETER Task
    The task to perform. Valid values: Install, Test, ExportCompliance, ExportConfig, ExportApplications, ExportScripts, ExportAll, Clean, Setup

.EXAMPLE
    .\build.ps1 -Task Install
    Installs all dependencies (Python and PowerShell)

.EXAMPLE
    .\build.ps1 -Task ExportAll
    Runs all exports and generates change log
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Install', 'InstallPython', 'InstallPowerShell', 'Test', 'ExportCompliance', 'ExportConfig', 'ExportApplications', 'ExportScripts', 'ExportAll', 'Clean', 'Setup', 'Help')]
    [string]$Task = 'Help'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Helper functions
function Write-TaskHeader {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Python {
    try {
        $pythonVersion = & python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python found: $pythonVersion" -ForegroundColor Green
            return $true
        }
    } catch {}
    
    try {
        $pythonVersion = & python3 --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Python3 found: $pythonVersion" -ForegroundColor Green
            $script:pythonCmd = 'python3'
            return $true
        }
    } catch {}
    
    Write-ErrorMessage "Python not found. Please install Python 3.8 or later."
    Write-Host "You can install Python from: https://www.python.org/downloads/" -ForegroundColor Yellow
    return $false
}

# Set Python command
$pythonCmd = 'python'

# Task implementations
function Install-AllDependencies {
    Write-TaskHeader "Installing all dependencies"
    Install-PythonDependencies
    Install-PowerShellDependencies
    Write-Success "All dependencies installed"
}

function Install-PythonDependencies {
    Write-TaskHeader "Installing Python dependencies"
    
    if (-not (Test-Python)) {
        throw "Python installation required"
    }
    
    try {
        # Upgrade pip first
        Write-Host "Upgrading pip..." -ForegroundColor Yellow
        & $pythonCmd -m pip install --upgrade pip
        
        # Install requirements
        Write-Host "Installing Python packages..." -ForegroundColor Yellow
        & $pythonCmd -m pip install -r requirements.txt
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Python dependencies"
        }
        
        Write-Success "Python dependencies installed"
    } catch {
        Write-ErrorMessage "Failed to install Python dependencies: $_"
        throw
    }
}

function Install-PowerShellDependencies {
    Write-TaskHeader "Installing PowerShell dependencies"
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "PowerShell version: $psVersion" -ForegroundColor Green
    
    # For PowerShell 5.1, we need to modify the script
    if ($psVersion.Major -eq 5) {
        Write-Host "Detected PowerShell 5.1 - Installing modules..." -ForegroundColor Yellow
        
        # Install modules directly for PS 5.1
        $modules = @(
            @{Name = 'Microsoft.Graph'; RequiredVersion = '2.10.0'},
            @{Name = 'Microsoft.Graph.Intune'; RequiredVersion = '6.1907.1.0'},
            @{Name = 'Pester'; RequiredVersion = '5.5.0'}
        )
        
        foreach ($module in $modules) {
            if (!(Get-Module -ListAvailable -Name $module.Name | Where-Object {$_.Version -eq $module.RequiredVersion})) {
                Write-Host "Installing $($module.Name) v$($module.RequiredVersion)..." -ForegroundColor Yellow
                try {
                    Install-Module @module -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                    Write-Success "$($module.Name) installed"
                } catch {
                    Write-Warning "Failed to install $($module.Name): $_"
                }
            } else {
                Write-Host "$($module.Name) v$($module.RequiredVersion) already installed" -ForegroundColor Green
            }
        }
    } else {
        # For PowerShell 7+, use the original script
        & "$PSScriptRoot\scripts\Install-Requirements.ps1"
    }
    
    Write-Success "PowerShell dependencies installed"
}

function Run-Tests {
    Write-TaskHeader "Running tests"
    
    if (-not (Test-Python)) {
        throw "Python required for running tests"
    }
    
    & $pythonCmd tests/test_runner.py --type unit
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Tests failed"
        throw "Test execution failed"
    }
    
    Write-Success "Tests passed"
}

function Export-CompliancePolicies {
    Write-TaskHeader "Exporting compliance policies"
    
    if (-not (Test-Python)) {
        throw "Python required for exports"
    }
    
    & $pythonCmd -m src.export_runner --module compliance_policies
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export compliance policies"
    }
    
    Write-Success "Compliance policies exported"
}

function Export-ConfigurationProfiles {
    Write-TaskHeader "Exporting configuration profiles"
    
    # Check if the Python export script exists
    $exportScript = Join-Path $PSScriptRoot "export_config_profiles.py"
    if (Test-Path $exportScript) {
        & $pythonCmd $exportScript
    } else {
        # Use the module-based approach
        Write-Host "Using PowerShell module for configuration profiles export..." -ForegroundColor Yellow
        
        # Import and run PowerShell export
        Import-Module "$PSScriptRoot\src\modules\powershell\Connect-GraphAPI.ps1" -Force
        Import-Module "$PSScriptRoot\src\modules\powershell\Export-ConfigurationProfiles.ps1" -Force
        
        if (Connect-GraphAPI) {
            Export-ConfigurationProfiles
        } else {
            throw "Failed to connect to Graph API"
        }
    }
    
    Write-Success "Configuration profiles exported"
}

function Export-Applications {
    Write-TaskHeader "Exporting applications"
    
    # Python module for applications
    Write-Host "Using Python module for applications export..." -ForegroundColor Yellow
    & $pythonCmd -m src.export_runner --module applications
    
    Write-Success "Applications exported"
}

function Export-Scripts {
    Write-TaskHeader "Exporting scripts"
    
    # PowerShell module for scripts
    Write-Host "Using PowerShell module for scripts export..." -ForegroundColor Yellow
    
    Import-Module "$PSScriptRoot\src\modules\powershell\Connect-GraphAPI.ps1" -Force
    Import-Module "$PSScriptRoot\src\modules\powershell\Export-IntuneScripts.ps1" -Force
    
    if (Connect-GraphAPI) {
        $scripts = Export-IntuneScripts -Verbose
        Write-Host "Exported $($scripts.Count) scripts" -ForegroundColor Green
    }
    
    Write-Success "Scripts exported"
}

function Export-All {
    Write-TaskHeader "Running all exports"
    
    Export-CompliancePolicies
    Export-ConfigurationProfiles
    Export-Applications
    Export-Scripts
    
    Write-Host "Generating change log..." -ForegroundColor Yellow
    & $pythonCmd -m src.generate_changelog
    
    Write-Success "All exports completed"
}

function Clean-Project {
    Write-TaskHeader "Cleaning temporary files"
    
    $foldersToClean = @(
        '__pycache__',
        'src\__pycache__',
        'src\utils\__pycache__',
        'src\modules\__pycache__',
        'src\modules\python\__pycache__',
        'tests\__pycache__',
        '.pytest_cache'
    )
    
    foreach ($folder in $foldersToClean) {
        if (Test-Path $folder) {
            Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed $folder" -ForegroundColor Yellow
        }
    }
    
    # Remove .pyc files
    Get-ChildItem -Path . -Filter "*.pyc" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Success "Cleanup completed"
}

function Setup-Environment {
    Write-TaskHeader "Setting up development environment"
    
    # Install dependencies first
    Install-AllDependencies
    
    # Create .env file if it doesn't exist
    $envFile = Join-Path $PSScriptRoot ".env"
    $envTemplate = Join-Path $PSScriptRoot "env.template"
    
    if (-not (Test-Path $envFile)) {
        if (Test-Path $envTemplate) {
            Copy-Item $envTemplate $envFile
            Write-Success "Created .env file - please configure it with your Azure AD app credentials"
        } else {
            Write-Warning "env.template not found - please create .env file manually"
        }
    } else {
        Write-Success ".env file already exists"
    }
    
    Write-Success "Development environment ready"
}

function Show-Help {
    $helpText = @'
Intune Backup Restore - Build Tasks

Usage: .\build.ps1 -Task <TaskName>

Available tasks:
  Install           - Install all dependencies (Python and PowerShell)
  InstallPython     - Install Python dependencies only
  InstallPowerShell - Install PowerShell dependencies only
  Test              - Run unit tests
  ExportCompliance  - Export compliance policies
  ExportConfig      - Export configuration profiles
  ExportApplications - Export applications
  ExportScripts     - Export scripts
  ExportAll         - Run all exports and generate change log
  Clean             - Clean temporary files
  Setup             - Setup development environment (install deps + create .env)
  Help              - Show this help message

Examples:
  .\build.ps1 -Task Install
  .\build.ps1 -Task ExportAll
  .\build.ps1 -Task Setup

For GitHub Actions agents, run:
  .\build.ps1 -Task Install
'@
    Write-Host $helpText -ForegroundColor Cyan
}

# Main execution
try {
    switch ($Task) {
        'Install' { Install-AllDependencies }
        'InstallPython' { Install-PythonDependencies }
        'InstallPowerShell' { Install-PowerShellDependencies }
        'Test' { Run-Tests }
        'ExportCompliance' { Export-CompliancePolicies }
        'ExportConfig' { Export-ConfigurationProfiles }
        'ExportApplications' { Export-Applications }
        'ExportScripts' { Export-Scripts }
        'ExportAll' { Export-All }
        'Clean' { Clean-Project }
        'Setup' { Setup-Environment }
        'Help' { Show-Help }
    }
} catch {
    Write-ErrorMessage "Task failed: $($_.Exception.Message)"
    exit 1
}
