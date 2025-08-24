# External Dependencies

This directory contains git submodules and external dependencies used by IntuneBackupRestore.

## intune-uploader

The `intune-uploader` submodule provides advanced application upload capabilities through AutoPkg processors.

### Features Added by Integration:
- **macOS App Support**: Upload PKG and DMG files directly
- **Automatic Icon Extraction**: Extract and upload app icons from packages
- **LOB App Support**: Deploy apps as "available" instead of "required"
- **Advanced Packaging**: Better handling of complex app packages
- **Version Management**: Intelligent app version comparison and updates

### Setup Instructions:

1. **Initialize the submodule** (if not already done):
   ```powershell
   git submodule init
   git submodule update
   ```

2. **Install Python 3.8+** (required for intune-uploader):
   ```powershell
   # Check if Python is installed
   python --version
   
   # If not installed, download from https://www.python.org/downloads/
   ```

3. **Install Python dependencies**:
   ```powershell
   pip install -r external/intune-uploader/IntuneUploader/requirements.txt
   ```

4. **Set up authentication**:
   ```powershell
   # The integration uses your existing Graph API connection
   # Ensure you have the required environment variable:
   $env:INTUNE_CLIENT_SECRET = "your-client-secret"
   ```

### Usage Examples:

```powershell
# Import the enhanced module
Import-Module .\src\modules\powershell\Import-Applications-Enhanced.ps1

# Connect to Graph API (using existing connection module)
.\src\modules\powershell\Connect-GraphAPI.ps1

# Import apps with enhanced features
Import-Applications-Enhanced `
    -ImportPath ".\exports\Applications" `
    -SourceFilesPath "C:\AppSources" `
    -ExtractIcons

# Use specific wrappers directly
Invoke-IntuneAppUploader `
    -AppFilePath "C:\Apps\MyApp.pkg" `
    -DisplayName "My macOS App" `
    -Description "Test application" `
    -Publisher "Contoso" `
    -BundleId "com.contoso.myapp" `
    -BundleVersion "1.0.0" `
    -LobApp

# Extract and upload icon for existing app
Invoke-IntuneAppIconGetter `
    -AppId "12345-67890-abcdef" `
    -AppFilePath "C:\Apps\MyApp.pkg"
```

### Updating the Submodule:

To get the latest updates from intune-uploader:

```powershell
cd external/intune-uploader
git fetch origin
git checkout main
git pull origin main
cd ../..
git add external/intune-uploader
git commit -m "Update intune-uploader submodule"
```

### Troubleshooting:

1. **Python not found**: Ensure Python 3.8+ is installed and in PATH
2. **Module import errors**: Run `pip install -r requirements.txt` in the intune-uploader directory
3. **Authentication errors**: Ensure INTUNE_CLIENT_SECRET environment variable is set
4. **Icon extraction fails**: Some app formats may not support automatic icon extraction

### License:

The intune-uploader project is licensed under Apache 2.0. See the [LICENSE](intune-uploader/LICENSE) file for details.
