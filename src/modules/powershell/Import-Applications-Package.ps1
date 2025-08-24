function Import-Applications-Package {
    <#
    .SYNOPSIS
        Import applications to Intune with support for local packages and public URLs
    
    .DESCRIPTION
        Enhanced import functionality that supports:
        - Local packages from packages/source directory
        - Public URLs for direct downloads
        - Automatic packaging with Win32 Content Prep Tool
        - Manifest-based deployment
    
    .PARAMETER ManifestPath
        Path to application manifest JSON file or directory containing manifests
    
    .PARAMETER PackagesPath
        Path to packages directory (default: ./packages)
    
    .PARAMETER UpdateExisting
        Update existing apps if found (default: true)
    
    .PARAMETER CreateIntunewinPackages
        Automatically create .intunewin packages (default: true)
    
    .EXAMPLE
        Import-Applications-Package -ManifestPath ".\packages\manifests\chrome.json"
    
    .EXAMPLE
        Import-Applications-Package -ManifestPath ".\packages\manifests" -UpdateExisting $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        
        [Parameter(Mandatory = $false)]
        [string]$PackagesPath = (Join-Path -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "..") -ChildPath "..") -ChildPath ".." | Join-Path -ChildPath "packages"),
        
        [Parameter(Mandatory = $false)]
        [bool]$UpdateExisting = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$CreateIntunewinPackages = $true
    )
    
    begin {
        # Ensure connected to Graph
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
        
        # Ensure IntuneWin32App module
        if ($CreateIntunewinPackages -and !(Get-Module -ListAvailable -Name "IntuneWin32App")) {
            Write-Warning "IntuneWin32App module not found. Installing..."
            Install-Module -Name IntuneWin32App -Force -Scope CurrentUser
        }
        Import-Module IntuneWin32App -Force -ErrorAction SilentlyContinue
        
        # Setup paths
        $sourceDir = Join-Path -Path $PackagesPath -ChildPath "source"
        $intunewinDir = Join-Path -Path $PackagesPath -ChildPath "intunewin"
        $tempDir = Join-Path -Path $PackagesPath -ChildPath "temp"
        
        # Create directories
        @($sourceDir, $intunewinDir, $tempDir) | ForEach-Object {
            if (!(Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
            }
        }
        
        # Download Win32 Content Prep Tool if needed
        $contentPrepTool = Join-Path -Path $tempDir -ChildPath "IntuneWinAppUtil.exe"
        if (!(Test-Path $contentPrepTool)) {
            Write-Verbose "Downloading Microsoft Win32 Content Prep Tool..."
            $downloadUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $contentPrepTool
        }
    }
    
    process {
        # Get manifest files
        $manifests = @()
        if (Test-Path $ManifestPath -PathType Leaf) {
            $manifests = @(Get-Item $ManifestPath)
        }
        elseif (Test-Path $ManifestPath -PathType Container) {
            $manifests = Get-ChildItem -Path $ManifestPath -Filter "*.json" -File
        }
        else {
            throw "Manifest path not found: $ManifestPath"
        }
        
        Write-Host "Found $($manifests.Count) manifest(s) to process" -ForegroundColor Cyan
        
        foreach ($manifestFile in $manifests) {
            Write-Host "`nProcessing: $($manifestFile.Name)" -ForegroundColor Yellow
            
            try {
                # Read manifest
                $manifest = Get-Content -Path $manifestFile.FullName -Raw | ConvertFrom-Json
                
                # Validate manifest
                if (-not $manifest.displayName) {
                    throw "Invalid manifest: missing displayName"
                }
                
                Write-Host "  App: $($manifest.displayName)" -ForegroundColor White
                
                # Check if app exists
                $existingApp = $null
                if ($UpdateExisting) {
                    $filter = "displayName eq '$($manifest.displayName)'"
                    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=$filter"
                    $result = Invoke-MgGraphRequest -Uri $uri -Method GET
                    
                    if ($result.value.Count -gt 0) {
                        $existingApp = $result.value[0]
                        Write-Host "  Found existing app (ID: $($existingApp.id))" -ForegroundColor Green
                    }
                }
                
                # Handle source file
                $sourceFile = $null
                $needsDownload = $false
                
                if ($manifest.sourceUrl) {
                    # Public URL provided
                    Write-Host "  Source URL: $($manifest.sourceUrl)" -ForegroundColor Cyan
                    $fileName = if ($manifest.fileName) { $manifest.fileName } else { Split-Path $manifest.sourceUrl -Leaf }
                    $sourceFile = Join-Path -Path $sourceDir -ChildPath $fileName
                    
                    if (!(Test-Path $sourceFile) -or $manifest.alwaysDownload) {
                        $needsDownload = $true
                    }
                }
                elseif ($manifest.fileName) {
                    # Local file
                    $sourceFile = Join-Path -Path $sourceDir -ChildPath $manifest.fileName
                    if (!(Test-Path $sourceFile)) {
                        Write-Warning "  Source file not found: $($manifest.fileName)"
                        continue
                    }
                }
                else {
                    Write-Warning "  No source file or URL specified in manifest"
                    continue
                }
                
                # Download if needed
                if ($needsDownload) {
                    Write-Host "  Downloading from: $($manifest.sourceUrl)" -ForegroundColor Cyan
                    try {
                        Invoke-WebRequest -Uri $manifest.sourceUrl -OutFile $sourceFile -UseBasicParsing
                        Write-Host "  Downloaded: $(Split-Path $sourceFile -Leaf)" -ForegroundColor Green
                    }
                    catch {
                        Write-Error "  Failed to download: $_"
                        continue
                    }
                }
                
                # Create .intunewin package if needed
                $intunewinFile = Join-Path -Path $intunewinDir -ChildPath "$($manifest.displayName).intunewin"
                
                if ($CreateIntunewinPackages -and (!$existingApp -or !(Test-Path $intunewinFile))) {
                    Write-Host "  Creating .intunewin package..." -ForegroundColor Cyan
                    
                    $setupFile = Split-Path $sourceFile -Leaf
                    $sourceFolder = Split-Path $sourceFile -Parent
                    
                    try {
                        $package = New-IntuneWin32AppPackage `
                            -SourceFolder $sourceFolder `
                            -SetupFile $setupFile `
                            -OutputFolder $intunewinDir `
                            -Force
                        
                        if ($package) {
                            # Rename to expected name
                            if ($package.Path -ne $intunewinFile) {
                                Move-Item -Path $package.Path -Destination $intunewinFile -Force
                            }
                            Write-Host "  Package created successfully" -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Warning "  Failed to create package: $_"
                    }
                }
                
                # Prepare app data for Graph API
                $appData = @{
                    "@odata.type" = "#microsoft.graph.win32LobApp"
                    displayName = $manifest.displayName
                    description = if ($manifest.description) { $manifest.description } else { "" }
                    publisher = if ($manifest.publisher) { $manifest.publisher } else { "Unknown" }
                    largeIcon = $null
                    isFeatured = if ($manifest.isFeatured) { $manifest.isFeatured } else { $false }
                    privacyInformationUrl = $manifest.privacyInformationUrl
                    informationUrl = $manifest.informationUrl
                    owner = if ($manifest.owner) { $manifest.owner } else { "" }
                    developer = if ($manifest.developer) { $manifest.developer } else { "" }
                    notes = if ($manifest.notes) { $manifest.notes } else { "Imported by IntuneBackupRestore" }
                    fileName = Split-Path $sourceFile -Leaf
                    installCommandLine = $manifest.installCommandLine
                    uninstallCommandLine = $manifest.uninstallCommandLine
                    installExperience = @{
                        runAsAccount = if ($manifest.runAsAccount) { $manifest.runAsAccount } else { "system" }
                        deviceRestartBehavior = if ($manifest.deviceRestartBehavior) { $manifest.deviceRestartBehavior } else { "suppress" }
                    }
                    returnCodes = if ($manifest.returnCodes) { $manifest.returnCodes } else { @(@{ returnCode = 0; type = "success" }) }
                    msiInformation = $manifest.msiInformation
                    setupFilePath = $manifest.setupFilePath
                    minimumFreeDiskSpaceInMB = if ($manifest.minimumFreeDiskSpaceInMB) { $manifest.minimumFreeDiskSpaceInMB } else { $null }
                    minimumMemoryInMB = if ($manifest.minimumMemoryInMB) { $manifest.minimumMemoryInMB } else { $null }
                    minimumNumberOfProcessors = if ($manifest.minimumNumberOfProcessors) { $manifest.minimumNumberOfProcessors } else { $null }
                    minimumCpuSpeedInMHz = if ($manifest.minimumCpuSpeedInMHz) { $manifest.minimumCpuSpeedInMHz } else { $null }
                    rules = $manifest.rules
                    requirementRules = if ($manifest.requirementRules) { $manifest.requirementRules } else { @() }
                    applicableArchitectures = if ($manifest.applicableArchitectures) { $manifest.applicableArchitectures } else { "x64,x86" }
                    minimumSupportedOperatingSystem = if ($manifest.minimumSupportedOperatingSystem) { 
                        $manifest.minimumSupportedOperatingSystem 
                    } else { 
                        @{ "@odata.type" = "#microsoft.graph.windowsMinimumOperatingSystem"; v10_1607 = $true }
                    }
                }
                
                # Create or update app
                if ($existingApp) {
                    Write-Host "  Updating app in Intune..." -ForegroundColor Cyan
                    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$($existingApp.id)"
                    $app = Invoke-MgGraphRequest -Uri $uri -Method PATCH -Body ($appData | ConvertTo-Json -Depth 10)
                    Write-Host "  Updated successfully!" -ForegroundColor Green
                }
                else {
                    Write-Host "  Creating app in Intune..." -ForegroundColor Cyan
                    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
                    $app = Invoke-MgGraphRequest -Uri $uri -Method POST -Body ($appData | ConvertTo-Json -Depth 10)
                    Write-Host "  Created successfully!" -ForegroundColor Green
                }
                
                # Handle assignments if specified
                if ($manifest.assignments) {
                    $appId = if ($app.id) { $app.id } else { $existingApp.id }
                    Write-Host "  Processing assignments..." -ForegroundColor Cyan
                    
                    foreach ($assignment in $manifest.assignments) {
                        try {
                            $assignmentBody = @{
                                "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                                intent = $assignment.intent
                                source = "direct"
                                target = $assignment.target
                            }
                            
                            $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments"
                            Invoke-MgGraphRequest -Uri $uri -Method POST -Body ($assignmentBody | ConvertTo-Json -Depth 10)
                            Write-Host "    Created assignment: $($assignment.intent)" -ForegroundColor Green
                        }
                        catch {
                            if ($_.Exception.Message -like "*already exists*") {
                                Write-Host "    Assignment already exists" -ForegroundColor Yellow
                            }
                            else {
                                Write-Warning "    Failed to create assignment: $_"
                            }
                        }
                    }
                }
                
                Write-Host "  Success!" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to process $($manifestFile.Name): $_"
            }
        }
    }
}

# Export function (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -ne 'ExternalScript') {
    Export-ModuleMember -Function Import-Applications-Package -ErrorAction SilentlyContinue
}
