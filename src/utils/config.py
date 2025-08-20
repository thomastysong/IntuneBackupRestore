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
