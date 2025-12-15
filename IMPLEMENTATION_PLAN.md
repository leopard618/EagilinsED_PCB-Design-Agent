# Full PCB Design Workflow Implementation Plan

This document outlines the complete implementation plan for extending the EagilinsED PCB Assistant to cover the **entire PCB design lifecycle** - from schematic creation to manufacturing outputs.

---

## 📋 Overview

### Current State
- ✅ PCB information export (`pcb_info.json`)
- ✅ PCB modifications (move, rotate, add components)
- ✅ Natural language queries about PCB

### Target State
- ✅ Full schematic design support
- ✅ Component search and acquisition
- ✅ Design rule constraints
- ✅ PCB creation from schematic
- ✅ Routing and placement
- ✅ Design verification (DRC/ERC)
- ✅ Manufacturing outputs (Gerber, BOM, etc.)

---

## 🗺️ Implementation Phases

Based on the [Altium Designer Tutorial](https://www.altium.com/documentation/altium-designer/tutorial):

| Phase | Tutorial Section | Priority |
|-------|-----------------|----------|
| 1 | Creating Project & Schematic Document | 🔴 High |
| 2 | Searching & Acquiring Components | 🔴 High |
| 3 | Capturing Schematic | 🔴 High |
| 4 | Setting Up Design Constraints | 🟡 Medium |
| 5 | Creating & Configuring PCB Document | 🟡 Medium |
| 6 | Component Placement & Routing | 🟡 Medium |
| 7 | Verifying Board Design | 🟢 High |
| 8 | PCB Drawing (Silkscreen, etc.) | 🟢 Low |
| 9 | Output Documentation & Project Release | 🔴 High |

---

## Phase 1: Creating Project & Schematic Document

**Tutorial**: [Creating Project and Schematic Document](https://www.altium.com/documentation/altium-designer/tutorial/creating-project-schematic-document)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Create new project | Create .PrjPcb file with specified name and location |
| Create schematic | Add new .SchDoc to project |
| Create PCB | Add new .PcbDoc to project |
| List project files | Show all documents in current project |
| Open/Close documents | Navigate between project files |

### New Altium Script: `altium_project_manager.pas`

```pascal
// Key procedures to implement:
procedure CreateNewProject(ProjectName, ProjectPath: String);
procedure AddSchematicToProject(SchematicName: String);
procedure AddPCBToProject(PCBName: String);
procedure ExportProjectInfo;
procedure OpenDocument(DocPath: String);
procedure CloseDocument(DocPath: String);
```

### New JSON Structure: `project_info.json`

```json
{
  "project": {
    "name": "MyProject",
    "path": "C:\\Projects\\MyProject\\MyProject.PrjPcb",
    "created": "2024-01-15T10:30:00",
    "modified": "2024-01-15T14:22:00"
  },
  "documents": [
    {
      "type": "Schematic",
      "name": "Sheet1.SchDoc",
      "path": "C:\\Projects\\MyProject\\Sheet1.SchDoc"
    },
    {
      "type": "PCB",
      "name": "PCB1.PcbDoc",
      "path": "C:\\Projects\\MyProject\\PCB1.PcbDoc"
    }
  ]
}
```

### Example User Queries

```
"Create a new project called 'PowerSupply' in my Documents folder"
"Add a new schematic sheet called 'MainCircuit'"
"What files are in the current project?"
"Create a PCB document for this project"
```

---

## Phase 2: Searching & Acquiring Components

**Tutorial**: [Searching and Acquiring Components](https://www.altium.com/documentation/altium-designer/tutorial/searching-acquiring-components)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Search components | Query Altium libraries by keyword, value, package |
| View component details | Get parameters, footprints, symbols |
| Place component | Add from library to schematic |
| Manage libraries | List available libraries |

### New Altium Script: `altium_component_search.pas`

```pascal
// Key procedures to implement:
procedure SearchComponents(Query: String);
procedure GetComponentDetails(LibRef, CompRef: String);
procedure PlaceComponentFromLibrary(LibRef, CompRef: String);
procedure ListAvailableLibraries;
procedure ExportSearchResults;
```

### New JSON Structure: `component_search.json`

```json
{
  "query": "10k resistor 0805",
  "results": [
    {
      "library": "Miscellaneous Devices.IntLib",
      "component": "Res2",
      "description": "Resistor",
      "parameters": {
        "Value": "10k",
        "Package": "0805"
      },
      "footprint": "0805",
      "symbol": "RES"
    }
  ]
}
```

### Example User Queries

```
"Find a 10k resistor in 0805 package"
"Search for ATmega328P microcontroller"
"What libraries do I have installed?"
"Place the LM7805 voltage regulator on the schematic"
```

---

## Phase 3: Capturing Schematic

**Tutorial**: [Capturing Schematic](https://www.altium.com/documentation/altium-designer/tutorial/capturing-schematic)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Export schematic info | Get all components, wires, nets |
| Place component | Add component to schematic at position |
| Create wire | Connect pins with wires |
| Add net label | Name nets for clarity |
| Add power ports | VCC, GND symbols |
| Add designators | Auto-annotate components |

### New Altium Script: `altium_schematic_capture.pas`

```pascal
// Key procedures to implement:
procedure ExportSchematicInfo;
procedure PlaceComponent(CompRef: String; X, Y: Integer);
procedure CreateWire(X1, Y1, X2, Y2: Integer);
procedure AddNetLabel(NetName: String; X, Y: Integer);
procedure AddPowerPort(PortType: String; X, Y: Integer);
procedure AnnotateSchematic;
procedure ValidateSchematic;
```

### New JSON Structure: `schematic_info.json`

```json
{
  "schematic": {
    "name": "Sheet1.SchDoc",
    "sheet_size": "A4",
    "title_block": {
      "title": "Power Supply",
      "revision": "1.0",
      "author": "Engineer"
    }
  },
  "components": [
    {
      "designator": "U1",
      "name": "LM7805",
      "library": "Linear.IntLib",
      "location": { "x": 100, "y": 200 },
      "rotation": 0,
      "pins": [
        { "name": "VIN", "number": "1", "net": "VIN" },
        { "name": "GND", "number": "2", "net": "GND" },
        { "name": "VOUT", "number": "3", "net": "+5V" }
      ]
    }
  ],
  "wires": [
    {
      "net": "VIN",
      "segments": [
        { "x1": 50, "y1": 200, "x2": 100, "y2": 200 }
      ]
    }
  ],
  "net_labels": [
    { "name": "VIN", "location": { "x": 50, "y": 200 } }
  ],
  "power_ports": [
    { "type": "GND", "net": "GND", "location": { "x": 100, "y": 150 } }
  ]
}
```

### Example User Queries

```
"Show me all components in the schematic"
"Connect pin 1 of U1 to pin 3 of C1"
"Add a ground symbol at the bottom of U1"
"What nets are in the schematic?"
"Annotate all components automatically"
```

---

## Phase 4: Setting Up Design Constraints

**Tutorial**: [Setting Up Design Constraints](https://www.altium.com/documentation/altium-designer/tutorial/setting-up-design-constraints)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Export design rules | Get current PCB design rules |
| Set clearance rules | Min spacing between objects |
| Set width rules | Trace width constraints |
| Set via rules | Via size and drill constraints |
| Net class rules | Different rules per net class |

### New Altium Script: `altium_design_rules.pas`

```pascal
// Key procedures to implement:
procedure ExportDesignRules;
procedure SetClearanceRule(RuleName: String; Clearance: Double);
procedure SetWidthRule(RuleName: String; MinWidth, MaxWidth: Double);
procedure SetViaRule(RuleName: String; ViaSize, HoleSize: Double);
procedure CreateNetClass(ClassName: String; Nets: Array);
procedure ApplyRuleToNetClass(RuleName, ClassName: String);
```

### New JSON Structure: `design_rules.json`

```json
{
  "clearance_rules": [
    {
      "name": "Clearance",
      "scope": "All",
      "minimum": 0.254,
      "unit": "mm"
    }
  ],
  "width_rules": [
    {
      "name": "Width",
      "scope": "All",
      "min_width": 0.254,
      "preferred_width": 0.3,
      "max_width": 2.0,
      "unit": "mm"
    },
    {
      "name": "Power Width",
      "scope": "NetClass:Power",
      "min_width": 0.5,
      "preferred_width": 0.8,
      "max_width": 2.0,
      "unit": "mm"
    }
  ],
  "via_rules": [
    {
      "name": "Via",
      "via_diameter": 0.6,
      "hole_size": 0.3,
      "unit": "mm"
    }
  ],
  "net_classes": [
    {
      "name": "Power",
      "nets": ["VCC", "GND", "+5V", "+3.3V"]
    },
    {
      "name": "Signal",
      "nets": ["SDA", "SCL", "TX", "RX"]
    }
  ]
}
```

### Example User Queries

```
"What are the current design rules?"
"Set minimum clearance to 0.2mm"
"Create a Power net class with VCC and GND"
"Set trace width for power nets to 0.5mm minimum"
"What is the current via size?"
```

---

## Phase 5: Creating & Configuring PCB Document

**Tutorial**: [Creating and Configuring PCB Document](https://www.altium.com/documentation/altium-designer/tutorial/creating-configuring-pcb-document)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Create PCB from schematic | Transfer design to PCB |
| Set board shape | Define board outline |
| Configure layers | Set up copper and mechanical layers |
| Set board stackup | Layer stack configuration |
| Import changes | Update PCB from schematic |

### New Altium Script: `altium_pcb_setup.pas`

```pascal
// Key procedures to implement:
procedure CreatePCBFromSchematic;
procedure SetBoardShape(Width, Height: Double);
procedure SetBoardShapeFromVertices(Vertices: Array);
procedure ConfigureLayers(LayerStack: String);
procedure ImportChangesFromSchematic;
procedure ExportBoardConfiguration;
```

### New JSON Structure: `board_config.json`

```json
{
  "board": {
    "width": 100,
    "height": 80,
    "unit": "mm",
    "shape": "rectangle",
    "vertices": [
      { "x": 0, "y": 0 },
      { "x": 100, "y": 0 },
      { "x": 100, "y": 80 },
      { "x": 0, "y": 80 }
    ]
  },
  "layers": {
    "copper_layers": 2,
    "stackup": [
      { "name": "Top Layer", "type": "signal", "thickness": 0.035 },
      { "name": "Dielectric", "type": "dielectric", "thickness": 1.5 },
      { "name": "Bottom Layer", "type": "signal", "thickness": 0.035 }
    ]
  },
  "origin": { "x": 0, "y": 0 }
}
```

### Example User Queries

```
"Create PCB from the current schematic"
"Set board size to 100mm x 80mm"
"How many layers does this board have?"
"Import changes from schematic to PCB"
"Set up a 4-layer board stackup"
```

---

## Phase 6: Component Placement & Routing

**Tutorial**: [Component Placement and Routing](https://www.altium.com/documentation/altium-designer/tutorial/component-placement-routing-board)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Auto-place components | Automatic component placement |
| Move component | Position component at coordinates |
| Align components | Align selected components |
| Auto-route | Automatic trace routing |
| Manual route | Create trace between pads |
| Add via | Place via at location |

### Enhanced Altium Script: `altium_execute_commands.pas`

```pascal
// Additional procedures:
procedure AutoPlaceComponents;
procedure AlignComponents(Components: Array; Alignment: String);
procedure AutoRouteNet(NetName: String);
procedure AutoRouteAll;
procedure CreateTrace(Layer: String; Points: Array; Width: Double);
procedure PlaceVia(X, Y: Double; NetName: String);
```

### Enhanced Commands in `pcb_commands.json`

```json
{
  "commands": [
    {
      "action": "auto_place",
      "options": {
        "group_by": "room",
        "respect_keepout": true
      }
    },
    {
      "action": "align_components",
      "designators": ["R1", "R2", "R3", "R4"],
      "alignment": "horizontal_center"
    },
    {
      "action": "create_trace",
      "net": "VCC",
      "layer": "Top Layer",
      "width": 0.5,
      "points": [
        { "x": 10.5, "y": 20.3 },
        { "x": 15.0, "y": 20.3 },
        { "x": 15.0, "y": 25.0 }
      ]
    },
    {
      "action": "auto_route",
      "net": "SDA"
    }
  ]
}
```

### Example User Queries

```
"Auto-place all components"
"Align R1, R2, R3, R4 horizontally"
"Route the VCC net on the top layer"
"Auto-route all remaining connections"
"Move U1 to the center of the board"
```

---

## Phase 7: Verifying Board Design

**Tutorial**: [Verifying the Board Design](https://www.altium.com/documentation/altium-designer/tutorial/verifying-board-design)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Run DRC | Design Rule Check |
| Run ERC | Electrical Rule Check |
| Export violations | Get list of errors/warnings |
| Clear violations | Mark as resolved |
| Check connectivity | Verify all nets connected |

### New Altium Script: `altium_verification.pas`

```pascal
// Key procedures to implement:
procedure RunDRC;
procedure RunERC;
procedure ExportViolations;
procedure ClearViolation(ViolationID: String);
procedure CheckConnectivity;
procedure ExportVerificationReport;
```

### New JSON Structure: `verification_report.json`

```json
{
  "drc_results": {
    "run_time": "2024-01-15T14:30:00",
    "total_violations": 3,
    "errors": 1,
    "warnings": 2,
    "violations": [
      {
        "id": "DRC001",
        "type": "Clearance",
        "severity": "error",
        "message": "Clearance Constraint (0.254mm) between Track and Pad",
        "objects": ["Track on Top Layer", "Pad R1-1"],
        "location": { "x": 45.2, "y": 32.1 }
      },
      {
        "id": "DRC002",
        "type": "Width",
        "severity": "warning",
        "message": "Track width (0.2mm) below minimum (0.254mm)",
        "objects": ["Track on Top Layer"],
        "location": { "x": 50.0, "y": 40.0 }
      }
    ]
  },
  "erc_results": {
    "run_time": "2024-01-15T14:30:05",
    "total_violations": 1,
    "violations": [
      {
        "id": "ERC001",
        "type": "Unconnected Pin",
        "severity": "warning",
        "message": "Pin U1-5 is not connected",
        "component": "U1",
        "pin": "5"
      }
    ]
  },
  "connectivity": {
    "total_nets": 25,
    "routed_nets": 23,
    "unrouted_nets": 2,
    "unrouted": ["NET1", "NET2"]
  }
}
```

### Example User Queries

```
"Run design rule check"
"Are there any DRC errors?"
"What nets are not routed?"
"Show me all clearance violations"
"Run ERC on the schematic"
```

---

## Phase 8: PCB Drawing (Silkscreen, etc.)

**Tutorial**: [PCB Drawing](https://www.altium.com/documentation/altium-designer/tutorial/pcb-drawing)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Add text | Silkscreen text labels |
| Add graphics | Logo, drawings |
| Add dimensions | Board dimensions |
| Configure silkscreen | Text size, placement |
| Add keepout | Keepout regions |

### New Altium Script: `altium_pcb_drawing.pas`

```pascal
// Key procedures to implement:
procedure AddText(Layer: String; Text: String; X, Y: Double; Height: Double);
procedure AddLine(Layer: String; X1, Y1, X2, Y2: Double; Width: Double);
procedure AddArc(Layer: String; CX, CY, Radius, StartAngle, EndAngle: Double);
procedure AddDimension(X1, Y1, X2, Y2: Double);
procedure AddKeepoutRegion(Vertices: Array);
procedure ImportLogo(FilePath: String; X, Y: Double);
```

### Enhanced Commands

```json
{
  "commands": [
    {
      "action": "add_text",
      "layer": "Top Overlay",
      "text": "Power Supply v1.0",
      "x": 50,
      "y": 75,
      "height": 1.5,
      "font": "Default"
    },
    {
      "action": "add_dimension",
      "x1": 0,
      "y1": 0,
      "x2": 100,
      "y2": 0,
      "layer": "Mechanical 1"
    },
    {
      "action": "add_keepout",
      "layer": "Keep-Out Layer",
      "vertices": [
        { "x": 45, "y": 35 },
        { "x": 55, "y": 35 },
        { "x": 55, "y": 45 },
        { "x": 45, "y": 45 }
      ]
    }
  ]
}
```

### Example User Queries

```
"Add 'Rev 1.0' text to the silkscreen"
"Add board dimensions"
"Create a keepout zone around the antenna"
"Add a line on the mechanical layer"
```

---

## Phase 9: Output Documentation & Project Release

**Tutorial**: [Output Documentation and Project Release](https://www.altium.com/documentation/altium-designer/tutorial/output-documentation-project-release)

### Features to Implement

| Feature | Description |
|---------|-------------|
| Generate Gerber | Manufacturing files |
| Generate drill files | NC Drill files |
| Generate BOM | Bill of Materials |
| Generate pick & place | Assembly data |
| Generate PDF | Schematic/PCB prints |
| Create output job | Configure outputs |

### New Altium Script: `altium_output_generator.pas`

```pascal
// Key procedures to implement:
procedure GenerateGerberFiles(OutputPath: String);
procedure GenerateDrillFiles(OutputPath: String);
procedure GenerateBOM(OutputPath: String; Format: String);
procedure GeneratePickAndPlace(OutputPath: String);
procedure GeneratePDF(OutputPath: String; DocumentType: String);
procedure GenerateODB(OutputPath: String);
procedure CreateOutputJob(JobName: String);
procedure RunOutputJob(JobName: String);
```

### New JSON Structure: `output_config.json`

```json
{
  "gerber": {
    "output_path": "C:\\Projects\\MyProject\\Output\\Gerber",
    "format": "RS-274X",
    "layers": [
      "Top Layer",
      "Bottom Layer",
      "Top Overlay",
      "Bottom Overlay",
      "Top Solder",
      "Bottom Solder",
      "Mechanical 1"
    ],
    "mirror_bottom": false,
    "include_apertures": true
  },
  "drill": {
    "output_path": "C:\\Projects\\MyProject\\Output\\NC Drill",
    "format": "Excellon",
    "units": "mm",
    "zero_suppression": "trailing"
  },
  "bom": {
    "output_path": "C:\\Projects\\MyProject\\Output\\BOM",
    "format": "xlsx",
    "columns": ["Designator", "Description", "Value", "Footprint", "Quantity"],
    "group_by": "Value"
  },
  "pick_and_place": {
    "output_path": "C:\\Projects\\MyProject\\Output\\Assembly",
    "format": "csv",
    "units": "mm",
    "reference": "board_origin"
  }
}
```

### New JSON Structure: `output_results.json`

```json
{
  "generated_files": [
    {
      "type": "Gerber",
      "files": [
        "MyProject-Top.GTL",
        "MyProject-Bottom.GBL",
        "MyProject-TopSolder.GTS"
      ],
      "path": "C:\\Projects\\MyProject\\Output\\Gerber",
      "generated": "2024-01-15T15:00:00"
    },
    {
      "type": "Drill",
      "files": ["MyProject.DRL"],
      "path": "C:\\Projects\\MyProject\\Output\\NC Drill"
    },
    {
      "type": "BOM",
      "files": ["MyProject-BOM.xlsx"],
      "path": "C:\\Projects\\MyProject\\Output\\BOM",
      "component_count": 45,
      "unique_parts": 23
    }
  ]
}
```

### Example User Queries

```
"Generate Gerber files for manufacturing"
"Create a BOM in Excel format"
"Generate pick and place file"
"Export drill files"
"Generate PDF of the schematic"
"Create all manufacturing outputs"
```

---

## 🏗️ Implementation Architecture

### Updated Project Structure

```
new-version/
├── main.py                          # Entry point
├── mcp_client.py                    # MCP client (enhanced)
├── mcp_server_file_based.py         # File-based MCP server (enhanced)
├── agent_orchestrator.py            # LLM orchestration (enhanced)
│
├── altium_scripts/
│   ├── altium_export_pcb_info.pas       # PCB export (existing)
│   ├── altium_execute_commands.pas      # Command execution (enhanced)
│   ├── altium_project_manager.pas       # NEW: Project management
│   ├── altium_schematic_capture.pas     # NEW: Schematic operations
│   ├── altium_component_search.pas      # NEW: Component search
│   ├── altium_design_rules.pas          # NEW: Design rules
│   ├── altium_pcb_setup.pas             # NEW: PCB configuration
│   ├── altium_verification.pas          # NEW: DRC/ERC
│   ├── altium_pcb_drawing.pas           # NEW: Graphics/text
│   └── altium_output_generator.pas      # NEW: Manufacturing outputs
│
├── data/
│   ├── pcb_info.json                    # PCB data (existing)
│   ├── pcb_commands.json                # Commands (existing)
│   ├── project_info.json                # NEW: Project structure
│   ├── schematic_info.json              # NEW: Schematic data
│   ├── component_search.json            # NEW: Search results
│   ├── design_rules.json                # NEW: Design rules
│   ├── board_config.json                # NEW: Board setup
│   ├── verification_report.json         # NEW: DRC/ERC results
│   └── output_config.json               # NEW: Output settings
│
├── pages/
│   ├── welcome_page.py                  # Connection page
│   ├── chat_page.py                     # Chat interface
│   └── project_page.py                  # NEW: Project overview
│
└── utils/
    ├── intent_classifier.py             # Enhanced for new intents
    └── command_builder.py               # NEW: Command generation
```

### Enhanced Intent Categories

```python
INTENT_CATEGORIES = {
    # Existing
    "pcb_query": ["component info", "net info", "board info"],
    "pcb_modify": ["move", "rotate", "add", "delete", "change value"],
    
    # New - Project Management
    "project_create": ["new project", "create project"],
    "project_query": ["project files", "list documents"],
    
    # New - Schematic
    "schematic_query": ["schematic info", "components", "nets", "connections"],
    "schematic_modify": ["place component", "wire", "connect", "annotate"],
    
    # New - Component Search
    "component_search": ["find", "search", "look for component"],
    
    # New - Design Rules
    "rules_query": ["design rules", "clearance", "width rules"],
    "rules_modify": ["set rule", "create net class"],
    
    # New - PCB Setup
    "pcb_setup": ["board size", "layers", "stackup", "import from schematic"],
    
    # New - Routing
    "routing": ["route", "auto-route", "trace", "via"],
    
    # New - Verification
    "verify": ["DRC", "ERC", "check design", "violations"],
    
    # New - Output
    "output": ["gerber", "BOM", "drill", "manufacturing", "PDF"]
}
```

---

## 📅 Implementation Order

### Priority 1 (Foundation)
1. **Phase 1**: Project & Schematic Document Creation
2. **Phase 3**: Schematic Capture (Export/Query)
3. **Phase 7**: Verification (DRC/ERC)

### Priority 2 (Core Workflow)
4. **Phase 2**: Component Search
5. **Phase 5**: PCB Creation from Schematic
6. **Phase 9**: Output Generation

### Priority 3 (Enhancement)
7. **Phase 4**: Design Constraints
8. **Phase 6**: Advanced Routing
9. **Phase 8**: PCB Drawing

---

## ❓ Questions Before Implementation

1. **Which phase should we start with?**
   - Recommended: Phase 1 (Project Management) or Phase 3 (Schematic Export)

2. **Do you have a sample .schdoc file to test with?**
   - Need schematic file for testing Phase 3

3. **Should we keep PCB and Schematic as separate modes, or unified?**
   - Option A: Mode selector (PCB Mode / Schematic Mode)
   - Option B: Auto-detect based on active document

4. **Output file locations?**
   - Same folder as project?
   - Configurable output directory?

---

## 🚀 Getting Started

To begin implementation, let me know:

1. Which phase to start with
2. Any specific features you want prioritized
3. Sample files available for testing

Ready to start building! 🎯

