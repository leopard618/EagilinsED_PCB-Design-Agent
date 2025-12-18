"""
Project Setup Page - Professional Design
Choose between existing project or create new
"""
import customtkinter as ctk
from config import WINDOW_WIDTH, WINDOW_HEIGHT


class ProjectSetupPage(ctk.CTkFrame):
    """Professional project setup page"""
    
    def __init__(self, parent, mcp_client, on_continue=None):
        super().__init__(parent, width=WINDOW_WIDTH, height=WINDOW_HEIGHT)
        self.parent = parent
        self.mcp_client = mcp_client
        self.on_continue = on_continue
        self.project_mode = None
        
        # Color scheme
        self.colors = {
            "bg_dark": "#0f172a",
            "bg_card": "#1e293b",
            "bg_hover": "#334155",
            "border": "#475569",
            "border_selected": "#3b82f6",
            "primary": "#3b82f6",
            "primary_hover": "#2563eb",
            "success": "#10b981",
            "success_hover": "#059669",
            "text": "#f8fafc",
            "text_muted": "#94a3b8",
            "text_dim": "#64748b"
        }
        
        self.configure(fg_color=self.colors["bg_dark"])
        self.setup_ui()
    
    def setup_ui(self):
        """Setup professional UI"""
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)
        
        # === Header ===
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.grid(row=0, column=0, pady=(60, 40), sticky="n")
        
        title = ctk.CTkLabel(
            header,
            text="Get Started",
            font=ctk.CTkFont(family="Segoe UI", size=32, weight="bold"),
            text_color=self.colors["text"]
        )
        title.pack()
        
        subtitle = ctk.CTkLabel(
            header,
            text="How would you like to begin?",
            font=ctk.CTkFont(size=14),
            text_color=self.colors["text_muted"]
        )
        subtitle.pack(pady=(8, 0))
        
        # === Cards Container ===
        cards_container = ctk.CTkFrame(self, fg_color="transparent")
        cards_container.grid(row=1, column=0, sticky="n")
        
        # Existing Project Card
        self.existing_card = self._create_card(
            cards_container,
            icon="📂",
            title="Open Existing Project",
            description="Import and analyze your current design",
            row=0,
            command=self.select_existing
        )
        
        # New Project Card
        self.new_card = self._create_card(
            cards_container,
            icon="✨",
            title="Start New Project",
            description="Create a fresh PCB design from scratch",
            row=1,
            command=self.select_new
        )
        
        # === Instructions Panel ===
        self.instructions = ctk.CTkFrame(
            self,
            fg_color=self.colors["bg_card"],
            corner_radius=12,
            border_width=1,
            border_color=self.colors["border"]
        )
        self.instructions.grid(row=2, column=0, pady=(30, 40), padx=40, sticky="n")
        self.instructions.grid_columnconfigure(0, weight=1)
        
        # Panel header
        self.instr_header = ctk.CTkLabel(
            self.instructions,
            text="",
            font=ctk.CTkFont(size=14, weight="bold"),
            text_color=self.colors["primary"]
        )
        self.instr_header.grid(row=0, column=0, pady=(20, 8), padx=24)
        
        # Panel content
        self.instr_content = ctk.CTkLabel(
            self.instructions,
            text="",
            font=ctk.CTkFont(size=12),
            text_color=self.colors["text_muted"],
            justify="left",
            wraplength=WINDOW_WIDTH - 120
        )
        self.instr_content.grid(row=1, column=0, pady=(0, 16), padx=24)
        
        # Continue button
        self.continue_btn = ctk.CTkButton(
            self.instructions,
            text="Continue →",
            font=ctk.CTkFont(size=13, weight="bold"),
            height=38,
            width=160,
            corner_radius=8,
            fg_color=self.colors["primary"],
            hover_color=self.colors["primary_hover"],
            command=self.continue_to_agent
        )
        self.continue_btn.grid(row=2, column=0, pady=(8, 24))
        
        # Hide initially
        self.instructions.grid_remove()
    
    def _create_card(self, parent, icon, title, description, row, command):
        """Create a selection card"""
        card = ctk.CTkFrame(
            parent,
            width=340,
            height=72,
            corner_radius=10,
            fg_color=self.colors["bg_card"],
            border_width=1,
            border_color=self.colors["border"]
        )
        card.grid(row=row, column=0, pady=6)
        card.grid_propagate(False)
        card.grid_columnconfigure(1, weight=1)
        
        # Icon
        icon_lbl = ctk.CTkLabel(
            card,
            text=icon,
            font=ctk.CTkFont(size=22)
        )
        icon_lbl.grid(row=0, column=0, rowspan=2, padx=(18, 12), pady=14)
        
        # Title
        title_lbl = ctk.CTkLabel(
            card,
            text=title,
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color=self.colors["text"],
            anchor="w"
        )
        title_lbl.grid(row=0, column=1, sticky="sw", pady=(14, 0))
        
        # Description
        desc_lbl = ctk.CTkLabel(
            card,
            text=description,
            font=ctk.CTkFont(size=11),
            text_color=self.colors["text_dim"],
            anchor="w"
        )
        desc_lbl.grid(row=1, column=1, sticky="nw", pady=(2, 14))
        
        # Arrow
        arrow = ctk.CTkLabel(
            card,
            text="→",
            font=ctk.CTkFont(size=16),
            text_color=self.colors["text_dim"]
        )
        arrow.grid(row=0, column=2, rowspan=2, padx=(8, 18))
        
        # Bind clicks
        for widget in [card, icon_lbl, title_lbl, desc_lbl, arrow]:
            widget.bind("<Button-1>", lambda e, c=command: c())
            widget.bind("<Enter>", lambda e, cd=card: cd.configure(fg_color=self.colors["bg_hover"]))
            widget.bind("<Leave>", lambda e, cd=card: cd.configure(fg_color=self.colors["bg_card"]) 
                        if cd != self.existing_card or self.project_mode != "existing" else None)
        
        return card
    
    def _highlight_card(self, selected_card, color):
        """Highlight selected card"""
        self.existing_card.configure(border_color=self.colors["border"])
        self.new_card.configure(border_color=self.colors["border"])
        selected_card.configure(border_color=color)
    
    def select_existing(self):
        """Select existing project"""
        self.project_mode = "existing"
        self._highlight_card(self.existing_card, self.colors["primary"])
        
        self.instr_header.configure(text="Export Project Data", text_color=self.colors["primary"])
        self.instr_content.configure(
            text="1. Open your project in Altium Designer\n"
                 "2. Go to File → Run Script\n"
                 "3. Run: altium_project_manager.pas → ExportProjectInfo\n"
                 "4. Run: altium_export_schematic_info.pas → ExportSchematicInfo\n\n"
                 "Click Continue when ready."
        )
        self.continue_btn.configure(fg_color=self.colors["primary"], hover_color=self.colors["primary_hover"])
        self.instructions.grid()
    
    def select_new(self):
        """Select new project"""
        self.project_mode = "new"
        self._highlight_card(self.new_card, self.colors["success"])
        
        self.instr_header.configure(text="Create with Natural Language", text_color=self.colors["success"])
        self.instr_content.configure(
            text="Use the AI assistant to create your design:\n\n"
                 "• \"Create a new project called MyDesign\"\n"
                 "• \"Add a schematic document\"\n"
                 "• \"Create PCB board\""
        )
        self.continue_btn.configure(fg_color=self.colors["success"], hover_color=self.colors["success_hover"])
        self.instructions.grid()
    
    def continue_to_agent(self):
        """Proceed to agent page"""
        if self.on_continue:
            self.on_continue(self.project_mode)
