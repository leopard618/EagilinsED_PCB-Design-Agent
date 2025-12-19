{*
 * Generate BOM Command
 * Generates Bill of Materials
 * Command: generate_bom
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

// Generate Bill of Materials (BOM)
Procedure GenerateBOM;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Iterator      : IPCB_BoardIterator;
    Component     : IPCB_Component;
    OutputPath    : String;
    OutputFile    : TStringList;
    BOMFile       : TStringList;
    JSONStr       : String;
    FileName      : String;
    BOMFileName   : String;
    CompName      : String;
    CompValue     : String;
    CompFootprint : String;
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
    OutputPath := EnsureOutputDir('BOM');
    
    CompCount := 0;
    
    // Build JSON BOM
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "BOM",' + #13#10;
    JSONStr := JSONStr + '  "components": [' + #13#10;
    FirstItem := True;
    
    // Also build CSV BOM
    BOMFile := TStringList.Create;
    Try
        BOMFile.Add('Designator,Value,Footprint,Quantity');
        
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
                            CompValue := Component.Comment.Text;
                        Except
                            CompValue := '';
                        End;
                        
                        Try
                            CompFootprint := Component.Pattern;
                        Except
                            CompFootprint := '';
                        End;
                        
                        // Add to JSON
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "designator": "' + EscapeJsonString(CompName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "value": "' + EscapeJsonString(CompValue) + '",' + #13#10;
                        JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(CompFootprint) + '",' + #13#10;
                        JSONStr := JSONStr + '      "quantity": 1' + #13#10;
                        JSONStr := JSONStr + '    }';
                        
                        // Add to CSV
                        BOMFile.Add('"' + CompName + '","' + CompValue + '","' + CompFootprint + '",1');
                        
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
        
        // Save CSV BOM
        BOMFileName := OutputPath + '\BOM.csv';
        Try
            BOMFile.SaveToFile(BOMFileName);
        Except
        End;
    Finally
        BOMFile.Free;
    End;
    
    // Save JSON result
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := OutputPath + '\BOM.json';
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
    
    ShowMessage('BOM Generated!' + #13#10 + #13#10 +
                'Total Components: ' + IntToStr(CompCount) + #13#10 + #13#10 +
                'Files generated:' + #13#10 +
                '- BOM.csv' + #13#10 +
                '- BOM.json' + #13#10 + #13#10 +
                'Output path: ' + OutputPath);
End;
