# AI Agent Deployment Guide for Intune Backup Solution

## Prerequisites Check
```yaml
required_components:
  - azure_ad_tenant: true
  - intune_license: true
  - github_account: true
  - permissions:
      azure: "Application Administrator or Global Administrator"
      github: "Repository creation and secrets management"
```

## Step 1: Azure AD App Registration
```yaml
task: create_app_registration
platform: Azure Portal
steps:
  - navigate_to: "Azure Active Directory > App registrations"
  - action: "New registration"
  - settings:
      name: "IntuneBackupAutomation"
      supported_account_types: "Single tenant"
      redirect_uri: "Not required"
  - post_creation:
      - record: "Application (client) ID"
      - record: "Directory (tenant) ID"
  - create_secret:
      - navigate_to: "Certificates & secrets"
      - action: "New client secret"
      - description: "IntuneBackup"
      - expires: "24 months"
      - record: "Secret value (IMMEDIATELY - shown only once)"
  - api_permissions:
      - navigate_to: "API permissions"
      - add_permission: "Microsoft Graph"
      - permission_type: "Application permissions"
      - required_permissions:
          - "DeviceManagementConfiguration.Read.All"
          - "DeviceManagementApps.Read.All"
          - "DeviceManagementRBAC.Read.All"
          - "DeviceManagementServiceConfig.Read.All"
          - "Group.Read.All"
      - action: "Grant admin consent"
validation:
  - check: "Admin consent granted shows green checkmark"
  - check: "All permissions show Granted status"
```

## Step 2: GitHub Repository Setup
```yaml
task: github_setup
steps:
  - create_private_repo:
      name: "IntuneBackupRestore"
      visibility: "Private"
      description: "Automated Intune configuration backup"
  - add_secrets:
      navigate_to: "Settings > Secrets and variables > Actions"
      secrets:
        - name: "AZURE_TENANT_ID"
          value: "<from_step_1>"
        - name: "AZURE_CLIENT_ID"
          value: "<from_step_1>"
        - name: "AZURE_CLIENT_SECRET"
          value: "<from_step_1>"
  - push_code:
      commands: |
        git remote add origin https://github.com/YOUR_ORG/IntuneBackupRestore.git
        git branch -M main
        git push -u origin main
```

## Step 3: Initial Test Run
```yaml
task: validate_deployment
steps:
  - trigger_workflow:
      navigate_to: "Actions tab in GitHub"
      workflow: "Intune Configuration Backup"
      action: "Run workflow"
      branch: "main"
  - monitor_execution:
      expected_duration: "2-5 minutes"
      check_logs: true
  - validate_results:
      check_commits: "New commit with exports/"
      check_artifacts: "backup-logs artifact available"
```

## Step 4: Verify Backup Contents
```yaml
task: verify_backup
validations:
  - directory_structure:
      exports/CompliancePolicies/: "Contains JSON files"
      exports/ConfigurationProfiles/: "Contains JSON files"
      change_logs/: "Contains latest.json"
  - file_format:
      type: "JSON"
      encoding: "UTF-8"
      pretty_print: true
  - content_validation:
      contains_id: true
      contains_displayName: true
      no_secrets: true
```

## Step 5: Configure Monitoring (Optional)
```yaml
task: grafana_setup
prerequisites:
  - grafana_instance: "Running and accessible"
  - github_pat: "Personal Access Token with repo read"
steps:
  - import_datasource:
      file: "grafana/datasource.json"
      update_url: "YOUR_ORG"
      update_token: "YOUR_GITHUB_TOKEN"
  - import_dashboard:
      file: "grafana/dashboard.json"
  - test_visualization:
      check: "Change log data appears"
```

## Troubleshooting Commands
```yaml
diagnostics:
  test_auth:
    python: |
      from src.utils.config import Config
      from src.utils.auth import GraphAuthenticator
      config = Config()
      auth = GraphAuthenticator(config)
      token = auth.get_token()
      print("Auth successful" if token else "Auth failed")
  
  test_graph_connection:
    powershell: |
      . ./src/modules/powershell/Connect-GraphAPI.ps1
      Connect-GraphAPI -Verbose
  
  manual_export:
    python: |
      python -m src.export_runner --module compliance_policies
  
  check_logs:
    location: "GitHub Actions run logs"
    key_errors:
      - "401": "Authentication failed - check credentials"
      - "403": "Insufficient permissions - check Graph API permissions"
      - "404": "Endpoint not found - check API version"
```

## Post-Deployment Checklist
```yaml
verify_complete:
  - [ ] App registration created and configured
  - [ ] GitHub secrets configured
  - [ ] Initial workflow run successful
  - [ ] Exports directory populated
  - [ ] Change log generated
  - [ ] No sensitive data exposed
  - [ ] Weekly schedule active
  
maintenance_tasks:
  - monitor: "Weekly workflow runs"
  - rotate: "Client secret before expiry"
  - update: "Modules if Intune APIs change"
  - review: "Change logs weekly"
```

## Common Issues and Resolutions
```yaml
issues:
  - symptom: "Workflow fails with authentication error"
    resolution: 
      - "Verify secrets are correctly set in GitHub"
      - "Check secret hasn't expired"
      - "Ensure no extra spaces in secret values"
  
  - symptom: "No policies exported"
    resolution:
      - "Verify Intune has policies configured"
      - "Check Graph API permissions granted"
      - "Test with Graph Explorer first"
  
  - symptom: "PowerShell module errors"
    resolution:
      - "Ensure using PowerShell 7+"
      - "Run Install-Requirements.ps1 locally first"
      - "Check module versions match requirements"
```
