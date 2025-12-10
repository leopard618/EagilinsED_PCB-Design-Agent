# EagilinsED - PCB Design Assistant

An intelligent, agent-driven PCB design assistant that integrates with Altium Designer using natural language.

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Altium Designer 25.8.1 (with PCB file open)
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
- Run `altium_export_pcb_info.pas` in Altium Designer (File → Run Script)
- Select "ExportPCBInfo" and click OK
- Wait for connection (up to 60 seconds)

### 2. Interact with Agent
Ask questions or request modifications in natural language:

**Information Queries:**
- "Where is component R101 located?"
- "What is the board size?"
- "List all resistors on the PCB"

**Modification Commands:**
- "Move R101 to position 90, 60"
- "Rotate C147 by 90 degrees"
- "Add resistor R500 with value 1k at coordinates 93, 56"

### 3. Execute Commands
When the agent queues a command:
- Run `altium_execute_commands.pas` in Altium Designer
- Select "ExecuteCommands" and click OK
- The PCB will be updated automatically

## 🛠️ Tech Stack

- **Python 3.11+** with CustomTkinter (GUI)
- **OpenAI GPT-4** (Natural Language Processing)
- **Altium Designer** (via DelphiScript file-based integration)
- **File-Based MCP** (JSON communication)

## 📁 Key Files

- `main.py` - Application entry point
- `agent_orchestrator.py` - Core agent logic
- `mcp_server_file_based.py` - MCP server (run this first)
- `altium_export_pcb_info.pas` - Altium export script
- `altium_execute_commands.pas` - Altium command execution script

## 🎯 Features

- ✅ Natural language interface (ChatGPT-like)
- ✅ Real-time PCB analysis
- ✅ Component modification commands
- ✅ Streaming responses
- ✅ File-based Altium integration

## 📚 Documentation

For detailed documentation, see [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)

## ⚠️ Notes

- Commands require manual script execution in Altium Designer
- Ensure Altium Designer is running with a PCB file open
- MCP server must be running before launching the application

## 🔧 Troubleshooting

**Connection fails:**
- Check that MCP server is running
- Verify `pcb_info.json` is created after running export script
- Ensure Altium Designer has a PCB file open

**Commands not executing:**
- Verify `pcb_commands.json` contains the command
- Check Altium Designer for error messages
- Ensure you're running the execute script correctly

---

**EagilinsED** - Making PCB design accessible through natural language 🚀

