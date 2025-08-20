#!/usr/bin/env python3
"""
Export runner for Intune backup modules
"""
import argparse
import logging
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.utils.config import Config
from src.utils.auth import GraphAuthenticator
from src.modules.python.export_compliance_policies import CompliancePolicyExporter


def setup_logging():
    """Configure logging"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def run_compliance_policies_export(config: Config, auth: GraphAuthenticator):
    """Run compliance policies export"""
    exporter = CompliancePolicyExporter(config, auth)
    policies = exporter.export_all()
    logging.info(f"Exported {len(policies)} compliance policies")
    return policies


def run_applications_export(config: Config, auth: GraphAuthenticator):
    """Run applications export - placeholder for now"""
    logging.warning("Applications export not yet implemented")
    return []


def main():
    parser = argparse.ArgumentParser(description='Run Intune configuration exports')
    parser.add_argument('--module', required=True, 
                       choices=['compliance_policies', 'applications', 'all'],
                       help='Module to export')
    
    args = parser.parse_args()
    
    setup_logging()
    
    try:
        # Initialize configuration and authentication
        config = Config()
        auth = GraphAuthenticator(config)
        
        # Run specified module
        if args.module == 'compliance_policies':
            run_compliance_policies_export(config, auth)
        elif args.module == 'applications':
            run_applications_export(config, auth)
        elif args.module == 'all':
            run_compliance_policies_export(config, auth)
            run_applications_export(config, auth)
        
        logging.info("Export completed successfully")
        
    except Exception as e:
        logging.error(f"Export failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
