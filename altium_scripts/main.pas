{*
 * Main Router Script - Executes all commands automatically
 * Reads commands from JSON files and executes them directly
 * 
 * Usage: File → Run Script → main.pas → ExecuteCommand
 *}

Const
    BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\';

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
        While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') And (JsonContent[QuoteEnd] <> #13) And (JsonContent[QuoteEnd] <> #10) Do
            Inc(QuoteEnd);
        If QuoteEnd > QuoteStart Then
            Result := Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart);
    End;
End;

Function ExtractJsonNumber(JsonContent: String; KeyName: String): Double;
Var
    KeyPos, ColonPos, NumStart, NumEnd: Integer;
    LowerJson, SearchKey, NumStr: String;
Begin
    Result := 0;
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
        NumStart := ColonPos;
        NumEnd := NumStart;
        While (NumEnd <= Length(JsonContent)) And 
              (((JsonContent[NumEnd] >= '0') And (JsonContent[NumEnd] <= '9')) Or 
               (JsonContent[NumEnd] = '.') Or (JsonContent[NumEnd] = '-') Or 
               (JsonContent[NumEnd] = '+') Or (JsonContent[NumEnd] = 'e') Or 
               (JsonContent[NumEnd] = 'E')) Do
            Inc(NumEnd);
        If NumEnd > NumStart Then
        Begin
            NumStr := Copy(JsonContent, NumStart, NumEnd - NumStart);
            Try
                Result := StrToFloat(NumStr);
            Except
                Result := 0;
            End;
        End;
    End;
End;

// Execute CreateProject command
Procedure ExecuteCreateProject(FileContent: String);
Var
    Workspace: IWorkspace;
    Client: IClient;
    Project: IProject;
    CommandFile: TStringList;
    FileName: String;
    PrjName, PrjPath, PrjFullPath: String;
    PrjDir: String;
    PrjFile: TStringList;
    Success: Boolean;
Begin
    Success := False;
    FileName := BASE_PATH + 'pcb_commands.json';
    
    // Extract project name
    PrjName := ExtractJsonString(FileContent, 'project_name');
    If PrjName = '' Then
    Begin
        PrjName := ExtractJsonString(FileContent, 'name');
        If PrjName = '' Then
            PrjName := 'NewProject';
    End;
    
    // Extract project path
    PrjPath := ExtractJsonString(FileContent, 'project_path');
    If PrjPath = '' Then
        PrjPath := ExtractJsonString(FileContent, 'path');
    
    // Create project full path
    If PrjPath = '' Then
        PrjFullPath := BASE_PATH + PrjName + '.PrjPcb'
    Else
        PrjFullPath := PrjPath + '\' + PrjName + '.PrjPcb';
    
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        Try
            Client := GetClient;
        Except
            Client := Nil;
        End;
        
        // Extract directory path
        PrjDir := ExtractFilePath(PrjFullPath);
        
        // Create directory if needed
        If Not DirectoryExists(PrjDir) Then
        Begin
            Try
                CreateDir(PrjDir);
            Except
                ShowMessage('ERROR: Could not create directory: ' + PrjDir);
                Exit;
            End;
        End;
        
        // Create project XML file
        Try
            PrjFile := TStringList.Create;
            Try
                PrjFile.Add('<?xml version="1.0" encoding="UTF-8"?>');
                PrjFile.Add('<Project xmlns="http://www.altium.com/ADST/Project">');
                PrjFile.Add('  <Name>' + PrjName + '</Name>');
                PrjFile.Add('  <Type>PCB</Type>');
                PrjFile.Add('  <Documents>');
                PrjFile.Add('  </Documents>');
                PrjFile.Add('</Project>');
                
                PrjFile.SaveToFile(PrjFullPath);
            Finally
                PrjFile.Free;
            End;
            
            // Verify file was created
            If Not FileExists(PrjFullPath) Then
            Begin
                ShowMessage('ERROR: Project file was not created: ' + PrjFullPath);
                Exit;
            End;
            
            // Open the project
            Try
                If Client <> Nil Then
                Begin
                    Try
                        Client.OpenDocument('', PrjFullPath);
                    Except
                        Try
                            Workspace.DM_OpenProject(PrjFullPath, True);
                        Except
                        End;
                    End;
                End
                Else
                Begin
                    Try
                        Workspace.DM_OpenProject(PrjFullPath, True);
                    Except
                    End;
                End;
                
                Sleep(1000);
                
                Project := Workspace.DM_FocusedProject;
                
                If Project <> Nil Then
                Begin
                    ShowMessage('SUCCESS! New project created:' + #13#10 +
                               'Name: ' + PrjName + '.PrjPcb' + #13#10 +
                               'Path: ' + PrjFullPath);
                    Success := True;
                End
                Else
                Begin
                    ShowMessage('Project file created:' + #13#10 +
                               'Path: ' + PrjFullPath + #13#10 +
                               'Please open it manually if needed.');
                    Success := True;
                End;
            Except
                ShowMessage('Project file created at: ' + PrjFullPath);
                Success := True;
            End;
        Except
            ShowMessage('ERROR: Exception creating project file: ' + PrjFullPath);
        End;
    Except
        ShowMessage('ERROR: Could not create project');
    End;
    
    // Clear command file if successful
    If Success Then
    Begin
        Try
            CommandFile := TStringList.Create;
            Try
                CommandFile.Add('[]');
                CommandFile.SaveToFile(FileName);
            Finally
                CommandFile.Free;
            End;
        Except
        End;
    End;
End;

// Main execution procedure
Procedure ExecuteCommand;
Var
    CommandFile: TStringList;
    FileName: String;
    FileContent: String;
    LowerContent: String;
Begin
    // Check PCB commands first
    FileName := BASE_PATH + 'pcb_commands.json';
    
    If FileExists(FileName) Then
    Begin
        CommandFile := TStringList.Create;
        Try
            CommandFile.LoadFromFile(FileName);
            FileContent := CommandFile.Text;
            LowerContent := LowerCase(FileContent);
            
            // Execute create_project command
            If (Pos('"create_new_project"', LowerContent) > 0) Or 
               (Pos('"create_project"', LowerContent) > 0) Then
            Begin
                ExecuteCreateProject(FileContent);
                Exit;
            End;
            
            // For other commands, show message that they need individual scripts
            // (We can add more inline execution later)
            If Pos('"move_component"', LowerContent) > 0 Then
            Begin
                ShowMessage('Command: move_component' + #13#10 +
                           'Please run: commands\pcb\moveComponent.pas → ExecuteMoveComponent');
                Exit;
            End
            Else If Pos('"export_pcb_info"', LowerContent) > 0 Then
            Begin
                ShowMessage('Command: export_pcb_info' + #13#10 +
                           'Please run: commands\export\exportPCBInfo.pas → ExportPCBInfo');
                Exit;
            End;
            
        Finally
            CommandFile.Free;
        End;
    End;
    
    // Check schematic commands
    FileName := BASE_PATH + 'schematic_commands.json';
    
    If FileExists(FileName) Then
    Begin
        CommandFile := TStringList.Create;
        Try
            CommandFile.LoadFromFile(FileName);
            FileContent := CommandFile.Text;
            LowerContent := LowerCase(FileContent);
            
            If Pos('"place_component"', LowerContent) > 0 Then
            Begin
                ShowMessage('Command: place_component' + #13#10 +
                           'Please run: commands\schematic\placeComponent.pas → ExecutePlaceComponent');
                Exit;
            End;
        Finally
            CommandFile.Free;
        End;
    End;
    
    ShowMessage('No command found in pcb_commands.json or schematic_commands.json');
End;
