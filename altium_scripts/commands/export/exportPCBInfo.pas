{*
 * Export PCB Info Command
 * Exports comprehensive PCB information to pcb_info.json
 * Command: export_pcb_info
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

Procedure ExportPCBInfo;
Var
    PCB           : IPCB_Board;
    PCBFile       : TStringList;
    FileName      : String;
    Component     : IPCB_Component;
    Net           : IPCB_Net;
    Via           : IPCB_Via;
    Track         : IPCB_Track;
    Pad           : IPCB_Pad;
    Layer         : TLayer;
    LayerCount    : Integer;
    ComponentCount: Integer;
    NetCount      : Integer;
    ViaCount      : Integer;
    TrackCount    : Integer;
    BoardRect     : TCoordRect;
    Width, Height : Double;
    I             : Integer;
    JSONStr       : String;
    Doc           : IDocument;
    Workspace     : IWorkspace;
    Iterator      : IPCB_BoardIterator;
    InnerIterator : IPCB_BoardIterator;
    CompX, CompY  : Double;
    CompWidth, CompHeight : Double;
    CompLayer     : String;
    CompName      : String;
    NetName       : String;
    LayerName     : String;
    BoundingRect  : TCoordRect;
    TempStr       : String;
    FirstItem     : Boolean;
    InnerFirstItem: Boolean;
    NetFirstItem  : Boolean;
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
            If Doc <> Nil Then
            Begin
                If Doc.DM_DocumentKind = 'PCB' Then
                Begin
                    PCB := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
                End;
            End;
        Except
        End;
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: Cannot access PCB board.' + #13#10 + #13#10 +
                    'Please make sure:' + #13#10 +
                    '1. A PCB document is open' + #13#10 +
                    '2. Click on the PCB document tab to make it active');
        Exit;
    End;

    // Initialize all counters
    ComponentCount := 0;
    NetCount := 0;
    ViaCount := 0;
    TrackCount := 0;
    LayerCount := 0;

    // Build comprehensive JSON string
    JSONStr := '{' + #13#10;
    
    // Get file name
    Try
        Doc := Workspace.DM_FocusedDocument;
        If Doc <> Nil Then
            FileName := Doc.DM_FileName
        Else
            FileName := 'Unknown';
    Except
        FileName := 'Unknown';
    End;
    
    If FileName = '' Then
        FileName := 'Unknown';
    
    JSONStr := JSONStr + '  "file_name": "' + EscapeJsonString(FileName) + '",' + #13#10;
    
    // Get board size
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
    
    JSONStr := JSONStr + '  "board_size": {' + #13#10;
    JSONStr := JSONStr + '    "width_mm": ' + FormatFloat('0.00', Width) + ',' + #13#10;
    JSONStr := JSONStr + '    "height_mm": ' + FormatFloat('0.00', Height) + ',' + #13#10;
    JSONStr := JSONStr + '    "area_mm2": ' + FormatFloat('0.00', Width * Height) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // ========== COMPONENTS ==========
    JSONStr := JSONStr + '  "components": [' + #13#10;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Component := Iterator.FirstPCBObject;
            FirstItem := True;
            While Component <> Nil Do
            Begin
                Inc(ComponentCount);
                
                If Not FirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                FirstItem := False;
                
                JSONStr := JSONStr + '    {' + #13#10;
                
                // Basic properties
                Try
                    CompName := Component.Name.Text;
                    If CompName = '' Then CompName := 'Unnamed';
                Except
                    CompName := 'Unknown';
                End;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(CompName) + '",' + #13#10;
                
                Try
                    CompX := CoordToMMs(Component.X);
                    CompY := CoordToMMs(Component.Y);
                Except
                    CompX := 0;
                    CompY := 0;
                End;
                JSONStr := JSONStr + '      "location": {' + #13#10;
                JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CompX) + ',' + #13#10;
                JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CompY) + #13#10;
                JSONStr := JSONStr + '      },' + #13#10;
                
                // Size
                Try
                    BoundingRect := Component.BoundingRectangle;
                    CompWidth := CoordToMMs(BoundingRect.Right - BoundingRect.Left);
                    CompHeight := CoordToMMs(BoundingRect.Top - BoundingRect.Bottom);
                    If CompWidth < 0 Then CompWidth := -CompWidth;
                    If CompHeight < 0 Then CompHeight := -CompHeight;
                Except
                    CompWidth := 0;
                    CompHeight := 0;
                End;
                JSONStr := JSONStr + '      "size": {' + #13#10;
                JSONStr := JSONStr + '        "width_mm": ' + FormatFloat('0.00', CompWidth) + ',' + #13#10;
                JSONStr := JSONStr + '        "height_mm": ' + FormatFloat('0.00', CompHeight) + #13#10;
                JSONStr := JSONStr + '      },' + #13#10;
                
                // Layer
                Try
                    CompLayer := Layer2String(Component.Layer);
                    If CompLayer = '' Then CompLayer := 'Layer ' + IntToStr(Component.Layer);
                Except
                    CompLayer := 'Unknown';
                End;
                JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(CompLayer) + '",' + #13#10;
                
                // Rotation
                Try
                    JSONStr := JSONStr + '      "rotation_degrees": ' + FormatFloat('0.00', Component.Rotation) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "rotation_degrees": 0,' + #13#10;
                End;
                
                // Footprint
                Try
                    TempStr := Component.Pattern;
                    If TempStr = '' Then TempStr := 'Unknown';
                Except
                    TempStr := 'Unknown';
                End;
                JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(TempStr) + '",' + #13#10;
                
                // Moveable
                Try
                    If Component.Moveable Then
                        TempStr := 'true'
                    Else
                        TempStr := 'false';
                    JSONStr := JSONStr + '      "moveable": ' + TempStr + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "moveable": true,' + #13#10;
                End;
                
                // Parameters
                JSONStr := JSONStr + '      "parameters": [';
                Try
                    FirstItem := True;
                    Try
                        TempStr := Component.Comment.Text;
                        If (TempStr <> '') And (TempStr <> CompName) Then
                        Begin
                            If Not FirstItem Then
                                JSONStr := JSONStr + ',';
                            FirstItem := False;
                            JSONStr := JSONStr + #13#10 + '        {' + #13#10;
                            JSONStr := JSONStr + '          "name": "Value",' + #13#10;
                            JSONStr := JSONStr + '          "value": "' + EscapeJsonString(TempStr) + '"' + #13#10;
                            JSONStr := JSONStr + '        }';
                        End;
                    Except
                    End;
                Except
                End;
                JSONStr := JSONStr + #13#10 + '      ],' + #13#10;
                
                JSONStr := JSONStr + '      "pins": []' + #13#10;
                JSONStr := JSONStr + '    }';
                
                Component := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
        ComponentCount := 0;
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== NETS ==========
    JSONStr := JSONStr + '  "nets": [' + #13#10;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Net := Iterator.FirstPCBObject;
            NetFirstItem := True;
            While Net <> Nil Do
            Begin
                Inc(NetCount);
                
                If Not NetFirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                NetFirstItem := False;
                
                JSONStr := JSONStr + '    {' + #13#10;
                
                Try
                    NetName := Net.Name;
                    If NetName = '' Then NetName := 'Unnamed';
                Except
                    NetName := 'Unknown';
                End;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(NetName) + '",' + #13#10;
                
                // Connected components
                JSONStr := JSONStr + '      "connected_components": [';
                Try
                    InnerFirstItem := True;
                    InnerIterator := PCB.BoardIterator_Create;
                    Try
                        InnerIterator.AddFilter_ObjectSet(MkSet(ePadObject));
                        InnerIterator.AddFilter_LayerSet(AllLayers);
                        InnerIterator.AddFilter_Method(eProcessAll);
                        
                        Pad := InnerIterator.FirstPCBObject;
                        While Pad <> Nil Do
                        Begin
                            Try
                                If (Pad.Net <> Nil) And (Pad.Net.Name = NetName) Then
                                Begin
                                    If (Pad.Component <> Nil) Then
                                    Begin
                                        Try
                                            TempStr := Pad.Component.Name.Text;
                                            If TempStr <> '' Then
                                            Begin
                                                If InnerFirstItem Or (Pos('"' + TempStr + '"', JSONStr) = 0) Then
                                                Begin
                                                    If Not InnerFirstItem Then
                                                        JSONStr := JSONStr + ',';
                                                    InnerFirstItem := False;
                                                    JSONStr := JSONStr + '"' + EscapeJsonString(TempStr) + '"';
                                                End;
                                            End;
                                        Except
                                        End;
                                    End;
                                End;
                            Except
                            End;
                            Pad := InnerIterator.NextPCBObject;
                        End;
                    Finally
                        PCB.BoardIterator_Destroy(InnerIterator);
                    End;
                Except
                End;
                JSONStr := JSONStr + '],' + #13#10;
                
                // Track count
                Try
                    I := 0;
                    InnerIterator := PCB.BoardIterator_Create;
                    Try
                        InnerIterator.AddFilter_ObjectSet(MkSet(eTrackObject));
                        InnerIterator.AddFilter_LayerSet(AllLayers);
                        InnerIterator.AddFilter_Method(eProcessAll);
                        Track := InnerIterator.FirstPCBObject;
                        While Track <> Nil Do
                        Begin
                            If (Track.Net <> Nil) And (Track.Net.Name = NetName) Then
                                Inc(I);
                            Track := InnerIterator.NextPCBObject;
                        End;
                    Finally
                        PCB.BoardIterator_Destroy(InnerIterator);
                    End;
                Except
                    I := 0;
                End;
                JSONStr := JSONStr + '      "track_count": ' + IntToStr(I) + ',' + #13#10;
                
                // Via count
                Try
                    I := 0;
                    InnerIterator := PCB.BoardIterator_Create;
                    Try
                        InnerIterator.AddFilter_ObjectSet(MkSet(eViaObject));
                        InnerIterator.AddFilter_LayerSet(AllLayers);
                        InnerIterator.AddFilter_Method(eProcessAll);
                        Via := InnerIterator.FirstPCBObject;
                        While Via <> Nil Do
                        Begin
                            If (Via.Net <> Nil) And (Via.Net.Name = NetName) Then
                                Inc(I);
                            Via := InnerIterator.NextPCBObject;
                        End;
                    Finally
                        PCB.BoardIterator_Destroy(InnerIterator);
                    End;
                Except
                    I := 0;
                End;
                JSONStr := JSONStr + '      "via_count": ' + IntToStr(I) + #13#10;
                
                JSONStr := JSONStr + '    }';
                
                Net := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
        NetCount := 0;
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== TRACKS ==========
    JSONStr := JSONStr + '  "tracks": [' + #13#10;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Track := Iterator.FirstPCBObject;
            FirstItem := True;
            While Track <> Nil Do
            Begin
                Inc(TrackCount);
                
                If Not FirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                FirstItem := False;
                
                JSONStr := JSONStr + '    {' + #13#10;
                
                Try
                    JSONStr := JSONStr + '      "start": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X1)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y1)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "start": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                Try
                    JSONStr := JSONStr + '      "end": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X2)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y2)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "end": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                Try
                    JSONStr := JSONStr + '      "width_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Width)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "width_mm": 0,' + #13#10;
                End;
                
                Try
                    LayerName := Layer2String(Track.Layer);
                    If LayerName = '' Then LayerName := 'Layer ' + IntToStr(Track.Layer);
                Except
                    LayerName := 'Unknown';
                End;
                JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(LayerName) + '",' + #13#10;
                
                Try
                    If Track.Net <> Nil Then
                        NetName := Track.Net.Name
                    Else
                        NetName := '';
                Except
                    NetName := '';
                End;
                JSONStr := JSONStr + '      "net": "' + EscapeJsonString(NetName) + '"' + #13#10;
                
                JSONStr := JSONStr + '    }';
                
                Track := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
        TrackCount := 0;
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== VIAS ==========
    JSONStr := JSONStr + '  "vias": [' + #13#10;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eViaObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Via := Iterator.FirstPCBObject;
            FirstItem := True;
            While Via <> Nil Do
            Begin
                Inc(ViaCount);
                
                If Not FirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                FirstItem := False;
                
                JSONStr := JSONStr + '    {' + #13#10;
                
                Try
                    JSONStr := JSONStr + '      "position": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Via.X)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Y)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "position": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                Try
                    JSONStr := JSONStr + '      "size_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Size)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "size_mm": 0,' + #13#10;
                End;
                
                Try
                    JSONStr := JSONStr + '      "hole_size_mm": ' + FormatFloat('0.00', CoordToMMs(Via.HoleSize)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "hole_size_mm": 0,' + #13#10;
                End;
                
                JSONStr := JSONStr + '      "start_layer": "Multi-Layer",' + #13#10;
                JSONStr := JSONStr + '      "end_layer": "Multi-Layer",' + #13#10;
                
                Try
                    If Via.Net <> Nil Then
                        NetName := Via.Net.Name
                    Else
                        NetName := '';
                Except
                    NetName := '';
                End;
                JSONStr := JSONStr + '      "net": "' + EscapeJsonString(NetName) + '"' + #13#10;
                
                JSONStr := JSONStr + '    }';
                
                Via := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
        ViaCount := 0;
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // Count layers
    JSONStr := JSONStr + '  "layers": [';
    Try
        FirstItem := True;
        For Layer := eTopLayer To eBottomLayer Do
        Begin
            Try
                If PCB.LayerIsUsed(Layer) Then
                Begin
                    Inc(LayerCount);
                    Try
                        LayerName := Layer2String(Layer);
                        If LayerName = '' Then LayerName := 'Layer ' + IntToStr(Layer);
                    Except
                        LayerName := 'Layer ' + IntToStr(Layer);
                    End;
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',';
                    FirstItem := False;
                    JSONStr := JSONStr + #13#10 + '    "' + LayerName + '"';
                End;
            Except
            End;
        End;
    Except
        LayerCount := 0;
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // Statistics
    JSONStr := JSONStr + '  "statistics": {' + #13#10;
    JSONStr := JSONStr + '    "layer_count": ' + IntToStr(LayerCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "component_count": ' + IntToStr(ComponentCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "net_count": ' + IntToStr(NetCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "track_count": ' + IntToStr(TrackCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "via_count": ' + IntToStr(ViaCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    JSONStr := JSONStr + '  "status": "active"' + #13#10;
    JSONStr := JSONStr + '}';

    // Write to file
    PCBFile := TStringList.Create;
    Try
        PCBFile.Text := JSONStr;
        FileName := BASE_PATH + 'pcb_info.json';
        
        Try
            PCBFile.SaveToFile(FileName);
            ShowMessage('SUCCESS! Comprehensive PCB information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                        'Components: ' + IntToStr(ComponentCount) + #13#10 +
                        'Nets: ' + IntToStr(NetCount) + #13#10 +
                        'Tracks: ' + IntToStr(TrackCount) + #13#10 +
                        'Vias: ' + IntToStr(ViaCount) + #13#10 +
                        'Layers: ' + IntToStr(LayerCount));
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        PCBFile.Free;
    End;
End;
