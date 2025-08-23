function Export-Applications {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExportPath = "exports/Applications",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAssignments = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeIcon = $true
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
            # Get all Win32 apps
            Write-Verbose "Retrieving Win32 applications..."
            
            # Using Graph API to get Win32 apps
            $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')"
            $apps = Invoke-MgGraphRequest -Uri $uri -Method GET
            
            $exportedApps = @()
            
            foreach ($app in $apps.value) {
                Write-Verbose "Processing app: $($app.displayName)"
                
                # Get full app details
                $fullAppUri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$($app.id)"
                $fullApp = Invoke-MgGraphRequest -Uri $fullAppUri -Method GET
                
                # Create manifest structure based on ERD design
                $manifest = @{
                    id = $fullApp.id
                    displayName = $fullApp.displayName
                    description = $fullApp.description
                    publisher = $fullApp.publisher
                    version = $fullApp.displayVersion
                    createdDateTime = $fullApp.createdDateTime
                    lastModifiedDateTime = $fullApp.lastModifiedDateTime
                    fileName = $fullApp.fileName
                    size = $fullApp.size
                    installCommandLine = $fullApp.installCommandLine
                    uninstallCommandLine = $fullApp.uninstallCommandLine
                    setupFilePath = $fullApp.setupFilePath
                    minimumFreeDiskSpaceInMB = $fullApp.minimumFreeDiskSpaceInMB
                    minimumMemoryInMB = $fullApp.minimumMemoryInMB
                    minimumNumberOfProcessors = $fullApp.minimumNumberOfProcessors
                    minimumCpuSpeedInMHz = $fullApp.minimumCpuSpeedInMHz
                    applicableArchitectures = $fullApp.applicableArchitectures
                    minimumSupportedOperatingSystem = $fullApp.minimumSupportedOperatingSystem
                    requiresReboot = $fullApp.requiresReboot
                    msiInformation = $fullApp.msiInformation
                    returnCodes = $fullApp.returnCodes
                    rules = $fullApp.rules
                    detectionRules = @()
                    requirementRules = @()
                }
                
                # Get detection rules
                $detectionRulesUri = "$fullAppUri/detectionRules"
                $detectionRules = Invoke-MgGraphRequest -Uri $detectionRulesUri -Method GET
                if ($detectionRules.value) {
                    $manifest.detectionRules = $detectionRules.value
                }
                
                # Get requirement rules
                $requirementRulesUri = "$fullAppUri/requirementRules"
                $requirementRules = Invoke-MgGraphRequest -Uri $requirementRulesUri -Method GET
                if ($requirementRules.value) {
                    $manifest.requirementRules = $requirementRules.value
                }
                
                # Get assignments if requested
                if ($IncludeAssignments) {
                    $assignmentsUri = "$fullAppUri/assignments"
                    $assignments = Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET
                    
                    $assignmentDetails = @()
                    foreach ($assignment in $assignments.value) {
                        $assignmentInfo = @{
                            id = $assignment.id
                            intent = $assignment.intent
                            source = $assignment.source
                            target = $assignment.target
                        }
                        
                        # Try to resolve group names if target is a group
                        if ($assignment.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') {
                            $groupId = $assignment.target.groupId
                            try {
                                $group = Get-MgGroup -GroupId $groupId -ErrorAction SilentlyContinue
                                if ($group) {
                                    $assignmentInfo.targetGroupName = $group.DisplayName
                                }
                            }
                            catch {
                                Write-Verbose "Could not resolve group name for ID: $groupId"
                            }
                        }
                        
                        $assignmentDetails += $assignmentInfo
                    }
                    
                    $manifest.assignments = $assignmentDetails
                }
                
                # Get icon if requested and available
                if ($IncludeIcon -and $fullApp.largeIcon) {
                    try {
                        $iconFileName = "$($app.displayName -replace '[^\w\s-]', '_')_icon.png"
                        $iconPath = Join-Path $ExportPath $iconFileName
                        
                        # Decode base64 icon data
                        $iconBytes = [Convert]::FromBase64String($fullApp.largeIcon.value)
                        [System.IO.File]::WriteAllBytes($iconPath, $iconBytes)
                        
                        $manifest.iconFile = $iconFileName
                        Write-Verbose "Exported icon for $($app.displayName)"
                    }
                    catch {
                        Write-Warning "Failed to export icon for $($app.displayName): $_"
                    }
                }
                
                # Note about content file
                $manifest.note = "Application content (.intunewin file) cannot be exported via Graph API. Original installer files must be maintained separately for re-import."
                
                # Save manifest to file
                $fileName = "$($app.displayName -replace '[^\w\s-]', '_')_$($app.id).json"
                $filePath = Join-Path $ExportPath $fileName
                
                # Convert to JSON with proper formatting
                $json = $manifest | ConvertTo-Json -Depth 10
                
                # Pretty print if not compressed
                if ($env:EXPORT_PRETTY_PRINT -ne 'false') {
                    $json = $manifest | ConvertTo-Json -Depth 10
                }
                
                $json | Out-File -FilePath $filePath -Encoding UTF8
                
                $exportedApps += [PSCustomObject]@{
                    Id = $app.id
                    DisplayName = $app.displayName
                    Version = $fullApp.displayVersion
                    FilePath = $filePath
                    Status = "Exported"
                }
                
                Write-Verbose "Exported application: $($app.displayName)"
            }
            
            return $exportedApps
        }
        catch {
            Write-Error "Failed to export applications: $_"
            throw
        }
    }
}
