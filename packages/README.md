# Intune Application Packages

This directory contains application manifests and packages for automated Intune deployment.

## Directory Structure

```
packages/
├── manifests/       # Application manifest JSON files
├── source/          # Source installers (downloaded or placed manually)
├── intunewin/       # Generated .intunewin packages
└── temp/            # Temporary files
```

## Manifest Format

Application manifests define how apps should be deployed to Intune. They support:
- **Local files**: Place installer in `source/` directory
- **Public URLs**: Automatically download from specified URL

### Example Manifest

```json
{
  "displayName": "Google Chrome Enterprise",
  "description": "Fast, secure web browser",
  "publisher": "Google LLC",
  "fileName": "ChromeStandaloneSetup64.exe",
  "sourceUrl": "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe",
  "alwaysDownload": true,
  "installCommandLine": "msiexec /i \"GoogleChromeStandaloneEnterprise64.msi\" /qn",
  "uninstallCommandLine": "msiexec /x {GUID} /qn",
  "rules": [
    {
      "@odata.type": "#microsoft.graph.win32LobAppFileSystemRule",
      "ruleType": "detection",
      "path": "%ProgramFiles%\\Google\\Chrome\\Application",
      "fileOrFolderName": "chrome.exe",
      "operationType": "exists"
    }
  ],
  "assignments": [
    {
      "intent": "available",
      "target": {
        "@odata.type": "#microsoft.graph.allLicensedUsersAssignmentTarget"
      }
    }
  ]
}
```

## Usage

### Import Single App
```powershell
Import-Applications-Package -ManifestPath ".\packages\manifests\chrome.json"
```

### Import All Apps
```powershell
Import-Applications-Package -ManifestPath ".\packages\manifests"
```

### Import with Local File
1. Place installer in `packages/source/`
2. Reference it in manifest with `fileName`
3. Run import command

### Import with URL
1. Add `sourceUrl` to manifest
2. Set `alwaysDownload: true` to force fresh download
3. Run import command

## Supported Fields

### Required Fields
- `displayName` - App name in Intune
- `installCommandLine` - Installation command
- `uninstallCommandLine` - Uninstallation command
- `rules` - Detection rules array

### Source Fields (one required)
- `fileName` - Local file in source directory
- `sourceUrl` - Public URL to download from

### Optional Fields
- `description` - App description
- `publisher` - Publisher name
- `developer` - Developer name
- `owner` - Owner information
- `notes` - Internal notes
- `informationUrl` - App info URL
- `privacyInformationUrl` - Privacy policy URL
- `alwaysDownload` - Force download even if file exists
- `runAsAccount` - "system" or "user" (default: "system")
- `deviceRestartBehavior` - "allow", "basedOnReturnCode", "suppress", "force"
- `minimumFreeDiskSpaceInMB` - Minimum free disk space
- `minimumMemoryInMB` - Minimum RAM
- `assignments` - Array of assignment objects

## Detection Rules

### File/Folder Detection
```json
{
  "@odata.type": "#microsoft.graph.win32LobAppFileSystemRule",
  "ruleType": "detection",
  "path": "%ProgramFiles%\\AppName",
  "fileOrFolderName": "app.exe",
  "operationType": "exists"
}
```

### Registry Detection
```json
{
  "@odata.type": "#microsoft.graph.win32LobAppRegistryRule",
  "ruleType": "detection",
  "keyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\AppName",
  "valueName": "Version",
  "operationType": "greaterThanOrEqual",
  "operator": "string",
  "comparisonValue": "1.0.0"
}
```

## Assignments

### All Users (Available)
```json
{
  "intent": "available",
  "target": {
    "@odata.type": "#microsoft.graph.allLicensedUsersAssignmentTarget"
  }
}
```

### All Devices (Required)
```json
{
  "intent": "required",
  "target": {
    "@odata.type": "#microsoft.graph.allDevicesAssignmentTarget"
  }
}
```

### Specific Group
```json
{
  "intent": "required",
  "target": {
    "@odata.type": "#microsoft.graph.groupAssignmentTarget",
    "groupId": "00000000-0000-0000-0000-000000000000"
  }
}
```
