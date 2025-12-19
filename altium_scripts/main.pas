{*
 * Main Router Script
 * Reads commands from JSON files and shows which script to run
 * 
 * Usage: File → Run Script → main.pas → ShowCommand
 *}

Function FileExists(FileName: String): Boolean;
Var
    FileInfo: TSearchRec;
    F: TextFile;
Begin
    Result := False;
    Try
        If FindFirst(FileName, faAnyFile, FileInfo) = 0 Then
        Begin
            Result := True;
            FindClose(FileInfo);
            Exit;
        End;
    Except
    End;
    Try
        AssignFile(F, FileName);
        Reset(F);
        CloseFile(F);
        Result := True;
    Except
        Result := False;
    End;
End;

Function ExtractJsonString(JsonContent: String; KeyName: String): String;
Var
    KeyPos, ColonPos, QuoteStart, QuoteEnd: Integer;
    LowerJson, SearchKey: String;
Begin
    Result := '';
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    If KeyPos > 0 Then
    Begin
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '"') Then
            Inc(ColonPos);
        QuoteStart := ColonPos;
        QuoteEnd := QuoteStart;
        While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') Do
            Inc(QuoteEnd);
        If QuoteEnd > QuoteStart Then
            Result := Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart);
    End;
End;

Procedure ShowCommand;
Var
    CommandFile: TStringList;
    FileName: String;
    FileContent: String;
    CommandType: String;
    CommandStart: Integer;
    ScriptPath: String;
    LowerContent: String;
Begin
    // Check PCB commands first
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\pcb_commands.json';
    
    If FileExists(FileName) Then
    Begin
        CommandFile := TStringList.Create;
        Try
            CommandFile.LoadFromFile(FileName);
            FileContent := CommandFile.Text;
            LowerContent := LowerCase(FileContent);
            
            // Check for each command type
            If Pos('"move_component"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\moveComponent.pas';
                ShowMessage('Command: move_component' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunMoveComponent');
                Exit;
            End
            Else If Pos('"rotate_component"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\rotateComponent.pas';
                ShowMessage('Command: rotate_component' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunRotateComponent');
                Exit;
            End
            Else If Pos('"remove_component"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\removeComponent.pas';
                ShowMessage('Command: remove_component' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunRemoveComponent');
                Exit;
            End
            Else If Pos('"add_component"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\addComponent.pas';
                ShowMessage('Command: add_component' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddComponent');
                Exit;
            End
            Else If Pos('"change_component_value"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\changeComponentValue.pas';
                ShowMessage('Command: change_component_value' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunChangeComponentValue');
                Exit;
            End
            Else If Pos('"add_track"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\addTrack.pas';
                ShowMessage('Command: add_track' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddTrack');
                Exit;
            End
            Else If Pos('"add_via"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\addVia.pas';
                ShowMessage('Command: add_via' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddVia');
                Exit;
            End
            Else If Pos('"change_layer"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\pcb\changeLayer.pas';
                ShowMessage('Command: change_layer' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunChangeLayer');
                Exit;
            End
            Else If Pos('"create_new_project"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\project\createProject.pas';
                ShowMessage('Command: create_new_project' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: CreateProject');
                Exit;
            End
            Else If Pos('"export_pcb_info"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\export\exportPCBInfo.pas';
                ShowMessage('Command: export_pcb_info' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunExportPCBInfo');
                Exit;
            End;
        Finally
            CommandFile.Free;
        End;
    End;
    
    // Check schematic commands
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\schematic_commands.json';
    
    If FileExists(FileName) Then
    Begin
        CommandFile := TStringList.Create;
        Try
            CommandFile.LoadFromFile(FileName);
            FileContent := CommandFile.Text;
            LowerContent := LowerCase(FileContent);
            
            If Pos('"place_component"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\schematic\placeComponent.pas';
                ShowMessage('Command: place_component' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunPlaceComponent');
                Exit;
            End
            Else If Pos('"add_wire"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\schematic\addWire.pas';
                ShowMessage('Command: add_wire' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddWire');
                Exit;
            End
            Else If Pos('"add_net_label"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\schematic\addNetLabel.pas';
                ShowMessage('Command: add_net_label' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddNetLabel');
                Exit;
            End
            Else If Pos('"add_power_port"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\schematic\addPowerPort.pas';
                ShowMessage('Command: add_power_port' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAddPowerPort');
                Exit;
            End
            Else If Pos('"annotate"', LowerContent) > 0 Then
            Begin
                ScriptPath := 'commands\schematic\annotate.pas';
                ShowMessage('Command: annotate' + #13#10 +
                           'Run script: ' + ScriptPath + #13#10 +
                           'Procedure: RunAnnotate');
                Exit;
            End;
        Finally
            CommandFile.Free;
        End;
    End;
    
    ShowMessage('No command found in pcb_commands.json or schematic_commands.json');
End;

