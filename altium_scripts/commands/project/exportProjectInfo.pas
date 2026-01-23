{*
 * Export Project Information
 * Exports project info to project_info.json
 * Command: export_project_info
 * OPTIMIZED: Direct TStringList writing, limits, batch processing
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    WRITE_INTERVAL = 1;      // ULTRA-AGGRESSIVE: Write to file EVERY SINGLE ITEM (for 23GB Altium)
    BATCH_SIZE = 1;          // ULTRA-AGGRESSIVE: UI refresh after EVERY item (maximum memory cleanup)

// Helper function to escape JSON strings
Function EscapeJsonString(InputStr: String): String;
Var
    I: Integer;
    ResultStr: String;
    Ch: Char;
Begin
    ResultStr := '';
    If Length(InputStr) > 500 Then
        InputStr := Copy(InputStr, 1, 500);  // Limit string length
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

// Append buffer to file and clear it (ULTRA-AGGRESSIVE for 23GB Altium)
// Uses direct file append - NO file loading into memory
Procedure AppendBufferToFile(Var Buffer: TStringList; FileName: String);
Var
    OutputFile: TextFile;
    I: Integer;
    TempStr: String;
Begin
    If Buffer.Count = 0 Then Exit;
    
    Try
        // ULTRA-AGGRESSIVE: Direct file append - no memory loading
        AssignFile(OutputFile, FileName);
        Try
            If FileExists(FileName) Then
                Append(OutputFile)  // Append mode - doesn't load file
            Else
                Rewrite(OutputFile);  // Create new file
            
            // Write each line immediately
            For I := 0 To Buffer.Count - 1 Do
            Begin
                TempStr := Buffer[I];
                WriteLn(OutputFile, TempStr);
                TempStr := '';  // Clear immediately
            End;
            
            CloseFile(OutputFile);
        Except
            Try
                CloseFile(OutputFile);
            Except
            End;
        End;
        
        // ULTRA-AGGRESSIVE: Clear buffer immediately
        Buffer.Clear;
    Except
        // If write fails, clear buffer anyway
        Buffer.Clear;
    End;
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
    I             : Integer;
    FirstItem     : Boolean;
    DocKind       : String;
    DocName       : String;
    DocPath       : String;
    PrjName       : String;
    PrjPath       : String;
    PrjType       : String;
    SchCount      : Integer;
    PCBCount      : Integer;
    LibCount      : Integer;
    OtherCount    : Integer;
    IsOpen        : Boolean;
    DocCount      : Integer;
    BatchCounter  : Integer;
    SafetyCounter : Integer;
Begin
    // Initialize
    SchCount := 0;
    PCBCount := 0;
    LibCount := 0;
    OtherCount := 0;
    BatchCounter := 0;
    SafetyCounter := 0;
    
    Try
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
            If Length(PrjName) > 200 Then PrjName := Copy(PrjName, 1, 200);
        Except
            PrjName := 'Unknown';
        End;
        
        Try
            PrjPath := Project.DM_ProjectFullPath;
            If Length(PrjPath) > 500 Then PrjPath := Copy(PrjPath, 1, 500);
        Except
            PrjPath := '';
        End;
        
        Try
            PrjType := Project.DM_ObjectKindString;
            If Length(PrjType) > 100 Then PrjType := Copy(PrjType, 1, 100);
        Except
            PrjType := 'PCB Project';
        End;
        
        // Get focused document for open status check
        Try
            FocusedDoc := Workspace.DM_FocusedDocument;
        Except
            FocusedDoc := Nil;
        End;
        
        // Get document count
        Try
            DocCount := Project.DM_LogicalDocumentCount;
            // NO LIMIT - process all documents
        Except
            DocCount := 0;
        End;
        
        // Create output file early - write directly
        OutputFile := TStringList.Create;
        Try
            OutputFile.Add('{');
            OutputFile.Add('  "project": {');
            OutputFile.Add('    "name": "' + EscapeJsonString(PrjName) + '",');
            OutputFile.Add('    "path": "' + EscapeJsonString(PrjPath) + '",');
            OutputFile.Add('    "type": "' + EscapeJsonString(PrjType) + '"');
            OutputFile.Add('  },');
            OutputFile.Add('  "documents": [');
            
            // Process documents - write directly to TStringList
            FirstItem := True;
            Try
                For I := 0 To DocCount - 1 Do
                Begin
                    // ULTRA-AGGRESSIVE: Write to file after EVERY item
                    If I Mod WRITE_INTERVAL = 0 Then
                    Begin
                        Try
                            AppendBufferToFile(OutputFile, FileName);
                        Except
                            OutputFile.Clear;
                        End;
                    End;
                    
                    // ULTRA-AGGRESSIVE: UI refresh after EVERY item
                    If I Mod BATCH_SIZE = 0 Then
                    Begin
                        Try
                            Application.ProcessMessages;
                            Sleep(5);
                        Except
                        End;
                    End;
                    
                    Inc(SafetyCounter);
                    
                    Try
                        Doc := Project.DM_LogicalDocuments(I);
                        If Doc <> Nil Then
                        Begin
                            // Get document properties with limits
                            Try
                                DocName := Doc.DM_FileName;
                                If Length(DocName) > 200 Then DocName := Copy(DocName, 1, 200);
                            Except
                                DocName := 'Unknown';
                            End;
                            
                            Try
                                DocPath := Doc.DM_FullPath;
                                If Length(DocPath) > 500 Then DocPath := Copy(DocPath, 1, 500);
                            Except
                                DocPath := '';
                            End;
                            
                            Try
                                DocKind := Doc.DM_DocumentKind;
                            Except
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
                            
                            // Write document entry directly
                            If Not FirstItem Then
                                OutputFile.Add(',');
                            FirstItem := False;
                            
                            OutputFile.Add('    {');
                            OutputFile.Add('      "name": "' + EscapeJsonString(DocName) + '",');
                            OutputFile.Add('      "path": "' + EscapeJsonString(DocPath) + '",');
                            OutputFile.Add('      "type": "' + EscapeJsonString(DocKind) + '",');
                            If IsOpen Then
                                OutputFile.Add('      "is_open": true')
                            Else
                                OutputFile.Add('      "is_open": false');
                            OutputFile.Add('    }');
                            
                            // Batch processing - allow UI refresh
                            Inc(BatchCounter);
                            If BatchCounter >= BATCH_SIZE Then
                            Begin
                                BatchCounter := 0;
                                Application.ProcessMessages;
                                Sleep(1);  // Yield control
                            End;
                        End;
                    Except
                        // Skip problematic documents
                    End;
                End;
            Except
                // Continue even if iteration fails
            End;
            
            OutputFile.Add('  ],');
            
            // Statistics
            OutputFile.Add('  "statistics": {');
            OutputFile.Add('    "total_documents": ' + IntToStr(SafetyCounter) + ',');
            OutputFile.Add('    "schematic_count": ' + IntToStr(SchCount) + ',');
            OutputFile.Add('    "pcb_count": ' + IntToStr(PCBCount) + ',');
            OutputFile.Add('    "library_count": ' + IntToStr(LibCount) + ',');
            OutputFile.Add('    "other_count": ' + IntToStr(OtherCount));
            OutputFile.Add('  },');
            OutputFile.Add('  "status": "active"');
            OutputFile.Add('}');
            
            // Write to file
            FileName := BASE_PATH + 'project_info.json';
            // Write final buffer
            AppendBufferToFile(OutputFile, FileName);
            
            // Finalize JSON - read file, add closing bracket
            Try
                OutputFile.LoadFromFile(FileName);
                // Remove any existing closing bracket
                While (OutputFile.Count > 0) And (Trim(OutputFile[OutputFile.Count - 1]) = '}') Do
                    OutputFile.Delete(OutputFile.Count - 1);
                OutputFile.Add('}');
                OutputFile.SaveToFile(FileName);
            Except
            End;
        Finally
            OutputFile.Free;
        End;
        
        // Show success message after cleanup
        ShowMessage('SUCCESS! Project information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                    'Project: ' + PrjName + #13#10 +
                    'Total Documents: ' + IntToStr(SafetyCounter) + #13#10 +
                    'Schematics: ' + IntToStr(SchCount) + #13#10 +
                    'PCBs: ' + IntToStr(PCBCount) + #13#10 +
                    'Libraries: ' + IntToStr(LibCount));
    Except
        ShowMessage('ERROR: Unexpected error during export');
    End;
End;
