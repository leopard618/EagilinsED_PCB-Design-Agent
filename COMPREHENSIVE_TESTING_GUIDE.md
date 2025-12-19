# EagilinsED - Comprehensive Testing Guide

## Project Status: Ready for Full Testing

### ✅ Implemented Features

**Core Intelligence:**
- ✅ Design Analysis (functional blocks, signals, components)
- ✅ Placement Strategy Generation
- ✅ Design Review (issues, warnings, suggestions)
- ✅ Autonomous Layout Generation (schematic → PCB layout)
- ✅ Constraint Generation (design rules, net classes)
- ✅ Batch Execution (multiple commands at once)

**UI/UX:**
- ✅ Professional dark theme interface
- ✅ Welcome page with connection
- ✅ Project setup (existing/new)
- ✅ Agent chat interface
- ✅ Back navigation
- ✅ Markdown stripping

**Integration:**
- ✅ MCP server (file-based)
- ✅ Altium script integration
- ✅ OpenAI API integration
- ✅ Command queuing system

---

## Prerequisites

### 1. Environment Setup

**Terminal 1 - MCP Server:**
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py
```
Expected: `Server running on http://localhost:8080`

**Terminal 2 - Application:**
```powershell
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python main.py
```

**Altium Designer:**
- Open Altium Designer (any state)

### 2. Test Data Preparation

For **"Open Existing Project"** flow, you need:
- A PCB project with schematic and/or PCB documents
- Export scripts ready to run

For **"Start New Project"** flow:
- No data needed initially

---

## Test Flow 1: Start New Project

### Phase 1: Connection & Setup

1. **Launch App** → Welcome page appears
2. **Click Connect** → Should show "Connected successfully"
3. **Click "Start New Project"** → Card highlights green
4. **Click Continue** → Moves to Agent Chat

### Phase 2: Create Project Documents

**Test Commands:**
```
Create a new PCB project called TestProject
Add a schematic document
Create a PCB document
```

**Verification:**
- Agent responds naturally (no markdown symbols)
- Commands queued to `project_commands.json` or `schematic_commands.json`
- Run scripts in Altium: `altium_project_manager.pas` → appropriate procedure

**Expected Result:**
- New `.PrjPcb` file created
- New `.SchDoc` added to project
- New `.PcbDoc` added to project

---

## Test Flow 2: Intelligent Design Features

### Prerequisites for Intelligence Tests

**Export Design Data from Altium:**

1. **Open your project** in Altium Designer
2. **File → Run Script** → Select script → Run procedure:

| Script | Procedure | Output File |
|--------|-----------|-------------|
| `altium_export_schematic_info.pas` | `ExportSchematicInfo` | `schematic_info.json` |
| `altium_export_pcb_info.pas` | `ExportPCBInfo` | `pcb_info.json` |
| `altium_project_manager.pas` | `ExportProjectInfo` | `project_info.json` |

**Note:** At minimum, export schematic data for intelligence features.

---

### Test 1: Design Analysis

**Command:**
```
Analyze this schematic
```

**What It Does:**
- Identifies functional blocks (power, MCU, interfaces, etc.)
- Classifies components by type
- Analyzes signal types (power, ground, high-speed, analog)
- Identifies critical components
- Infers design type

**Expected Response:**
- Summary of functional blocks found
- Component breakdown (ICs, passives, connectors)
- Signal analysis (power nets, high-speed nets)
- Critical components and their requirements
- Design type inference (e.g., "Microcontroller Board")

**Verification Checklist:**
- ✅ Functional blocks identified correctly
- ✅ Component counts match schematic
- ✅ Signal types classified properly
- ✅ Critical components highlighted
- ✅ Response is natural language (no markdown)

**Example Output:**
```
I've analyzed your schematic design. Here's what I found:

**Design Type:** Microcontroller Board

**Functional Blocks:**
- Power Supply: U2 (LDO regulator), C1-C4 (decoupling)
- MCU Section: U1 (STM32), Y1 (crystal), R1-R3 (pull-ups)
- Interface: J1 (USB connector), U3 (USB transceiver)

**Components:**
- Total: 15 components
- ICs: 3 (U1, U2, U3)
- Passives: 10 (R, C)
- Connectors: 2 (J1, J2)

**Signals:**
- Power nets: VCC, 3V3, GND
- High-speed: USB_D+, USB_D-
- Critical: U1 (MCU), Y1 (crystal - place close to U1)
```

---

### Test 2: Placement Strategy

**Command:**
```
Generate placement strategy for this design
```
or
```
What's the best way to place these components?
```

**What It Does:**
- Analyzes functional blocks
- Recommends board zones for each block
- Suggests placement order
- Identifies critical spacing requirements
- Provides routing priorities

