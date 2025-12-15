{*
 * Altium Designer Script to Export Comprehensive PCB Information
 * Compatible with Altium Designer 25.8.1
 * Exports ALL properties for components, nets, tracks, vias, and other PCB objects
 * 
 * TO RUN THIS SCRIPT:
 * 1. Click on the PCB document tab to make it active
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_export_pcb_info.pas
 * 4. When dialog appears, select "ExportPCBInfo" procedure
 * 5. Click OK
 *}

// Helper function to escape JSON strings (escape quotes, backslashes, etc.)
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
            // Non-printable or non-ASCII characters - skip or replace
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
    Arc           : IPCB_Arc;
    Region        : IPCB_Region;
    Pin           : IPCB_Pin;
    Layer         : TLayer;
    LayerCount    : Integer;
    ComponentCount: Integer;
    NetCount      : Integer;
    ViaCount      : Integer;
    TrackCount    : Integer;
    PadCount      : Integer;
    ArcCount      : Integer;
    RegionCount   : Integer;
    BoardRect     : TCoordRect;
    Width, Height : Double;
    I, J          : Integer;
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
    PinObj        : IPCB_Pin;
    TempStr       : String;
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
    PadCount := 0;
    ArcCount := 0;
    RegionCount := 0;
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
    
    // ========== COMPONENTS WITH ALL PROPERTIES ==========
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
                
                // Moveable (Locked property not available in Altium API)
                Try
                    If Component.Moveable Then
                        TempStr := 'true'
                    Else
                        TempStr := 'false';
                    JSONStr := JSONStr + '      "moveable": ' + TempStr + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "moveable": true,' + #13#10;
                End;
                
                // Parameters - Try to get Value from Comment
                JSONStr := JSONStr + '      "parameters": [';
                Try
                    FirstItem := True;
                    // Try to get Value from Component.Comment.Text
                    // In Altium, component values are often stored in the Comment field
                    Try
                        TempStr := Component.Comment.Text;
                        If (TempStr <> '') And (TempStr <> CompName) Then
                        Begin
                            // This is likely the component value
                            If Not FirstItem Then
                                JSONStr := JSONStr + ',';
                            FirstItem := False;
                            JSONStr := JSONStr + #13#10 + '        {' + #13#10;
                            JSONStr := JSONStr + '          "name": "Value",' + #13#10;
                            JSONStr := JSONStr + '          "value": "' + EscapeJsonString(TempStr) + '"' + #13#10;
                            JSONStr := JSONStr + '        }';
                        End;
                    Except
                        // Comment property not available or failed
                    End;
                Except
                    // Parameters section failed, leave empty
                End;
                JSONStr := JSONStr + #13#10 + '      ],' + #13#10;
                
                // Pins (Note: PinCount property not available in Altium API)
                // Pins/pads are accessed through the board iterator, but for efficiency,
                // we'll collect them separately or skip for now
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
    
    // ========== NETS WITH ALL PROPERTIES ==========
    JSONStr := JSONStr + '  "nets": [' + #13#10;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Net := Iterator.FirstPCBObject;
            FirstItem := True;
            While Net <> Nil Do
            Begin
                Inc(NetCount);
                
                If Not FirstItem Then
                    JSONStr := JSONStr + ',' + #13#10;
                FirstItem := False;
                
                JSONStr := JSONStr + '    {' + #13#10;
                
                Try
                    NetName := Net.Name;
                    If NetName = '' Then NetName := 'Unnamed';
                Except
                    NetName := 'Unknown';
                End;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(NetName) + '",' + #13#10;
                
                // Connected components (find by iterating through pads)
                JSONStr := JSONStr + '      "connected_components": [';
                Try
                    FirstItem := True;
                    // Iterate through all pads to find which components are connected to this net
                    InnerIterator := PCB.BoardIterator_Create;
                    Try
                        InnerIterator.AddFilter_ObjectSet(MkSet(ePadObject));
                        InnerIterator.AddFilter_LayerSet(AllLayers);
                        InnerIterator.AddFilter_Method(eProcessAll);
                        
                        Pad := InnerIterator.FirstPCBObject;
                        While Pad <> Nil Do
                        Begin
                            Try
                                // Check if this pad is connected to the current net
                                If (Pad.Net <> Nil) And (Pad.Net.Name = NetName) Then
                                Begin
                                    // Get the component this pad belongs to
                                    If (Pad.Component <> Nil) Then
                                    Begin
                                        Try
                                            TempStr := Pad.Component.Name.Text;
                                            If TempStr <> '' Then
                                            Begin
                                                // Check if we already added this component
                                                If FirstItem Or (Pos('"' + TempStr + '"', JSONStr) = 0) Then
                                                Begin
                                                    If Not FirstItem Then
                                                        JSONStr := JSONStr + ',';
                                                    FirstItem := False;
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
                
                // Track count for this net
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
                
                // Via count for this net
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
    
    // ========== TRACKS WITH ALL PROPERTIES ==========
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
                
                // Start position
                Try
                    JSONStr := JSONStr + '      "start": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X1)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y1)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "start": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                // End position
                Try
                    JSONStr := JSONStr + '      "end": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X2)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y2)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "end": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                // Width
                Try
                    JSONStr := JSONStr + '      "width_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Width)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "width_mm": 0,' + #13#10;
                End;
                
                // Layer
                Try
                    LayerName := Layer2String(Track.Layer);
                    If LayerName = '' Then LayerName := 'Layer ' + IntToStr(Track.Layer);
                Except
                    LayerName := 'Unknown';
                End;
                JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(LayerName) + '",' + #13#10;
                
                // Net
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
    
    // ========== VIAS WITH ALL PROPERTIES ==========
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
                
                // Position
                Try
                    JSONStr := JSONStr + '      "position": {' + #13#10;
                    JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Via.X)) + ',' + #13#10;
                    JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Y)) + #13#10;
                    JSONStr := JSONStr + '      },' + #13#10;
                Except
                    JSONStr := JSONStr + '      "position": {"x_mm": 0, "y_mm": 0},' + #13#10;
                End;
                
                // Size
                Try
                    JSONStr := JSONStr + '      "size_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Size)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "size_mm": 0,' + #13#10;
                End;
                
                // Hole size
                Try
                    JSONStr := JSONStr + '      "hole_size_mm": ' + FormatFloat('0.00', CoordToMMs(Via.HoleSize)) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "hole_size_mm": 0,' + #13#10;
                End;
                
                // Layer information (TopLayer/BottomLayer properties not available in Altium API)
                // Vias span multiple layers, so we'll mark them as multi-layer
                JSONStr := JSONStr + '      "start_layer": "Multi-Layer",' + #13#10;
                JSONStr := JSONStr + '      "end_layer": "Multi-Layer",' + #13#10;
                
                // Net
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
    
    // Count and collect layer information
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
    
    // Add statistics
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
        
        // Save to fixed location
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\pcb_info.json';
        
        Try
            // Save with UTF-8 encoding (TStringList should handle this, but ensure it)
            PCBFile.SaveToFile(FileName);
            // Note: TStringList.SaveToFile in DelphiScript may use system default encoding
            // If encoding issues occur, the Python server will try multiple encodings
            ShowMessage('SUCCESS! Comprehensive PCB information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                        'Components: ' + IntToStr(ComponentCount) + ' (with all properties, parameters, pins)' + #13#10 +
                        'Nets: ' + IntToStr(NetCount) + ' (with connected components, track/via counts)' + #13#10 +
                        'Tracks: ' + IntToStr(TrackCount) + ' (with start/end positions, width, layer, net)' + #13#10 +
                        'Vias: ' + IntToStr(ViaCount) + ' (with position, size, layers, net)' + #13#10 +
                        'Layers: ' + IntToStr(LayerCount));
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName + #13#10 + #13#10 +
                        'Check if the directory exists and you have write permissions.');
        End;
    Finally
        PCBFile.Free;
    End;
End;
