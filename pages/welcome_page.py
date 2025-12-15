"""
Welcome and Connection Status Page
Supports PCB, Schematic, and Project document types
"""
import customtkinter as ctk
from mcp_client import AltiumMCPClient
from config import WINDOW_WIDTH, WINDOW_HEIGHT
import threading


class WelcomePage(ctk.CTkFrame):
    """Welcome page with connection functionality and document type selection"""
    
    # Document type options
    DOC_TYPES = {
        "PCB Document": {
            "type": "PCB",
            "script": "altium_scripts/altium_export_pcb_info.pas",
            "procedure": "ExportPCBInfo",
            "description": "Export PCB layout data"
        },
        "Schematic": {
            "type": "SCH", 
            "script": "altium_scripts/altium_export_schematic_info.pas",
            "procedure": "ExportSchematicInfo",
            "description": "Export schematic design data"
        },
        "Project Overview": {
            "type": "PRJ",
            "script": "altium_scripts/altium_project_manager.pas",
            "procedure": "ExportProjectInfo",
            "description": "Export project structure"
        }
    }
    
    def __init__(self, parent, on_connect_success=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.on_connect_success = on_connect_success
        self.mcp_client = AltiumMCPClient()
        self.loading_active = False
        self.loading_frame = None
        self.loading_label = None
        self.spinner_dots = 0
        self.selected_doc_type = "PCB Document"  # Default selection
        
        self.setup_ui()
    
    def setup_ui(self):
        """Setup the UI components"""
        # Configure grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)
        
        # Welcome message
        welcome_label = ctk.CTkLabel(
            self,
            text="EagilinsED",
            font=ctk.CTkFont(size=36, weight="bold"),
            anchor="center"
        )
        welcome_label.grid(row=0, column=0, pady=(60, 10), sticky="n")
        
        # Subtitle
        subtitle_label = ctk.CTkLabel(
            self,
            text="PCB Design Assistant",
            font=ctk.CTkFont(size=16),
            text_color="gray"
        )
        subtitle_label.grid(row=1, column=0, pady=(0, 30), sticky="n")
        
        # Document type selection frame
        doc_type_frame = ctk.CTkFrame(self, fg_color="transparent")
        doc_type_frame.grid(row=2, column=0, pady=10, sticky="n")
        
        # Document type label
        doc_type_label = ctk.CTkLabel(
            doc_type_frame,
            text="Select Document Type:",
            font=ctk.CTkFont(size=14, weight="bold")
        )
        doc_type_label.pack(pady=(0, 10))
        
        # Document type dropdown
        self.doc_type_var = ctk.StringVar(value="PCB Document")
        self.doc_type_menu = ctk.CTkOptionMenu(
            doc_type_frame,
            values=list(self.DOC_TYPES.keys()),
            variable=self.doc_type_var,
            command=self._on_doc_type_change,
            width=200,
            height=35,
            font=ctk.CTkFont(size=14)
        )
        self.doc_type_menu.pack(pady=5)
        
        # Document type description
        self.doc_type_desc = ctk.CTkLabel(
            doc_type_frame,
            text=self.DOC_TYPES["PCB Document"]["description"],
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        self.doc_type_desc.pack(pady=5)
        
        # Status label
        self.status_label = ctk.CTkLabel(
            self,
            text="Ready to connect to Altium Designer",
            font=ctk.CTkFont(size=14),
            text_color="gray"
        )
        self.status_label.grid(row=3, column=0, pady=15, sticky="n")
        
        # Loading text label (hidden initially) - for instructions
        self.instructions_label = ctk.CTkLabel(
            self,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        self.instructions_label.grid(row=4, column=0, pady=(0, 10), sticky="n")
        
        # Loading spinner frame (centered, hidden initially)
        self.loading_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.loading_frame.grid(row=5, column=0, sticky="nsew")
        self.loading_frame.grid_columnconfigure(0, weight=1)
        self.loading_frame.grid_rowconfigure(0, weight=1)
        
        # Spinner container
        spinner_container = ctk.CTkFrame(self.loading_frame, fg_color="transparent")
        spinner_container.grid(row=0, column=0, sticky="")
        
        # Animated loading spinner (three dots)
        self.spinner_label = ctk.CTkLabel(
            spinner_container,
            text="●  ○  ○",
            font=ctk.CTkFont(size=36),
            text_color="#3B82F6"
        )
        self.spinner_label.grid(row=0, column=0, pady=20)
        
        # Loading text below spinner (hidden - user doesn't want it)
        self.loading_text_label = ctk.CTkLabel(
            spinner_container,
            text="",
            font=ctk.CTkFont(size=14),
            text_color="gray"
        )
        self.loading_text_label.grid(row=1, column=0, pady=10)
        
        # Initially hide the loading frame
        self.loading_frame.grid_remove()
        
        # Connect button
        self.connect_button = ctk.CTkButton(
            self,
            text="Connect",
            font=ctk.CTkFont(size=18, weight="bold"),
            height=50,
            width=200,
            command=self.connect_to_altium,
            fg_color="#3B82F6",
            hover_color="#2563EB"
        )
        self.connect_button.grid(row=6, column=0, pady=30, sticky="n")
        
        # Error message label (hidden initially)
        self.error_label = ctk.CTkLabel(
            self,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="red",
            wraplength=WINDOW_WIDTH - 40
        )
        self.error_label.grid(row=7, column=0, pady=10, sticky="n")
    
    def _on_doc_type_change(self, selection):
        """Handle document type selection change"""
        self.selected_doc_type = selection
        if selection in self.DOC_TYPES:
            self.doc_type_desc.configure(text=self.DOC_TYPES[selection]["description"])
            # Update the MCP client's document type
            self.mcp_client.set_document_type(self.DOC_TYPES[selection]["type"])
    
    def _animate_spinner(self):
        """Animate the loading spinner"""
        if not self.loading_active:
            return
        
        # Three dots animation - one dot moves position
        # Cycle through: ●○○ → ○●○ → ○○● → ●○○
        spinner_states = [
            "●  ○  ○",
            "○  ●  ○",
            "○  ○  ●",
            "●  ○  ○"
        ]
        self.spinner_dots = (self.spinner_dots + 1) % len(spinner_states)
        self.spinner_label.configure(text=spinner_states[self.spinner_dots])
        
        # Loading text is hidden - no need to update
        
        # Schedule next animation frame (slower for better visibility)
        if self.loading_active:
            self.after(400, self._animate_spinner)
    
    def _start_loading(self):
        """Start the loading animation"""
        self.loading_active = True
        self.loading_frame.grid()
        self.spinner_dots = 0
        self._animate_spinner()
    
    def _stop_loading(self):
        """Stop the loading animation"""
        self.loading_active = False
        self.loading_frame.grid_remove()
    
    def connect_to_altium(self):
        """Attempt to connect to Altium Designer (waits for manual script execution)"""
        # Get selected document type info
        doc_info = self.DOC_TYPES.get(self.selected_doc_type, self.DOC_TYPES["PCB Document"])
        
        # Update UI to loading state
        self.connect_button.configure(state="disabled", text="Waiting...")
        self.doc_type_menu.configure(state="disabled")
        self.error_label.configure(text="")
        self.status_label.configure(text=f"Waiting for {self.selected_doc_type} data...", text_color="gray")
        
        # Show manual execution instructions based on document type
        instructions = (
            f"Please run the export script in Altium Designer:\n\n"
            f"1. Open your {self.selected_doc_type} in Altium\n"
            f"2. Go to: File → Run Script\n"
            f"3. Select: {doc_info['script']}\n"
            f"4. Choose procedure: {doc_info['procedure']}\n"
            f"5. Click OK\n\n"
            f"Waiting for data file..."
        )
        self.instructions_label.configure(text=instructions, text_color="gray", justify="left")
        
        # Start loading animation
        self._start_loading()
        self.update()
        
        # Run connection in a separate thread to avoid blocking UI
        def connect_thread():
            try:
                # Attempt connection (this will wait for manual script execution)
                success, message = self.mcp_client.connect()
                
                # Update UI on main thread
                self.after(0, self._on_connect_complete, success, message)
            except Exception as e:
                self.after(0, self._on_connect_complete, False, f"Connection error: {str(e)}")
        
        thread = threading.Thread(target=connect_thread, daemon=True)
        thread.start()
    
    def _on_connect_complete(self, success: bool, message: str):
        """Handle connection completion (called on main thread)"""
        # Stop loading animation
        self._stop_loading()
        
        if success:
            self.instructions_label.configure(text="")
            self.status_label.configure(text=f"Connected to {self.selected_doc_type}!", text_color="green")
            self.error_label.configure(text="", text_color="green")
            # Move to next page immediately
            if self.on_connect_success:
                self.on_connect_success(self.mcp_client)
        else:
            self.instructions_label.configure(text="")  # Clear instructions
            self.status_label.configure(text="Connection failed", text_color="red")
            self.error_label.configure(text=f"Error: {message}", text_color="red", justify="left")
            self.connect_button.configure(state="normal", text="Connect")
            self.doc_type_menu.configure(state="normal")
    
    def get_mcp_client(self):
        """Get the MCP client instance"""
        return self.mcp_client

