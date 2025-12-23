"""
Intelligent Agent Orchestrator - Design Co-Pilot

This agent provides intelligent PCB design assistance:
- Analyzes schematics and identifies functional blocks
- Generates placement and routing strategies
- Reviews designs for potential issues
- Suggests optimizations and improvements

NOT just a command executor - a design intelligence partner.
"""
from typing import Dict, Any, Optional, Tuple, Callable
from llm_client import LLMClient
from mcp_client import AltiumMCPClient
from design_analyzer import DesignAnalyzer
from layout_generator import LayoutGenerator, generate_layout_from_schematic
from batch_executor import BatchExecutor, AutoLayoutExecutor
from constraint_generator import ConstraintGenerator, generate_constraints_from_design
import json
import re
import logging

# Setup logging
logger = logging.getLogger(__name__)


class AgentOrchestrator:
    """
    Intelligent design co-pilot that:
    - Analyzes schematics and PCBs
    - Generates design strategies
    - Reviews and suggests improvements
    - Executes approved commands
    """
    
    def __init__(self, llm_client: LLMClient, mcp_client: AltiumMCPClient):
        self.llm_client = llm_client
        self.mcp_client = mcp_client
        self.design_analyzer = DesignAnalyzer(llm_client)
        self.layout_generator = LayoutGenerator()
        self.constraint_generator = ConstraintGenerator()
        self.auto_executor = AutoLayoutExecutor(mcp_client)
        self.conversation_history = []
        self.current_analysis = None  # Cache for design analysis
        self.current_layout = None  # Cache for generated layout
        self.pending_command = None  # Store command waiting for confirmation
    
    def process_query(self, user_query: str, stream_callback: Optional[Callable[[str], None]] = None) -> Tuple[str, str, bool]:
        """
        Process user query with design intelligence
        
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
        action = intent_response.get("action", "answer")
        
        # Handle design intelligence actions
        if action == "analyze":
            response_text = self._perform_design_analysis(user_query, all_context, intent_response)
            status = "analyzed"
            is_execution = False
            self.conversation_history.append({"role": "assistant", "content": response_text})
            return response_text, status, is_execution
        
        elif action == "strategy":
            response_text = self._generate_placement_strategy(user_query, all_context)
            status = "strategy_generated"
            is_execution = False
            self.conversation_history.append({"role": "assistant", "content": response_text})
            return response_text, status, is_execution
        
        elif action == "review":
            response_text = self._perform_design_review(user_query, all_context)
            status = "reviewed"
            is_execution = False
            self.conversation_history.append({"role": "assistant", "content": response_text})
            return response_text, status, is_execution
        
        elif action == "generate_layout":
            response_text = self._generate_autonomous_layout(user_query, all_context)
            status = "layout_generated"
            is_execution = True  # This is an execution action
            self.conversation_history.append({"role": "assistant", "content": response_text})
            return response_text, status, is_execution
        
        elif action == "execute":
            # Prepare command for confirmation (don't execute yet)
            pcb_info = all_context.get("pcb_info")
            execution_result = self._prepare_command_confirmation(intent_response, pcb_info)
            response_text = execution_result.get("message", "Command ready for confirmation")
            status = execution_result.get("status", "confirm")
            is_execution = False  # Not executed yet, waiting for confirmation
            
            # Store pending command for later execution
            self.pending_command = {
                "intent": intent_response,
                "pcb_info": pcb_info
            }
            
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
        
        system_prompt = """You are an intelligent PCB design co-pilot for Altium Designer. You help professional engineers with design intelligence, not basic operations.

The user may be requesting:
1. DESIGN ANALYSIS - Analyze schematic, identify functional blocks, understand design intent
2. PLACEMENT STRATEGY - Generate component placement recommendations
3. DESIGN REVIEW - Review design for issues, missing components, violations
4. ANSWER - Answer questions about the current design
5. EXECUTE - Execute a specific modification command (rare - professionals know Altium)

You have access to:
- Schematic data (components, nets, connections, topology)
- PCB data (layers, components, traces, board size)
- Design rules (clearance, width, via rules)
- Verification reports (DRC/ERC violations)

