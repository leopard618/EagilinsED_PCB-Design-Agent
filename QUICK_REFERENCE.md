# EagilinsED Quick Reference Card

## 🚀 Quick Start

```powershell
# Terminal 1: Start MCP Server
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python mcp_server_file_based.py

# Terminal 2: Start Application
cd E:\Workspace\AI\11.10.WayNe\new-version
.\venv\Scripts\Activate.ps1
python main.py
```

---

## 📜 Altium Scripts Reference

| Script | Procedure | Description |
|--------|-----------|-------------|
| **altium_export_pcb_info.pas** | `ExportPCBInfo` | Export PCB data for connection |
| **altium_execute_commands.pas** | `ExecuteCommands` | Execute queued modifications |
| **altium_export_schematic_info.pas** | `ExportSchematicInfo` | Export schematic data |
| **altium_project_manager.pas** | `ExportProjectInfo` | Export project structure |
| **altium_verification.pas** | `RunDRCAndExport` | Run Design Rule Check |
| **altium_verification.pas** | `RunERCAndExport` | Run Electrical Rule Check |
| **altium_verification.pas** | `CheckConnectivityAndExport` | Check unrouted nets |
| **altium_output_generator.pas** | `GenerateBOM` | Generate Bill of Materials |
| **altium_output_generator.pas** | `GeneratePickAndPlace` | Generate Pick & Place file |
| **altium_output_generator.pas** | `GenerateGerberFiles` | Generate Gerber files |
| **altium_output_generator.pas** | `GenerateDrillFiles` | Generate NC Drill files |
| **altium_component_search.pas** | `SearchComponents` | Search installed libraries |
| **altium_component_search.pas** | `ListInstalledLibraries` | List all libraries |
| **altium_design_rules.pas** | `ExportDesignRules` | Export clearance/width/via rules |
| **altium_design_rules.pas** | `ExportNetClasses` | Export net class definitions |
| **altium_design_rules.pas** | `ShowDesignRulesSummary` | Quick design rules summary |
| **altium_pcb_setup.pas** | `ExportBoardConfig` | Export board size, layers, stackup |
| **altium_pcb_setup.pas** | `ShowBoardInfo` | Quick board information |
| **altium_pcb_setup.pas** | `ExportBoardOutline` | Export board outline vertices |
| **altium_pcb_drawing.pas** | `AddTextToPCB` | Add text to silkscreen |
| **altium_pcb_drawing.pas** | `AddLineToPCB` | Add line to layer |
| **altium_pcb_drawing.pas** | `AddRectangleToPCB` | Add rectangle outline |
| **altium_pcb_drawing.pas** | `ExportTextObjects` | Export all text on board |

---

## 💬 Sample Queries for EagilinsED

### PCB Information
```
"What components are on the board?"
"Where is R95 located?"
"List all nets on the PCB"
"What is the board size?"
"How many vias are there?"
```

### PCB Modifications
```
"Move R123 to 76, 69"
"Rotate U1 by 90 degrees"
"Add a resistor R200 at position 100, 50"
"Delete component C15"
"Change the value of R1 to 10k"
```

### Schematic Questions
```
"What components are in the schematic?"
"Show me the power ports"
"What is U1 connected to?"
```

### Verification
```
"Run DRC on the board"
"Are there any design errors?"
"Which nets are not routed?"
"Check design rule violations"
```

### Manufacturing Outputs
```
"Generate BOM"
"Create pick and place file"
"Generate manufacturing files"
```

---

## 🔧 Workflow Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                      EagilinsED Workflow                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. START                                                       │
│     ├─ Start MCP Server (Terminal 1)                           │
│     └─ Start Application (Terminal 2)                          │
│                                                                 │
│  2. CONNECT                                                     │
│     ├─ Run altium_export_pcb_info.pas → ExportPCBInfo          │
│     └─ Click Connect in EagilinsED                             │
│                                                                 │
│  3. ASK & MODIFY                                                │
│     ├─ Ask questions → Get instant answers                     │
│     └─ Request modifications → Command queued                  │
│                                                                 │
│  4. EXECUTE (when modifications requested)                      │
│     └─ Run altium_execute_commands.pas → ExecuteCommands       │
│                                                                 │
│  5. VERIFY                                                      │
│     └─ Run altium_verification.pas → RunDRCAndExport           │
│                                                                 │
│  6. OUTPUT                                                      │
│     └─ Run altium_output_generator.pas → GenerateBOM, etc.     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 File Locations

| File | Purpose |
|------|---------|
| `pcb_info.json` | PCB data exported from Altium |
| `pcb_commands.json` | Queued modification commands |
| `schematic_info.json` | Schematic data exported from Altium |
| `project_info.json` | Project structure information |
| `verification_report.json` | DRC/ERC results |
| `output_result.json` | Output generation results |
| `Output/` folder | Generated manufacturing files |

---

## ⚡ Tips

1. **Always run export script first** before connecting
2. **After modifications**, run ExecuteCommands in Altium
3. **PCB info auto-updates** after ExecuteCommands runs
4. **Use specific component names** for modifications (e.g., "R123" not "that resistor")
5. **Check terminal logs** for detailed debug information

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect | Run `altium_export_pcb_info.pas` first |
| OpenAI timeout | Check proxy settings, restart app |
| Commands not executing | Make sure to run `ExecuteCommands` in Altium |
| Wrong component modified | Use exact designator (case-sensitive) |
| Server not starting | Check if port 8080 is available |


