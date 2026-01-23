{*
 * Export PCB Info - ABSOLUTE MINIMAL VERSION
 * Just writes a JSON file - NO Altium API calls at all
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';

Procedure ExportPCBInfo;
Var
    F: TextFile;
Begin
    AssignFile(F, BASE_PATH + 'pcb_info.json');
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "file_name": "minimal",');
    WriteLn(F, '  "board_size": {"width_mm": 0, "height_mm": 0},');
    WriteLn(F, '  "components": [],');
    WriteLn(F, '  "nets": [],');
    WriteLn(F, '  "tracks": [],');
    WriteLn(F, '  "vias": [],');
    WriteLn(F, '  "statistics": {"component_count": 0, "net_count": 0, "track_count": 0, "via_count": 0}');
    WriteLn(F, '}');
    CloseFile(F);
    ShowMessage('Done! File: ' + BASE_PATH + 'pcb_info.json');
End;
