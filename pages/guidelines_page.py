"""
Guidelines and Tips Page
"""
import customtkinter as ctk
from config import WINDOW_WIDTH, WINDOW_HEIGHT


class GuidelinesPage(ctk.CTkFrame):
    """Page displaying usage guidelines and tips"""
    
    def __init__(self, parent, on_next=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.on_next = on_next
        
        self.setup_ui()
    
    def setup_ui(self):
        """Setup the UI components"""
        # Configure grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # Title
        title_label = ctk.CTkLabel(
            self,
            text="Things to Keep in Mind",
            font=ctk.CTkFont(size=24, weight="bold"),
            anchor="center"
        )
        title_label.grid(row=0, column=0, pady=(40, 30), sticky="n")
        
        # Scrollable frame for guidelines
        scrollable_frame = ctk.CTkScrollableFrame(
            self,
            width=WINDOW_WIDTH - 40,
            height=WINDOW_HEIGHT - 200
        )
        scrollable_frame.grid(row=1, column=0, pady=20, padx=20, sticky="nsew")
        scrollable_frame.grid_columnconfigure(0, weight=1)
        
        # Guidelines list
        guidelines = [
            "1. Always ensure Altium Designer is running and a PCB file is open before connecting.",
            "2. Save your work frequently. The assistant can modify your PCB, so keep backups.",
            "3. Review all modifications before applying them to your design.",
            "4. The agent uses OpenAI for analysis - ensure you have API credits available.",
            "5. MCP server must be running and properly configured for Altium Designer integration.",
            "6. Some operations may take time depending on PCB complexity.",
            "7. Verify component placements and routing after automated modifications.",
            "8. Use clear, specific queries when asking the agent to analyze or modify your PCB.",
            "9. The assistant can help with component placement, routing analysis, and design rules.",
            "10. If connection fails, check that Altium Designer is running and MCP server is active."
        ]
        
        for i, guideline in enumerate(guidelines):
            guideline_label = ctk.CTkLabel(
                scrollable_frame,
                text=guideline,
                font=ctk.CTkFont(size=14),
                anchor="w",
                justify="left",
                wraplength=WINDOW_WIDTH - 80
            )
            guideline_label.grid(row=i, column=0, pady=8, padx=20, sticky="w")
        
        # Next button
        next_button = ctk.CTkButton(
            self,
            text="Next",
            font=ctk.CTkFont(size=18, weight="bold"),
            height=50,
            width=200,
            command=self.go_next
        )
        next_button.grid(row=2, column=0, pady=30, sticky="s")
    
    def go_next(self):
        """Navigate to next page"""
        if self.on_next:
            self.on_next()

