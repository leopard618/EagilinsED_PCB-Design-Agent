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

// Case-insensitive character comparison helper
Function CharEqualIgnoreCase(Ch1, Ch2: Char): Boolean;
Var
    UpCh1, UpCh2: Char;
Begin
    If Ch1 = Ch2 Then
    Begin
        Result := True;
        Exit;
    End;
    UpCh1 := UpCase(Ch1);
    UpCh2 := UpCase(Ch2);
    Result := UpCh1 = UpCh2;
End;

// Case-insensitive string search (memory efficient - no string copies)
Function FindKeyIgnoreCase(JsonContent: String; KeyName: String; StartPos: Integer): Integer;
Var
    I, J, KeyLen: Integer;
    Match: Boolean;
Begin
    Result := 0;
    KeyLen := Length(KeyName);
    If (KeyLen = 0) Or (StartPos < 1) Or (StartPos > Length(JsonContent)) Then Exit;
    
    // Search for "keyname" pattern (with quotes)
    I := StartPos;
    While I <= Length(JsonContent) - KeyLen - 1 Do
    Begin
        // Check for opening quote
        If JsonContent[I] = '"' Then
        Begin
            Match := True;
            // Compare key name (case-insensitive)
            For J := 1 To KeyLen Do
            Begin
                If (I + J > Length(JsonContent)) Or 
                   Not CharEqualIgnoreCase(JsonContent[I + J], KeyName[J]) Then
                Begin
                    Match := False;
                    Break;
                End;
            End;
            // Check for closing quote after key name
            If Match And (I + KeyLen + 1 <= Length(JsonContent)) And 
               (JsonContent[I + KeyLen + 1] = '"') Then
            Begin
                Result := I;
                Exit;
            End;
        End;
        Inc(I);
    End;
End;

Function ExtractJsonString(JsonContent: String; KeyName: String): String;
Var
    KeyPos, ColonPos, QuoteStart, QuoteEnd: Integer;
    ParamStart, ParamEnd: Integer;
    I: Integer;
    MaxLen: Integer;
