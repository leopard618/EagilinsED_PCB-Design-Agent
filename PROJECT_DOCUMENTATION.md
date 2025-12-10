# EagilinsED - Agent-Driven PCB Design Assistant

## 📋 Project Overview

**EagilinsED** is an intelligent, agent-driven PCB (Printed Circuit Board) design assistant that integrates with Altium Designer. It uses natural language processing to understand user queries and either provides information about the PCB or executes modification commands. The system bridges the gap between human language and PCB design operations through an AI-powered conversational interface.

### Key Features
- **Natural Language Interface**: ChatGPT-like conversational UI for PCB design tasks
- **Intelligent Intent Recognition**: Automatically determines if a query needs information or action
- **Real-time PCB Analysis**: Query component locations, values, nets, tracks, and board properties
- **PCB Modification Commands**: Execute commands like moving components, rotating, adding/removing components, etc.
- **File-Based Integration**: Works with Altium Designer through file-based communication (no COM interface required)
- **Streaming Responses**: Real-time word-by-word response generation for better UX

---

## 🛠️ Tech Stack

### Core Technologies
- **Python 3.11+**: Primary programming language
- **CustomTkinter 5.2+**: Modern, customizable GUI framework (mobile-sized interface: 450x850px)
- **OpenAI GPT-4**: Large Language Model for natural language understanding and response generation
- **Altium Designer 25.8.1**: PCB design software (via file-based integration)
- **DelphiScript**: Altium's scripting language for PCB data export and command execution

### Key Python Libraries
- **openai**: OpenAI API client for LLM interactions
- **requests**: HTTP client for MCP server communication
- **customtkinter**: Modern Tkinter-based GUI framework
- **python-dotenv**: Environment variable management
- **json**: JSON parsing and manipulation
- **pathlib**: File system operations
- **threading**: Asynchronous operations for non-blocking UI

### Integration Method
- **File-Based MCP (Model Context Protocol)**: Custom implementation using JSON files for data exchange
- **Altium Designer Scripts**: DelphiScript files for PCB data export and command execution

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ Welcome  │→ │Guidelines│→ │  Agent   │                  │
│  │   Page   │  │   Page   │  │   Page   │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Agent Orchestrator Layer                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  AgentOrchestrator                                    │  │
│  │  - Intent Determination (Info vs Execute)            │  │
│  │  - Response Generation                                │  │
│  │  - Command Execution                                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────┐        ┌──────────────────┐
│   LLM Client      │        │   MCP Client     │
│  (OpenAI GPT-4)   │        │  (File-Based)    │
└──────────────────┘        └──────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    MCP Server Layer                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  File-Based MCP Server (HTTP)                        │  │
│  │  - Reads pcb_info.json                               │  │
│  │  - Writes pcb_commands.json                          │  │
│  │  - JSON repair and validation                        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Altium Designer Integration                     │
│  ┌──────────────────┐        ┌──────────────────┐         │
│  │ Export Script    │        │ Execute Script   │         │
│  │ (DelphiScript)   │        │ (DelphiScript)   │         │
│  │                  │        │                  │         │
│  │ Exports PCB data │        │ Executes commands│         │
│  │ to pcb_info.json │        │ from pcb_commands│         │
│  └──────────────────┘        └──────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. **UI Layer** (`pages/`)
- **WelcomePage**: Connection interface with loading animation
- **GuidelinesPage**: Usage guidelines and tips
- **AgentPage**: Main chat interface (ChatGPT-like)

#### 2. **Agent Layer** (`agent_orchestrator.py`)
- **Intent Classification**: Determines if query is informational or requires action
- **Response Generation**: Generates natural language responses
- **Command Execution**: Queues commands for Altium Designer

#### 3. **LLM Integration** (`llm_client.py`)
- **OpenAI API Client**: Handles GPT-4 interactions
- **Streaming Support**: Real-time response streaming
- **Context Management**: Manages conversation history and PCB context

#### 4. **MCP Integration** (`mcp_client.py`, `mcp_server_file_based.py`)
- **MCP Client**: HTTP client for MCP server communication
- **File Watcher**: Monitors `pcb_info.json` for updates
- **MCP Server**: HTTP server that reads/writes JSON files

