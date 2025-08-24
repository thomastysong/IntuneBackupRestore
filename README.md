# Intune Configuration Backup as Code

This repository contains an automated solution for backing up Microsoft Intune configurations to Git with version control and change tracking.

## Overview

This system automatically:
- Exports all Microsoft Intune configurations via Microsoft Graph API
- Backs up Win32 applications, configuration profiles, compliance policies, and scripts
- Stores configurations as JSON files in Git with version control
- Supports importing configurations back to Intune (restore/migration scenarios)
- Tracks changes between backups with detailed change logs
- Runs weekly via GitHub Actions (with manual trigger option)
- Provides integration points for monitoring (e.g., Grafana)

## Architecture

The solution uses:
- **PowerShell** and **Python** modules for different Intune components
- **Microsoft Graph API** for data retrieval
- **GitHub Actions** for scheduled automation
- **Git** for version control and history

![Intune Backup Architecture](docs/image.png)

## Supported Configurations

### Export Support
- ✅ **Configuration Profiles** - Device configuration policies
- ✅ **Compliance Policies** - Device compliance rules  
- ✅ **Applications** - Win32 LOB applications (metadata and assignments)
- ✅ **Scripts** - PowerShell scripts, Shell scripts, and Proactive Remediations
- ✅ **Assignments** - Group assignments for all configurations

### Import Support  
- ✅ **Applications** - Import Win32 apps from manifest + source files
  - ✨ **Enhanced Import** - macOS apps (PKG/DMG), automatic icon extraction, LOB apps
  - 📦 **Package Management** - Import from local files or public URLs
  - 🤖 **GitHub Actions** - Automated deployment on manifest changes
- 🔄 **Configuration Profiles** - Coming soon
- 🔄 **Compliance Policies** - Coming soon
- 🔄 **Scripts** - Coming soon

> **Note:** Application content (.intunewin files) cannot be exported via Graph API. Original installer files must be maintained separately for re-import.

## Quick Start

1. **Set up Azure AD App Registration**
   - Create app registration with Graph API permissions
   - Required permissions: 
     - `DeviceManagementConfiguration.Read.All` - For configuration profiles
     - `DeviceManagementRBAC.Read.All` - For RBAC roles
     - `DeviceManagementApps.Read.All` - For applications export
     - `DeviceManagementApps.ReadWrite.All` - For applications import
     - `DeviceManagementManagedDevices.Read.All` - For scripts

2. **Configure GitHub Secrets**
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`

3. **Deploy to GitHub**
   - Push this repository to a private GitHub repository
   - GitHub Actions will automatically run weekly or on manual trigger

## Repository Structure

```
IntuneBackupRestore/
├── .github/workflows/      # GitHub Actions workflows
├── src/                    # Source code
│   ├── modules/           # Export modules (PowerShell & Python)
│   └── utils/             # Shared utilities
├── exports/               # Exported Intune configurations
├── change_logs/           # JSON change logs
├── tests/                 # Test suite
├── docs/                  # Additional documentation
└── scripts/               # Setup and utility scripts
```

## Building and Running

For detailed build instructions and dependency management, see [BUILD.md](BUILD.md).

**Quick Start:**
```batch
# Install dependencies and run all exports
.\build.cmd Install
.\build.cmd ExportAll

# Export specific components
.\build.cmd ExportApplications
.\build.cmd ExportScripts  
.\build.cmd ExportCompliance
.\build.cmd ExportConfig
```

**Import Applications (PowerShell):**
```powershell
# Import the module
Import-Module .\src\modules\powershell\Import-Applications.ps1

# Connect to Graph API
.\src\modules\powershell\Connect-GraphAPI.ps1

# Import applications from export
Import-Applications -ImportPath ".\exports\Applications" -SourceFilesPath "C:\AppSources"
```

**Enhanced Import with intune-uploader Integration:**
```powershell
# Import enhanced module (includes macOS app support, icon extraction)
Import-Module .\src\modules\powershell\Import-Applications-Enhanced.ps1

# Import with advanced features
Import-Applications-Enhanced -ImportPath ".\exports\Applications" -SourceFilesPath "C:\AppSources" -ExtractIcons
```

**Package-Based Import (Recommended):**
```powershell
# Import from package manifests with URL support
. .\src\modules\powershell\Import-Applications-Package.ps1

# Import single app
Import-Applications-Package -ManifestPath ".\packages\manifests\chrome.json"

# Import all apps from manifests directory
Import-Applications-Package -ManifestPath ".\packages\manifests"
```

## Package Management

The package management system simplifies app deployment:

1. **Create manifest** in `packages/manifests/` (see examples)
2. **Specify source**:
   - Local file: Place in `packages/source/` and reference with `fileName`
   - Public URL: Add `sourceUrl` for automatic download
3. **Run import** manually or via GitHub Actions

See [packages/README.md](packages/README.md) for detailed manifest documentation.

## Development

See [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) for detailed implementation guide.

## Security

- All data is stored in a private repository
- Credentials are managed via GitHub Secrets
- App registration uses read-only permissions
- No sensitive secrets are exported to the backup

## Support

This is an internal tool. For issues or questions, contact the Client Platform Engineering team.
