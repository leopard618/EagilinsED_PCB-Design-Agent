"""
MCP Client for Altium Designer Integration
"""
import requests
import json
import time
from typing import Dict, Any, Optional, Tuple
from pathlib import Path
from config import MCP_SERVER_URL, MCP_TIMEOUT
import json


def wait_for_pcb_info(info_file: str = None, timeout: int = 20) -> bool:
    """
    Wait for pcb_info.json to be created/updated with valid content
    
    Args:
        info_file: Path to pcb_info.json
        timeout: Maximum time to wait in seconds
    
    Returns:
        bool: True if file exists and is valid, False otherwise
    """
    if info_file is None:
        info_file = Path(__file__).parent / "pcb_info.json"
    else:
        info_file = Path(info_file)
    
    start_time = time.time()
    last_size = 0
    stable_count = 0
    
    while time.time() - start_time < timeout:
        if info_file.exists():
            try:
                current_size = info_file.stat().st_size
                
                if current_size > 1000:
                    if current_size == last_size:
                        stable_count += 1
                        if stable_count >= 2:
                            try:
                                with open(info_file, 'r', encoding='utf-8') as f:
                                    content = f.read().strip()
                                    if len(content) > 500:
                                        # Try to parse JSON
                                        try:
                                            data = json.loads(content)
                                        except json.JSONDecodeError:
                                            # Try to repair common JSON errors
                                            import re
                                            # Fix missing comma between closing brace and opening brace
                                            content = re.sub(r'\}\s*\{', '}, {', content)
                                            # Fix missing comma between closing bracket and opening brace
                                            content = re.sub(r'\]\s*\{', '], {', content)
                                            # Fix missing comma between closing brace and opening bracket
                                            content = re.sub(r'\}\s*\[', '}, [', content)
                                            # Fix missing comma between closing bracket and opening bracket
                                            content = re.sub(r'\]\s*\[', '], [', content)
                                            # Try parsing again
                                            try:
                                                data = json.loads(content)
                                            except json.JSONDecodeError:
                                                if time.time() - start_time < timeout - 3:
                                                    stable_count = 0
                                                    time.sleep(1.0)
                                                    continue
                                                else:
                                                    return False
                                        
                                        if isinstance(data, dict):
                                            if 'components' in data or 'file_name' in data:
                                                return True
                            except json.JSONDecodeError:
                                if time.time() - start_time < timeout - 3:
                                    stable_count = 0
                                    time.sleep(1.0)
                                    continue
                                else:
                                    return False
                            except Exception:
                                stable_count = 0
                                time.sleep(0.5)
                                continue
                    else:
                        last_size = current_size
                        stable_count = 0
                        time.sleep(0.5)
                        continue
                elif current_size > 0:
                    last_size = current_size
                    stable_count = 0
                    time.sleep(0.5)
                    continue
                else:
                    time.sleep(0.5)
                    continue
            except Exception:
                time.sleep(0.5)
                continue
        else:
            time.sleep(0.5)
    
    if info_file.exists():
        try:
            current_size = info_file.stat().st_size
            if current_size < 100:
                return False
            try:
                with open(info_file, 'r', encoding='utf-8') as f:
                    content = f.read().strip()
                    if len(content) > 100:
                        # Try to parse JSON
                        try:
                            data = json.loads(content)
                        except json.JSONDecodeError:
                            # Try to repair common JSON errors
                            import re
                            # Fix missing comma between closing brace and opening brace
                            content = re.sub(r'\}\s*\{', '}, {', content)
                            # Fix missing comma between closing bracket and opening brace
                            content = re.sub(r'\]\s*\{', '], {', content)
                            # Fix missing comma between closing brace and opening bracket
                            content = re.sub(r'\}\s*\[', '}, [', content)
                            # Fix missing comma between closing bracket and opening bracket
                            content = re.sub(r'\]\s*\[', '], [', content)
                            # Try parsing again
                            try:
                                data = json.loads(content)
                            except json.JSONDecodeError:
                                return False
                        
                        if isinstance(data, dict) and ('components' in data or 'file_name' in data):
                            return True
            except:
                pass
        except:
            pass
    
    return False