Begin
    Result := '';
    MaxLen := Length(JsonContent);
    // Safety limit: don't process files larger than 1MB
    If MaxLen > 1048576 Then Exit;
    
    // First, try to find in "parameters" object (case-insensitive)
    KeyPos := FindKeyIgnoreCase(JsonContent, 'parameters', 1);
    If KeyPos > 0 Then
    Begin
        // Find colon after "parameters"
        ColonPos := KeyPos + Length('parameters') + 1; // +1 for closing quote
        While (ColonPos <= MaxLen) And (JsonContent[ColonPos] <> ':') Do 
        Begin
            Inc(ColonPos);
            If ColonPos > MaxLen Then Exit;
        End;
        If ColonPos > MaxLen Then Exit;
        Inc(ColonPos);
        
        // Skip whitespace
        While (ColonPos <= MaxLen) And (JsonContent[ColonPos] = ' ') Do 
        Begin
            Inc(ColonPos);
            If ColonPos > MaxLen Then Exit;
        End;
        
        // Find the start and end of the parameters object
        If (ColonPos <= MaxLen) And (JsonContent[ColonPos] = '{') Then
        Begin
            ParamStart := ColonPos;
            ParamEnd := ParamStart + 1;
            // Find matching '}' with safety limit
            While (ParamEnd <= MaxLen) And (ParamEnd <= ParamStart + 10000) And 
                  (JsonContent[ParamEnd] <> '}') Do 
            Begin
                Inc(ParamEnd);
            End;
            
            If (ParamEnd <= MaxLen) And (JsonContent[ParamEnd] = '}') Then
            Begin
                // Search for KeyName within parameters section (case-insensitive)
                KeyPos := FindKeyIgnoreCase(JsonContent, KeyName, ParamStart);
                If (KeyPos > 0) And (KeyPos < ParamEnd) Then
                Begin
                    // Find colon after key
                    ColonPos := KeyPos + Length(KeyName) + 1; // +1 for closing quote
                    While (ColonPos <= ParamEnd) And (JsonContent[ColonPos] <> ':') Do 
                    Begin
                        Inc(ColonPos);
                        If ColonPos > ParamEnd Then Exit;
                    End;
                    If ColonPos > ParamEnd Then Exit;
                    Inc(ColonPos);
                    
                    // Skip whitespace
                    While (ColonPos <= ParamEnd) And (JsonContent[ColonPos] = ' ') Do 
                    Begin
                        Inc(ColonPos);
                        If ColonPos > ParamEnd Then Exit;
                    End;
                    
                    // Skip opening quote if present
                    If (ColonPos <= ParamEnd) And (JsonContent[ColonPos] = '"') Then 
                        Inc(ColonPos);
                    If ColonPos > ParamEnd Then Exit;
                    
                    // Extract value
                    QuoteStart := ColonPos;
                    QuoteEnd := QuoteStart;
                    While (QuoteEnd <= ParamEnd) And (QuoteEnd <= QuoteStart + 1000) And
                          (JsonContent[QuoteEnd] <> '"') And 
                          (JsonContent[QuoteEnd] <> ',') And 
                          (JsonContent[QuoteEnd] <> '}') Do 
                    Begin
                        Inc(QuoteEnd);
                    End;
                    
                    If QuoteEnd > QuoteStart Then
                    Begin
                        Result := Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart);
                        Exit; // Found in parameters, exit
                    End;
                End;
            End;
        End;
    End;
    
    // If not found in "parameters", try to find at the root level
    KeyPos := FindKeyIgnoreCase(JsonContent, KeyName, 1);
    If KeyPos > 0 Then
    Begin
        // Find colon after key
        ColonPos := KeyPos + Length(KeyName) + 1; // +1 for closing quote
        While (ColonPos <= MaxLen) And (JsonContent[ColonPos] <> ':') Do
        Begin
            Inc(ColonPos);
            If ColonPos > MaxLen Then Exit;
        End;
        If ColonPos > MaxLen Then Exit;
        Inc(ColonPos);
        
        // Skip whitespace
        While (ColonPos <= MaxLen) And (JsonContent[ColonPos] = ' ') Do
        Begin
            Inc(ColonPos);
            If ColonPos > MaxLen Then Exit;
        End;
        If ColonPos > MaxLen Then Exit;
        
        // Skip opening quote if present
        If (ColonPos <= MaxLen) And (JsonContent[ColonPos] = '"') Then 
            Inc(ColonPos);
        If ColonPos > MaxLen Then Exit;
        
        // Extract value
        QuoteStart := ColonPos;
        QuoteEnd := QuoteStart;
        While (QuoteEnd <= MaxLen) And (QuoteEnd <= QuoteStart + 1000) And
              (JsonContent[QuoteEnd] <> '"') And 
              (JsonContent[QuoteEnd] <> ',') And 
              (JsonContent[QuoteEnd] <> '}') And 
              (JsonContent[QuoteEnd] <> #13) And 
              (JsonContent[QuoteEnd] <> #10) Do
        Begin
            Inc(QuoteEnd);
        End;
        
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

// Get workspace interface (wrapper for built-in GetWorkSpace)
Function GetWorkspace: IWorkspace;
Begin
    Try
        Result := GetWorkSpace;
    Except
        Result := Nil;
    End;
End;

// Execute CreateProject command
Procedure ExecuteCreateProject(FileContent: String);
Var
    Workspace: IWorkspace;
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
    
    // Extract project name (check multiple formats)
    PrjName := ExtractJsonString(FileContent, 'project_name');
    If PrjName = '' Then
    Begin
        PrjName := ExtractJsonString(FileContent, 'projectName');  // camelCase
        If PrjName = '' Then
        Begin
            PrjName := ExtractJsonString(FileContent, 'name');
            If PrjName = '' Then
                PrjName := 'NewProject';
        End;
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
                // Try using global Client variable first (wrapped in try-except for safety)
                Try
                    Client.OpenDocument('', PrjFullPath);
                Except
                    // Client.OpenDocument failed or Client not available, try Workspace method
                    Try
                        Workspace.DM_OpenProject(PrjFullPath, True);
                    Except
                        // Both methods failed, but file was created successfully
                        // User can open it manually
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
    HasCreateCommand: Boolean;
Begin
    // Check PCB commands first
    FileName := BASE_PATH + 'pcb_commands.json';
    
    If FileExists(FileName) Then
    Begin
        CommandFile := TStringList.Create;
        Try
            CommandFile.LoadFromFile(FileName);
            FileContent := CommandFile.Text;
            
            // Safety check: limit file size to prevent memory issues
            If Length(FileContent) > 1048576 Then // 1MB limit
            Begin
                ShowMessage('ERROR: Command file too large (>1MB). Please check the file.');
                Exit;
            End;
            
            // Check for create project commands (case-insensitive, memory-efficient)
            // Search once for each possible command name
            HasCreateCommand := (FindKeyIgnoreCase(FileContent, 'create_new_project', 1) > 0) Or
                                (FindKeyIgnoreCase(FileContent, 'create_project', 1) > 0) Or
                                (FindKeyIgnoreCase(FileContent, 'createnewproject', 1) > 0) Or
                                (FindKeyIgnoreCase(FileContent, 'createproject', 1) > 0);
            
            If HasCreateCommand Then
            Begin
                ExecuteCreateProject(FileContent);
                Exit;
            End;
            
            // For other commands, show message that they need individual scripts
            // (We can add more inline execution later)
            If FindKeyIgnoreCase(FileContent, 'move_component', 1) > 0 Then
            Begin
                ShowMessage('Command: move_component' + #13#10 +
                           'Please run: commands\pcb\moveComponent.pas → ExecuteMoveComponent');
                Exit;
            End
            Else If FindKeyIgnoreCase(FileContent, 'export_pcb_info', 1) > 0 Then
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
            
            // Safety check: limit file size
            If Length(FileContent) > 1048576 Then // 1MB limit
            Begin
                ShowMessage('ERROR: Command file too large (>1MB). Please check the file.');
                Exit;
            End;
            
            If FindKeyIgnoreCase(FileContent, 'place_component', 1) > 0 Then
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
