import json
import logging
import base64
from pathlib import Path
from typing import List, Dict, Any, Optional
import requests
from ...utils.auth import GraphAuthenticator
from ...utils.config import Config


class ApplicationExporter:
    def __init__(self, config: Config, authenticator: GraphAuthenticator):
        self.config = config
        self.auth = authenticator
        self.logger = logging.getLogger(__name__)
        self.export_path = Path("exports/Applications")
        self.export_path.mkdir(parents=True, exist_ok=True)
    
    def export_all(self) -> List[Dict[str, Any]]:
        """Export all Win32 applications"""
        apps = self._get_all_win32_apps()
        exported = []
        
        for app in apps:
            try:
                full_app = self._get_app_details(app['id'])
                
                # Build manifest
                manifest = self._build_manifest(full_app)
                
                # Get assignments if requested
                if self.config.export_config['include_assignments']:
                    manifest['assignments'] = self._get_app_assignments(app['id'])
                
                # Export icon if available
                if full_app.get('largeIcon'):
                    self._export_icon(full_app['largeIcon'], app['displayName'])
                    manifest['iconFile'] = f"{self._sanitize_filename(app['displayName'])}_icon.png"
                
                # Add note about content limitations
                manifest['note'] = "Application content (.intunewin file) cannot be exported via Graph API. Original installer files must be maintained separately for re-import."
                
                # Save manifest
                self._save_manifest(manifest, app['displayName'], app['id'])
                exported.append({
                    'id': app['id'],
                    'displayName': app['displayName'],
                    'version': full_app.get('displayVersion', 'Unknown'),
                    'status': 'Exported'
                })
                
                self.logger.info(f"Exported application: {app['displayName']}")
            except Exception as e:
                self.logger.error(f"Failed to export app {app['id']}: {e}")
        
        return exported
    
    def _get_all_win32_apps(self) -> List[Dict[str, Any]]:
        """Retrieve all Win32 apps from Graph API"""
        token = self.auth.get_token()
        headers = {'Authorization': f'Bearer {token}'}
        
        # Filter for Win32 LOB apps
        endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceAppManagement/mobileApps"
        params = {"$filter": "isof('microsoft.graph.win32LobApp')"}
        
        response = requests.get(endpoint, headers=headers, params=params)
        response.raise_for_status()
        
        return response.json().get('value', [])
    
    def _get_app_details(self, app_id: str) -> Dict[str, Any]:
        """Get full details of a specific app"""
        token = self.auth.get_token()
        headers = {'Authorization': f'Bearer {token}'}
        
        endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceAppManagement/mobileApps/{app_id}"
        response = requests.get(endpoint, headers=headers)
        response.raise_for_status()
        
        app_data = response.json()
        
        # Get detection rules
        detection_endpoint = f"{endpoint}/detectionRules"
        detection_response = requests.get(detection_endpoint, headers=headers)
        if detection_response.status_code == 200:
            app_data['detectionRules'] = detection_response.json().get('value', [])
        
        # Get requirement rules
        requirement_endpoint = f"{endpoint}/requirementRules"
        requirement_response = requests.get(requirement_endpoint, headers=headers)
        if requirement_response.status_code == 200:
            app_data['requirementRules'] = requirement_response.json().get('value', [])
        
        return app_data
    
    def _get_app_assignments(self, app_id: str) -> List[Dict[str, Any]]:
        """Get assignments for an app"""
        token = self.auth.get_token()
        headers = {'Authorization': f'Bearer {token}'}
        
        endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/deviceAppManagement/mobileApps/{app_id}/assignments"
        response = requests.get(endpoint, headers=headers)
        response.raise_for_status()
        
        assignments = []
        for assignment in response.json().get('value', []):
            assignment_info = {
                'id': assignment['id'],
                'intent': assignment['intent'],
                'source': assignment.get('source', 'direct'),
                'target': assignment['target']
            }
            
            # Try to resolve group names
            if assignment['target'].get('@odata.type') == '#microsoft.graph.groupAssignmentTarget':
                group_id = assignment['target']['groupId']
                try:
                    group_endpoint = f"https://graph.microsoft.com/{self.config.graph_config['api_version']}/groups/{group_id}"
                    group_response = requests.get(group_endpoint, headers=headers)
                    if group_response.status_code == 200:
                        assignment_info['targetGroupName'] = group_response.json().get('displayName')
                except Exception as e:
                    self.logger.debug(f"Could not resolve group name for {group_id}: {e}")
            
            assignments.append(assignment_info)
        
        return assignments
    
    def _build_manifest(self, app: Dict[str, Any]) -> Dict[str, Any]:
        """Build manifest structure from app data"""
        manifest = {
            'id': app['id'],
            'displayName': app['displayName'],
            'description': app.get('description', ''),
            'publisher': app.get('publisher', ''),
            'version': app.get('displayVersion', ''),
            'createdDateTime': app.get('createdDateTime'),
            'lastModifiedDateTime': app.get('lastModifiedDateTime'),
            'fileName': app.get('fileName'),
            'size': app.get('size'),
            'installCommandLine': app.get('installCommandLine'),
            'uninstallCommandLine': app.get('uninstallCommandLine'),
            'setupFilePath': app.get('setupFilePath'),
            'minimumFreeDiskSpaceInMB': app.get('minimumFreeDiskSpaceInMB'),
            'minimumMemoryInMB': app.get('minimumMemoryInMB'),
            'minimumNumberOfProcessors': app.get('minimumNumberOfProcessors'),
            'minimumCpuSpeedInMHz': app.get('minimumCpuSpeedInMHz'),
            'applicableArchitectures': app.get('applicableArchitectures', []),
            'minimumSupportedOperatingSystem': app.get('minimumSupportedOperatingSystem', {}),
            'requiresReboot': app.get('requiresReboot', False),
            'msiInformation': app.get('msiInformation'),
            'returnCodes': app.get('returnCodes', []),
            'rules': app.get('rules', []),
            'detectionRules': app.get('detectionRules', []),
            'requirementRules': app.get('requirementRules', [])
        }
        
        # Remove None values for cleaner JSON
        manifest = {k: v for k, v in manifest.items() if v is not None}
        
        return manifest
    
    def _export_icon(self, icon_data: Dict[str, Any], app_name: str) -> Optional[str]:
        """Export app icon to file"""
        try:
            if icon_data and icon_data.get('value'):
                icon_bytes = base64.b64decode(icon_data['value'])
                icon_filename = f"{self._sanitize_filename(app_name)}_icon.png"
                icon_path = self.export_path / icon_filename
                
                with open(icon_path, 'wb') as f:
                    f.write(icon_bytes)
                
                return icon_filename
        except Exception as e:
            self.logger.warning(f"Failed to export icon for {app_name}: {e}")
        
        return None
    
    def _save_manifest(self, manifest: Dict[str, Any], app_name: str, app_id: str):
        """Save manifest to JSON file"""
        filename = f"{self._sanitize_filename(app_name)}_{app_id}.json"
        filepath = self.export_path / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            if self.config.export_config['pretty_print']:
                json.dump(manifest, f, indent=2, ensure_ascii=False)
            else:
                json.dump(manifest, f, ensure_ascii=False)
    
    def _sanitize_filename(self, name: str) -> str:
        """Sanitize filename by removing invalid characters"""
        import re
        return re.sub(r'[^\w\s-]', '_', name)
