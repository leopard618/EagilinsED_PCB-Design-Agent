{*
 * Altium Designer Script - Design Rules Manager
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Export current design rules to JSON
 * - Query clearance, width, via rules
 * - List net classes
 * 
 * TO RUN THIS SCRIPT:
 * 1. Open a PCB document
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_design_rules.pas
 * 4. When dialog appears, select the procedure you want to run
 * 5. Click OK
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
    RuleType      : String;
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
                    
                    // Check if it's a clearance rule
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
                    
                    // Check if it's a width rule
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
                    
                    // Check if it's a via rule
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

// Export net classes
Procedure ExportNetClasses;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    NetClass      : IPCB_ObjectClass;
    ClassIterator : IPCB_ObjectClassIterator;
    Net           : IPCB_Net;
    NetIterator   : IPCB_BoardIterator;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    FirstClass    : Boolean;
    FirstNet      : Boolean;
    ClassCount    : Integer;
    NetName       : String;
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
    
    ClassCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "net_classes": [' + #13#10;
    FirstClass := True;
    
    Try
        ClassIterator := PCB.ObjectClassIterator_Create;
        If ClassIterator <> Nil Then
        Begin
            Try
                ClassIterator.SetState_FilterObjectClass(eClassMemberKind_Net);
                
                NetClass := ClassIterator.FirstObjectClass;
                While NetClass <> Nil Do
                Begin
                    Inc(ClassCount);
                    
                    If Not FirstClass Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstClass := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(NetClass.Name) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "name": "Unknown",' + #13#10;
                    End;
                    
                    // Get nets in this class
                    JSONStr := JSONStr + '      "nets": [';
                    FirstNet := True;
                    
                    Try
                        NetIterator := PCB.BoardIterator_Create;
                        If NetIterator <> Nil Then
                        Begin
                            Try
                                NetIterator.AddFilter_ObjectSet(MkSet(eNetObject));
                                NetIterator.AddFilter_Method(eProcessAll);
                                
                                Net := NetIterator.FirstPCBObject;
                                While Net <> Nil Do
                                Begin
                                    Try
                                        If NetClass.IsMember(Net) Then
                                        Begin
                                            If Not FirstNet Then
                                                JSONStr := JSONStr + ', ';
                                            FirstNet := False;
                                            
                                            NetName := Net.Name;
                                            JSONStr := JSONStr + '"' + EscapeJsonString(NetName) + '"';
                                        End;
                                    Except
                                    End;
                                    
                                    Net := NetIterator.NextPCBObject;
                                End;
                            Finally
                                PCB.BoardIterator_Destroy(NetIterator);
                            End;
                        End;
                    Except
                    End;
                    
                    JSONStr := JSONStr + ']' + #13#10;
                    JSONStr := JSONStr + '    }';
                    
                    NetClass := ClassIterator.NextObjectClass;
                End;
            Finally
                PCB.ObjectClassIterator_Destroy(ClassIterator);
            End;
        End;
    Except
    End;
    
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    JSONStr := JSONStr + '  "class_count": ' + IntToStr(ClassCount) + ',' + #13#10;
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'net_classes.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Net Classes Exported!' + #13#10 + #13#10 +
                        'Total Classes: ' + IntToStr(ClassCount) + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;

// Quick summary of design rules
Procedure ShowDesignRulesSummary;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Rule          : IPCB_Rule;
    Iterator      : IPCB_BoardIterator;
    SummaryStr    : String;
    ClearanceMin  : Double;
    WidthMin      : Double;
    ViaMin        : Double;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
    Except
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    ClearanceMin := 999;
    WidthMin := 999;
    ViaMin := 999;
    
    // Find minimum values
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
                    If Rule.Enabled Then
                    Begin
                        If Rule.RuleKind = eRule_Clearance Then
                        Begin
                            Try
                                If CoordToMMs(Rule.Gap) < ClearanceMin Then
                                    ClearanceMin := CoordToMMs(Rule.Gap);
                            Except
                            End;
                        End
                        Else If Rule.RuleKind = eRule_Width Then
                        Begin
                            Try
                                If CoordToMMs(Rule.MinWidth) < WidthMin Then
                                    WidthMin := CoordToMMs(Rule.MinWidth);
                            Except
                            End;
                        End
                        Else If Rule.RuleKind = eRule_RoutingViaStyle Then
                        Begin
                            Try
                                If CoordToMMs(Rule.MinWidth) < ViaMin Then
                                    ViaMin := CoordToMMs(Rule.MinWidth);
                            Except
                            End;
                        End;
                    End;
                    
                    Rule := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    
    // Build summary
    SummaryStr := '=== Design Rules Summary ===' + #13#10 + #13#10;
    
    If ClearanceMin < 999 Then
        SummaryStr := SummaryStr + 'Min Clearance: ' + FormatFloat('0.000', ClearanceMin) + ' mm' + #13#10
    Else
        SummaryStr := SummaryStr + 'Min Clearance: Not defined' + #13#10;
    
    If WidthMin < 999 Then
        SummaryStr := SummaryStr + 'Min Track Width: ' + FormatFloat('0.000', WidthMin) + ' mm' + #13#10
    Else
        SummaryStr := SummaryStr + 'Min Track Width: Not defined' + #13#10;
    
    If ViaMin < 999 Then
        SummaryStr := SummaryStr + 'Min Via Size: ' + FormatFloat('0.000', ViaMin) + ' mm' + #13#10
    Else
        SummaryStr := SummaryStr + 'Min Via Size: Not defined' + #13#10;
    
    SummaryStr := SummaryStr + #13#10 + 'Run ExportDesignRules for complete details.';
    
    ShowMessage(SummaryStr);
End;


