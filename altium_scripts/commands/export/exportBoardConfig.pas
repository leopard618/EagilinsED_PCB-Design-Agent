{*
 * Export Board Config Command
 * Exports board configuration to board_config.json
 * Command: export_board_config
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

// Export board configuration to JSON
Procedure ExportBoardConfig;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
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
    
    // Build JSON
    JSONStr := '{' + #13#10;
    
    Try
        JSONStr := JSONStr + '  "pcb_file": "' + EscapeJsonString(PCB.FileName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '  "pcb_file": "Unknown",' + #13#10;
    End;
    
    // Board dimensions
    JSONStr := JSONStr + '  "board": {' + #13#10;
    JSONStr := JSONStr + '    "width_mm": ' + FormatFloat('0.00', Width) + ',' + #13#10;
    JSONStr := JSONStr + '    "height_mm": ' + FormatFloat('0.00', Height) + ',' + #13#10;
    JSONStr := JSONStr + '    "area_mm2": ' + FormatFloat('0.00', Width * Height) + ',' + #13#10;
    JSONStr := JSONStr + '    "origin": {' + #13#10;
    JSONStr := JSONStr + '      "x_mm": ' + FormatFloat('0.00', OriginX) + ',' + #13#10;
    JSONStr := JSONStr + '      "y_mm": ' + FormatFloat('0.00', OriginY) + #13#10;
    JSONStr := JSONStr + '    }' + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Layer stack
    JSONStr := JSONStr + '  "layer_stack": {' + #13#10;
    
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
    
    JSONStr := JSONStr + '    "total_layers": ' + IntToStr(LayerCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "signal_layers": ' + IntToStr(SignalLayers) + ',' + #13#10;
    
    // Layer details
    JSONStr := JSONStr + '    "layers": [' + #13#10;
    FirstItem := True;
    
    Try
        If LayerStack <> Nil Then
        Begin
            For I := 1 To LayerStack.LayersCount Do
            Begin
                Layer := LayerStack.LayerObject(I);
                If Layer <> Nil Then
                Begin
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '      {' + #13#10;
                    
                    Try
                        LayerName := Layer.Name;
                    Except
                        LayerName := 'Layer ' + IntToStr(I);
                    End;
                    JSONStr := JSONStr + '        "name": "' + EscapeJsonString(LayerName) + '",' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '        "layer_id": ' + IntToStr(Layer.LayerID) + ',' + #13#10;
                    Except
                        JSONStr := JSONStr + '        "layer_id": ' + IntToStr(I) + ',' + #13#10;
                    End;
                    
                    Try
                        If Layer.IsSignalLayer Then
                            JSONStr := JSONStr + '        "type": "signal",' + #13#10
                        Else If Layer.IsDielectric Then
                            JSONStr := JSONStr + '        "type": "dielectric",' + #13#10
                        Else If Layer.IsPlane Then
                            JSONStr := JSONStr + '        "type": "plane",' + #13#10
                        Else
                            JSONStr := JSONStr + '        "type": "other",' + #13#10;
                    Except
                        JSONStr := JSONStr + '        "type": "unknown",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '        "copper_thickness_mm": ' + FormatFloat('0.000', CoordToMMs(Layer.CopperThickness)) + ',' + #13#10;
                    Except
                        JSONStr := JSONStr + '        "copper_thickness_mm": 0.035,' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '        "dielectric_thickness_mm": ' + FormatFloat('0.000', CoordToMMs(Layer.DielectricThickness)) + #13#10;
                    Except
                        JSONStr := JSONStr + '        "dielectric_thickness_mm": 0' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '      }';
                End;
            End;
        End;
    Except
    End;
    
    JSONStr := JSONStr + #13#10 + '    ]' + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // Units
    Try
        If PCB.DisplayUnit = eImperial Then
            JSONStr := JSONStr + '  "display_unit": "mil",' + #13#10
        Else
            JSONStr := JSONStr + '  "display_unit": "mm",' + #13#10;
    Except
        JSONStr := JSONStr + '  "display_unit": "mm",' + #13#10;
    End;
    
    // Grid
    Try
        JSONStr := JSONStr + '  "snap_grid_mm": ' + FormatFloat('0.000', CoordToMMs(PCB.SnapGridSize)) + ',' + #13#10;
    Except
        JSONStr := JSONStr + '  "snap_grid_mm": 0.1,' + #13#10;
    End;
    
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
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
