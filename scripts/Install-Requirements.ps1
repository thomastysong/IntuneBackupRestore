#Requires -Version 7.0

Write-Host "Installing PowerShell requirements..." -ForegroundColor Green

# Install required modules
$modules = @(
    @{Name = 'Microsoft.Graph'; RequiredVersion = '2.10.0'},
    @{Name = 'Microsoft.Graph.Intune'; RequiredVersion = '6.1907.1.0'},
    @{Name = 'Pester'; RequiredVersion = '5.5.0'}
)

foreach ($module in $modules) {
    if (!(Get-Module -ListAvailable -Name $module.Name | Where-Object {$_.Version -eq $module.RequiredVersion})) {
        Write-Host "Installing $($module.Name) v$($module.RequiredVersion)..." -ForegroundColor Yellow
        Install-Module @module -Force -AllowClobber -Scope CurrentUser
    } else {
        Write-Host "$($module.Name) v$($module.RequiredVersion) already installed" -ForegroundColor Green
    }
}
