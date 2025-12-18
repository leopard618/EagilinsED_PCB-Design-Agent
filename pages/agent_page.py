"""
Agent Page - Professional Chat Interface
Main interaction page for EagilinsED
"""
import customtkinter as ctk
from mcp_client import AltiumMCPClient
from llm_client import LLMClient
from agent_orchestrator import AgentOrchestrator
from config import WINDOW_WIDTH, WINDOW_HEIGHT
import threading
import re


def strip_markdown(text: str) -> str:
    """Remove markdown formatting from text"""
    # Remove bold **text** or __text__
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'__(.+?)__', r'\1', text)
    # Remove italic *text* or _text_
    text = re.sub(r'\*(.+?)\*', r'\1', text)
    text = re.sub(r'_(.+?)_', r'\1', text)
    # Remove code blocks ```text```
    text = re.sub(r'```[\s\S]*?```', '', text)
    # Remove inline code `text`
    text = re.sub(r'`(.+?)`', r'\1', text)
    # Remove headers # ## ###
    text = re.sub(r'^#{1,6}\s*', '', text, flags=re.MULTILINE)
    return text


class ChatMessage(ctk.CTkFrame):
    """Professional chat message bubble"""
    
    def __init__(self, parent, message: str = "", is_user: bool = True, colors: dict = None):
        super().__init__(parent, fg_color="transparent")
        self.grid_columnconfigure(0, weight=1)
        self.is_user = is_user
        
        # Default colors
        self.colors = colors or {
            "user_bg": "#3b82f6",
            "assistant_bg": "#1e293b",
            "border": "#334155",
            "text": "#f8fafc"
        }
        
        # Container for alignment
        container = ctk.CTkFrame(self, fg_color="transparent")
        container.grid(row=0, column=0, sticky="e" if is_user else "w")
        
        # Message bubble
        bubble_color = self.colors["user_bg"] if is_user else self.colors["assistant_bg"]
        bubble = ctk.CTkFrame(
            container,
            fg_color=bubble_color,
            corner_radius=16,
            border_width=0 if is_user else 1,
            border_color=self.colors["border"]
        )
        bubble.grid(row=0, column=0, padx=(60 if is_user else 0, 0 if is_user else 60))
        
        # Message text
        self.msg_label = ctk.CTkLabel(
            bubble,
            text=message,
            font=ctk.CTkFont(size=13),
            text_color=self.colors["text"],
            anchor="w",
            justify="left",
            wraplength=WINDOW_WIDTH - 160
        )
        self.msg_label.grid(row=0, column=0, sticky="w", padx=16, pady=14)
    
    def append_text(self, text: str):
        """Append text for streaming"""
        current = self.msg_label.cget("text")
        self.msg_label.configure(text=current + text)
    
    def set_text(self, text: str):
        """Set complete text (strips markdown for assistant)"""
        if not self.is_user:
            text = strip_markdown(text)
        self.msg_label.configure(text=text)


