"""
Intelligent Agent Orchestrator
Decides whether to answer questions or execute commands
"""
from typing import Dict, Any, Optional, Tuple, Callable
from llm_client import LLMClient
from mcp_client import AltiumMCPClient
import json
import re
import logging

# Setup logging
logger = logging.getLogger(__name__)


class AgentOrchestrator:
    """Intelligent agent that decides whether to answer or execute"""
    
    def __init__(self, llm_client: LLMClient, mcp_client: AltiumMCPClient):
        self.llm_client = llm_client
        self.mcp_client = mcp_client
        self.conversation_history = []
    
    def process_query(self, user_query: str, stream_callback: Optional[Callable[[str], None]] = None) -> Tuple[str, str, bool]:
        """
        Process user query intelligently
        
        Args:
            user_query: User's query
            stream_callback: Optional callback function for streaming chunks (chunk_text) -> None
        
        Returns:
            tuple: (response_text, status_message, is_execution)
        """
        # Add user query to history
        self.conversation_history.append({"role": "user", "content": user_query})
        
        # Get ALL available context (not just PCB)
        all_context = self._get_all_available_context()
        
        # Use LLM to determine intent and generate response
        intent_response = self._determine_intent(user_query, all_context)
        
        if intent_response.get("action") == "execute":
            # Execute command via MCP (commands are queued for manual execution)
            pcb_info = all_context.get("pcb_info")
            execution_result = self._execute_command(intent_response, pcb_info)
            response_text = execution_result.get("message", "Command queued")
            status = execution_result.get("status", "success")
            # Treat "info" status as answered (not execution) since it's explaining limitations
            is_execution = (status == "success")
            
            # Add assistant response to history
            self.conversation_history.append({
                "role": "assistant", 
                "content": response_text
            })
            
            return response_text, status, is_execution
        else:
            # Generate conversational response (with streaming if callback provided)
            if stream_callback:
                response_text = self._generate_response_stream(user_query, all_context, stream_callback)
            else:
                response_text = self._generate_response(user_query, all_context)
            status = "answered"
            is_execution = False
            
            # Add assistant response to history
            self.conversation_history.append({
                "role": "assistant", 
                "content": response_text
            })
            
            return response_text, status, is_execution
    
    def _summarize_pcb_info(self, pcb_info: Dict[str, Any] = None) -> str:
        """Create a concise summary of PCB info to avoid token limits"""
        if not pcb_info:
            return "No PCB info available"
        
        try:
            stats = pcb_info.get("statistics", {})
            summary = f"PCB: {pcb_info.get('file_name', 'Unknown')}\n"
            summary += f"Board: {pcb_info.get('board_size', {}).get('width_mm', 0):.1f}mm x {pcb_info.get('board_size', {}).get('height_mm', 0):.1f}mm\n"
            summary += f"Components: {stats.get('component_count', 0)}, Nets: {stats.get('net_count', 0)}, Layers: {stats.get('layer_count', 0)}\n"
            summary += f"Vias: {stats.get('via_count', 0)}, Tracks: {stats.get('track_count', 0)}\n"
            
            # Only include component/net names if query needs them
            components = pcb_info.get("components", [])
            if components and len(components) > 0:
                # Limit to first 10 component names
                comp_names = [c.get("name", "Unknown") if isinstance(c, dict) else str(c) for c in components[:10]]
                summary += f"Sample components: {', '.join(comp_names)}\n"
            
            nets = pcb_info.get("nets", [])
            if nets and len(nets) > 0:
                net_names = [n.get("name", "Unknown") if isinstance(n, dict) else str(n) for n in nets[:10]]
                summary += f"Sample nets: {', '.join(net_names)}"
            
            return summary
        except:
            return "PCB info available but could not summarize"
    
    def _summarize_schematic_info(self, sch_info: Dict[str, Any] = None) -> str:
        """Create a concise summary of schematic info"""
        if not sch_info:
            return "No schematic info available"
        
        try:
            stats = sch_info.get("statistics", {})
            schematic = sch_info.get("schematic", {})
            summary = f"Schematic: {schematic.get('name', 'Unknown')}\n"
            summary += f"Title: {schematic.get('title', 'N/A')}\n"
            summary += f"Components: {stats.get('component_count', 0)}, Wires: {stats.get('wire_count', 0)}\n"
            summary += f"Net Labels: {stats.get('net_label_count', 0)}, Power Ports: {stats.get('power_port_count', 0)}\n"
            
            components = sch_info.get("components", [])
            if components and len(components) > 0:
                comp_names = [c.get("designator", "Unknown") if isinstance(c, dict) else str(c) for c in components[:10]]
                summary += f"Sample components: {', '.join(comp_names)}"
            
            return summary
        except:
            return "Schematic info available but could not summarize"
    
    def _summarize_project_info(self, prj_info: Dict[str, Any] = None) -> str:
        """Create a concise summary of project info"""
        if not prj_info:
            return "No project info available"
        
        try:
            project = prj_info.get("project", {})
            stats = prj_info.get("statistics", {})
            summary = f"Project: {project.get('name', 'Unknown')}\n"
            summary += f"Type: {project.get('type', 'PCB Project')}\n"
            summary += f"Documents: {stats.get('total_documents', 0)}\n"
            summary += f"Schematics: {stats.get('schematic_count', 0)}, PCBs: {stats.get('pcb_count', 0)}\n"
            
            documents = prj_info.get("documents", [])
            if documents and len(documents) > 0:
                doc_names = [d.get("name", "Unknown") if isinstance(d, dict) else str(d) for d in documents[:5]]
                summary += f"Documents: {', '.join(doc_names)}"
            
            return summary
        except:
            return "Project info available but could not summarize"
    
    def _summarize_design_rules(self, rules_info: Dict[str, Any] = None) -> str:
        """Create a concise summary of design rules"""
        if not rules_info:
            return "No design rules available"
        
        try:
            stats = rules_info.get("statistics", {})
            summary = f"Design Rules:\n"
            summary += f"Total Rules: {stats.get('total_rules', 0)}\n"
            summary += f"Clearance: {stats.get('clearance_rules', 0)}, Width: {stats.get('width_rules', 0)}, Via: {stats.get('via_rules', 0)}\n"
            
            # Get minimum clearance
            clearance_rules = rules_info.get("clearance_rules", [])
            if clearance_rules:
                min_clearance = min([r.get("minimum_mm", 999) for r in clearance_rules if r.get("enabled", True)], default=0)
                if min_clearance < 999:
                    summary += f"Min Clearance: {min_clearance:.3f} mm\n"
            
            # Get minimum width
            width_rules = rules_info.get("width_rules", [])
            if width_rules:
                min_width = min([r.get("min_width_mm", 999) for r in width_rules if r.get("enabled", True)], default=0)
                if min_width < 999:
                    summary += f"Min Track Width: {min_width:.3f} mm"
            
            return summary
        except:
            return "Design rules available but could not summarize"
    
    def _summarize_board_config(self, board_config: Dict[str, Any] = None) -> str:
        """Create a concise summary of board configuration"""
        if not board_config:
            return "No board configuration available"
        
        try:
            board = board_config.get("board", {})
            layer_stack = board_config.get("layer_stack", {})
            summary = f"Board Configuration:\n"
            summary += f"Size: {board.get('width_mm', 0):.1f} x {board.get('height_mm', 0):.1f} mm\n"
            summary += f"Layers: {layer_stack.get('total_layers', 0)} total, {layer_stack.get('signal_layers', 0)} signal\n"
            summary += f"Display Unit: {board_config.get('display_unit', 'mm')}\n"
            summary += f"Grid: {board_config.get('snap_grid_mm', 0):.3f} mm"
            return summary
        except:
            return "Board config available but could not summarize"
    
    def _summarize_verification(self, verification: Dict[str, Any] = None) -> str:
        """Create a concise summary of verification report"""
        if not verification:
            return "No verification report available"
        
        try:
            vtype = verification.get("verification_type", "Unknown")
            summary = f"Verification ({vtype}):\n"
            
            if vtype == "DRC":
                summary_data = verification.get("summary", {})
                summary += f"Violations: {summary_data.get('total_violations', 0)}\n"
                summary += f"Errors: {summary_data.get('errors', 0)}, Warnings: {summary_data.get('warnings', 0)}\n"
                summary += f"Status: {verification.get('status', 'Unknown')}"
            elif vtype == "ERC":
                summary_data = verification.get("summary", {})
                summary += f"Errors: {summary_data.get('errors', 0)}, Warnings: {summary_data.get('warnings', 0)}\n"
                summary += f"Status: {verification.get('status', 'Unknown')}"
            else:
                summary_data = verification.get("summary", {})
                summary += f"Total Nets: {summary_data.get('total_nets', 0)}\n"
                summary += f"Routed: {summary_data.get('routed_nets', 0)}, Unrouted: {summary_data.get('unrouted_nets', 0)}"
            
            return summary
        except:
            return "Verification report available but could not summarize"
    
    def _summarize_component_search(self, search_results: Dict[str, Any] = None) -> str:
        """Create a concise summary of component search results"""
        if not search_results:
            return "No component search results available"
        
        try:
            query = search_results.get("query", "Unknown")
            results = search_results.get("results", [])
            count = search_results.get("result_count", len(results))
            summary = f"Component Search: '{query}'\n"
            summary += f"Found: {count} results\n"
            
            if results and len(results) > 0:
                sample = results[:5]
                comp_names = [r.get("name", "Unknown") for r in sample]
                summary += f"Sample: {', '.join(comp_names)}"
            
            return summary
        except:
            return "Component search results available but could not summarize"
    
    def _get_all_available_context(self) -> Dict[str, Any]:
        """Get ALL available context data - returns dict of all data sources"""
        context = {}
        
        if not self.mcp_client.connected:
            return context
        
        # Try to get all available data (don't fail if some are missing)
        context["pcb_info"] = self.mcp_client.get_pcb_info()
        context["schematic_info"] = self.mcp_client.get_schematic_info()
        context["project_info"] = self.mcp_client.get_project_info()
        context["verification_report"] = self.mcp_client.get_verification_report()
        context["design_rules"] = self.mcp_client.get_design_rules()
        context["board_config"] = self.mcp_client.get_board_config()
        context["component_search"] = self.mcp_client.get_component_search()
        context["output_result"] = self.mcp_client.get_output_result()
        
        return context
    
    def _get_all_context(self) -> str:
        """Get context from all available data sources as formatted string"""
        context = ""
        all_data = self._get_all_available_context()
        
        # PCB info
        if all_data.get("pcb_info"):
            context += f"[PCB]\n{self._summarize_pcb_info(all_data['pcb_info'])}\n\n"
        
        # Schematic info
        if all_data.get("schematic_info"):
            context += f"[Schematic]\n{self._summarize_schematic_info(all_data['schematic_info'])}\n\n"
        
        # Project info
        if all_data.get("project_info"):
            context += f"[Project]\n{self._summarize_project_info(all_data['project_info'])}\n\n"
        
        # Design rules
        if all_data.get("design_rules"):
            context += f"[Design Rules]\n{self._summarize_design_rules(all_data['design_rules'])}\n\n"
        
        # Board config
        if all_data.get("board_config"):
            context += f"[Board Config]\n{self._summarize_board_config(all_data['board_config'])}\n\n"
        
        # Verification
        if all_data.get("verification_report"):
            context += f"[Verification]\n{self._summarize_verification(all_data['verification_report'])}\n\n"
        
        # Component search
        if all_data.get("component_search"):
            context += f"[Component Search]\n{self._summarize_component_search(all_data['component_search'])}\n\n"
        
        return context if context else "No design data available"
    
    def _determine_intent(self, query: str, all_context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Use LLM to determine if query requires execution or just answering"""
        if all_context is None:
            all_context = {}
        
        system_prompt = """You are an intelligent PCB/Schematic design assistant for Altium Designer. Analyze the user's query and determine:
1. If it requires executing a command in Altium Designer (like adding components, modifying layout, generating outputs, etc.)
2. If it's just a question that needs an answer

The assistant has access to multiple data sources:
- PCB information (components, nets, layers, board size)
- Schematic information (components, wires, nets, connections)
- Project information (documents, file structure)
- Design rules (clearance, width, via rules)
- Board configuration (layers, stackup, dimensions)
- Verification reports (DRC/ERC violations, connectivity)
- Component search results (library components)
- Manufacturing outputs (BOM, Pick & Place, etc.)

Respond with JSON in this format:
{
    "action": "execute" or "answer",
    "reasoning": "brief explanation",
    "command": "command_name" (if action is execute, otherwise null),
    "parameters": {} (if action is execute, otherwise null),
    "response": "your response text" (if action is answer, otherwise null)
}

Available command categories:
- PCB Modification: move_component, rotate_component, add_component, remove_component, change_value, add_track, add_via
- Schematic Modification: place_component, add_wire, add_net_label, annotate, add_power_port
- Verification: run_drc, run_erc, check_connectivity
- Output Generation: generate_gerber, generate_drill, generate_bom, generate_pick_place

Query types that should be "answer":
- Questions about schematic (components, wires, nets, connections)
- Questions about project (files, documents, structure)
- Questions about design rules (clearance, width, via sizes)
- Questions about board configuration (size, layers, stackup)
- Questions about verification (DRC/ERC violations, connectivity)
- Questions about component search results
- Questions about manufacturing outputs
- Questions about finding/searching for components (guide to run search script)

Query types that should be "execute":
- Commands to place components from search results (use place_component with library info)

Execution keywords: add, remove, modify, change, update, place, move, delete, create, set, configure, generate, run, check, verify
Answer keywords: what, how, why, explain, tell, show, describe, analyze, list, count, where, which

If the query is ambiguous, prefer "answer" unless it clearly requires modification or action."""
        
        # Build context summary from all available data
        context_summary = self._get_all_context()
        
        # Limit conversation history to last 2 exchanges (4 messages)
        recent_history = self.conversation_history[-4:] if len(self.conversation_history) > 4 else self.conversation_history
        
        context = f"Available Design Data:\n{context_summary}\n\n"
        if recent_history:
            context += f"Recent conversation: {json.dumps(recent_history, indent=2)[:500]}"  # Limit history size
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"{context}\n\nUser query: {query}"}
        ]
        
        response = self.llm_client.chat(messages, temperature=0.3)
        
        if response:
            try:
                # Try to extract JSON from response
                json_match = re.search(r'\{.*\}', response, re.DOTALL)
                if json_match:
                    return json.loads(json_match.group())
                else:
                    # Fallback: determine by keywords
                    return self._fallback_intent_detection(query)
            except:
                return self._fallback_intent_detection(query)
        
        return self._fallback_intent_detection(query)
    
    def _fallback_intent_detection(self, query: str) -> Dict[str, Any]:
        """Fallback intent detection using keywords"""
        execution_keywords = ["add", "remove", "modify", "change", "update", "place", "move", "delete", "create", "set"]
        query_lower = query.lower()
        
        if any(keyword in query_lower for keyword in execution_keywords):
            return {
                "action": "execute",
                "command": "modify_pcb",
                "parameters": {"request": query}
            }
        else:
            return {
                "action": "answer",
                "response": None
            }
    
    def _execute_command(self, intent: Dict[str, Any], pcb_info: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute command via MCP - routes to PCB or Schematic based on command type"""
        logger.info(f"Executing command with intent: {intent}")
        
        if not self.mcp_client.connected:
            logger.warning("Not connected to Altium Designer")
            return {
                "status": "error",
                "message": "Not connected to Altium Designer. Please connect first."
            }
        
        command = intent.get("command")
        parameters = intent.get("parameters", {})
        
        if not command:
            # Generate command from query using LLM
            command_data = self.llm_client.generate_modification_command(
                intent.get("reasoning", ""),
                pcb_info
            )
            if command_data:
                command = command_data.get("command")
                parameters = command_data.get("parameters", {})
        
        if command:
            # Determine if this is a schematic command
            schematic_commands = ["place_component", "add_wire", "add_net_label", "annotate", "add_power_port"]
            is_schematic = any(cmd in command.lower() for cmd in schematic_commands)
            
            logger.info(f"Sending command to MCP: {command} with params: {parameters} (schematic: {is_schematic})")
            
            if is_schematic:
                result = self.mcp_client.modify_schematic(command, parameters)
                script_name = "altium_schematic_modify.pas"
            else:
                result = self.mcp_client.modify_pcb(command, parameters)
                script_name = "altium_execute_commands.pas"
            logger.info(f"MCP result: {result}")
            if result:
                if result.get("success", False):
                    # Command queued successfully
                    procedure_name = "ExecuteSchematicCommands" if is_schematic else "ExecuteCommands"
                    return {
                        "status": "success",
                        "message": f"✅ Got it! I've prepared the command for you. " +
                                  f"To apply it, just go to Altium Designer and click File → Run Script, " +
                                  f"then select '{script_name}' and choose '{procedure_name}'. " +
                                  f"It only takes a couple of clicks!"
                    }
                else:
                    # Check if command was queued successfully
                    error_msg = result.get("message", "").lower()
                    if "queued" in error_msg or "success" in error_msg:
                        # Command queued - provide friendly guidance
                        procedure_name = "ExecuteSchematicCommands" if is_schematic else "ExecuteCommands"
                        return {
                            "status": "success",
                            "message": f"✅ Perfect! I've prepared everything for you. " +
                                      f"To apply the change, simply go to Altium Designer and click File → Run Script, " +
                                      f"then select '{script_name}' and choose '{procedure_name}'. " +
                                      f"It's just two quick clicks!"
                            }
                    else:
                        # Modification not supported - provide helpful message
                        return {
                            "status": "info",
                            "message": "I understand you want to modify the PCB, but the current file-based connection method doesn't support modifications.\n\n" +
                                      "To enable modifications, you would need:\n" +
                                      "1. A real MCP server with COM interface to Altium Designer\n" +
                                      "2. Or an Altium script that can process modification commands\n\n" +
                                      "For now, I can help you:\n" +
                                      "• Analyze your PCB design\n" +
                                      "• Get component locations and details\n" +
                                      "• Query net information\n" +
                                      "• Provide design recommendations\n\n" +
                                      "Would you like me to help analyze your PCB instead?"
                        }
            else:
                return {
                    "status": "error",
                    "message": f"Failed to execute command: {command}. The file-based MCP server doesn't support modifications."
                }
        else:
            return {
                "status": "error",
                "message": "Could not determine command to execute. Please be more specific."
            }
    
    def _get_relevant_context_data(self, query: str, all_context: Dict[str, Any] = None) -> str:
        """Extract only relevant data based on query to save tokens - uses ALL available context"""
        if not all_context:
            all_context = {}
        
        query_lower = query.lower()
        context = ""
        
        # Determine which data sources are relevant to the query
        needs_pcb = any(word in query_lower for word in ["pcb", "board", "component", "net", "via", "track", "layer"])
        needs_schematic = any(word in query_lower for word in ["schematic", "sch", "wire", "pin", "connection"])
        needs_project = any(word in query_lower for word in ["project", "file", "document", "prj"])
        needs_rules = any(word in query_lower for word in ["rule", "clearance", "width", "design rule", "constraint"])
        needs_config = any(word in query_lower for word in ["config", "setup", "stackup", "layer stack", "board size"])
        needs_verification = any(word in query_lower for word in ["drc", "erc", "violation", "error", "check", "verify"])
        needs_search = any(word in query_lower for word in ["search", "find", "component", "library", "part"])
        needs_output = any(word in query_lower for word in ["bom", "gerber", "output", "manufacturing", "pick", "place"])
        
        # PCB info
        pcb_info = all_context.get("pcb_info")
        if needs_pcb and pcb_info:
            context += self._get_relevant_pcb_data(query, pcb_info)
            context += "\n"
        
        # Schematic info
        if needs_schematic and all_context.get("schematic_info"):
            sch_info = all_context["schematic_info"]
            context += f"[Schematic]\n{self._summarize_schematic_info(sch_info)}\n"
            
            # Add specific component details if asked
            if "component" in query_lower:
                components = sch_info.get("components", [])
                if components:
                    comp_names = [c.get("designator", "Unknown") for c in components[:10]]
                    context += f"Components: {', '.join(comp_names)}\n"
            context += "\n"
        
        # Project info
        if needs_project and all_context.get("project_info"):
            context += f"[Project]\n{self._summarize_project_info(all_context['project_info'])}\n\n"
        
        # Design rules
        if needs_rules and all_context.get("design_rules"):
            context += f"[Design Rules]\n{self._summarize_design_rules(all_context['design_rules'])}\n\n"
        
        # Board config
        if needs_config and all_context.get("board_config"):
            context += f"[Board Config]\n{self._summarize_board_config(all_context['board_config'])}\n\n"
        
        # Verification
        if needs_verification and all_context.get("verification_report"):
            context += f"[Verification]\n{self._summarize_verification(all_context['verification_report'])}\n\n"
        
        # Component search - always include if available, even if not explicitly asked
        search_results = all_context.get("component_search")
        if search_results:
            context += f"[Component Search Results]\n{self._summarize_component_search(search_results)}\n\n"
            # Add detailed results if user is asking about search
            if needs_search:
                results = search_results.get("results", [])
                if results:
                    context += "Available components from search:\n"
                    for i, result in enumerate(results[:10], 1):  # Limit to 10
                        comp_name = result.get("name", "Unknown")
                        comp_desc = result.get("description", "No description")
                        comp_lib = result.get("library", "Unknown library")
                        context += f"{i}. {comp_name} ({comp_lib})\n"
                        if comp_desc and comp_desc != "No description":
                            context += f"   Description: {comp_desc}\n"
                    context += "\n"
        
        # Library list - include if user is searching
        if needs_search and all_context.get("library_list"):
            lib_list = all_context["library_list"]
            libraries = lib_list.get("libraries", [])
            if libraries:
                context += f"[Available Libraries]\n"
                context += f"Total: {lib_list.get('library_count', 0)} libraries\n"
                lib_names = [lib.get("name", "Unknown") for lib in libraries[:10]]
                context += f"Sample: {', '.join(lib_names)}\n\n"
        
        # Output results
        if needs_output and all_context.get("output_result"):
            output = all_context["output_result"]
            context += f"[Outputs]\nType: {output.get('output_type', 'Unknown')}\n"
            context += f"Status: {output.get('status', 'Unknown')}\n\n"
        
        # If no specific context matched, provide summary of what's available
        if not context:
            available = []
            if all_context.get("pcb_info"):
                available.append("PCB")
            if all_context.get("schematic_info"):
                available.append("Schematic")
            if all_context.get("project_info"):
                available.append("Project")
            if all_context.get("design_rules"):
                available.append("Design Rules")
            if all_context.get("board_config"):
                available.append("Board Config")
            if all_context.get("verification_report"):
                available.append("Verification")
            
            if available:
                context = f"Available data: {', '.join(available)}. Please ask a specific question about one of these.\n"
            else:
                context = "No design data available. Please export data from Altium Designer first.\n"
        
        return context
    
    def _get_relevant_pcb_data(self, query: str, pcb_info: Dict[str, Any] = None) -> str:
        """Extract only relevant PCB data based on query to save tokens"""
        if not pcb_info:
            return "No PCB information available."
        
        query_lower = query.lower()
        context = ""
        
        # Always include basic stats
        stats = pcb_info.get("statistics", {})
        context += f"PCB: {pcb_info.get('file_name', 'Unknown')}\n"
        context += f"Board size: {pcb_info.get('board_size', {}).get('width_mm', 0):.1f}mm x {pcb_info.get('board_size', {}).get('height_mm', 0):.1f}mm\n"
        context += f"Statistics: {stats.get('component_count', 0)} components, {stats.get('net_count', 0)} nets, {stats.get('layer_count', 0)} layers\n"
        
        # Only include detailed data if query asks for it
        if "component" in query_lower or "where" in query_lower or "location" in query_lower or "size" in query_lower or "value" in query_lower:
            components = pcb_info.get("components", [])
            if components:
                # Extract component name from query (e.g., "C168", "R1", etc.)
                # Look for patterns like "C168", "R1", "U12", etc.
                import re
                comp_pattern = re.search(r'\b([CRUDLT][0-9]+)\b', query, re.IGNORECASE)
                found_component = None
                
                if comp_pattern:
                    # Search for exact component name match
                    target_name = comp_pattern.group(1).upper()  # Normalize to uppercase
                    for comp in components:
                        comp_name = comp.get("name", "") if isinstance(comp, dict) else str(comp)
                        if comp_name.upper() == target_name:
                            found_component = comp
                            break
                
                # If not found by pattern, try substring match
                if not found_component:
                    for comp in components:
                        comp_name = comp.get("name", "") if isinstance(comp, dict) else str(comp)
                        # Check if component name appears in query
                        if comp_name.lower() in query_lower or query_lower in comp_name.lower():
                            found_component = comp
                            break
                
                if found_component:
                    # Include full details for this component
                    comp_name = found_component.get("name", "") if isinstance(found_component, dict) else str(found_component)
                    context += f"\nComponent {comp_name}:\n"
                    loc = found_component.get("location", {})
                    size = found_component.get("size", {})
                    context += f"  Location: ({loc.get('x_mm', 0):.2f}, {loc.get('y_mm', 0):.2f}) mm\n"
                    context += f"  Size: {size.get('width_mm', 0):.2f} x {size.get('height_mm', 0):.2f} mm\n"
                    context += f"  Layer: {found_component.get('layer', 'Unknown')}\n"
                    context += f"  Footprint: {found_component.get('footprint', 'Unknown')}\n"
                    context += f"  Rotation: {found_component.get('rotation_degrees', 0):.1f} degrees\n"
                    # Extract value from parameters
                    params = found_component.get("parameters", [])
                    if params and isinstance(params, list):
                        for param in params:
                            if isinstance(param, dict) and param.get("name") == "Value":
                                context += f"  Value: {param.get('value', 'Unknown')}\n"
                                break
                else:
                    # Just list some component names as examples
                    comp_names = [c.get("name", "") if isinstance(c, dict) else str(c) for c in components[:15]]
                    context += f"Sample components: {', '.join(comp_names)}\n"
        
        # Handle list queries (all resistors, all capacitors, etc.)
        if "list" in query_lower or "all" in query_lower or "show" in query_lower:
            components = pcb_info.get("components", [])
            if components:
                if "resistor" in query_lower or "r" in query_lower:
                    # Filter resistors (components starting with R)
                    resistors = [c.get("name", "") if isinstance(c, dict) else str(c) for c in components if (isinstance(c, dict) and c.get("name", "").upper().startswith("R")) or (isinstance(c, str) and c.upper().startswith("R"))]
                    if resistors:
                        context += f"\nResistors on board: {', '.join(resistors[:30])}\n"
                elif "capacitor" in query_lower or "c" in query_lower:
                    # Filter capacitors (components starting with C)
                    capacitors = [c.get("name", "") if isinstance(c, dict) else str(c) for c in components if (isinstance(c, dict) and c.get("name", "").upper().startswith("C")) or (isinstance(c, str) and c.upper().startswith("C"))]
                    if capacitors:
                        context += f"\nCapacitors on board: {', '.join(capacitors[:30])}\n"
                else:
                    # List all components
                    comp_names = [c.get("name", "") if isinstance(c, dict) else str(c) for c in components[:50]]
                    context += f"\nComponents on board: {', '.join(comp_names)}\n"
        
        if "net" in query_lower:
            nets = pcb_info.get("nets", [])
            if nets:
                net_names = [n.get("name", "") if isinstance(n, dict) else str(n) for n in nets[:15]]
                context += f"Nets: {', '.join(net_names)}\n"
        
        if "layer" in query_lower:
            layers = pcb_info.get("layers", [])
            if layers:
                context += f"Layers: {', '.join(layers)}\n"
        
        return context
    
    def _generate_response(self, query: str, all_context: Dict[str, Any] = None) -> str:
        """Generate conversational response using all available context"""
        if all_context is None:
            all_context = {}
        
        query_lower = query.lower()
        
        # Special handling for component search queries
        if any(word in query_lower for word in ["find", "search", "look for", "component", "library", "part"]) and \
           not any(word in query_lower for word in ["result", "found", "show", "list", "what"]):
            search_results = all_context.get("component_search")
            if not search_results:
                # Guide user to run search script
                return (
                    "I can help you search for components in your Altium libraries! 🔍\n\n"
                    "To search for components:\n"
                    "1. In Altium Designer, go to File → Run Script\n"
                    "2. Select: `altium_component_search.pas`\n"
                    "3. Choose: `SearchComponents`\n"
                    "4. Enter your search term (e.g., 'resistor', '10k', '0805')\n"
                    "5. The results will be saved to `component_search.json`\n\n"
                    "After you run the search, I can:\n"
                    "• Show you the search results\n"
                    "• Help you place components from the results\n"
                    "• Answer questions about found components\n\n"
                    "You can also list all installed libraries by running `ListInstalledLibraries` from the same script."
                )
        
        system_prompt = """You are an expert PCB/Schematic design assistant for Altium Designer. Provide helpful, clear, and technical answers about PCB design, schematic design, design rules, board configuration, and manufacturing.

You have access to multiple data sources:
- PCB information (components, nets, layers, board size)
- Schematic information (components, wires, nets, power ports)
- Project information (documents, file structure)
- Design rules (clearance, width, via rules)
- Board configuration (layers, stackup, dimensions)
- Verification reports (DRC/ERC violations, connectivity)
- Component search results (library components found in search)
- Manufacturing outputs (BOM, Pick & Place, etc.)

Use the relevant context data provided to give accurate, context-aware responses. If the user asks about something that's in the context, answer directly using that data. If data is not available, guide them on how to export it from Altium Designer.

IMPORTANT: 
- If the user asks about component search results and they are available in the context, show them the results and offer to help place components from the search results.
- When showing search results, include component name, library, and description.
- If user wants to place a component from search results, guide them to use the place_component command with the library information from the search results."""
        
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add recent conversation history (limit to last 2 exchanges = 4 messages)
        messages.extend(self.conversation_history[-4:])
        
        # Add only relevant context (not full JSON) - intelligently selected based on query
        relevant_context = self._get_relevant_context_data(query, all_context)
        if relevant_context:
            messages.append({
                "role": "system",
                "content": f"Design Context:\n{relevant_context}"
            })
        
        response = self.llm_client.chat(messages, temperature=0.7)
        return response or "I'm sorry, I couldn't generate a response. Please try again."
    
    def _generate_response_stream(self, query: str, all_context: Dict[str, Any] = None, stream_callback: Callable[[str], None] = None) -> str:
        """Generate conversational response with streaming using all available context"""
        if all_context is None:
            all_context = {}
        
        query_lower = query.lower()
        
        # Special handling for component search queries (non-streaming for guidance)
        if any(word in query_lower for word in ["find", "search", "look for", "component", "library", "part"]) and \
           not any(word in query_lower for word in ["result", "found", "show", "list", "what"]):
            search_results = all_context.get("component_search")
            if not search_results:
                guidance = (
                    "I can help you search for components in your Altium libraries! 🔍\n\n"
                    "To search for components:\n"
                    "1. In Altium Designer, go to File → Run Script\n"
                    "2. Select: `altium_component_search.pas`\n"
                    "3. Choose: `SearchComponents`\n"
                    "4. Enter your search term (e.g., 'resistor', '10k', '0805')\n"
                    "5. The results will be saved to `component_search.json`\n\n"
                    "After you run the search, I can:\n"
                    "• Show you the search results\n"
                    "• Help you place components from the results\n"
                    "• Answer questions about found components\n\n"
                    "You can also list all installed libraries by running `ListInstalledLibraries` from the same script."
                )
                if stream_callback:
                    stream_callback(guidance)
                return guidance
        
        system_prompt = """You are an expert PCB/Schematic design assistant for Altium Designer. Provide helpful, clear, and technical answers about PCB design, schematic design, design rules, board configuration, and manufacturing.

You have access to multiple data sources:
- PCB information (components, nets, layers, board size, locations, values, footprints)
- Schematic information (components, wires, nets, power ports, connections)
- Project information (documents, file structure)
- Design rules (clearance, width, via rules, net classes)
- Board configuration (layers, stackup, dimensions, origin, grid)
- Verification reports (DRC/ERC violations, connectivity status)
- Component search results (library components found in search)
- Manufacturing outputs (BOM, Pick & Place, Gerber, etc.)

When answering questions, use the provided context data directly. Do NOT say you don't have access to the information if it's provided in the context.
Be specific and accurate with the data provided. If the user asks about something in the context, answer directly using that data.

IMPORTANT: 
- If the user asks about component search results and they are available in the context, show them the results and offer to help place components from the search results.
- When showing search results, include component name, library, and description.
- If user wants to place a component from search results, guide them to use the place_component command with the library information from the search results."""
        
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add recent conversation history (limit to last 2 exchanges = 4 messages)
        messages.extend(self.conversation_history[-4:])
        
        # Add only relevant context (not full JSON) - intelligently selected based on query
        relevant_context = self._get_relevant_context_data(query, all_context)
        if relevant_context:
            messages.append({
                "role": "system",
                "content": f"Design Context:\n{relevant_context}"
            })
        
        full_response = ""
        for chunk in self.llm_client.chat_stream(messages, temperature=0.7):
            if chunk:
                full_response += chunk
                if stream_callback:
                    stream_callback(chunk)
        
        return full_response or "I'm sorry, I couldn't generate a response. Please try again."
    
    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []

