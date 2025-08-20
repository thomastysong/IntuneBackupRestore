# Intune Configuration Backup Development Plan (AI Agent Implementation Guide)

## Meta Instructions
```yaml
agent_instructions:
  execution_mode: sequential_with_validation
  error_handling: stop_on_critical_failure
  testing_approach: incremental_with_validation
  documentation: inline_with_code
  commit_frequency: per_completed_module
```

## Phase 0: Repository Initialization
```yaml
tasks:
  - id: init_git_repo
    command: |
      cd C:\repos\IntuneBackupRestore
      git init
      git config user.name "Intune Backup Bot"
      git config user.email "intune-backup@company.com"
    validation:
      - check: .git directory exists
      - check: git status returns valid response
    
  - id: create_gitignore
    create_file: .gitignore
    content: |
      # Environment and secrets
      .env
      *.env.*
      
      # Credentials
      *.pfx
      *.cer
      *.key
      client_secret.txt
      
      # Test data
      test_exports/
      temp/
      
      # Python
      __pycache__/
      *.py[cod]
      venv/
      .venv/
      
      # PowerShell
      *.ps1.bak
      
      # IDE
      .vscode/
      .idea/
      
      # Logs
      *.log
      logs/
    
  - id: create_directory_structure
    directories:
      - src/
      - src/modules/
      - src/modules/powershell/
      - src/modules/python/
      - src/utils/
      - exports/
      - exports/CompliancePolicies/
      - exports/ConfigurationProfiles/
      - exports/Applications/
      - exports/Scripts/
      - exports/Roles/
      - exports/Assignments/
      - change_logs/
      - tests/
      - tests/unit/
      - tests/integration/
      - .github/
      - .github/workflows/
      - docs/
      - scripts/
    
  - id: initial_commit
    commands:
      - git add .
      - git commit -m "Initial repository structure for Intune Configuration Backup"
    validation:
      - check: git log shows commit
```

## Phase 1: Environment Configuration
```yaml
tasks:
  - id: create_env_template
    create_file: .env.template
    content: |
      # Azure AD App Registration
      AZURE_TENANT_ID=your-tenant-id
      AZURE_CLIENT_ID=your-client-id
      AZURE_CLIENT_SECRET=your-client-secret
      
      # Graph API Configuration
      GRAPH_API_VERSION=v1.0
      GRAPH_API_BETA_ENABLED=false
      
      # Export Configuration
      EXPORT_FORMAT=json
      EXPORT_PRETTY_PRINT=true
      EXPORT_INCLUDE_ASSIGNMENTS=true
      
      # GitHub Configuration
      GITHUB_TOKEN=your-github-token
      GITHUB_REPO_OWNER=your-org
      GITHUB_REPO_NAME=IntuneBackupRestore
      
      # Notification Configuration
      NOTIFICATION_ENABLED=false
      NOTIFICATION_WEBHOOK_URL=
    
  - id: create_config_module
    create_file: src/utils/config.py
    content: |
      import os
      from pathlib import Path
      from typing import Dict, Any
      from dotenv import load_dotenv
      
      class Config:
          def __init__(self):
              load_dotenv()
              self.validate_required_vars()
          
          @property
          def azure_config(self) -> Dict[str, str]:
              return {
                  'tenant_id': os.getenv('AZURE_TENANT_ID'),
                  'client_id': os.getenv('AZURE_CLIENT_ID'),
                  'client_secret': os.getenv('AZURE_CLIENT_SECRET')
              }
          
          @property
          def graph_config(self) -> Dict[str, Any]:
              return {
                  'api_version': os.getenv('GRAPH_API_VERSION', 'v1.0'),
                  'beta_enabled': os.getenv('GRAPH_API_BETA_ENABLED', 'false').lower() == 'true'
              }
          
          @property
          def export_config(self) -> Dict[str, Any]:
              return {
                  'format': os.getenv('EXPORT_FORMAT', 'json'),
                  'pretty_print': os.getenv('EXPORT_PRETTY_PRINT', 'true').lower() == 'true',
                  'include_assignments': os.getenv('EXPORT_INCLUDE_ASSIGNMENTS', 'true').lower() == 'true'
              }
          
          def validate_required_vars(self):
              required = ['AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_CLIENT_SECRET']
              missing = [var for var in required if not os.getenv(var)]
              if missing:
                  raise ValueError(f"Missing required environment variables: {', '.join(missing)}")
    
  - id: create_requirements
    create_file: requirements.txt
    content: |
      # Core dependencies
      msal==1.24.1
      requests==2.31.0
      python-dotenv==1.0.0
      
      # Graph SDK
      msgraph-sdk==1.0.0
      
      # JSON/YAML processing
      pyyaml==6.0.1
      jsonschema==4.19.1
      deepdiff==6.5.0
      
      # Testing
      pytest==7.4.3
      pytest-mock==3.12.0
      pytest-asyncio==0.21.1
      
      # Utilities
      click==8.1.7
      colorama==0.4.6
      tabulate==0.9.0
    
  - id: create_powershell_requirements
    create_file: scripts/Install-Requirements.ps1
    content: |
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
```

