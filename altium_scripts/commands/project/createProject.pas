{*
 * Create New Project Command
 * Creates a new PCB project from JSON command
 *}

Uses utils\helpers, utils\json_parser, utils\workspace;

// Create project from JSON command
Function CreateProject(CommandJson: String): Boolean;
Var
    Workspace: IWorkspace;
    Client: IClient;
    Project: IProject;
    PrjName, PrjPath, PrjFullPath: String;
    BasePath: String;
    PrjDir: String;
    PrjFile: TStringList;
Begin
    Result := False;
    BasePath := 'E:\Workspace\AI\11.10.WayNe\new-version\';
    
    // Extract project name from JSON
    PrjName := ExtractJsonString(CommandJson, 'project_name');
    If PrjName = '' Then
    Begin
        PrjName := ExtractJsonString(CommandJson, 'name');
        If PrjName = '' Then
            PrjName := 'NewProject';
    End;
    
    // Extract project path (optional)
    PrjPath := ExtractJsonString(CommandJson, 'project_path');
    
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
        
        // Create project full path
        If PrjPath = '' Then
        Begin
            PrjFullPath := BasePath + PrjName + '.PrjPcb';
        End
        Else
        Begin
            PrjFullPath := PrjPath + '\' + PrjName + '.PrjPcb';
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
            
            // Open the project file
            Try
                If Client <> Nil Then
                Begin
                    Client.OpenDocument('', PrjFullPath);
                End
                Else
                Begin
                    Try
                        Workspace.DM_OpenProject(PrjFullPath, True);
                    Except
                    End;
                End;
                
                Project := Workspace.DM_FocusedProject;
                
                If Project <> Nil Then
                Begin
                    ShowMessage('SUCCESS! New project created:' + #13#10 +
                               'Name: ' + PrjName + '.PrjPcb' + #13#10 +
                               'Path: ' + PrjFullPath + #13#10 + #13#10 +
                               'Project has been created and opened.');
                    Result := True;
                End
                Else
                Begin
                    ShowMessage('Project file created, but could not open it automatically.' + #13#10 +
                               'Please open it manually: ' + PrjFullPath);
                    Result := True; // File created successfully
                End;
            Except
                ShowMessage('Project file created at: ' + PrjFullPath + #13#10 +
                           'Please open it manually in Altium Designer.');
                Result := True; // File created successfully
            End;
        Except
            ShowMessage('ERROR: Exception creating project file. Make sure the path is valid.' + #13#10 +
                       'Path: ' + PrjFullPath);
        End;
    Except
        ShowMessage('ERROR: Could not create project');
    End;
End;

