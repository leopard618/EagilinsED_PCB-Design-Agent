"""
Intelligent Agent Orchestrator
Decides whether to answer questions or execute commands
"""
from typing import Dict, Any, Optional, Tuple, Callable
from llm_client import LLMClient
from mcp_client import AltiumMCPClient
import json
import re


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
        
        # Get current PCB info for context
        pcb_info = self.mcp_client.get_pcb_info() if self.mcp_client.connected else None
        
        # Use LLM to determine intent and generate response
        intent_response = self._determine_intent(user_query, pcb_info)
        
        if intent_response.get("action") == "execute":
            # Execute command via MCP (commands are queued for manual execution)
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
                response_text = self._generate_response_stream(user_query, pcb_info, stream_callback)
            else:
                response_text = self._generate_response(user_query, pcb_info)
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
    
    def _get_all_context(self) -> str:
        """Get context from all available data sources"""
        context = ""
        
        # PCB info
        pcb_info = self.mcp_client.get_pcb_info() if self.mcp_client.connected else None
        if pcb_info:
            context += f"[PCB]\n{self._summarize_pcb_info(pcb_info)}\n\n"
        
        # Schematic info
        sch_info = self.mcp_client.get_schematic_info() if self.mcp_client.connected else None
        if sch_info:
            context += f"[Schematic]\n{self._summarize_schematic_info(sch_info)}\n\n"
        
        # Project info
        prj_info = self.mcp_client.get_project_info() if self.mcp_client.connected else None
        if prj_info:
            context += f"[Project]\n{self._summarize_project_info(prj_info)}\n\n"
        
        return context if context else "No design data available"
    
    def _determine_intent(self, query: str, pcb_info: Dict[str, Any] = None) -> Dict[str, Any]:
        """Use LLM to determine if query requires execution or just answering"""
        system_prompt = """You are an intelligent PCB/Schematic design assistant for Altium Designer. Analyze the user's query and determine:
1. If it requires executing a command in Altium Designer (like adding components, modifying layout, generating outputs, etc.)
2. If it's just a question that needs an answer

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
- Schematic Operations: place_component, add_wire, add_net_label, annotate
- Verification: run_drc, run_erc, check_connectivity
- Output Generation: generate_gerber, generate_drill, generate_bom, generate_pick_place

Execution keywords: add, remove, modify, change, update, place, move, delete, create, set, configure, generate, run, check, verify
Answer keywords: what, how, why, explain, tell, show, describe, analyze, list, count

If the query is ambiguous, prefer "answer" unless it clearly requires modification or action."""
        
        # Use summarized PCB info instead of full JSON
        pcb_summary = self._summarize_pcb_info(pcb_info)
        
        # Limit conversation history to last 2 exchanges (4 messages)
        recent_history = self.conversation_history[-4:] if len(self.conversation_history) > 4 else self.conversation_history
        
        context = f"PCB Summary: {pcb_summary}\n\n"
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
        """Execute command via MCP"""
        if not self.mcp_client.connected:
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
            result = self.mcp_client.modify_pcb(command, parameters)
            if result:
                if result.get("success", False):
                    # Command queued successfully
                    return {
                        "status": "success",
                        "message": "✅ Got it! I've prepared the command for you. " +
                                  "To apply it, just go to Altium Designer and click File → Run Script, " +
                                  "then select 'altium_execute_commands.pas' and choose 'ExecuteCommands'. " +
                                  "It only takes a couple of clicks!"
                    }
                else:
                    # Check if command was queued successfully
                    error_msg = result.get("message", "").lower()
                    if "queued" in error_msg or "success" in error_msg:
                        # Command queued - provide friendly guidance
                        return {
                            "status": "success",
                            "message": "✅ Perfect! I've prepared everything for you. " +
                                      "To apply the change, simply go to Altium Designer and click File → Run Script, " +
                                          "then select 'altium_execute_commands.pas' and choose 'ExecuteCommands'. " +
                                          "It's just two quick clicks!"
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
    
    def _generate_response(self, query: str, pcb_info: Dict[str, Any] = None) -> str:
        """Generate conversational response"""
        system_prompt = """You are an expert PCB design assistant. Provide helpful, clear, and technical answers about PCB design.
        Use the PCB information provided to give context-aware responses. If you need specific component or net details, ask the user to query them specifically."""
        
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add recent conversation history (limit to last 2 exchanges = 4 messages)
        messages.extend(self.conversation_history[-4:])
        
        # Add only relevant PCB info (not full JSON)
        pcb_context = self._get_relevant_pcb_data(query, pcb_info)
        if pcb_context:
            messages.append({
                "role": "system",
                "content": f"PCB Context:\n{pcb_context}"
            })
        
        response = self.llm_client.chat(messages, temperature=0.7)
        return response or "I'm sorry, I couldn't generate a response. Please try again."
    
    def _generate_response_stream(self, query: str, pcb_info: Dict[str, Any] = None, stream_callback: Callable[[str], None] = None) -> str:
        """Generate conversational response with streaming"""
        system_prompt = """You are an expert PCB design assistant. Provide helpful, clear, and technical answers about PCB design.
        Use the PCB information provided in the context to answer questions directly. You have access to detailed component information including:
        - Component locations (x, y coordinates in mm)
        - Component sizes (width x height in mm)
        - Component values (from parameters)
        - Component footprints
        - Component layers and rotations
        - Net information
        - Board statistics
        
        When answering questions, use the provided PCB context data directly. Do NOT say you don't have access to the information if it's provided in the context.
        Be specific and accurate with the data provided."""
        
        messages = [
            {"role": "system", "content": system_prompt}
        ]
        
        # Add recent conversation history (limit to last 2 exchanges = 4 messages)
        messages.extend(self.conversation_history[-4:])
        
        # Add only relevant PCB info (not full JSON)
        pcb_context = self._get_relevant_pcb_data(query, pcb_info)
        if pcb_context:
            messages.append({
                "role": "system",
                "content": f"PCB Context:\n{pcb_context}"
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