## Phase 2: Authentication Module Development
```yaml
tasks:
  - id: create_auth_module_python
    create_file: src/utils/auth.py
    content: |
      import msal
      from typing import Optional, Dict
      import logging
      from .config import Config
      
      class GraphAuthenticator:
          def __init__(self, config: Config):
              self.config = config
              self.logger = logging.getLogger(__name__)
              self._token_cache = {}
              self._app = self._create_msal_app()
          
          def _create_msal_app(self) -> msal.ConfidentialClientApplication:
              azure_config = self.config.azure_config
              return msal.ConfidentialClientApplication(
                  azure_config['client_id'],
                  authority=f"https://login.microsoftonline.com/{azure_config['tenant_id']}",
                  client_credential=azure_config['client_secret']
              )
          
          def get_token(self, scopes: Optional[list] = None) -> str:
              if scopes is None:
                  scopes = ["https://graph.microsoft.com/.default"]
              
              cache_key = "|".join(sorted(scopes))
              
              # Check cache
              if cache_key in self._token_cache:
                  token_data = self._token_cache[cache_key]
                  # Simple validation - in production, check expiry
                  if token_data:
                      return token_data['access_token']
              
              # Acquire new token
              result = self._app.acquire_token_for_client(scopes=scopes)
              
              if "access_token" in result:
                  self._token_cache[cache_key] = result
                  self.logger.info("Successfully acquired token")
                  return result['access_token']
              else:
                  error_msg = f"Failed to acquire token: {result.get('error_description', 'Unknown error')}"
                  self.logger.error(error_msg)
                  raise Exception(error_msg)
    
    validation:
      - test_file: tests/unit/test_auth.py
      - test_content: |
          import pytest
          from unittest.mock import Mock, patch
          from src.utils.auth import GraphAuthenticator
          from src.utils.config import Config
          
          def test_graph_authenticator_init():
              mock_config = Mock(spec=Config)
              mock_config.azure_config = {
                  'tenant_id': 'test-tenant',
                  'client_id': 'test-client',
                  'client_secret': 'test-secret'
              }
              
              auth = GraphAuthenticator(mock_config)
              assert auth.config == mock_config
              assert auth._token_cache == {}
  
  - id: create_auth_module_powershell
    create_file: src/modules/powershell/Connect-GraphAPI.ps1
    content: |
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
```