Respond with JSON:
{
    "action": "analyze" or "strategy" or "review" or "generate_layout" or "answer" or "execute",
    "reasoning": "brief explanation",
    "analysis_type": "functional_blocks|signal_paths|constraints|full" (if action is analyze),
    "command": "command_name" (if action is execute),
    "parameters": {} (if action is execute),
    "response": null
}

PRIORITIZE DESIGN INTELLIGENCE:
- "Analyze this schematic" → analyze (functional_blocks)
- "What are the functional blocks?" → analyze (functional_blocks)
- "Generate placement strategy" → strategy
- "How should I place these components?" → strategy
- "Review this design" → review
- "Are there any issues?" → review
- "What's missing in this design?" → review
- "Suggest placement for power supply" → strategy
- "Identify high-speed signals" → analyze (signal_paths)
- "Generate layout" → generate_layout (AUTONOMOUS LAYOUT)
- "Create initial placement" → generate_layout
- "Place all components automatically" → generate_layout
- "Auto-place the board" → generate_layout

Only use "execute" for explicit single-component commands like:
- "Move R1 to 50, 30" → execute
- "Rotate U1 by 90 degrees" → execute

Default to design intelligence (analyze/strategy/review/generate_layout) over simple answers."""
        
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
        query_lower = query.lower()
        
        # Check for project creation
        if "create project" in query_lower or "new project" in query_lower or "create new project" in query_lower:
            # Extract project name from query
            import re
            name_match = re.search(r'(?:project|project called|project named|name)\s+([A-Za-z0-9_]+)', query, re.IGNORECASE)
            project_name = name_match.group(1) if name_match else "MyProject"
            
            return {
                "action": "execute",
                "command": "create_new_project",
                "parameters": {"project_name": project_name}
            }
        
        # Check for other execution keywords
        execution_keywords = ["add", "remove", "modify", "change", "update", "place", "move", "delete", "set"]
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
    
    def _prepare_command_confirmation(self, intent: Dict[str, Any], pcb_info: Dict[str, Any] = None) -> Dict[str, Any]:
        """Prepare command confirmation message - returns confirmation request instead of executing"""
        logger.info(f"Preparing command confirmation with intent: {intent}")
        
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
            # Generate confirmation message
            confirmation_msg = self._generate_confirmation_message(command, parameters, intent.get("reasoning", ""))
            
            return {
                "status": "confirm",
                "message": confirmation_msg,
                "command": command,
                "parameters": parameters
            }
        else:
            return {
                "status": "error",
                "message": "Could not determine the command to execute."
            }
    
    def _generate_confirmation_message(self, command: str, parameters: Dict[str, Any], user_query: str = "") -> str:
        """Generate a natural confirmation message for the command"""
        # Map commands to friendly names
        command_names = {
            "create_project": "create a new project",
            "create_new_project": "create a new project",
            "move_component": "move a component",
            "rotate_component": "rotate a component",
            "add_component": "add a component",
            "remove_component": "remove a component",
            "export_pcb_info": "export PCB information",
            "place_component": "place a component",
            "add_wire": "add a wire",
            "add_net_label": "add a net label"
        }
        
        friendly_action = command_names.get(command, command.replace("_", " "))
        
        # Build parameter description
        param_desc = []
        if "project_name" in parameters:
            param_desc.append(f'named "{parameters["project_name"]}"')
        if "name" in parameters:
            param_desc.append(f'named "{parameters["name"]}"')
        if "component_name" in parameters:
            param_desc.append(f'component "{parameters["component_name"]}"')
        if "x" in parameters and "y" in parameters:
            param_desc.append(f'to position ({parameters["x"]}, {parameters["y"]})')
        
        param_text = " " + " ".join(param_desc) if param_desc else ""
        
        # Generate natural confirmation message
        return f"Are you going to {friendly_action}{param_text}?"
    
    def execute_pending_command(self) -> Dict[str, Any]:
        """Execute the pending command after user confirmation"""
        if not self.pending_command:
            return {
                "status": "error",
                "message": "No pending command to execute."
            }
        
        intent = self.pending_command.get("intent")
        pcb_info = self.pending_command.get("pcb_info")
        
        # Clear pending command
        self.pending_command = None
        
        # Execute the command
        return self._execute_command(intent, pcb_info)
    
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
            
            # Commands are now split into individual files - use main.pas router
            if is_schematic:
                result = self.mcp_client.modify_schematic(command, parameters)
            else:
                result = self.mcp_client.modify_pcb(command, parameters)
            script_name = "main.pas"  # Router script that shows which command script to run
            logger.info(f"MCP result: {result}")
            if result:
                if result.get("success", False):
                    # Command queued successfully - generate natural response using LLM
                    procedure_name = "ShowCommand"  # Shows which individual script to run
                    command_type = "schematic" if is_schematic else "PCB"
                    
                    # Generate natural, varied response using LLM
                    natural_response = self._generate_command_response(
                        user_query=intent.get("reasoning", ""),
                        command=command,
                        parameters=parameters,
                        script_name=script_name,
                        procedure_name=procedure_name,
                        command_type=command_type
                    )
                    
                    return {
                        "status": "success",
                        "message": natural_response
                    }
                else:
                    # Check if command was queued successfully
                    error_msg = result.get("message", "").lower()
                    if "queued" in error_msg or "success" in error_msg:
                        # Command queued - generate natural response
                        procedure_name = "ExecuteSchematicCommands" if is_schematic else "ExecuteCommands"
                        command_type = "schematic" if is_schematic else "PCB"
                        
                        natural_response = self._generate_command_response(
                            user_query=intent.get("reasoning", ""),
                            command=command,
                            parameters=parameters,
                            script_name=script_name,
                            procedure_name=procedure_name,
                            command_type=command_type
                        )
                        
                        return {
                            "status": "success",
                            "message": natural_response
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
        """Generate concise, short response using all available context"""
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
                    "To search components: File → Run Script → altium_component_search.pas → SearchComponents\n"
                    "Results saved to component_search.json. I'll show them after you run the search."
                )
        
        system_prompt = """You are an expert PCB/Schematic design assistant. Be concise and direct.

