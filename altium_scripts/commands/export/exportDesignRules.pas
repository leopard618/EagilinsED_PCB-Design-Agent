{*
 * Export Design Rules Command
 * Exports design rules to design_rules.json
 * Command: export_design_rules
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

// Export all design rules to JSON
Procedure ExportDesignRules;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Rule          : IPCB_Rule;
    Iterator      : IPCB_BoardIterator;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    FirstItem     : Boolean;
    RuleCount     : Integer;
    ClearanceCount: Integer;
    WidthCount    : Integer;
    ViaCount      : Integer;
    OtherCount    : Integer;
    RuleName      : String;
    RuleEnabled   : Boolean;
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
    
    // Initialize counters
    RuleCount := 0;
    ClearanceCount := 0;
    WidthCount := 0;
    ViaCount := 0;
    OtherCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    
    Try
        JSONStr := JSONStr + '  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '  "pcb_file": "Unknown",' + #13#10;
    End;
    
    // ========== CLEARANCE RULES ==========
    JSONStr := JSONStr + '  "clearance_rules": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Rule := Iterator.FirstPCBObject;
                While Rule <> Nil Do
                Begin
                    Inc(RuleCount);
                    
                    Try
                        RuleName := Rule.Name;
                        RuleEnabled := Rule.Enabled;
                    Except
                        RuleName := 'Unknown';
                        RuleEnabled := True;
                    End;
                    
                    If Rule.RuleKind = eRule_Clearance Then
                    Begin
                        Inc(ClearanceCount);
                        
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(RuleName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "enabled": ' + BoolToStr(RuleEnabled, True) + ',' + #13#10;
                        
                        Try
                            JSONStr := JSONStr + '      "minimum_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.Gap)) + ',' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "minimum_mm": 0,' + #13#10;
                        End;
                        
                        Try
                            JSONStr := JSONStr + '      "scope": "' + EscapeJsonString(Rule.Scope1Expression) + '"' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "scope": "All"' + #13#10;
                        End;
                        
                        JSONStr := JSONStr + '    }';
                    End;
                    
                    Rule := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== WIDTH RULES ==========
    JSONStr := JSONStr + '  "width_rules": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Rule := Iterator.FirstPCBObject;
                While Rule <> Nil Do
                Begin
                    Try
                        RuleName := Rule.Name;
                        RuleEnabled := Rule.Enabled;
                    Except
                        RuleName := 'Unknown';
                        RuleEnabled := True;
                    End;
                    
                    If Rule.RuleKind = eRule_Width Then
                    Begin
                        Inc(WidthCount);
                        
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(RuleName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "enabled": ' + BoolToStr(RuleEnabled, True) + ',' + #13#10;
                        
                        Try
                            JSONStr := JSONStr + '      "min_width_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.MinWidth)) + ',' + #13#10;
                            JSONStr := JSONStr + '      "preferred_width_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.PreferedWidth)) + ',' + #13#10;
                            JSONStr := JSONStr + '      "max_width_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.MaxWidth)) + ',' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "min_width_mm": 0,' + #13#10;
                            JSONStr := JSONStr + '      "preferred_width_mm": 0,' + #13#10;
                            JSONStr := JSONStr + '      "max_width_mm": 0,' + #13#10;
                        End;
                        
                        Try
                            JSONStr := JSONStr + '      "scope": "' + EscapeJsonString(Rule.Scope1Expression) + '"' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "scope": "All"' + #13#10;
                        End;
                        
                        JSONStr := JSONStr + '    }';
                    End;
                    
                    Rule := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== VIA RULES ==========
    JSONStr := JSONStr + '  "via_rules": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Rule := Iterator.FirstPCBObject;
                While Rule <> Nil Do
                Begin
                    Try
                        RuleName := Rule.Name;
                        RuleEnabled := Rule.Enabled;
                    Except
                        RuleName := 'Unknown';
                        RuleEnabled := True;
                    End;
                    
                    If Rule.RuleKind = eRule_RoutingViaStyle Then
                    Begin
                        Inc(ViaCount);
                        
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(RuleName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "enabled": ' + BoolToStr(RuleEnabled, True) + ',' + #13#10;
                        
                        Try
                            JSONStr := JSONStr + '      "via_diameter_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.MinWidth)) + ',' + #13#10;
                            JSONStr := JSONStr + '      "hole_size_mm": ' + FormatFloat('0.000', CoordToMMs(Rule.MinHoleWidth)) + ',' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "via_diameter_mm": 0,' + #13#10;
                            JSONStr := JSONStr + '      "hole_size_mm": 0,' + #13#10;
                        End;
                        
                        Try
                            JSONStr := JSONStr + '      "scope": "' + EscapeJsonString(Rule.Scope1Expression) + '"' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "scope": "All"' + #13#10;
                        End;
                        
                        JSONStr := JSONStr + '    }';
                    End;
                    
                    Rule := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== STATISTICS ==========
    OtherCount := RuleCount - ClearanceCount - WidthCount - ViaCount;
    
    JSONStr := JSONStr + '  "statistics": {' + #13#10;
    JSONStr := JSONStr + '    "total_rules": ' + IntToStr(RuleCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "clearance_rules": ' + IntToStr(ClearanceCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "width_rules": ' + IntToStr(WidthCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "via_rules": ' + IntToStr(ViaCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "other_rules": ' + IntToStr(OtherCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'design_rules.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Design Rules Exported!' + #13#10 + #13#10 +
                        'Total Rules: ' + IntToStr(RuleCount) + #13#10 +
                        'Clearance: ' + IntToStr(ClearanceCount) + #13#10 +
                        'Width: ' + IntToStr(WidthCount) + #13#10 +
                        'Via: ' + IntToStr(ViaCount) + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
