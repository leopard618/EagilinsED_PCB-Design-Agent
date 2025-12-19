# Command Execution Guide

## How Commands Work

**YES - You only need to run ONE script per command type to execute ALL queued commands.**

### How It Works:

1. **Agent queues commands** → Commands are saved to JSON files
2. **You run ONE script** → The script reads ALL commands from the JSON file
3. **Script executes ALL commands** → All queued commands are processed at once
4. **JSON file is cleared** → After execution, the file is reset to `[]`

---

## Command Types & Scripts

### 1. Schematic Commands

**File:** `schematic_commands.json`  
**Script:** `altium_schematic_modify.pas`  
**Procedure:** `ExecuteSchematicCommands`

**What it does:**
- Reads ALL commands from `schematic_commands.json`
- Executes them one by one:
  - `place_component` - Places components
  - `add_wire` - Adds wires
  - `add_net_label` - Adds net labels
  - `add_power_port` - Adds power ports
  - `annotate` - Annotates schematic
- Shows success/failure count
- Clears the JSON file after execution

**Example:**
```
You queue 5 commands:
1. place_component (R1)
2. place_component (C1)
3. add_wire (R1 to C1)
4. add_net_label (VCC)
5. add_power_port (GND)

→ Run altium_schematic_modify.pas ONCE
→ All 5 commands execute automatically
→ Shows: "5 command(s) executed successfully"
```

---

### 2. PCB Commands

**File:** `pcb_commands.json`  
**Script:** `RUN.pas`  
**Procedure:** `ExecuteCommands`

**What it does:**
- Reads ALL commands from `pcb_commands.json`
- Executes them one by one:
  - `move_component` - Moves components
  - `rotate_component` - Rotates components
  - `add_track` - Adds routing tracks
  - `add_via` - Adds vias
  - `set_layer` - Changes layer
- Shows success/failure count
- Clears the JSON file after execution

**Example:**
```
You queue 10 commands:
1. move_component (U1 to x=50, y=50)
2. move_component (R1 to x=60, y=50)
3. rotate_component (U1, 90°)
... (7 more commands)

→ Run RUN.pas ONCE
→ All 10 commands execute automatically
→ Shows: "10 command(s) executed successfully"
```

---

### 3. Project Creation Commands

**File:** `project_commands.json`  
**Script:** `altium_project_manager.pas`  
**Procedures:** 
- `CreateNewProject` - Creates new project
- `CreateSchematicDocument` - Creates schematic
- `CreatePCBDocument` - Creates PCB

**Note:** These are individual procedures, not batch execution.

**Example:**
```
1. Agent queues: CreateProject
   → Run altium_project_manager.pas → CreateNewProject

2. Agent queues: CreateSchematic
   → Run altium_project_manager.pas → CreateSchematicDocument

3. Agent queues: CreatePCB
   → Run altium_project_manager.pas → CreatePCBDocument
```

---

## Workflow Example

### Scenario: Create Project and Add Components

**Step 1: Create Project**
```
User: "Create a new project called MyProject"
Agent: Queues command → project_commands.json
You: Run altium_project_manager.pas → CreateNewProject
Result: Project created
```

**Step 2: Add Schematic**
```
User: "Add a schematic document"
Agent: Queues command → project_commands.json
You: Run altium_project_manager.pas → CreateSchematicDocument
Result: Schematic added
```

**Step 3: Place Multiple Components**
```
User: "Add resistor R1, capacitor C1, and connect them"
Agent: Queues 3 commands → schematic_commands.json:
  1. place_component (R1)
  2. place_component (C1)
  3. add_wire (R1 to C1)

You: Run altium_schematic_modify.pas → ExecuteSchematicCommands ONCE
Result: All 3 commands execute automatically
Shows: "3 command(s) executed successfully"
```

---

## Important Notes

### ✅ DO:
- Run the script ONCE per command type
- Wait for the script to finish (shows success message)
- Check the success/failure count
- Run ExportSchematicInfo or ExportPCBInfo after modifications

### ❌ DON'T:
- Run the script multiple times for the same commands
- Run the script if the JSON file is empty (`[]`)
- Run the script if no document is open

---

## Troubleshooting

### "No commands found"
- Check if JSON file exists
- Check if JSON file has commands (not just `[]`)
- Make sure you're in the correct document (Schematic for schematic commands, PCB for PCB commands)

### "Some commands failed"
- Check the error message
- Verify component/library names are correct
- Make sure coordinates are valid
- Check if document is locked or read-only

### "Script error"
- Make sure the correct document is open
- Check file paths in the script (BASE_PATH)
- Verify JSON syntax is correct

---

## Quick Reference

| Command Type | JSON File | Script | Procedure |
|--------------|-----------|--------|-----------|
| Schematic | `schematic_commands.json` | `altium_schematic_modify.pas` | `ExecuteSchematicCommands` |
| PCB | `pcb_commands.json` | `RUN.pas` | `ExecuteCommands` |
| Project | `project_commands.json` | `altium_project_manager.pas` | `CreateNewProject` / `CreateSchematicDocument` / `CreatePCBDocument` |

---

## Summary

**YES - One script execution processes ALL queued commands of that type.**

- Queue multiple commands → Run script once → All execute
- No need to run script multiple times
- Script automatically processes the entire queue
- JSON file is cleared after successful execution

