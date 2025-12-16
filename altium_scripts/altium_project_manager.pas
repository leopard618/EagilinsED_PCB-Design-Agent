{*
 * Altium Designer Script - Project Manager
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Export project information (all documents in project)
 * - Create new projects
 * - Add schematic/PCB documents to project
 * - Open/Close documents
 * 
 * TO RUN THIS SCRIPT:
 * 1. In Altium Designer, go to: File -> Run Script
 * 2. Select this file: altium_project_manager.pas
 * 3. When dialog appears, select the procedure you want to run
 * 4. Click OK
 *}

// Helper function to escape JSON strings
Function EscapeJsonString(InputStr: String): String;
Var
    I: Integer;
    ResultStr: String;
    Ch: Char;
Begin
    ResultStr := '';
    For I := 1 To Length(InputStr) Do
    Begin
        Ch := InputStr[I];
        If Ch = '"' Then
            ResultStr := ResultStr + '\"'
        Else If Ch = '\' Then
            ResultStr := ResultStr + '\\'
        Else If Ch = #13 Then
            ResultStr := ResultStr + '\r'
        Else If Ch = #10 Then
            ResultStr := ResultStr + '\n'
        Else If Ch = #9 Then
            ResultStr := ResultStr + '\t'
        Else If (Ord(Ch) < 32) Or (Ord(Ch) > 126) Then
            ResultStr := ResultStr + '?'
        Else
            ResultStr := ResultStr + Ch;
    End;
    Result := ResultStr;
End;

