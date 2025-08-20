#!/usr/bin/env python3
"""
Generate changelog by comparing current exports with previous state
"""
import logging
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.utils.diff_generator import DiffGenerator


def setup_logging():
    """Configure logging"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def main():
    setup_logging()
    
    try:
        # Initialize diff generator
        diff_gen = DiffGenerator()
        
        # Generate change log
        logging.info("Generating change log...")
        changes = diff_gen.generate_change_log()
        
        # Log summary
        total_changes = len(changes['added']) + len(changes['removed']) + len(changes['modified'])
        logging.info(f"Change log generated: {len(changes['added'])} added, "
                    f"{len(changes['removed'])} removed, {len(changes['modified'])} modified")
        
        if total_changes == 0:
            logging.info("No changes detected")
        
    except Exception as e:
        logging.error(f"Failed to generate change log: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
