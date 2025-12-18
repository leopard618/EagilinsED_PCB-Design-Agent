"""
File-Based MCP Server for Altium Designer
Uses Altium scripts to export data to JSON files
This works when COM interface is not available

Supports:
- PCB information (pcb_info.json)
- Schematic information (schematic_info.json)
- Project information (project_info.json)
- Verification reports (verification_report.json)
- Output results (output_result.json)
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from urllib.parse import urlparse
import sys
import os
import time
from pathlib import Path


class AltiumMCPHandler(BaseHTTPRequestHandler):
    """File-based MCP handler - reads data from JSON files exported by Altium scripts"""
    
    # Base directory for all data files
    BASE_DIR = r"E:\Workspace\AI\11.10.WayNe\new-version"
    
    def __init__(self, *args, **kwargs):
        # Default location for data files
        self.pcb_info_path = kwargs.pop('pcb_info_path', None)
        if not self.pcb_info_path:
            self.pcb_info_path = os.path.join(self.BASE_DIR, "pcb_info.json")
        
        # Additional file paths
        self.schematic_info_path = os.path.join(self.BASE_DIR, "schematic_info.json")
        self.project_info_path = os.path.join(self.BASE_DIR, "project_info.json")
        self.verification_report_path = os.path.join(self.BASE_DIR, "verification_report.json")
        self.connectivity_report_path = os.path.join(self.BASE_DIR, "connectivity_report.json")
        self.output_result_path = os.path.join(self.BASE_DIR, "output_result.json")
        self.commands_path = os.path.join(self.BASE_DIR, "pcb_commands.json")
        self.schematic_commands_path = os.path.join(self.BASE_DIR, "schematic_commands.json")
        self.design_rules_path = os.path.join(self.BASE_DIR, "design_rules.json")
        self.board_config_path = os.path.join(self.BASE_DIR, "board_config.json")
        self.component_search_path = os.path.join(self.BASE_DIR, "component_search.json")
        self.library_list_path = os.path.join(self.BASE_DIR, "library_list.json")
        
        super().__init__(*args, **kwargs)
    
    def repair_json_syntax(self, content: str) -> str:
        """
        Attempt to repair common JSON syntax errors
        Fixes: missing commas between objects, trailing commas, etc.
        """
        import re
        
        # Fix missing comma between closing brace and opening brace: }    { -> },    {
        # This handles cases like: }    { or }\n{ or }  {
        content = re.sub(r'\}\s*\{', '}, {', content)
        
        # Fix missing comma between closing bracket and opening brace: ]    { -> ],    {
        content = re.sub(r'\]\s*\{', '], {', content)
        
        # Fix missing comma between closing brace and opening bracket: }    [ -> },    [
        content = re.sub(r'\}\s*\[', '}, [', content)
        
        # Fix missing comma between closing bracket and opening bracket: ]    [ -> ],    [
        content = re.sub(r'\]\s*\[', '], [', content)
        
        # Fix trailing commas before closing brackets/braces (remove them)
        content = re.sub(r',(\s*[}\]])', r'\1', content)
        
        return content
    
    def get_json_from_file(self, file_path: str):
        """Read any JSON file with error handling and repair"""
        if not os.path.exists(file_path):
            return None
        
        try:
            # Try to read file with UTF-8 first
            content = None
            try:
                with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()
            except Exception:
                encodings = ['utf-8-sig', 'latin-1', 'cp1252']
                for encoding in encodings:
                    try:
                        with open(file_path, 'r', encoding=encoding, errors='replace') as f:
                            content = f.read()
                            break
                    except:
                        continue
            
            if content is None:
                return None
            
            # Try to parse JSON
            try:
                return json.loads(content)
            except json.JSONDecodeError:
                # Try repair
                repaired = self.repair_json_syntax(content)
                try:
                    return json.loads(repaired)
                except:
                    return None
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return None
    
    def get_pcb_info_from_file(self):
        """Read PCB info from JSON file exported by Altium script"""
        if not os.path.exists(self.pcb_info_path):
            return None
        
        try:
            # Check if file is recent (within 10 minutes - more flexible for testing)
            file_age = time.time() - os.path.getmtime(self.pcb_info_path)
            if file_age > 600:  # 10 minutes
                print(f"Warning: pcb_info.json is {file_age:.0f} seconds old (>{600} seconds)")
                # Still return the data, just warn - user can refresh by running script
                # return None  # File is too old - commented out to be more flexible
            
            # Try to read file with UTF-8 first (most common)
            content = None
            try:
                with open(self.pcb_info_path, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()
            except Exception:
                # Fallback to other encodings
                encodings = ['utf-8-sig', 'latin-1', 'cp1252', 'iso-8859-1', 'windows-1252']
                for encoding in encodings:
                    try:
                        with open(self.pcb_info_path, 'r', encoding=encoding, errors='replace') as f:
                            content = f.read()
                            break
                    except:
                        continue
            
            if content is None:
                print("Error: Could not read file with any encoding")
                return None
            
            # Try to parse JSON directly first
            data = None
            last_error = None
            try:
                data = json.loads(content)
                return data
            except json.JSONDecodeError as e:
                last_error = e
                # Try to repair common JSON syntax errors
                print(f"JSON parse error detected at line {e.lineno}, column {e.colno}")
                print("Attempting to repair JSON syntax errors...")
                
                repaired_content = self.repair_json_syntax(content)
                
                try:
                    data = json.loads(repaired_content)
                    print("✓ Successfully repaired JSON syntax errors!")
                    return data
                except json.JSONDecodeError as e2:
                    print(f"JSON repair failed: {e2} at line {e2.lineno}, column {e2.colno}")
                    print("  The file needs to be re-exported with the fixed Altium script.")
                    last_error = e2
            
            if data is None:
                error_msg = str(last_error) if last_error else "Could not decode file with any encoding"
                print(f"Error reading PCB info file: {error_msg}")
                # If file exists but has JSON errors, provide helpful message
                if os.path.exists(self.pcb_info_path) and isinstance(last_error, json.JSONDecodeError):
                    print(f"  The file exists but has JSON syntax errors that could not be automatically repaired.")
                    print(f"  This usually means it was generated with an older version of the export script.")
                    print(f"  Please re-run the export script in Altium Designer to generate a new file.")
                return None
            
            return data
        except Exception as e:
            print(f"Error reading PCB info file: {e}")
            return None
    
    def _send_json_response(self, data, status_code=200):
        """Send JSON response with CORS headers"""
        self.send_response(status_code)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode())
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == "/health":
            file_exists = os.path.exists(self.pcb_info_path)
            self._send_json_response({
                "status": "healthy",
                "method": "file_based",
                "info_file": self.pcb_info_path,
                "file_exists": file_exists
            })
        
        elif path == "/altium/status":
            # Check if file exists first
            file_exists = os.path.exists(self.pcb_info_path)
            info = self.get_pcb_info_from_file()
            connected = info is not None
            
            if connected:
                message = "Connected via file-based method (Altium script)"
                pcb_file = info.get("file_name", "Unknown")
            else:
                if file_exists:
                    message = "PCB info file exists but has errors. Please re-run the export script in Altium Designer (File -> Run Script -> altium_export_pcb_info.pas -> ExportPCBInfo)"
                else:
                    message = "Waiting for Altium script to export PCB info. Run the Altium script first!"
                pcb_file = None
            
            self._send_json_response({
                "connected": connected,
                "message": message,
                "pcb_file": pcb_file,
                "info_file_path": self.pcb_info_path,
                "method": "file_based",
                "file_exists": file_exists
            })
        
        elif path == "/altium/pcb/info":
            info = self.get_pcb_info_from_file()
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No PCB info available. Please run the Altium script (altium_export_pcb_info.pas) to export PCB information.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_export_pcb_info.pas",
                    "instructions3": "3. The script will create pcb_info.json",
                    "file_path": self.pcb_info_path
                }, 404)
        
        elif path == "/altium/schematic/info":
            info = self.get_json_from_file(self.schematic_info_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No schematic info available. Please run the Altium script to export schematic information.",
                    "instructions": "1. In Altium Designer, open a schematic document",
                    "instructions2": "2. Go to File -> Run Script",
                    "instructions3": "3. Select altium_scripts/altium_export_schematic_info.pas",
                    "file_path": self.schematic_info_path
                }, 404)
        
        elif path == "/altium/project/info":
            info = self.get_json_from_file(self.project_info_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No project info available. Please run the Altium script to export project information.",
                    "instructions": "1. In Altium Designer, open a project",
                    "instructions2": "2. Go to File -> Run Script",
                    "instructions3": "3. Select altium_scripts/altium_project_manager.pas -> ExportProjectInfo",
                    "file_path": self.project_info_path
                }, 404)
        
        elif path == "/altium/verification/report":
            # Try verification report first, then connectivity
            info = self.get_json_from_file(self.verification_report_path)
            if not info:
                info = self.get_json_from_file(self.connectivity_report_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No verification report available. Run DRC/ERC first.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_verification.pas",
                    "instructions3": "3. Choose RunDRCAndExport, RunERCAndExport, or CheckConnectivityAndExport"
                }, 404)
        
        elif path == "/altium/output/result":
            info = self.get_json_from_file(self.output_result_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No output result available. Generate outputs first.",
                    "instructions": "Use altium_scripts/altium_output_generator.pas to generate manufacturing outputs"
                }, 404)
        
        elif path == "/altium/design/rules":
            info = self.get_json_from_file(self.design_rules_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No design rules available. Export design rules first.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_design_rules.pas",
                    "instructions3": "3. Choose ExportDesignRules",
                    "file_path": self.design_rules_path
                }, 404)
        
        elif path == "/altium/board/config":
            info = self.get_json_from_file(self.board_config_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No board configuration available. Export board config first.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_pcb_setup.pas",
                    "instructions3": "3. Choose ExportBoardConfig",
                    "file_path": self.board_config_path
                }, 404)
        
        elif path == "/altium/component/search":
            info = self.get_json_from_file(self.component_search_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No component search results available. Search components first.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_component_search.pas",
                    "instructions3": "3. Choose SearchComponents",
                    "file_path": self.component_search_path
                }, 404)
        
        elif path == "/altium/libraries":
            info = self.get_json_from_file(self.library_list_path)
            
            if info:
                self._send_json_response(info)
            else:
                self._send_json_response({
                    "error": "No library list available. List libraries first.",
                    "instructions": "1. In Altium Designer, go to File -> Run Script",
                    "instructions2": "2. Select altium_scripts/altium_component_search.pas",
                    "instructions3": "3. Choose ListInstalledLibraries",
                    "file_path": self.library_list_path
                }, 404)
        
        elif path == "/altium/files":
            # Return status of all data files
            files_status = {
                "pcb_info": {
                    "path": self.pcb_info_path,
                    "exists": os.path.exists(self.pcb_info_path),
                    "valid": self.get_pcb_info_from_file() is not None
                },
                "schematic_info": {
                    "path": self.schematic_info_path,
                    "exists": os.path.exists(self.schematic_info_path),
                    "valid": self.get_json_from_file(self.schematic_info_path) is not None
                },
                "project_info": {
                    "path": self.project_info_path,
                    "exists": os.path.exists(self.project_info_path),
                    "valid": self.get_json_from_file(self.project_info_path) is not None
                },
                "verification_report": {
                    "path": self.verification_report_path,
                    "exists": os.path.exists(self.verification_report_path),
                    "valid": self.get_json_from_file(self.verification_report_path) is not None
                },
                "output_result": {
                    "path": self.output_result_path,
                    "exists": os.path.exists(self.output_result_path),
                    "valid": self.get_json_from_file(self.output_result_path) is not None
                },
                "design_rules": {
                    "path": self.design_rules_path,
                    "exists": os.path.exists(self.design_rules_path),
                    "valid": self.get_json_from_file(self.design_rules_path) is not None
                },
                "board_config": {
                    "path": self.board_config_path,
                    "exists": os.path.exists(self.board_config_path),
                    "valid": self.get_json_from_file(self.board_config_path) is not None
                },
                "component_search": {
                    "path": self.component_search_path,
                    "exists": os.path.exists(self.component_search_path),
                    "valid": self.get_json_from_file(self.component_search_path) is not None
                },
                "library_list": {
                    "path": self.library_list_path,
                    "exists": os.path.exists(self.library_list_path),
                    "valid": self.get_json_from_file(self.library_list_path) is not None
                }
            }
            self._send_json_response(files_status)
        
        else:
            self._send_json_response({"error": "Not found"}, 404)
    
    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode()) if post_data else {}
        except:
            data = {}
        
        if path == "/altium/pcb/analyze":
            query = data.get("query", "")
            info = self.get_pcb_info_from_file()
            
            if info:
                response = {
                    "analysis": f"PCB Analysis for: {query}",
                    "details": f"Current PCB has {info.get('component_count', 0)} components, "
                              f"{info.get('net_count', 0)} nets, and {info.get('layer_count', 0)} layers.",
                    "pcb_info": info
                }
                self._send_json_response(response)
            else:
                self._send_json_response({
                    "error": "No PCB info available. Run Altium script first."
                }, 404)
        
        elif path == "/altium/pcb/modify":
            # File-based modification: write command to file for Altium script to execute
            command = data.get("command", "")
            parameters = data.get("parameters", {})
            
            try:
                # Write command to pcb_commands.json (same directory as pcb_info.json)
                if self.pcb_info_path:
                    commands_file = os.path.join(os.path.dirname(self.pcb_info_path), "pcb_commands.json")
                else:
                    # Default to current directory
                    commands_file = os.path.join(os.getcwd(), "pcb_commands.json")
                
                # Read existing commands or create new
                commands = []
                if os.path.exists(commands_file):
                    try:
                        with open(commands_file, 'r', encoding='utf-8') as f:
                            commands = json.load(f)
                            if not isinstance(commands, list):
                                commands = []
                    except:
                        commands = []
                
                # Add new command
                new_command = {
                    "command": command,
                    "parameters": parameters,
                    "timestamp": time.time()
                }
                commands.append(new_command)
                
                # Write back to file
                with open(commands_file, 'w', encoding='utf-8') as f:
                    json.dump(commands, f, indent=2)
                
                self._send_json_response({
                    "success": True,
                    "message": "Command queued. Please run altium_execute_commands.pas in Altium Designer to execute it.",
                    "command_file": commands_file
                })
            except Exception as e:
                self._send_json_response({
                    "success": False,
                    "message": f"Failed to queue command: {str(e)}"
                }, 500)
        
        elif path == "/altium/schematic/modify":
            # File-based modification: write command to file for Altium script to execute
            command = data.get("command", "")
            parameters = data.get("parameters", {})
            
            try:
                # Write command to schematic_commands.json
                commands_file = self.schematic_commands_path
                
                # Read existing commands or create new
                commands = []
                if os.path.exists(commands_file):
                    try:
                        with open(commands_file, 'r', encoding='utf-8') as f:
                            commands = json.load(f)
                            if not isinstance(commands, list):
                                commands = []
                    except:
                        commands = []
                
                # Add new command
                new_command = {
                    "command": command,
                    "parameters": parameters,
                    "timestamp": time.time()
                }
                commands.append(new_command)
                
                # Write back to file
                with open(commands_file, 'w', encoding='utf-8') as f:
                    json.dump(commands, f, indent=2)
                
                self._send_json_response({
                    "success": True,
                    "message": "Command queued. Please run altium_execute_commands.pas in Altium Designer to execute it.",
                    "command_file": commands_file
                })
            except Exception as e:
                self._send_json_response({
                    "success": False,
                    "message": f"Error queuing command: {str(e)}"
                }, 500)
        
        elif path == "/altium/schematic/modify":
            # File-based modification: write command to file for Altium script to execute
            command = data.get("command", "")
            parameters = data.get("parameters", {})
            
            try:
                # Write command to schematic_commands.json
                commands_file = self.schematic_commands_path
                
                # Read existing commands or create new
                commands = []
                if os.path.exists(commands_file):
                    try:
                        with open(commands_file, 'r', encoding='utf-8') as f:
                            commands = json.load(f)
                            if not isinstance(commands, list):
                                commands = []
                    except:
                        commands = []
                
                # Add new command
                new_command = {
                    "command": command,
                    "parameters": parameters,
                    "timestamp": time.time()
                }
                commands.append(new_command)
                
                # Write back to file
                with open(commands_file, 'w', encoding='utf-8') as f:
                    json.dump(commands, f, indent=2)
                
                self._send_json_response({
                    "success": True,
                    "message": "Command queued. Please run altium_schematic_modify.pas in Altium Designer to execute it.",
                    "command_file": commands_file
                })
            except Exception as e:
                self._send_json_response({
                    "success": False,
                    "message": f"Error queuing command: {str(e)}"
                }, 500)
        
        else:
            self._send_json_response({"error": "Not found"}, 404)
    
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
    
    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[MCP Server] {format % args}")


def run_server(port=8080, pcb_info_path=None):
    """Run the file-based MCP server"""
    server_address = ("", port)
    
    handler_class = lambda *args, **kwargs: AltiumMCPHandler(*args, pcb_info_path=pcb_info_path, **kwargs)
    httpd = HTTPServer(server_address, handler_class)
    
    print("=" * 60)
    print("Altium Designer MCP Server (File-Based)")
    print("=" * 60)
    print(f"Server running on http://localhost:{port}")
    print(f"PCB Info File: {pcb_info_path or 'Auto-detect'}")
    print("")
    print("IMPORTANT: This server uses file-based communication.")
    print("You must run the Altium script to export PCB info:")
    print("  1. In Altium Designer: DXP -> Run Script")
    print("  2. Select: altium_export_pcb_info.pas")
    print("  3. The script will create pcb_info.json")
    print("")
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='File-based MCP server for Altium Designer')
    parser.add_argument('--port', type=int, default=8080, help='Server port')
    parser.add_argument('--info-file', type=str, help='Path to pcb_info.json file')
    args = parser.parse_args()
    
    run_server(args.port, args.info_file)

