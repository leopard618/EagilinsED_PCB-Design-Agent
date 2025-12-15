"""
Main Agent Page with ChatGPT-like Interface
"""
import customtkinter as ctk
from mcp_client import AltiumMCPClient
from llm_client import LLMClient
from agent_orchestrator import AgentOrchestrator
from config import WINDOW_WIDTH, WINDOW_HEIGHT
import threading


class ChatMessage(ctk.CTkFrame):
    """Individual chat message widget"""
    
    def __init__(self, parent, message: str = "", is_user: bool = True, streaming: bool = False):
        super().__init__(parent, fg_color="transparent")
        self.grid_columnconfigure(0, weight=1)
        self.is_user = is_user
        self.streaming = streaming
        
        # Message frame with different colors for user/assistant
        if is_user:
            msg_frame = ctk.CTkFrame(self, fg_color=("#3B82F6", "#2563EB"), corner_radius=10)
        else:
            msg_frame = ctk.CTkFrame(self, fg_color=("#2B2B2B", "#1F1F1F"), corner_radius=10)
        
        msg_frame.grid(row=0, column=0, sticky="ew", padx=(0, 0) if is_user else (20, 0))
        
        # Message label
        self.msg_label = ctk.CTkLabel(
            msg_frame,
            text=message,
            font=ctk.CTkFont(size=13),
            anchor="w",
            justify="left",
            wraplength=WINDOW_WIDTH - 100,
            padx=15,
            pady=10
        )
        self.msg_label.grid(row=0, column=0, sticky="ew")
        msg_frame.grid_columnconfigure(0, weight=1)
    
    def append_text(self, text: str):
        """Append text to message (for streaming)"""
        current_text = self.msg_label.cget("text")
        self.msg_label.configure(text=current_text + text)


