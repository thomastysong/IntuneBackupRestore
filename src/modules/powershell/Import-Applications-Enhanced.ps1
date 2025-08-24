# Import wrapper modules
$wrapperPath = Join-Path -Path $PSScriptRoot -ChildPath "wrappers"
. (Join-Path -Path $wrapperPath -ChildPath "Invoke-IntuneAppUploader.ps1")
. (Join-Path -Path $wrapperPath -ChildPath "Invoke-IntuneAppIconGetter.ps1")

function Import-Applications-Enhanced {
    <#
    .SYNOPSIS
        Enhanced application import with intune-uploader integration
    
    .DESCRIPTION
        Imports applications to Intune with advanced features from intune-uploader:
        - Support for macOS apps (PKG, DMG)
        - Automatic icon extraction
        - Better error handling and progress tracking
        - Support for LOB apps
    
    .PARAMETER ImportPath
        Path to directory containing application manifests
    
    .PARAMETER SourceFilesPath
        Path to directory containing source application files
    
    .PARAMETER UpdateExisting
        Update existing apps if found
    
    .PARAMETER ExtractIcons
        Automatically extract and upload icons from app packages
    
    .PARAMETER UseLegacyMode
        Fall back to original Import-Applications for unsupported scenarios
    
    .EXAMPLE
        Import-Applications-Enhanced -ImportPath ".\exports\Applications" -SourceFilesPath "C:\AppSources" -ExtractIcons
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ImportPath,
        
        [Parameter(Mandatory = $false)]
        [string]$SourceFilesPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$UpdateExisting = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ExtractIcons = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseLegacyMode = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateGroups = $false,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$GroupMappingTable = @{}
    )
    
    begin {
        # Check Python availability
        $pythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        
        if (-not $pythonAvailable -and -not $UseLegacyMode) {
            Write-Warning "Python not available. Falling back to legacy mode."
            $UseLegacyMode = $true
        }
        
        # Ensure connected to Graph
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
        
        # Initialize counters
        $stats = @{
            Total = 0
            Imported = 0
            Updated = 0
            Skipped = 0
            Failed = 0
        }
    }
    
    process {
        # Get all manifest files
        $manifestFiles = Get-ChildItem -Path $ImportPath -Filter "*.json" -File
        $stats.Total = $manifestFiles.Count
        
        Write-Host "Found $($stats.Total) application manifest(s) to process" -ForegroundColor Cyan
        
        foreach ($manifestFile in $manifestFiles) {
            Write-Host "`nProcessing: $($manifestFile.Name)" -ForegroundColor Yellow
            
            try {
                # Read manifest
                $manifest = Get-Content -Path $manifestFile.FullName -Raw | ConvertFrom-Json
                
                # Determine app type and processing method
                $appType = $manifest.'@odata.type' -replace '#microsoft.graph.', ''
                $sourceFile = $null
                
                # Find source file if available
                if ($SourceFilesPath -and $manifest.fileName) {
                    $sourceFile = Join-Path $SourceFilesPath $manifest.fileName
                    if (-not (Test-Path $sourceFile)) {
                        # Try with display name
                        $possibleFiles = Get-ChildItem -Path $SourceFilesPath -Filter "*$($manifest.displayName)*" -File
                        if ($possibleFiles.Count -eq 1) {
                            $sourceFile = $possibleFiles[0].FullName
                        }
                        else {
                            Write-Warning "Source file not found: $($manifest.fileName)"
                            $sourceFile = $null
                        }
                    }
                }
                
                # Check if we should use enhanced uploader
                $useEnhancedUploader = -not $UseLegacyMode -and $pythonAvailable -and $sourceFile
                
                # Check for macOS apps or specific app types that benefit from enhanced uploader
                if ($sourceFile) {
                    $extension = [System.IO.Path]::GetExtension($sourceFile).ToLower()
                    if ($extension -in @('.pkg', '.dmg')) {
                        $useEnhancedUploader = $true
                        Write-Verbose "Using enhanced uploader for macOS app"
                    }
                }
                
                if ($useEnhancedUploader) {
                    Write-Host "  Using enhanced uploader..." -ForegroundColor Green
                    
                    # Prepare parameters for enhanced uploader
                    $uploaderParams = @{
                        AppFilePath = $sourceFile
                        DisplayName = $manifest.displayName
                        Description = $manifest.description
                        Publisher = $manifest.publisher
                        BundleId = $manifest.bundleId
                        BundleVersion = if ($manifest.displayVersion) { $manifest.displayVersion } else { "1.0.0" }
                        UpdateExisting = $UpdateExisting
                    }
                    
                    # Add optional parameters
                    if ($manifest.owner) { $uploaderParams.Owner = $manifest.owner }
                    if ($manifest.developer) { $uploaderParams.Developer = $manifest.developer }
                    if ($manifest.informationUrl) { $uploaderParams.InformationUrl = $manifest.informationUrl }
                    if ($manifest.privacyInformationUrl) { $uploaderParams.PrivacyUrl = $manifest.privacyInformationUrl }
                    if ($manifest.notes) { $uploaderParams.Notes = $manifest.notes }
                    if ($manifest.categories) { $uploaderParams.Categories = $manifest.categories.displayName }
                    
                    # Handle minimum OS version
                    if ($manifest.minimumSupportedOperatingSystem) {
                        $uploaderParams.MinimumOSVersion = $manifest.minimumSupportedOperatingSystem.'@odata.type' -replace '.*#', ''
                    }
                    
                    # Check for LOB app indicator
                    if ($manifest.isLobApp -or $appType -eq 'macOSLobApp') {
                        $uploaderParams.LobApp = $true
                    }
                    
                    # Handle assignments
                    if ($manifest.assignments) {
                        $assignmentGroups = @{
                            Required = @()
                            Available = @()
                            Uninstall = @()
                        }
                        
                        foreach ($assignment in $manifest.assignments) {
                            $groupId = $assignment.target.groupId
                            if ($GroupMappingTable.ContainsKey($groupId)) {
                                $groupId = $GroupMappingTable[$groupId]
                            }
                            
                            switch ($assignment.intent) {
                                "required" { $assignmentGroups.Required += $groupId }
                                "available" { $assignmentGroups.Available += $groupId }
                                "uninstall" { $assignmentGroups.Uninstall += $groupId }
                            }
                        }
                        
                        if ($assignmentGroups.Required.Count -gt 0 -or 
                            $assignmentGroups.Available.Count -gt 0 -or 
                            $assignmentGroups.Uninstall.Count -gt 0) {
                            $uploaderParams.AssignmentGroups = $assignmentGroups
                        }
                    }
                    
                    # Upload the app
                    $result = Invoke-IntuneAppUploader @uploaderParams
                    
                    if ($result.Success) {
                        Write-Host "  Successfully uploaded: $($result.AppName) (ID: $($result.AppId))" -ForegroundColor Green
                        
                        # Extract and upload icon if requested
                        if ($ExtractIcons -and $result.AppId) {
                            Write-Host "  Extracting and uploading icon..." -ForegroundColor Cyan
                            try {
                                $iconResult = Invoke-IntuneAppIconGetter -AppId $result.AppId -AppFilePath $sourceFile
                                if ($iconResult.Success) {
                                    Write-Host "  Icon uploaded successfully" -ForegroundColor Green
                                }
                            }
                            catch {
                                Write-Warning "  Failed to extract/upload icon: $_"
                            }
                        }
                        
                        if ($UpdateExisting) {
                            $stats.Updated++
                        }
                        else {
                            $stats.Imported++
                        }
                    }
                    else {
                        throw "Upload failed: $($result.Message)"
                    }
                }
                else {
                    # Fall back to legacy import
                    Write-Host "  Using legacy import method..." -ForegroundColor Yellow
                    
                    # Load legacy module if needed
                    if (-not (Get-Command Import-Applications -ErrorAction SilentlyContinue)) {
                        . (Join-Path $PSScriptRoot "Import-Applications.ps1")
                    }
                    
                    # Create temporary directory with single manifest
                    $tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "IntuneImport_$(Get-Random)")
                    Copy-Item $manifestFile.FullName -Destination $tempDir
                    
                    try {
                        # Run legacy import
                        $legacyParams = @{
                            ImportPath = $tempDir.FullName
                            UpdateExisting = $UpdateExisting
                            CreateGroups = $CreateGroups
                            GroupMappingTable = $GroupMappingTable
                        }
                        
                        if ($SourceFilesPath) {
                            $legacyParams.SourceFilesPath = $SourceFilesPath
                        }
                        
                        Import-Applications @legacyParams
                        $stats.Imported++
                    }
                    finally {
                        Remove-Item $tempDir -Recurse -Force
                    }
                }
            }
            catch {
                Write-Error "Failed to import $($manifestFile.Name): $_"
                $stats.Failed++
            }
        }
        
        # Display summary
        Write-Host "`nImport Summary:" -ForegroundColor Cyan
        Write-Host "  Total manifests: $($stats.Total)"
        Write-Host "  Imported: $($stats.Imported)" -ForegroundColor Green
        Write-Host "  Updated: $($stats.Updated)" -ForegroundColor Green
        Write-Host "  Skipped: $($stats.Skipped)" -ForegroundColor Yellow
        Write-Host "  Failed: $($stats.Failed)" -ForegroundColor Red
        
        return $stats
    }
}

# Export the enhanced function (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Script is being dot-sourced, don't export
}
else {
    Export-ModuleMember -Function Import-Applications-Enhanced -ErrorAction SilentlyContinue
}
