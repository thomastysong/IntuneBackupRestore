# Intune Uploader Integration Plan

## Overview
This document outlines the integration of the `intune-uploader` project capabilities into the IntuneBackupRestore solution.

## Integration Strategy

### 1. **Submodule Approach**
Add intune-uploader as a git submodule to maintain separation and easy updates:
- Preserves original code integrity
- Allows independent updates
- Clear licensing boundaries

### 2. **Wrapper Layer**
Create PowerShell wrappers around key Python processors:
- Maintains consistency with existing PowerShell-based architecture
- Provides seamless integration with current workflow
- Enables gradual adoption

### 3. **Feature Integration**

#### Phase 1: Core App Upload Enhancement
- Integrate `IntuneAppUploader` for enhanced app packaging and upload
- Add support for macOS apps (PKG, DMG)
- Leverage advanced content preparation features

#### Phase 2: Icon Management
- Integrate `IntuneAppIconGetter` for automatic icon extraction
- Enhance app metadata with proper icons

#### Phase 3: App Lifecycle Management
- Add `IntuneAppCleaner` for version management
- Implement `IntuneAppPromoter` for staged deployments
- Integrate `IntuneVTAppDeleter` for security scanning

#### Phase 4: Notifications
- Add Teams/Slack notifications for import/export operations
- Provide real-time status updates

## Technical Implementation

### Directory Structure
```
IntuneBackupRestore/
├── external/
│   └── intune-uploader/       # Git submodule
├── src/
│   ├── modules/
│   │   ├── powershell/
│   │   │   ├── wrappers/      # New PowerShell wrappers
│   │   │   │   ├── Invoke-IntuneAppUploader.ps1
│   │   │   │   ├── Invoke-IntuneAppIconGetter.ps1
│   │   │   │   └── ...
│   │   └── python/
│       └── intune_integration/ # Python integration layer
└── ...
```

### Key Integration Points

1. **Authentication Bridge**
   - Use existing Graph API connection from PowerShell
   - Pass credentials to Python processors
   - Maintain single sign-on experience

2. **Data Format Conversion**
   - Convert between PowerShell objects and Python dictionaries
   - Handle manifest format differences
   - Ensure compatibility with existing exports

3. **Error Handling**
   - Unified error reporting
   - Consistent logging format
   - Graceful fallback to native implementation

## Benefits

1. **Enhanced Capabilities**
   - Support for more app types (macOS, MSI, EXE)
   - Advanced packaging features
   - Better version management

2. **Improved Automation**
   - AutoPkg integration for automated updates
   - Scheduled app refreshes
   - Automated security scanning

3. **Better User Experience**
   - Icon extraction and management
   - Notifications for important events
   - Cleaner app catalog

## Implementation Timeline

- **Week 1**: Set up submodule and basic wrappers
- **Week 2**: Integrate core upload functionality
- **Week 3**: Add icon management and app lifecycle features
- **Week 4**: Implement notifications and testing

## Compatibility Notes

- Requires Python 3.8+ (for intune-uploader)
- Additional Python dependencies via requirements.txt
- Compatible with existing PowerShell 7+ requirements
- Maintains backward compatibility with existing import/export formats
