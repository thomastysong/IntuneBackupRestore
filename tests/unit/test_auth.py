import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.utils.auth import GraphAuthenticator
from src.utils.config import Config


class TestGraphAuthenticator:
    def test_graph_authenticator_init(self):
        """Test GraphAuthenticator initialization"""
        mock_config = Mock(spec=Config)
        mock_config.azure_config = {
            'tenant_id': 'test-tenant',
            'client_id': 'test-client',
            'client_secret': 'test-secret'
        }
        
        auth = GraphAuthenticator(mock_config)
        assert auth.config == mock_config
        assert auth._token_cache == {}
    
    @patch('src.utils.auth.msal.ConfidentialClientApplication')
    def test_create_msal_app(self, mock_msal_app):
        """Test MSAL app creation"""
        mock_config = Mock(spec=Config)
        mock_config.azure_config = {
            'tenant_id': 'test-tenant',
            'client_id': 'test-client',
            'client_secret': 'test-secret'
        }
        
        auth = GraphAuthenticator(mock_config)
        
        mock_msal_app.assert_called_once_with(
            'test-client',
            authority='https://login.microsoftonline.com/test-tenant',
            client_credential='test-secret'
        )
    
    @patch('src.utils.auth.msal.ConfidentialClientApplication')
    def test_get_token_success(self, mock_msal_app):
        """Test successful token acquisition"""
        mock_config = Mock(spec=Config)
        mock_config.azure_config = {
            'tenant_id': 'test-tenant',
            'client_id': 'test-client',
            'client_secret': 'test-secret'
        }
        
        # Mock the MSAL app instance
        mock_app_instance = Mock()
        mock_app_instance.acquire_token_for_client.return_value = {
            'access_token': 'test-token-12345',
            'token_type': 'Bearer'
        }
        mock_msal_app.return_value = mock_app_instance
        
        auth = GraphAuthenticator(mock_config)
        token = auth.get_token()
        
        assert token == 'test-token-12345'
        mock_app_instance.acquire_token_for_client.assert_called_once_with(
            scopes=['https://graph.microsoft.com/.default']
        )
    
    @patch('src.utils.auth.msal.ConfidentialClientApplication')
    def test_get_token_failure(self, mock_msal_app):
        """Test token acquisition failure"""
        mock_config = Mock(spec=Config)
        mock_config.azure_config = {
            'tenant_id': 'test-tenant',
            'client_id': 'test-client',
            'client_secret': 'test-secret'
        }
        
        # Mock the MSAL app instance with failure
        mock_app_instance = Mock()
        mock_app_instance.acquire_token_for_client.return_value = {
            'error': 'invalid_client',
            'error_description': 'Invalid client credentials'
        }
        mock_msal_app.return_value = mock_app_instance
        
        auth = GraphAuthenticator(mock_config)
        
        with pytest.raises(Exception) as exc_info:
            auth.get_token()
        
        assert 'Failed to acquire token: Invalid client credentials' in str(exc_info.value)
    
    @patch('src.utils.auth.msal.ConfidentialClientApplication')
    def test_token_caching(self, mock_msal_app):
        """Test that tokens are cached properly"""
        mock_config = Mock(spec=Config)
        mock_config.azure_config = {
            'tenant_id': 'test-tenant',
            'client_id': 'test-client',
            'client_secret': 'test-secret'
        }
        
        # Mock the MSAL app instance
        mock_app_instance = Mock()
        mock_app_instance.acquire_token_for_client.return_value = {
            'access_token': 'cached-token-12345',
            'token_type': 'Bearer'
        }
        mock_msal_app.return_value = mock_app_instance
        
        auth = GraphAuthenticator(mock_config)
        
        # First call should acquire token
        token1 = auth.get_token()
        assert token1 == 'cached-token-12345'
        assert mock_app_instance.acquire_token_for_client.call_count == 1
        
        # Second call should use cache
        token2 = auth.get_token()
        assert token2 == 'cached-token-12345'
        assert mock_app_instance.acquire_token_for_client.call_count == 1  # Still 1