## Phase 3: Export Module Development
```yaml
module_development_order:
  - compliance_policies
  - configuration_profiles
  - applications
  - scripts
  - roles
  - assignments

compliance_policies_module:
  - id: create_compliance_export
    create_file: src/modules/python/export_compliance_policies.py
    content: |
      import json
      import logging
      from pathlib import Path
      from typing import List, Dict, Any
      import requests
      from ...utils.auth import GraphAuthenticator
      from ...utils.config import Config
      
      class CompliancePolicyExporter:
          def __init__(self, config: Config, authenticator: GraphAuthenticator):
              self.config = config
              self.auth = authenticator
              self.logger = logging.getLogger(__name__)
              self.export_path = Path("exports/CompliancePolicies")
              self.export_path.mkdir(parents=True, exist_ok=True)
          
          def export_all(self) -> List[Dict[str, Any]]:
              """Export all compliance policies"""
              policies = self._get_all_policies()
              exported = []
              
              for policy in policies:
                  try:
                      full_policy = self._get_policy_details(policy['id'])
                      if self.config.export_config['include_assignments']:
                          full_policy['assignments'] = self._get_policy_assignments(policy['id'])
                      
                      self._save_policy(full_policy)
                      exported.append(full_policy)
                      self.logger.info(f"Exported compliance policy: {policy['displayName']}")
                  except Exception as e:
                      self.logger.error(f"Failed to export policy {policy['id']}: {e}")
              
              return exported
          
          def _get_all_policies(self) -> List[Dict[str, Any]]:
              """Retrieve all compliance policies from Graph API"""
              token = self.auth.get_token()
              headers = {'Authorization': f'Bearer {token}'}
              
              endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceManagement/deviceCompliancePolicies"
              response = requests.get(endpoint, headers=headers)
              response.raise_for_status()
              
              return response.json().get('value', [])
          
          def _get_policy_details(self, policy_id: str) -> Dict[str, Any]:
              """Get full details of a specific policy"""
              token = self.auth.get_token()
              headers = {'Authorization': f'Bearer {token}'}
              
              endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceManagement/deviceCompliancePolicies/{policy_id}"
              response = requests.get(endpoint, headers=headers)
              response.raise_for_status()
              
              return response.json()
          
          def _get_policy_assignments(self, policy_id: str) -> List[Dict[str, Any]]:
              """Get assignments for a policy"""
              token = self.auth.get_token()
              headers = {'Authorization': f'Bearer {token}'}
              
              endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceManagement/deviceCompliancePolicies/{policy_id}/assignments"
              response = requests.get(endpoint, headers=headers)
              
              if response.status_code == 404:
                  return []
              
              response.raise_for_status()
              return response.json().get('value', [])
          
          def _save_policy(self, policy: Dict[str, Any]):
              """Save policy to file"""
              filename = f"{policy['displayName'].replace('/', '_')}_{policy['id']}.json"
              filepath = self.export_path / filename
              
              with open(filepath, 'w', encoding='utf-8') as f:
                  if self.config.export_config['pretty_print']:
                      json.dump(policy, f, indent=2, ensure_ascii=False)
                  else:
                      json.dump(policy, f, ensure_ascii=False)
    
    validation:
      - check: File created successfully
      - test: Unit test for each method
      - integration_test: Test with mock Graph API responses

configuration_profiles_module:
  - id: create_config_profile_export
    create_file: src/modules/powershell/Export-ConfigurationProfiles.ps1
    content: |
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
                          $exportProfile | Add-Member -NotePropertyName 'assignments' -NotePropertyValue $assignments
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

# Additional modules follow similar pattern...
```