class AgentPage(ctk.CTkFrame):
    """Professional agent chat interface"""
    
    def __init__(self, parent, mcp_client: AltiumMCPClient, on_back=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.mcp_client = mcp_client
        self.on_back = on_back
        self.messages = []
        self.is_loading = False
        
        # Color scheme (matching welcome page)
        self.colors = {
            "bg_dark": "#0f172a",
            "bg_card": "#1e293b",
            "bg_input": "#334155",
            "border": "#475569",
            "primary": "#3b82f6",
            "primary_hover": "#2563eb",
            "success": "#10b981",
            "warning": "#f59e0b",
            "error": "#ef4444",
            "text": "#f8fafc",
            "text_muted": "#94a3b8",
            "text_dim": "#64748b",
            "accent": "#06b6d4",
            "user_bg": "#3b82f6",
            "assistant_bg": "#1e293b"
        }
        
        self.configure(fg_color=self.colors["bg_dark"])
        
        # Initialize LLM
        try:
            self.llm_client = LLMClient()
            self.agent = AgentOrchestrator(self.llm_client, mcp_client)
        except Exception as e:
            self.llm_client = None
            self.agent = None
            print(f"LLM client error: {e}")
        
        self.setup_ui()
        self.add_welcome_message()
    
    def setup_ui(self):
        """Setup professional UI"""
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # === Header ===
        header = ctk.CTkFrame(self, fg_color=self.colors["bg_card"], height=60, corner_radius=0)
        header.grid(row=0, column=0, sticky="ew")
        header.grid_columnconfigure(1, weight=1)  # Middle section expands
        header.grid_propagate(False)
        
        # Left section: Back + Brand
        left_frame = ctk.CTkFrame(header, fg_color="transparent")
        left_frame.grid(row=0, column=0, sticky="w", padx=(12, 0), pady=10)
        
        back_btn = ctk.CTkButton(
            left_frame,
            text="←",
            font=ctk.CTkFont(size=16),
            width=36,
            height=36,
            corner_radius=8,
            fg_color="transparent",
            hover_color=self.colors["bg_input"],
            text_color=self.colors["text_muted"],
            command=self.go_back
        )
        back_btn.pack(side="left")
        
        brand = ctk.CTkLabel(
            left_frame,
            text="EagilinsED",
            font=ctk.CTkFont(family="Segoe UI", size=18, weight="bold"),
            text_color=self.colors["text"]
        )
        brand.pack(side="left", padx=(8, 0))
        
        # Right section: Status + Clear
        right_frame = ctk.CTkFrame(header, fg_color="transparent")
        right_frame.grid(row=0, column=2, sticky="e", padx=(0, 16), pady=10)
        
        self.status_dot = ctk.CTkLabel(
            right_frame,
            text="●",
            font=ctk.CTkFont(size=10),
            text_color=self.colors["success"]
        )
        self.status_dot.pack(side="left", padx=(0, 4))
        
        self.status_text = ctk.CTkLabel(
            right_frame,
            text="Connected",
            font=ctk.CTkFont(size=12),
            text_color=self.colors["text_muted"]
        )
        self.status_text.pack(side="left", padx=(0, 16))
        
        clear_btn = ctk.CTkButton(
            right_frame,
            text="Clear",
            font=ctk.CTkFont(size=11),
            width=56,
            height=28,
            corner_radius=6,
            fg_color="transparent",
            hover_color=self.colors["bg_input"],
            border_width=1,
            border_color=self.colors["border"],
            text_color=self.colors["text_muted"],
            command=self.clear_chat
        )
        clear_btn.pack(side="left")
        
        # === Chat Area ===
        self.chat_frame = ctk.CTkScrollableFrame(
            self,
            fg_color=self.colors["bg_dark"],
            scrollbar_button_color=self.colors["bg_input"],
            scrollbar_button_hover_color=self.colors["border"]
        )
        self.chat_frame.grid(row=1, column=0, sticky="nsew", padx=0, pady=0)
        self.chat_frame.grid_columnconfigure(0, weight=1)
        
        # === Input Area ===
        input_container = ctk.CTkFrame(self, fg_color=self.colors["bg_card"], height=80)
        input_container.grid(row=2, column=0, sticky="ew")
        input_container.grid_columnconfigure(0, weight=1)
        input_container.grid_propagate(False)
        
        # Input wrapper
        input_wrapper = ctk.CTkFrame(
            input_container,
            fg_color=self.colors["bg_input"],
            corner_radius=12,
            border_width=1,
            border_color=self.colors["border"]
        )
        input_wrapper.grid(row=0, column=0, padx=20, pady=15, sticky="ew")
        input_wrapper.grid_columnconfigure(0, weight=1)
        
        # Input entry
        self.input_entry = ctk.CTkEntry(
            input_wrapper,
            placeholder_text="Ask about your design or request analysis...",
            font=ctk.CTkFont(size=14),
            height=40,
            border_width=0,
            fg_color="transparent",
            text_color=self.colors["text"],
            placeholder_text_color=self.colors["text_dim"]
        )
        self.input_entry.grid(row=0, column=0, padx=(15, 5), pady=5, sticky="ew")
        self.input_entry.bind("<Return>", lambda e: self.send_message())
        
        # Send button
        self.send_button = ctk.CTkButton(
            input_wrapper,
            text="→",
            font=ctk.CTkFont(size=18, weight="bold"),
            width=40,
            height=40,
            corner_radius=8,
            fg_color=self.colors["primary"],
            hover_color=self.colors["primary_hover"],
            command=self.send_message
        )
        self.send_button.grid(row=0, column=1, padx=(0, 5), pady=5)
        
        # Quick actions (optional hints)
        hints_frame = ctk.CTkFrame(input_container, fg_color="transparent")
        hints_frame.grid(row=1, column=0, padx=20, pady=(0, 10), sticky="w")
        
        hints = ["Analyze schematic", "Generate layout", "Review design"]
        for hint in hints:
            hint_btn = ctk.CTkButton(
                hints_frame,
                text=hint,
                font=ctk.CTkFont(size=10),
                height=22,
                corner_radius=11,
                fg_color="transparent",
                hover_color=self.colors["bg_input"],
                border_width=1,
                border_color=self.colors["border"],
                text_color=self.colors["text_dim"],
                command=lambda h=hint: self.quick_action(h)
            )
            hint_btn.pack(side="left", padx=(0, 8))
    
    def add_welcome_message(self):
        """Add professional welcome message"""
        welcome = """Welcome to EagilinsED, your intelligent PCB design co-pilot.

I can help you with:
• Analyze - Identify functional blocks and design patterns
• Generate Layout - Create autonomous component placement
• Review - Find issues and suggest improvements
• Strategy - Recommend placement and routing approaches

Try asking: "Analyze this schematic" or "Generate layout for this design" """
        
        self.add_message(welcome, is_user=False)
    
    def add_message(self, message: str, is_user: bool = True) -> ChatMessage:
        """Add message to chat"""
        # Strip markdown from assistant messages
        if not is_user:
            message = strip_markdown(message)
        msg = ChatMessage(self.chat_frame, message, is_user, self.colors)
        msg.grid(row=len(self.messages), column=0, sticky="ew", padx=20, pady=8)
        self.messages.append(msg)
        
        # Scroll to bottom
        self.chat_frame.update()
        self.chat_frame._parent_canvas.yview_moveto(1.0)
        
        return msg
    
    def quick_action(self, action: str):
        """Handle quick action button click"""
        self.input_entry.delete(0, "end")
        self.input_entry.insert(0, action)
        self.send_message()
    
    def send_message(self):
        """Send user message"""
        text = self.input_entry.get().strip()
        if not text or self.is_loading:
            return
        
        if not self.agent:
            self.add_message("LLM not available. Check OpenAI API key.", is_user=False)
            return
        
        # Clear input
        self.input_entry.delete(0, "end")
        
        # Add user message
        self.add_message(text, is_user=True)
        
        # Update status
        self.set_status("Processing...", "warning")
        self.set_loading(True)
        
        # Process in thread
        threading.Thread(target=self.process_message, args=(text,), daemon=True).start()
    
    def set_loading(self, loading: bool):
        """Set loading state"""
        self.is_loading = loading
        if loading:
            self.send_button.configure(text="◌", state="disabled", fg_color=self.colors["text_dim"])
            self.input_entry.configure(state="disabled")
        else:
            self.send_button.configure(text="→", state="normal", fg_color=self.colors["primary"])
            self.input_entry.configure(state="normal")
            self.input_entry.focus()
    
    def set_status(self, text: str, status: str = "success"):
        """Update status indicator"""
        colors = {
            "success": self.colors["success"],
            "warning": self.colors["warning"],
            "error": self.colors["error"],
            "info": self.colors["accent"]
        }
        color = colors.get(status, self.colors["success"])
        self.status_dot.configure(text_color=color)
        self.status_text.configure(text=text)
    
    def process_message(self, text: str):
        """Process message in background"""
        try:
            # Create streaming message
            streaming_msg = ChatMessage(self.chat_frame, "", False, self.colors)
            streaming_msg.grid(row=len(self.messages), column=0, sticky="ew", padx=20, pady=8)
            self.messages.append(streaming_msg)
            
            # Scroll
            self.after(0, lambda: self.chat_frame._parent_canvas.yview_moveto(1.0))
            
            # Stream callback
            def on_chunk(chunk: str):
                if chunk:
                    self.after(0, lambda c=chunk: streaming_msg.append_text(c))
                    self.after(0, lambda: self.chat_frame._parent_canvas.yview_moveto(1.0))
            
            # Process
            response, status, is_exec = self.agent.process_query(text, stream_callback=on_chunk)
            
            # Update UI
            self.after(0, lambda: self.on_response_complete(response, status, is_exec, streaming_msg))
            
        except Exception as e:
            self.after(0, lambda: self.on_response_complete(f"Error: {e}", "error", False, None))
    
    def on_response_complete(self, response: str, status: str, is_exec: bool, msg: ChatMessage):
        """Handle response completion"""
        if msg and msg.msg_label.cget("text") != response:
            msg.set_text(response)
        elif not msg:
            self.add_message(response, is_user=False)
        
        # Update status
        if status == "error":
            self.set_status("Error", "error")
        elif is_exec:
            self.set_status("Command Ready", "info")
        elif status in ["analyzed", "strategy_generated", "reviewed", "layout_generated"]:
            self.set_status("Analysis Complete", "success")
        else:
            self.set_status("Ready", "success")
        
        self.set_loading(False)
        
        # Final scroll
        self.chat_frame.update()
        self.chat_frame._parent_canvas.yview_moveto(1.0)
    
    def clear_chat(self):
        """Clear chat history"""
        for msg in self.messages:
            msg.destroy()
        self.messages = []
        
        if self.agent:
            self.agent.clear_history()
        
        self.add_welcome_message()
        self.set_status("Ready", "success")
    
    def go_back(self):
        """Go back to project setup page"""
        self.clear_chat()
        if self.on_back:
            self.on_back()