class AltiumMCPClient:
    """Client for communicating with Altium Designer via MCP"""
    
    # Document types
    DOC_PCB = "PCB"
    DOC_SCHEMATIC = "SCH"
    DOC_PROJECT = "PRJ"
    
    def __init__(self, server_url: str = None):
        self.server_url = server_url or MCP_SERVER_URL
        self.connected = False
        self.session = requests.Session()
        self.session.timeout = MCP_TIMEOUT
        self.active_document_type = self.DOC_PCB  # Default to PCB mode
        
        # Disable proxy for localhost connections (important for local MCP server)
        self.session.trust_env = False  # Don't use system proxy settings
        self.session.proxies = {
            'http': None,
            'https': None
        }
    
    def connect(self) -> Tuple[bool, str]:
        """
        Connect to Altium Designer via MCP server
        Waits for user to manually run export script to get PCB info
        
        Returns:
            tuple: (success: bool, message: str)
        """
        try:
            # First, check if PCB info file already exists and is valid
            # This avoids unnecessary script execution attempts
            info_file = Path(__file__).parent / "pcb_info.json"
            file_exists_and_valid = False
            
            try:
                altium_check = self.session.get(
                    f"{self.server_url}/altium/status",
                    timeout=5
                )
                if altium_check.status_code == 200:
                    data = altium_check.json()
                    if data.get("connected", False):
                        # File exists and is valid - no need to run script
                        self.connected = True
                        return True, "Successfully connected (using existing PCB info)"
                    file_exists_and_valid = False
            except:
                pass  # Continue to try script execution if status check fails
            
            # Wait for user to manually run the export script (up to 60 seconds)
            # Check if file exists and is valid
            print("Waiting for PCB info file (please run export script in Altium Designer)...")
            if wait_for_pcb_info(str(info_file), timeout=60):
                # File was created successfully and is valid, verify connection
                time.sleep(0.5)
                print("PCB info file created successfully!")
            else:
                # Timeout or file is invalid
                if info_file.exists():
                    try:
                        file_size = info_file.stat().st_size
                        if file_size < 100:
                            return False, "PCB info file is empty. Please check Altium Designer for error messages after running the export script.\n\nPlease try running the export script again in Altium Designer."
                        else:
                            return False, "PCB info file is invalid or corrupted. Please try running the export script again in Altium Designer."
                    except:
                        return False, "PCB info file exists but cannot be read. Please check file permissions."
                else:
                    return False, "PCB info file was not created within 1 minute. Please make sure you ran the export script in Altium Designer:\n\nFile → Run Script → altium_export_pcb_info.pas → ExportPCBInfo"
            
            # Test connection to MCP server
            print(f"Connecting to MCP server at {self.server_url}...")
            try:
                response = self.session.get(
                    f"{self.server_url}/health",
                    timeout=5
                )
                print(f"Server response: {response.status_code}")
            except Exception as e:
                print(f"Server connection error: {e}")
                raise
            
            if response.status_code == 200:
                # Check if Altium Designer is available
                altium_check = self.session.get(
                    f"{self.server_url}/altium/status",
                    timeout=5
                )
                
                if altium_check.status_code == 200:
                    data = altium_check.json()
                    if data.get("connected", False):
                        self.connected = True
                        return True, "Successfully connected and loaded PCB info"
                    else:
                        # File might have errors
                        error_msg = data.get("message", "PCB info file has errors")
                        return False, f"Failed to load PCB info: {error_msg}"
                else:
                    return False, f"Failed to check Altium Designer status: {altium_check.status_code}"
            else:
                return False, f"MCP server not responding: {response.status_code}"
                
        except requests.exceptions.ConnectionError:
            return False, "Cannot connect to MCP server. Please ensure the server is running."
        except requests.exceptions.Timeout:
            return False, "Connection timeout. Please check your network settings."
        except Exception as e:
            return False, f"Connection error: {str(e)}"
    
    def disconnect(self):
        """Disconnect from Altium Designer"""
        self.connected = False
    
    def get_pcb_info(self) -> Optional[Dict[str, Any]]:
        """Get information about the current PCB"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/pcb/info",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting PCB info: {e}")
            return None
    
    def analyze_pcb(self, query: str) -> Optional[Dict[str, Any]]:
        """Analyze PCB based on query"""
        if not self.connected:
            return None
        
        try:
            response = self.session.post(
                f"{self.server_url}/altium/pcb/analyze",
                json={"query": query},
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error analyzing PCB: {e}")
            return None
    
    def modify_pcb(self, command: str, parameters: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Modify PCB through MCP
        Commands are queued to pcb_commands.json for manual script execution
        """
        if not self.connected:
            return None
        
        try:
            response = self.session.post(
                f"{self.server_url}/altium/pcb/modify",
                json={"command": command, "parameters": parameters},
                timeout=MCP_TIMEOUT
            )
            # Return response even if status code is not 200 (like 501 for not supported)
            if response.status_code in [200, 501]:
                result = response.json()
                
                if isinstance(result, dict):
                    result["message"] = "Command queued. Please run altium_execute_commands.pas in Altium Designer to execute it."
                
                return result
            return None
        except Exception as e:
            print(f"Error modifying PCB: {e}")
            return None
    
    def get_schematic_info(self) -> Optional[Dict[str, Any]]:
        """Get information about the current schematic"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/schematic/info",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting schematic info: {e}")
            return None
    
    def get_project_info(self) -> Optional[Dict[str, Any]]:
        """Get information about the current project"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/project/info",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting project info: {e}")
            return None
    
    def get_verification_report(self) -> Optional[Dict[str, Any]]:
        """Get verification (DRC/ERC) report"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/verification/report",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting verification report: {e}")
            return None
    
    def get_output_result(self) -> Optional[Dict[str, Any]]:
        """Get output generation result"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/output/result",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting output result: {e}")
            return None
    
    def get_files_status(self) -> Optional[Dict[str, Any]]:
        """Get status of all data files"""
        if not self.connected:
            return None
        
        try:
            response = self.session.get(
                f"{self.server_url}/altium/files",
                timeout=MCP_TIMEOUT
            )
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"Error getting files status: {e}")
            return None
    
    def set_document_type(self, doc_type: str):
        """Set the active document type (PCB, SCH, PRJ)"""
        if doc_type in [self.DOC_PCB, self.DOC_SCHEMATIC, self.DOC_PROJECT]:
            self.active_document_type = doc_type
    
    def get_current_document_info(self) -> Optional[Dict[str, Any]]:
        """Get info for the currently active document type"""
        if self.active_document_type == self.DOC_PCB:
            return self.get_pcb_info()
        elif self.active_document_type == self.DOC_SCHEMATIC:
            return self.get_schematic_info()
        elif self.active_document_type == self.DOC_PROJECT:
            return self.get_project_info()
        return None

