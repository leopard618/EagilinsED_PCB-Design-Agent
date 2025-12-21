# EagilinsED

AI-powered PCB design co-pilot that generates layouts from schematics automatically.

## Quick Start

```powershell
# Terminal 1: Start server
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py

# Terminal 2: Start app
.\venv\Scripts\Activate.ps1
python main.py
```

## Features

- **Analyze** - Identify functional blocks in schematic
- **Strategy** - Generate placement recommendations  
- **Review** - Find design issues and suggest fixes
- **Generate Layout** - Create PCB layout automatically

## Usage

1. Connect to MCP server
2. Export schematic data from Altium
3. Ask: `"Generate layout for this design"`
4. Run generated script in Altium

## Example Commands

```
"Analyze this schematic"
"Generate placement strategy"
"Review this design for issues"
"Generate layout"
```

## Requirements

- Python 3.11+
- Altium Designer 25.x
- OpenAI API key

## Setup

```powershell
pip install -r requirements.txt
```

Create `.env`:
```
OPENAI_API_KEY=your-key
```

## Documentation

See `SCRIPT_GUIDE.md` for detailed script structure and usage instructions.

