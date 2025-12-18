# EagilinsED - Complete Testing Guide

## Overview

EagilinsED is an AI-powered PCB design co-pilot that autonomously generates PCB layouts from schematics. This guide covers complete testing of all features.

---

## Prerequisites

### Software Requirements
- Windows 10/11
- Python 3.11+
- Altium Designer 25.x
- OpenAI API key (GPT-4)

### Environment Setup

```powershell
# Navigate to project
cd E:\Workspace\AI\11.10.WayNe\new-version

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Verify dependencies
pip install -r requirements.txt
```

### Configuration

Create `.env` file in project root:
```
OPENAI_API_KEY=your-openai-api-key
```

---

## Part 1: Server Setup

### Step 1.1: Start MCP Server

```powershell
# Terminal 1
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py
```

**Expected Output:**
```
MCP Server (File-Based) starting on http://localhost:5000
```

### Step 1.2: Verify Server

```powershell
# Terminal 2 (new terminal)
curl http://localhost:5000/health
```

**Expected Response:**
```json
{"status": "ok", "server": "file-based-mcp"}
```

---

## Part 2: Application Launch

### Step 2.1: Start Application

```powershell
# Terminal 2
.\venv\Scripts\Activate.ps1
python main.py
```

**Expected:** Application window opens with Welcome page

### Step 2.2: Welcome Page Test

| Element | Expected |
|---------|----------|
| Title | "EagilinsED" (large text) |
| Subtitle | "PCB Design Assistant" |
| Logo | PCB motherboard image |
| Button | "Connect" button (blue) |

### Step 2.3: Connect to Server

1. Click **Connect** button
2. Wait for connection (spinner animation)

**Expected:** 
- Status changes to "Connected successfully!"
- Automatically moves to Project Setup page

**If connection fails:**
- Check MCP server is running (Terminal 1)
- Check port 5000 is not blocked
- Error message will display

---

## Part 3: Project Setup

### Step 3.1: Project Setup Page

After connection, you'll see two options:
- **Existing Project** - Use an existing schematic/PCB
- **New Project** - Start from scratch

### Step 3.2: Test Existing Project Flow

1. Click **Existing Project** card
2. Read instructions panel
3. **In Altium Designer:**
   - Open your project
   - File → Run Script
   - Run `altium_export_schematic_info.pas` → `ExportSchematicInfo`
   - Run `altium_export_pcb_info.pas` → `ExportPCBInfo`
4. Click **Continue**

### Step 3.3: Test New Project Flow

1. Click **New Project** card
2. Read instructions panel
3. Click **Continue**
4. Use natural language to create project

---

## Part 4: Agent Chat Interface

### Step 4.1: Guidelines Page

After project setup:
- Read the quick tips
- Click **Continue** to enter agent chat

### Step 4.2: Chat Interface Elements

| Element | Location |
|---------|----------|
| Chat history | Main area |
| Input field | Bottom |
| Send button | Bottom right |
| Clear button | Top right |

---

## Part 5: Core Feature Testing

### Test 5.1: Design Analysis

**Input:**
```
Analyze this schematic and identify the functional blocks
```

**Expected Response:**
- Identifies functional blocks (Power, MCU, Interface, etc.)
- Lists components in each block
- Shows critical components
- Provides placement considerations

### Test 5.2: Placement Strategy

**Input:**
```
Generate a placement strategy for this design
```

**Expected Response:**
- Board zone recommendations
- Placement order/priorities
- Critical spacing requirements
- Routing priorities

### Test 5.3: Design Review

**Input:**
```
Review this design for potential issues
```

**Expected Response:**
- Lists warnings/errors found
- Missing decoupling capacitors
- ESD protection gaps
- Recommendations for each issue
- Overall design health score

### Test 5.4: Autonomous Layout Generation (KEY FEATURE)

**Input:**
```
Generate a layout for this design
```

**Expected Response:**
- Layout summary (component count, board size)
- Functional block placement breakdown
- Generated files location
- Instructions to apply layout in Altium

**Generated File:**
- `altium_scripts/batch_placement.pas`

---

## Part 6: Altium Integration Testing

### Test 6.1: Export Schematic Data

1. Open Altium Designer
2. Open a schematic document
3. File → Run Script
4. Navigate to `altium_scripts/`
5. Select `altium_export_schematic_info.pas`
6. Run `ExportSchematicInfo`

**Expected:** 
- `schematic_info.json` created in project folder
- Message: "Schematic info exported successfully"

### Test 6.2: Export PCB Data

1. Open a PCB document in Altium
2. File → Run Script
3. Select `altium_export_pcb_info.pas`
4. Run `ExportPCBInfo`

**Expected:**
- `pcb_info.json` created in project folder
- Message: "PCB info exported successfully"

### Test 6.3: Apply Generated Layout

1. Generate layout using agent (Test 5.4)
2. Open PCB document in Altium
3. File → Run Script
4. Select `batch_placement.pas`
5. Run `ExecuteBatchPlacement`

**Expected:**
- All components move to calculated positions
- Message: "Batch placement complete. X components placed."

### Test 6.4: Apply Design Rules

1. Open PCB document
2. File → Run Script
3. Select script generated by constraint generator
4. Run `CreateDesignRules`

**Expected:**
- Design rules created in Altium
- Net classes defined

---

## Part 7: Natural Language Commands

