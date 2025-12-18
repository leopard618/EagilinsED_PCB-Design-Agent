"""
Project Setup Page
Asks user whether to use existing project or create new one
If existing, guides them to export data from Altium first
"""
import customtkinter as ctk
from config import WINDOW_WIDTH, WINDOW_HEIGHT


class ProjectSetupPage(ctk.CTkFrame):
    """Project setup page - choose existing or new project"""
    
    def __init__(self, parent, mcp_client, on_continue=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.mcp_client = mcp_client
        self.on_continue = on_continue
        self.project_mode = None  # "existing" or "new"
        self.selected_card = None  # Track selected card
        
        self.setup_ui()
    
    def setup_ui(self):
        """Setup the UI components with modern design"""
        # Configure grid
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(3, weight=1)
        
        # Title with gradient-like effect
        title_label = ctk.CTkLabel(
            self,
            text="Project Setup",
            font=ctk.CTkFont(family="Segoe UI", size=36, weight="bold"),
            text_color="#ffffff"
        )
        title_label.grid(row=0, column=0, pady=(80, 8), sticky="n")
        
        # Subtitle
        subtitle_label = ctk.CTkLabel(
            self,
            text="Choose how you want to begin your design journey",
            font=ctk.CTkFont(size=14),
            text_color="#9CA3AF"
        )
        subtitle_label.grid(row=1, column=0, pady=(0, 50), sticky="n")
        
        # Cards container - vertical column layout
        cards_frame = ctk.CTkFrame(self, fg_color="transparent")
        cards_frame.grid(row=2, column=0, pady=10, sticky="n")
        cards_frame.grid_columnconfigure(0, weight=1)
        
        # ===== Card 1: Existing Project =====
        self.existing_card = ctk.CTkFrame(
            cards_frame,
            width=320,
            height=80,
            corner_radius=12,
            fg_color="#1E293B",
            border_width=2,
            border_color="#334155"
        )
        self.existing_card.grid(row=0, column=0, padx=12, pady=8)
        self.existing_card.grid_propagate(False)
        self.existing_card.grid_columnconfigure(1, weight=1)
        
        # Icon
        existing_icon = ctk.CTkLabel(
            self.existing_card,
            text="",
            font=ctk.CTkFont(size=28),
            text_color="#60A5FA"
        )
        existing_icon.grid(row=0, column=0, rowspan=2, padx=(20, 15), pady=15)
        
        # Title
        existing_title = ctk.CTkLabel(
            self.existing_card,
            text="Existing Project",
            font=ctk.CTkFont(size=15, weight="bold"),
            text_color="#F1F5F9",
            anchor="w"
        )
        existing_title.grid(row=0, column=1, sticky="sw", pady=(15, 0))
        
        # Description
        existing_desc = ctk.CTkLabel(
            self.existing_card,
            text="Open and analyze your current design",
            font=ctk.CTkFont(size=11),
            text_color="#94A3B8",
            anchor="w"
        )
        existing_desc.grid(row=1, column=1, sticky="nw", pady=(2, 15))
        
        # Arrow/Select indicator
        existing_arrow = ctk.CTkLabel(
            self.existing_card,
            text=">",
            font=ctk.CTkFont(size=18),
            text_color="#64748B"
        )
        existing_arrow.grid(row=0, column=2, rowspan=2, padx=(10, 20))
        
        # Make entire card clickable
        self.existing_card.bind("<Button-1>", lambda e: self.select_existing())
        existing_icon.bind("<Button-1>", lambda e: self.select_existing())
        existing_title.bind("<Button-1>", lambda e: self.select_existing())
        existing_desc.bind("<Button-1>", lambda e: self.select_existing())
        existing_arrow.bind("<Button-1>", lambda e: self.select_existing())
        
        # ===== Card 2: New Project =====
        self.new_card = ctk.CTkFrame(
            cards_frame,
            width=320,
            height=80,
            corner_radius=12,
            fg_color="#1E293B",
            border_width=2,
            border_color="#334155"
        )
        self.new_card.grid(row=1, column=0, padx=12, pady=8)
        self.new_card.grid_propagate(False)
        self.new_card.grid_columnconfigure(1, weight=1)
        
        # Icon
        new_icon = ctk.CTkLabel(
            self.new_card,
            text="",
            font=ctk.CTkFont(size=28),
            text_color="#34D399"
        )
        new_icon.grid(row=0, column=0, rowspan=2, padx=(20, 15), pady=15)
        
        # Title
        new_title = ctk.CTkLabel(
            self.new_card,
            text="New Project",
            font=ctk.CTkFont(size=15, weight="bold"),
            text_color="#F1F5F9",
            anchor="w"
        )
        new_title.grid(row=0, column=1, sticky="sw", pady=(15, 0))
        
        # Description
        new_desc = ctk.CTkLabel(
            self.new_card,
            text="Start fresh with a blank canvas",
            font=ctk.CTkFont(size=11),
            text_color="#94A3B8",
            anchor="w"
        )
        new_desc.grid(row=1, column=1, sticky="nw", pady=(2, 15))
        
        # Arrow/Select indicator
        new_arrow = ctk.CTkLabel(
            self.new_card,
            text=">",
            font=ctk.CTkFont(size=18),
            text_color="#64748B"
        )
        new_arrow.grid(row=0, column=2, rowspan=2, padx=(10, 20))
        
        # Make entire card clickable
        self.new_card.bind("<Button-1>", lambda e: self.select_new())
        new_icon.bind("<Button-1>", lambda e: self.select_new())
        new_title.bind("<Button-1>", lambda e: self.select_new())
        new_desc.bind("<Button-1>", lambda e: self.select_new())
        new_arrow.bind("<Button-1>", lambda e: self.select_new())
        
        # ===== Instructions Panel (hidden initially) =====
        self.instructions_panel = ctk.CTkFrame(
            self,
            corner_radius=16,
            fg_color="#1E293B",
            border_width=1,
            border_color="#334155"
        )
        self.instructions_panel.grid(row=3, column=0, pady=(20, 30), padx=30, sticky="n")
        self.instructions_panel.grid_columnconfigure(0, weight=1)
        
        # Panel header
        self.panel_header = ctk.CTkLabel(
            self.instructions_panel,
            text="",
            font=ctk.CTkFont(size=16, weight="bold"),
            text_color="#60A5FA"
        )
        self.panel_header.grid(row=0, column=0, pady=(20, 10), padx=25)
        
        # Panel content
        self.panel_content = ctk.CTkLabel(
            self.instructions_panel,
            text="",
            font=ctk.CTkFont(size=12),
            text_color="#CBD5E1",
            justify="left",
            wraplength=WINDOW_WIDTH - 100
        )
        self.panel_content.grid(row=1, column=0, pady=(0, 20), padx=25)
        
        # Continue button
        self.continue_btn = ctk.CTkButton(
            self.instructions_panel,
            text="Continue",
            font=ctk.CTkFont(size=14, weight="bold"),
            height=42,
            width=200,
            corner_radius=10,
            fg_color="#3B82F6",
            hover_color="#2563EB",
            command=self.continue_to_agent
        )
        self.continue_btn.grid(row=2, column=0, pady=(10, 25))
        
        # Hide panel initially
        self.instructions_panel.grid_remove()
    
    def _highlight_card(self, card, color):
        """Highlight selected card"""
        # Reset both cards
        self.existing_card.configure(border_color="#334155")
        self.new_card.configure(border_color="#334155")
        # Highlight selected
        card.configure(border_color=color)
    
    def select_existing(self):
        """User selected existing project"""
        self.project_mode = "existing"
        self._highlight_card(self.existing_card, "#3B82F6")
        
        # Update panel
        self.panel_header.configure(text="Prepare Your Project Data", text_color="#60A5FA")
        self.panel_content.configure(
            text="To analyze your existing project, please export the data first:\n\n"
                 "1. Open your project in Altium Designer\n"
                 "2. Go to File → Run Script\n"
                 "3. Execute these scripts:\n"
                 "     • altium_project_manager.pas → ExportProjectInfo\n"
                 "     • altium_export_pcb_info.pas → ExportPCBInfo\n"
                 "     • altium_export_schematic_info.pas → ExportSchematicInfo\n\n"
                 "Click Continue when your data is exported."
        )
        self.continue_btn.configure(fg_color="#3B82F6", hover_color="#2563EB")
        
        # Show panel
        self.instructions_panel.grid()
    
    def select_new(self):
        """User selected new project"""
        self.project_mode = "new"
        self._highlight_card(self.new_card, "#10B981")
        
        # Update panel
        self.panel_header.configure(text="Ready to Create", text_color="#34D399")
        self.panel_content.configure(
            text="You can create your project using natural language:\n\n"
                 "Try commands like:\n"
                 "     • \"Create a new PCB project called MyProject\"\n"
                 "     • \"Add a schematic document\"\n"
                 "     • \"Create a PCB document\"\n\n"
                 "The AI assistant will guide you through each step."
        )
        self.continue_btn.configure(fg_color="#10B981", hover_color="#059669")
        
        # Show panel
        self.instructions_panel.grid()
    
    def continue_to_agent(self):
        """Continue to the agent page"""
        if self.on_continue:
            self.on_continue(self.project_mode)

