# Build and Dependency Management

This document describes how to build and run the Intune Backup Restore solution on various Windows environments.

## Quick Start

### For Development Machines
```batch
# Setup complete environment (installs dependencies + creates .env)
.\build.ps1 -Task Setup

# Or using make (if installed)
make setup
```

### For CI/CD Agents
```batch
# Basic dependency installation
.\build.cmd Install

# Or for minimal Windows agents
.\scripts\Setup-Agent.ps1
.\build.cmd Install
```

## Build Scripts Overview

### 1. **build.ps1** (Primary Build Script)
PowerShell-based build script that handles all tasks. Works on Windows Server, Windows 11, and minimal Windows images.

**Available Tasks:**
- `Install` - Install all dependencies (Python + PowerShell)
- `InstallPython` - Install Python dependencies only
- `InstallPowerShell` - Install PowerShell dependencies only  
- `Test` - Run unit tests
- `ExportCompliance` - Export compliance policies
- `ExportConfig` - Export configuration profiles
- `ExportAll` - Run all exports and generate change log
- `Clean` - Clean temporary files
- `Setup` - Complete setup (install + create .env)
- `Help` - Show help message

**Examples:**
```powershell
# Install all dependencies
.\build.ps1 -Task Install

# Run all exports
.\build.ps1 -Task ExportAll

# Run tests
.\build.ps1 -Task Test
```

### 2. **build.cmd** (Batch Wrapper)
Simple batch file wrapper for build.ps1. Use this if PowerShell execution policy is restricted.

```batch
build.cmd Install
build.cmd ExportAll
```

### 3. **Makefile** (Alternative for Make Users)
For environments with `make` installed (via Git for Windows, Chocolatey, or Scoop).

```bash
make install       # Install all dependencies
make test          # Run tests
make export-all    # Run all exports
make help          # Show all targets
```

### 4. **Setup-Agent.ps1** (Agent Preparation)
Prepares minimal Windows agents that may not have Python or required PowerShell modules.

**Features:**
- Checks for Python and installs if missing
- Installs NuGet provider
- Configures PSGallery as trusted
- Installs required PowerShell modules
- Verifies environment readiness

**Usage:**
```powershell
# Run on a fresh agent
.\scripts\Setup-Agent.ps1

# Skip Python check if already installed
.\scripts\Setup-Agent.ps1 -SkipPythonCheck
```

## Environment Requirements

### Minimum Requirements
- **Windows**: Windows Server 2016+, Windows 10/11, or Windows container
- **PowerShell**: 5.1 or higher  
- **Python**: 3.8 or higher
- **.NET Framework**: 4.5+ (for PowerShell modules)

### Automatically Installed
- Python packages (via pip)
- PowerShell modules (Microsoft.Graph, etc.)
- NuGet provider (if missing)

## CI/CD Integration

### GitHub Actions
The workflow automatically uses the build scripts:

```yaml
- name: Install all dependencies
  shell: cmd
  run: |
    build.cmd Install
```

### Azure DevOps
```yaml
- task: PowerShell@2
  inputs:
    filePath: 'build.ps1'
    arguments: '-Task Install'
    
- task: PowerShell@2  
  inputs:
    filePath: 'build.ps1'
    arguments: '-Task ExportAll'
```

### Jenkins
```groovy
stage('Install Dependencies') {
    steps {
        bat 'build.cmd Install'
    }
}

stage('Run Exports') {
    steps {
        bat 'build.cmd ExportAll'
    }
}
```

## Troubleshooting

### Python Not Found
```powershell
# Run agent setup to install Python
.\scripts\Setup-Agent.ps1
```

### PowerShell Module Installation Fails
```powershell
# Ensure NuGet provider is installed
Install-PackageProvider -Name NuGet -Force

# Trust PSGallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Retry installation
.\build.ps1 -Task InstallPowerShell
```

### Permission Errors
- Run PowerShell as Administrator
- Or use `-Scope CurrentUser` for module installation

### Execution Policy Errors
```powershell
# Bypass for current session
powershell -ExecutionPolicy Bypass -File build.ps1 -Task Install

# Or use the batch wrapper
build.cmd Install
```

## Agent-Specific Notes

### Windows Server Core
- Use `Setup-Agent.ps1` first to ensure Python is installed
- May need to install .NET Framework features

### Windows Containers
```dockerfile
# In your Dockerfile
COPY . /app
WORKDIR /app
RUN powershell -File scripts/Setup-Agent.ps1
RUN powershell -File build.ps1 -Task Install
```

### Minimal Windows Images
1. Run `Setup-Agent.ps1` to install prerequisites
2. Use `build.cmd` for all operations
3. Check logs if modules fail to install

## Development Workflow

1. **Initial Setup**
   ```batch
   git clone <repository>
   cd IntuneBackupRestore
   .\build.ps1 -Task Setup
   ```

2. **Configure Credentials**
   - Edit `.env` file with Azure AD app details

3. **Run Exports**
   ```batch
   .\build.ps1 -Task ExportAll
   ```

4. **Run Tests**
   ```batch
   .\build.ps1 -Task Test
   ```

5. **Clean Up**
   ```batch
   .\build.ps1 -Task Clean
   ```
