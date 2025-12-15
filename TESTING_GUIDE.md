# EagilinsED - Complete Testing Guide

This guide walks you through testing all features of the EagilinsED PCB Design Assistant.

---

## 🚀 Prerequisites

1. **Altium Designer 25.5.2+** running with a project open
2. **Python virtual environment** activated
3. **OpenAI API key** configured in `.env` file

---

## 📋 Test Setup

### Step 1: Start the MCP Server
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py
```
You should see:
```
============================================================
Altium Designer MCP Server (File-Based)
============================================================
Server running on http://localhost:8080
```

### Step 2: Start the Application
In a new terminal:
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python main.py
```
The EagilinsED application window should appear.

### Step 3: Open Script Project in Altium
1. In Altium: **File → Open**
2. Navigate to: `E:\Workspace\AI\11.10.WayNe\new-version\altium_scripts\`
3. Open: `Scripts_Project.PrjScr`

---

## 🧪 Test 1: PCB Document Mode

### 1.1 Export PCB Data
1. In Altium: Open your PCB document (`.PcbDoc`)
2. Click on the PCB tab to make it active
3. Run script: `altium_export_pcb_info.pas` → `ExportPCBInfo`
4. You should see a success message with component/net counts

### 1.2 Connect Application
1. In EagilinsED app: Select **"PCB Document"** from dropdown
2. Click **Connect**
3. Wait for "Connected to PCB Document!" message

### 1.3 Test PCB Queries
Try these queries in the chat:

| Query | Expected Result |
|-------|-----------------|
| "What is the board size?" | Shows width x height in mm |
| "How many components are there?" | Shows component count |
| "List all resistors" | Lists components starting with R |
| "Where is R1 located?" | Shows X, Y coordinates |
| "What is the value of C1?" | Shows component value |
| "How many layers?" | Shows layer count |
| "What nets are on the board?" | Lists net names |

### 1.4 Test PCB Modifications
Try these modification commands:

| Command | Expected Result |
|---------|-----------------|
| "Move R1 to position 50, 60" | Command queued message |
| "Rotate C1 by 90 degrees" | Command queued message |
| "Add resistor R999 at 80, 70" | Command queued message |

After each command:
1. Run script: `altium_execute_commands.pas` → `ExecuteCommands`
2. Verify the change in Altium Designer

---

## 🧪 Test 2: Schematic Mode

### 2.1 Export Schematic Data
1. In Altium: Open your schematic document (`.SchDoc`)
2. Click on the schematic tab to make it active
3. Run script: `altium_export_schematic_info.pas` → `ExportSchematicInfo`
4. You should see a success message with component/wire counts

### 2.2 Connect Application
1. In EagilinsED app: Select **"Schematic"** from dropdown
2. Click **Connect**
3. Wait for connection (may need to run export script first)

### 2.3 Test Schematic Queries
Try these queries:

| Query | Expected Result |
|-------|-----------------|
| "List all components" | Shows component designators |
| "What components are in the schematic?" | Lists components with values |
| "How many wires are there?" | Shows wire count |
| "What power ports are used?" | Lists VCC, GND, etc. |
| "Show net labels" | Lists all net label names |

---

## 🧪 Test 3: Project Overview Mode

### 3.1 Export Project Data
1. In Altium: Have any project open
2. Run script: `altium_project_manager.pas` → `ExportProjectInfo`
3. You should see project document list

### 3.2 Connect Application
1. In EagilinsED app: Select **"Project Overview"** from dropdown
2. Click **Connect**

### 3.3 Test Project Queries
Try these queries:

| Query | Expected Result |
|-------|-----------------|
| "What files are in this project?" | Lists all documents |
| "How many schematics?" | Shows schematic count |
| "How many PCBs?" | Shows PCB count |

---

## 🧪 Test 4: Design Verification (DRC/ERC)

### 4.1 Run DRC on PCB
1. In Altium: Open a PCB document
2. Run script: `altium_verification.pas` → `RunDRCAndExport`
3. Check the result message (PASS or violations found)

### 4.2 Run ERC on Schematic
1. In Altium: Open a schematic document
2. Run script: `altium_verification.pas` → `RunERCAndExport`
3. Check the result message

### 4.3 Check Connectivity
1. In Altium: Open a PCB document
2. Run script: `altium_verification.pas` → `CheckConnectivityAndExport`
3. See routed vs unrouted nets

### 4.4 Query Verification Results
After running verification, ask in the app:

| Query | Expected Result |
|-------|-----------------|
| "Are there any DRC errors?" | Shows violation count |
| "What nets are unrouted?" | Lists unrouted nets |

---

## 🧪 Test 5: Manufacturing Outputs

### 5.1 Generate BOM
1. In Altium: Open a PCB document
2. Run script: `altium_output_generator.pas` → `GenerateBOM`
3. Check output folder: `E:\Workspace\AI\11.10.WayNe\new-version\Output\BOM\`
4. Files created: `BOM.csv`, `BOM.json`

### 5.2 Generate Pick and Place
1. Run script: `altium_output_generator.pas` → `GeneratePickAndPlace`
2. Check output folder: `E:\Workspace\AI\11.10.WayNe\new-version\Output\Assembly\`
3. Files created: `PickAndPlace.csv`, `PickAndPlace.json`

### 5.3 Verify Output Files
Open the generated files to verify:
- CSV files should be comma-separated with headers
- JSON files should contain component data

---

## 📊 Test Checklist

Use this checklist to track your testing:

```
[ ] Server starts without errors
[ ] Application launches correctly
[ ] Document type dropdown works
[ ] 
PCB Mode:
[ ] PCB export script runs successfully
[ ] Connection to PCB works
[ ] Board size query works
[ ] Component location query works
[ ] Component list query works
[ ] Move command queues correctly
[ ] Execute script applies changes

Schematic Mode:
[ ] Schematic export script runs successfully
[ ] Connection to Schematic works
[ ] Component list query works
[ ] Net label query works

Project Mode:
[ ] Project export script runs successfully
[ ] Document list query works

Verification:
[ ] DRC runs and exports results
[ ] ERC runs and exports results
[ ] Connectivity check works

Outputs:
[ ] BOM generates CSV and JSON
[ ] Pick & Place generates CSV and JSON
```

---

## ❗ Troubleshooting

### "Connection failed"
- Ensure MCP server is running
- Verify the export script was run in Altium
- Check that the correct document type is selected

### "No PCB info available"
- Make sure a PCB document is active in Altium (click on the tab)
- Re-run the export script
- Check `pcb_info.json` exists in the project folder

### "Script error in Altium"
- Ensure the document is open and active
- Check the Altium Messages panel for details
- Verify file paths in the script match your setup

### "LLM client not available"
- Check your `.env` file has valid `OPENAI_API_KEY`
- Verify internet connection

---

## 🎉 Testing Complete!

If all tests pass, your EagilinsED installation is working correctly!

Next steps:
- Try with your real project files
- Explore natural language queries
- Report any issues for improvement

---

*EagilinsED - Full PCB Design Lifecycle Assistant* 🚀

