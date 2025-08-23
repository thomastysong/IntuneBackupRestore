function Export-IntuneScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ExportPath = "exports/Scripts",
        
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
            # Get all device management scripts
            Write-Verbose "Retrieving device management scripts..."
            $scriptsUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceManagementScripts"
            $scripts = Invoke-MgGraphRequest -Uri $scriptsUri -Method GET
            
            # Get all device shell scripts (macOS/Linux)
            Write-Verbose "Retrieving device shell scripts..."
            $shellScriptsUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceShellScripts"
            $shellScripts = Invoke-MgGraphRequest -Uri $shellScriptsUri -Method GET
            
            # Get all device health scripts (Proactive Remediations)
            Write-Verbose "Retrieving device health scripts (Proactive Remediations)..."
            $healthScriptsUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
            $healthScripts = Invoke-MgGraphRequest -Uri $healthScriptsUri -Method GET
            
            $exportedScripts = @()
            
            # Process PowerShell scripts
            foreach ($script in $scripts.value) {
                Write-Verbose "Processing PowerShell script: $($script.displayName)"
                
                # Get full script details including content
                $fullScriptUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceManagementScripts/$($script.id)"
                $fullScript = Invoke-MgGraphRequest -Uri $fullScriptUri -Method GET
                
                # Create script manifest
                $manifest = @{
                    id = $fullScript.id
                    displayName = $fullScript.displayName
                    description = $fullScript.description
                    scriptType = "PowerShell"
                    createdDateTime = $fullScript.createdDateTime
                    lastModifiedDateTime = $fullScript.lastModifiedDateTime
                    runAsAccount = $fullScript.runAsAccount
                    enforceSignatureCheck = $fullScript.enforceSignatureCheck
                    fileName = $fullScript.fileName
                    runAs32Bit = $fullScript.runAs32Bit
                    roleScopeTagIds = $fullScript.roleScopeTagIds
                }
                
                # Decode and save script content
                if ($fullScript.scriptContent) {
                    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($fullScript.scriptContent))
                    $scriptFileName = "$($script.displayName -replace '[^\w\s-]', '_').ps1"
                    $scriptPath = Join-Path $ExportPath $scriptFileName
                    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
                    $manifest.scriptFile = $scriptFileName
                }
                
                # Get assignments if requested
                if ($IncludeAssignments) {
                    $assignmentsUri = "$fullScriptUri/assignments"
                    $assignments = Invoke-MgGraphRequest -Uri $assignmentsUri -Method GET
                    $manifest.assignments = @()
                    
                    foreach ($assignment in $assignments.value) {
                        $assignmentInfo = @{
                            id = $assignment.id
                            target = $assignment.target
                        }
                        
                        # Try to resolve group names
                        if ($assignment.target.'@odata.type' -match 'groupAssignmentTarget') {
                            try {
                                $group = Get-MgGroup -GroupId $assignment.target.groupId -ErrorAction SilentlyContinue
                                if ($group) {
                                    $assignmentInfo.targetGroupName = $group.DisplayName
                                }
                            }
                            catch {
                                Write-Verbose "Could not resolve group name for ID: $($assignment.target.groupId)"
                            }
                        }
                        
                        $manifest.assignments += $assignmentInfo
                    }
                }
                
                # Save manifest
                $manifestFileName = "$($script.displayName -replace '[^\w\s-]', '_')_$($script.id).json"
                $manifestPath = Join-Path $ExportPath $manifestFileName
                $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
                
                $exportedScripts += [PSCustomObject]@{
                    Id = $script.id
                    DisplayName = $script.displayName
                    Type = "PowerShell"
                    FilePath = $manifestPath
                    Status = "Exported"
                }
            }
            
            # Process Shell scripts
            foreach ($script in $shellScripts.value) {
                Write-Verbose "Processing shell script: $($script.displayName)"
                
                # Similar processing for shell scripts
                $fullScriptUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceShellScripts/$($script.id)"
                $fullScript = Invoke-MgGraphRequest -Uri $fullScriptUri -Method GET
                
                $manifest = @{
                    id = $fullScript.id
                    displayName = $fullScript.displayName
                    description = $fullScript.description
                    scriptType = "Shell"
                    createdDateTime = $fullScript.createdDateTime
                    lastModifiedDateTime = $fullScript.lastModifiedDateTime
                    runAsAccount = $fullScript.runAsAccount
                    fileName = $fullScript.fileName
                    roleScopeTagIds = $fullScript.roleScopeTagIds
                }
                
                # Save script content
                if ($fullScript.scriptContent) {
                    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($fullScript.scriptContent))
                    $scriptFileName = "$($script.displayName -replace '[^\w\s-]', '_').sh"
                    $scriptPath = Join-Path $ExportPath $scriptFileName
                    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
                    $manifest.scriptFile = $scriptFileName
                }
                
                # Save manifest
                $manifestFileName = "$($script.displayName -replace '[^\w\s-]', '_')_$($script.id).json"
                $manifestPath = Join-Path $ExportPath $manifestFileName
                $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
                
                $exportedScripts += [PSCustomObject]@{
                    Id = $script.id
                    DisplayName = $script.displayName
                    Type = "Shell"
                    FilePath = $manifestPath
                    Status = "Exported"
                }
            }
            
            # Process Proactive Remediation scripts
            foreach ($script in $healthScripts.value) {
                Write-Verbose "Processing proactive remediation: $($script.displayName)"
                
                $fullScriptUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)"
                $fullScript = Invoke-MgGraphRequest -Uri $fullScriptUri -Method GET
                
                $manifest = @{
                    id = $fullScript.id
                    displayName = $fullScript.displayName
                    description = $fullScript.description
                    scriptType = "ProactiveRemediation"
                    createdDateTime = $fullScript.createdDateTime
                    lastModifiedDateTime = $fullScript.lastModifiedDateTime
                    runAsAccount = $fullScript.runAsAccount
                    enforceSignatureCheck = $fullScript.enforceSignatureCheck
                    runAs32Bit = $fullScript.runAs32Bit
                    isGlobalScript = $fullScript.isGlobalScript
                    roleScopeTagIds = $fullScript.roleScopeTagIds
                }
                
                # Save detection script
                if ($fullScript.detectionScriptContent) {
                    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($fullScript.detectionScriptContent))
                    $scriptFileName = "$($script.displayName -replace '[^\w\s-]', '_')_detection.ps1"
                    $scriptPath = Join-Path $ExportPath $scriptFileName
                    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
                    $manifest.detectionScriptFile = $scriptFileName
                }
                
                # Save remediation script
                if ($fullScript.remediationScriptContent) {
                    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($fullScript.remediationScriptContent))
                    $scriptFileName = "$($script.displayName -replace '[^\w\s-]', '_')_remediation.ps1"
                    $scriptPath = Join-Path $ExportPath $scriptFileName
                    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
                    $manifest.remediationScriptFile = $scriptFileName
                }
                
                # Save manifest
                $manifestFileName = "$($script.displayName -replace '[^\w\s-]', '_')_$($script.id).json"
                $manifestPath = Join-Path $ExportPath $manifestFileName
                $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding UTF8
                
                $exportedScripts += [PSCustomObject]@{
                    Id = $script.id
                    DisplayName = $script.displayName
                    Type = "ProactiveRemediation"
                    FilePath = $manifestPath
                    Status = "Exported"
                }
            }
            
            return $exportedScripts
        }
        catch {
            Write-Error "Failed to export Intune scripts: $_"
            throw
        }
    }
}