class AgentPage(ctk.CTkFrame):
    """Main agent page with ChatGPT-like interface"""
    
    # Document type display names
    DOC_TYPE_NAMES = {
        "PCB": "PCB Document",
        "SCH": "Schematic",
        "PRJ": "Project"
    }
    
    def __init__(self, parent, mcp_client: AltiumMCPClient):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.mcp_client = mcp_client
        self.messages = []
        self.doc_type = mcp_client.active_document_type if mcp_client else "PCB"
        
        try:
            self.llm_client = LLMClient()
            self.agent = AgentOrchestrator(self.llm_client, mcp_client)
        except Exception as e:
            self.llm_client = None
            self.agent = None
            print(f"Warning: LLM client not available: {e}")
        
        self.setup_ui()
        self.add_welcome_message()
    
    def setup_ui(self):
        """Setup the UI components"""
        # Configure grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # Title bar
        title_frame = ctk.CTkFrame(self, fg_color="transparent")
        title_frame.grid(row=0, column=0, sticky="ew", padx=10, pady=10)
        title_frame.grid_columnconfigure(0, weight=1)
        
        # Title (context-aware based on document type)
        doc_type_name = self.DOC_TYPE_NAMES.get(self.doc_type, "PCB Document")
        title_label = ctk.CTkLabel(
            title_frame,
            text=f"EagilinsED - {doc_type_name}",
            font=ctk.CTkFont(size=20, weight="bold"),
            anchor="center"
        )
        title_label.grid(row=0, column=0, pady=5)
        
        # Status indicator with document type
        self.status_label = ctk.CTkLabel(
            title_frame,
            text=f"● Connected to {doc_type_name}",
            font=ctk.CTkFont(size=11),
            text_color="green"
        )
        self.status_label.grid(row=1, column=0, pady=2)
        
        # Chat area (scrollable)
        self.chat_frame = ctk.CTkScrollableFrame(
            self,
            width=WINDOW_WIDTH - 20,
            height=WINDOW_HEIGHT - 180,
            fg_color=("#1A1A1A", "#1A1A1A")
        )
        self.chat_frame.grid(row=1, column=0, pady=10, padx=10, sticky="nsew")
        self.chat_frame.grid_columnconfigure(0, weight=1)
        
        # Input area
        input_frame = ctk.CTkFrame(self, fg_color="transparent")
        input_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=10)
        input_frame.grid_columnconfigure(0, weight=1)
        
        # Input entry with context-aware placeholder
        placeholder_texts = {
            "PCB": "Ask about your PCB design or request modifications...",
            "SCH": "Ask about your schematic or component connections...",
            "PRJ": "Ask about your project structure or documents..."
        }
        placeholder = placeholder_texts.get(self.doc_type, placeholder_texts["PCB"])
        
        self.input_entry = ctk.CTkEntry(
            input_frame,
            placeholder_text=placeholder,
            height=45,
            font=ctk.CTkFont(size=14),
            corner_radius=20
        )
        self.input_entry.grid(row=0, column=0, padx=5, pady=5, sticky="ew")
        self.input_entry.bind("<Return>", lambda e: self.send_message())
        
        # Send button (icon button with loading state)
        self.send_button = ctk.CTkButton(
            input_frame,
            text="",
            height=45,
            width=45,
            command=self.send_message,
            corner_radius=20,
            fg_color=("#3B82F6", "#2563EB"),
            hover_color=("#2563EB", "#1E40AF")
        )
        # Use Unicode arrow icon
        self.send_button.configure(text="➤")
        self.send_button.grid(row=0, column=1, padx=5, pady=5)
        self.is_loading = False
    
    def add_welcome_message(self):
        """Add context-aware welcome message to chat"""
        if self.doc_type == "SCH":
            welcome_text = "Hello! I'm your schematic design assistant. I can help you:\n\n"
            welcome_text += "• Analyze your schematic design\n"
            welcome_text += "• Find component connections and nets\n"
            welcome_text += "• Query pin assignments and values\n"
            welcome_text += "• Check power and ground connections\n\n"
            welcome_text += "Just ask me anything about your schematic!"
        elif self.doc_type == "PRJ":
            welcome_text = "Hello! I'm your project assistant. I can help you:\n\n"
            welcome_text += "• View project structure and documents\n"
            welcome_text += "• List schematics and PCBs in the project\n"
            welcome_text += "• Check project statistics\n"
            welcome_text += "• Navigate between documents\n\n"
            welcome_text += "Just ask me anything about your project!"
        else:  # PCB (default)
            welcome_text = "Hello! I'm your PCB design assistant. I can help you:\n\n"
            welcome_text += "• Analyze your PCB layout\n"
            welcome_text += "• Find component locations and properties\n"
            welcome_text += "• Execute modifications (move, rotate, add)\n"
            welcome_text += "• Run DRC and generate outputs\n\n"
            welcome_text += "Just ask me anything about your PCB!"
        
        self.add_message(welcome_text, is_user=False)
    
    def add_message(self, message: str, is_user: bool = True):
        """Add a message to the chat"""
        chat_msg = ChatMessage(self.chat_frame, message, is_user)
        chat_msg.grid(row=len(self.messages), column=0, sticky="ew", padx=10, pady=5)
        self.messages.append(chat_msg)
        
        # Scroll to bottom
        self.chat_frame.update()
        self.chat_frame._parent_canvas.yview_moveto(1.0)
    
    def send_message(self):
        """Send user message and get response"""
        user_text = self.input_entry.get().strip()
        
        if not user_text:
            return
        
        if not self.agent:
            self.add_message("LLM client not available. Please check OpenAI API key.", is_user=False)
            return
        
        # Clear input
        self.input_entry.delete(0, "end")
        
        # Add user message
        self.add_message(user_text, is_user=True)
        
        # Update status
        self.status_label.configure(text="● Thinking...", text_color="blue")
        
        # Set loading state
        self.set_loading_state(True)
        
        # Disable input during processing
        self.input_entry.configure(state="disabled")
        
        # Process in thread to avoid blocking UI
        thread = threading.Thread(target=self.process_message, args=(user_text,))
        thread.daemon = True
        thread.start()
    
    def set_loading_state(self, loading: bool):
        """Set loading state for send button"""
        self.is_loading = loading
        if loading:
            # Show loading rectangle icon
            self.send_button.configure(text="▭", state="disabled", fg_color=("#6B7280", "#4B5563"))
        else:
            # Show send arrow icon
            self.send_button.configure(text="➤", state="normal", fg_color=("#3B82F6", "#2563EB"))
    
    def process_message(self, user_text: str):
        """Process message in background thread"""
        try:
            # Create streaming message widget
            streaming_msg = ChatMessage(self.chat_frame, "", is_user=False, streaming=True)
            streaming_msg.grid(row=len(self.messages), column=0, sticky="ew", padx=10, pady=5)
            self.messages.append(streaming_msg)
            
            # Scroll to bottom
            self.chat_frame.update()
            self.chat_frame._parent_canvas.yview_moveto(1.0)
            
            # Define streaming callback
            def stream_callback(chunk: str):
                if chunk:
                    self.after(0, lambda: streaming_msg.append_text(chunk))
                    self.after(0, lambda: self.chat_frame._parent_canvas.yview_moveto(1.0))
            
            # Process with streaming
            response_text, status, is_execution = self.agent.process_query(user_text, stream_callback=stream_callback)
            
            # Update UI in main thread
            self.after(0, self.display_response, response_text, status, is_execution, streaming_msg)
        except Exception as e:
            error_msg = f"Error processing message: {str(e)}"
            self.after(0, self.display_response, error_msg, "error", False, None)
    
    def display_response(self, response_text: str, status: str, is_execution: bool, streaming_msg: ChatMessage = None):
        """Display response in UI (called from main thread)"""
        # If streaming message exists, ensure it has full text
        if streaming_msg:
            # Text should already be there from streaming, just ensure it's complete
            if streaming_msg.msg_label.cget("text") != response_text:
                streaming_msg.msg_label.configure(text=response_text)
        else:
            # Add assistant response (non-streaming fallback)
            self.add_message(response_text, is_user=False)
        
        # Update status
        if status == "success":
            if is_execution:
                self.status_label.configure(text="● Command Queued", text_color="orange")
            else:
                self.status_label.configure(text="● Ready", text_color="green")
        elif status == "error":
            self.status_label.configure(text="● Error", text_color="red")
        else:
            self.status_label.configure(text="● Ready", text_color="green")
        
        # Re-enable input and button
        self.set_loading_state(False)
        self.input_entry.configure(state="normal")
        self.input_entry.focus()
        
        # Final scroll to bottom
        self.chat_frame.update()
        self.chat_frame._parent_canvas.yview_moveto(1.0)