## Phase 4: Change Detection System
```yaml
tasks:
  - id: create_diff_generator
    create_file: src/utils/diff_generator.py
    content: |
      import json
      from pathlib import Path
      from datetime import datetime
      from typing import Dict, List, Any, Optional
      from deepdiff import DeepDiff
      import logging
      
      class DiffGenerator:
          def __init__(self, export_base_path: str = "exports"):
              self.export_base_path = Path(export_base_path)
              self.logger = logging.getLogger(__name__)
              self.change_log_path = Path("change_logs")
              self.change_log_path.mkdir(exist_ok=True)
          
          def generate_change_log(self, previous_commit: Optional[str] = None) -> Dict[str, Any]:
              """Generate change log by comparing current exports with previous state"""
              changes = {
                  "timestamp": datetime.utcnow().isoformat() + "Z",
                  "commit": previous_commit,
                  "added": [],
                  "removed": [],
                  "modified": []
              }
              
              # Get all current files
              current_files = self._get_all_export_files()
              
              # Get previous files (from git history or cache)
              previous_files = self._get_previous_files(previous_commit)
              
              # Compare file sets
              current_set = {f.relative_to(self.export_base_path): f for f in current_files}
              previous_set = {f.relative_to(self.export_base_path): f for f in previous_files}
              
              # Find added files
              added_paths = set(current_set.keys()) - set(previous_set.keys())
              for path in added_paths:
                  changes["added"].append(self._create_change_entry(current_set[path], "added"))
              
              # Find removed files
              removed_paths = set(previous_set.keys()) - set(current_set.keys())
              for path in removed_paths:
                  changes["removed"].append(self._create_change_entry(previous_set[path], "removed"))
              
              # Find modified files
              common_paths = set(current_set.keys()) & set(previous_set.keys())
              for path in common_paths:
                  diff = self._compare_files(previous_set[path], current_set[path])
                  if diff:
                      changes["modified"].append(diff)
              
              # Save change log
              self._save_change_log(changes)
              
              return changes
          
          def _compare_files(self, old_file: Path, new_file: Path) -> Optional[Dict[str, Any]]:
              """Compare two JSON files and return differences"""
              try:
                  with open(old_file, 'r', encoding='utf-8') as f:
                      old_data = json.load(f)
                  
                  with open(new_file, 'r', encoding='utf-8') as f:
                      new_data = json.load(f)
                  
                  # Use DeepDiff for detailed comparison
                  diff = DeepDiff(old_data, new_data, ignore_order=True, 
                                 exclude_paths=["root['lastModifiedDateTime']"])
                  
                  if diff:
                      return {
                          "objectType": self._get_object_type(new_file),
                          "displayName": new_data.get('displayName', 'Unknown'),
                          "objectId": new_data.get('id', 'Unknown'),
                          "changes": self._format_deepdiff(diff)
                      }
              except Exception as e:
                  self.logger.error(f"Error comparing files {old_file} and {new_file}: {e}")
              
              return None
          
          def _format_deepdiff(self, diff: DeepDiff) -> Dict[str, Any]:
              """Format DeepDiff output for our change log"""
              formatted = {}
              
              if 'values_changed' in diff:
                  for path, change in diff['values_changed'].items():
                      key = path.split("'")[1] if "'" in path else path
                      formatted[key] = {
                          "old": change['old_value'],
                          "new": change['new_value']
                      }
              
              return formatted
          
          def _save_change_log(self, changes: Dict[str, Any]):
              """Save change log to file"""
              timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
              filename = f"changelog_{timestamp}.json"
              filepath = self.change_log_path / filename
              
              with open(filepath, 'w', encoding='utf-8') as f:
                  json.dump(changes, f, indent=2, ensure_ascii=False)
              
              # Also save as latest.json for easy access
              latest_path = self.change_log_path / "latest.json"
              with open(latest_path, 'w', encoding='utf-8') as f:
                  json.dump(changes, f, indent=2, ensure_ascii=False)
```

