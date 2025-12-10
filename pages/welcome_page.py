"""
Welcome and Connection Status Page
"""
import customtkinter as ctk
from mcp_client import AltiumMCPClient
from config import WINDOW_WIDTH, WINDOW_HEIGHT
import threading


class WelcomePage(ctk.CTkFrame):
    """Welcome page with connection functionality"""
    
    def __init__(self, parent, on_connect_success=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.on_connect_success = on_connect_success
        self.mcp_client = AltiumMCPClient()
        self.loading_active = False
        self.loading_frame = None
        self.loading_label = None
        self.spinner_dots = 0
        
        self.setup_ui()
    
    def setup_ui(self):
        """Setup the UI components"""
        # Configure grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # Welcome message
        welcome_label = ctk.CTkLabel(
            self,
            text="Welcome to\nEagilinsED",
            font=ctk.CTkFont(size=32, weight="bold"),
            anchor="center"
        )
        welcome_label.grid(row=0, column=0, pady=(80, 40), sticky="n")
        
        # Status label
        self.status_label = ctk.CTkLabel(
            self,
            text="Ready to connect to Altium Designer",
            font=ctk.CTkFont(size=14),
            text_color="gray"
        )
        self.status_label.grid(row=1, column=0, pady=20, sticky="n")
        
        # Loading text label (hidden initially) - for instructions
        self.instructions_label = ctk.CTkLabel(
            self,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        self.instructions_label.grid(row=2, column=0, pady=(0, 20), sticky="n")
        
        # Loading spinner frame (centered, hidden initially)
        self.loading_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.loading_frame.grid(row=1, column=0, sticky="nsew")
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
        self.spinner_label.grid(row=0, column=0, pady=30)
        
        # Loading text below spinner (hidden - user doesn't want it)
        self.loading_text_label = ctk.CTkLabel(
            spinner_container,
            text="",
            font=ctk.CTkFont(size=14),
            text_color="gray"
        )
        self.loading_text_label.grid(row=1, column=0, pady=15)
        
        # Initially hide the loading frame
        self.loading_frame.grid_remove()
        
        # Connect button
        self.connect_button = ctk.CTkButton(
            self,
            text="Connect",
            font=ctk.CTkFont(size=18, weight="bold"),
            height=50,
            width=200,
            command=self.connect_to_altium
        )
        self.connect_button.grid(row=3, column=0, pady=40, sticky="n")
        
        # Error message label (hidden initially)
        self.error_label = ctk.CTkLabel(
            self,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="red",
            wraplength=WINDOW_WIDTH - 40
        )
        self.error_label.grid(row=4, column=0, pady=20, sticky="n")
    
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
        # Update UI to loading state
        self.connect_button.configure(state="disabled", text="Waiting...")
        self.error_label.configure(text="")
        self.status_label.configure(text="Waiting for PCB data...", text_color="gray")
        
        # Show manual execution instructions
        instructions = (
            "Please run the export script in Altium Designer:\n\n"
            "1. In Altium Designer, go to: File → Run Script\n"
            "2. Select: altium_export_pcb_info.pas\n"
            "3. When dialog appears, select: ExportPCBInfo\n"
            "4. Click OK\n\n"
            "Waiting for PCB info file..."
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
            self.status_label.configure(text="Connected successfully!", text_color="green")
            self.error_label.configure(text="", text_color="green")
            # Move to next page immediately
            if self.on_connect_success:
                self.on_connect_success(self.mcp_client)
        else:
            self.instructions_label.configure(text="")  # Clear instructions
            self.status_label.configure(text="Connection failed", text_color="red")
            self.error_label.configure(text=f"Error: {message}", text_color="red", justify="left")
            self.connect_button.configure(state="normal", text="Connect")
    
    def get_mcp_client(self):
        """Get the MCP client instance"""
        return self.mcp_client

