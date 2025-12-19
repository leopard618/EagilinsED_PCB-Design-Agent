{*
 * Generate Pick & Place Command
 * Generates pick and place file for assembly
 * Command: generate_pick_place
 *}

Const
    OUTPUT_BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\Output';
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

// Ensure output directory exists
Function EnsureOutputDir(SubDir: String): String;
Var
    FullPath: String;
Begin
    FullPath := OUTPUT_BASE_PATH;
    If SubDir <> '' Then
        FullPath := FullPath + '\' + SubDir;
    
    Try
        ForceDirectories(FullPath);
    Except
    End;
    
    Result := FullPath;
End;

// Generate Pick and Place file
Procedure GeneratePickAndPlace;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Iterator      : IPCB_BoardIterator;
    Component     : IPCB_Component;
    OutputPath    : String;
    OutputFile    : TStringList;
    PnPFile       : TStringList;
    JSONStr       : String;
    FileName      : String;
    PnPFileName   : String;
    CompName      : String;
    CompX, CompY  : Double;
    CompRotation  : Double;
    CompLayer     : String;
    CompCount     : Integer;
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
        ShowMessage('ERROR: Cannot access PCB board.');
        Exit;
    End;
    
    // Create output directory
    OutputPath := EnsureOutputDir('Assembly');
    
    CompCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "Pick and Place",' + #13#10;
    JSONStr := JSONStr + '  "units": "mm",' + #13#10;
    JSONStr := JSONStr + '  "components": [' + #13#10;
    FirstItem := True;
    
    // Build CSV
    PnPFile := TStringList.Create;
    Try
        PnPFile.Add('Designator,X(mm),Y(mm),Rotation,Layer,Footprint');
        
        Try
            Iterator := PCB.BoardIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Component := Iterator.FirstPCBObject;
                    While Component <> Nil Do
                    Begin
                        Inc(CompCount);
                        
                        Try
                            CompName := Component.Name.Text;
                        Except
                            CompName := 'Unknown';
                        End;
                        
                        Try
                            CompX := CoordToMMs(Component.X);
                            CompY := CoordToMMs(Component.Y);
                        Except
                            CompX := 0;
                            CompY := 0;
                        End;
                        
                        Try
                            CompRotation := Component.Rotation;
                        Except
                            CompRotation := 0;
                        End;
                        
                        Try
                            CompLayer := Layer2String(Component.Layer);
                        Except
                            CompLayer := 'Top';
                        End;
                        
                        // Add to JSON
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "designator": "' + EscapeJsonString(CompName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "x": ' + FormatFloat('0.000', CompX) + ',' + #13#10;
                        JSONStr := JSONStr + '      "y": ' + FormatFloat('0.000', CompY) + ',' + #13#10;
                        JSONStr := JSONStr + '      "rotation": ' + FormatFloat('0.0', CompRotation) + ',' + #13#10;
                        JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(CompLayer) + '",' + #13#10;
                        
                        Try
                            JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(Component.Pattern) + '"' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "footprint": ""' + #13#10;
                        End;
                        
                        JSONStr := JSONStr + '    }';
                        
                        // Add to CSV
                        Try
                            PnPFile.Add(CompName + ',' + 
                                       FormatFloat('0.000', CompX) + ',' + 
                                       FormatFloat('0.000', CompY) + ',' + 
                                       FormatFloat('0.0', CompRotation) + ',' + 
                                       CompLayer + ',' + 
                                       Component.Pattern);
                        Except
                            PnPFile.Add(CompName + ',' + 
                                       FormatFloat('0.000', CompX) + ',' + 
                                       FormatFloat('0.000', CompY) + ',' + 
                                       FormatFloat('0.0', CompRotation) + ',' + 
                                       CompLayer + ',');
                        End;
                        
                        Component := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        
        JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
        JSONStr := JSONStr + '  "total_components": ' + IntToStr(CompCount) + ',' + #13#10;
        JSONStr := JSONStr + '  "output_path": "' + EscapeJsonString(OutputPath) + '",' + #13#10;
        JSONStr := JSONStr + '  "status": "generated"' + #13#10;
        JSONStr := JSONStr + '}';
        
        // Save CSV
        PnPFileName := OutputPath + '\PickAndPlace.csv';
        Try
            PnPFile.SaveToFile(PnPFileName);
        Except
        End;
    Finally
        PnPFile.Free;
    End;
    
    // Save JSON
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := OutputPath + '\PickAndPlace.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
        
        // Also save to standard location
        FileName := BASE_PATH + 'output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
    
    ShowMessage('Pick and Place Generated!' + #13#10 + #13#10 +
                'Total Components: ' + IntToStr(CompCount) + #13#10 + #13#10 +
                'Files generated:' + #13#10 +
                '- PickAndPlace.csv' + #13#10 +
                '- PickAndPlace.json' + #13#10 + #13#10 +
                'Output path: ' + OutputPath);
End;
