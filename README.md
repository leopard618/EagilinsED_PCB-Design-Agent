# EagilinsED - Full PCB Design Assistant

An intelligent, agent-driven PCB/Schematic design assistant that integrates with Altium Designer using natural language. Supports the complete PCB design lifecycle from schematic capture to manufacturing outputs.

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Altium Designer 25.5.2+ (with license)
- OpenAI API key

### Installation

1. **Clone/Download the project**
```bash
cd new-version
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure environment**
Create a `.env` file:
```env
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-4
MCP_SERVER_URL=http://localhost:8080
```

4. **Start MCP Server**
```bash
python mcp_server_file_based.py
```

5. **Launch Application**
```bash
python main.py
```

## 📖 Usage

### 1. Connect to Altium Designer
- Click "Connect" button
- In Altium: File → Run Script → Select `altium_scripts/altium_export_pcb_info.pas`
- Choose "ExportPCBInfo" and click OK
- Wait for connection (up to 60 seconds)

### 2. Available Operations

#### PCB Queries
- "Where is component R101 located?"
- "What is the board size?"
- "List all resistors on the PCB"
- "How many vias are on the board?"

#### PCB Modifications
- "Move R101 to position 90, 60"
- "Rotate C147 by 90 degrees"
- "Add resistor R500 with value 1k at coordinates 93, 56"

#### Schematic Operations
- Run `altium_export_schematic_info.pas` to export schematic data
- "What components are in the schematic?"
- "Show me the power connections"

#### Design Verification
- Run `altium_verification.pas` → `RunDRCAndExport` for DRC
- Run `altium_verification.pas` → `RunERCAndExport` for ERC
- "Are there any DRC violations?"

#### Manufacturing Outputs
- Run `altium_output_generator.pas` → `GenerateBOM` for BOM
- Run `altium_output_generator.pas` → `GeneratePickAndPlace` for assembly data
- "Generate manufacturing files"

### 3. Execute Commands
When the agent queues a command:
- Run `altium_scripts/altium_execute_commands.pas` in Altium Designer
- Select "ExecuteCommands" and click OK
- The PCB will be updated automatically

## 🛠️ Tech Stack

- **Python 3.11+** with CustomTkinter (GUI)
- **OpenAI GPT-4** (Natural Language Processing)
- **Altium Designer 25.5.2** (via DelphiScript file-based integration)
- **File-Based MCP** (JSON communication)

## 📁 Project Structure

```
new-version/
├── main.py                          # Application entry point
├── agent_orchestrator.py            # Core agent logic
├── mcp_server_file_based.py         # MCP server
├── mcp_client.py                    # MCP client
├── llm_client.py                    # OpenAI integration
├── config.py                        # Configuration
│
├── altium_scripts/                  # Altium DelphiScript files
│   ├── altium_export_pcb_info.pas       # Export PCB data
│   ├── altium_export_schematic_info.pas # Export schematic data
│   ├── altium_execute_commands.pas      # Execute modifications
│   ├── altium_project_manager.pas       # Project management
│   ├── altium_verification.pas          # DRC/ERC
│   └── altium_output_generator.pas      # Manufacturing outputs
│
├── pages/                           # UI pages
│   ├── welcome_page.py              # Connection page
│   ├── agent_page.py                # Chat interface
│   └── guidelines_page.py           # Help/guidelines
│
└── PCB_Project/                     # Sample Altium project
    ├── PCB_Project.PrjPcb
    ├── *.SchDoc
    └── *.PcbDoc
```

## 🎯 Features

### Current
- ✅ Natural language interface
- ✅ PCB analysis and modification
- ✅ Schematic information export
- ✅ Design rule checking (DRC/ERC)
- ✅ BOM generation
- ✅ Pick and Place file generation
- ✅ Streaming responses

### Planned
- 🔲 Component search from libraries
- 🔲 Schematic modification commands
- 🔲 Auto-routing integration
- 🔲 Gerber preview

## 📚 Documentation

- [Implementation Plan](IMPLEMENTATION_PLAN.md) - Full development roadmap
- [Project Documentation](PROJECT_DOCUMENTATION.md) - Detailed architecture

## ⚠️ Notes

- Commands require manual script execution in Altium Designer
- Ensure Altium Designer is running with a document open
- MCP server must be running before launching the application
- Scripts are located in `altium_scripts/` folder

## 🔧 Troubleshooting

**Connection fails:**
- Check that MCP server is running (`python mcp_server_file_based.py`)
- Verify `pcb_info.json` is created after running export script
- Ensure Altium Designer has a PCB file open and active

**Commands not executing:**
- Verify `pcb_commands.json` contains the command
- Check Altium Designer for error messages
- Ensure the correct script is run (altium_execute_commands.pas)

**JSON errors in pcb_info.json:**
- Re-run the export script in Altium Designer
- The server has auto-repair for common JSON syntax errors

---

**EagilinsED** - Full PCB Design Lifecycle Assistant 🚀