// Export project information to JSON
Procedure ExportProjectInfo;
Var
    Workspace     : IWorkspace;
    Project       : IProject;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    I             : Integer;
    FirstItem     : Boolean;
    DocKind       : String;
    DocName       : String;
    DocPath       : String;
    PrjName       : String;
    PrjPath       : String;
    SchCount      : Integer;
    PCBCount      : Integer;
    LibCount      : Integer;
    OtherCount    : Integer;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
    Except
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    // Get current project
    Project := Nil;
    Try
        Project := Workspace.DM_FocusedProject;
    Except
    End;
    
    If Project = Nil Then
    Begin
        ShowMessage('ERROR: No project is currently open.' + #13#10 + #13#10 +
                    'Please open a project first (File → Open Project)');
        Exit;
    End;
    
    // Get project info
    Try
        PrjName := Project.DM_ProjectFileName;
        PrjPath := Project.DM_ProjectFullPath;
    Except
        PrjName := 'Unknown';
        PrjPath := '';
    End;
    
    // Initialize counters
    SchCount := 0;
    PCBCount := 0;
    LibCount := 0;
    OtherCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "project": {' + #13#10;
    JSONStr := JSONStr + '    "name": "' + EscapeJsonString(PrjName) + '",' + #13#10;
    JSONStr := JSONStr + '    "path": "' + EscapeJsonString(PrjPath) + '",' + #13#10;
    
    // Get project type
    Try
        JSONStr := JSONStr + '    "type": "' + EscapeJsonString(Project.DM_ObjectKindString) + '"' + #13#10;
    Except
        JSONStr := JSONStr + '    "type": "PCB Project"' + #13#10;
    End;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Documents
    JSONStr := JSONStr + '  "documents": [' + #13#10;
    FirstItem := True;
    
    Try
        For I := 0 To Project.DM_LogicalDocumentCount - 1 Do
        Begin
            Doc := Project.DM_LogicalDocuments(I);
            If Doc <> Nil Then
            Begin
                If Not FirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                FirstItem := False;
                
                Try
                    DocName := Doc.DM_FileName;
                    DocPath := Doc.DM_FullPath;
                    DocKind := Doc.DM_DocumentKind;
                Except
                    DocName := 'Unknown';
                    DocPath := '';
                    DocKind := 'Unknown';
                End;
                
                // Count by type
                If DocKind = 'SCH' Then
                    Inc(SchCount)
                Else If DocKind = 'PCB' Then
                    Inc(PCBCount)
                Else If (DocKind = 'SCHLIB') Or (DocKind = 'PCBLIB') Or (DocKind = 'INTLIB') Then
                    Inc(LibCount)
                Else
                    Inc(OtherCount);
                
                JSONStr := JSONStr + '    {' + #13#10;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(DocName) + '",' + #13#10;
                JSONStr := JSONStr + '      "path": "' + EscapeJsonString(DocPath) + '",' + #13#10;
                JSONStr := JSONStr + '      "type": "' + EscapeJsonString(DocKind) + '",' + #13#10;
                
                // Check if document is open
                Try
                    If Doc.DM_IsOpen Then
                        JSONStr := JSONStr + '      "is_open": true' + #13#10
                    Else
                        JSONStr := JSONStr + '      "is_open": false' + #13#10;
                Except
                    JSONStr := JSONStr + '      "is_open": false' + #13#10;
                End;
                
                JSONStr := JSONStr + '    }';
            End;
        End;
    Except
    End;
    
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // Statistics
    JSONStr := JSONStr + '  "statistics": {' + #13#10;
    JSONStr := JSONStr + '    "total_documents": ' + IntToStr(Project.DM_LogicalDocumentCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "schematic_count": ' + IntToStr(SchCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "pcb_count": ' + IntToStr(PCBCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "library_count": ' + IntToStr(LibCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "other_count": ' + IntToStr(OtherCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    JSONStr := JSONStr + '  "status": "active"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\project_info.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('SUCCESS! Project information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                        'Project: ' + PrjName + #13#10 +
                        'Total Documents: ' + IntToStr(Project.DM_LogicalDocumentCount) + #13#10 +
                        'Schematics: ' + IntToStr(SchCount) + #13#10 +
                        'PCBs: ' + IntToStr(PCBCount) + #13#10 +
                        'Libraries: ' + IntToStr(LibCount));
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;

// Get focused document type
Procedure GetFocusedDocumentType;
Var
    Workspace : IWorkspace;
    Doc       : IDocument;
    DocKind   : String;
    DocName   : String;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('No workspace available');
            Exit;
        End;
        
        Doc := Workspace.DM_FocusedDocument;
        If Doc = Nil Then
        Begin
            ShowMessage('No document is currently focused');
            Exit;
        End;
        
        DocKind := Doc.DM_DocumentKind;
        DocName := Doc.DM_FileName;
        
        ShowMessage('Focused Document:' + #13#10 +
                    'Name: ' + DocName + #13#10 +
                    'Type: ' + DocKind + #13#10 +
                    'Path: ' + Doc.DM_FullPath);
    Except
        ShowMessage('ERROR: Could not get focused document info');
    End;
End;

// Open a specific document in the project
Procedure OpenDocumentByPath(DocPath: String);
Var
    Workspace : IWorkspace;
    Project   : IProject;
    Doc       : IDocument;
    I         : Integer;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
        
        Project := Workspace.DM_FocusedProject;
        If Project = Nil Then Exit;
        
        // Find and open the document
        For I := 0 To Project.DM_LogicalDocumentCount - 1 Do
        Begin
            Doc := Project.DM_LogicalDocuments(I);
            If Doc <> Nil Then
            Begin
                If (Doc.DM_FullPath = DocPath) Or (Doc.DM_FileName = DocPath) Then
                Begin
                    // Open the document
                    Client.OpenDocument('', DocPath);
                    ShowMessage('Document opened: ' + Doc.DM_FileName);
                    Exit;
                End;
            End;
        End;
        
        ShowMessage('Document not found in project: ' + DocPath);
    Except
        ShowMessage('ERROR: Could not open document');
    End;
End;

// Close current document
Procedure CloseCurrentDocument;
Var
    Workspace : IWorkspace;
    Doc       : IDocument;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
        
        Doc := Workspace.DM_FocusedDocument;
        If Doc = Nil Then
        Begin
            ShowMessage('No document is currently focused');
            Exit;
        End;
        
        Client.CloseDocument(Doc);
        ShowMessage('Document closed');
    Except
        ShowMessage('ERROR: Could not close document');
    End;
End;

// List all available libraries
Procedure ListAvailableLibraries;
Var
    LibManager  : ILibraryManager;
    Lib         : ILibrary;
    I           : Integer;
    LibList     : String;
Begin
    Try
        LibManager := IntegratedLibraryManager;
        If LibManager = Nil Then
        Begin
            ShowMessage('Library Manager not available');
            Exit;
        End;
        
        LibList := 'Available Libraries:' + #13#10 + #13#10;
        
        For I := 0 To LibManager.InstalledLibraryCount - 1 Do
        Begin
            LibList := LibList + IntToStr(I + 1) + '. ' + LibManager.InstalledLibraryPath(I) + #13#10;
        End;
        
        If LibManager.InstalledLibraryCount = 0 Then
            LibList := LibList + '(No libraries installed)';
        
        ShowMessage(LibList);
    Except
        ShowMessage('ERROR: Could not access library manager');
    End;
End;

// Create a new Schematic document and add to current project
Procedure CreateSchematicDocument;
Var
    Workspace   : IWorkspace;
    Project      : IProject;
    Doc          : IDocument;
    DocName      : String;
    DocPath      : String;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        Project := Workspace.DM_FocusedProject;
        If Project = Nil Then
        Begin
            ShowMessage('ERROR: No project is currently open.' + #13#10 + #13#10 +
                        'Please open or create a project first.');
            Exit;
        End;
        
        // Get document name from user
        DocName := InputBox('Create Schematic Document', 
                           'Enter schematic name (without extension):', 
                           'Sheet1');
        If DocName = '' Then Exit;
        
        // Create new schematic document
        Try
            Doc := Client.CreateDocument('SCH', DocName + '.SchDoc', '');
            If Doc <> Nil Then
            Begin
                // Add to current project
                Project.DM_AddSourceDocument(Doc.DM_FullPath);
                
                // Open the document
                Client.ShowDocument(Doc);
                
                DocPath := Doc.DM_FullPath;
                ShowMessage('SUCCESS! Schematic document created:' + #13#10 +
                           'Name: ' + DocName + '.SchDoc' + #13#10 +
                           'Path: ' + DocPath + #13#10 + #13#10 +
                           'Document has been added to project and opened.');
            End
            Else
            Begin
                ShowMessage('ERROR: Could not create schematic document');
            End;
        Except
            ShowMessage('ERROR: Exception creating schematic document');
        End;
    Except
        ShowMessage('ERROR: Could not create schematic document');
    End;
End;

// Create a new PCB document and add to current project
Procedure CreatePCBDocument;
Var
    Workspace   : IWorkspace;
    Project      : IProject;
    Doc          : IDocument;
    DocName      : String;
    DocPath      : String;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        Project := Workspace.DM_FocusedProject;
        If Project = Nil Then
        Begin
            ShowMessage('ERROR: No project is currently open.' + #13#10 + #13#10 +
                        'Please open or create a project first.');
            Exit;
        End;
        
        // Get document name from user
        DocName := InputBox('Create PCB Document', 
                           'Enter PCB name (without extension):', 
                           'PCB1');
        If DocName = '' Then Exit;
        
        // Create new PCB document
        Try
            Doc := Client.CreateDocument('PCB', DocName + '.PcbDoc', '');
            If Doc <> Nil Then
            Begin
                // Add to current project
                Project.DM_AddSourceDocument(Doc.DM_FullPath);
                
                // Open the document
                Client.ShowDocument(Doc);
                
                DocPath := Doc.DM_FullPath;
                ShowMessage('SUCCESS! PCB document created:' + #13#10 +
                           'Name: ' + DocName + '.PcbDoc' + #13#10 +
                           'Path: ' + DocPath + #13#10 + #13#10 +
                           'Document has been added to project and opened.');
            End
            Else
            Begin
                ShowMessage('ERROR: Could not create PCB document');
            End;
        Except
            ShowMessage('ERROR: Exception creating PCB document');
        End;
    Except
        ShowMessage('ERROR: Could not create PCB document');
    End;
End;

// Create a new PCB Project
Procedure CreateNewProject;
Var
    Workspace   : IWorkspace;
    Project      : IProject;
    PrjName      : String;
    PrjPath      : String;
    PrjFullPath  : String;
Begin
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        // Get project name from user
        PrjName := InputBox('Create New Project', 
                           'Enter project name (without extension):', 
                           'MyProject');
        If PrjName = '' Then Exit;
        
        // Get project path (optional - will use default if empty)
        PrjPath := InputBox('Create New Project', 
                           'Enter project folder path (or leave empty for default):', 
                           '');
        
        // Create project full path
        If PrjPath = '' Then
        Begin
            // Use default workspace location
            PrjFullPath := PrjName + '.PrjPcb';
        End
        Else
        Begin
            PrjFullPath := PrjPath + '\' + PrjName + '.PrjPcb';
        End;
        
        // Create new PCB project
        Try
            Project := Workspace.DM_CreateProject('PCB', PrjFullPath);
            If Project <> Nil Then
            Begin
                // Open the project
                Workspace.DM_OpenProject(Project, True);
                
                ShowMessage('SUCCESS! New project created:' + #13#10 +
                           'Name: ' + PrjName + '.PrjPcb' + #13#10 +
                           'Path: ' + PrjFullPath + #13#10 + #13#10 +
                           'Project has been created and opened.' + #13#10 +
                           'You can now add schematic and PCB documents.');
            End
            Else
            Begin
                ShowMessage('ERROR: Could not create project');
            End;
        Except
            ShowMessage('ERROR: Exception creating project. Make sure the path is valid.');
        End;
    Except
        ShowMessage('ERROR: Could not create project');
    End;
End;

