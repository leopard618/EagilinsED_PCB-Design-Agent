# EagilinsED - Complete Command List

## 🎯 Project Goal

**EagilinsED** is an **AI-powered PCB design co-pilot** that:
- **Automatically generates PCB layouts from schematics** without step-by-step instructions
- **Analyzes designs** to identify functional blocks, components, and signals
- **Generates placement strategies** and design rules
- **Reviews designs** for issues and suggests improvements
- **Executes commands** in Altium Designer via natural language

---

## 📋 Command Categories

### 1. **Intelligent Design Commands** (Natural Language → AI Analysis)

These commands use AI to analyze and generate design decisions:

| Command | Description | Example |
|---------|-------------|---------|
| `analyze` | Analyze schematic/PCB design | "Analyze this schematic" |
| `strategy` | Generate placement strategy | "Generate placement strategy" |
| `review` | Review design for issues | "Review this design" |
| `generate_layout` | Generate PCB layout from schematic | "Generate layout for this design" |

**How to use:**
- Just type in natural language in the agent chat
- Agent automatically detects intent and performs analysis
- Results are shown in chat, no Altium script needed

---

### 2. **Project Management Commands** (via RUN.pas or altium_project_manager.pas)

| Command | Script | Procedure | Parameters | Description |
|---------|--------|-----------|------------|-------------|
| `create_project` / `create_new_project` | `RUN.pas` → Shows instructions | `ExecuteCreateProject` | `{"project_name": "MyProject"}` | Creates new PCB project |
| `create_project` | `altium_project_manager.pas` | `CreateProjectFromJson` | Reads from `pcb_commands.json` | Creates project from JSON |
| `export_project_info` | `RUN.pas` | `ExecuteExportProjectInfo` | `{}` | Exports project info to JSON |

**Note:** `create_project` in RUN.pas shows instructions to use `altium_project_manager.pas → CreateProjectFromJson`

---

### 3. **PCB Modification Commands** (via RUN.pas)

**File:** `pcb_commands.json`  
**Script:** `RUN.pas`  
**Procedure:** `ExecuteCommands`

| Command | Parameters | Description | Requires PCB Open |
|---------|------------|-------------|------------------|
| `move_component` | `{"component_name": "U1", "new_coordinates": [50.0, 50.0]}` | Move component to new position | ✅ Yes |
| `rotate_component` | `{"component_name": "U1", "rotation_degrees": 90}` | Rotate component | ✅ Yes |
| `remove_component` | `{"component_name": "U1"}` | Remove component from PCB | ✅ Yes |
| `add_component` | `{"component_name": "R1", "footprint": "R0805", "coordinates": [50.0, 50.0]}` | Add new component | ✅ Yes |
| `change_component_value` | `{"component_name": "R1", "parameter": "Value", "new_value": "10k"}` | Change component value/parameter | ✅ Yes |
| `add_track` | `{"start": [10.0, 10.0], "end": [20.0, 20.0], "width": 0.2, "layer": "TopLayer"}` | Add routing track | ✅ Yes |
| `add_via` | `{"coordinates": [15.0, 15.0], "diameter": 0.5, "hole_diameter": 0.2}` | Add via at location | ✅ Yes |
| `change_layer` | `{"component_name": "U1", "new_layer": "BottomLayer"}` | Move component to different layer | ✅ Yes |

**Usage:**
1. Agent queues commands to `pcb_commands.json`
2. Run `RUN.pas → ExecuteCommands` **ONCE**
3. All queued commands execute automatically
4. File is cleared after execution

---

### 4. **Schematic Modification Commands** (via altium_schematic_modify.pas)

**File:** `schematic_commands.json`  
**Script:** `altium_schematic_modify.pas`  
**Procedure:** `ExecuteSchematicCommands`

| Command | Parameters | Description | Requires Schematic Open |
|---------|------------|-------------|------------------------|
| `place_component` | `{"component_name": "R1", "library": "Miscellaneous Devices", "symbol": "Resistor", "coordinates": [100.0, 100.0]}` | Place component in schematic | ✅ Yes |
| `add_wire` | `{"start": [100.0, 100.0], "end": [200.0, 100.0]}` | Add wire between points | ✅ Yes |
| `add_net_label` | `{"net_name": "VCC", "coordinates": [150.0, 100.0]}` | Add net label | ✅ Yes |
| `add_power_port` | `{"port_name": "GND", "port_type": "Power Ground", "coordinates": [100.0, 50.0]}` | Add power port | ✅ Yes |
| `annotate` / `annotate_schematic` | `{}` | Annotate schematic components | ✅ Yes |

