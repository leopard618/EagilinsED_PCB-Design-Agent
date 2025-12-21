{*
 * Create New Project Command
 * Creates a new PCB project from JSON command
 * Command: create_project
 *}

Const
    BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\';

// Helper function to extract JSON string value
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

// Check if file exists
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

// Get workspace interface
Function GetWorkspace: IWorkspace;
Begin
    Result := GetWorkSpace;
End;

// Create project from JSON command file
Procedure CreateProject;
Var
    Workspace: IWorkspace;
    Client: IClient;
    Project: IProject;
    CommandFile: TStringList;
    FileName: String;
    FileContent: String;
    PrjName, PrjPath, PrjFullPath: String;
    PrjDir: String;
    PrjFile: TStringList;
    Success: Boolean;
    DebugMsg: String;
Begin
    Success := False;
    FileName := BASE_PATH + 'pcb_commands.json';
    
    // Read command from JSON file
    If Not FileExists(FileName) Then
    Begin
        ShowMessage('ERROR: Command file not found: ' + FileName);
        Exit;
    End;
    
    CommandFile := TStringList.Create;
    Try
        Try
            CommandFile.LoadFromFile(FileName);
        Except
            ShowMessage('ERROR: Could not read file: ' + FileName);
            Exit;
        End;
        
        FileContent := CommandFile.Text;
        
        // Debug: Show what we're reading
        If Length(FileContent) > 200 Then
            DebugMsg := Copy(FileContent, 1, 200) + '...'
        Else
            DebugMsg := FileContent;
        
        // Extract project name from JSON
        // The JSON structure is: [{"command": "...", "parameters": {"project_name": "..."}}]
        PrjName := ExtractJsonString(FileContent, 'project_name');
        
        // Debug message
        If PrjName = '' Then
        Begin
            PrjName := ExtractJsonString(FileContent, 'name');
            If PrjName = '' Then
            Begin
                ShowMessage('WARNING: Could not extract project_name from JSON.' + #13#10 +
                           'Using default name: NewProject' + #13#10 + #13#10 +
                           'JSON content (first 200 chars):' + #13#10 + DebugMsg);
                PrjName := 'NewProject';
            End;
        End;
        
        // Extract project path (optional)
        PrjPath := ExtractJsonString(FileContent, 'project_path');
        If PrjPath = '' Then
            PrjPath := ExtractJsonString(FileContent, 'path');
        
        // Create project full path
        If PrjPath = '' Then
        Begin
            PrjFullPath := BASE_PATH + PrjName + '.PrjPcb';
        End
        Else
        Begin
            PrjFullPath := PrjPath + '\' + PrjName + '.PrjPcb';
        End;
        
        // Show what we're about to create
        ShowMessage('Creating project:' + #13#10 +
                   'Name: ' + PrjName + #13#10 +
                   'Path: ' + PrjFullPath);
        
        Try
            Workspace := GetWorkspace;
            If Workspace = Nil Then
            Begin
                ShowMessage('ERROR: Cannot access workspace');
                Exit;
            End;
            
            // Get Client interface
            Try
                Client := GetClient;
            Except
                Client := Nil;
            End;
            
            // Extract directory path
            PrjDir := ExtractFilePath(PrjFullPath);
            
            // Create directory if it doesn't exist
            If Not DirectoryExists(PrjDir) Then
            Begin
                Try
                    CreateDir(PrjDir);
                Except
                    ShowMessage('ERROR: Could not create directory: ' + PrjDir);
                    Exit;
                End;
            End;
            
            // Create project XML file manually
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
                
                // Open the project file
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
                    
                    // Wait a moment for project to open
                    Sleep(1000);
                    
                    Project := Workspace.DM_FocusedProject;
                    
                    If Project <> Nil Then
                    Begin
                        ShowMessage('SUCCESS! New project created:' + #13#10 +
                                   'Name: ' + PrjName + '.PrjPcb' + #13#10 +
                                   'Path: ' + PrjFullPath + #13#10 + #13#10 +
                                   'Project has been created and opened.');
                        Success := True;
                    End
                    Else
                    Begin
                        ShowMessage('Project file created successfully!' + #13#10 +
                                   'Name: ' + PrjName + '.PrjPcb' + #13#10 +
                                   'Path: ' + PrjFullPath + #13#10 + #13#10 +
                                   'Please open it manually in Altium Designer if it did not open automatically.');
                        Success := True; // File created successfully
                    End;
                Except
                    ShowMessage('Project file created at: ' + PrjFullPath + #13#10 +
                               'Please open it manually in Altium Designer.');
                    Success := True; // File created successfully
                End;
            Except
                ShowMessage('ERROR: Exception creating project file. Make sure the path is valid.' + #13#10 +
                           'Path: ' + PrjFullPath);
            End;
        Except
            ShowMessage('ERROR: Exception accessing workspace or creating project.');
        End;
        
        // Clear command file if successful
        If Success Then
        Begin
            Try
                CommandFile.Clear;
                CommandFile.Add('[]');
                CommandFile.SaveToFile(FileName);
            Except
                ShowMessage('WARNING: Project created but could not clear command file.');
            End;
        End;
    Finally
        CommandFile.Free;
    End;
End;
