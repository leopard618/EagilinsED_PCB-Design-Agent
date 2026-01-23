{*
 * Export Board Config Command
 * Exports board configuration to board_config.json
 * Command: export_board_config
 * OPTIMIZED: Direct TStringList writing, removed JSONStr concatenation
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    MAX_LAYERS = 100;  // Safety limit

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

// Export board configuration to JSON
Procedure ExportBoardConfig;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    BoardRect     : TCoordRect;
    Width, Height : Double;
    OriginX       : Double;
    OriginY       : Double;
    LayerStack    : IPCB_LayerStack;
    Layer         : IPCB_LayerObject;
    LayerCount    : Integer;
    SignalLayers  : Integer;
    I             : Integer;
    FirstItem     : Boolean;
    LayerName     : String;
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
    
    // Get board dimensions
    Try
        If PCB.BoardOutline <> Nil Then
        Begin
            BoardRect := PCB.BoardOutline.BoundingRectangle;
            Width := CoordToMMs(BoardRect.Right - BoardRect.Left);
            Height := CoordToMMs(BoardRect.Top - BoardRect.Bottom);
            If Width < 0 Then Width := -Width;
            If Height < 0 Then Height := -Height;
        End
        Else
        Begin
            Width := 0;
            Height := 0;
        End;
    Except
        Width := 0;
        Height := 0;
    End;
    
    // Get origin
    Try
        OriginX := CoordToMMs(PCB.XOrigin);
        OriginY := CoordToMMs(PCB.YOrigin);
    Except
        OriginX := 0;
        OriginY := 0;
    End;
    
    // Create output file
    OutputFile := TStringList.Create;
    Try
        // Start JSON
        OutputFile.Add('{');
        
        Try
            OutputFile.Add('  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",');
        Except
            OutputFile.Add('  "pcb_file": "Unknown",');
        End;
        
        // Board dimensions
        OutputFile.Add('  "board": {');
        OutputFile.Add('    "width_mm": ' + FormatFloat('0.00', Width) + ',');
        OutputFile.Add('    "height_mm": ' + FormatFloat('0.00', Height) + ',');
        OutputFile.Add('    "area_mm2": ' + FormatFloat('0.00', Width * Height) + ',');
        OutputFile.Add('    "origin": {');
        OutputFile.Add('      "x_mm": ' + FormatFloat('0.00', OriginX) + ',');
        OutputFile.Add('      "y_mm": ' + FormatFloat('0.00', OriginY));
        OutputFile.Add('    }');
        OutputFile.Add('  },');
        
        // Layer stack
        OutputFile.Add('  "layer_stack": {');
        
        LayerCount := 0;
        SignalLayers := 0;
        
        Try
            LayerStack := PCB.LayerStack;
            If LayerStack <> Nil Then
            Begin
                LayerCount := LayerStack.LayersCount;
                SignalLayers := LayerStack.SignalLayerCount;
            End;
        Except
        End;
        
        OutputFile.Add('    "total_layers": ' + IntToStr(LayerCount) + ',');
        OutputFile.Add('    "signal_layers": ' + IntToStr(SignalLayers) + ',');
        
        // Layer details
        OutputFile.Add('    "layers": [');
        FirstItem := True;
        
        Try
            If LayerStack <> Nil Then
            Begin
                For I := 1 To LayerStack.LayersCount Do
                Begin
                    If I > MAX_LAYERS Then Break;  // Safety limit
                    
                    Layer := LayerStack.LayerObject(I);
                    If Layer <> Nil Then
                    Begin
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('      {');
                        
                        Try
                            LayerName := Layer.Name;
                        Except
                            LayerName := 'Layer ' + IntToStr(I);
                        End;
                        OutputFile.Add('        "name": "' + EscapeJsonString(LayerName) + '",');
                        
                        Try
                            OutputFile.Add('        "layer_id": ' + IntToStr(Layer.LayerID) + ',');
                        Except
                            OutputFile.Add('        "layer_id": ' + IntToStr(I) + ',');
                        End;
                        
                        Try
                            If Layer.IsSignalLayer Then
                                OutputFile.Add('        "type": "signal",')
                            Else If Layer.IsDielectric Then
                                OutputFile.Add('        "type": "dielectric",')
                            Else If Layer.IsPlane Then
                                OutputFile.Add('        "type": "plane",')
                            Else
                                OutputFile.Add('        "type": "other",');
                        Except
                            OutputFile.Add('        "type": "unknown",');
                        End;
                        
                        Try
                            OutputFile.Add('        "copper_thickness_mm": ' + FormatFloat('0.000', CoordToMMs(Layer.CopperThickness)) + ',');
                        Except
                            OutputFile.Add('        "copper_thickness_mm": 0.035,');
                        End;
                        
                        Try
                            OutputFile.Add('        "dielectric_thickness_mm": ' + FormatFloat('0.000', CoordToMMs(Layer.DielectricThickness)));
                        Except
                            OutputFile.Add('        "dielectric_thickness_mm": 0');
                        End;
                        
                        OutputFile.Add('      }');
                    End;
                End;
            End;
        Except
        End;
        
        OutputFile.Add('    ]');
        OutputFile.Add('  },');
        
        // Units
        Try
            If PCB.DisplayUnit = eImperial Then
                OutputFile.Add('  "display_unit": "mil",')
            Else
                OutputFile.Add('  "display_unit": "mm",');
        Except
            OutputFile.Add('  "display_unit": "mm",');
        End;
        
        // Grid
        Try
            OutputFile.Add('  "snap_grid_mm": ' + FormatFloat('0.000', CoordToMMs(PCB.SnapGridSize)) + ',');
        Except
            OutputFile.Add('  "snap_grid_mm": 0.1,');
        End;
        
        OutputFile.Add('  "status": "success"');
        OutputFile.Add('}');
        
        // Save to file
        FileName := BASE_PATH + 'board_config.json';
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Board Configuration Exported!' + #13#10 + #13#10 +
                        'Board Size: ' + FormatFloat('0.00', Width) + ' x ' + FormatFloat('0.00', Height) + ' mm' + #13#10 +
                        'Layers: ' + IntToStr(LayerCount) + ' total, ' + IntToStr(SignalLayers) + ' signal' + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