**Usage:**
1. Agent queues commands to `schematic_commands.json`
2. Run `altium_schematic_modify.pas → ExecuteSchematicCommands` **ONCE**
3. All queued commands execute automatically
4. File is cleared after execution

---

### 5. **Data Export Commands** (via individual scripts)

| Command | Script | Procedure | Output File | Description |
|---------|--------|-----------|-------------|-------------|
| `export_project_info` | `RUN.pas` | `ExecuteExportProjectInfo` | `project_info.json` | Export project information |
| `export_pcb_info` | `altium_export_pcb_info.pas` | `ExportPCBInfo` | `pcb_info.json` | Export PCB data (components, nets, tracks) |
| `export_schematic_info` | `altium_export_schematic_info.pas` | `ExportSchematicInfo` | `schematic_info.json` | Export schematic data (components, wires, nets) |
| `export_design_rules` | `altium_design_rules.pas` | `ExportDesignRules` | `design_rules.json` | Export design rules |
| `export_board_config` | `altium_pcb_setup.pas` | `ExportBoardConfig` | `board_config.json` | Export board configuration |
| `run_drc` | `altium_verification.pas` | `RunDRCAndExport` | `verification_report.json` | Run DRC and export results |
| `run_erc` | `altium_verification.pas` | `RunERCAndExport` | `connectivity_report.json` | Run ERC and export results |
| `search_components` | `altium_component_search.pas` | `SearchComponents` | `component_search.json` | Search component libraries |

**Note:** Export commands are typically run manually in Altium, not queued via agent.

---

## 🧪 Testing Guide by Command Type

### Test 1: Intelligent Design Commands

**Test Commands:**
```
1. "Analyze this schematic"
2. "Generate placement strategy"
3. "Review this design for issues"
4. "Generate layout from this schematic"
```

**Prerequisites:**
- Schematic or PCB data exported (run export scripts first)
- Agent connected to MCP server

**Expected Results:**
- Analysis shows functional blocks, components, signals
- Strategy shows placement recommendations
- Review shows issues and suggestions
- Layout generation creates placement coordinates

---

### Test 2: Project Creation

**Test Command:**
```
"Create a new project called TestProject"
```

**Steps:**
1. Agent queues command to `pcb_commands.json`
2. Run `RUN.pas → ExecuteCommands` in Altium
3. Shows instructions to run `altium_project_manager.pas → CreateProjectFromJson`
4. Run `altium_project_manager.pas → CreateProjectFromJson`
5. Project is created and opened
6. `pcb_commands.json` is cleared

**Verification:**
- Project file created at: `E:\Workspace\AI\11.10.WayNe\new-version\TestProject.PrjPcb`
- Project opens in Altium Designer
- Command file is cleared

---

### Test 3: PCB Modification Commands

**Test Commands:**
```
1. "Move component U1 to position 50, 50"
2. "Rotate component R1 by 90 degrees"
3. "Add a track from 10,10 to 20,20"
4. "Add a via at position 15,15"
```

**Prerequisites:**
- PCB document must be open in Altium
- Components must exist on PCB

**Steps:**
1. Agent queues commands to `pcb_commands.json`
2. Run `RUN.pas → ExecuteCommands` **ONCE**
3. All commands execute automatically
4. Shows success/failure count
5. File is cleared

**Verification:**
- Components move/rotate as specified
- Tracks and vias are added
- Command file is cleared after execution

---

### Test 4: Schematic Modification Commands

**Test Commands:**
```
1. "Place a resistor R1 at position 100, 100"
2. "Add a wire from R1 to C1"
3. "Add net label VCC at position 150, 100"
4. "Add power port GND"
```

**Prerequisites:**
- Schematic document must be open in Altium
- Project must exist

**Steps:**
1. Agent queues commands to `schematic_commands.json`
2. Run `altium_schematic_modify.pas → ExecuteSchematicCommands` **ONCE**
3. All commands execute automatically
4. Shows success/failure count
5. File is cleared

