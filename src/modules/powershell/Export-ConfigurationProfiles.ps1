function Export-ConfigurationProfiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExportPath = "exports/ConfigurationProfiles",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAssignments = $true
    )
    
    begin {
        # Ensure export directory exists
        if (!(Test-Path $ExportPath)) {
            New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
        }
        
        # Ensure connected to Graph
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
    }
    
    process {
        try {
            # Get all device configuration profiles
            Write-Verbose "Retrieving device configuration profiles..."
            $profiles = Get-MgDeviceManagementDeviceConfiguration -All
            
            $exportedProfiles = @()
            
            foreach ($profile in $profiles) {
                Write-Verbose "Processing profile: $($profile.DisplayName)"
                
                # Get full profile details
                $fullProfile = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $profile.Id
                
                # Convert to exportable format
                $exportProfile = $fullProfile | Select-Object -Property * -ExcludeProperty AdditionalProperties
                
                # Add assignments if requested
                if ($IncludeAssignments) {
                    $assignments = Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $profile.Id
                    $exportProfile | Add-Member -NotePropertyName 'assignments' -NotePropertyValue $assignments -Force
                }
                
                # Save to file
                $fileName = "$($profile.DisplayName -replace '[^\w\s-]', '_')_$($profile.Id).json"
                $filePath = Join-Path $ExportPath $fileName
                
                $exportProfile | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
                
                $exportedProfiles += [PSCustomObject]@{
                    Id = $profile.Id
                    DisplayName = $profile.DisplayName
                    FilePath = $filePath
                    Status = "Exported"
                }
            }
            
            return $exportedProfiles
        }
        catch {
            Write-Error "Failed to export configuration profiles: $_"
            throw
        }
    }
}
