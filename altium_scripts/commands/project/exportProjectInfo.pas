{*
 * Export Project Information
 * Exports project info to project_info.json
 * Command: export_project_info
 *}

Const
    BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\';

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
    FocusedDoc    : IDocument;
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
    IsOpen        : Boolean;
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
    
    Try
        JSONStr := JSONStr + '    "type": "' + EscapeJsonString(Project.DM_ObjectKindString) + '"' + #13#10;
    Except
        JSONStr := JSONStr + '    "type": "PCB Project"' + #13#10;
    End;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Get focused document for open status check
    Try
        FocusedDoc := Workspace.DM_FocusedDocument;
    Except
        FocusedDoc := Nil;
    End;
    
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
                
                // Check if document is open
                IsOpen := False;
                Try
                    If (FocusedDoc <> Nil) And (Doc <> Nil) Then
                    Begin
                        If FocusedDoc.DM_FullPath = Doc.DM_FullPath Then
                            IsOpen := True;
                    End;
                Except
                    IsOpen := False;
                End;
                
                JSONStr := JSONStr + '    {' + #13#10;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(DocName) + '",' + #13#10;
                JSONStr := JSONStr + '      "path": "' + EscapeJsonString(DocPath) + '",' + #13#10;
                JSONStr := JSONStr + '      "type": "' + EscapeJsonString(DocKind) + '",' + #13#10;
                
                If IsOpen Then
                    JSONStr := JSONStr + '      "is_open": true' + #13#10
                Else
                    JSONStr := JSONStr + '      "is_open": false' + #13#10;
                
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
        FileName := BASE_PATH + 'project_info.json';
        
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
