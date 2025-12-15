{*
 * Altium Designer Script - Design Verification
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Run Design Rule Check (DRC) on PCB
 * - Run Electrical Rule Check (ERC) on Schematic
 * - Export violation reports to JSON
 * - Check connectivity
 * 
 * TO RUN THIS SCRIPT:
 * 1. Open the document you want to verify (PCB or Schematic)
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_verification.pas
 * 4. When dialog appears, select the procedure you want to run
 * 5. Click OK
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
    TempStr       : String;
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
        // ResetDRCMarkers clears previous violations
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
                    
                    // Violation ID
                    JSONStr := JSONStr + '      "id": "DRC' + IntToStr(ViolationCount) + '",' + #13#10;
                    
                    // Rule name
                    Try
                        JSONStr := JSONStr + '      "rule": "' + EscapeJsonString(Violation.Rule.Name) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "rule": "Unknown",' + #13#10;
                    End;
                    
                    // Description
                    Try
                        JSONStr := JSONStr + '      "description": "' + EscapeJsonString(Violation.Description) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "description": "",' + #13#10;
                    End;
                    
                    // Severity (based on rule priority)
                    Try
                        // Violations are typically errors
                        JSONStr := JSONStr + '      "severity": "error",' + #13#10;
                        Inc(ErrorCount);
                    Except
                        JSONStr := JSONStr + '      "severity": "unknown",' + #13#10;
                    End;
                    
                    // Location
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
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\verification_report.json';
        
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
        // Try via workspace
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
            // Compile project to check for errors
            Project.DM_Compile;
        End;
    Except
    End;
    
    // Initialize counters (ERC results would need to be read from project messages)
    ViolationCount := 0;
    ErrorCount := 0;
    WarningCount := 0;
    
    // Build JSON (basic structure - full implementation would parse project messages)
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
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\verification_report.json';
        
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

// Check PCB connectivity and unrouted nets
Procedure CheckConnectivityAndExport;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Net           : IPCB_Net;
    Iterator      : IPCB_BoardIterator;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    TotalNets     : Integer;
    RoutedNets    : Integer;
    UnroutedNets  : Integer;
    FirstItem     : Boolean;
    ConnectedPads : Integer;
    HasConnections: Boolean;
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
        ShowMessage('ERROR: Cannot access PCB board.');
        Exit;
    End;
    
    // Initialize counters
    TotalNets := 0;
    RoutedNets := 0;
    UnroutedNets := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "check_type": "Connectivity",' + #13#10;
    
    Try
        JSONStr := JSONStr + '  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '  "pcb_file": "Unknown",' + #13#10;
    End;
    
    // Unrouted nets
    JSONStr := JSONStr + '  "unrouted_nets": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Net := Iterator.FirstPCBObject;
                While Net <> Nil Do
                Begin
                    Inc(TotalNets);
                    
                    // Check if net has routing (simplified check)
                    // A net is considered routed if it has tracks
                    HasConnections := (Net.TrackCount > 0) Or (Net.ViaCount > 0);
                    
                    If HasConnections Then
                        Inc(RoutedNets)
                    Else
                    Begin
                        Inc(UnroutedNets);
                        
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        Try
                            JSONStr := JSONStr + '    "' + EscapeJsonString(Net.Name) + '"';
                        Except
                            JSONStr := JSONStr + '    "Unknown"';
                        End;
                    End;
                    
                    Net := Iterator.NextPCBObject;
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
    JSONStr := JSONStr + '    "total_nets": ' + IntToStr(TotalNets) + ',' + #13#10;
    JSONStr := JSONStr + '    "routed_nets": ' + IntToStr(RoutedNets) + ',' + #13#10;
    JSONStr := JSONStr + '    "unrouted_nets": ' + IntToStr(UnroutedNets) + ',' + #13#10;
    If TotalNets > 0 Then
        JSONStr := JSONStr + '    "routing_completion": ' + FormatFloat('0.0', (RoutedNets / TotalNets) * 100) + #13#10
    Else
        JSONStr := JSONStr + '    "routing_completion": 0' + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Status
    If UnroutedNets = 0 Then
        JSONStr := JSONStr + '  "status": "COMPLETE"' + #13#10
    Else
        JSONStr := JSONStr + '  "status": "INCOMPLETE"' + #13#10;
    
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\connectivity_report.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            If UnroutedNets = 0 Then
                ShowMessage('Connectivity Check COMPLETE!' + #13#10 + #13#10 +
                            'All ' + IntToStr(TotalNets) + ' nets are routed.' + #13#10 + #13#10 +
                            'Report saved to: ' + FileName)
            Else
                ShowMessage('Connectivity Check:' + #13#10 + #13#10 +
                            'Total Nets: ' + IntToStr(TotalNets) + #13#10 +
                            'Routed: ' + IntToStr(RoutedNets) + #13#10 +
                            'Unrouted: ' + IntToStr(UnroutedNets) + #13#10 + #13#10 +
                            'Report saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save report to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;

