"""
DRC Module
Integrated with artifact store for DRC operations

Per Week 1 Task 9: Integrate DRC with Artifact Store
"""
from typing import List, Optional, Dict, Any
from core.artifacts.store import ArtifactStore
from core.artifacts.models import Artifact, ArtifactType, ArtifactMeta, SourceEngine, CreatedBy
from core.ir.gir import GeometryIR
from core.ir.cir import ConstraintIR
import json
import subprocess
from pathlib import Path


class DRCModule:
    """
    DRC module integrated with artifact store
    
    Reads board and constraint artifacts, runs DRC, and stores violations.
    """
    
    def __init__(self, artifact_store: Optional[ArtifactStore] = None):
        """
        Initialize DRC module
        
        Args:
            artifact_store: Artifact store instance (creates new if None)
        """
        self.store = artifact_store or ArtifactStore()
    
    def get_board_artifact(self, artifact_id: str) -> Optional[Artifact]:
        """Get board artifact from store"""
        artifact = self.store.read(artifact_id)
        if artifact and artifact.type == ArtifactType.PCB_BOARD:
            return artifact
        return None
    
    def get_constraint_artifact(self, artifact_id: str) -> Optional[Artifact]:
        """Get constraint artifact from store"""
        artifact = self.store.read(artifact_id)
        if artifact and artifact.type == ArtifactType.CONSTRAINT_RULESET:
            return artifact
        return None
    
    def get_gir_from_artifact(self, artifact_id: str) -> Optional[GeometryIR]:
        """Extract G-IR from board artifact"""
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return None
        
        try:
            data = artifact.data
            if isinstance(data, dict):
                return GeometryIR(**data)
            return None
        except Exception as e:
            print(f"Error converting artifact to G-IR: {e}")
            return None
    
    def get_cir_from_artifact(self, artifact_id: str) -> Optional[ConstraintIR]:
        """Extract C-IR from constraint artifact"""
        artifact = self.get_constraint_artifact(artifact_id)
        if not artifact:
            return None
        
        try:
            data = artifact.data
            if isinstance(data, dict):
                from core.ir.cir import ConstraintIR
                return ConstraintIR(**data)
            return None
        except Exception as e:
            print(f"Error converting artifact to C-IR: {e}")
            return None
    
    def run_drc(self, board_artifact_id: str, constraint_artifact_id: str) -> Optional[Artifact]:
        """
        Run DRC on board using constraints
        
        Args:
            board_artifact_id: Board artifact ID
            constraint_artifact_id: Constraint artifact ID
            
        Returns:
            Violations artifact or None if DRC fails
        """
        # Get artifacts
        board_artifact = self.get_board_artifact(board_artifact_id)
        constraint_artifact = self.get_constraint_artifact(constraint_artifact_id)
        
        if not board_artifact or not constraint_artifact:
            print("Error: Board or constraint artifact not found")
            return None
        
        # Export to temporary files for Altium DRC script
        from adapters.altium.exporter import AltiumExporter
        exporter = AltiumExporter()
        
        gir = self.get_gir_from_artifact(board_artifact_id)
        cir = self.get_cir_from_artifact(constraint_artifact_id)
        
        if not gir or not cir:
            print("Error: Could not extract G-IR or C-IR from artifacts")
            return None
        
        # Export to temporary files
        temp_dir = Path("temp_drc")
        temp_dir.mkdir(exist_ok=True)
        
        pcb_info_path = str(temp_dir / "pcb_info.json")
        design_rules_path = str(temp_dir / "design_rules.json")
        
        exporter.export_pcb_info(gir, pcb_info_path)
        exporter.export_design_rules(cir, design_rules_path)
        
        # Run Altium DRC script
        # Note: This assumes Altium script is available
        # For MVP, we'll create a mock DRC result
        violations = self._run_altium_drc(pcb_info_path, design_rules_path)
        
        # Create violations artifact
        violations_artifact = self.create_violations_artifact(
            violations=violations,
            board_artifact_id=board_artifact_id,
            constraint_artifact_id=constraint_artifact_id
        )
        
        # Store violations artifact
        stored = self.store.create(violations_artifact)
        
        return stored
    
    def create_violations_artifact(self, violations: List[Dict[str, Any]], 
                                   board_artifact_id: str, 
                                   constraint_artifact_id: str) -> Artifact:
        """
        Create violations artifact from parsed violations
        
        Args:
            violations: List of violation dicts
            board_artifact_id: Board artifact ID
            constraint_artifact_id: Constraint artifact ID
            
        Returns:
            Violations artifact
        """
        from datetime import datetime
        
        return Artifact(
            type=ArtifactType.CONSTRAINT_VIOLATIONS,
            data={
                "violations": violations,
                "board_artifact_id": board_artifact_id,
                "constraint_artifact_id": constraint_artifact_id,
                "drc_run_timestamp": datetime.utcnow().isoformat(),
                "violation_count": len(violations)
            },
            meta=ArtifactMeta(
                source_engine=SourceEngine.ALTIUM,
                created_by=CreatedBy.ENGINE
            ),
            relations=[
                {"role": "checks", "target_id": board_artifact_id},
                {"role": "uses", "target_id": constraint_artifact_id}
            ]
        )
    
    def _run_altium_drc(self, pcb_info_path: str, design_rules_path: str) -> List[Dict[str, Any]]:
        """
        Run Altium DRC script and parse results
        
        Args:
            pcb_info_path: Path to pcb_info.json
            design_rules_path: Path to design_rules.json
            
        Returns:
            List of violation dicts
        """
        # For MVP: Return mock violations
        # Future: Actually call Altium DRC script
        # altium_scripts/commands/verification/runDRC.pas
        
        violations = []
        
        # Mock violation for testing
        violations.append({
            "id": "violation-1",
            "type": "clearance",
            "severity": "error",
            "message": "Clearance violation between track and pad",
            "location": {
                "x_mm": 25.0,
                "y_mm": 30.0,
                "layer": "L1"
            },
            "rule_id": "rule-clearance-1",
            "actual_clearance_mm": 0.1,
            "required_clearance_mm": 0.2
        })
        
        return violations
    
    def parse_drc_output(self, drc_output_path: str) -> List[Dict[str, Any]]:
        """
        Parse Altium DRC output file
        
        Args:
            drc_output_path: Path to DRC output JSON file
            
        Returns:
            List of violation dicts
        """
        try:
            with open(drc_output_path, 'r', encoding='utf-8') as f:
                drc_data = json.load(f)
        except Exception as e:
            print(f"Error reading DRC output: {e}")
            return []
        
        violations = []
        
        # Parse DRC output format
        # Expected format from Altium script:
        # {
        #   "violations": [
        #     {
        #       "type": "clearance",
        #       "message": "...",
        #       "location": {"x_mm": ..., "y_mm": ..., "layer": "..."},
        #       "rule": "...",
        #       "actual": ...,
        #       "required": ...
        #     }
        #   ]
        # }
        
        drc_violations = drc_data.get("violations", [])
        
        for i, viol_data in enumerate(drc_violations):
            violation = {
                "id": f"violation-{i+1}",
                "type": viol_data.get("type", "unknown"),
                "severity": viol_data.get("severity", "error"),
                "message": viol_data.get("message", ""),
                "location": viol_data.get("location", {}),
                "rule_id": viol_data.get("rule", ""),
                "actual_clearance_mm": viol_data.get("actual"),
                "required_clearance_mm": viol_data.get("required")
            }
            violations.append(violation)
        
        return violations
    
    def get_violations(self, violations_artifact_id: str) -> List[Dict[str, Any]]:
        """
        Get violations from violations artifact
        
        Args:
            violations_artifact_id: Violations artifact ID
            
        Returns:
            List of violation dicts
        """
        artifact = self.store.read(violations_artifact_id)
        if not artifact or artifact.type != ArtifactType.CONSTRAINT_VIOLATIONS:
            return []
        
        return artifact.data.get("violations", [])
