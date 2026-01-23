"""
Altium Importer
Maps Altium JSON exports to canonical G-IR and C-IR artifacts
Per Architecture Spec §8.1
"""
import json
from pathlib import Path
from typing import Dict, Any, Optional, List

from core.ir.gir import (
    GeometryIR, Board, BoardOutline, Layer, LayerKind, Stackup, Net, Track, TrackSegment,
    Via, Footprint, Pad
)
from core.ir.cir import ConstraintIR, Rule, RuleType, RuleScope, RuleParams, Netclass, NetclassDefaults
from core.artifacts.models import Artifact, ArtifactType, ArtifactMeta, SourceEngine, CreatedBy


class AltiumImporter:
    """Imports Altium data to canonical IR artifacts"""
    
    def __init__(self):
        """Initialize importer"""
        pass
    
    def import_pcb_info(self, pcb_info_path: str) -> Optional[GeometryIR]:
        """
        Import PCB info from Altium JSON to G-IR
        
        Args:
            pcb_info_path: Path to pcb_info.json file
            
        Returns:
            GeometryIR object or None if import fails
        """
        try:
            with open(pcb_info_path, 'r', encoding='utf-8') as f:
                pcb_data = json.load(f)
        except Exception as e:
            print(f"Error reading pcb_info.json: {e}")
            return None
        
        # Extract board information
        board_size = pcb_data.get('board_size', {})
        width_mm = board_size.get('width_mm', 100.0)
        height_mm = board_size.get('height_mm', 80.0)
        
        # Create board outline (simple rectangle for MVP)
        outline = BoardOutline(
            polygon=[[0, 0], [width_mm, 0], [width_mm, height_mm], [0, height_mm]]
        )
        
        # Extract layers
        layers_data = pcb_data.get('layers', [])
        layers = []
        for i, layer_name in enumerate(layers_data):
            # Determine layer kind
            layer_name_lower = layer_name.lower()
            if 'top' in layer_name_lower or 'signal' in layer_name_lower:
                kind = LayerKind.SIGNAL
            elif 'gnd' in layer_name_lower or 'ground' in layer_name_lower:
                kind = LayerKind.GROUND
            elif 'power' in layer_name_lower or 'vcc' in layer_name_lower:
                kind = LayerKind.POWER
            else:
                kind = LayerKind.SIGNAL
            
            layers.append(Layer(
                id=f"L{i+1}",
                name=layer_name,
                kind=kind,
                index=i+1
            ))
        
        # Create stackup
        stackup = Stackup(
            layers=[layer.id for layer in layers],
            thickness_mm=pcb_data.get('board_thickness_mm', 1.6),
            dielectrics=[]
        )
        
        board = Board(
            outline=outline,
            layers=layers,
            stackup=stackup
        )
        
        # Extract nets
        nets_data = pcb_data.get('nets', [])
        nets = []
        for net_data in nets_data:
            if isinstance(net_data, dict):
                net_name = net_data.get('name', '')
                net_id = f"net-{net_name.lower().replace(' ', '-')}"
            else:
                net_name = str(net_data)
                net_id = f"net-{net_name.lower().replace(' ', '-')}"
            
            nets.append(Net(id=net_id, name=net_name))
        
        # Extract tracks
        tracks_data = pcb_data.get('tracks', [])
        tracks = []
        for track_data in tracks_data:
            track_id = track_data.get('id', f"trk-{len(tracks)}")
            net_name = track_data.get('net', '')
            net_id = f"net-{net_name.lower().replace(' ', '-')}" if net_name else None
            
            if not net_id or net_id not in [n.id for n in nets]:
                continue
            
            layer_name = track_data.get('layer', layers[0].name if layers else 'Top')
            layer_id = next((l.id for l in layers if l.name == layer_name), layers[0].id if layers else 'L1')
            
            # Extract segments
            segments = []
            width_mm = track_data.get('width_mm', 0.25)
            
            # Handle different track formats
            if 'start' in track_data and 'end' in track_data:
                segments.append(TrackSegment(
                    from_pos=[track_data['start'].get('x_mm', 0), track_data['start'].get('y_mm', 0)],
                    to_pos=[track_data['end'].get('x_mm', 0), track_data['end'].get('y_mm', 0)],
                    width_mm=width_mm
                ))
            elif 'segments' in track_data:
                for seg in track_data['segments']:
                    segments.append(TrackSegment(
                        from_pos=[seg.get('from', {}).get('x', 0), seg.get('from', {}).get('y', 0)],
                        to_pos=[seg.get('to', {}).get('x', 0), seg.get('to', {}).get('y', 0)],
                        width_mm=width_mm
                    ))
            
            if segments:
                tracks.append(Track(
                    id=track_id,
                    net_id=net_id,
                    layer_id=layer_id,
                    segments=segments
                ))
        
        # Extract vias
        vias_data = pcb_data.get('vias', [])
        vias = []
        for via_data in vias_data:
            via_id = via_data.get('id', f"via-{len(vias)}")
            net_name = via_data.get('net', '')
            net_id = f"net-{net_name.lower().replace(' ', '-')}" if net_name else None
            
            if net_id and net_id not in [n.id for n in nets]:
                continue
            
            position = [
                via_data.get('x_mm', via_data.get('position', {}).get('x', 0)),
                via_data.get('y_mm', via_data.get('position', {}).get('y', 0))
            ]
            drill_mm = via_data.get('drill_mm', via_data.get('drill_size_mm', 0.3))
            
            # Determine layers (default to all signal layers)
            via_layers = [l.id for l in layers if l.kind == LayerKind.SIGNAL]
            if not via_layers:
                via_layers = [layers[0].id] if layers else []
            
            vias.append(Via(
                id=via_id,
                net_id=net_id or '',
                position=position,
                drill_mm=drill_mm,
                layers=via_layers
            ))
        
        # Extract footprints (components)
        components_data = pcb_data.get('components', [])
        footprints = []
        for comp_data in components_data:
            if isinstance(comp_data, dict):
                comp_name = comp_data.get('name', comp_data.get('designator', ''))
                comp_id = f"fp-{comp_name.lower()}"
                
                location = comp_data.get('location', {})
                position = [
                    location.get('x_mm', location.get('x', 0)),
                    location.get('y_mm', location.get('y', 0))
                ]
                rotation = comp_data.get('rotation_degrees', comp_data.get('rotation', 0))
                layer_name = comp_data.get('layer', layers[0].name if layers else 'Top')
                layer_id = next((l.id for l in layers if l.name == layer_name), layers[0].id if layers else 'L1')
                
                # Extract pads (simplified - just create placeholder)
                pads = []
                # In real implementation, would extract pad data from component
                
                footprints.append(Footprint(
                    id=comp_id,
                    ref=comp_name,
                    position=position,
                    rotation_deg=rotation,
                    layer=layer_id,
                    pads=pads,
                    footprint_name=comp_data.get('footprint', '')
                ))
        
        return GeometryIR(
            board=board,
            nets=nets,
            tracks=tracks,
            vias=vias,
            footprints=footprints
        )
    
    def import_design_rules(self, design_rules_path: str) -> Optional[ConstraintIR]:
        """
        Import design rules from Altium JSON to C-IR
        
        Args:
            design_rules_path: Path to design_rules.json file
            
        Returns:
            ConstraintIR object or None if import fails
        """
        try:
            with open(design_rules_path, 'r', encoding='utf-8') as f:
                rules_data = json.load(f)
        except Exception as e:
            print(f"Error reading design_rules.json: {e}")
            return None
        
        rules = []
        netclasses = []
        
        # Import clearance rules
        clearance_rules = rules_data.get('clearance_rules', [])
        for rule_data in clearance_rules:
            if not rule_data.get('enabled', True):
                continue
            
            rule_id = rule_data.get('id', f"rule-clearance-{len(rules)}")
            min_clearance = rule_data.get('minimum_mm', rule_data.get('min_clearance_mm', 0.2))
            
            # Determine scope
            scope = RuleScope()
            if 'net_class' in rule_data:
                scope.netclass = rule_data['net_class']
            elif 'nets' in rule_data:
                scope.nets = [f"net-{n.lower().replace(' ', '-')}" for n in rule_data['nets']]
            
            rules.append(Rule(
                id=rule_id,
                type=RuleType.CLEARANCE,
                scope=scope,
                params=RuleParams(min_clearance_mm=min_clearance),
                enabled=True
            ))
        
        # Import width rules
        width_rules = rules_data.get('width_rules', [])
        for rule_data in width_rules:
            if not rule_data.get('enabled', True):
                continue
            
            rule_id = rule_data.get('id', f"rule-width-{len(rules)}")
            min_width = rule_data.get('min_width_mm', 0.25)
            preferred_width = rule_data.get('preferred_width_mm', rule_data.get('default_width_mm', 0.3))
            
            scope = RuleScope()
            if 'net_class' in rule_data:
                scope.netclass = rule_data['net_class']
            elif 'nets' in rule_data:
                scope.nets = [f"net-{n.lower().replace(' ', '-')}" for n in rule_data['nets']]
            
            rules.append(Rule(
                id=rule_id,
                type=RuleType.TRACE_WIDTH,
                scope=scope,
                params=RuleParams(
                    min_width_mm=min_width,
                    preferred_width_mm=preferred_width
                ),
                enabled=True
            ))
        
        # Import netclasses
        netclasses_data = rules_data.get('netclasses', [])
        for nc_data in netclasses_data:
            nc_id = f"nc-{nc_data.get('name', '').lower().replace(' ', '-')}"
            nc_name = nc_data.get('name', '')
            nc_nets = [f"net-{n.lower().replace(' ', '-')}" for n in nc_data.get('nets', [])]
            
            defaults = NetclassDefaults(
                trace_width_mm=nc_data.get('default_width_mm', 0.3),
                clearance_mm=nc_data.get('default_clearance_mm', 0.2)
            )
            
            netclasses.append(Netclass(
                id=nc_id,
                name=nc_name,
                nets=nc_nets,
                defaults=defaults
            ))
        
        return ConstraintIR(rules=rules, netclasses=netclasses)
    
    def create_pcb_board_artifact(self, gir: GeometryIR, pcb_info_path: str) -> Artifact:
        """
        Create pcb.board artifact from G-IR
        
        Args:
            gir: Geometry IR
            pcb_info_path: Source file path (for metadata)
            
        Returns:
            Artifact object
        """
        return Artifact(
            type=ArtifactType.PCB_BOARD,
            data=gir.model_dump(),
            meta=ArtifactMeta(
                source_engine=SourceEngine.ALTIUM,
                created_by=CreatedBy.ENGINE
            )
        )
    
    def create_constraint_ruleset_artifact(self, cir: ConstraintIR, design_rules_path: str) -> Artifact:
        """
        Create constraint.ruleSet artifact from C-IR
        
        Args:
            cir: Constraint IR
            design_rules_path: Source file path (for metadata)
            
        Returns:
            Artifact object
        """
        return Artifact(
            type=ArtifactType.CONSTRAINT_RULESET,
            data=cir.model_dump(),
            meta=ArtifactMeta(
                source_engine=SourceEngine.ALTIUM,
                created_by=CreatedBy.ENGINE
            )
        )
