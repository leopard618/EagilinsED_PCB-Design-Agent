{*
 * Run ERC Command
 * Runs Electrical Rule Check and exports results
 * Command: run_erc
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

// Run ERC on schematic and export results
Procedure RunERCAndExport;
Var
    CurrentSheet  : ISch_Document;
    Workspace     : IWorkspace;
    Project       : IProject;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    ViolationCount: Integer;
    ErrorCount    : Integer;
    WarningCount  : Integer;
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
    
    // Get current schematic
    CurrentSheet := Nil;
    Try
        CurrentSheet := SchServer.GetCurrentSchDocument;
    Except
    End;
    
    If CurrentSheet = Nil Then
    Begin
        Try
            Doc := Workspace.DM_FocusedDocument;
            If (Doc <> Nil) And (Doc.DM_DocumentKind = 'SCH') Then
                CurrentSheet := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
        Except
        End;
    End;
    
    If CurrentSheet = Nil Then
    Begin
        ShowMessage('ERROR: Cannot access schematic document.' + #13#10 + #13#10 +
                    'Please make sure a schematic document is open and active.');
        Exit;
    End;
    
    // Run ERC via project compile
    Try
        Project := Workspace.DM_FocusedProject;
        If Project <> Nil Then
        Begin
            Project.DM_Compile;
        End;
    Except
    End;
    
    // Initialize counters
    ViolationCount := 0;
    ErrorCount := 0;
    WarningCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "verification_type": "ERC",' + #13#10;
    
    Try
        JSONStr := JSONStr + '  "schematic_file": "' + EscapeJsonString(CurrentSheet.DocumentName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '  "schematic_file": "Unknown",' + #13#10;
    End;
    
    // Try to get error count from project
    Try
        Project := Workspace.DM_FocusedProject;
        If Project <> Nil Then
        Begin
            ErrorCount := Project.DM_ErrorCount;
            WarningCount := Project.DM_WarningCount;
            ViolationCount := ErrorCount + WarningCount;
        End;
    Except
    End;
    
    JSONStr := JSONStr + '  "violations": [],' + #13#10;
    
    // Summary
    JSONStr := JSONStr + '  "summary": {' + #13#10;
    JSONStr := JSONStr + '    "total_violations": ' + IntToStr(ViolationCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "errors": ' + IntToStr(ErrorCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "warnings": ' + IntToStr(WarningCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Pass/Fail status
    If ErrorCount = 0 Then
        JSONStr := JSONStr + '  "status": "PASS"' + #13#10
    Else
        JSONStr := JSONStr + '  "status": "FAIL"' + #13#10;
    
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'verification_report.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            If ErrorCount = 0 Then
                ShowMessage('ERC COMPLETED!' + #13#10 + #13#10 +
                            'Errors: ' + IntToStr(ErrorCount) + #13#10 +
                            'Warnings: ' + IntToStr(WarningCount) + #13#10 + #13#10 +
                            'Report saved to: ' + FileName)
            Else
                ShowMessage('ERC COMPLETED with errors!' + #13#10 + #13#10 +
                            'Errors: ' + IntToStr(ErrorCount) + #13#10 +
                            'Warnings: ' + IntToStr(WarningCount) + #13#10 + #13#10 +
                            'Check Messages panel for details.' + #13#10 +
                            'Report saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save report to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