CRITICAL: Keep responses SHORT (2-3 sentences max). Get straight to the point.

Available data: PCB, Schematic, Project, Design Rules, Board Config, Verification, Component Search, Outputs.

Answer directly using context data. If data is missing, briefly guide them to export it.

Be natural but brief. No long explanations unless specifically asked."""
        
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
                    "To search components: File → Run Script → altium_component_search.pas → SearchComponents\n"
                    "Results saved to component_search.json. I'll show them after you run the search."
                )
                if stream_callback:
                    stream_callback(guidance)
                return guidance
        
        system_prompt = """You are an expert PCB/Schematic design assistant. Be concise and direct.

CRITICAL: Keep responses SHORT (2-3 sentences max). Get straight to the point.

Available data: PCB, Schematic, Project, Design Rules, Board Config, Verification, Component Search, Outputs.

Answer directly using context data. If data is missing, briefly guide them to export it.

Be natural but brief. No long explanations unless specifically asked."""
        
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
    
    def _generate_command_response(self, user_query: str, command: str, parameters: Dict[str, Any], 
                                   script_name: str, procedure_name: str, command_type: str) -> str:
        """
        Generate natural, varied response for command execution using LLM
        Makes responses more conversational and realistic
        """
        system_prompt = f"""You are a helpful PCB/Schematic design assistant. The user has requested a {command_type} modification command.

The command "{command}" has been successfully prepared with parameters: {json.dumps(parameters, indent=2)}

To apply this change, the user needs to:
1. Go to Altium Designer
2. Click File → Run Script
3. Select '{script_name}'
4. Choose '{procedure_name}'
5. Click OK

