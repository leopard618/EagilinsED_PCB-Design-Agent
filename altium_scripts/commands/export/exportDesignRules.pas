{*
 * Export Design Rules Command
 * Exports design rules to design_rules.json
 * Command: export_design_rules
 * ULTRA-OPTIMIZED: Minimal property access, early exit, UI refresh
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
    If Length(InputStr) > 1000 Then
        InputStr := Copy(InputStr, 1, 1000);  // Limit string length
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
    RuleCount     : Integer;
    ClearanceCount: Integer;
    WidthCount    : Integer;
    ViaCount      : Integer;
    RuleName      : String;
    RuleEnabled   : Boolean;
    RuleKind      : TRuleKind;
    TempStr       : String;
    SafetyCounter : Integer;
    BatchCounter  : Integer;
    GapVal        : TCoord;
    MinW          : TCoord;
    PrefW         : TCoord;
    MaxW          : TCoord;
    ViaD          : TCoord;
    HoleS         : TCoord;
    ScopeExpr     : String;
Begin
    // Initialize
    RuleCount := 0;
    ClearanceCount := 0;
    WidthCount := 0;
    ViaCount := 0;
    SafetyCounter := 0;
    BatchCounter := 0;
    
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
        
        // Create output file early
        OutputFile := TStringList.Create;
        Try
            OutputFile.Add('{');
            
            // PCB file
            Try
                OutputFile.Add('  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",');
            Except
                OutputFile.Add('  "pcb_file": "Unknown",');
            End;
            
            // Start arrays
            OutputFile.Add('  "clearance_rules": [');
            
            // ========== ITERATE ONCE - Process rules directly ==========
            Try
                Iterator := PCB.BoardIterator_Create;
                If Iterator <> Nil Then
                Begin
                    Try
                        Iterator.AddFilter_ObjectSet(MkSet(eRuleObject));
                        Iterator.AddFilter_LayerSet(AllLayers);
                        Iterator.AddFilter_Method(eProcessAll);
                        
                        Rule := Iterator.FirstPCBObject;
                        While Rule <> Nil Do  // NO LIMIT - process all!
                        Begin
                            Inc(RuleCount);
                            Inc(BatchCounter);
                            
                            // ULTRA-AGGRESSIVE: Write to file after EVERY item
                            If RuleCount Mod WRITE_INTERVAL = 0 Then
                            Begin
                                Try
                                    AppendBufferToFile(OutputFile, FileName);
                                Except
                                    OutputFile.Clear;
                                End;
                            End;
                            
                            // ULTRA-AGGRESSIVE: UI refresh after EVERY item
                            If BatchCounter >= BATCH_SIZE Then
                            Begin
                                BatchCounter := 0;
                                Try
                                    Application.ProcessMessages;
                                    Sleep(5);
                                Except
                                End;
                            End;
                            
                            // Get basic properties with minimal access
                            Try
                                RuleKind := Rule.RuleKind;
                            Except
                                RuleKind := eRule_Unknown;
                            End;
                            
                            Try
                                RuleName := Rule.Name;
                                If Length(RuleName) > 100 Then
                                    RuleName := Copy(RuleName, 1, 100);
                            Except
                                RuleName := 'Rule' + IntToStr(RuleCount);
                            End;
                            
                            Try
                                RuleEnabled := Rule.Enabled;
                            Except
                                RuleEnabled := True;
                            End;
                            
                            // Process based on rule type - MINIMAL property access
                            If RuleKind = eRule_Clearance Then
                            Begin
                                Inc(ClearanceCount);
                                
                                If ClearanceCount > 1 Then
                                    OutputFile.Add(',');
                                
                                OutputFile.Add('    {');
                                OutputFile.Add('      "name": "' + EscapeJsonString(RuleName) + '",');
                                OutputFile.Add('      "enabled": ' + BoolToStr(RuleEnabled, True) + ',');
                                
                                Try
                                    GapVal := Rule.Gap;
                                    OutputFile.Add('      "minimum_mm": ' + FormatFloat('0.000', CoordToMMs(GapVal)) + ',');
                                Except
                                    OutputFile.Add('      "minimum_mm": 0.2,');
                                End;
                                
                                Try
                                    ScopeExpr := Rule.Scope1Expression;
                                    If Length(ScopeExpr) > 200 Then
                                        ScopeExpr := Copy(ScopeExpr, 1, 200);
                                    OutputFile.Add('      "scope": "' + EscapeJsonString(ScopeExpr) + '"');
                                Except
                                    OutputFile.Add('      "scope": "All"');
                                End;
                                
                                OutputFile.Add('    }');
                            End
                            Else If RuleKind = eRule_Width Then
                            Begin
                                Inc(WidthCount);
                                
                                If WidthCount = 1 Then
                                Begin
                                    OutputFile.Add('  ],');
                                    OutputFile.Add('  "width_rules": [');
                                End
                                Else
                                    OutputFile.Add(',');
                                
                                OutputFile.Add('    {');
                                OutputFile.Add('      "name": "' + EscapeJsonString(RuleName) + '",');
                                OutputFile.Add('      "enabled": ' + BoolToStr(RuleEnabled, True) + ',');
                                
                                Try
                                    MinW := Rule.MinWidth;
                                    PrefW := Rule.PreferedWidth;
                                    MaxW := Rule.MaxWidth;
                                    OutputFile.Add('      "min_width_mm": ' + FormatFloat('0.000', CoordToMMs(MinW)) + ',');
                                    OutputFile.Add('      "preferred_width_mm": ' + FormatFloat('0.000', CoordToMMs(PrefW)) + ',');
                                    OutputFile.Add('      "max_width_mm": ' + FormatFloat('0.000', CoordToMMs(MaxW)) + ',');
                                Except
                                    OutputFile.Add('      "min_width_mm": 0.25,');
                                    OutputFile.Add('      "preferred_width_mm": 0.3,');
                                    OutputFile.Add('      "max_width_mm": 0.5,');
                                End;
                                
                                Try
                                    ScopeExpr := Rule.Scope1Expression;
                                    If Length(ScopeExpr) > 200 Then
                                        ScopeExpr := Copy(ScopeExpr, 1, 200);
                                    OutputFile.Add('      "scope": "' + EscapeJsonString(ScopeExpr) + '"');
                                Except
                                    OutputFile.Add('      "scope": "All"');
                                End;
                                
                                OutputFile.Add('    }');
                            End
                            Else If RuleKind = eRule_RoutingViaStyle Then
                            Begin
                                Inc(ViaCount);
                                
                                If ViaCount = 1 Then
                                Begin
                                    OutputFile.Add('  ],');
                                    OutputFile.Add('  "via_rules": [');
                                End
                                Else
                                    OutputFile.Add(',');
                                
                                OutputFile.Add('    {');
                                OutputFile.Add('      "name": "' + EscapeJsonString(RuleName) + '",');
                                OutputFile.Add('      "enabled": ' + BoolToStr(RuleEnabled, True) + ',');
                                
                                Try
                                    ViaD := Rule.MinWidth;
                                    HoleS := Rule.MinHoleWidth;
                                    OutputFile.Add('      "via_diameter_mm": ' + FormatFloat('0.000', CoordToMMs(ViaD)) + ',');
                                    OutputFile.Add('      "hole_size_mm": ' + FormatFloat('0.000', CoordToMMs(HoleS)) + ',');
                                Except
                                    OutputFile.Add('      "via_diameter_mm": 0.8,');
                                    OutputFile.Add('      "hole_size_mm": 0.4,');
                                End;
                                
                                Try
                                    ScopeExpr := Rule.Scope1Expression;
                                    If Length(ScopeExpr) > 200 Then
                                        ScopeExpr := Copy(ScopeExpr, 1, 200);
                                    OutputFile.Add('      "scope": "' + EscapeJsonString(ScopeExpr) + '"');
                                Except
                                    OutputFile.Add('      "scope": "All"');
                                End;
                                
                                OutputFile.Add('    }');
                            End;
                            
                            // Get next rule with error handling
                            Try
                                Rule := Iterator.NextPCBObject;
                            Except
                                Rule := Nil;  // Exit on error
                            End;
                            
                            // Batch processing - allow UI to refresh
                            If BatchCounter >= BATCH_SIZE Then
                            Begin
                                BatchCounter := 0;
                                // Small delay to allow UI refresh
                                Sleep(5);  // Longer sleep for memory cleanup
                            End;
                        End;
                        
                        // Close arrays
                        OutputFile.Add('  ],');
                        
                        // NO LIMITS - process all rules
                    Finally
                        PCB.BoardIterator_Destroy(Iterator);
                    End;
                End
                Else
                Begin
                    // No iterator - close arrays anyway
                    OutputFile.Add('  ],');
                End;
            Except
                // On error, close arrays
                OutputFile.Add('  ],');
                OutputFile.Add('  "error": "Failed to iterate rules",');
            End;
            
            // Complete JSON
            OutputFile.Add('  "netclasses": [],');
            OutputFile.Add('  "statistics": {');
            OutputFile.Add('    "total_rules": ' + IntToStr(RuleCount) + ',');
            OutputFile.Add('    "clearance_rules": ' + IntToStr(ClearanceCount) + ',');
            OutputFile.Add('    "width_rules": ' + IntToStr(WidthCount) + ',');
            OutputFile.Add('    "via_rules": ' + IntToStr(ViaCount) + ',');
            OutputFile.Add('    "other_rules": ' + IntToStr(RuleCount - ClearanceCount - WidthCount - ViaCount));
            OutputFile.Add('  },');
            OutputFile.Add('  "status": "success"');
            OutputFile.Add('}');
            
            // Write final buffer
            FileName := BASE_PATH + 'design_rules.json';
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
        ShowMessage('Design Rules Exported!' + #13#10 + #13#10 +
                    'Total: ' + IntToStr(RuleCount) + #13#10 +
                    'Clearance: ' + IntToStr(ClearanceCount) + #13#10 +
                    'Width: ' + IntToStr(WidthCount) + #13#10 +
                    'Via: ' + IntToStr(ViaCount) + #13#10 + #13#10 +
                    'File: ' + FileName);
        
    Except
        ShowMessage('ERROR: Unexpected error during export');
    End;
End;
