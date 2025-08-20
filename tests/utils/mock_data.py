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
    
    @staticmethod
    def generate_assignment() -> Dict[str, Any]:
        return {
            "id": str(uuid.uuid4()),
            "target": {
                "@odata.type": "#microsoft.graph.allDevicesAssignmentTarget"
            }
        }
    
    @staticmethod
    def generate_graph_api_response(data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate a mock Graph API response"""
        return {
            "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#deviceManagement/deviceCompliancePolicies",
            "value": data
        }