## Phase 5: GitHub Actions Workflow
```yaml
tasks:
  - id: create_main_workflow
    create_file: .github/workflows/intune-backup.yml
    content: |
      name: Intune Configuration Backup
      
      on:
        schedule:
          # Run every Monday at 00:00 UTC
          - cron: '0 0 * * 1'
        workflow_dispatch:
          inputs:
            include_beta_endpoints:
              description: 'Include beta Graph API endpoints'
              required: false
              type: boolean
              default: false
      
      env:
        AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
        AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
        AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
      
      jobs:
        backup:
          runs-on: windows-latest
          permissions:
            contents: write
          
          steps:
            - name: Checkout repository
              uses: actions/checkout@v4
              with:
                fetch-depth: 2  # Need previous commit for diff
            
            - name: Set up Python
              uses: actions/setup-python@v4
              with:
                python-version: '3.11'
            
            - name: Install Python dependencies
              run: |
                python -m pip install --upgrade pip
                pip install -r requirements.txt
            
            - name: Set up PowerShell modules
              shell: pwsh
              run: |
                ./scripts/Install-Requirements.ps1
            
            - name: Run compliance policies export
              run: |
                python -m src.export_runner --module compliance_policies
            
            - name: Run configuration profiles export
              shell: pwsh
              run: |
                Import-Module ./src/modules/powershell/Connect-GraphAPI.ps1
                Import-Module ./src/modules/powershell/Export-ConfigurationProfiles.ps1
                
                Connect-GraphAPI
                Export-ConfigurationProfiles
            
            - name: Run applications export
              run: |
                python -m src.export_runner --module applications
            
            - name: Run scripts export
              shell: pwsh
              run: |
                Import-Module ./src/modules/powershell/Export-IntuneScripts.ps1
                Export-IntuneScripts
            
            - name: Generate change log
              run: |
                python -m src.generate_changelog
            
            - name: Commit changes
              run: |
                git config --local user.email "intune-backup@github.com"
                git config --local user.name "Intune Backup Bot"
                
                git add exports/ change_logs/
                
                # Check if there are changes to commit
                if git diff --staged --quiet; then
                  echo "No changes to commit"
                else
                  git commit -m "Intune backup: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
                  git push
                fi
            
            - name: Upload artifacts
              if: always()
              uses: actions/upload-artifact@v3
              with:
                name: backup-logs
                path: |
                  logs/
                  change_logs/latest.json
```

## Phase 6: Testing Framework
```yaml
test_structure:
  - id: create_test_framework
    create_file: tests/test_runner.py
    content: |
      import pytest
      import sys
      from pathlib import Path
      
      # Add src to path
      sys.path.insert(0, str(Path(__file__).parent.parent))
      
      def run_unit_tests():
          """Run unit tests"""
          return pytest.main(['-v', 'tests/unit/', '--cov=src'])
      
      def run_integration_tests():
          """Run integration tests"""
          return pytest.main(['-v', 'tests/integration/'])
      
      def run_all_tests():
          """Run all tests"""
          return pytest.main(['-v', 'tests/', '--cov=src'])
      
      if __name__ == "__main__":
          import argparse
          parser = argparse.ArgumentParser()
          parser.add_argument('--type', choices=['unit', 'integration', 'all'], default='all')
          args = parser.parse_args()
          
          if args.type == 'unit':
              sys.exit(run_unit_tests())
          elif args.type == 'integration':
              sys.exit(run_integration_tests())
          else:
              sys.exit(run_all_tests())

  - id: create_mock_data_generator
    create_file: tests/utils/mock_data.py
    content: |
      import json
      from pathlib import Path
      from typing import Dict, Any, List
      import uuid
      
      class MockIntuneDataGenerator:
          @staticmethod
          def generate_compliance_policy() -> Dict[str, Any]:
              return {
                  "id": str(uuid.uuid4()),
                  "displayName": f"Test Compliance Policy {uuid.uuid4().hex[:8]}",
                  "description": "Mock compliance policy for testing",
                  "@odata.type": "#microsoft.graph.windows10CompliancePolicy",
                  "passwordRequired": True,
                  "passwordMinimumLength": 8,
                  "passwordRequiredType": "alphanumeric",
                  "storageRequireEncryption": True,
                  "osMinimumVersion": "10.0.19041"
              }
          
          @staticmethod
          def generate_configuration_profile() -> Dict[str, Any]:
              return {
                  "id": str(uuid.uuid4()),
                  "displayName": f"Test Config Profile {uuid.uuid4().hex[:8]}",
                  "description": "Mock configuration profile for testing",
                  "@odata.type": "#microsoft.graph.windows10GeneralConfiguration",
                  "passwordBlockSimple": True,
                  "passwordMinimumLength": 8,
                  "passwordRequired": True
              }
```

