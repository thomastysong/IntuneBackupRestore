# Application Manifest Schema

This document describes the JSON schema used for Intune Win32 application manifests in the IntuneBackupRestore project.

## Overview

Application manifests are JSON files that contain all the metadata needed to recreate a Win32 application in Microsoft Intune. These files are generated during export and consumed during import operations.

## Schema Structure

### Core Properties

```json
{
  "id": "string",
  "displayName": "string",
  "description": "string",
  "publisher": "string",
  "version": "string",
  "fileName": "string",
  "installCommandLine": "string",
  "uninstallCommandLine": "string",
  "note": "string"
}
```

#### Required Fields

- **displayName** (string): The display name of the application
- **fileName** (string): The installer filename (e.g., "setup.exe", "app.msi")
- **installCommandLine** (string): Silent install command (e.g., "msiexec /i app.msi /quiet")
- **uninstallCommandLine** (string): Silent uninstall command

#### Optional Fields

- **id** (string): Intune application ID (GUID)
- **description** (string): Application description
- **publisher** (string): Application publisher name
- **version** (string): Application version
- **note** (string): Additional notes (typically about content limitations)

### System Requirements

```json
{
  "minimumFreeDiskSpaceInMB": "number",
  "minimumMemoryInMB": "number", 
  "minimumNumberOfProcessors": "number",
  "minimumCpuSpeedInMHz": "number",
  "applicableArchitectures": ["x86", "x64", "arm", "arm64"],
  "minimumSupportedOperatingSystem": {
    "v8_0": false,
    "v8_1": false,
    "v10_0": true,
    "v10_1607": true,
    "v10_1703": true,
    "v10_1709": true,
    "v10_1803": true,
    "v10_1809": true,
    "v10_1903": true,
    "v10_1909": true,
    "v10_2004": true,
    "v10_20H2": true,
    "v10_21H1": true
  }
}
```

### Detection Rules

Detection rules determine if the application is installed. Multiple types are supported:

#### File Detection Rule
```json
{
  "@odata.type": "#microsoft.graph.win32LobAppFileSystemDetectionRule",
  "path": "C:\\Program Files\\MyApp",
  "fileOrFolderName": "myapp.exe",
  "check32BitOn64System": false,
  "detectionType": "exists",
  "operator": "notConfigured",
  "detectionValue": null
}
```

#### Registry Detection Rule
```json
{
  "@odata.type": "#microsoft.graph.win32LobAppRegistryDetectionRule",
  "keyPath": "HKLM\\Software\\MyCompany\\MyApp",
  "valueName": "Version",
  "detectionType": "string",
  "operator": "equal",
  "detectionValue": "1.0.0"
}
```

#### MSI Product Code Detection Rule
```json
{
  "@odata.type": "#microsoft.graph.win32LobAppProductCodeDetectionRule",
  "productCode": "{12345678-1234-1234-1234-123456789012}",
  "productVersionOperator": "notConfigured",
  "productVersion": null
}
```

### Requirement Rules

Requirement rules define prerequisites for installation:

```json
{
  "@odata.type": "#microsoft.graph.win32LobAppFileSystemRequirementRule",
  "path": "C:\\Windows\\System32",
  "fileOrFolderName": "file.dll",
  "check32BitOn64System": false,
  "detectionType": "version",
  "operator": "greaterThanOrEqual",
  "detectionValue": "10.0.0.0"
}
```

### Return Codes

Define custom return codes for installation results:

```json
{
  "returnCode": 0,
  "type": "success"
},
{
  "returnCode": 1707,
  "type": "success"
},
{
  "returnCode": 3010,
  "type": "softReboot"
},
{
  "returnCode": 1641,
  "type": "hardReboot"
}
```

### Assignments

Define how the application is assigned to groups:

```json
{
  "id": "assignment-guid",
  "intent": "required|available|uninstall",
  "source": "direct",
  "target": {
    "@odata.type": "#microsoft.graph.groupAssignmentTarget",
    "groupId": "group-guid"
  },
  "targetGroupName": "All Windows Devices"
}
```

## Complete Example

```json
{
  "id": "12345678-1234-1234-1234-123456789012",
  "displayName": "7-Zip 19.00",
  "description": "7-Zip is a file archiver with a high compression ratio",
  "publisher": "Igor Pavlov",
  "version": "19.00",
  "fileName": "7z1900-x64.msi",
  "installCommandLine": "msiexec /i 7z1900-x64.msi /quiet",
  "uninstallCommandLine": "msiexec /x {23170F69-40C1-2702-1900-000001000000} /quiet",
  "minimumFreeDiskSpaceInMB": 100,
  "minimumMemoryInMB": 512,
  "applicableArchitectures": ["x64"],
  "minimumSupportedOperatingSystem": {
    "v10_0": true
  },
  "detectionRules": [
    {
      "@odata.type": "#microsoft.graph.win32LobAppProductCodeDetectionRule",
      "productCode": "{23170F69-40C1-2702-1900-000001000000}"
    }
  ],
  "requirementRules": [],
  "returnCodes": [
    {
      "returnCode": 0,
      "type": "success"
    },
    {
      "returnCode": 3010,
      "type": "softReboot"
    }
  ],
  "assignments": [
    {
      "intent": "required",
      "target": {
        "@odata.type": "#microsoft.graph.groupAssignmentTarget",
        "groupId": "98765432-4321-4321-4321-210987654321"
      },
      "targetGroupName": "All Windows 10 Devices"
    }
  ],
  "iconFile": "7-Zip_19.00_icon.png",
  "note": "Application content (.intunewin file) cannot be exported via Graph API. Original installer files must be maintained separately for re-import."
}
```

## Import Considerations

When importing applications:

1. **Source Files**: The original installer file specified in `fileName` must be available in the source files directory
2. **Group Mapping**: If the target groups don't exist, they can be created automatically with the `-CreateGroups` flag
3. **Version Management**: The import process compares versions and only updates if the manifest version is higher
4. **Icon Files**: Icon files referenced in `iconFile` should be present in the import directory

## Usage

### Export
```powershell
Export-Applications -ExportPath ".\exports\Applications" -IncludeAssignments
```

### Import
```powershell
Import-Applications -ImportPath ".\exports\Applications" -SourceFilesPath "C:\AppSources" -UpdateExisting
```

## Notes

- The manifest format is designed to be compatible with Microsoft Graph API structures
- All `@odata.type` properties must be preserved for proper Graph API compatibility
- Detection and requirement rules follow the same structure as the Intune portal
- The schema is extensible - additional properties from Graph API responses are preserved
