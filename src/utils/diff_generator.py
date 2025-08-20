import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from deepdiff import DeepDiff
import logging


class DiffGenerator:
    def __init__(self, export_base_path: str = "exports"):
        self.export_base_path = Path(export_base_path)
        self.logger = logging.getLogger(__name__)
        self.change_log_path = Path("change_logs")
        self.change_log_path.mkdir(exist_ok=True)
    
    def generate_change_log(self, previous_commit: Optional[str] = None) -> Dict[str, Any]:
        """Generate change log by comparing current exports with previous state"""
        changes = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "commit": previous_commit,
            "added": [],
            "removed": [],
            "modified": []
        }
        
        # Get all current files
        current_files = self._get_all_export_files()
        
        # Get previous files (from git history or cache)
        previous_files = self._get_previous_files(previous_commit)
        
        # Compare file sets
        current_set = {f.relative_to(self.export_base_path): f for f in current_files}
        previous_set = {f.relative_to(self.export_base_path): f for f in previous_files}
        
        # Find added files
        added_paths = set(current_set.keys()) - set(previous_set.keys())
        for path in added_paths:
            changes["added"].append(self._create_change_entry(current_set[path], "added"))
        
        # Find removed files
        removed_paths = set(previous_set.keys()) - set(current_set.keys())
        for path in removed_paths:
            changes["removed"].append(self._create_change_entry(previous_set[path], "removed"))
        
        # Find modified files
        common_paths = set(current_set.keys()) & set(previous_set.keys())
        for path in common_paths:
            diff = self._compare_files(previous_set[path], current_set[path])
            if diff:
                changes["modified"].append(diff)
        
        # Save change log
        self._save_change_log(changes)
        
        return changes
    
    def _get_all_export_files(self) -> List[Path]:
        """Get all JSON files in the export directory"""
        return list(self.export_base_path.rglob("*.json"))
    
    def _get_previous_files(self, commit: Optional[str] = None) -> List[Path]:
        """Get files from previous commit or empty list if no previous state"""
        # For now, return empty list if this is the first run
        # In production, this would use git to get previous state
        return []
    
    def _create_change_entry(self, file_path: Path, change_type: str) -> Dict[str, Any]:
        """Create a change entry for added/removed files"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            return {
                "objectType": self._get_object_type(file_path),
                "displayName": data.get('displayName', 'Unknown'),
                "objectId": data.get('id', 'Unknown'),
                "changeType": change_type
            }
        except Exception as e:
            self.logger.error(f"Error reading file {file_path}: {e}")
            return {
                "objectType": self._get_object_type(file_path),
                "displayName": "Error reading file",
                "objectId": "Unknown",
                "changeType": change_type
            }
    
    def _compare_files(self, old_file: Path, new_file: Path) -> Optional[Dict[str, Any]]:
        """Compare two JSON files and return differences"""
        try:
            with open(old_file, 'r', encoding='utf-8') as f:
                old_data = json.load(f)
            
            with open(new_file, 'r', encoding='utf-8') as f:
                new_data = json.load(f)
            
            # Use DeepDiff for detailed comparison
            diff = DeepDiff(old_data, new_data, ignore_order=True, 
                           exclude_paths=["root['lastModifiedDateTime']"])
            
            if diff:
                return {
                    "objectType": self._get_object_type(new_file),
                    "displayName": new_data.get('displayName', 'Unknown'),
                    "objectId": new_data.get('id', 'Unknown'),
                    "changes": self._format_deepdiff(diff)
                }
        except Exception as e:
            self.logger.error(f"Error comparing files {old_file} and {new_file}: {e}")
        
        return None
    
    def _get_object_type(self, file_path: Path) -> str:
        """Determine object type from file path"""
        parent_dir = file_path.parent.name
        return parent_dir
    
    def _format_deepdiff(self, diff: DeepDiff) -> Dict[str, Any]:
        """Format DeepDiff output for our change log"""
        formatted = {}
        
        if 'values_changed' in diff:
            for path, change in diff['values_changed'].items():
                key = path.split("'")[1] if "'" in path else path
                formatted[key] = {
                    "old": change['old_value'],
                    "new": change['new_value']
                }
        
        return formatted
    
    def _save_change_log(self, changes: Dict[str, Any]):
        """Save change log to file"""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"changelog_{timestamp}.json"
        filepath = self.change_log_path / filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(changes, f, indent=2, ensure_ascii=False)
        
        # Also save as latest.json for easy access
        latest_path = self.change_log_path / "latest.json"
        with open(latest_path, 'w', encoding='utf-8') as f:
            json.dump(changes, f, indent=2, ensure_ascii=False)
