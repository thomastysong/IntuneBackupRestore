function Import-Applications {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ImportPath,
        
        [Parameter(Mandatory=$false)]
        [string]$SourceFilesPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$UpdateExisting = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateGroups = $false,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$GroupMappingTable = @{}
    )
    
    begin {
        # Ensure connected to Graph
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Not connected to Graph API. Run Connect-GraphAPI first."
        }
        
        # Check if we have the IntuneWin32App module for packaging
        if (!(Get-Module -ListAvailable -Name "IntuneWin32App")) {
            Write-Warning "IntuneWin32App module not found. Installing from PowerShell Gallery..."
            Install-Module -Name IntuneWin32App -Force -Scope CurrentUser
        }
        
        Import-Module IntuneWin32App -Force
        
        # Download Win32 Content Prep Tool if not available
        $contentPrepTool = Join-Path $env:TEMP "IntuneWinAppUtil.exe"
        if (!(Test-Path $contentPrepTool)) {
            Write-Verbose "Downloading Microsoft Win32 Content Prep Tool..."
            $downloadUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $contentPrepTool
        }
    }
    
    process {
        try {
            # Get all JSON manifest files
            $manifestFiles = Get-ChildItem -Path $ImportPath -Filter "*.json" -File
            
            $importedApps = @()
            
            foreach ($manifestFile in $manifestFiles) {
                Write-Verbose "Processing manifest: $($manifestFile.Name)"
                
                # Read and parse manifest
                $manifest = Get-Content -Path $manifestFile.FullName -Raw | ConvertFrom-Json
                
                # Check if app already exists
                $existingApp = $null
                if ($UpdateExisting) {
                    $filter = "displayName eq '$($manifest.displayName)'"
                    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=$filter"
                    $result = Invoke-MgGraphRequest -Uri $uri -Method GET
                    
                    if ($result.value.Count -gt 0) {
                        $existingApp = $result.value[0]
                        Write-Verbose "Found existing app: $($existingApp.displayName) (ID: $($existingApp.id))"
                        
                        # Compare versions
                        if ($existingApp.displayVersion -ge $manifest.version) {
                            Write-Warning "Existing app version ($($existingApp.displayVersion)) is same or newer than manifest version ($($manifest.version)). Skipping..."
                            continue
                        }
                    }
                }
                
                # Prepare app data
                $appData = @{
                    "@odata.type" = "#microsoft.graph.win32LobApp"
                    displayName = $manifest.displayName
                    description = $manifest.description
                    publisher = $manifest.publisher
                    displayVersion = $manifest.version
                    installCommandLine = $manifest.installCommandLine
                    uninstallCommandLine = $manifest.uninstallCommandLine
                    setupFilePath = $manifest.setupFilePath
                    minimumFreeDiskSpaceInMB = $manifest.minimumFreeDiskSpaceInMB
                    minimumMemoryInMB = $manifest.minimumMemoryInMB
                    minimumNumberOfProcessors = $manifest.minimumNumberOfProcessors
                    minimumCpuSpeedInMHz = $manifest.minimumCpuSpeedInMHz
                    applicableArchitectures = $manifest.applicableArchitectures
                    minimumSupportedOperatingSystem = $manifest.minimumSupportedOperatingSystem
                    requiresReboot = $manifest.requiresReboot
                    fileName = $manifest.fileName
                    rules = @()
                    detectionRules = @()
                    requirementRules = @()
                    returnCodes = $manifest.returnCodes
                }
                
                # Package the application if source files are available
                $intunewinFile = $null
                if ($SourceFilesPath -and $manifest.fileName) {
                    $appSourcePath = Join-Path $SourceFilesPath $manifest.displayName
                    if (Test-Path $appSourcePath) {
                        Write-Verbose "Packaging application from: $appSourcePath"
                        
                        # Use IntuneWin32App module to create package
                        $intunewinFile = New-IntuneWin32AppPackage `
                            -SourceFolder $appSourcePath `
                            -SetupFile $manifest.fileName `
                            -OutputFolder $env:TEMP `
                            -IntuneWinAppUtilPath $contentPrepTool
                        
                        if (!$intunewinFile) {
                            throw "Failed to create .intunewin package for $($manifest.displayName)"
                        }
                    }
                    else {
                        Write-Warning "Source files not found at: $appSourcePath. Cannot create package."
                        continue
                    }
                }
                else {
                    Write-Warning "No source files path provided or fileName not specified in manifest. Cannot import $($manifest.displayName)"
                    continue
                }
                
                # Process detection rules
                foreach ($rule in $manifest.detectionRules) {
                    $detectionRule = @{
                        "@odata.type" = $rule.'@odata.type'
                    }
                    
                    # Copy all properties from the rule
                    foreach ($prop in $rule.PSObject.Properties) {
                        if ($prop.Name -ne '@odata.type') {
                            $detectionRule[$prop.Name] = $prop.Value
                        }
                    }
                    
                    $appData.rules += $detectionRule
                    $appData.detectionRules += $detectionRule
                }
                
                # Process requirement rules
                foreach ($rule in $manifest.requirementRules) {
                    $requirementRule = @{
                        "@odata.type" = $rule.'@odata.type'
                    }
                    
                    foreach ($prop in $rule.PSObject.Properties) {
                        if ($prop.Name -ne '@odata.type') {
                            $requirementRule[$prop.Name] = $prop.Value
                        }
                    }
                    
                    $appData.requirementRules += $requirementRule
                }
                
                # Create or update the app
                if ($existingApp) {
                    Write-Verbose "Updating existing app: $($manifest.displayName)"
                    
                    # Update app metadata
                    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$($existingApp.id)"
                    $result = Invoke-MgGraphRequest -Uri $uri -Method PATCH -Body ($appData | ConvertTo-Json -Depth 10)
                    
                    # Upload new content
                    if ($intunewinFile) {
                        # This would require implementing the content upload process
                        Write-Warning "Content update for existing apps not fully implemented. App metadata updated but content not replaced."
                    }
                }
                else {
                    Write-Verbose "Creating new app: $($manifest.displayName)"
                    
                    # Create new app using IntuneWin32App module if available
                    if ($intunewinFile) {
                        # Use the module's Add-IntuneWin32App function
                        $newApp = Add-IntuneWin32App `
                            -FilePath $intunewinFile.Path `
                            -DisplayName $manifest.displayName `
                            -Description $manifest.description `
                            -Publisher $manifest.publisher `
                            -AppVersion $manifest.version `
                            -InstallCommandLine $manifest.installCommandLine `
                            -UninstallCommandLine $manifest.uninstallCommandLine `
                            -InstallExperience "system" `
                            -RestartBehavior "suppress" `
                            -DetectionRule $appData.detectionRules `
                            -RequirementRule $appData.requirementRules `
                            -ReturnCode $appData.returnCodes `
                            -Icon $manifest.iconFile
                        
                        $result = $newApp
                    }
                    else {
                        throw "Cannot create app without .intunewin package"
                    }
                }
                
                # Handle assignments
                if ($manifest.assignments -and $result) {
                    $appId = if ($existingApp) { $existingApp.id } else { $result.id }
                    
                    foreach ($assignment in $manifest.assignments) {
                        try {
                            $targetGroup = $null
                            
                            # Resolve group
                            if ($assignment.targetGroupName) {
                                # Check mapping table first
                                if ($GroupMappingTable.ContainsKey($assignment.targetGroupName)) {
                                    $targetGroupName = $GroupMappingTable[$assignment.targetGroupName]
                                }
                                else {
                                    $targetGroupName = $assignment.targetGroupName
                                }
                                
                                # Find group
                                $filter = "displayName eq '$targetGroupName'"
                                $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=$filter"
                                $groupResult = Invoke-MgGraphRequest -Uri $groupUri -Method GET
                                
                                if ($groupResult.value.Count -gt 0) {
                                    $targetGroup = $groupResult.value[0]
                                }
                                elseif ($CreateGroups) {
                                    # Create the group
                                    Write-Verbose "Creating group: $targetGroupName"
                                    $newGroup = @{
                                        displayName = $targetGroupName
                                        mailEnabled = $false
                                        mailNickname = $targetGroupName -replace '[^\w]', ''
                                        securityEnabled = $true
                                    }
                                    
                                    $targetGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups" -Method POST -Body ($newGroup | ConvertTo-Json)
                                }
                                else {
                                    Write-Warning "Group not found and CreateGroups not enabled: $targetGroupName"
                                    continue
                                }
                            }
                            elseif ($assignment.target.groupId) {
                                $targetGroup = @{ id = $assignment.target.groupId }
                            }
                            
                            if ($targetGroup) {
                                # Create assignment
                                $assignmentData = @{
                                    "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                                    intent = $assignment.intent
                                    target = @{
                                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                                        groupId = $targetGroup.id
                                    }
                                }
                                
                                $assignmentUri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments"
                                Invoke-MgGraphRequest -Uri $assignmentUri -Method POST -Body ($assignmentData | ConvertTo-Json -Depth 10)
                                
                                Write-Verbose "Created assignment for group: $($targetGroup.displayName ?? $targetGroup.id)"
                            }
                        }
                        catch {
                            Write-Warning "Failed to create assignment: $_"
                        }
                    }
                }
                
                # Clean up temp files
                if ($intunewinFile -and (Test-Path $intunewinFile.Path)) {
                    Remove-Item $intunewinFile.Path -Force
                }
                
                $importedApps += [PSCustomObject]@{
                    Id = if ($existingApp) { $existingApp.id } else { $result.id }
                    DisplayName = $manifest.displayName
                    Version = $manifest.version
                    Status = if ($existingApp) { "Updated" } else { "Created" }
                    FilePath = $manifestFile.FullName
                }
            }
            
            return $importedApps
        }
        catch {
            Write-Error "Failed to import applications: $_"
            throw
        }
    }
}
