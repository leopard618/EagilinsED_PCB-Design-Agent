{*
 * Check Connectivity Command
 * Checks connectivity and exports results
 * Command: check_connectivity
 * OPTIMIZED: Direct TStringList writing, removed JSONStr concatenation, limits
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    MAX_NETS = 5000;      // Safety limit
    BATCH_SIZE = 100;     // Process in batches

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
    TotalNets     : Integer;
    RoutedNets    : Integer;
    UnroutedNets  : Integer;
    FirstItem     : Boolean;
    HasConnections: Boolean;
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
        ShowMessage('ERROR: Cannot access PCB board.');
        Exit;
    End;
    
    // Initialize counters
    TotalNets := 0;
    RoutedNets := 0;
    UnroutedNets := 0;
    BatchCounter := 0;
    
    // Create output file
    OutputFile := TStringList.Create;
    Try
        // Start JSON
        OutputFile.Add('{');
        OutputFile.Add('  "check_type": "Connectivity",');
        
        Try
            OutputFile.Add('  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",');
        Except
            OutputFile.Add('  "pcb_file": "Unknown",');
        End;
        
        // Unrouted nets
        OutputFile.Add('  "unrouted_nets": [');
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
                    While (Net <> Nil) And (TotalNets < MAX_NETS) Do
                    Begin
                        Inc(TotalNets);
                        Inc(BatchCounter);
                        
                        // UI refresh every BATCH_SIZE items
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(1);
                        End;
                        
                        // Check if net has routing
                        HasConnections := (Net.TrackCount > 0) Or (Net.ViaCount > 0);
                        
                        If HasConnections Then
                            Inc(RoutedNets)
                        Else
                        Begin
                            Inc(UnroutedNets);
                            
                            If Not FirstItem Then
                                OutputFile.Add(',');
                            FirstItem := False;
                            
                            Try
                                OutputFile.Add('    "' + EscapeJsonString(Net.Name) + '"');
                            Except
                                OutputFile.Add('    "Unknown"');
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
        
        OutputFile.Add('  ],');
        
        // Summary
        OutputFile.Add('  "summary": {');
        OutputFile.Add('    "total_nets": ' + IntToStr(TotalNets) + ',');
        OutputFile.Add('    "routed_nets": ' + IntToStr(RoutedNets) + ',');
        OutputFile.Add('    "unrouted_nets": ' + IntToStr(UnroutedNets) + ',');
        If TotalNets > 0 Then
            OutputFile.Add('    "routing_completion": ' + FormatFloat('0.0', (RoutedNets / TotalNets) * 100))
        Else
            OutputFile.Add('    "routing_completion": 0');
        OutputFile.Add('  },');
        
        // Status
        If UnroutedNets = 0 Then
            OutputFile.Add('  "status": "COMPLETE"')
        Else
            OutputFile.Add('  "status": "INCOMPLETE"');
        
        OutputFile.Add('}');
        
        // Save to file
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
