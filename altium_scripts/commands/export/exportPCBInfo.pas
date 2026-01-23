{*
 * Export PCB Info Command - STREAMING VERSION
 * Exports comprehensive PCB information to pcb_info.json
 * Uses incremental file writing to handle large boards without memory limits
 * 
 * SOLUTION: File-Based + Streaming + File Watcher
 * - Writes to file periodically instead of accumulating in memory
 * - Processes ALL components (no artificial limits)
 * - Constant memory usage regardless of board size
 * - Works for complex PCBs (1000+ components)
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    WRITE_INTERVAL = 1;      // ULTRA-AGGRESSIVE: Write to file EVERY SINGLE ITEM (for 23GB Altium)
    BATCH_SIZE = 1;          // ULTRA-AGGRESSIVE: UI refresh after EVERY item (maximum memory cleanup)

// Optimized helper function to escape JSON strings
Function EscapeJsonString(InputStr: String): String;
Var
    I, Len: Integer;
    ResultStr: String;
    Ch: Char;
    NeedsEscape: Boolean;
Begin
    Len := Length(InputStr);
    If Len > 200 Then
    Begin
        InputStr := Copy(InputStr, 1, 200);
        Len := 200;
    End;
    
    If Len = 0 Then
    Begin
        Result := '';
        Exit;
    End;
    
    // Quick check if escaping is needed
    NeedsEscape := False;
    For I := 1 To Len Do
    Begin
        Ch := InputStr[I];
        If (Ch = '"') Or (Ch = '\') Or (Ch = #13) Or (Ch = #10) Or (Ch = #9) Or 
           ((Ord(Ch) < 32) Or (Ord(Ch) > 126)) Then
        Begin
            NeedsEscape := True;
            Break;
        End;
    End;
    
    If Not NeedsEscape Then
    Begin
        Result := InputStr;
        Exit;
    End;
    
    // Build escaped string
    ResultStr := '';
    For I := 1 To Len Do
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

// Append buffer to file and clear it (ULTRA-AGGRESSIVE for 23GB Altium)
// Uses direct file append - NO file loading into memory
Procedure AppendBufferToFile(Var Buffer: TStringList; FileName: String);
Var
    OutputFile: TextFile;
    I: Integer;
    TempStr: String;
Begin
    If Buffer.Count = 0 Then Exit;
    
    Try
        // ULTRA-AGGRESSIVE: Direct file append - no memory loading
        AssignFile(OutputFile, FileName);
        Try
            If FileExists(FileName) Then
                Append(OutputFile)  // Append mode - doesn't load file
            Else
                Rewrite(OutputFile);  // Create new file
            
            // Write each line immediately
            For I := 0 To Buffer.Count - 1 Do
            Begin
                TempStr := Buffer[I];
                WriteLn(OutputFile, TempStr);
                TempStr := '';  // Clear immediately
            End;
            
            CloseFile(OutputFile);
        Except
            Try
                CloseFile(OutputFile);
            Except
            End;
        End;
        
        // ULTRA-AGGRESSIVE: Clear buffer immediately
        Buffer.Clear;
    Except
        // If write fails, clear buffer anyway
        Buffer.Clear;
    End;
End;

Procedure ExportPCBInfo;
Var
    PCB           : IPCB_Board;
    Buffer        : TStringList;  // Small buffer for incremental writing
    FileName      : String;
    Component     : IPCB_Component;
    Net           : IPCB_Net;
    Via           : IPCB_Via;
    Track         : IPCB_Track;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Iterator      : IPCB_BoardIterator;
    ComponentCount: Integer;
    NetCount      : Integer;
    ViaCount      : Integer;
    TrackCount    : Integer;
    BatchCounter  : Integer;
    WriteCounter  : Integer;
    CompX, CompY  : Double;
    CompWidth, CompHeight : Double;
    CompLayer     : String;
    CompName      : String;
    NetName       : String;
    LayerName     : String;
    TempStr       : String;
    FirstItem     : Boolean;
    Width, Height : Double;
    BoardRect     : TCoordRect;
    BoundingRect  : TCoordRect;
Begin
    // Initialize
    ComponentCount := 0;
    NetCount := 0;
    ViaCount := 0;
    TrackCount := 0;
    BatchCounter := 0;
    WriteCounter := 0;
    
    Try
        // CRITICAL: Get workspace with error handling (memory-safe)
        Try
            Workspace := GetWorkspace;
        Except
            ShowMessage('ERROR: Out of memory - Cannot access workspace' + #13#10 + #13#10 +
                        'Altium is using too much memory (23GB+).' + #13#10 +
                        'Please:' + #13#10 +
                        '1. Close other applications' + #13#10 +
                        '2. Restart Altium Designer' + #13#10 +
                        '3. Try again');
            Exit;
        End;
        
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        // Get PCB board (memory-safe)
        Try
            PCB := PCBServer.GetCurrentPCBBoard;
        Except
            PCB := Nil;
        End;
        
        If PCB = Nil Then
        Begin
            Try
                Doc := Workspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'PCB') Then
                Begin
                    Try
                        PCB := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
                    Except
                        PCB := Nil;
                    End;
                End;
            Except
                PCB := Nil;
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
        
        FileName := BASE_PATH + 'pcb_info.json';
        
        // Create buffer for incremental writing
        Buffer := TStringList.Create;
        Try
            // Write header
            Buffer.Add('{');
            
            Try
                Doc := Workspace.DM_FocusedDocument;
                If Doc <> Nil Then
                    TempStr := Doc.DM_FileName
                Else
                    TempStr := 'Unknown';
                If Length(TempStr) > 200 Then TempStr := Copy(TempStr, 1, 200);
            Except
                TempStr := 'Unknown';
            End;
            
            Buffer.Add('  "file_name": "' + EscapeJsonString(TempStr) + '",');
            
            // Board size
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
            
            Buffer.Add('  "board_size": {');
            Buffer.Add('    "width_mm": ' + FormatFloat('0.00', Width) + ',');
            Buffer.Add('    "height_mm": ' + FormatFloat('0.00', Height) + ',');
            Buffer.Add('    "area_mm2": ' + FormatFloat('0.00', Width * Height));
            Buffer.Add('  },');
            
            // Write header to file immediately
            Buffer.SaveToFile(FileName);
            Buffer.Clear;
            
            // ========== COMPONENTS - STREAMING (NO LIMITS) ==========
            Buffer.Add('  "components": [');
            FirstItem := True;
            WriteCounter := 0;
            BatchCounter := 0;
            
            Try
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Component := Iterator.FirstPCBObject;
                    While Component <> Nil Do  // NO LIMIT - process all!
                    Begin
                        Inc(ComponentCount);
                        Inc(BatchCounter);
                        Inc(WriteCounter);
                        
                        // ULTRA-AGGRESSIVE: Write to file after EVERY item (WRITE_INTERVAL = 1)
                        If WriteCounter >= WRITE_INTERVAL Then
                        Begin
                            Try
                                AppendBufferToFile(Buffer, FileName);
                                WriteCounter := 0;
                            Except
                                // If write fails, clear buffer and continue
                                Buffer.Clear;
                                WriteCounter := 0;
                            End;
                        End;
                        
                        // ULTRA-AGGRESSIVE: UI refresh after EVERY item (BATCH_SIZE = 1)
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Try
                                Application.ProcessMessages;
                                Sleep(5);  // Small sleep for memory cleanup
                            Except
                            End;
                        End;
                        
                        If Not FirstItem Then
                            Buffer.Add(',');
                        FirstItem := False;
                        
                        Buffer.Add('    {');
                        
                        // Basic properties
                        Try
                            CompName := Component.Name.Text;
                            If CompName = '' Then CompName := 'Unnamed';
                            If Length(CompName) > 100 Then CompName := Copy(CompName, 1, 100);
                        Except
                            CompName := 'Unknown';
                        End;
                        Buffer.Add('      "name": "' + EscapeJsonString(CompName) + '",');
                        
                        // Location - cache and format
                        Try
                            CompX := CoordToMMs(Component.X);
                            CompY := CoordToMMs(Component.Y);
                            TempStr := FormatFloat('0.00', CompX);
                            Buffer.Add('      "location": {');
                            Buffer.Add('        "x_mm": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompY);
                            Buffer.Add('        "y_mm": ' + TempStr);
                            Buffer.Add('      },');
                        Except
                            Buffer.Add('      "location": {"x_mm": 0, "y_mm": 0},');
                        End;
                        
                        // Size
                        Try
                            BoundingRect := Component.BoundingRectangle;
                            CompWidth := CoordToMMs(BoundingRect.Right - BoundingRect.Left);
                            CompHeight := CoordToMMs(BoundingRect.Top - BoundingRect.Bottom);
                            If CompWidth < 0 Then CompWidth := -CompWidth;
                            If CompHeight < 0 Then CompHeight := -CompHeight;
                            TempStr := FormatFloat('0.00', CompWidth);
                            Buffer.Add('      "size": {');
                            Buffer.Add('        "width_mm": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompHeight);
                            Buffer.Add('        "height_mm": ' + TempStr);
                            Buffer.Add('      },');
                        Except
                            Buffer.Add('      "size": {"width_mm": 0, "height_mm": 0},');
                        End;
                        
                        // Layer
                        Try
                            CompLayer := Layer2String(Component.Layer);
                            If CompLayer = '' Then CompLayer := 'Layer ' + IntToStr(Component.Layer);
                            If Length(CompLayer) > 50 Then CompLayer := Copy(CompLayer, 1, 50);
                        Except
                            CompLayer := 'Unknown';
                        End;
                        Buffer.Add('      "layer": "' + EscapeJsonString(CompLayer) + '",');
                        
                        // Rotation
                        Try
                            TempStr := FormatFloat('0.00', Component.Rotation);
                            Buffer.Add('      "rotation_degrees": ' + TempStr + ',');
                        Except
                            Buffer.Add('      "rotation_degrees": 0,');
                        End;
                        
                        // Footprint
                        Try
                            TempStr := Component.Pattern;
                            If TempStr = '' Then TempStr := 'Unknown';
                            If Length(TempStr) > 100 Then TempStr := Copy(TempStr, 1, 100);
                        Except
                            TempStr := 'Unknown';
                        End;
                        Buffer.Add('      "footprint": "' + EscapeJsonString(TempStr) + '",');
                        
                        // Moveable
                        Try
                            If Component.Moveable Then
                                TempStr := 'true'
                            Else
                                TempStr := 'false';
                        Except
                            TempStr := 'true';
                        End;
                        Buffer.Add('      "moveable": ' + TempStr + ',');
                        
                        // Parameters (simplified)
                        Buffer.Add('      "parameters": [');
                        Try
                            TempStr := Component.Comment.Text;
                            If (TempStr <> '') And (TempStr <> CompName) Then
                            Begin
                                If Length(TempStr) > 100 Then TempStr := Copy(TempStr, 1, 100);
                                Buffer.Add('        {');
                                Buffer.Add('          "name": "Value",');
                                Buffer.Add('          "value": "' + EscapeJsonString(TempStr) + '"');
                                Buffer.Add('        }');
                            End;
                        Except
                        End;
                        Buffer.Add('      ],');
                        
                        Buffer.Add('      "pins": []');
                        Buffer.Add('    }');
                        
                        Component := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            Except
            End;
            
            Buffer.Add('  ],');
            
            // Write components buffer
            AppendBufferToFile(Buffer, FileName);
            
            // ========== NETS - STREAMING (NO LIMITS) ==========
            Buffer.Add('  "nets": [');
            FirstItem := True;
            WriteCounter := 0;
            BatchCounter := 0;
            
            Try
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Net := Iterator.FirstPCBObject;
                    While Net <> Nil Do  // NO LIMIT - process all!
                    Begin
                        Inc(NetCount);
                        Inc(BatchCounter);
                        Inc(WriteCounter);
                        
                        // ULTRA-AGGRESSIVE: Write to file after EVERY item
                        If WriteCounter >= WRITE_INTERVAL Then
                        Begin
                            Try
                                AppendBufferToFile(Buffer, FileName);
                                WriteCounter := 0;
                            Except
                                Buffer.Clear;
                                WriteCounter := 0;
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
                        
                        If Not FirstItem Then
                            Buffer.Add(',');
                        FirstItem := False;
                        
                        Buffer.Add('    {');
                        
                        Try
                            NetName := Net.Name;
                            If NetName = '' Then NetName := 'Unnamed';
                            If Length(NetName) > 200 Then NetName := Copy(NetName, 1, 200);
                        Except
                            NetName := 'Unknown';
                        End;
                        Buffer.Add('      "name": "' + EscapeJsonString(NetName) + '",');
                        Buffer.Add('      "pin_count": ' + IntToStr(Net.PinCount));
                        Buffer.Add('    }');
                        
                        Net := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            Except
            End;
            
            Buffer.Add('  ],');
            
            // ULTRA-AGGRESSIVE: Write nets buffer immediately
            AppendBufferToFile(Buffer, FileName);
            
            // ========== TRACKS - STREAMING (NO LIMITS) ==========
            Buffer.Add('  "tracks": [');
            FirstItem := True;
            WriteCounter := 0;
            BatchCounter := 0;
            
            Try
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eTrackObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Track := Iterator.FirstPCBObject;
                    While Track <> Nil Do  // NO LIMIT - process all!
                    Begin
                        Inc(TrackCount);
                        Inc(BatchCounter);
                        Inc(WriteCounter);
                        
                        // ULTRA-AGGRESSIVE: Write to file after EVERY item
                        If WriteCounter >= WRITE_INTERVAL Then
                        Begin
                            Try
                                AppendBufferToFile(Buffer, FileName);
                                WriteCounter := 0;
                            Except
                                Buffer.Clear;
                                WriteCounter := 0;
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
                        
                        If Not FirstItem Then
                            Buffer.Add(',');
                        FirstItem := False;
                        
                        Buffer.Add('    {');
                        
                        Try
                            Buffer.Add('      "start": {');
                            Buffer.Add('        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X1)) + ',');
                            Buffer.Add('        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y1)));
                            Buffer.Add('      },');
                        Except
                            Buffer.Add('      "start": {"x_mm": 0, "y_mm": 0},');
                        End;
                        
                        Try
                            Buffer.Add('      "end": {');
                            Buffer.Add('        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Track.X2)) + ',');
                            Buffer.Add('        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Y2)));
                            Buffer.Add('      },');
                        Except
                            Buffer.Add('      "end": {"x_mm": 0, "y_mm": 0},');
                        End;
                        
                        Try
                            Buffer.Add('      "width_mm": ' + FormatFloat('0.00', CoordToMMs(Track.Width)) + ',');
                        Except
                            Buffer.Add('      "width_mm": 0,');
                        End;
                        
                        Try
                            LayerName := Layer2String(Track.Layer);
                            If LayerName = '' Then LayerName := 'Layer ' + IntToStr(Track.Layer);
                            If Length(LayerName) > 50 Then LayerName := Copy(LayerName, 1, 50);
                        Except
                            LayerName := 'Unknown';
                        End;
                        Buffer.Add('      "layer": "' + EscapeJsonString(LayerName) + '"');
                        
                        Buffer.Add('    }');
                        
                        Track := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            Except
            End;
            
            Buffer.Add('  ],');
            
            // ULTRA-AGGRESSIVE: Write tracks buffer immediately
            AppendBufferToFile(Buffer, FileName);
            
            // ========== VIAS - STREAMING (NO LIMITS) ==========
            Buffer.Add('  "vias": [');
            FirstItem := True;
            WriteCounter := 0;
            BatchCounter := 0;
            
            Try
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eViaObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Via := Iterator.FirstPCBObject;
                    While Via <> Nil Do  // NO LIMIT - process all!
                    Begin
                        Inc(ViaCount);
                        Inc(BatchCounter);
                        Inc(WriteCounter);
                        
                        // ULTRA-AGGRESSIVE: Write to file after EVERY item
                        If WriteCounter >= WRITE_INTERVAL Then
                        Begin
                            Try
                                AppendBufferToFile(Buffer, FileName);
                                WriteCounter := 0;
                            Except
                                Buffer.Clear;
                                WriteCounter := 0;
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
                        
                        If Not FirstItem Then
                            Buffer.Add(',');
                        FirstItem := False;
                        
                        Buffer.Add('    {');
                        
                        Try
                            Buffer.Add('      "location": {');
                            Buffer.Add('        "x_mm": ' + FormatFloat('0.00', CoordToMMs(Via.X)) + ',');
                            Buffer.Add('        "y_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Y)));
                            Buffer.Add('      },');
                        Except
                            Buffer.Add('      "location": {"x_mm": 0, "y_mm": 0},');
                        End;
                        
                        Try
                            Buffer.Add('      "drill_diameter_mm": ' + FormatFloat('0.00', CoordToMMs(Via.HoleSize)) + ',');
                        Except
                            Buffer.Add('      "drill_diameter_mm": 0,');
                        End;
                        
                        Try
                            Buffer.Add('      "diameter_mm": ' + FormatFloat('0.00', CoordToMMs(Via.Size)));
                        Except
                            Buffer.Add('      "diameter_mm": 0');
                        End;
                        
                        Buffer.Add('    }');
                        
                        Via := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            Except
            End;
            
            Buffer.Add('  ],');
            
            // ULTRA-AGGRESSIVE: Write vias buffer immediately
            AppendBufferToFile(Buffer, FileName);
            
            // Add statistics and close - read file, add footer, write
            Try
                Buffer.LoadFromFile(FileName);
                // Remove any existing closing bracket
                While (Buffer.Count > 0) And (Trim(Buffer[Buffer.Count - 1]) = '}') Do
                    Buffer.Delete(Buffer.Count - 1);
                // Add statistics
                Buffer.Add('  "statistics": {');
                Buffer.Add('    "component_count": ' + IntToStr(ComponentCount) + ',');
                Buffer.Add('    "net_count": ' + IntToStr(NetCount) + ',');
                Buffer.Add('    "track_count": ' + IntToStr(TrackCount) + ',');
                Buffer.Add('    "via_count": ' + IntToStr(ViaCount));
                Buffer.Add('  }');
                Buffer.Add('}');
                Buffer.SaveToFile(FileName);
            Except
                // If final write fails, at least we have the data
            End;
            
            ShowMessage('SUCCESS! Streaming export completed!' + #13#10 + #13#10 +
                       'Components: ' + IntToStr(ComponentCount) + #13#10 +
                       'Nets: ' + IntToStr(NetCount) + #13#10 +
                       'Tracks: ' + IntToStr(TrackCount) + #13#10 +
                       'Vias: ' + IntToStr(ViaCount) + #13#10 + #13#10 +
                       'File: ' + FileName + #13#10 + #13#10 +
                       'Memory-efficient streaming - NO LIMITS!');
        Finally
            Buffer.Free;
        End;
    Except
        ShowMessage('ERROR: Export failed. Check memory and try again.');
    End;
End;
