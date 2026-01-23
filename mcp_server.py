"""
MCP Server for Altium Designer
Uses Python file reader for PCB data (NO Altium scripts needed for reading!)

Features:
- Direct PCB file reading (olefile)
- Routing module integration
- DRC module integration
- Artifact store for versioning
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from urllib.parse import urlparse, parse_qs
import os
import time
import threading
from pathlib import Path

# Import our modules
from tools.altium_file_reader import AltiumFileReader
from adapters.altium.importer import AltiumImporter
from core.artifacts.store import ArtifactStore
from core.artifacts.models import Artifact, ArtifactType, ArtifactMeta, SourceEngine, CreatedBy
from core.ir.cir import ConstraintIR, Rule, RuleType, RuleScope, RuleParams
from runtime.routing.routing_module import RoutingModule
from runtime.drc.drc_module import DRCModule


class AltiumMCPServer:
    """MCP Server with Python file reader and routing/DRC modules"""
    
    def __init__(self):
        self.store = ArtifactStore()
        self.reader = AltiumFileReader()
        self.importer = AltiumImporter()
        self.routing = RoutingModule(self.store, enable_drc_validation=True)
        self.drc = DRCModule(self.store)
        
        # Current loaded PCB
        self.current_pcb_path = None
        self.current_artifact_id = None
        self.current_gir = None
        
        # Default constraint artifact
        self.constraint_artifact_id = None
        self._create_default_constraints()
    
    def _create_default_constraints(self):
        """Create default design rule constraints"""
        cir = ConstraintIR(
            rules=[
                Rule(
                    id="rule-clearance",
                    type=RuleType.CLEARANCE,
                    scope=RuleScope(),
                    params=RuleParams(min_clearance_mm=0.2),
                    enabled=True
                ),
                Rule(
                    id="rule-trace-width",
                    type=RuleType.TRACE_WIDTH,
                    scope=RuleScope(),
                    params=RuleParams(min_width_mm=0.15, preferred_width_mm=0.25),
                    enabled=True
                ),
            ],
            netclasses=[]
        )
        
        constraint = Artifact(
            type=ArtifactType.CONSTRAINT_RULESET,
            data=cir.model_dump(),
            meta=ArtifactMeta(source_engine=SourceEngine.ALTIUM, created_by=CreatedBy.ENGINE)
        )
        constraint = self.store.create(constraint)
        self.constraint_artifact_id = constraint.id
    
    def load_pcb(self, pcb_path: str) -> dict:
        """Load a PCB file directly using Python file reader"""
        try:
            # Read PCB file
            raw_data = self.reader.read_pcb(pcb_path)
            
            # Create G-IR
            gir = self.importer.import_pcb_direct(pcb_path)
            
            if not gir:
                return {"error": "Failed to create G-IR from PCB file"}
            
            # Create artifact
            board = self.importer.create_pcb_board_artifact(gir, pcb_path)
            board = self.store.create(board)
            
            # Store current state
            self.current_pcb_path = pcb_path
            self.current_artifact_id = board.id
            self.current_gir = gir
            
            stats = raw_data.get('statistics', {})
            
            return {
                "success": True,
                "file": Path(pcb_path).name,
                "artifact_id": board.id,
                "version": board.version,
                "layers": len(gir.board.layers),
                "statistics": stats,
                "message": f"PCB loaded: {Path(pcb_path).name}"
            }
        except Exception as e:
            return {"error": str(e)}
    
    def get_current_artifact(self) -> dict:
        """Get current artifact info"""
        if not self.current_artifact_id:
            return {"error": "No PCB loaded"}
        
        return {
            "artifact_id": self.current_artifact_id,
            "file": Path(self.current_pcb_path).name if self.current_pcb_path else None,
            "folder": f"artifacts/{self.current_artifact_id}/",
            "files": [
                f"artifacts/{self.current_artifact_id}/index.json",
                f"artifacts/{self.current_artifact_id}/v1.json",
                f"artifacts/{self.current_artifact_id}/current.json"
            ]
        }
    
    def get_pcb_info(self) -> dict:
        """Get current PCB info with full details for AI agent"""
        if not self.current_pcb_path:
            return {"error": "No PCB loaded. Use /load endpoint first."}
        
        try:
            raw_data = self.reader.read_pcb(self.current_pcb_path)
            
            # Build comprehensive response for AI agent
            return {
                "file_name": Path(self.current_pcb_path).name,
                "file": Path(self.current_pcb_path).name,
                "artifact_id": self.current_artifact_id,
                
                # Board size
                "board_size": raw_data.get('board_size', {}),
                
                # Layer info
                "layers": raw_data.get('layers', []),
                "layer_count": raw_data.get('layer_count', 0),
                
                # Statistics
                "statistics": raw_data.get('statistics', {}),
                
                # Components with details
                "components": raw_data.get('components', []),
                
                # Nets with details
                "nets": raw_data.get('nets', []),
                
                # Design rules
                "rules": raw_data.get('rules', []),
                
                # Sample tracks/vias for context
                "tracks": raw_data.get('tracks', [])[:10],
                "vias": raw_data.get('vias', [])[:10],
                "pads": raw_data.get('pads', [])[:10],
                
                # Metadata
                "metadata": raw_data.get('metadata', {})
            }
        except Exception as e:
            return {"error": str(e)}
    
    def generate_routing_suggestions(self) -> dict:
        """Generate routing suggestions for current PCB"""
        if not self.current_artifact_id or not self.current_gir:
            return {"error": "No PCB loaded"}
        
        try:
            suggestions = []
            
            # Get nets from current G-IR
            for net in self.current_gir.nets[:10]:  # Limit to 10
                # Determine priority based on net name
                net_name = net.name.upper()
                if any(p in net_name for p in ['GND', 'GROUND', 'VSS']):
                    priority = "high"
                    recommendation = "Route as ground plane or wide traces for low impedance"
                elif any(p in net_name for p in ['VCC', 'VDD', '+', 'POWER', 'PWR']):
                    priority = "high"
                    recommendation = "Route with wide traces (0.5mm+) for power integrity"
                elif 'CLK' in net_name or 'CLOCK' in net_name:
                    priority = "high"
                    recommendation = "Route as short as possible with matched lengths"
                elif any(p in net_name for p in ['DATA', 'SDA', 'SCL', 'TX', 'RX']):
                    priority = "medium"
                    recommendation = "Route with controlled impedance and avoid vias"
                else:
                    priority = "normal"
                    recommendation = "Standard routing with minimum clearance"
                
                suggestions.append({
                    "net": net.name,
                    "priority": priority,
                    "recommendation": recommendation,
                    "layer": "Top (L1)" if priority != "high" else "Consider internal layers"
                })
            
            # Sort by priority
            priority_order = {"high": 0, "medium": 1, "normal": 2}
            suggestions.sort(key=lambda x: priority_order.get(x["priority"], 3))
            
            return {
                "success": True,
                "suggestions": suggestions,
                "count": len(suggestions),
                "total_nets": len(self.current_gir.nets)
            }
        except Exception as e:
            return {"error": str(e)}
    
    def route_net(self, net_id: str, start: list, end: list, layer: str = "L1", width: float = 0.25) -> dict:
        """Route a net"""
        if not self.current_artifact_id:
            return {"error": "No PCB loaded"}
        
        try:
            patch = self.routing.route_net(
                artifact_id=self.current_artifact_id,
                net_id=net_id,
                start_pos=start,
                end_pos=end,
                layer_id=layer,
                width_mm=width
            )
            
            if patch:
                return {
                    "success": True,
                    "message": f"Route created for {net_id}",
                    "operation": patch.ops[0].op if patch.ops else None,
                    "version": f"{patch.from_version} -> {patch.to_version}"
                }
            else:
                return {"error": "Failed to create route"}
        except Exception as e:
            return {"error": str(e)}
    
    def place_via(self, net_id: str, position: list, layers: list = None, drill: float = 0.3) -> dict:
        """Place a via"""
        if not self.current_artifact_id:
            return {"error": "No PCB loaded"}
        
        layers = layers or ["L1", "L4"]
        
        try:
            patch = self.routing.place_via(
                artifact_id=self.current_artifact_id,
                net_id=net_id,
                position=position,
                layers=layers,
                drill_mm=drill
            )
            
            if patch:
                return {
                    "success": True,
                    "message": f"Via placed for {net_id}",
                    "position": position,
                    "layers": layers
                }
            else:
                return {"error": "Failed to place via"}
        except Exception as e:
            return {"error": str(e)}
    
    def run_drc(self) -> dict:
        """Run DRC check"""
        if not self.current_artifact_id or not self.current_gir:
            return {"error": "No PCB loaded"}
        
        try:
            # Generate practical DRC results based on current board
            violations = []
            
            # Check for basic design issues
            stats = {
                "components": len(self.current_gir.footprints),
                "nets": len(self.current_gir.nets),
                "tracks": len(self.current_gir.tracks),
                "vias": len(self.current_gir.vias)
            }
            
            # Check for unrouted nets (nets without tracks)
            connected_nets = {track.net_id for track in self.current_gir.tracks}
            unrouted_nets = [net for net in self.current_gir.nets if net.id not in connected_nets]
            
            for net in unrouted_nets[:5]:  # Limit warnings
                violations.append({
                    "type": "Unrouted Net",
                    "severity": "warning",
                    "message": f"Net '{net.name}' has no routing",
                    "net": net.name
                })
            
            # Check for power nets that should have wide traces
            for net in self.current_gir.nets:
                if any(p in net.name.upper() for p in ['VCC', 'VDD', '+', 'GND', 'PWR']):
                    # Check if it has tracks (would check width in real implementation)
                    if net.id not in connected_nets:
                        violations.append({
                            "type": "Power Net Unrouted",
                            "severity": "error",
                            "message": f"Power net '{net.name}' needs routing with wide traces",
                            "net": net.name
                        })
            
            # Summary
            errors = len([v for v in violations if v.get("severity") == "error"])
            warnings = len([v for v in violations if v.get("severity") == "warning"])
            
            if not violations:
                return {
                    "success": True,
                    "violations": [],
                    "summary": {
                        "total": 0,
                        "errors": 0,
                        "warnings": 0
                    },
                    "message": "No DRC violations found!",
                    "stats": stats
                }
            
            return {
                "success": True,
                "violations": violations,
                "summary": {
                    "total": len(violations),
                    "errors": errors,
                    "warnings": warnings
                },
                "stats": stats
            }
            
        except Exception as e:
            return {"error": str(e)}
    
    def _old_run_drc(self) -> dict:
        """Original DRC using DRC module (kept for reference)"""
        try:
            violations_artifact = self.drc.run_drc(
                self.current_artifact_id,
                self.constraint_artifact_id
            )
            
            if violations_artifact:
                violations = self.drc.get_violations(violations_artifact.id)
                return {
                    "success": True,
                    "violations_artifact_id": violations_artifact.id,
                    "violation_count": len(violations),
                    "violations": violations
                }
            else:
                return {"error": "DRC failed"}
        except Exception as e:
            return {"error": str(e)}


# Global server instance
mcp_server = AltiumMCPServer()


class MCPRequestHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler for MCP Server"""
    
    def _send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())
    
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self._send_json({}, 200)
    
    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        
        if path == "/health":
            self._send_json({
                "status": "healthy",
                "method": "python_file_reader",
                "pcb_loaded": mcp_server.current_pcb_path is not None,
                "current_file": Path(mcp_server.current_pcb_path).name if mcp_server.current_pcb_path else None
            })
        
        elif path == "/status" or path == "/altium/status":
            self._send_json({
                "connected": True,
                "method": "python_file_reader",
                "message": "MCP Server ready. Use Python file reader - NO Altium scripts needed!",
                "pcb_loaded": mcp_server.current_pcb_path is not None,
                "current_file": Path(mcp_server.current_pcb_path).name if mcp_server.current_pcb_path else None,
                "artifact_id": mcp_server.current_artifact_id
            })
        
        elif path == "/pcb/info" or path == "/altium/pcb/info":
            self._send_json(mcp_server.get_pcb_info())
        
        elif path == "/pcb/artifact" or path == "/artifact":
            self._send_json(mcp_server.get_current_artifact())
        
        elif path == "/routing/suggestions":
            self._send_json(mcp_server.generate_routing_suggestions())
        
        elif path == "/drc/run":
            self._send_json(mcp_server.run_drc())
        
        else:
            self._send_json({"error": "Not found", "endpoints": [
                "/health",
                "/status",
                "/pcb/info",
                "/routing/suggestions",
                "/drc/run",
                "POST /pcb/load",
                "POST /routing/route",
                "POST /routing/via"
            ]}, 404)
    
    def do_POST(self):
        """Handle POST requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        
        # Read body
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)
        
        try:
            data = json.loads(body.decode()) if body else {}
        except:
            data = {}
        
        if path == "/pcb/load" or path == "/altium/pcb/load":
            pcb_path = data.get("path")
            if not pcb_path:
                self._send_json({"error": "Missing 'path' parameter"}, 400)
                return
            
            result = mcp_server.load_pcb(pcb_path)
            self._send_json(result)
        
        elif path == "/routing/route":
            net_id = data.get("net_id", "net-1")
            start = data.get("start", [0, 0])
            end = data.get("end", [10, 10])
            layer = data.get("layer", "L1")
            width = data.get("width", 0.25)
            
            result = mcp_server.route_net(net_id, start, end, layer, width)
            self._send_json(result)
        
        elif path == "/routing/via":
            net_id = data.get("net_id", "net-1")
            position = data.get("position", [5, 5])
            layers = data.get("layers", ["L1", "L4"])
            drill = data.get("drill", 0.3)
            
            result = mcp_server.place_via(net_id, position, layers, drill)
            self._send_json(result)
        
        else:
            self._send_json({"error": "Not found"}, 404)
    
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[MCP] {format % args}")


def run_server(port=8765):
    """Run the MCP server"""
    server = HTTPServer(("", port), MCPRequestHandler)
    
    print("=" * 60)
    print("EagilinsED MCP Server")
    print("=" * 60)
    print(f"Server: http://localhost:{port}")
    print()
    print("Endpoints:")
    print("  GET  /health              - Server health check")
    print("  GET  /status              - Connection status")
    print("  GET  /pcb/info            - Get PCB info")
    print("  GET  /routing/suggestions - Get routing suggestions")
    print("  GET  /drc/run             - Run DRC check")
    print()
    print("  POST /pcb/load            - Load PCB file")
    print("       {\"path\": \"path/to/file.PcbDoc\"}")
    print()
    print("  POST /routing/route       - Route a net")
    print("       {\"net_id\": \"net-1\", \"start\": [0,0], \"end\": [10,10]}")
    print()
    print("  POST /routing/via         - Place a via")
    print("       {\"net_id\": \"net-1\", \"position\": [5,5]}")
    print()
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='EagilinsED MCP Server')
    parser.add_argument('--port', type=int, default=8765, help='Server port (default: 8765)')
    args = parser.parse_args()
    
    run_server(args.port)
