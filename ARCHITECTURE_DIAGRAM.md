# 🏗️ EagilinsED Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  CustomTkinter UI (main.py)                               │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │  │
│  │  │   Chat      │  │  Menu (⋮)    │  │  File Upload    │  │  │
│  │  │  Interface  │  │  - Run DRC   │  │  (📁 button)    │  │  │
│  │  │             │  │  - Export    │  │                 │  │  │
│  │  │  Natural    │  │  - Refresh   │  │                 │  │  │
│  │  │  Language   │  │  - Routing   │  │                 │  │  │
│  │  └─────────────┘  └──────────────┘  └─────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AGENT ORCHESTRATOR                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  agent_orchestrator.py                                    │  │
│  │  - Interprets user intent                                 │  │
│  │  - Coordinates modules                                    │  │
│  │  - Generates responses                                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  LLM Client   │    │  MCP Client   │    │  Altium       │
│  (OpenAI)     │    │  (REST API)   │    │  Script Client│
└───────────────┘    └───────────────┘    └───────────────┘
                              │                     │
                              ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      MCP SERVER (Port 8765)                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  mcp_server.py                                            │  │
│  │  - REST API endpoints                                     │  │
│  │  - Coordinates modules                                    │  │
│  │  - Manages artifacts                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  Routing      │    │  DRC Module   │    │  File Reader  │
│  Module       │    │               │    │               │
│  - A* Path    │    │  - Violations │    │  - .PcbDoc    │
│  - Suggestions│    │  - Rules      │    │  - Direct read│
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ARTIFACT STORE                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Version-controlled storage                                │  │
│  │  artifacts/{uuid}/                                         │  │
│  │    - index.json (metadata)                                │  │
│  │    - v1.json, v2.json (versions)                         │  │
│  │    - current.json (latest)                                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  G-IR         │    │  C-IR         │    │  Patches      │
│  (Geometry)   │    │  (Constraints) │    │  (Changes)    │
│  - Board      │    │  - Rules      │    │  - Operations │
│  - Components │    │  - Netclasses │    │  - Versioning │
│  - Tracks     │    │  - Params     │    │               │
│  - Vias       │    │               │    │               │
└───────────────┘    └───────────────┘    └───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ALTIUM DESIGNER                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  command_server.pas (Script Server)                      │  │
│  │  - Listens for commands                                   │  │
│  │  - Executes: move, add_track, add_via, run_drc           │  │
│  │  - Exports: comprehensive PCB data                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Load PCB Data

```
Altium Designer
    │
    │ (Export PCB Info)
    ▼
altium_pcb_info.json
    │
    │ (Import)
    ▼
AltiumImporter
    │
    │ (Convert)
    ▼
G-IR (GeometryIR)
    │
    │ (Store)
    ▼
Artifact Store
    │
    │ (Version)
    ▼
artifacts/{uuid}/v1.json
```

### 2. Run DRC

```
User: "run DRC"
    │
    ▼
Agent Orchestrator
    │
    ▼
MCP Server → Altium Script Client
    │
    ▼
Altium Designer (command_server.pas)
    │
    │ (Run DRC)
    ▼
Design Rule Check
    │
    │ (Generate Report)
    ▼
Project Outputs/Design Rule Check*.html
    │
    │ (Parse)
    ▼
DRC Module
    │
    │ (Create Artifact)
    ▼
Violations Artifact
```

### 3. Routing Suggestion

```
User: "routing suggestions"
    │
    ▼
Agent Orchestrator
    │
    ▼
MCP Server → Routing Module
    │
    │ (Read G-IR from Artifact)
    ▼
GeometryIR
    │
    │ (Analyze unconnected nets)
    ▼
A* Pathfinding
    │
    │ (Calculate routes)
    ▼
Routing Suggestions (Patches)
    │
    │ (Return)
    ▼
Agent → User
```

### 4. Modify PCB

```
User: "move U1 to 50, 60"
    │
    ▼
Agent Orchestrator
    │
    │ (Create Patch)
    ▼
Patch (MoveComponentOp)
    │
    │ (Confirm)
    ▼
Altium Script Client
    │
    │ (Send command)
    ▼
Altium Designer
    │
    │ (Execute)
    ▼
Component Moved
    │
    │ (Result)
    ▼
Agent → User: "Component moved!"
```

## Module Responsibilities

### G-IR (Geometry IR)
- **Purpose:** Represent PCB geometry
- **Data:** Board, layers, components, nets, tracks, vias, pads
- **Location:** `core/ir/gir.py`
- **Usage:** Loaded from Altium export or file reader

### C-IR (Constraint IR)
- **Purpose:** Represent design rules
- **Data:** Rules (clearance, width, via), netclasses
- **Location:** `core/ir/cir.py`
- **Usage:** Extracted from Altium or created programmatically

### Routing Module
- **Purpose:** Generate routing suggestions
- **Features:** A* pathfinding, obstacle avoidance, via placement
- **Location:** `runtime/routing/routing_module.py`
- **Input:** G-IR (from artifacts)
- **Output:** Patches with routing suggestions

### DRC Module
- **Purpose:** Check design rules
- **Features:** Violation detection, rule validation
- **Location:** `runtime/drc/drc_module.py`
- **Input:** G-IR + C-IR (from artifacts)
- **Output:** Violations artifact

### Artifact Store
- **Purpose:** Version-controlled storage
- **Features:** Create, read, update, version history
- **Location:** `core/artifacts/store.py`
- **Storage:** File-based (JSON files)

### Altium Integration
- **Purpose:** Bidirectional communication with Altium
- **Components:**
  - `tools/altium_file_reader.py` - Read .PcbDoc files
  - `tools/altium_script_client.py` - Send commands to Altium
  - `altium_scripts/command_server.pas` - Altium script server
  - `adapters/altium/importer.py` - Convert Altium data to G-IR/C-IR

## Communication Protocols

### MCP Server (REST API)
- **Port:** 8765
- **Protocol:** HTTP/JSON
- **Endpoints:** See `COMPLETE_GUIDE.md`

### Altium Script Server
- **Protocol:** JSON files
- **Files:**
  - `altium_command.json` - Commands from Python
  - `altium_result.json` - Results from Altium
  - `altium_pcb_info.json` - Exported PCB data

### Artifact Storage
- **Format:** JSON
- **Structure:**
  ```
  artifacts/
    {uuid}/
      index.json      # Metadata
      v1.json         # Version 1
      v2.json         # Version 2
      current.json    # Latest version
  ```

## Feature Matrix

| Feature | Input | Processing | Output |
|---------|-------|------------|--------|
| **Load PCB** | .PcbDoc file | File reader → G-IR | Artifact |
| **Export PCB** | Altium Designer | Script export → JSON | G-IR + Artifact |
| **Run DRC** | G-IR + C-IR | DRC Module → Altium DRC | Violations Artifact |
| **Routing** | G-IR | A* Pathfinding | Routing Patches |
| **Modify PCB** | User command | Patch → Altium Script | Updated PCB |
| **Analyze** | G-IR | Agent analysis | Recommendations |

---

**See `COMPLETE_GUIDE.md` for detailed usage instructions.**
