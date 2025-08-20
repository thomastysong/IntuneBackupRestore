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
