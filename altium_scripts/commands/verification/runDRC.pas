{*
 * Run DRC Command
 * Runs Design Rule Check and exports results
 * Command: run_drc
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

// Run DRC and export results
Procedure RunDRCAndExport;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    Violation     : IPCB_Violation;
    Iterator      : IPCB_BoardIterator;
    ViolationCount: Integer;
    ErrorCount    : Integer;
    WarningCount  : Integer;
    FirstItem     : Boolean;
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
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
        Try
            Doc := Workspace.DM_FocusedDocument;
            If (Doc <> Nil) And (Doc.DM_DocumentKind = 'PCB') Then
                PCB := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
        Except
        End;
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: Cannot access PCB board.' + #13#10 + #13#10 +
                    'Please make sure a PCB document is open and active.');
        Exit;
    End;
    
    // Run DRC
    Try
        PCB.RunDRC;
    Except
        ShowMessage('ERROR: Failed to run DRC');
        Exit;
    End;
    
    // Initialize counters
    ViolationCount := 0;
    ErrorCount := 0;
    WarningCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "verification_type": "DRC",' + #13#10;
    
    Try
        JSONStr := JSONStr + '  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '  "pcb_file": "Unknown",' + #13#10;
    End;
    
    // Get violations
    JSONStr := JSONStr + '  "violations": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eViolationObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Violation := Iterator.FirstPCBObject;
                While Violation <> Nil Do
                Begin
                    Inc(ViolationCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    JSONStr := JSONStr + '      "id": "DRC' + IntToStr(ViolationCount) + '",' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "rule": "' + EscapeJsonString(Violation.Rule.Name) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "rule": "Unknown",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "description": "' + EscapeJsonString(Violation.Description) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "description": "",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "severity": "error",' + #13#10;
                        Inc(ErrorCount);
                    Except
                        JSONStr := JSONStr + '      "severity": "unknown",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "location": {' + #13#10;
                        JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Violation.X)) + ',' + #13#10;
                        JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Violation.Y)) + #13#10;
                        JSONStr := JSONStr + '      }' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "location": {"x_mm": 0, "y_mm": 0}' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    Violation := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // Summary
    JSONStr := JSONStr + '  "summary": {' + #13#10;
    JSONStr := JSONStr + '    "total_violations": ' + IntToStr(ViolationCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "errors": ' + IntToStr(ErrorCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "warnings": ' + IntToStr(WarningCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Pass/Fail status
    If ViolationCount = 0 Then
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
            If ViolationCount = 0 Then
                ShowMessage('DRC PASSED!' + #13#10 + #13#10 +
                            'No violations found.' + #13#10 + #13#10 +
                            'Report saved to: ' + FileName)
            Else
                ShowMessage('DRC COMPLETED with violations!' + #13#10 + #13#10 +
                            'Violations: ' + IntToStr(ViolationCount) + #13#10 +
                            'Errors: ' + IntToStr(ErrorCount) + #13#10 +
                            'Warnings: ' + IntToStr(WarningCount) + #13#10 + #13#10 +
                            'Report saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save report to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
