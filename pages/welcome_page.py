"""
Welcome and Connection Status Page
Simplified connection - just checks MCP server and Altium availability
"""
import customtkinter as ctk
from mcp_client import AltiumMCPClient
from config import WINDOW_WIDTH, WINDOW_HEIGHT
import threading
import os
from pathlib import Path


class WelcomePage(ctk.CTkFrame):
    """Welcome page with simplified connection functionality"""
    
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
        self.grid_rowconfigure(3, weight=1)
        
        # Welcome message - increased size
        welcome_label = ctk.CTkLabel(
            self,
            text="EagilinsED",
            font=ctk.CTkFont(size=56, weight="bold"),  # Increased from 36 to 48
            anchor="center"
        )
        welcome_label.grid(row=0, column=0, pady=(80, 10), sticky="n")
        
        # Subtitle
        subtitle_label = ctk.CTkLabel(
            self,
            text="PCB Design Assistant",
            font=ctk.CTkFont(size=16),
            text_color="gray"
        )
        subtitle_label.grid(row=1, column=0, pady=(0, 50), sticky="n")  # Increased spacing
        
        # Logo/Image - Center of the page
        logo_path = Path(__file__).parent.parent / "assets" / "logo.png"
        if logo_path.exists():
            try:
                # Load image with PIL first (CTkImage requires PIL Image object, not path string)
                from PIL import Image as PILImage
                pil_image = PILImage.open(logo_path)
                
                # Preserve transparency - don't add white background
                # Keep RGBA if it has alpha channel, only convert if necessary
                if pil_image.mode == 'RGBA':
                    # Keep RGBA to preserve transparency
                    pass  # Keep as RGBA
                elif pil_image.mode == 'P' and 'transparency' in pil_image.info:
                    # Palette mode with transparency - convert to RGBA
                    pil_image = pil_image.convert('RGBA')
                elif pil_image.mode not in ('RGB', 'RGBA', 'L'):
                    # Convert other modes to RGB (but preserve if already RGB)
                    pil_image = pil_image.convert('RGB')
                
                # Get actual dimensions
                img_width, img_height = pil_image.size
                
                # Calculate display size maintaining aspect ratio
                # Smaller size as requested
                max_width, max_height = 350, 250
                aspect_ratio = img_width / img_height
                
                if img_width > max_width or img_height > max_height:
                    if aspect_ratio > 1:  # Wider than tall
                        display_width = max_width
                        display_height = int(max_width / aspect_ratio)
                    else:  # Taller than wide
                        display_height = max_height
                        display_width = int(max_height * aspect_ratio)
                else:
                    # Use original size if smaller than max
                    display_width, display_height = img_width, img_height
                
                # Resize image with high-quality resampling to avoid noise
                if display_width != img_width or display_height != img_height:
                    pil_image = pil_image.resize(
                        (display_width, display_height), 
                        resample=PILImage.Resampling.LANCZOS  # High-quality resampling
                    )
                
                # Create CTkImage with PIL Image object (preserves transparency if RGBA)
                logo_image = ctk.CTkImage(
                    light_image=pil_image,
                    dark_image=pil_image,
                    size=(display_width, display_height)
                )
                logo_label = ctk.CTkLabel(
                    self,
                    image=logo_image,
                    text=""  # No text, just image
                )
                logo_label.grid(row=2, column=0, pady=(20, 40), sticky="n")  # Moved down a bit
            except Exception as e:
                print(f"Could not load logo image: {e}")
                import traceback
                traceback.print_exc()
                # No fallback icons - just skip logo if it fails
        # No else clause - if image doesn't exist, just don't show anything
        
        # Info text
        info_label = ctk.CTkLabel(
            self,
            text="Make sure Altium Designer is open before connecting",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        info_label.grid(row=3, column=0, pady=(0, 30), sticky="n")
        
        # Status label (hidden initially, will be updated during connection)
        self.status_label = ctk.CTkLabel(
            self,
            text="",  # Empty by default - removed "Ready to connect"
            font=ctk.CTkFont(size=14),
            text_color="gray"
        )
        self.status_label.grid(row=4, column=0, pady=(0, 30), sticky="n")
        
        # Instructions label (hidden initially)
        self.instructions_label = ctk.CTkLabel(
            self,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="gray",
            wraplength=WINDOW_WIDTH - 40
        )
        self.instructions_label.grid(row=5, column=0, pady=(0, 20), sticky="n")
        
        # Loading spinner frame (centered, hidden initially)
        self.loading_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.loading_frame.grid(row=6, column=0, sticky="nsew")
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
        self.connect_button.grid_remove()  # Hide button when loading
        self.loading_frame.grid()  # Show loading spinner
        self.spinner_dots = 0
        self._animate_spinner()
    
    def _stop_loading(self):
        """Stop the loading animation"""
        self.loading_active = False
        self.loading_frame.grid_remove()  # Hide loading spinner
        self.connect_button.grid()  # Show button again
    
    def connect_to_altium(self):
        """Attempt to connect to Altium Designer - simplified connection"""
        # Update UI to loading state
        self.connect_button.configure(state="disabled", text="Connecting...")
        self.error_label.configure(text="")
        self.status_label.configure(text="Connecting to MCP server...", text_color="gray")
        self.instructions_label.configure(text="Checking connection...", text_color="gray")
        
        # Start loading animation
        self._start_loading()
        self.update()
        
        # Run connection in a separate thread to avoid blocking UI
        def connect_thread():
            try:
                # Attempt simplified connection (just checks MCP server and Altium availability)
                success, message = self.mcp_client.connect_simple()
                
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