Generate a natural, conversational response that:
- Acknowledges what the user wants to do
- Confirms the command is ready
- Provides clear, friendly instructions on how to execute it
- Varies your wording each time (don't use the same template)
- Be concise but helpful
- Use a friendly, professional tone

IMPORTANT: 
- Don't repeat the exact same message every time
- Make it sound natural and conversational
- Show enthusiasm when appropriate
- Keep it under 3-4 sentences unless more detail is needed"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"User request: {user_query}"}
        ]
        
        # Add recent conversation context for more natural responses
        if len(self.conversation_history) > 0:
            messages.append({
                "role": "system",
                "content": f"Recent conversation context: {json.dumps(self.conversation_history[-2:], indent=2)}"
            })
        
        # Use slightly higher temperature for more variety
        response = self.llm_client.chat(messages, temperature=0.8)
        
        if response:
            return response.strip()
        else:
            # Fallback to a simple message if LLM fails
            return f"✅ I've prepared the {command} command for you. To apply it, go to Altium Designer → File → Run Script → {script_name} → {procedure_name}."
    
    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []
        self.current_analysis = None
    
    # =========================================================================
    # DESIGN INTELLIGENCE METHODS
    # =========================================================================
    
    def _perform_design_analysis(self, query: str, all_context: Dict[str, Any], 
                                  intent: Dict[str, Any]) -> str:
        """
        Perform intelligent design analysis using the DesignAnalyzer.
        Identifies functional blocks, signals, and design patterns.
        """
        analysis_type = intent.get("analysis_type", "full")
        
        # Load data into analyzer
        if all_context.get("schematic_info"):
            self.design_analyzer.load_schematic_data(all_context["schematic_info"])
        if all_context.get("pcb_info"):
            self.design_analyzer.load_pcb_data(all_context["pcb_info"])
        
        # Perform analysis
        analysis = self.design_analyzer.analyze_schematic()
        
        # Check for errors
        if isinstance(analysis, dict) and "error" in analysis:
            return (
                "I need schematic or PCB data to analyze your design. Please export your design data first:\n\n"
                "1. Open your project in Altium Designer\n"
                "2. Go to File → Run Script\n"
                "3. Run 'altium_export_schematic_info.pas' → ExportSchematicInfo\n"
                "   or 'altium_export_pcb_info.pas' → ExportPCBInfo\n\n"
                "Once exported, I can analyze your design."
            )
        
        self.current_analysis = analysis  # Cache for follow-up questions
        
        # Format response using LLM for natural language
        prompt = f"""Based on this design analysis, provide a clear summary for the PCB engineer.

User Question: {query}

Analysis Results:
{json.dumps(analysis, indent=2)}

Provide a professional, insightful response that:
1. Summarizes the key findings
2. Identifies the functional blocks found
3. Highlights critical components and their placement requirements
4. Notes any potential issues or considerations
5. Suggests next steps if appropriate

Be specific and technical - this is for a professional PCB engineer."""

        messages = [
            {"role": "system", "content": "You are an expert PCB design engineer providing design analysis insights."},
            {"role": "user", "content": prompt}
        ]
        
        response = self.llm_client.chat(messages, temperature=0.5)
        return response or "Analysis complete. Please check the design data."
    
    def _generate_placement_strategy(self, query: str, all_context: Dict[str, Any]) -> str:
        """
        Generate intelligent placement strategy recommendations.
        Uses schematic topology to suggest component placement.
        """
        # Load data into analyzer
        if all_context.get("schematic_info"):
            self.design_analyzer.load_schematic_data(all_context["schematic_info"])
        if all_context.get("pcb_info"):
            self.design_analyzer.load_pcb_data(all_context["pcb_info"])
        
        # Generate placement strategy
        strategy = self.design_analyzer.generate_placement_strategy()
        
        if "error" in strategy:
            return "I need schematic or PCB data to generate a placement strategy. Please export your design data first using the Altium scripts."
        
        # Format response
        prompt = f"""Based on this placement strategy analysis, provide clear recommendations.

User Request: {query}

Strategy Analysis:
{json.dumps(strategy, indent=2)}

Provide actionable placement recommendations that:
1. Explain the recommended board zones and why
2. List the placement order with priorities
3. Highlight critical spacing requirements
4. Suggest routing priorities
5. Note any special considerations

Be specific with measurements and component references."""

        messages = [
            {"role": "system", "content": "You are an expert PCB layout engineer providing placement strategy recommendations."},
            {"role": "user", "content": prompt}
        ]
        
        response = self.llm_client.chat(messages, temperature=0.5)
        return response or "Strategy generated. Please review the placement recommendations."
    
    def _perform_design_review(self, query: str, all_context: Dict[str, Any]) -> str:
        """
        Perform design review to identify issues and suggest improvements.
        Checks for missing components, design rule violations, etc.
        """
        # Load data into analyzer
        if all_context.get("schematic_info"):
            self.design_analyzer.load_schematic_data(all_context["schematic_info"])
        if all_context.get("pcb_info"):
            self.design_analyzer.load_pcb_data(all_context["pcb_info"])
        
        # Perform review
        review = self.design_analyzer.review_design()
        
        # Also get verification data if available
        verification = all_context.get("verification_report", {})
        
        # Format response
        prompt = f"""Based on this design review, provide a comprehensive assessment.

User Request: {query}

Design Review Results:
{json.dumps(review, indent=2)}

Verification Data:
{json.dumps(verification, indent=2) if verification else "No verification data available"}

Provide a professional design review that:
1. Lists any issues found (warnings, errors)
2. Explains why each issue matters
3. Provides specific recommendations to fix each issue
4. Suggests optimizations and improvements
5. Gives an overall design health assessment

Be constructive and specific - help the engineer improve the design."""

        messages = [
            {"role": "system", "content": "You are a senior PCB design reviewer providing constructive feedback."},
            {"role": "user", "content": prompt}
        ]
        
        response = self.llm_client.chat(messages, temperature=0.5)
        return response or "Review complete. Please check the findings."
    
    def _generate_autonomous_layout(self, query: str, all_context: Dict[str, Any]) -> str:
        """
        Generate a complete PCB layout autonomously.
        This is the core capability that converts schematic → PCB layout.
        """
        # Check for required data
        schematic_info = all_context.get("schematic_info")
        pcb_info = all_context.get("pcb_info")
        
        if not schematic_info and not pcb_info:
            return (
                "I need design data to generate a layout. Please export your schematic or PCB data first:\n\n"
                "1. Open your project in Altium Designer\n"
                "2. Go to File → Run Script\n"
                "3. Run 'altium_export_schematic_info.pas' → ExportSchematicInfo\n"
                "   or 'altium_export_pcb_info.pas' → ExportPCBInfo\n\n"
                "Once exported, I can analyze your design and generate an optimal layout."
            )
        
        # Get board size from PCB info or use defaults
        board_width = 100.0
        board_height = 80.0
        
        if pcb_info:
            board_size = pcb_info.get("board_size", {})
            board_width = board_size.get("width_mm", 100.0)
            board_height = board_size.get("height_mm", 80.0)
        
        # Get components from schematic or PCB
        components = []
        if schematic_info:
            components = schematic_info.get("components", [])
        elif pcb_info:
            components = pcb_info.get("components", [])
        
        if not components:
            return "No components found in the design data. Please ensure your schematic has components and export the data again."
        
        # First, analyze the design
        self.design_analyzer.load_schematic_data(schematic_info or {})
        if pcb_info:
            self.design_analyzer.load_pcb_data(pcb_info)
        
        analysis = self.design_analyzer.analyze_schematic()
        
        # Generate layout
        self.layout_generator.set_board_size(board_width, board_height)
        placements = self.layout_generator.generate_layout(components)
        constraints = self.layout_generator.generate_constraints(analysis.get("signal_analysis"))
        
        # Generate batch execution
        commands = self.layout_generator.generate_placement_commands()
        execution_result = self.auto_executor.execute_layout(commands, method="batch_script")
        
        # Cache for follow-up
        self.current_layout = {
            "placements": placements,
            "constraints": constraints,
            "execution": execution_result
        }
        
        # Generate response
        summary = self.layout_generator.get_placement_summary()
        
        response = f"""## Layout Generated Successfully

I've analyzed your design and generated an initial PCB layout.

### Summary
- **Components placed:** {summary['total_components']}
- **Board size:** {summary['board_size']['width_mm']}mm x {summary['board_size']['height_mm']}mm
- **Design constraints:** {summary['constraints_count']} rules generated

### Functional Block Placement
"""
        
        for block, count in summary.get("by_block", {}).items():
            response += f"- **{block.replace('_', ' ').title()}:** {count} components\n"
        
        response += f"""
### Generated Files
- **Batch Script:** `{execution_result.get('files', {}).get('script', 'batch_placement.pas')}`

### To Apply the Layout

{execution_result.get('instructions', '')}

### What's Next?
1. Review the placement in Altium
2. Adjust any components that need fine-tuning
3. Ask me to "review the design" for any issues
4. Start routing when satisfied with placement

Would you like me to explain the placement strategy or make any adjustments?
"""
        
        return response

