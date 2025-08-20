function Connect-GraphAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$TenantId = $env:AZURE_TENANT_ID,
        
        [Parameter(Mandatory=$false)]
        [string]$ClientId = $env:AZURE_CLIENT_ID,
        
        [Parameter(Mandatory=$false)]
        [string]$ClientSecret = $env:AZURE_CLIENT_SECRET
    )
    
    try {
        # Validate parameters
        if ([string]::IsNullOrEmpty($TenantId) -or 
            [string]::IsNullOrEmpty($ClientId) -or 
            [string]::IsNullOrEmpty($ClientSecret)) {
            throw "Missing required authentication parameters"
        }
        
        # Create credential object
        $secureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($ClientId, $secureClientSecret)
        
        # Connect to Graph
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $credential -NoWelcome
        
        # Verify connection
        $context = Get-MgContext
        if ($null -eq $context) {
            throw "Failed to establish Graph connection"
        }
        
        Write-Verbose "Successfully connected to Graph API for tenant: $($context.TenantId)"
        return $true
    }
    catch {
        Write-Error "Failed to connect to Graph API: $_"
        return $false
    }
}
