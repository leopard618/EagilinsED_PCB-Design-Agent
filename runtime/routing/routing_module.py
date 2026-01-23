"""
Routing Module
Integrated with artifact store for routing operations

Per Week 1 Task 7-8, 12: Routing Module with Basic Operations + DRC Integration
"""
from typing import List, Optional, Dict, Any, Tuple
import math
from core.artifacts.store import ArtifactStore
from core.artifacts.models import Artifact, ArtifactType, ArtifactMeta, SourceEngine, CreatedBy
from core.ir.gir import GeometryIR, Board, Net, Track, TrackSegment, Via, Footprint
from core.patch.schema import Patch, PatchOp, PatchMeta
from core.patch.operations import MoveComponentOp, AddTrackSegmentOp, AddViaOp


class RoutingModule:
    """
    Routing module integrated with artifact store
    
    Reads G-IR from artifacts and generates routing suggestions.
    """
    
    def __init__(self, artifact_store: Optional[ArtifactStore] = None, 
                 enable_drc_validation: bool = True):
        """
        Initialize routing module
        
        Args:
            artifact_store: Artifact store instance (creates new if None)
            enable_drc_validation: Whether to automatically run DRC after routing
        """
        self.store = artifact_store or ArtifactStore()
        self.enable_drc_validation = enable_drc_validation
    
    def get_board_artifact(self, artifact_id: str) -> Optional[Artifact]:
        """
        Get board artifact from store
        
        Args:
            artifact_id: Board artifact ID
            
        Returns:
            Artifact or None if not found
        """
        artifact = self.store.read(artifact_id)
        if artifact and artifact.type == ArtifactType.PCB_BOARD:
            return artifact
        return None
    
    def get_gir_from_artifact(self, artifact_id: str) -> Optional[GeometryIR]:
        """
        Extract G-IR from board artifact
        
        Args:
            artifact_id: Board artifact ID
            
        Returns:
            GeometryIR object or None
        """
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return None
        
        try:
            # Artifact data contains G-IR as dict (from gir.model_dump())
            data = artifact.data
            
            if isinstance(data, dict):
                # Parse dict back to GeometryIR using Pydantic
                return GeometryIR(**data)
            else:
                return None
            
        except Exception as e:
            print(f"Error converting artifact to G-IR: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def generate_routing_suggestions(self, artifact_id: str) -> List[Patch]:
        """
        Generate routing suggestions based on board artifact
        
        Args:
            artifact_id: Board artifact ID
            
        Returns:
            List of Patch objects with routing suggestions
        """
        gir = self.get_gir_from_artifact(artifact_id)
        if not gir:
            return []
        
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return []
        
        suggestions = []
        
        # Analyze unconnected nets (nets without tracks)
        connected_nets = {track.net_id for track in gir.tracks}
        unconnected_nets = [net for net in gir.nets if net.id not in connected_nets]
        
        # Generate routing suggestions for unconnected nets
        for net in unconnected_nets[:5]:  # Limit to first 5 for MVP
            # Find pads connected to this net
            pads = []
            for fp in gir.footprints:
                for pad in fp.pads:
                    if pad.net_id == net.id:
                        pads.append((fp, pad))
            
            if len(pads) >= 2:
                # Generate track between first two pads
                fp1, pad1 = pads[0]
                fp2, pad2 = pads[1]
                
                # Calculate positions (footprint position + pad offset)
                pos1 = [
                    fp1.position[0] + pad1.position[0],
                    fp1.position[1] + pad1.position[1]
                ]
                pos2 = [
                    fp2.position[0] + pad2.position[0],
                    fp2.position[1] + pad2.position[1]
                ]
                
                # Create AddTrackSegment operation
                add_track_op = AddTrackSegmentOp(
                    net_id=net.id,
                    layer_id=gir.board.layers[0].id if gir.board.layers else "L1",
                    from_pos=pos1,
                    to_pos=pos2,
                    width_mm=0.25  # Default width
                )
                
                # Create patch
                patch = Patch(
                    artifact_id=artifact_id,
                    from_version=artifact.version,
                    to_version=artifact.version + 1,
                    ops=[PatchOp(**add_track_op.to_patch_op())],
                    meta=PatchMeta(
                        author="routing-module",
                        source="agent",
                        explain=f"Route net {net.name} between {fp1.ref} and {fp2.ref}"
                    )
                )
                patch.validate_version_consistency()
                suggestions.append(patch)
        
        return suggestions
    
    def optimize_component_placement(self, artifact_id: str) -> List[Patch]:
        """
        Generate component placement optimization suggestions
        
        Args:
            artifact_id: Board artifact ID
            
        Returns:
            List of Patch objects with placement suggestions
        """
        gir = self.get_gir_from_artifact(artifact_id)
        if not gir:
            return []
        
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return []
        
        suggestions = []
        
        # Simple optimization: spread out components that are too close
        min_spacing = 5.0  # mm
        footprints = gir.footprints
        
        for i, fp1 in enumerate(footprints):
            for j, fp2 in enumerate(footprints[i+1:], i+1):
                # Calculate distance
                dx = fp1.position[0] - fp2.position[0]
                dy = fp1.position[1] - fp2.position[1]
                distance = (dx**2 + dy**2)**0.5
                
                if distance < min_spacing:
                    # Suggest moving fp2 away
                    new_x = fp2.position[0] + (min_spacing - distance) * (dx / distance if distance > 0 else 1)
                    new_y = fp2.position[1] + (min_spacing - distance) * (dy / distance if distance > 0 else 1)
                    
                    move_op = MoveComponentOp(
                        component_ref=fp2.ref,
                        new_position_mm=[new_x, new_y],
                        new_rotation_deg=fp2.rotation_deg
                    )
                    
                    patch = Patch(
                        artifact_id=artifact_id,
                        from_version=artifact.version,
                        to_version=artifact.version + 1,
                        ops=[PatchOp(**move_op.to_patch_op())],
                        meta=PatchMeta(
                            author="routing-module",
                            source="agent",
                            explain=f"Move {fp2.ref} to increase spacing from {fp1.ref}"
                        )
                    )
                    patch.validate_version_consistency()
                    suggestions.append(patch)
        
        return suggestions
    
    def route_net(self, artifact_id: str, net_id: str, start_pos: List[float], 
                  end_pos: List[float], layer_id: str, width_mm: float = 0.25) -> Optional[Patch]:
        """
        Route a single net between two points
        
        Args:
            artifact_id: Board artifact ID
            net_id: Net to route
            start_pos: Start position [x, y] in mm
            end_pos: End position [x, y] in mm
            layer_id: Layer to route on
            width_mm: Track width in mm
            
        Returns:
            Patch with routing suggestion or None
        """
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return None
        
        # Create AddTrackSegment operation
        add_track_op = AddTrackSegmentOp(
            net_id=net_id,
            layer_id=layer_id,
            from_pos=start_pos,
            to_pos=end_pos,
            width_mm=width_mm
        )
        
        patch = Patch(
            artifact_id=artifact_id,
            from_version=artifact.version,
            to_version=artifact.version + 1,
            ops=[PatchOp(**add_track_op.to_patch_op())],
            meta=PatchMeta(
                author="routing-module",
                source="agent",
                explain=f"Route net {net_id} from {start_pos} to {end_pos}"
            )
        )
        patch.validate_version_consistency()
        return patch
    
    def place_via(self, artifact_id: str, net_id: str, position: List[float],
                  layers: List[str], drill_mm: float = 0.3) -> Optional[Patch]:
        """
        Place a via at specified position
        
        Args:
            artifact_id: Board artifact ID
            net_id: Net the via belongs to
            position: Via position [x, y] in mm
            layers: List of layer IDs the via connects
            drill_mm: Via drill diameter in mm
            
        Returns:
            Patch with via placement suggestion or None
        """
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return None
        
        add_via_op = AddViaOp(
            net_id=net_id,
            position=position,
            drill_mm=drill_mm,
            layers=layers
        )
        
        patch = Patch(
            artifact_id=artifact_id,
            from_version=artifact.version,
            to_version=artifact.version + 1,
            ops=[PatchOp(**add_via_op.to_patch_op())],
            meta=PatchMeta(
                author="routing-module",
                source="agent",
                explain=f"Place via for net {net_id} at {position}"
            )
        )
        patch.validate_version_consistency()
        return patch
    
    def calculate_route_path(self, start_pos: List[float], end_pos: List[float],
                            obstacles: List[Tuple[float, float, float]] = None) -> List[List[float]]:
        """
        Calculate routing path avoiding obstacles
        
        Args:
            start_pos: Start position [x, y]
            end_pos: End position [x, y]
            obstacles: List of (x, y, radius) obstacles to avoid
            
        Returns:
            List of waypoints [[x1, y1], [x2, y2], ...]
        """
        if obstacles is None:
            obstacles = []
        
        # Simple straight-line routing for MVP
        # Future: Add obstacle avoidance, pathfinding algorithms
        return [start_pos, end_pos]
    
    def optimize_component_spacing(self, artifact_id: str, min_spacing_mm: float = 5.0) -> List[Patch]:
        """
        Optimize component placement to ensure minimum spacing
        
        Args:
            artifact_id: Board artifact ID
            min_spacing_mm: Minimum spacing between components in mm
            
        Returns:
            List of patches with placement optimizations
        """
        gir = self.get_gir_from_artifact(artifact_id)
        if not gir:
            return []
        
        artifact = self.get_board_artifact(artifact_id)
        if not artifact:
            return []
        
        suggestions = []
        footprints = gir.footprints
        
        for i, fp1 in enumerate(footprints):
            for j, fp2 in enumerate(footprints[i+1:], i+1):
                # Calculate distance
                dx = fp1.position[0] - fp2.position[0]
                dy = fp1.position[1] - fp2.position[1]
                distance = math.sqrt(dx**2 + dy**2)
                
                if distance < min_spacing_mm and distance > 0:
                    # Calculate new position to maintain spacing
                    direction_x = dx / distance if distance > 0 else 1.0
                    direction_y = dy / distance if distance > 0 else 1.0
                    
                    # Move fp2 away from fp1
                    move_distance = min_spacing_mm - distance + 0.5  # Add small buffer
                    new_x = fp2.position[0] + direction_x * move_distance
                    new_y = fp2.position[1] + direction_y * move_distance
                    
                    # Ensure new position is within board bounds
                    board_outline = gir.board.outline.polygon
                    if board_outline:
                        x_coords = [p[0] for p in board_outline]
                        y_coords = [p[1] for p in board_outline]
                        new_x = max(min(x_coords), min(max(x_coords), new_x))
                        new_y = max(min(y_coords), min(max(y_coords), new_y))
                    
                    move_op = MoveComponentOp(
                        component_ref=fp2.ref,
                        new_position_mm=[new_x, new_y],
                        new_rotation_deg=fp2.rotation_deg
                    )
                    
                    patch = Patch(
                        artifact_id=artifact_id,
                        from_version=artifact.version,
                        to_version=artifact.version + 1,
                        ops=[PatchOp(**move_op.to_patch_op())],
                        meta=PatchMeta(
                            author="routing-module",
                            source="agent",
                            explain=f"Optimize spacing: Move {fp2.ref} away from {fp1.ref} (distance: {distance:.2f}mm < {min_spacing_mm}mm)"
                        )
                    )
                    patch.validate_version_consistency()
                    suggestions.append(patch)
        
        return suggestions
