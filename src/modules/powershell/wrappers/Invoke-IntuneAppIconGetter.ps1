function Invoke-IntuneAppIconGetter {
    <#
    .SYNOPSIS
        PowerShell wrapper for the intune-uploader IntuneAppIconGetter processor
    
    .DESCRIPTION
        Extracts application icons and uploads them to Intune apps.
        Supports various formats including PKG, DMG, APP, EXE, MSI files.
    
    .PARAMETER AppId
        The Intune application ID to update with the icon
    
    .PARAMETER AppFilePath
        Path to the application file to extract icon from
    
    .PARAMETER IconPath
        Direct path to an icon file (PNG, JPG, JPEG) to use instead of extraction
    
    .EXAMPLE
        Invoke-IntuneAppIconGetter -AppId "12345-67890" -AppFilePath "C:\Apps\MyApp.pkg"
    
    .EXAMPLE
        Invoke-IntuneAppIconGetter -AppId "12345-67890" -IconPath "C:\Icons\app-icon.png"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Extract')]
        [ValidateScript({ Test-Path $_ })]
        [string]$AppFilePath,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Direct')]
        [ValidateScript({ Test-Path $_ })]
        [string]$IconPath
    )
    
    begin {
        # Ensure Python environment
        $pythonPath = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonPath) {
            throw "Python is not installed or not in PATH. Python 3.8+ is required."
        }
        
        # Get Graph API context
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
        
        # Prepare paths
        $modulePath = Join-Path $PSScriptRoot ".." ".." ".." ".." "external" "intune-uploader" "IntuneUploader"
        $iconGetterScript = Join-Path $modulePath "IntuneAppIconGetter.py"
        
        if (-not (Test-Path $iconGetterScript)) {
            throw "IntuneAppIconGetter.py not found. Ensure submodule is initialized."
        }
    }
    
    process {
        try {
            # Set up environment
            $env:INTUNE_CLIENT_ID = $context.ClientId
            $env:INTUNE_TENANT_ID = $context.TenantId
            
            # Build input dictionary
            $inputDict = @{
                CLIENT_ID = $env:INTUNE_CLIENT_ID
                CLIENT_SECRET = $env:INTUNE_CLIENT_SECRET
                TENANT_ID = $env:INTUNE_TENANT_ID
                intune_app_id = $AppId
            }
            
            # Add file path based on parameter set
            if ($PSCmdlet.ParameterSetName -eq 'Extract') {
                $inputDict.app_file = $AppFilePath
            }
            else {
                $inputDict.icon_path = $IconPath
            }
            
            # Convert to JSON
            $inputJson = $inputDict | ConvertTo-Json -Compress
            $encodedInput = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($inputJson))
            
            # Create Python wrapper
            $wrapperScript = @"
import sys
import os
import json
import base64

sys.path.insert(0, r'$modulePath')

from IntuneAppIconGetter import IntuneAppIconGetter

# Decode input
input_json = base64.b64decode('$encodedInput').decode('utf-8')
input_dict = json.loads(input_json)

# Create and run processor
processor = IntuneAppIconGetter()
processor.env = input_dict

output = {}

try:
    processor.main()
    output['success'] = True
    output['message'] = 'Icon updated successfully'
    output['icon_extracted'] = getattr(processor, 'icon_extracted', False)
    
except Exception as e:
    output['success'] = False
    output['message'] = str(e)

print(json.dumps(output))
"@
            
            # Execute
            $tempScript = [System.IO.Path]::GetTempFileName() + ".py"
            $wrapperScript | Out-File -FilePath $tempScript -Encoding UTF8
            
            try {
                $result = & python $tempScript 2>&1
                $output = $result | ConvertFrom-Json
                
                if ($output.success) {
                    Write-Verbose "Icon updated successfully"
                    return [PSCustomObject]@{
                        Success = $true
                        AppId = $AppId
                        IconExtracted = $output.icon_extracted
                        Message = $output.message
                    }
                }
                else {
                    throw "Failed to update icon: $($output.message)"
                }
            }
            finally {
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -Force
                }
            }
        }
        finally {
            Remove-Item Env:INTUNE_CLIENT_ID -ErrorAction SilentlyContinue
            Remove-Item Env:INTUNE_TENANT_ID -ErrorAction SilentlyContinue
        }
    }
}

# Export the function (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript') {
    Export-ModuleMember -Function Invoke-IntuneAppIconGetter -ErrorAction SilentlyContinue
}
