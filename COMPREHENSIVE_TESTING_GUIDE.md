# EagilinsED - Comprehensive Testing Guide

## 🎯 Testing Approaches

This guide provides **two ways** to test EagilinsED:

### Approach 1: Complete Design Workflow (Recommended) ⭐
**Follow Phases 1-9** to create a complete PCB design from scratch. This matches the Altium Designer tutorial workflow and tests all features in a real-world scenario. **If you complete all 9 phases, you have successfully completed a full project!**

### Approach 2: Individual Feature Testing
**Skip to Section 4** to test individual features independently. Use this if you already have a project and want to test specific features.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup Instructions](#setup-instructions)
3. [Complete Design Workflow - From Scratch](#complete-design-workflow---from-scratch)
   - [Phase 1: Creating the Project and Schematic Document](#phase-1-creating-the-project-and-schematic-document)
   - [Phase 2: Searching for and Acquiring Components](#phase-2-searching-for-and-acquiring-components)
   - [Phase 3: Capturing the Schematic](#phase-3-capturing-the-schematic)
   - [Phase 4: Setting Up Design Constraints](#phase-4-setting-up-design-constraints)
   - [Phase 5: Creating and Configuring PCB Document](#phase-5-creating-and-configuring-pcb-document)
   - [Phase 6: Placing Components and Routing the Board](#phase-6-placing-components-and-routing-the-board)
   - [Phase 7: Verifying Your Board Design](#phase-7-verifying-your-board-design)
   - [Phase 8: Creating the PCB Drawing](#phase-8-creating-the-pcb-drawing)
   - [Phase 9: Preparing Outputs and Releasing](#phase-9-preparing-outputs-and-releasing)
4. [Data Export Scripts Testing](#data-export-scripts-testing)
5. [Modification Commands Testing](#modification-commands-testing)
6. [Agent Intelligence Testing](#agent-intelligence-testing)
7. [Component Search Testing](#component-search-testing)
8. [Verification & Output Testing](#verification--output-testing)
9. [Advanced Features Testing](#advanced-features-testing)
10. [Troubleshooting](#troubleshooting)
11. [Test Results Template](#test-results-template)

---

## 🔧 Prerequisites

### Required Software
- ✅ Altium Designer 25.5.2 (with license)
- ✅ Python 3.8+ with virtual environment
- ✅ EagilinsED application files
- ✅ All Altium scripts in `altium_scripts/` folder

### Required Files
- ✅ `pcb_info.json` (will be created by export script)
- ✅ `schematic_info.json` (will be created by export script)
- ✅ `pcb_commands.json` (should exist as empty array `[]`)
- ✅ `schematic_commands.json` (should exist as empty array `[]`)

### Test Environment
- ✅ Altium Designer with a PCB project open
- ✅ At least one PCB document (.PcbDoc)
- ✅ At least one Schematic document (.SchDoc)
- ✅ MCP Server running on port 8080
- ✅ EagilinsED application running

---

## 🚀 Setup Instructions

### Step 1: Start MCP Server

**Terminal 1:**
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py
```

**Expected Output:**
```
[MCP Server] Starting server on port 8080...
[MCP Server] Server started successfully
```

**✅ Test:** Open browser to `http://localhost:8080/health` - should return `{"status": "ok"}`

---

### Step 2: Start EagilinsED Application

**Terminal 2:**
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python main.py
```

**Expected:** Application window opens with welcome page

---

### Step 3: Open Altium Designer

1. Open Altium Designer 25.5.2
2. You can either:
   - **Option A:** Open an existing project (skip to Phase 3)
   - **Option B:** Follow the complete workflow from scratch (start with Phase 1)

---

## 🎯 Complete Design Workflow - From Scratch

This section guides you through a **complete PCB design workflow** using EagilinsED, matching the Altium Designer tutorial structure. This is the **recommended path** to test all features in a real-world scenario.

### Phase 1: Creating the Project and Schematic Document

**Purpose:** Set up a new project from scratch

**You have TWO options:**

#### Option A: Using Altium Designer UI (Traditional Method)

1. **Create New Project in Altium Designer:**
   - In Altium Designer, go to: **File → New → Project → PCB Project**
   - Choose a location and name (e.g., `MyTestProject.PrjPcb`)
   - Click **OK**

2. **Add Schematic Document:**
   - Right-click on the project in **Projects** panel
   - Select: **Add New to Project → Schematic**
   - A new schematic document (`Sheet1.SchDoc`) is created
   - Save the project: **File → Save Project As...**
   - Save the schematic: **File → Save As...** (name it `Main.SchDoc`)

#### Option B: Using EagilinsED Scripts (New Method) ⭐

1. **Create New Project via Script:**
   - In Altium Designer: **File → Run Script**
   - Select: `altium_project_manager.pas`
   - Choose: **`CreateNewProject`**
   - Enter project name (e.g., `MyTestProject`)
   - Enter project folder path (or leave empty for default)
   - Click **OK**
   - Project is created and opened automatically

2. **Create Schematic Document via Script:**
   - **File → Run Script → `altium_project_manager.pas` → `CreateSchematicDocument`**
   - Enter schematic name (e.g., `Main`)
   - Click **OK**
   - Schematic document is created, added to project, and opened automatically

3. **Create PCB Document via Script (Optional - can do later):**
   - **File → Run Script → `altium_project_manager.pas` → `CreatePCBDocument`**
   - Enter PCB name (e.g., `Main`)
   - Click **OK**
   - PCB document is created, added to project, and opened automatically

4. **Verify Project Structure:**
   - In **Projects** panel, you should see:
     ```
     MyTestProject.PrjPcb
     ├── Main.SchDoc
     └── (PCB document if created)
     ```

5. **Export Project Info (Optional but Recommended):**
   - **File → Run Script → `altium_project_manager.pas` → `ExportProjectInfo`**
   - This creates `project_info.json` for EagilinsED to understand your project

**✅ Pass Criteria:**
- Project created successfully
- Schematic document added to project
- Project saved without errors
- Project structure visible in Projects panel

**📝 Notes:**
- You now have a project with a schematic document
- Ready to start adding components

---

### Phase 2: Searching for and Acquiring Components

**Purpose:** Find and prepare components for your design using EagilinsED

**Steps:**

1. **Start EagilinsED and Connect:**
   - Make sure MCP server is running (from Setup Step 1)
   - Open EagilinsED application (from Setup Step 2)
   - Click **Connect** button
   - Wait for connection to establish

2. **Search for Components via EagilinsED:**
   - In EagilinsED chat, ask: **"Find a 10k resistor"** or **"Search for capacitors"**
   - Agent will provide instructions to run component search

3. **Run Component Search in Altium:**
   - In Altium Designer: **File → Run Script**
   - Select: `altium_component_search.pas`
   - Choose: **`SearchComponents`**
   - Enter search term (e.g., "resistor", "capacitor", "LED", "microcontroller")
   - Click **OK**
   - Wait for success message: "Component Search Complete!"

4. **View Search Results in EagilinsED:**
   - In EagilinsED, reconnect to refresh data
   - Ask: **"What components did you find?"** or **"Show me the search results"**
   - Agent will display component names, libraries, and descriptions

5. **List Available Libraries (Optional):**
   - In Altium Designer: **File → Run Script → `altium_component_search.pas` → `ListInstalledLibraries`**
   - This helps you see what libraries are available

**✅ Pass Criteria:**
- Component search executes successfully
- Search results file created (`component_search.json`)
- Agent displays search results correctly
- You can identify components you want to use

**📝 Notes:**
- Keep note of component names and library paths from search results
- You'll use these in Phase 3 to place components

---

### Phase 3: Capturing the Schematic

**Purpose:** Create your schematic by placing components and connecting them using EagilinsED

**Steps:**

1. **Make Schematic Active:**
   - In Altium Designer, click on the **Schematic document tab** (`Main.SchDoc`)
   - Ensure it's the active/focused document

2. **Place Components via EagilinsED:**
   - In EagilinsED chat, ask: **"Place a resistor R1 at position 100, 100"**
   - Agent will queue the command
   - **Execute in Altium:** **File → Run Script → `altium_schematic_modify.pas` → `ExecuteSchematicCommands`**
   - Verify component appears in schematic

3. **Place More Components:**
   - Continue placing components:
     - **"Place a capacitor C1 at position 200, 100"**
     - **"Place an LED D1 at position 300, 100"**
     - **"Place a microcontroller U1 at position 200, 200"**
   - After each command, run `ExecuteSchematicCommands` in Altium

4. **Add Power Ports:**
   - In EagilinsED: **"Add VCC power port at position 50, 50"**
   - In EagilinsED: **"Add GND power port at position 50, 150"**
   - Run `ExecuteSchematicCommands` in Altium

5. **Connect Components with Wires:**
   - In EagilinsED: **"Add a wire from 100, 100 to 200, 100"**
   - In EagilinsED: **"Add a wire from 200, 100 to 300, 100"**
   - Continue adding wires to connect your circuit
   - Run `ExecuteSchematicCommands` after each wire command

6. **Add Net Labels (Optional):**
   - In EagilinsED: **"Add net label VCC at position 100, 80"**
   - Run `ExecuteSchematicCommands` in Altium

7. **Annotate Schematic:**
   - In EagilinsED: **"Annotate the schematic"**
   - Run `ExecuteSchematicCommands` in Altium
   - Components get proper designators (R1, C1, U1, etc.)

8. **Export Schematic Info:**
   - **File → Run Script → `altium_export_schematic_info.pas` → `ExportSchematicInfo`**
   - This creates `schematic_info.json` for EagilinsED

9. **Verify Schematic:**
   - In EagilinsED, reconnect
   - Ask: **"What components are in my schematic?"**
   - Agent should list all placed components

**✅ Pass Criteria:**
- Components placed successfully
- Wires connect components
- Power ports added
- Schematic is readable and logical
- Schematic info exported correctly

**📝 Notes:**
- Your schematic is now complete
- Ready to move to PCB layout

---

### Phase 4: Setting Up Design Constraints

**Purpose:** Configure design rules before PCB layout

**Steps:**

1. **Create PCB Document (if not already created):**
   
   **Option A: Using Altium UI:**
   - Right-click on project in **Projects** panel
   - Select: **Add New to Project → PCB**
   - A new PCB document (`PCB1.PcbDoc`) is created
   - Save it: **File → Save As...** (name it `Main.PcbDoc`)
   
   **Option B: Using Script:**
   - **File → Run Script → `altium_project_manager.pas` → `CreatePCBDocument`**
   - Enter PCB name (e.g., `Main`)
   - Click **OK**
   - PCB document is created and opened automatically

2. **Update PCB from Schematic:**
   - In Altium Designer: **Design → Update PCB Document Main.PcbDoc**
   - Click **Validate Changes**
   - Click **Execute Changes**
   - Click **Close**
   - Components should appear in PCB document

3. **Export Design Rules:**
   - Make sure PCB document is active
   - **File → Run Script → `altium_design_rules.pas` → `ExportDesignRules`**
   - This creates `design_rules.json`

4. **View Design Rules via EagilinsED:**
   - In EagilinsED, reconnect
   - Ask: **"What are my design rules?"** or **"What is the minimum clearance?"**
   - Agent will display current design rules

5. **Modify Design Rules (if needed):**
   - In Altium Designer: **Design → Rules...**
   - Adjust rules as needed (clearance, track width, via size, etc.)
   - Re-export design rules after changes

**✅ Pass Criteria:**
- PCB document created
- Components imported from schematic
- Design rules exported
- Agent can read design rules

**📝 Notes:**
- Design rules are now set
- Ready to configure board and place components

---

### Phase 5: Creating and Configuring PCB Document

**Purpose:** Set up board size, layers, and stackup

**Steps:**

1. **Define Board Outline:**
   - In PCB document, switch to **Keep-Out Layer** (press `L` to see layers)
   - Draw board outline using **Place → Line** or **Place → Rectangle**
   - Or use **Design → Board Shape → Define from selected objects**

2. **Export Board Configuration:**
   - **File → Run Script → `altium_pcb_setup.pas` → `ExportBoardConfig`**
   - This creates `board_config.json`

3. **View Board Info via EagilinsED:**
   - In EagilinsED, reconnect
   - Ask: **"What is my board size?"** or **"How many layers does my board have?"**
   - Agent will display board configuration

4. **Configure Layer Stack (if needed):**
   - In Altium Designer: **Design → Layer Stack Manager**
   - Add/remove layers, configure stackup
   - Re-export board config after changes

**✅ Pass Criteria:**
- Board outline defined
- Board configuration exported
- Agent can read board info

**📝 Notes:**
- Board is now configured
- Ready to place components

---

### Phase 6: Placing Components and Routing the Board

**Purpose:** Place components on PCB and route connections using EagilinsED

**Steps:**

1. **Export PCB Info:**
   - Make sure PCB document is active
   - **File → Run Script → `altium_export_pcb_info.pas` → `ExportPCBInfo`**
   - This creates `pcb_info.json`

2. **Connect to EagilinsED:**
   - In EagilinsED, click **Connect**
   - Wait for connection and data loading

3. **View Current PCB State:**
   - In EagilinsED, ask: **"What components are on my PCB?"**
   - Agent will list all components and their positions

4. **Place/Move Components via EagilinsED:**
   - Ask: **"Move R1 to position 50, 30"**
   - Ask: **"Move U1 to position 100, 100"**
   - Ask: **"Rotate C1 by 90 degrees"**
   - After each command, run: **File → Run Script → `altium_execute_commands.pas` → `ExecuteCommands`**
   - Verify components move/rotate in PCB

5. **Add Components (if needed):**
   - Ask: **"Add a resistor R10 at position 150, 50"**
   - Run `ExecuteCommands` in Altium

6. **Manual Routing (Current Limitation):**
   - ⚠️ **Note:** Automatic routing via EagilinsED is not yet implemented
   - Use Altium Designer's routing tools:
     - **Route → Interactive Routing** (shortcut: `P`, `T`)
     - Click on pads to start routing
     - Click to place track segments
     - Right-click to finish route

7. **Add Tracks via EagilinsED (if coordinates known):**
   - Ask: **"Add a track from 50, 30 to 100, 30"**
   - Run `ExecuteCommands` in Altium

8. **Add Vias (if needed):**
   - Ask: **"Add a via at position 75, 50"**
   - Run `ExecuteCommands` in Altium

9. **Re-export PCB Info:**
   - After modifications, re-export: **File → Run Script → `altium_export_pcb_info.pas` → `ExportPCBInfo`**
   - Reconnect in EagilinsED to refresh data

**✅ Pass Criteria:**
- Components placed in logical positions
- Components can be moved/rotated via EagilinsED
- Tracks added (manually or via commands)
- PCB layout is functional

**📝 Notes:**
- PCB layout is progressing
- Ready for verification

---

### Phase 7: Verifying Your Board Design

**Purpose:** Run design rule checks and verify connectivity

**Steps:**

1. **Run Design Rule Check (DRC):**
   - In Altium Designer, make PCB document active
   - **File → Run Script → `altium_verification.pas` → `RunDRCAndExport`**
   - Wait for DRC to complete
   - Check `verification_report.json` is created

2. **View DRC Results via EagilinsED:**
   - In EagilinsED, reconnect
   - Ask: **"What design rule violations do I have?"** or **"Show me DRC errors"**
   - Agent will display violations (if any)

3. **Fix Violations (if any):**
   - Review violations in Altium Designer's **Messages** panel
   - Fix issues manually or via EagilinsED commands
   - Re-run DRC after fixes

4. **Run Electrical Rule Check (ERC):**
   - Switch to Schematic document
   - **File → Run Script → `altium_verification.pas` → `RunERCAndExport`**
   - Check for electrical errors

5. **Check Connectivity:**
   - Switch back to PCB document
   - **File → Run Script → `altium_verification.pas` → `CheckConnectivityAndExport`**
   - This creates `connectivity_report.json`

6. **View Connectivity via EagilinsED:**
   - In EagilinsED, reconnect
   - Ask: **"What nets are routed?"** or **"Show connectivity status"**
   - Agent will display connectivity information

**✅ Pass Criteria:**
- DRC runs without errors (or violations are fixed)
- ERC passes (or errors are fixed)
- Connectivity check completes
- Agent can display verification results

**📝 Notes:**
- Design is verified
- Ready for final touches

---

### Phase 8: Creating the PCB Drawing

**Purpose:** Add text, dimensions, and drawings to PCB

**Steps:**

1. **Add Text to PCB via EagilinsED:**
   - In EagilinsED, ask: **"Add text 'MyBoard v1.0' at position 50, 50"**
   - Run: **File → Run Script → `altium_pcb_drawing.pas` → `AddTextToPCB`**
   - Verify text appears on PCB

2. **Add More Text:**
   - Ask: **"Add text 'REV A' at position 50, 60"**
   - Run `AddTextToPCB` in Altium

3. **Add Lines (if needed):**
   - Ask: **"Add a line from 10, 10 to 20, 20"**
   - Run: **File → Run Script → `altium_pcb_drawing.pas` → `AddLineToPCB`**

4. **Add Rectangles (if needed):**
   - Ask: **"Add a rectangle from 5, 5 to 15, 15"**
   - Run: **File → Run Script → `altium_pcb_drawing.pas` → `AddRectangleToPCB`**

5. **Export Text Objects:**
   - **File → Run Script → `altium_pcb_drawing.pas` → `ExportTextObjects`**
   - This exports all text objects for reference

**✅ Pass Criteria:**
- Text added successfully
- Text is readable and positioned correctly
- Drawing elements added (if used)

**📝 Notes:**
- PCB drawing is complete
- Ready for manufacturing outputs

---

### Phase 9: Preparing Outputs and Releasing

**Purpose:** Generate manufacturing files (Gerber, BOM, Pick & Place)

**Steps:**

1. **Generate Bill of Materials (BOM):**
   - In Altium Designer, make PCB document active
   - **File → Run Script → `altium_output_generator.pas` → `GenerateBOM`**
   - Check `Output/` folder for BOM file
   - Verify BOM contains all components

2. **Generate Pick & Place File:**
   - **File → Run Script → `altium_output_generator.pas` → `GeneratePickAndPlace`**
   - Check `Output/` folder for Pick & Place file
   - Verify file contains component positions

3. **Generate Gerber Files:**
   - **File → Run Script → `altium_output_generator.pas` → `GenerateGerberFiles`**
   - Check `Output/` folder for Gerber files (.GTL, .GBL, .GTS, .GBS, etc.)
   - Verify all layer files are present

4. **Generate Drill Files:**
   - **File → Run Script → `altium_output_generator.pas` → `GenerateDrillFiles`**
   - Check `Output/` folder for drill files (.TXT, .DRR)

5. **Generate All Outputs (Alternative):**
   - **File → Run Script → `altium_output_generator.pas` → `GenerateAllOutputs`**
   - This generates all output files at once

6. **View Output Status via EagilinsED:**
   - In EagilinsED, reconnect
   - Ask: **"What outputs were generated?"** or **"Show output results"**
   - Agent will display output generation status

7. **Verify Output Files:**
   - Check `Output/` folder contains:
     - BOM file (.xlsx or .csv)
     - Pick & Place file (.txt or .csv)
     - Gerber files (.GTL, .GBL, .GTS, .GBS, .GTO, .GBO, etc.)
     - Drill files (.TXT, .DRR)
     - NC Drill files

**✅ Pass Criteria:**
- All output files generated successfully
- Files are in correct format
- Files contain expected data
- Agent can report output status

**📝 Notes:**
- ✅ **Congratulations!** Your complete PCB design workflow is finished!
- All files are ready for manufacturing
- Project is complete from schematic to outputs

---

## 🎓 Workflow Summary

**Complete Design Flow:**
```
Phase 1: Create Project & Schematic ✅
    ↓
Phase 2: Search & Acquire Components ✅
    ↓
Phase 3: Capture Schematic ✅
    ↓
Phase 4: Set Up Design Constraints ✅
    ↓
Phase 5: Configure PCB Document ✅
    ↓
Phase 6: Place Components & Route ✅
    ↓
Phase 7: Verify Design ✅
    ↓
Phase 8: Create PCB Drawing ✅
    ↓
Phase 9: Generate Outputs ✅
    ↓
🎉 PROJECT COMPLETE!
```

**If you complete all 9 phases, you have successfully:**
- ✅ Created a complete PCB project from scratch
- ✅ Used EagilinsED throughout the entire workflow
- ✅ Tested all major features
- ✅ Generated manufacturing-ready outputs

---

## 📤 Data Export Scripts Testing

### Test 1: Export PCB Information

**Purpose:** Export PCB data for agent to use

**Steps:**
1. In Altium Designer, make sure PCB document is active
2. Go to: **File → Run Script**
3. Select: `altium_export_pcb_info.pas`
4. Choose procedure: **`ExportPCBInfo`**
5. Click **OK**

**Expected Results:**
- ✅ Success message: "PCB Info Exported!"
- ✅ File created: `E:\Workspace\AI\11.10.WayNe\new-version\pcb_info.json`
- ✅ File size > 1 KB
- ✅ File contains JSON with "components", "nets", "layers" arrays

**Verification:**
```powershell
# Check file exists
Test-Path "E:\Workspace\AI\11.10.WayNe\new-version\pcb_info.json"

# Check file size
(Get-Item "E:\Workspace\AI\11.10.WayNe\new-version\pcb_info.json").Length
```

**✅ Pass Criteria:**
- File exists and is valid JSON
- Contains at least basic PCB information
- No error messages in Altium

---

### Test 2: Export Schematic Information

**Purpose:** Export schematic data for agent to use

**Steps:**
1. In Altium Designer, click on Schematic document tab to make it active
2. Go to: **File → Run Script**
3. Select: `altium_export_schematic_info.pas`
4. Choose procedure: **`ExportSchematicInfo`**
5. Click **OK**

**Expected Results:**
- ✅ Success message: "Schematic Info Exported!"
- ✅ File created: `E:\Workspace\AI\11.10.WayNe\new-version\schematic_info.json`
- ✅ File contains JSON with "components", "wires", "nets" arrays

**Verification:**
```powershell
Test-Path "E:\Workspace\AI\11.10.WayNe\new-version\schematic_info.json"
```

**✅ Pass Criteria:**
- File exists and is valid JSON
- Contains schematic component information
- No error messages

---

### Test 3: Export Project Information

**Purpose:** Export project structure for agent to use

**Steps:**
1. In Altium Designer, any document can be active
2. Go to: **File → Run Script**
3. Select: `altium_project_manager.pas`
4. Choose procedure: **`ExportProjectInfo`**
5. Click **OK**

**Expected Results:**
- ✅ Success message with project info
- ✅ File created: `E:\Workspace\AI\11.10.WayNe\new-version\project_info.json`
- ✅ File contains project name, documents list

**✅ Pass Criteria:**
- File exists and is valid JSON
- Contains project structure information

---

### Test 4: Export Design Rules

**Purpose:** Export design rules for agent queries

**Steps:**
1. In Altium Designer, open PCB document
2. Go to: **File → Run Script**
3. Select: `altium_design_rules.pas`
4. Choose procedure: **`ExportDesignRules`**
5. Click **OK**

**Expected Results:**
- ✅ Success message
- ✅ File created: `E:\Workspace\AI\11.10.WayNe\new-version\design_rules.json`
- ✅ File contains clearance rules, width rules, via rules

**✅ Pass Criteria:**
- File exists and is valid JSON
- Contains design rules information

---

### Test 5: Export Board Configuration

**Purpose:** Export board setup information

**Steps:**
1. In Altium Designer, open PCB document
2. Go to: **File → Run Script**
3. Select: `altium_pcb_setup.pas`
4. Choose procedure: **`ExportBoardConfig`**
5. Click **OK**

**Expected Results:**
- ✅ Success message
- ✅ File created: `E:\Workspace\AI\11.10.WayNe\new-version\board_config.json`
- ✅ File contains board size, layers, stackup

**✅ Pass Criteria:**
- File exists and is valid JSON
- Contains board configuration data

---

## 🔧 Modification Commands Testing

### Test 6: Connect to EagilinsED

**Purpose:** Establish connection with exported data

**Steps:**
1. In EagilinsED application, click **Connect** button
2. Wait for connection (loading spinner)
3. Check status message

**Expected Results:**
- ✅ Loading spinner appears
- ✅ Connection succeeds
- ✅ Status: "Successfully connected and loaded PCB info"
- ✅ Application navigates to agent chat page

**✅ Pass Criteria:**
- Connection successful
- No error messages
- Can see agent chat interface

---

### Test 7: PCB Modification - Move Component

**Purpose:** Test moving a component via natural language

**Steps:**
1. In EagilinsED chat, type: **"Move R1 to position 50, 30"**
   (Replace R1 with an actual component designator from your PCB)
2. Wait for agent response
3. Check `pcb_commands.json` file
4. In Altium Designer: **File → Run Script → `altium_execute_commands.pas` → `ExecuteCommands`**
5. Verify component moved in PCB

**Expected Results:**
- ✅ Agent responds: "✅ Got it! I've prepared the command..."
- ✅ `pcb_commands.json` contains move_component command
- ✅ Command executes successfully in Altium
- ✅ Component moves to new position
- ✅ Success message in Altium: "SUCCESS! 1 command(s) executed successfully"

**Verification:**
```powershell
# Check command file
Get-Content "E:\Workspace\AI\11.10.WayNe\new-version\pcb_commands.json" | ConvertFrom-Json
```

**✅ Pass Criteria:**
- Command queued correctly
- Command executes without errors
- Component actually moves in PCB

---

### Test 8: PCB Modification - Rotate Component

**Steps:**
1. In EagilinsED chat: **"Rotate U1 by 90 degrees"**
2. Run `ExecuteCommands` in Altium
3. Verify component rotated

**Expected Results:**
- ✅ Command queued
- ✅ Component rotates in PCB
- ✅ Rotation angle correct

**✅ Pass Criteria:**
- Component rotates correctly
- No errors

---

### Test 9: PCB Modification - Add Component

**Steps:**
1. In EagilinsED chat: **"Add a resistor R200 at position 100, 50"**
2. Run `ExecuteCommands` in Altium
3. Verify component added

**Expected Results:**
- ✅ Command queued
- ✅ Component added to PCB
- ✅ Component has correct designator (R200)

**✅ Pass Criteria:**
- Component appears in PCB
- Designator is correct
- Position is correct

---

### Test 10: PCB Modification - Change Component Value

**Steps:**
1. In EagilinsED chat: **"Change the value of R1 to 10k"**
2. Run `ExecuteCommands` in Altium
3. Verify value changed

**Expected Results:**
- ✅ Command queued
- ✅ Component value parameter updated
- ✅ Value visible in PCB

**✅ Pass Criteria:**
- Value parameter updated correctly

---

### Test 11: Schematic Modification - Place Component

**Purpose:** Test placing component in schematic

**Steps:**
1. In EagilinsED chat: **"Place a resistor R1 at position 50, 30"**
2. Check `schematic_commands.json`
3. In Altium Designer, make Schematic document active
4. Run: **File → Run Script → `altium_schematic_modify.pas` → `ExecuteSchematicCommands`**
5. Verify component placed

**Expected Results:**
- ✅ Agent responds with schematic script guidance
- ✅ `schematic_commands.json` contains place_component command
- ✅ Component placed in schematic
- ✅ Component has correct designator

**Verification:**
```powershell
Get-Content "E:\Workspace\AI\11.10.WayNe\new-version\schematic_commands.json" | ConvertFrom-Json
```

**✅ Pass Criteria:**
- Command queued to schematic_commands.json
- Component appears in schematic
- Designator is correct

---

### Test 12: Schematic Modification - Add Wire

**Steps:**
1. In EagilinsED chat: **"Add a wire from 10, 20 to 30, 20"**
2. Run `ExecuteSchematicCommands` in Altium
3. Verify wire added

**Expected Results:**
- ✅ Wire appears in schematic
- ✅ Wire connects specified points

**✅ Pass Criteria:**
- Wire visible in schematic
- Coordinates correct

---

### Test 13: Schematic Modification - Add Net Label

**Steps:**
1. In EagilinsED chat: **"Add net label VCC at position 50, 50"**
2. Run `ExecuteSchematicCommands` in Altium
3. Verify net label added

**Expected Results:**
- ✅ Net label appears
- ✅ Label text is "VCC"
- ✅ Position correct

**✅ Pass Criteria:**
- Net label visible
- Text and position correct

---

### Test 14: Schematic Modification - Add Power Port

**Steps:**
1. In EagilinsED chat: **"Add VCC power port at 10, 10"**
2. Run `ExecuteSchematicCommands` in Altium
3. Verify power port added

**Expected Results:**
- ✅ Power port appears
- ✅ Port name is "VCC"
- ✅ Position correct

**✅ Pass Criteria:**
- Power port visible
- Name and position correct

---

## 🧠 Agent Intelligence Testing

### Test 15: PCB Questions

**Purpose:** Test agent using PCB data

**Test Queries:**
1. **"What components are on the PCB?"**
   - **Expected:** Agent lists component designators from PCB

2. **"Where is R1 located?"**
   - **Expected:** Agent provides X, Y coordinates in mm

3. **"What is the board size?"**
   - **Expected:** Agent provides width x height in mm

4. **"How many nets are there?"**
   - **Expected:** Agent provides net count

5. **"List all resistors"**
   - **Expected:** Agent lists all components starting with "R"

**✅ Pass Criteria:**
- Agent answers using actual PCB data
- Answers are accurate
- No "I don't have access" messages

---

### Test 16: Schematic Questions

**Purpose:** Test agent using schematic data

**Prerequisites:** Run `ExportSchematicInfo` first

**Test Queries:**
1. **"What components are in the schematic?"**
   - **Expected:** Agent lists schematic components

2. **"Show me the power ports"**
   - **Expected:** Agent lists power ports from schematic

3. **"What nets are in the schematic?"**
   - **Expected:** Agent lists nets from schematic

**✅ Pass Criteria:**
- Agent uses schematic data
- Answers are accurate
- No errors

---

### Test 17: Project Questions

**Purpose:** Test agent using project data

**Prerequisites:** Run `ExportProjectInfo` first

**Test Queries:**
1. **"What files are in the project?"**
   - **Expected:** Agent lists project documents

2. **"How many schematics are there?"**
   - **Expected:** Agent provides schematic count

**✅ Pass Criteria:**
- Agent uses project data
- Answers are accurate

---

### Test 18: Design Rules Questions

**Purpose:** Test agent using design rules data

**Prerequisites:** Run `ExportDesignRules` first

**Test Queries:**
1. **"What are the design rules?"**
   - **Expected:** Agent summarizes design rules

2. **"What is the minimum clearance?"**
   - **Expected:** Agent provides clearance value

3. **"What is the track width?"**
   - **Expected:** Agent provides width rules

**✅ Pass Criteria:**
- Agent uses design rules data
- Answers are accurate

---

### Test 19: Board Configuration Questions

**Purpose:** Test agent using board config data

**Prerequisites:** Run `ExportBoardConfig` first

**Test Queries:**
1. **"What is the board size?"**
   - **Expected:** Agent provides dimensions

2. **"How many layers does the board have?"**
   - **Expected:** Agent provides layer count

3. **"What is the layer stackup?"**
   - **Expected:** Agent describes layer stackup

**✅ Pass Criteria:**
- Agent uses board config data
- Answers are accurate

---

## 🔍 Component Search Testing

### Test 20: Component Search Guidance

**Purpose:** Test agent guiding user to search

**Steps:**
1. In EagilinsED chat: **"Find a 10k resistor"**
2. Check agent response

**Expected Results:**
- ✅ Agent provides step-by-step instructions
- ✅ Instructions mention `altium_component_search.pas`
- ✅ Instructions mention `SearchComponents` procedure
- ✅ Clear guidance on what to do next

**✅ Pass Criteria:**
- Instructions are clear and complete
- User knows exactly what to do

---

### Test 21: Run Component Search

**Purpose:** Execute component search in Altium

**Steps:**
1. In Altium Designer: **File → Run Script**
2. Select: `altium_component_search.pas`
3. Choose: **`SearchComponents`**
4. Enter search term: **"resistor"** (or any component name)
5. Click **OK**

**Expected Results:**
- ✅ Input dialog appears
- ✅ Search executes
- ✅ Success message: "Component Search Complete!"
- ✅ File created: `component_search.json`
- ✅ File contains search results

**Verification:**
```powershell
Get-Content "E:\Workspace\AI\11.10.WayNe\new-version\component_search.json" | ConvertFrom-Json
```

**✅ Pass Criteria:**
- Search completes without errors
- Results file created
- Results contain component information

---

### Test 22: View Search Results

**Purpose:** Test agent displaying search results

**Steps:**
1. After running search (Test 21)
2. In EagilinsED, reconnect or refresh
3. Ask: **"What did you find?"** or **"Show me the search results"**

**Expected Results:**
- ✅ Agent displays search results
- ✅ Shows component names
- ✅ Shows library names
- ✅ Shows descriptions
- ✅ Lists multiple results if available

**✅ Pass Criteria:**
- Agent displays actual search results
- Information is accurate
- Results are readable

---

### Test 23: Place Component from Search

**Purpose:** Test placing component using search results

**Steps:**
1. After search (Test 21) and viewing results (Test 22)
2. In EagilinsED chat: **"Place Res2 from the search results at position 50, 30"**
3. Check `schematic_commands.json`
4. Run `ExecuteSchematicCommands` in Altium
5. Verify component placed

**Expected Results:**
- ✅ Agent extracts library information from search
- ✅ Command queued with correct library reference
- ✅ Component placed in schematic
- ✅ Component uses correct library

**✅ Pass Criteria:**
- Command includes library information
- Component placed successfully
- Library reference is correct

---

### Test 24: List Libraries

**Purpose:** Test listing installed libraries

**Steps:**
1. In Altium Designer: **File → Run Script**
2. Select: `altium_component_search.pas`
3. Choose: **`ListInstalledLibraries`**
4. Click **OK**

**Expected Results:**
- ✅ Success message with library count
- ✅ File created: `library_list.json`
- ✅ File contains list of libraries

**✅ Pass Criteria:**
- Libraries listed successfully
- File created correctly

---

## ✅ Verification & Output Testing

### Test 25: Run Design Rule Check (DRC)

**Purpose:** Test DRC verification

**Steps:**
1. In Altium Designer, open PCB document
2. **File → Run Script → `altium_verification.pas` → `RunDRCAndExport`**
3. Check results

**Expected Results:**
- ✅ DRC runs
- ✅ File created: `verification_report.json`
- ✅ Report contains violations (if any)

**✅ Pass Criteria:**
- DRC completes
- Report file created
- Can query violations in EagilinsED

---

### Test 26: Run Electrical Rule Check (ERC)

**Purpose:** Test ERC verification

**Steps:**
1. In Altium Designer, open Schematic document
2. **File → Run Script → `altium_verification.pas` → `RunERCAndExport`**
3. Check results

**Expected Results:**
- ✅ ERC runs
- ✅ File created: `verification_report.json`
- ✅ Report contains errors/warnings

**✅ Pass Criteria:**
- ERC completes
- Report file created

---

### Test 27: Check Connectivity

**Purpose:** Test connectivity check

**Steps:**
1. In Altium Designer, open PCB document
2. **File → Run Script → `altium_verification.pas` → `CheckConnectivityAndExport`**
3. Check results

**Expected Results:**
- ✅ Connectivity check runs
- ✅ File created: `connectivity_report.json`
- ✅ Report shows routed/unrouted nets

**✅ Pass Criteria:**
- Check completes
- Report file created

---

### Test 28: Generate BOM

**Purpose:** Test Bill of Materials generation

**Steps:**
1. In Altium Designer, open PCB document
2. **File → Run Script → `altium_output_generator.pas` → `GenerateBOM`**
3. Check output folder

**Expected Results:**
- ✅ BOM generated
- ✅ File created in `Output/` folder
- ✅ File contains component list

**✅ Pass Criteria:**
- BOM file created
- Contains component information

---

### Test 29: Generate Pick & Place

**Purpose:** Test Pick & Place file generation

**Steps:**
1. In Altium Designer, open PCB document
2. **File → Run Script → `altium_output_generator.pas` → `GeneratePickAndPlace`**
3. Check output folder

**Expected Results:**
- ✅ Pick & Place file generated
- ✅ File contains component positions

**✅ Pass Criteria:**
- File created
- Contains position data

---

### Test 30: Generate Gerber Files

**Purpose:** Test Gerber file generation

**Steps:**
1. In Altium Designer, open PCB document
2. **File → Run Script → `altium_output_generator.pas` → `GenerateGerberFiles`**
3. Check output folder

**Expected Results:**
- ✅ Gerber files generated
- ✅ Multiple .GTL, .GBL, .GTS, .GBS files created

**✅ Pass Criteria:**
- Gerber files created
- Files are valid

---

## 🎯 Advanced Features Testing

### Test 31: Multi-Context Query

**Purpose:** Test agent using multiple data sources

**Prerequisites:** Export PCB, Schematic, Project, Design Rules, Board Config

**Test Query:**
**"Give me a summary of my design"**

**Expected Results:**
- ✅ Agent provides comprehensive summary
- ✅ Includes PCB information
- ✅ Includes schematic information
- ✅ Includes project information
- ✅ Includes design rules
- ✅ Includes board configuration

**✅ Pass Criteria:**
- Agent uses all available data
- Summary is comprehensive
- No missing information

---

### Test 32: Complex Modification

**Purpose:** Test multiple commands in sequence

**Steps:**
1. Ask: **"Move R1 to 50, 30 and rotate U1 by 90 degrees"**
2. Check `pcb_commands.json` contains both commands
3. Run `ExecuteCommands` in Altium
4. Verify both modifications applied

**Expected Results:**
- ✅ Multiple commands queued
- ✅ Both commands execute
- ✅ Both modifications applied

**✅ Pass Criteria:**
- Multiple commands work
- All modifications applied

---

### Test 33: Error Handling - Invalid Component

**Purpose:** Test error handling for invalid requests

**Steps:**
1. Ask: **"Move XYZ999 to 50, 30"** (non-existent component)
2. Run `ExecuteCommands` in Altium
3. Check error message

**Expected Results:**
- ✅ Command queued (agent doesn't validate)
- ✅ Altium shows error or partial success message
- ✅ Error message is clear

**✅ Pass Criteria:**
- Error handled gracefully
- User informed of issue

---

### Test 34: Master Menu Script

**Purpose:** Test quick access menu

**Steps:**
1. In Altium Designer: **File → Run Script**
2. Select: `altium_master.pas`
3. Choose: **`ShowMainMenu`**
4. Select an option from menu

**Expected Results:**
- ✅ Menu appears
- ✅ Options are clear
- ✅ Guidance provided for each option

**✅ Pass Criteria:**
- Menu works
- Options are useful

---

## 🔧 Troubleshooting

### Issue: Can't Connect to EagilinsED

**Symptoms:**
- Connection fails
- "PCB info file not found" error

**Solutions:**
1. ✅ Run `ExportPCBInfo` in Altium first
2. ✅ Check `pcb_info.json` exists and is valid
3. ✅ Verify file path is correct
4. ✅ Check MCP server is running
5. ✅ Restart EagilinsED application

---

### Issue: Commands Not Executing

**Symptoms:**
- Command queued but nothing happens
- No success message in Altium

**Solutions:**
1. ✅ Check command file exists (`pcb_commands.json` or `schematic_commands.json`)
2. ✅ Verify JSON is valid (no syntax errors)
3. ✅ Make sure correct document is active (PCB for PCB commands, Schematic for schematic commands)
4. ✅ Check Altium error messages
5. ✅ Verify component designators are correct (case-sensitive)

---

### Issue: Agent Says "No Data Available"

**Symptoms:**
- Agent can't answer questions
- "No data available" messages

**Solutions:**
1. ✅ Export the relevant data type first
2. ✅ Reconnect in EagilinsED to refresh data
3. ✅ Check JSON files exist and are valid
4. ✅ Verify file paths are correct

---

### Issue: Component Not Placed Correctly

**Symptoms:**
- Component placed but wrong designator
- Component not visible

**Solutions:**
1. ✅ Check library reference is correct
2. ✅ Verify component exists in library
3. ✅ Check coordinates are reasonable
4. ✅ Ensure schematic/PCB is active
5. ✅ Check Altium error messages

---

### Issue: Search Results Not Showing

**Symptoms:**
- Agent doesn't show search results
- "No search results" message

**Solutions:**
1. ✅ Run `SearchComponents` in Altium first
2. ✅ Check `component_search.json` exists
3. ✅ Reconnect in EagilinsED
4. ✅ Verify JSON is valid

---

## 📊 Test Results Template

```
═══════════════════════════════════════════════════════════════
EagilinsED Comprehensive Test Results
═══════════════════════════════════════════════════════════════

Date: ________________
Tester: ______________
Altium Version: _______
Python Version: _______

═══════════════════════════════════════════════════════════════
SETUP & PREREQUISITES
═══════════════════════════════════════════════════════════════

[ ] MCP Server starts successfully
[ ] EagilinsED application starts
[ ] Altium Designer opens project
[ ] All required files exist

═══════════════════════════════════════════════════════════════
COMPLETE DESIGN WORKFLOW (Phases 1-9)
═══════════════════════════════════════════════════════════════

Phase 1 - Create Project & Schematic:    [ ] PASS  [ ] FAIL  Notes: ________
Phase 2 - Search & Acquire Components:   [ ] PASS  [ ] FAIL  Notes: ________
Phase 3 - Capture Schematic:             [ ] PASS  [ ] FAIL  Notes: ________
Phase 4 - Set Up Design Constraints:     [ ] PASS  [ ] FAIL  Notes: ________
Phase 5 - Configure PCB Document:        [ ] PASS  [ ] FAIL  Notes: ________
Phase 6 - Place Components & Route:     [ ] PASS  [ ] FAIL  Notes: ________
Phase 7 - Verify Board Design:           [ ] PASS  [ ] FAIL  Notes: ________
Phase 8 - Create PCB Drawing:            [ ] PASS  [ ] FAIL  Notes: ________
Phase 9 - Generate Outputs:              [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
DATA EXPORT SCRIPTS (Tests 1-5)
═══════════════════════════════════════════════════════════════

Test 1 - Export PCB Info:        [ ] PASS  [ ] FAIL  Notes: ________
Test 2 - Export Schematic Info:   [ ] PASS  [ ] FAIL  Notes: ________
Test 3 - Export Project Info:     [ ] PASS  [ ] FAIL  Notes: ________
Test 4 - Export Design Rules:     [ ] PASS  [ ] FAIL  Notes: ________
Test 5 - Export Board Config:     [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
CONNECTION (Test 6)
═══════════════════════════════════════════════════════════════

Test 6 - Connect to EagilinsED:   [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
PCB MODIFICATIONS (Tests 7-10)
═══════════════════════════════════════════════════════════════

Test 7 - Move Component:          [ ] PASS  [ ] FAIL  Notes: ________
Test 8 - Rotate Component:        [ ] PASS  [ ] FAIL  Notes: ________
Test 9 - Add Component:           [ ] PASS  [ ] FAIL  Notes: ________
Test 10 - Change Value:            [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
SCHEMATIC MODIFICATIONS (Tests 11-14)
═══════════════════════════════════════════════════════════════

Test 11 - Place Component:        [ ] PASS  [ ] FAIL  Notes: ________
Test 12 - Add Wire:               [ ] PASS  [ ] FAIL  Notes: ________
Test 13 - Add Net Label:          [ ] PASS  [ ] FAIL  Notes: ________
Test 14 - Add Power Port:          [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
AGENT INTELLIGENCE (Tests 15-19)
═══════════════════════════════════════════════════════════════

Test 15 - PCB Questions:          [ ] PASS  [ ] FAIL  Notes: ________
Test 16 - Schematic Questions:    [ ] PASS  [ ] FAIL  Notes: ________
Test 17 - Project Questions:     [ ] PASS  [ ] FAIL  Notes: ________
Test 18 - Design Rules Questions: [ ] PASS  [ ] FAIL  Notes: ________
Test 19 - Board Config Questions: [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
COMPONENT SEARCH (Tests 20-24)
═══════════════════════════════════════════════════════════════

Test 20 - Search Guidance:        [ ] PASS  [ ] FAIL  Notes: ________
Test 21 - Run Search:             [ ] PASS  [ ] FAIL  Notes: ________
Test 22 - View Results:           [ ] PASS  [ ] FAIL  Notes: ________
Test 23 - Place from Search:     [ ] PASS  [ ] FAIL  Notes: ________
Test 24 - List Libraries:        [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
VERIFICATION & OUTPUTS (Tests 25-30)
═══════════════════════════════════════════════════════════════

Test 25 - Run DRC:                [ ] PASS  [ ] FAIL  Notes: ________
Test 26 - Run ERC:                [ ] PASS  [ ] FAIL  Notes: ________
Test 27 - Check Connectivity:    [ ] PASS  [ ] FAIL  Notes: ________
Test 28 - Generate BOM:           [ ] PASS  [ ] FAIL  Notes: ________
Test 29 - Generate Pick & Place:  [ ] PASS  [ ] FAIL  Notes: ________
Test 30 - Generate Gerber:        [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
ADVANCED FEATURES (Tests 31-34)
═══════════════════════════════════════════════════════════════

Test 31 - Multi-Context Query:    [ ] PASS  [ ] FAIL  Notes: ________
Test 32 - Complex Modification:   [ ] PASS  [ ] FAIL  Notes: ________
Test 33 - Error Handling:         [ ] PASS  [ ] FAIL  Notes: ________
Test 34 - Master Menu:            [ ] PASS  [ ] FAIL  Notes: ________

═══════════════════════════════════════════════════════════════
SUMMARY
═══════════════════════════════════════════════════════════════

Total Tests: 43 (9 Phases + 34 Feature Tests)
Passed: _____
Failed: _____
Pass Rate: _____%

Workflow Completion:
[ ] Complete (All 9 phases finished)
[ ] Partial (Phases _____ completed)
[ ] Not Started

Issues Found:
1. _____________________________________________________________
2. _____________________________________________________________
3. _____________________________________________________________

Overall Assessment:
[ ] Excellent - All features working
[ ] Good - Minor issues
[ ] Fair - Some issues need fixing
[ ] Poor - Major issues

Additional Notes:
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________

═══════════════════════════════════════════════════════════════
```

---

## ✅ Success Criteria

**All tests pass if:**
1. ✅ All export scripts create valid JSON files
2. ✅ Connection to EagilinsED succeeds
3. ✅ PCB modifications execute correctly
4. ✅ Schematic modifications execute correctly
5. ✅ Agent answers questions using correct data
6. ✅ Component search workflow functions
7. ✅ Verification scripts run successfully
8. ✅ Output generation works
9. ✅ Error handling is graceful
10. ✅ All features integrate seamlessly

---

## 🎯 Testing Tips

1. **Test in order** - Follow test sequence for best results
2. **Export data first** - Always export data before testing agent queries
3. **Use real component names** - Use actual designators from your PCB
4. **Check JSON files** - Verify JSON files are valid after export
5. **Reconnect after exports** - Reconnect in EagilinsED to refresh data
6. **Check Altium messages** - Look for error messages in Altium dialogs
7. **Test one feature at a time** - Don't mix test scenarios
8. **Document issues** - Note any problems for fixing

---

**Good luck with testing! 🚀**


