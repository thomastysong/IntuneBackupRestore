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
