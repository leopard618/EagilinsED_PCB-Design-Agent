"""
EagilinsED - Agent-Driven PCB Design Assistant
Main Application Entry Point
"""
import customtkinter as ctk
import logging
import sys
from pages.welcome_page import WelcomePage
from pages.guidelines_page import GuidelinesPage
from pages.project_setup_page import ProjectSetupPage
from pages.agent_page import AgentPage
from config import WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE
from mcp_client import AltiumMCPClient

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("EagilinsED")


class EagilinsEDApp(ctk.CTk):
    """Main application class"""
    
    def __init__(self):
        super().__init__()
        
        # Configure window
        self.title(WINDOW_TITLE)
        self.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
        self.resizable(False, False)
        
        # Set appearance mode and color theme
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        
        # Store MCP client and project mode
        self.mcp_client = None
        self.project_mode = None  # "existing" or "new"
        
        # Show welcome page
        self.show_welcome_page()
    
    def show_welcome_page(self):
        """Show welcome and connection page"""
        # Clear existing widgets
        for widget in self.winfo_children():
            widget.destroy()
        
        welcome_page = WelcomePage(
            self,
            on_connect_success=self.on_connect_success
        )
        welcome_page.pack(fill="both", expand=True)
    
    def on_connect_success(self, mcp_client: AltiumMCPClient):
        """Callback when connection is successful"""
        logger.info("MCP connection established successfully")
        self.mcp_client = mcp_client
        self.show_project_setup_page()
    
    def show_project_setup_page(self):
        """Show project setup page - ask user about existing or new project"""
        # Clear existing widgets
        for widget in self.winfo_children():
            widget.destroy()
        
        project_setup_page = ProjectSetupPage(
            self,
            self.mcp_client,
            on_continue=self.on_project_setup_complete
        )
        project_setup_page.pack(fill="both", expand=True)
    
    def on_project_setup_complete(self, project_mode: str):
        """Callback when project setup is complete"""
        logger.info(f"Project mode selected: {project_mode}")
        self.project_mode = project_mode
        self.show_guidelines_page()
    
    def show_guidelines_page(self):
        """Show guidelines page"""
        # Clear existing widgets
        for widget in self.winfo_children():
            widget.destroy()
        
        guidelines_page = GuidelinesPage(
            self,
            on_next=self.show_agent_page
        )
        guidelines_page.pack(fill="both", expand=True)
    
    def show_agent_page(self):
        """Show main agent page"""
        # Clear existing widgets
        for widget in self.winfo_children():
            widget.destroy()
        
        if self.mcp_client:
            agent_page = AgentPage(self, self.mcp_client, on_back=self.show_project_setup_page)
            agent_page.pack(fill="both", expand=True)
        else:
            # Fallback: show welcome page if no client
            self.show_welcome_page()


def main():
    """Main entry point"""
    logger.info("=" * 50)
    logger.info("EagilinsED - PCB Design Assistant")
    logger.info("=" * 50)
    logger.info("Starting application...")
    
    try:
        app = EagilinsEDApp()
        logger.info("Application window created successfully")
        app.mainloop()
    except Exception as e:
        logger.error(f"Application error: {e}")
        raise


if __name__ == "__main__":
    main()

