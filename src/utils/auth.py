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
