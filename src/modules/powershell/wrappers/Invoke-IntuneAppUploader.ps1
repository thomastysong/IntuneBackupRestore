function Invoke-IntuneAppUploader {
    <#
    .SYNOPSIS
        PowerShell wrapper for the intune-uploader IntuneAppUploader processor
    
    .DESCRIPTION
        This function provides a PowerShell interface to the Python-based IntuneAppUploader,
        enabling seamless integration with the existing IntuneBackupRestore workflow.
    
    .PARAMETER AppFilePath
        Path to the application file (PKG, DMG, MSI, EXE, INTUNEWIN)
    
    .PARAMETER DisplayName
        Display name for the application in Intune
    
    .PARAMETER Description
        Description of the application
    
    .PARAMETER Publisher
        Publisher of the application
    
    .PARAMETER BundleId
        Bundle ID (for macOS apps) or Product Code (for Windows apps)
    
    .PARAMETER BundleVersion
        Version of the application
    
    .PARAMETER Categories
        Array of category names to assign the app to
    
    .PARAMETER AssignmentGroups
        Hashtable of assignment groups: @{ Required = @(); Available = @(); Uninstall = @() }
    
    .PARAMETER MinimumOSVersion
        Minimum supported operating system version
    
    .PARAMETER Architecture
        Application architecture (x86, x64, universal)
    
    .PARAMETER UpdateExisting
        Update existing app if found with same name
    
    .EXAMPLE
        Invoke-IntuneAppUploader -AppFilePath "C:\Apps\MyApp.pkg" -DisplayName "My Application" -Description "Test app" -Publisher "Contoso" -BundleId "com.contoso.myapp" -BundleVersion "1.0.0"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$AppFilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [string]$Publisher,
        
        [Parameter(Mandatory = $true)]
        [string]$BundleId,
        
        [Parameter(Mandatory = $true)]
        [string]$BundleVersion,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Categories = @(),
        
        [Parameter(Mandatory = $false)]
        [hashtable]$AssignmentGroups = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$MinimumOSVersion,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('x86', 'x64', 'universal')]
        [string]$Architecture = 'universal',
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateExisting = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$Owner,
        
        [Parameter(Mandatory = $false)]
        [string]$Developer,
        
        [Parameter(Mandatory = $false)]
        [string]$InformationUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$PrivacyUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$Notes,
        
        [Parameter(Mandatory = $false)]
        [switch]$InstallAsManaged,
        
        [Parameter(Mandatory = $false)]
        [switch]$PreventMacAppDataBackup,
        
        [Parameter(Mandatory = $false)]
        [switch]$LobApp
    )
    
    begin {
        # Ensure we have the required Python environment
        $pythonPath = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonPath) {
            throw "Python is not installed or not in PATH. Python 3.8+ is required."
        }
        
        # Check Python version
        $pythonVersion = & python --version 2>&1
        if ($pythonVersion -notmatch "Python 3\.([8-9]|1[0-9])") {
            throw "Python 3.8 or higher is required. Current version: $pythonVersion"
        }
        
        # Get Graph API context
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
        
        # Prepare paths
        $modulePath = Join-Path $PSScriptRoot ".." ".." ".." ".." "external" "intune-uploader" "IntuneUploader"
        $uploaderScript = Join-Path $modulePath "IntuneAppUploader.py"
        
        if (-not (Test-Path $uploaderScript)) {
            throw "IntuneAppUploader.py not found at: $uploaderScript. Ensure submodule is initialized."
        }
        
        # Install Python requirements if needed
        $requirementsFile = Join-Path $modulePath "requirements.txt"
        if (Test-Path $requirementsFile) {
            Write-Verbose "Installing Python requirements..."
            & python -m pip install -r $requirementsFile --quiet
        }
    }
    
    process {
        try {
            # Prepare environment variables for authentication
            $env:INTUNE_CLIENT_ID = $context.ClientId
            $env:INTUNE_TENANT_ID = $context.TenantId
            
            # Note: For production use, you'll need to handle client secret securely
            # This is a simplified example
            if (-not $env:INTUNE_CLIENT_SECRET) {
                Write-Warning "INTUNE_CLIENT_SECRET environment variable not set. Authentication may fail."
            }
            
            # Build AutoPkg-style input dictionary
            $inputDict = @{
                CLIENT_ID = $env:INTUNE_CLIENT_ID
                CLIENT_SECRET = $env:INTUNE_CLIENT_SECRET
                TENANT_ID = $env:INTUNE_TENANT_ID
                app_file = $AppFilePath
                displayname = $DisplayName
                description = $Description
                publisher = $Publisher
                bundleId = $BundleId
                bundleVersion = $BundleVersion
                update_app = $UpdateExisting.IsPresent
                categories = $Categories
                install_as_managed = $InstallAsManaged.IsPresent
                prevent_mac_app_data_backup = $PreventMacAppDataBackup.IsPresent
                lob_app = $LobApp.IsPresent
            }
            
            # Add optional parameters
            if ($Owner) { $inputDict.owner = $Owner }
            if ($Developer) { $inputDict.developer = $Developer }
            if ($InformationUrl) { $inputDict.information_url = $InformationUrl }
            if ($PrivacyUrl) { $inputDict.privacy_information_url = $PrivacyUrl }
            if ($Notes) { $inputDict.notes = $Notes }
            if ($MinimumOSVersion) { $inputDict.minimumSupportedOperatingSystem = $MinimumOSVersion }
            
            # Handle assignments
            if ($AssignmentGroups.Count -gt 0) {
                if ($AssignmentGroups.ContainsKey('Required')) {
                    $inputDict.required_groups = $AssignmentGroups.Required
                }
                if ($AssignmentGroups.ContainsKey('Available')) {
                    $inputDict.available_groups = $AssignmentGroups.Available
                }
                if ($AssignmentGroups.ContainsKey('Uninstall')) {
                    $inputDict.uninstall_groups = $AssignmentGroups.Uninstall
                }
            }
            
            # Convert to JSON for passing to Python
            $inputJson = $inputDict | ConvertTo-Json -Depth 10 -Compress
            $encodedInput = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($inputJson))
            
            # Create temporary Python wrapper script
            $wrapperScript = @"
import sys
import os
import json
import base64

# Add module path
sys.path.insert(0, r'$modulePath')

from IntuneAppUploader import IntuneAppUploader

# Decode input
input_json = base64.b64decode('$encodedInput').decode('utf-8')
input_dict = json.loads(input_json)

# Create processor instance
processor = IntuneAppUploader()
processor.env = input_dict

# Set up output
output = {}

try:
    # Run the processor
    processor.main()
    
    # Collect output variables
    for key in processor.output_variables:
        if hasattr(processor, key):
            output[key] = getattr(processor, key)
    
    output['success'] = True
    output['message'] = 'App uploaded successfully'
    
except Exception as e:
    output['success'] = False
    output['message'] = str(e)
    output['error'] = type(e).__name__

# Output as JSON
print(json.dumps(output))
"@
            
            # Write wrapper script to temp file
            $tempScript = [System.IO.Path]::GetTempFileName() + ".py"
            $wrapperScript | Out-File -FilePath $tempScript -Encoding UTF8
            
            try {
                # Execute Python script
                Write-Verbose "Executing IntuneAppUploader..."
                $result = & python $tempScript 2>&1
                
                # Parse result
                $output = $result | ConvertFrom-Json
                
                if ($output.success) {
                    Write-Verbose "App uploaded successfully"
                    
                    # Return app details
                    return [PSCustomObject]@{
                        Success = $true
                        AppId = $output.intune_app_id
                        AppName = $DisplayName
                        Version = $BundleVersion
                        Message = $output.message
                    }
                }
                else {
                    throw "Failed to upload app: $($output.message)"
                }
            }
            finally {
                # Clean up temp script
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -Force
                }
            }
        }
        catch {
            Write-Error "Error uploading app: $_"
            throw
        }
        finally {
            # Clean up environment variables
            Remove-Item Env:INTUNE_CLIENT_ID -ErrorAction SilentlyContinue
            Remove-Item Env:INTUNE_TENANT_ID -ErrorAction SilentlyContinue
        }
    }
}

# Export the function (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript') {
    Export-ModuleMember -Function Invoke-IntuneAppUploader -ErrorAction SilentlyContinue
}