#### 5. **Altium Integration** (`altium_export_pcb_info.pas`, `altium_execute_commands.pas`)
- **Export Script**: Exports PCB data to JSON format
- **Execute Script**: Reads commands from JSON and executes them in Altium

---

## 🔄 Workflow

### 1. **Application Startup**
```
User launches application
    ↓
Welcome Page displayed
    ↓
User clicks "Connect" button
    ↓
Loading animation starts
    ↓
Instructions shown: "Run export script in Altium Designer"
```

### 2. **Connection Process**
```
User runs altium_export_pcb_info.pas in Altium Designer
    ↓
Altium script exports PCB data to pcb_info.json
    ↓
MCP Client detects file creation/update
    ↓
Validates JSON structure and content
    ↓
Connection successful → Move to Guidelines Page
```

### 3. **Agent Interaction Workflow**
```
User enters query in Agent Page
    ↓
AgentOrchestrator receives query
    ↓
LLM determines intent (Info vs Execute)
    ↓
┌─────────────────┬─────────────────┐
│  INFO QUERY     │  EXECUTE QUERY   │
│                 │                  │
│  Get PCB info   │  Generate command│
│  from MCP       │  via LLM        │
│                 │                  │
│  Summarize data │  Queue command   │
│  for LLM        │  to pcb_commands │
│                 │  .json           │
│  Generate       │                  │
│  response       │  User runs       │
│  (streaming)    │  execute script  │
│                 │                  │
│  Display answer │  Altium executes │
└─────────────────┴─────────────────┘
```

### 4. **Command Execution Workflow**
```
User: "Move R101 to position 90, 60"
    ↓
Agent generates: move_component command
    ↓
Command written to pcb_commands.json
    ↓
User manually runs altium_execute_commands.pas in Altium
    ↓
Altium script reads pcb_commands.json
    ↓
Script executes command in Altium Designer
    ↓
Script updates pcb_info.json with new PCB state
    ↓
Command file cleared
```

---

## 📁 File Structure

```
EagilinsED/
│
├── main.py                          # Application entry point
├── config.py                        # Configuration (API keys, window size, etc.)
├── requirements.txt                 # Python dependencies
│
├── pages/                           # UI Pages
│   ├── __init__.py
│   ├── welcome_page.py              # Connection page with loading animation
│   ├── guidelines_page.py           # Usage guidelines
│   └── agent_page.py                # Main chat interface
│
├── agent_orchestrator.py            # Core agent logic (intent, response, execution)
├── llm_client.py                    # OpenAI API integration
├── mcp_client.py                    # MCP client (HTTP requests)
├── mcp_server_file_based.py         # MCP server (file-based, HTTP)
│
├── altium_export_pcb_info.pas       # Altium script: Export PCB data to JSON
├── altium_execute_commands.pas      # Altium script: Execute commands from JSON
│
├── pcb_info.json                    # PCB data (exported by Altium)
├── pcb_commands.json                # Commands queue (written by Python, read by Altium)
│
├── TEST_SENTENCES.md                # Test queries for all features
└── PROJECT_DOCUMENTATION.md         # This file
```

---

## 🔌 Data Flow

### PCB Information Flow (Read)
```
Altium Designer
    ↓ (User runs export script)
altium_export_pcb_info.pas
    ↓ (Writes JSON)
pcb_info.json
    ↓ (Read by)
MCP Server (HTTP GET /altium/pcb/info)
    ↓ (Returns JSON)
MCP Client
    ↓ (Provides to)
Agent Orchestrator
    ↓ (Summarizes for)
LLM (OpenAI)
    ↓ (Generates)
User Response
```

### Command Execution Flow (Write)
```
User Query
    ↓ (Processed by)
Agent Orchestrator
    ↓ (Generates command via)
LLM (OpenAI)
    ↓ (Command sent to)
MCP Client
    ↓ (HTTP POST to)
MCP Server
    ↓ (Writes to)
pcb_commands.json
    ↓ (User runs execute script)
altium_execute_commands.pas
    ↓ (Reads and executes)
Altium Designer
    ↓ (Updates PCB)
    ↓ (Re-exports data)
pcb_info.json (updated)
```

---

The system provides a conversational interface for PCB design tasks, making complex operations accessible through natural language while maintaining full control through manual script execution.

