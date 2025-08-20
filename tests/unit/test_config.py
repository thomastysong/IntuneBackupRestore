import pytest
import os
from unittest.mock import patch
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.utils.config import Config


class TestConfig:
    @patch.dict(os.environ, {
        'AZURE_TENANT_ID': 'test-tenant-123',
        'AZURE_CLIENT_ID': 'test-client-456',
        'AZURE_CLIENT_SECRET': 'test-secret-789',
        'GRAPH_API_VERSION': 'beta',
        'GRAPH_API_BETA_ENABLED': 'true',
        'EXPORT_FORMAT': 'yaml',
        'EXPORT_PRETTY_PRINT': 'false',
        'EXPORT_INCLUDE_ASSIGNMENTS': 'false'
    })
    def test_config_with_all_env_vars(self):
        """Test Config with all environment variables set"""
        config = Config()
        
        # Test azure config
        assert config.azure_config['tenant_id'] == 'test-tenant-123'
        assert config.azure_config['client_id'] == 'test-client-456'
        assert config.azure_config['client_secret'] == 'test-secret-789'
        
        # Test graph config
        assert config.graph_config['api_version'] == 'beta'
        assert config.graph_config['beta_enabled'] is True
        
        # Test export config
        assert config.export_config['format'] == 'yaml'
        assert config.export_config['pretty_print'] is False
        assert config.export_config['include_assignments'] is False
    
    @patch.dict(os.environ, {
        'AZURE_TENANT_ID': 'test-tenant',
        'AZURE_CLIENT_ID': 'test-client',
        'AZURE_CLIENT_SECRET': 'test-secret'
    }, clear=True)
    def test_config_with_minimal_env_vars(self):
        """Test Config with only required environment variables"""
        config = Config()
        
        # Test azure config
        assert config.azure_config['tenant_id'] == 'test-tenant'
        assert config.azure_config['client_id'] == 'test-client'
        assert config.azure_config['client_secret'] == 'test-secret'
        
        # Test default values
        assert config.graph_config['api_version'] == 'v1.0'
        assert config.graph_config['beta_enabled'] is False
        assert config.export_config['format'] == 'json'
        assert config.export_config['pretty_print'] is True
        assert config.export_config['include_assignments'] is True
    
    @patch.dict(os.environ, {}, clear=True)
    def test_config_missing_required_vars(self):
        """Test Config raises error when required variables are missing"""
        with pytest.raises(ValueError) as exc_info:
            Config()
        
        assert 'Missing required environment variables' in str(exc_info.value)
        assert 'AZURE_TENANT_ID' in str(exc_info.value)
        assert 'AZURE_CLIENT_ID' in str(exc_info.value)
        assert 'AZURE_CLIENT_SECRET' in str(exc_info.value)
    
    @patch.dict(os.environ, {
        'AZURE_TENANT_ID': 'test-tenant',
        'AZURE_CLIENT_ID': 'test-client',
        # Missing AZURE_CLIENT_SECRET
    }, clear=True)
    def test_config_missing_one_required_var(self):
        """Test Config identifies specific missing variable"""
        with pytest.raises(ValueError) as exc_info:
            Config()
        
        assert 'Missing required environment variables: AZURE_CLIENT_SECRET' in str(exc_info.value)
    
    @patch.dict(os.environ, {
        'AZURE_TENANT_ID': 'test-tenant',
        'AZURE_CLIENT_ID': 'test-client',
        'AZURE_CLIENT_SECRET': 'test-secret',
        'GRAPH_API_BETA_ENABLED': 'TRUE'  # Test case insensitive
    })
    def test_config_case_insensitive_boolean(self):
        """Test boolean parsing is case insensitive"""
        config = Config()
        assert config.graph_config['beta_enabled'] is True
    
    @patch.dict(os.environ, {
        'AZURE_TENANT_ID': 'test-tenant',
        'AZURE_CLIENT_ID': 'test-client',
        'AZURE_CLIENT_SECRET': 'test-secret',
        'EXPORT_PRETTY_PRINT': 'yes'  # Invalid boolean value
    })
    def test_config_invalid_boolean_defaults_to_false(self):
        """Test invalid boolean values default to False"""
        config = Config()
        assert config.export_config['pretty_print'] is False
