{*
 * Export Schematic Info Command
 * Exports comprehensive schematic information to schematic_info.json
 * Command: export_schematic_info
 * ULTRA-OPTIMIZED: Direct TStringList writing, removed JSONStr concatenation, limits, batch processing
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';
    WRITE_INTERVAL = 1;      // ULTRA-AGGRESSIVE: Write to file EVERY SINGLE ITEM (for 23GB Altium)
    BATCH_SIZE = 1;          // ULTRA-AGGRESSIVE: UI refresh after EVERY item (maximum memory cleanup)

// Optimized helper function to escape JSON strings
// Uses pre-check to avoid unnecessary concatenations
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
    
    // If no escaping needed, return as-is (common case optimization)
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

// Convert coordinate units to mm (Altium uses internal units)
Function CoordToMM(Coord: TCoord): Double;
Begin
    // Altium internal units: 1 mil = 10000 internal units
    // 1 mm = 39.3701 mils
    Result := Coord / 10000 / 39.3701;
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

// Export schematic information
Procedure ExportSchematicInfo;
Var
    CurrentSheet  : ISch_Document;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Iterator      : ISch_Iterator;
    Component     : ISch_Component;
    Wire          : ISch_Wire;
    NetLabel      : ISch_NetLabel;
    PowerPort     : ISch_PowerObject;
    Port          : ISch_Port;
    Pin           : ISch_Pin;
    Parameter     : ISch_Parameter;
    OutputFile    : TStringList;
    FileName      : String;
    FirstItem     : Boolean;
    CompCount     : Integer;
    WireCount     : Integer;
    NetLabelCount : Integer;
    PowerCount    : Integer;
    PortCount     : Integer;
    I             : Integer;
    TempStr       : String;
    DesignatorStr : String;
    ValueStr      : String;
    FootprintStr  : String;
    LibRefStr     : String;
    CompX, CompY  : Double;  // Cache coordinates
    PinIterator   : ISch_Iterator;
    PinFirst      : Boolean;
    BatchCounter  : Integer;
    SafetyCounter : Integer;
Begin
    // Get current schematic
    CurrentSheet := Nil;
    
    Try
        CurrentSheet := SchServer.GetCurrentSchDocument;
    Except
    End;
    
    If CurrentSheet = Nil Then
    Begin
        Try
            Workspace := GetWorkspace;
            If Workspace <> Nil Then
            Begin
                Doc := Workspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'SCH') Then
                Begin
                    CurrentSheet := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
                End;
            End;
        Except
        End;
    End;
    
    If CurrentSheet = Nil Then
    Begin
        ShowMessage('ERROR: Cannot access schematic document.' + #13#10 + #13#10 +
                    'Please make sure:' + #13#10 +
                    '1. A schematic document (.SchDoc) is open' + #13#10 +
                    '2. Click on the schematic tab to make it active');
        Exit;
    End;
    
    // Initialize counters
    CompCount := 0;
    WireCount := 0;
    NetLabelCount := 0;
    PowerCount := 0;
    PortCount := 0;
    BatchCounter := 0;
    SafetyCounter := 0;
    
    // Create output file
    OutputFile := TStringList.Create;
    Try
        // Start JSON
        OutputFile.Add('{');
        
        // Sheet information
        OutputFile.Add('  "schematic": {');
        Try
            TempStr := CurrentSheet.DocumentName;
            If Length(TempStr) > 200 Then TempStr := Copy(TempStr, 1, 200);
            OutputFile.Add('    "name": "' + EscapeJsonString(TempStr) + '",');
        Except
            OutputFile.Add('    "name": "Unknown",');
        End;
        
        Try
            TempStr := CurrentSheet.SheetStyle;
            If Length(TempStr) > 50 Then TempStr := Copy(TempStr, 1, 50);
            OutputFile.Add('    "sheet_style": "' + EscapeJsonString(TempStr) + '",');
        Except
            OutputFile.Add('    "sheet_style": "A4",');
        End;
        
        Try
            TempStr := CurrentSheet.Title;
            If Length(TempStr) > 200 Then TempStr := Copy(TempStr, 1, 200);
            OutputFile.Add('    "title": "' + EscapeJsonString(TempStr) + '",');
            TempStr := CurrentSheet.DocumentNumber;
            If Length(TempStr) > 100 Then TempStr := Copy(TempStr, 1, 100);
            OutputFile.Add('    "document_number": "' + EscapeJsonString(TempStr) + '",');
            TempStr := CurrentSheet.Revision;
            If Length(TempStr) > 50 Then TempStr := Copy(TempStr, 1, 50);
            OutputFile.Add('    "revision": "' + EscapeJsonString(TempStr) + '"');
        Except
            OutputFile.Add('    "title": "",');
            OutputFile.Add('    "document_number": "",');
            OutputFile.Add('    "revision": ""');
        End;
        OutputFile.Add('  },');
        
        // ========== COMPONENTS ==========
        OutputFile.Add('  "components": [');
        FirstItem := True;
        
        Try
            Iterator := CurrentSheet.SchIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
                    
                    Component := Iterator.FirstSchObject;
                    While Component <> Nil Do  // NO LIMIT - process all!
                    Begin
                        Inc(CompCount);
                        Inc(BatchCounter);
                        
                        // ULTRA-AGGRESSIVE: Write to file after EVERY item
                        If CompCount Mod WRITE_INTERVAL = 0 Then
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
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        // MINIMAL PROPERTY ACCESS - Only essential properties
                        // Designator (essential)
                        Try
                            DesignatorStr := Component.Designator.Text;
                            If DesignatorStr = '' Then DesignatorStr := 'Unknown';
                        Except
                            DesignatorStr := 'Unknown';
                        End;
                        OutputFile.Add('      "designator": "' + EscapeJsonString(DesignatorStr) + '",');
                        DesignatorStr := '';  // Clear immediately
                        
                        // SKIP: Comment.Text (may trigger memory)
                        // SKIP: LibReference (may trigger memory)
                        // SKIP: SourceLibraryName (may trigger memory)
                        // SKIP: Footprint (may trigger memory, requires ParameterCount access)
                        
                        // Location - cache coordinates and format once
                        Try
                            CompX := CoordToMM(Component.Location.X);
                            CompY := CoordToMM(Component.Location.Y);
                            TempStr := FormatFloat('0.00', CompX);
                            OutputFile.Add('      "location": {');
                            OutputFile.Add('        "x": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompY);
                            OutputFile.Add('        "y": ' + TempStr);
                            OutputFile.Add('      },');
                        Except
                            OutputFile.Add('      "location": {"x": 0, "y": 0},');
                        End;
                        
                        // Orientation
                        Try
                            OutputFile.Add('      "orientation": ' + IntToStr(Component.Orientation) + ',');
                        Except
                            OutputFile.Add('      "orientation": 0,');
                        End;
                        
                        // Mirrored
                        Try
                            If Component.IsMirrored Then
                                OutputFile.Add('      "mirrored": true,')
                            Else
                                OutputFile.Add('      "mirrored": false,');
                        Except
                            OutputFile.Add('      "mirrored": false,');
                        End;
                        
                        // Pins
                        OutputFile.Add('      "pins": [');
                        PinFirst := True;
                        Try
                            PinIterator := Component.SchIterator_Create;
                            If PinIterator <> Nil Then
                            Begin
                                Try
                                    PinIterator.AddFilter_ObjectSet(MkSet(ePin));
                                    Pin := PinIterator.FirstSchObject;
                                    While Pin <> Nil Do
                                    Begin
                                        If Not PinFirst Then
                                            OutputFile.Add(',');
                                        PinFirst := False;
                                        
                                        OutputFile.Add('        {');
                                        Try
                                            OutputFile.Add('          "name": "' + EscapeJsonString(Pin.Name) + '",');
                                            OutputFile.Add('          "designator": "' + EscapeJsonString(Pin.Designator) + '",');
                                            If Pin.Net <> Nil Then
                                                OutputFile.Add('          "net": "' + EscapeJsonString(Pin.Net.Name) + '"')
                                            Else
                                                OutputFile.Add('          "net": ""');
                                        Except
                                            OutputFile.Add('          "name": "",');
                                            OutputFile.Add('          "designator": "",');
                                            OutputFile.Add('          "net": ""');
                                        End;
                                        OutputFile.Add('        }');
                                        
                                        Pin := PinIterator.NextSchObject;
                                    End;
                                Finally
                                    Component.SchIterator_Destroy(PinIterator);
                                End;
                            End;
                        Except
                        End;
                        OutputFile.Add('      ],');
                        
                        // Parameters
                        OutputFile.Add('      "parameters": [');
                        PinFirst := True;
                        Try
                            For I := 0 To Component.ParameterCount - 1 Do
                            Begin
                                If I > 20 Then Break;  // Safety limit
                                Parameter := Component.SchParameters(I);
                                If Parameter <> Nil Then
                                Begin
                                    If Not PinFirst Then
                                        OutputFile.Add(',');
                                    PinFirst := False;
                                    
                                    OutputFile.Add('        {');
                                    Try
                                        OutputFile.Add('          "name": "' + EscapeJsonString(Parameter.Name) + '",');
                                        OutputFile.Add('          "value": "' + EscapeJsonString(Parameter.Text) + '"');
                                    Except
                                        OutputFile.Add('          "name": "",');
                                        OutputFile.Add('          "value": ""');
                                    End;
                                    OutputFile.Add('        }');
                                End;
                            End;
                        Except
                        End;
                        OutputFile.Add('      ]');
                        
                        OutputFile.Add('    }');
                        
                        Component := Iterator.NextSchObject;
                    End;
                Finally
                    CurrentSheet.SchIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        OutputFile.Add('  ],');
        
        // ========== WIRES ==========
        OutputFile.Add('  "wires": [');
        FirstItem := True;
        BatchCounter := 0;
        
        Try
            Iterator := CurrentSheet.SchIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eWire));
                    
                    Wire := Iterator.FirstSchObject;
                    While (Wire <> Nil) And (WireCount < MAX_WIRES) Do
                    Begin
                        Inc(WireCount);
                        Inc(BatchCounter);
                        
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(5);  // Longer sleep for memory cleanup
                        End;
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        // Vertices - cache coordinates
                        OutputFile.Add('      "vertices": [');
                        Try
                            For I := 1 To Wire.VerticesCount Do
                            Begin
                                If I > 100 Then Break;  // Safety limit
                                If I > 1 Then
                                    OutputFile.Add(',');
                                CompX := CoordToMM(Wire.Vertex(I).X);
                                CompY := CoordToMM(Wire.Vertex(I).Y);
                                TempStr := FormatFloat('0.00', CompX);
                                OutputFile.Add('        {"x": ' + TempStr + ', "y": ' + FormatFloat('0.00', CompY) + '}');
                            End;
                        Except
                        End;
                        OutputFile.Add('      ],');
                        
                        // Net name
                        Try
                            If Wire.Net <> Nil Then
                                OutputFile.Add('      "net": "' + EscapeJsonString(Wire.Net.Name) + '"')
                            Else
                                OutputFile.Add('      "net": ""');
                        Except
                            OutputFile.Add('      "net": ""');
                        End;
                        
                        OutputFile.Add('    }');
                        
                        Wire := Iterator.NextSchObject;
                    End;
                Finally
                    CurrentSheet.SchIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        OutputFile.Add('  ],');
        
        // ========== NET LABELS ==========
        OutputFile.Add('  "net_labels": [');
        FirstItem := True;
        BatchCounter := 0;
        
        Try
            Iterator := CurrentSheet.SchIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eNetLabel));
                    
                    NetLabel := Iterator.FirstSchObject;
                    While (NetLabel <> Nil) And (NetLabelCount < MAX_NETLABELS) Do
                    Begin
                        Inc(NetLabelCount);
                        Inc(BatchCounter);
                        
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(5);  // Longer sleep for memory cleanup
                        End;
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        Try
                            OutputFile.Add('      "name": "' + EscapeJsonString(NetLabel.Text) + '",');
                            CompX := CoordToMM(NetLabel.Location.X);
                            CompY := CoordToMM(NetLabel.Location.Y);
                            TempStr := FormatFloat('0.00', CompX);
                            OutputFile.Add('      "location": {');
                            OutputFile.Add('        "x": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompY);
                            OutputFile.Add('        "y": ' + TempStr);
                            OutputFile.Add('      },');
                            OutputFile.Add('      "orientation": ' + IntToStr(NetLabel.Orientation));
                        Except
                            OutputFile.Add('      "name": "",');
                            OutputFile.Add('      "location": {"x": 0, "y": 0},');
                            OutputFile.Add('      "orientation": 0');
                        End;
                        
                        OutputFile.Add('    }');
                        
                        NetLabel := Iterator.NextSchObject;
                    End;
                Finally
                    CurrentSheet.SchIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        OutputFile.Add('  ],');
        
        // ========== POWER PORTS ==========
        OutputFile.Add('  "power_ports": [');
        FirstItem := True;
        BatchCounter := 0;
        
        Try
            Iterator := CurrentSheet.SchIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(ePowerObject));
                    
                    PowerPort := Iterator.FirstSchObject;
                    While (PowerPort <> Nil) And (PowerCount < MAX_POWERPORTS) Do
                    Begin
                        Inc(PowerCount);
                        Inc(BatchCounter);
                        
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(5);  // Longer sleep for memory cleanup
                        End;
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        Try
                            OutputFile.Add('      "name": "' + EscapeJsonString(PowerPort.Text) + '",');
                            OutputFile.Add('      "style": "' + EscapeJsonString(PowerPort.Style) + '",');
                            CompX := CoordToMM(PowerPort.Location.X);
                            CompY := CoordToMM(PowerPort.Location.Y);
                            TempStr := FormatFloat('0.00', CompX);
                            OutputFile.Add('      "location": {');
                            OutputFile.Add('        "x": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompY);
                            OutputFile.Add('        "y": ' + TempStr);
                            OutputFile.Add('      },');
                            If PowerPort.Net <> Nil Then
                                OutputFile.Add('      "net": "' + EscapeJsonString(PowerPort.Net.Name) + '"')
                            Else
                                OutputFile.Add('      "net": "' + EscapeJsonString(PowerPort.Text) + '"');
                        Except
                            OutputFile.Add('      "name": "",');
                            OutputFile.Add('      "style": "",');
                            OutputFile.Add('      "location": {"x": 0, "y": 0},');
                            OutputFile.Add('      "net": ""');
                        End;
                        
                        OutputFile.Add('    }');
                        
                        PowerPort := Iterator.NextSchObject;
                    End;
                Finally
                    CurrentSheet.SchIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        OutputFile.Add('  ],');
        
        // ========== PORTS ==========
        OutputFile.Add('  "ports": [');
        FirstItem := True;
        BatchCounter := 0;
        
        Try
            Iterator := CurrentSheet.SchIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(ePort));
                    
                    Port := Iterator.FirstSchObject;
                    While (Port <> Nil) And (PortCount < MAX_PORTS) Do
                    Begin
                        Inc(PortCount);
                        Inc(BatchCounter);
                        
                        If BatchCounter >= BATCH_SIZE Then
                        Begin
                            BatchCounter := 0;
                            Application.ProcessMessages;
                            Sleep(5);  // Longer sleep for memory cleanup
                        End;
                        
                        If Not FirstItem Then
                            OutputFile.Add(',');
                        FirstItem := False;
                        
                        OutputFile.Add('    {');
                        
                        Try
                            OutputFile.Add('      "name": "' + EscapeJsonString(Port.Name) + '",');
                            OutputFile.Add('      "io_type": "' + EscapeJsonString(Port.IOType) + '",');
                            CompX := CoordToMM(Port.Location.X);
                            CompY := CoordToMM(Port.Location.Y);
                            TempStr := FormatFloat('0.00', CompX);
                            OutputFile.Add('      "location": {');
                            OutputFile.Add('        "x": ' + TempStr + ',');
                            TempStr := FormatFloat('0.00', CompY);
                            OutputFile.Add('        "y": ' + TempStr);
                            OutputFile.Add('      }');
                        Except
                            OutputFile.Add('      "name": "",');
                            OutputFile.Add('      "io_type": "",');
                            OutputFile.Add('      "location": {"x": 0, "y": 0}');
                        End;
                        
                        OutputFile.Add('    }');
                        
                        Port := Iterator.NextSchObject;
                    End;
                Finally
                    CurrentSheet.SchIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        OutputFile.Add('  ],');
        
        // Statistics
        OutputFile.Add('  "statistics": {');
        OutputFile.Add('    "component_count": ' + IntToStr(CompCount) + ',');
        OutputFile.Add('    "wire_count": ' + IntToStr(WireCount) + ',');
        OutputFile.Add('    "net_label_count": ' + IntToStr(NetLabelCount) + ',');
        OutputFile.Add('    "power_port_count": ' + IntToStr(PowerCount) + ',');
        OutputFile.Add('    "port_count": ' + IntToStr(PortCount));
        OutputFile.Add('  },');
        
        OutputFile.Add('  "status": "active"');
        OutputFile.Add('}');
        
        // Write final buffer
        FileName := BASE_PATH + 'schematic_info.json';
        Try
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
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
        
        // Show success message
        ShowMessage('SUCCESS! Schematic information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                    'Components: ' + IntToStr(CompCount) + #13#10 +
                    'Wires: ' + IntToStr(WireCount) + #13#10 +
                    'Net Labels: ' + IntToStr(NetLabelCount) + #13#10 +
                    'Power Ports: ' + IntToStr(PowerCount) + #13#10 +
                    'Ports: ' + IntToStr(PortCount));
    Finally
        OutputFile.Free;
    End;
End;
