{*
 * Run DRC Command
 * Runs Design Rule Check and exports results
 * Command: run_drc
 * OPTIMIZED: Direct TStringList writing, removed JSONStr concatenation, limits
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    MAX_VIOLATIONS = 1000;  // Safety limit
    BATCH_SIZE = 50;        // Process in batches

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

// Run DRC and export results
Procedure RunDRCAndExport;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    Violation     : IPCB_Violation;
    Iterator      : IPCB_BoardIterator;
    ViolationCount: Integer;
    ErrorCount    : Integer;
    WarningCount  : Integer;
    FirstItem     : Boolean;
    BatchCounter  : Integer;
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
    BatchCounter := 0;
    
    // Create output file
    OutputFile := TStringList.Create;
    Try
        // Start JSON
        OutputFile.Add('{');
        OutputFile.Add('  "verification_type": "DRC",');
        
        Try
            OutputFile.Add('  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",');
        Except
            OutputFile.Add('  "pcb_file": "Unknown",');
        End;
        
        // Get violations
        OutputFile.Add('  "violations": [');
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
                    While (Violation <> Nil) And (ViolationCount < MAX_VIOLATIONS) Do
                    Begin
                        Inc(ViolationCount);
                        Inc(BatchCounter);
                        
                        // UI refresh every BATCH_SIZE items
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(1);
                        End;
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        OutputFile.Add('      "id": "DRC' + IntToStr(ViolationCount) + '",');
                        
                        Try
                            OutputFile.Add('      "rule": "' + EscapeJsonString(Violation.Rule.Name) + '",');
                        Except
                            OutputFile.Add('      "rule": "Unknown",');
                        End;
                        
                        Try
                            OutputFile.Add('      "description": "' + EscapeJsonString(Violation.Description) + '",');
                        Except
                            OutputFile.Add('      "description": "",');
                        End;
                        
                        Try
                            OutputFile.Add('      "severity": "error",');
                            Inc(ErrorCount);
                        Except
                            OutputFile.Add('      "severity": "unknown",');
                        End;
                        
                        Try
                            OutputFile.Add('      "location": {');
                            OutputFile.Add('        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Violation.X)) + ',');
                            OutputFile.Add('        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Violation.Y)));
                            OutputFile.Add('      }');
                        Except
                            OutputFile.Add('      "location": {"x_mm": 0, "y_mm": 0}');
                        End;
                        
                        OutputFile.Add('    }');
                        
                        Violation := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        
        OutputFile.Add('  ],');
        
        // Summary
        OutputFile.Add('  "summary": {');
        OutputFile.Add('    "total_violations": ' + IntToStr(ViolationCount) + ',');
        OutputFile.Add('    "errors": ' + IntToStr(ErrorCount) + ',');
        OutputFile.Add('    "warnings": ' + IntToStr(WarningCount));
        OutputFile.Add('  },');
        
        // Pass/Fail status
        If ViolationCount = 0 Then
            OutputFile.Add('  "status": "PASS"')
        Else
            OutputFile.Add('  "status": "FAIL"');
        
        OutputFile.Add('}');
        
        // Save to file
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
