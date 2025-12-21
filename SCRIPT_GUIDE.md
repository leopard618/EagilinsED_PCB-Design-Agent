# EagilinsED - Altium Scripts Guide

## Overview

This guide explains the updated Altium script structure. All scripts have been reorganized into individual command files, each containing a complete, self-contained implementation.

## Folder Structure

```
altium_scripts/
├── main.pas                    # Router script - shows which command to run
├── Scripts_Project.PrjScr      # Altium project file
├── commands/
│   ├── project/                # Project management commands
│   │   ├── createProject.pas
│   │   └── exportProjectInfo.pas
│   ├── pcb/                    # PCB modification commands
│   │   ├── addComponent.pas
│   │   ├── addTrack.pas
│   │   ├── addVia.pas
│   │   ├── changeComponentValue.pas
│   │   ├── changeLayer.pas
│   │   ├── moveComponent.pas
│   │   ├── removeComponent.pas
│   │   └── rotateComponent.pas
│   ├── schematic/               # Schematic modification commands
│   │   ├── addNetLabel.pas
│   │   ├── addPowerPort.pas
│   │   ├── addWire.pas
│   │   ├── annotate.pas
│   │   └── placeComponent.pas
│   ├── export/                  # Data export commands
│   │   ├── exportBoardConfig.pas
│   │   ├── exportDesignRules.pas
│   │   ├── exportPCBInfo.pas
│   │   └── exportSchematicInfo.pas
│   ├── verification/            # Design verification commands
│   │   ├── checkConnectivity.pas
│   │   ├── runDRC.pas
│   │   └── runERC.pas
│   ├── output/                  # Manufacturing output commands
│   │   ├── generateBOM.pas
│   │   ├── generateDrill.pas
│   │   ├── generateGerber.pas
│   │   └── generatePickPlace.pas
│   └── search/                  # Component search commands
│       ├── getComponentDetails.pas
│       ├── listLibraries.pas
│       └── searchComponents.pas
└── utils/                       # Helper functions (reference)
    ├── helpers.pas
    ├── json_parser.pas
    └── workspace.pas
```

## How It Works

### 1. Command Flow

1. **User sends command via UI** → Agent orchestrator interprets the command
2. **Command written to JSON** → `pcb_commands.json` or `schematic_commands.json`
3. **User runs `main.pas`** → Router script reads JSON and shows which command file to run
4. **User runs specific command file** → Command executes and updates Altium Designer

### 2. Using main.pas Router

When you run `main.pas` in Altium Designer:

1. It reads `pcb_commands.json` or `schematic_commands.json`
2. Identifies the command type
3. Shows a message like:
   ```
   Command: move_component
   Please run: commands/pcb/moveComponent.pas → ExecuteMoveComponent
   ```

### 3. Executing Commands

**Step 1:** Run `main.pas` in Altium Designer
- File → Run Script → Select `altium_scripts/main.pas`
- Click "Run"

**Step 2:** Read the message to see which command file to run

**Step 3:** Run the specific command file
- File → Run Script → Select the command file (e.g., `commands/pcb/moveComponent.pas`)
- Select the procedure (e.g., `ExecuteMoveComponent`)
- Click "Run"

## Available Commands

### Project Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `create_project` | `commands/project/createProject.pas` | `ExecuteCreateProject` | Create a new Altium PCB project |
| `export_project_info` | `commands/project/exportProjectInfo.pas` | `ExportProjectInfo` | Export project information to JSON |

### PCB Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `add_component` | `commands/pcb/addComponent.pas` | `ExecuteAddComponent` | Add a component to the PCB |
| `move_component` | `commands/pcb/moveComponent.pas` | `ExecuteMoveComponent` | Move a component to new coordinates |
| `rotate_component` | `commands/pcb/rotateComponent.pas` | `ExecuteRotateComponent` | Rotate a component |
| `remove_component` | `commands/pcb/removeComponent.pas` | `ExecuteRemoveComponent` | Remove a component from PCB |
| `change_component_value` | `commands/pcb/changeComponentValue.pas` | `ExecuteChangeComponentValue` | Change component value/comment |
| `change_layer` | `commands/pcb/changeLayer.pas` | `ExecuteChangeLayer` | Move component to different layer |
| `add_track` | `commands/pcb/addTrack.pas` | `ExecuteAddTrack` | Add a track/routing |
| `add_via` | `commands/pcb/addVia.pas` | `ExecuteAddVia` | Add a via |

### Schematic Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `place_component` | `commands/schematic/placeComponent.pas` | `ExecutePlaceComponent` | Place a component on schematic |
| `add_wire` | `commands/schematic/addWire.pas` | `ExecuteAddWire` | Add a wire connection |
| `add_net_label` | `commands/schematic/addNetLabel.pas` | `ExecuteAddNetLabel` | Add a net label |
| `add_power_port` | `commands/schematic/addPowerPort.pas` | `ExecuteAddPowerPort` | Add a power port |
| `annotate` | `commands/schematic/annotate.pas` | `ExecuteAnnotate` | Annotate schematic components |

### Export Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `export_pcb_info` | `commands/export/exportPCBInfo.pas` | `ExportPCBInfo` | Export PCB data to `pcb_info.json` |
| `export_schematic_info` | `commands/export/exportSchematicInfo.pas` | `ExportSchematicInfo` | Export schematic data to `schematic_info.json` |
| `export_design_rules` | `commands/export/exportDesignRules.pas` | `ExportDesignRules` | Export design rules to `design_rules.json` |
| `export_board_config` | `commands/export/exportBoardConfig.pas` | `ExportBoardConfig` | Export board config to `board_config.json` |

