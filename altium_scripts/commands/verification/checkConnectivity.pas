{*
 * Check Connectivity Command
 * Checks connectivity and exports results
 * Command: check_connectivity
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
                    
                    // Check if net has routing
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
        FileName := BASE_PATH + 'connectivity_report.json';
        
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