### Question Commands (Information)

| Command | Expected Behavior |
|---------|------------------|
| "What components are in this design?" | Lists all components |
| "Show me the power nets" | Lists power-related nets |
| "What's the board size?" | Shows board dimensions |
| "How many layers?" | Shows layer count |
| "List all ICs" | Shows integrated circuits |

### Analysis Commands

| Command | Expected Behavior |
|---------|------------------|
| "Analyze the schematic" | Functional block analysis |
| "Identify high-speed signals" | Signal classification |
| "What's the design type?" | MCU/FPGA/Power/RF detection |
| "Find critical components" | Components needing special attention |

### Strategy Commands

| Command | Expected Behavior |
|---------|------------------|
| "Generate placement strategy" | Zone-based placement plan |
| "How should I place the power section?" | Power-specific guidance |
| "Suggest board zones" | Block-to-zone mapping |
| "What constraints are needed?" | Design rule suggestions |

### Layout Generation Commands

| Command | Expected Behavior |
|---------|------------------|
| "Generate layout" | Full autonomous layout |
| "Create initial placement" | Component placement generation |
| "Auto-place the board" | Batch placement script |
| "Place all components" | Same as above |

### Review Commands

| Command | Expected Behavior |
|---------|------------------|
| "Review this design" | Design health check |
| "Are there any issues?" | Problem identification |
| "What's missing?" | Missing component detection |
| "Check for errors" | Validation report |

---

## Part 8: End-to-End Workflow Test

### Complete Workflow: Schematic → PCB Layout

1. **Start Application**
   ```powershell
   python mcp_server_file_based.py  # Terminal 1
   python main.py                    # Terminal 2
   ```

2. **Connect**
   - Click Connect on Welcome page

3. **Setup Project**
   - Select "Existing Project"
   - Export data from Altium (schematic + PCB)
   - Click Continue

4. **Analyze Design**
   ```
   "Analyze this schematic and identify functional blocks"
   ```

5. **Review Design**
   ```
   "Review this design for issues"
   ```

6. **Generate Layout**
   ```
   "Generate a layout for this design"
   ```

7. **Apply in Altium**
   - File → Run Script
   - Run `batch_placement.pas` → `ExecuteBatchPlacement`

8. **Verify Placement**
   - Check component positions
   - Verify functional block grouping
   - Review zone assignments

---

## Part 9: Troubleshooting

### Connection Issues

| Problem | Solution |
|---------|----------|
| "Cannot connect to MCP server" | Ensure server is running on port 5000 |
| Connection timeout | Check firewall settings |
| Proxy errors | Server bypasses proxy automatically |

### Altium Script Errors

| Problem | Solution |
|---------|----------|
| "No PCB document open" | Open a PCB file first |
| "No schematic document open" | Open a schematic first |
| Script not found | Check `altium_scripts/` folder path |

### Agent Response Issues

| Problem | Solution |
|---------|----------|
| "No data available" | Export data from Altium first |
| Slow response | Normal for complex analysis |
| API error | Check OpenAI API key |

### Layout Generation Issues

| Problem | Solution |
|---------|----------|
| "No components found" | Export schematic/PCB data |
| Placement overlaps | Increase board size or adjust spacing |
| Script execution fails | Check component designators match |

---

## Part 10: Test Checklist

### Basic Tests
- [ ] MCP server starts
- [ ] Application launches
- [ ] Connection succeeds
- [ ] Project setup works
- [ ] Chat interface responsive

### Data Export Tests
- [ ] Schematic export works
- [ ] PCB export works
- [ ] JSON files created correctly

### Agent Intelligence Tests
- [ ] Design analysis returns blocks
- [ ] Strategy generation works
- [ ] Design review identifies issues
- [ ] Layout generation creates script

### Integration Tests
- [ ] Batch script runs in Altium
- [ ] Components placed correctly
- [ ] Design rules created
- [ ] End-to-end workflow completes

---

## Part 11: Demo Script for Client

### Demo Flow (5 minutes)

1. **Introduction** (30 sec)
   - "This is EagilinsED, an AI co-pilot for PCB design"
   
2. **Show Connection** (30 sec)
   - Launch app, connect to server
   
3. **Load Existing Design** (1 min)
   - Select existing project
   - Show data already exported
   
4. **Design Analysis** (1 min)
   - "Analyze this schematic"
   - Show functional block detection
   
5. **Autonomous Layout** (1.5 min)
   - "Generate layout for this design"
   - Show placement summary
   - Show generated script
   
6. **Apply in Altium** (1 min)
   - Run batch placement script
   - Show components placed
   
7. **Conclusion** (30 sec)
   - "From schematic to placed PCB with one command"

### Key Points to Highlight

- **No step-by-step instructions needed**
- **Understands design intent automatically**
- **Generates real coordinates, not just advice**
- **Professional-grade placement decisions**
- **One-click batch execution**

---

## Summary

EagilinsED provides:

| Feature | Capability |
|---------|------------|
| Design Analysis | Functional block detection |
| Placement Strategy | Zone-based recommendations |
| Layout Generation | Autonomous component placement |
| Constraint Inference | Net classes + design rules |
| Design Review | Issue detection + suggestions |
| Batch Execution | Single-script placement |

**Total Test Coverage:** 11 parts, 40+ test cases

---

*EagilinsED - Design Intelligence, Not Command Execution*