### Verification Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `run_drc` | `commands/verification/runDRC.pas` | `RunDRCAndExport` | Run Design Rule Check |
| `run_erc` | `commands/verification/runERC.pas` | `RunERCAndExport` | Run Electrical Rule Check |
| `check_connectivity` | `commands/verification/checkConnectivity.pas` | `CheckConnectivityAndExport` | Check routing connectivity |

### Output Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `generate_gerber` | `commands/output/generateGerber.pas` | `GenerateGerberFiles` | Generate Gerber files |
| `generate_drill` | `commands/output/generateDrill.pas` | `GenerateDrillFiles` | Generate NC Drill files |
| `generate_bom` | `commands/output/generateBOM.pas` | `GenerateBOM` | Generate Bill of Materials |
| `generate_pick_place` | `commands/output/generatePickPlace.pas` | `GeneratePickAndPlace` | Generate Pick & Place file |

### Search Commands

| Command | File | Procedure | Description |
|---------|------|-----------|-------------|
| `list_libraries` | `commands/search/listLibraries.pas` | `ListInstalledLibraries` | List all installed libraries |
| `search_components` | `commands/search/searchComponents.pas` | `SearchComponents` | Search for components |
| `get_component_details` | `commands/search/getComponentDetails.pas` | `GetComponentDetails` | Get component details |

## Command JSON Format

### PCB Commands (`pcb_commands.json`)

```json
{
  "command": "move_component",
  "parameters": {
    "designator": "R1",
    "x": 10.0,
    "y": 20.0
  }
}
```

### Schematic Commands (`schematic_commands.json`)

```json
{
  "command": "place_component",
  "parameters": {
    "library_ref": "Resistor",
    "library_name": "Miscellaneous Devices",
    "x": 100.0,
    "y": 100.0
  }
}
```

## Testing Workflow

### 1. Start New Project

1. Open EagilinsED application
2. Click "Start New Project"
3. Enter project name
4. Go to Agent page
5. Say: "Create a new project"
6. Run `main.pas` in Altium Designer
7. Follow instructions to run `commands/project/createProject.pas`

### 2. Export Data

1. In Agent page, say: "Export PCB information"
2. Run `main.pas` in Altium Designer
3. Follow instructions to run `commands/export/exportPCBInfo.pas`
4. Data will be exported to `pcb_info.json`

### 3. Modify PCB

1. In Agent page, say: "Move component R1 to position 10mm, 20mm"
2. Run `main.pas` in Altium Designer
3. Follow instructions to run `commands/pcb/moveComponent.pas`
4. Component will be moved

### 4. Verify Design

1. In Agent page, say: "Run DRC check"
2. Run `main.pas` in Altium Designer
3. Follow instructions to run `commands/verification/runDRC.pas`
4. Results exported to `verification_report.json`

### 5. Generate Outputs

1. In Agent page, say: "Generate Gerber files"
2. Run `main.pas` in Altium Designer
3. Follow instructions to run `commands/output/generateGerber.pas`
4. Files generated in `Output/Gerber/` folder

## File Locations

### Input Files (Read by Scripts)
- `pcb_commands.json` - PCB modification commands
- `schematic_commands.json` - Schematic modification commands
- `project_commands.json` - Project creation commands

### Output Files (Generated by Scripts)
- `pcb_info.json` - PCB data export
- `schematic_info.json` - Schematic data export
- `design_rules.json` - Design rules export
- `board_config.json` - Board configuration export
- `project_info.json` - Project information export
- `verification_report.json` - DRC/ERC results
- `connectivity_report.json` - Connectivity check results
- `library_list.json` - Library list
- `component_search.json` - Component search results
- `component_details.json` - Component details
- `output_result.json` - Manufacturing output status

### Output Directories
- `Output/Gerber/` - Gerber files
- `Output/NC Drill/` - Drill files
- `Output/BOM/` - Bill of Materials
- `Output/Assembly/` - Pick & Place files

## Important Notes

1. **Each command file is self-contained** - All necessary functions are included in each file
2. **No dependencies** - Command files don't depend on each other
3. **Router pattern** - `main.pas` only shows which file to run, it doesn't execute commands
4. **Manual execution** - You must manually run the command file after `main.pas` shows the instruction
5. **JSON files** - Commands are queued in JSON files, then executed via scripts

## Troubleshooting

### "Cannot access PCB board" Error
- Make sure a PCB document is open and active in Altium Designer
- Click on the PCB tab to make it the focused document

### "Cannot access schematic document" Error
- Make sure a schematic document is open and active
- Click on the schematic tab to make it the focused document

### "No project is currently open" Error
- Open a project first: File → Open Project

### Command Not Found
- Check that `pcb_commands.json` or `schematic_commands.json` exists
- Verify the command name matches the expected format
- Run `main.pas` to see the exact command file to execute

## Best Practices

1. **Always run `main.pas` first** - It will tell you which command file to run
2. **Check JSON files** - Verify command parameters before running scripts
3. **Backup your work** - Save your Altium project before running modification commands
4. **Test export commands first** - Verify data export before attempting modifications
5. **Read error messages** - Scripts provide detailed error messages with solutions

## Script Development

If you need to modify or add commands:

1. **Create new command file** in appropriate `commands/` subfolder
2. **Include helper functions** - Each file should be self-contained
3. **Use BASE_PATH constant** - For file paths: `E:\Workspace\AI\11.10.WayNe\new-version\`
4. **Follow naming convention** - `camelCase.pas` for files, `PascalCase` for procedures
5. **Update main.pas** - Add routing logic for new command type
6. **Test thoroughly** - Verify JSON output and error handling

## Support

For issues or questions:
- Check error messages in Altium Designer
- Verify JSON file format
- Ensure correct file paths
- Check that required documents are open

