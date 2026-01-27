# 🚀 EagilinsED PCB Design Agent - Complete Guide

## Table of Contents
1. [Overview](#overview)
2. [Setup & Installation](#setup--installation)
3. [Starting the System](#starting-the-system)
4. [Connecting to Altium Designer](#connecting-to-altium-designer)
5. [UI Features](#ui-features)
6. [Core Modules](#core-modules)
7. [Workflows & Examples](#workflows--examples)
8. [Troubleshooting](#troubleshooting)

---

## Overview

**EagilinsED** is an AI-powered PCB design assistant that integrates with Altium Designer to provide:
- **G-IR (Geometry IR)**: Complete board geometry representation
- **C-IR (Constraint IR)**: Design rules and constraints
- **Routing Module**: AI-driven routing suggestions with A* pathfinding
- **DRC Module**: Design rule checking and violation detection
- **Natural Language Interface**: Chat with AI to modify your PCB

---

## Setup & Installation

### Prerequisites

1. **Python 3.8+** installed
2. **Altium Designer** (any recent version)
3. **OpenAI API Key** (for AI features)

### Step 1: Install Dependencies

```powershell
# Navigate to project directory
cd D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent

# Activate virtual environment
.\venv\Scripts\activate

# Install dependencies (if not already installed)
pip install -r requirements.txt
```

### Step 2: Configure API Key

Create or edit `.env` file in project root:

```env
OPENAI_API_KEY=your-api-key-here
```

Or set environment variable:
```powershell
$env:OPENAI_API_KEY="your-api-key-here"
```

---

## Starting the System

### Terminal 1: Start MCP Server

```powershell
cd D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent
.\venv\Scripts\activate
python mcp_server.py
```

**Expected Output:**
```
============================================================
EagilinsED MCP Server
============================================================
Server: http://localhost:8765

Endpoints:
  GET  /health              - Server health check
  GET  /status              - Connection status
  GET  /pcb/info            - Get PCB info
  POST /pcb/load            - Load PCB file
  ...
```

**Keep this terminal open!**

### Terminal 2: Start UI

```powershell
cd D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent
.\venv\Scripts\activate
python main.py
```

**Expected Output:**
```
=================================================
EagilinsED - PCB Design Assistant
=================================================
Starting application...
Application window created successfully
Connecting to MCP server at http://localhost:8765...
MCP connection established successfully
```

**The UI window should open!**

---

## Connecting to Altium Designer

### Step 1: Open Altium Designer

1. Launch Altium Designer
2. Open your PCB project: `PCB_Project/PCB_Project.PrjPcb`
3. Open the PCB document: `Y904A23-GF-DYPCB-V1.0.PcbDoc`

### Step 2: Start Command Server in Altium

1. In Altium Designer, go to: **DXP → Run Script**
2. Navigate to: `altium_scripts/command_server.pas`
3. Click **Run**
4. In the script dialog, select **`StartServer`** and click **OK**

**Expected Result:**
- Altium shows: "EagilinsED Command Server Started!"
- Server is now listening for commands

### Step 3: Verify Connection

In the UI:
1. Click the **⋮** (three-dot) menu button (top-right)
2. Select **"Altium Status"**
3. Should show: "Altium Script Server: CONNECTED"

---

## UI Features

### Main Interface

```
┌─────────────────────────────────────────────────────────┐
│  ← EagilinsED    ● Connected    Clear    ⋮             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Chat Messages Area]                                  │
│                                                         │
│  User: "move U1 to position 50, 60"                   │
│  Agent: "I'll move component U1..."                   │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [Ask about your design...]  📁  →                     │
└─────────────────────────────────────────────────────────┘
```

### Header Buttons

| Button | Function |
|--------|----------|
| **←** | Go back to project setup |
| **● Connected** | Status indicator (green = connected) |
| **Clear** | Clear chat history |
| **⋮** | Menu with actions (see below) |

### Three-Dot Menu (⋮)

Click the **⋮** button to access:

| Menu Item | What It Does |
|-----------|--------------|
| **Run DRC** | Runs Design Rule Check in Altium Designer |
| **Export PCB Info** | Exports comprehensive PCB data from Altium |
| **Refresh Data** | Reloads data from current PCB |
| **Routing Suggestions** | Gets AI routing recommendations |
| **List Components** | Shows all components on board |
| **Altium Status** | Checks Altium connection |
| **View DRC Report** | Opens DRC HTML report in browser |

### Chat Interface

**Purpose:** Natural language commands for PCB modifications

**Examples:**
- `"move C135 to position 80, 45"`
- `"add a track on net GND from 10,10 to 60,60"`
- `"what are the routing recommendations?"`
- `"list all capacitors"`
- `"how many components are on this board?"`

---

## Core Modules

### 1. G-IR (Geometry Internal Representation)

**What it is:** Complete geometric representation of your PCB

**Contains:**
- Board outline and dimensions
- Layers (Top, Bottom, GND, VCC, etc.)
- Components (footprints with positions)
- Pads (with positions, sizes, net connections)
- Nets (electrical connections)
- Tracks (routed traces)
- Vias (layer transitions)

**How to use:**
1. **Load PCB:** Click **📁** → Select `.PcbDoc` file
2. **Or Export from Altium:** Menu → **Export PCB Info**
3. Data is automatically converted to G-IR

**Example:**
```
After loading PCB:
- 116 components extracted
- 55 nets identified
- 1038 tracks loaded
- 2390 vias found
- 4 layers detected
```

### 2. C-IR (Constraint Internal Representation)

**What it is:** Design rules and constraints

**Contains:**
- Clearance rules (min spacing between objects)
- Trace width rules (min/preferred/max widths)
- Via rules (drill sizes, diameters)
- Netclasses (grouped nets with default values)

**How to use:**
1. Rules are extracted from Altium when you export PCB info
2. Or create programmatically:
   ```python
   from core.ir.cir import ConstraintIR, Rule, RuleType
   
   cir = ConstraintIR(
       rules=[
           Rule(
               id="rule-clearance",
               type=RuleType.CLEARANCE,
               params={"min_clearance_mm": 0.2}
           )
       ]
   )
   ```

**Example Rules:**
- Minimum clearance: 0.2mm
- Minimum trace width: 0.15mm
- Preferred trace width: 0.25mm
- Via drill: 0.2mm - 0.4mm

### 3. Routing Module

**What it is:** AI-driven routing suggestions with obstacle avoidance

**Features:**
- **A* Pathfinding**: Calculates routes avoiding components
- **Route Suggestions**: For unconnected nets
- **Via Placement**: Suggests optimal via locations
- **Component Spacing**: Optimizes placement

**How to use:**

**Via Menu:**
1. Menu → **Routing Suggestions**
2. See prioritized recommendations

**Via Chat:**
```
User: "generate routing suggestions"
Agent: Shows routing priorities for each net
```

**Via API:**
```python
from runtime.routing.routing_module import RoutingModule

routing = RoutingModule()
suggestions = routing.generate_routing_suggestions(artifact_id)
```

**Example Output:**
```
Routing Suggestions:

[HIGH] +21V: Route with wide traces (0.5mm+) for power integrity
[HIGH] +30VIN: Route with wide traces (0.5mm+) for power integrity
[MEDIUM] NetR222_1: Standard routing with minimum clearance
```

### 4. DRC Module

**What it is:** Design Rule Checking and violation detection

**Checks:**
- Track width violations
- Via drill violations
- Clearance violations (between pads, tracks)
- Unrouted nets

**How to use:**

**Via Menu:**
1. Menu → **Run DRC**
2. Altium Designer runs DRC
3. Report saved to: `PCB_Project/Project Outputs for PCB_Project/`
4. Menu → **View DRC Report** to open in browser

**Via Chat:**
```
User: "run DRC check"
Agent: Runs DRC and shows violations
```

**Example Violations:**
```
DRC Results:
- 55 unrouted nets (warnings)
- 0 clearance violations
- 0 width violations
```

---

## Workflows & Examples

### Workflow 1: Initial Setup & Load PCB

**Step 1:** Start MCP Server
```powershell
python mcp_server.py
```

**Step 2:** Start UI
```powershell
python main.py
```

**Step 3:** Connect to Altium
1. Open Altium Designer
2. Open your PCB
3. Run: `DXP → Run Script → command_server.pas → StartServer`

**Step 4:** Load PCB Data
- **Option A:** Click **📁** → Select `.PcbDoc` file
- **Option B:** Menu → **Export PCB Info** (from Altium)

**Result:** PCB loaded with all data (components, nets, tracks, vias)

---

### Workflow 2: Analyze Board

**Step 1:** Load PCB (see Workflow 1)

**Step 2:** Ask questions in chat:
```
User: "how many components are on this board?"
Agent: "116 components found..."

User: "list all the nets"
Agent: "55 nets: +21V, +30VIN, GND, NetR222_1..."

User: "where is component C135?"
Agent: "C135 is located at (45.2mm, 32.1mm) on Top layer..."
```

**Step 3:** Get routing suggestions:
```
User: "what routing recommendations do you have?"
Agent: Shows prioritized routing suggestions
```

---

### Workflow 3: Run DRC Check

**Step 1:** Ensure Altium is connected (Menu → Altium Status)

**Step 2:** Run DRC
- Menu → **Run DRC**
- Or chat: `"run DRC check"`

**Step 3:** View Results
- Menu → **View DRC Report**
- Opens HTML report in browser

**Step 4:** Fix Violations
- Review violations in report
- Use chat to fix: `"move component U1 to avoid clearance violation"`

---

### Workflow 4: Modify PCB via Chat

**Step 1:** Ensure Altium is connected

**Step 2:** Give commands:
```
User: "move U1 to position 100, 50"
Agent: "Moving component U1 to (100mm, 50mm)..."
       [Shows confirmation modal]
User: Clicks "Yes"
Agent: "Component moved successfully!"
```

**Step 3:** Add routing:
```
User: "add a track on net GND from 10,10 to 60,60"
Agent: "Adding track on GND net..."
       [Shows confirmation]
User: Clicks "Yes"
Agent: "Track added!"
```

**Step 4:** Verify in Altium
- Check Altium Designer - changes should be visible
- Run DRC to verify no violations

---

### Workflow 5: Export & Refresh Data

**Step 1:** Make changes in Altium Designer

**Step 2:** Export updated data
- Menu → **Export PCB Info**
- Waits for export
- Automatically reloads data

**Step 3:** Verify refresh
- Menu → **List Components**
- Should show updated component positions

---

## Feature Details

### G-IR Data Structure

```python
GeometryIR(
    board=Board(
        outline=BoardOutline(polygon=[[0,0], [100,0], [100,80], [0,80]]),
        layers=[
            Layer(id="L1", name="Top", kind=LayerKind.SIGNAL, index=1),
            Layer(id="L2", name="GND", kind=LayerKind.GROUND, index=2)
        ],
        stackup=Stackup(layers=["L1", "L2"], thickness_mm=1.6)
    ),
    nets=[
        Net(id="net-gnd", name="GND"),
        Net(id="net-vcc", name="VCC")
    ],
    tracks=[
        Track(
            id="trk1",
            net_id="net-gnd",
            layer_id="L1",
            segments=[
                TrackSegment(from_pos=[10,10], to_pos=[50,10], width_mm=0.25)
            ]
        )
    ],
    vias=[
        Via(
            id="via1",
            net_id="net-gnd",
            position=[30,10],
            drill_mm=0.3,
            layers=["L1", "L4"]
        )
    ],
    footprints=[
        Footprint(
            id="fp-u1",
            ref="U1",
            position=[20,20],
            rotation_deg=90,
            layer="L1",
            pads=[
                Pad(
                    id="pad1",
                    net_id="net-gnd",
                    position=[0,0],
                    size_mm=[1,1]
                )
            ]
        )
    ]
)
```

### C-IR Data Structure

```python
ConstraintIR(
    rules=[
        Rule(
            id="rule-clearance",
            type=RuleType.CLEARANCE,
            scope=RuleScope(),
            params=RuleParams(min_clearance_mm=0.2),
            enabled=True
        ),
        Rule(
            id="rule-width",
            type=RuleType.TRACE_WIDTH,
            scope=RuleScope(netclass="power"),
            params=RuleParams(
                min_width_mm=0.25,
                preferred_width_mm=0.5
            ),
            enabled=True
        )
    ],
    netclasses=[
        Netclass(
            id="nc-power",
            name="Power",
            nets=["net-vcc"],
            defaults=NetclassDefaults(
                trace_width_mm=0.5,
                clearance_mm=0.3
            )
        )
    ]
)
```

### Routing Module Functions

```python
# Generate routing suggestions
suggestions = routing.generate_routing_suggestions(artifact_id)

# Route a specific net
patch = routing.route_net(
    artifact_id=artifact_id,
    net_id="net-gnd",
    start_pos=[10.0, 10.0],
    end_pos=[50.0, 50.0],
    layer_id="L1",
    width_mm=0.25
)

# Place a via
via_patch = routing.place_via(
    artifact_id=artifact_id,
    net_id="net-gnd",
    position=[30.0, 30.0],
    layers=["L1", "L4"],
    drill_mm=0.3
)

# Calculate path with obstacle avoidance
waypoints = routing.calculate_route_path(
    start_pos=[0.0, 0.0],
    end_pos=[50.0, 50.0],
    obstacles=[(25.0, 25.0, 5.0)],  # (x, y, radius)
    grid_resolution=0.5
)
```

### DRC Module Functions

```python
# Run DRC check
violations_artifact = drc.run_drc(
    board_artifact_id=board_id,
    constraint_artifact_id=constraint_id
)

# Get violations
violations = drc.get_violations(violations_artifact.id)

# Example violation:
{
    "id": "violation-1",
    "type": "clearance",
    "severity": "error",
    "message": "Clearance violation between pads: 0.15mm < 0.2mm",
    "location": {"x_mm": 25.0, "y_mm": 30.0},
    "actual_clearance_mm": 0.15,
    "required_clearance_mm": 0.2
}
```

---

## API Endpoints

### MCP Server (http://localhost:8765)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health check |
| `/status` | GET | Connection status |
| `/pcb/info` | GET | Get current PCB info |
| `/pcb/load` | POST | Load PCB file |
| `/pcb/load-altium-export` | POST | Load from Altium export |
| `/routing/suggestions` | GET | Get routing suggestions |
| `/routing/route` | POST | Route a net |
| `/routing/via` | POST | Place a via |
| `/drc/run` | GET | Run DRC check |
| `/altium/status` | GET | Altium script server status |
| `/altium/ping` | GET | Test Altium connection |
| `/altium/apply` | POST | Apply action to Altium |

### Example API Calls

```powershell
# Health check
curl http://localhost:8765/health

# Load PCB
curl -X POST http://localhost:8765/pcb/load `
  -H "Content-Type: application/json" `
  -d '{"path": "PCB_Project/Y904A23-GF-DYPCB-V1.0.PcbDoc"}'

# Get routing suggestions
curl http://localhost:8765/routing/suggestions

# Run DRC
curl http://localhost:8765/drc/run
```

---

## File Structure

```
EagilinsED_PCB-Design-Agent/
├── core/
│   ├── ir/
│   │   ├── gir.py          # G-IR (Geometry)
│   │   └── cir.py          # C-IR (Constraints)
│   ├── artifacts/
│   │   ├── models.py       # Artifact models
│   │   └── store.py        # Version control
│   └── patch/
│       ├── schema.py       # Patch schema
│       └── operations.py   # Patch operations
├── runtime/
│   ├── routing/
│   │   └── routing_module.py  # Routing with A*
│   └── drc/
│       └── drc_module.py       # DRC checking
├── adapters/
│   └── altium/
│       ├── importer.py     # Altium → G-IR/C-IR
│       └── exporter.py     # G-IR/C-IR → Altium
├── tools/
│   ├── altium_file_reader.py  # Read .PcbDoc files
│   └── altium_script_client.py # Altium command client
├── pages/
│   └── agent_page.py       # Main UI
├── altium_scripts/
│   └── command_server.pas  # Altium script server
├── mcp_server.py          # REST API server
├── main.py                # UI entry point
└── artifacts/             # Versioned data storage
```

---

## Troubleshooting

### Issue: MCP Server won't start

**Solution:**
```powershell
# Check if port 8765 is in use
netstat -ano | findstr :8765

# Kill process if needed
taskkill /PID <pid> /F

# Restart server
python mcp_server.py
```

### Issue: Altium Script Server not connecting

**Solution:**
1. Verify Altium Designer is open
2. Verify PCB document is open
3. Check file paths in `command_server.pas`:
   ```pascal
   COMMAND_FILE = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\altium_command.json';
   RESULT_FILE  = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\altium_result.json';
   ```
4. Run script again: `DXP → Run Script → StartServer`

### Issue: "No PCB loaded" error

**Solution:**
1. Click **📁** button → Select `.PcbDoc` file
2. Or Menu → **Export PCB Info** (if Altium connected)

### Issue: OpenAI API errors

**Solution:**
1. Check `.env` file has `OPENAI_API_KEY`
2. Or set environment variable:
   ```powershell
   $env:OPENAI_API_KEY="sk-..."
   ```
3. Verify API key is valid

### Issue: Import errors

**Solution:**
```powershell
# Reinstall dependencies
pip install -r requirements.txt

# Check Python version
python --version  # Should be 3.8+
```

---

## Quick Reference

### Common Chat Commands

| Command | Result |
|---------|--------|
| `"how many components?"` | Shows component count |
| `"list all nets"` | Lists all electrical nets |
| `"where is U1?"` | Shows component location |
| `"move U1 to 50, 60"` | Moves component (requires confirmation) |
| `"add track on GND from 10,10 to 50,50"` | Adds track (requires confirmation) |
| `"run DRC"` | Runs design rule check |
| `"routing suggestions"` | Gets AI routing recommendations |

### Menu Actions

| Action | Keyboard | Description |
|--------|----------|-------------|
| Run DRC | - | Runs DRC in Altium |
| Export PCB Info | - | Exports data from Altium |
| Refresh Data | - | Reloads current PCB |
| View DRC Report | - | Opens DRC HTML report |

### File Locations

| File | Location |
|------|----------|
| Altium export | `altium_pcb_info.json` |
| DRC report | `PCB_Project/Project Outputs for PCB_Project/Design Rule Check*.html` |
| Artifacts | `artifacts/{uuid}/` |
| Command file | `altium_command.json` |
| Result file | `altium_result.json` |

---

## Next Steps

1. **Load your PCB** - Use 📁 button or Export from Altium
2. **Explore data** - Ask questions in chat
3. **Run DRC** - Check for violations
4. **Get suggestions** - Use routing suggestions
5. **Make modifications** - Use chat commands (with confirmation)

---

## Support

For issues or questions:
1. Check this guide
2. Review `WEEK_SUMMARY.md` for implementation details
3. Check terminal output for error messages
4. Verify Altium connection status

---

**Happy PCB Designing! 🎉**