**Verification:**
- Components are placed
- Wires are added
- Net labels and power ports are added
- Command file is cleared after execution

---

### Test 5: Data Export Commands

**Test Steps:**
1. Open a project with schematic and/or PCB in Altium
2. Run export scripts manually:
   - `altium_export_schematic_info.pas → ExportSchematicInfo`
   - `altium_export_pcb_info.pas → ExportPCBInfo`
   - `altium_project_manager.pas → ExportProjectInfo`
3. Check that JSON files are created in project directory
4. Agent can now read this data for analysis

**Verification:**
- JSON files are created
- Files contain valid data
- Agent can access data via MCP server

---

## 📝 Command Format Examples

### Natural Language (Agent Chat)
```
✅ "Create a new project called MyProject"
✅ "Move component U1 to position 50, 50"
✅ "Analyze this schematic"
✅ "Generate layout from this design"
✅ "Add a resistor R1 at 100, 100"
```

### JSON Format (Command Files)
```json
[
  {
    "command": "move_component",
    "parameters": {
      "component_name": "U1",
      "new_coordinates": [50.0, 50.0]
    },
    "timestamp": 1234567890.123
  }
]
```

---

## 🔄 Complete Workflow Example

### Scenario: Create Project → Add Schematic → Generate Layout

**Step 1: Create Project**
```
User: "Create a new project called MyProject"
→ Agent queues: create_new_project
→ Run: RUN.pas → ExecuteCommands (shows instructions)
→ Run: altium_project_manager.pas → CreateProjectFromJson
→ Result: Project created and opened
```

**Step 2: Add Schematic Document**
```
User: "Add a schematic document"
→ Agent queues: create_schematic
→ Run: altium_project_manager.pas → CreateSchematicDocument
→ Result: Schematic document created
```

**Step 3: Place Components**
```
User: "Place resistor R1 and capacitor C1"
→ Agent queues: place_component (R1), place_component (C1)
→ Run: altium_schematic_modify.pas → ExecuteSchematicCommands ONCE
→ Result: Both components placed
```

**Step 4: Export Data**
```
→ Run: altium_export_schematic_info.pas → ExportSchematicInfo
→ Result: schematic_info.json created
```

**Step 5: Generate Layout**
```
User: "Generate layout from this schematic"
→ Agent analyzes schematic
→ Agent generates placement coordinates
→ Agent queues: move_component commands
→ Run: RUN.pas → ExecuteCommands ONCE
→ Result: Components placed on PCB
```

---

## ⚠️ Important Notes

### ✅ DO:
- Run scripts **ONCE** per command type (they process all queued commands)
- Wait for success message before running again
- Export data before asking for analysis
- Open correct document type (Schematic for schematic commands, PCB for PCB commands)

### ❌ DON'T:
- Run scripts multiple times for same commands
- Run scripts if JSON file is empty (`[]`)
- Run scripts without required documents open
- Mix command types in wrong files

---

## 📊 Command Summary Table

| Category | Commands | Script | File | Batch? |
|----------|----------|--------|------|--------|
| **Intelligent** | analyze, strategy, review, generate_layout | N/A (AI) | N/A | N/A |
| **Project** | create_project, export_project_info | RUN.pas / altium_project_manager.pas | pcb_commands.json | ❌ |
| **PCB** | move_component, rotate_component, add_track, add_via, etc. | RUN.pas | pcb_commands.json | ✅ |
| **Schematic** | place_component, add_wire, add_net_label, etc. | altium_schematic_modify.pas | schematic_commands.json | ✅ |
| **Export** | export_pcb_info, export_schematic_info, etc. | Individual scripts | Individual JSON files | ❌ |

---

## 🎯 Project Goal Summary

**EagilinsED** enables:
1. ✅ **Autonomous Layout Generation** - Takes schematic → Generates PCB layout automatically
2. ✅ **Intelligent Design Analysis** - Identifies functional blocks, components, signals
3. ✅ **Strategy Generation** - Recommends placement and routing strategies
4. ✅ **Design Review** - Finds issues and suggests improvements
5. ✅ **Natural Language Control** - Execute Altium commands via chat
6. ✅ **Batch Execution** - Process multiple commands at once

**Key Capability:** The agent can take a schematic file **without step-by-step instructions** and generate an initial PCB layout automatically. ✅