## Phase 7: Deployment and Validation
```yaml
deployment_steps:
  - id: pre_deployment_validation
    script: |
      # Validate all required files exist
      $requiredFiles = @(
          ".github/workflows/intune-backup.yml",
          "requirements.txt",
          "src/utils/config.py",
          "src/utils/auth.py"
      )
      
      foreach ($file in $requiredFiles) {
          if (!(Test-Path $file)) {
              throw "Required file missing: $file"
          }
      }
      
      # Run tests
      python tests/test_runner.py --type unit
      if ($LASTEXITCODE -ne 0) {
          throw "Unit tests failed"
      }
  
  - id: github_secrets_setup
    manual_steps:
      - instruction: "Navigate to GitHub repository settings"
      - instruction: "Go to Settings > Secrets and variables > Actions"
      - instruction: "Add the following secrets:"
        secrets:
          - AZURE_TENANT_ID
          - AZURE_CLIENT_ID
          - AZURE_CLIENT_SECRET
  
  - id: initial_deployment
    commands:
      - git add .
      - git commit -m "Complete Intune backup solution implementation"
      - git branch -M main
      - git remote add origin https://github.com/YOUR_ORG/IntuneBackupRestore.git
      - git push -u origin main
  
  - id: test_workflow_execution
    manual_step: "Manually trigger the workflow from GitHub Actions tab to validate"
    validation_criteria:
      - Workflow completes successfully
      - Export files are created in exports/ directory
      - Change log is generated in change_logs/
      - Changes are committed back to repository

## Phase 8: Monitoring Setup
```yaml
grafana_integration:
  - id: create_grafana_datasource_config
    create_file: grafana/datasource.json
    content: |
      {
        "name": "Intune Change Logs",
        "type": "simplejson",
        "access": "proxy",
        "url": "https://api.github.com/repos/YOUR_ORG/IntuneBackupRestore/contents/change_logs/latest.json",
        "jsonData": {
          "headers": {
            "Authorization": "Bearer YOUR_GITHUB_TOKEN"
          }
        }
      }
  
  - id: create_grafana_dashboard
    create_file: grafana/dashboard.json
    content: |
      {
        "dashboard": {
          "title": "Intune Configuration Changes",
          "panels": [
            {
              "title": "Recent Changes",
              "type": "table",
              "targets": [
                {
                  "target": "changes"
                }
              ]
            },
            {
              "title": "Change Summary",
              "type": "stat",
              "targets": [
                {
                  "target": "change_count"
                }
              ]
            }
          ]
        }
      }
```

## Validation Criteria
```yaml
success_metrics:
  - all_modules_export_successfully: true
  - change_detection_accuracy: 100%
  - github_actions_success_rate: 100%
  - test_coverage: >= 80%
  - deployment_validation_passed: true
  
completion_checklist:
  - [ ] Azure AD app registration configured
  - [ ] All export modules implemented
  - [ ] Change detection system working
  - [ ] GitHub Actions workflow deployed
  - [ ] Tests passing with good coverage
  - [ ] Initial backup completed successfully
  - [ ] Change logs being generated
  - [ ] Documentation complete
  - [ ] Grafana integration configured (optional)
```

## Error Handling Matrix
```yaml
error_scenarios:
  - scenario: "Graph API authentication failure"
    detection: "MSAL exception or 401 response"
    action: "Retry with exponential backoff, alert on persistent failure"
    
  - scenario: "Export module failure"
    detection: "Exception in export module"
    action: "Continue with other modules, log error, partial backup"
    
  - scenario: "Git commit failure"
    detection: "Git command returns non-zero"
    action: "Retry once, preserve exports locally, alert team"
    
  - scenario: "Rate limiting from Graph API"
    detection: "429 response code"
    action: "Implement backoff, respect retry-after header"
```

## Implementation Notes for AI Agent
```yaml
execution_guidelines:
  - Always validate outputs before proceeding to next phase
  - Implement comprehensive error handling in all modules
  - Use logging extensively for debugging
  - Test each component in isolation before integration
  - Commit working code frequently
  - Document any deviations from plan
  - Prioritize security (never log secrets)
  - Make code modular and reusable
  - Follow language-specific best practices
  - Ensure all paths are cross-platform compatible
```