**Expected Response:**
- Board zone recommendations (top-left, center, bottom-right, etc.)
- Placement order (what to place first)
- Critical spacing requirements (e.g., "C1 within 3mm of U1")
- Routing priorities (power first, then high-speed, etc.)

**Verification Checklist:**
- ✅ Zones assigned logically (power bottom-left, MCU center, etc.)
- ✅ Placement order makes sense (ICs first, then passives)
- ✅ Critical spacing identified (decoupling caps near ICs)
- ✅ Routing priorities listed

**Example Output:**
```
Based on your design, here's my recommended placement strategy:

**Board Zones:**
- **Bottom-Left:** Power supply block (U2, L1, C1-C4)
  Reason: Isolate power from sensitive circuits
  
- **Center:** MCU section (U1, Y1, R1-R3)
  Reason: Central location for routing to all blocks
  
- **Right Edge:** Interface connectors (J1, J2)
  Reason: Easy access for external connections

**Placement Order:**
1. Place U1 (MCU) in center
2. Place Y1 (crystal) within 5mm of U1
3. Place decoupling capacitors (C1-C4) within 3mm of U1
4. Place power supply block in bottom-left
5. Place connectors on right edge

**Critical Spacing:**
- C1, C2 must be within 3mm of U1 (decoupling)
- Y1 must be within 5mm of U1 (clock signal integrity)
- Keep power supply away from analog sections
```

---

### Test 3: Design Review

**Command:**
```
Review this design for issues
```
or
```
Check my design for problems
```

**What It Does:**
- Checks for missing components (e.g., decoupling caps)
- Identifies potential design issues
- Suggests improvements
- Provides design health score

**Expected Response:**
- List of issues (warnings, errors)
- Explanations of why each issue matters
- Specific recommendations to fix
- Overall design health assessment

**Verification Checklist:**
- ✅ Missing decoupling detected (if applicable)
- ✅ ESD protection suggestions (if needed)
- ✅ Design health score provided
- ✅ Actionable recommendations

**Example Output:**
```
I've reviewed your design and found the following:

**Issues Found:**

1. **Warning - Decoupling Capacitors**
   - Found: 3 ICs, but only 4 capacitors
   - Issue: Each IC should have at least 2 decoupling capacitors (100nF + 10uF)
   - Recommendation: Add 100nF ceramic capacitor near each IC power pin

2. **Suggestion - ESD Protection**
   - Found: External connectors (J1, J2) without ESD protection
   - Issue: External interfaces are vulnerable to ESD damage
   - Recommendation: Add TVS diodes on USB and connector signals

**Design Health Score:** 75/100

**Overall Assessment:**
Your design is solid but could benefit from additional decoupling and ESD protection. The functional blocks are well-organized.
```

---

### Test 4: Autonomous Layout Generation ⭐ **CORE FEATURE**

**Command:**
```
Generate layout for this design
```
or
```
Create PCB layout automatically
```

**What It Does:**
1. Analyzes schematic → Identifies functional blocks
2. Classifies components → Groups by function
3. Assigns board zones → Power, MCU, interfaces, etc.
4. Calculates positions → X,Y coordinates for each component
5. Generates constraints → Design rules, net classes
6. Creates batch script → Ready for Altium execution

**Expected Response:**
- Summary of components placed
- Board zones used
- Instructions to execute layout
- File path to batch script

**Verification Checklist:**
- ✅ Components assigned to logical zones
- ✅ Coordinates calculated (X, Y in mm)
- ✅ Batch script generated (`altium_scripts/batch_placement.pas`)
- ✅ Design constraints generated
- ✅ Clear execution instructions

**Example Output:**
```
## Layout Generated Successfully

I've analyzed your design and generated an initial PCB layout.

### Summary
- **Components placed:** 15
- **Board size:** 100mm × 80mm
- **Zones used:** Power (bottom-left), MCU (center), Interfaces (right edge)

### Placement by Block
- Power Supply: 5 components (U2, L1, C1-C4)
- MCU Section: 6 components (U1, Y1, R1-R3, C5-C6)
- Interfaces: 4 components (J1, J2, U3, C7)

### Generated Files
- **Batch Script:** `altium_scripts/batch_placement.pas`
- **Placements:** All components have X,Y coordinates

### To Execute:
1. Open your PCB document in Altium Designer
2. Go to File → Run Script
3. Select `batch_placement.pas`
4. Run procedure: `ExecuteBatchPlacement`
5. All 15 components will be placed automatically

### Design Constraints
I've also generated design rules:
- Power track width: 0.5mm
- High-speed clearance: 0.3mm
- Default clearance: 0.2mm

You can review and adjust placements as needed.
```

**Execution Steps:**
1. Check `altium_scripts/batch_placement.pas` exists
2. Open PCB document in Altium
3. File → Run Script → `batch_placement.pas`
4. Run: `ExecuteBatchPlacement`
5. Verify components placed correctly

---

## Test Flow 3: Open Existing Project

### Phase 1: Setup

1. **Connect** → Welcome page
2. **Click "Open Existing Project"** → Card highlights blue
3. **Follow export instructions** → Export data from Altium
4. **Click Continue** → Moves to Agent Chat

### Phase 2: Test Intelligence Features

Run all tests from **Test Flow 2** (Analysis, Strategy, Review, Layout)

---

## Advanced Testing

### Test 5: Constraint Generation

**Command:**
```
Generate design rules for this design
```

**What It Does:**
- Analyzes nets → Classifies by type (power, ground, high-speed)
- Generates net classes → Groups related nets
- Creates design rules → Clearance, width, via rules
- Generates Altium script → Ready to apply rules

**Expected:**
- Net classes defined (Power, Ground, HighSpeed, etc.)
- Design rules generated
- Script file created

---

### Test 6: Component Search Integration

**Command:**
```
Search for USB connector components
```

**What It Does:**
- Searches Altium libraries
- Returns matching components
- Can be used for placement

**Note:** Requires `altium_component_search.pas` script execution first.

---

## Verification Checklist

### UI/UX
- [ ] Welcome page loads correctly
- [ ] Connection succeeds
- [ ] Project setup cards work
- [ ] Agent chat interface responsive
- [ ] Back button works
- [ ] Clear button resets chat
- [ ] No markdown symbols in responses
- [ ] Professional appearance

### Intelligence Features
- [ ] Design analysis identifies blocks correctly
- [ ] Placement strategy is logical
- [ ] Design review finds issues
- [ ] Layout generation creates valid coordinates
- [ ] Batch script executes in Altium
- [ ] Constraints are reasonable

### Integration
- [ ] MCP server responds
- [ ] Commands queue correctly
- [ ] Altium scripts execute
- [ ] JSON files created/read properly
- [ ] OpenAI API works

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No schematic data" | Export `schematic_info.json` first |
| "Connection failed" | Check MCP server is running |
| "No response from agent" | Check OpenAI API key in `.env` |
| "Script not found" | Check `altium_scripts` folder path |
| "Layout not generated" | Ensure schematic has components |
| "Components not placed" | Check batch script syntax |
| "Markdown in response" | Should be stripped - check `strip_markdown()` |

---

## Success Criteria

**For Client Demo:**

1. ✅ **Connection:** App connects to MCP server reliably
2. ✅ **Analysis:** Agent correctly identifies functional blocks
3. ✅ **Strategy:** Placement recommendations are logical
4. ✅ **Review:** Issues are identified accurately
5. ✅ **Layout Generation:** Components placed with valid coordinates
6. ✅ **Execution:** Batch script runs in Altium successfully
7. ✅ **UI:** Professional, responsive interface
8. ✅ **Natural Language:** Agent responds conversationally

---

## Test Scenarios

### Scenario 1: Simple MCU Board
- Components: MCU, crystal, decoupling caps, USB connector
- Expected: Power zone, MCU center, connector edge

### Scenario 2: Power Supply Board
- Components: Regulator, inductor, capacitors
- Expected: All in power zone, proper spacing

### Scenario 3: Mixed Signal Board
- Components: MCU, analog section, digital section
- Expected: Analog/digital separation, proper zones

---

## Next Steps After Testing

1. **Document Issues:** Note any bugs or improvements
2. **Optimize Layout:** Adjust zone assignments if needed
3. **Enhance Analysis:** Add more block detection patterns
4. **Improve Constraints:** Refine design rule generation
5. **Client Demo:** Prepare demonstration script

---

## Client Demo Script

**Opening:**
"EagilinsED is an intelligent PCB design co-pilot that doesn't just execute commands - it co-designs with you."

**Demo Flow:**
1. Show connection and project setup
2. Demonstrate analysis: "Analyze this schematic"
3. Show strategy: "Generate placement strategy"
4. Show review: "Review this design"
5. **Highlight:** "Generate layout" → Full autonomous layout
6. Execute batch script in Altium
7. Show components placed automatically

**Key Message:**
"The agent takes a schematic and automatically generates an initial PCB layout, including component placement and design rules, without step-by-step instructions."

---

## Notes

- All intelligent features require exported design data
- Layout generation works best with complete schematic data
- Batch scripts can be reviewed before execution
- Placements can be adjusted manually after generation
- Design rules are suggestions and can be modified

---

**Last Updated:** 2025-12-19
**Status:** Ready for Full Testing ✅

