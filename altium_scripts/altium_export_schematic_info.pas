{*
 * Altium Designer Script - Export Schematic Information
 * Compatible with Altium Designer 25.5.2
 * 
 * Exports comprehensive schematic information to JSON:
 * - All components with designators, values, footprints
 * - All wires and connections
 * - All nets and net labels
 * - Power ports
 * - Sheet information
 * 
 * TO RUN THIS SCRIPT:
 * 1. Click on the Schematic document tab to make it active
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_export_schematic_info.pas
 * 4. When dialog appears, select "ExportSchematicInfo" procedure
 * 5. Click OK
 *}

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

// Convert coordinate units to mm (Altium uses internal units)
Function CoordToMM(Coord: TCoord): Double;
Begin
    // Altium internal units: 1 mil = 10000 internal units
    // 1 mm = 39.3701 mils
    Result := Coord / 10000 / 39.3701;
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
    SchObject     : ISch_GraphicalObject;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
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
    PinList       : String;
    PinIterator   : ISch_Iterator;
    PinFirst      : Boolean;
Begin
    // Get current schematic
    CurrentSheet := Nil;
    
    Try
        // Try to get current schematic document
        CurrentSheet := SchServer.GetCurrentSchDocument;
    Except
    End;
    
    If CurrentSheet = Nil Then
    Begin
        // Try via workspace
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
    
    // Build JSON
    JSONStr := '{' + #13#10;
    
    // Sheet information
    JSONStr := JSONStr + '  "schematic": {' + #13#10;
    Try
        JSONStr := JSONStr + '    "name": "' + EscapeJsonString(CurrentSheet.DocumentName) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '    "name": "Unknown",' + #13#10;
    End;
    
    Try
        // Get sheet size
        JSONStr := JSONStr + '    "sheet_style": "' + EscapeJsonString(CurrentSheet.SheetStyle) + '",' + #13#10;
    Except
        JSONStr := JSONStr + '    "sheet_style": "A4",' + #13#10;
    End;
    
    Try
        JSONStr := JSONStr + '    "title": "' + EscapeJsonString(CurrentSheet.Title) + '",' + #13#10;
        JSONStr := JSONStr + '    "document_number": "' + EscapeJsonString(CurrentSheet.DocumentNumber) + '",' + #13#10;
        JSONStr := JSONStr + '    "revision": "' + EscapeJsonString(CurrentSheet.Revision) + '"' + #13#10;
    Except
        JSONStr := JSONStr + '    "title": "",' + #13#10;
        JSONStr := JSONStr + '    "document_number": "",' + #13#10;
        JSONStr := JSONStr + '    "revision": ""' + #13#10;
    End;
    JSONStr := JSONStr + '  },' + #13#10;
    
    // ========== COMPONENTS ==========
    JSONStr := JSONStr + '  "components": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eSchComponent));
                
                Component := Iterator.FirstSchObject;
                While Component <> Nil Do
                Begin
                    Inc(CompCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    // Designator
                    Try
                        DesignatorStr := Component.Designator.Text;
                        If DesignatorStr = '' Then DesignatorStr := 'Unknown';
                    Except
                        DesignatorStr := 'Unknown';
                    End;
                    JSONStr := JSONStr + '      "designator": "' + EscapeJsonString(DesignatorStr) + '",' + #13#10;
                    
                    // Comment (usually the value)
                    Try
                        ValueStr := Component.Comment.Text;
                    Except
                        ValueStr := '';
                    End;
                    JSONStr := JSONStr + '      "value": "' + EscapeJsonString(ValueStr) + '",' + #13#10;
                    
                    // Library reference (component name in library)
                    Try
                        LibRefStr := Component.LibReference;
                    Except
                        LibRefStr := '';
                    End;
                    JSONStr := JSONStr + '      "library_ref": "' + EscapeJsonString(LibRefStr) + '",' + #13#10;
                    
                    // Source library
                    Try
                        TempStr := Component.SourceLibraryName;
                    Except
                        TempStr := '';
                    End;
                    JSONStr := JSONStr + '      "source_library": "' + EscapeJsonString(TempStr) + '",' + #13#10;
                    
                    // Footprint
                    Try
                        FootprintStr := Component.Footprint;
                        If FootprintStr = '' Then
                        Begin
                            // Try to get from parameters
                            For I := 0 To Component.ParameterCount - 1 Do
                            Begin
                                Parameter := Component.SchParameters(I);
                                If (Parameter <> Nil) And (LowerCase(Parameter.Name) = 'footprint') Then
                                Begin
                                    FootprintStr := Parameter.Text;
                                    Break;
                                End;
                            End;
                        End;
                    Except
                        FootprintStr := '';
                    End;
                    JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(FootprintStr) + '",' + #13#10;
                    
                    // Location
                    Try
                        JSONStr := JSONStr + '      "location": {' + #13#10;
                        JSONStr := JSONStr + '        "x": ' + FormatFloat('0.00', CoordToMM(Component.Location.X)) + ',' + #13#10;
                        JSONStr := JSONStr + '        "y": ' + FormatFloat('0.00', CoordToMM(Component.Location.Y)) + #13#10;
                        JSONStr := JSONStr + '      },' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "location": {"x": 0, "y": 0},' + #13#10;
                    End;
                    
                    // Orientation/Rotation
                    Try
                        JSONStr := JSONStr + '      "orientation": ' + IntToStr(Component.Orientation) + ',' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "orientation": 0,' + #13#10;
                    End;
                    
                    // Mirrored
                    Try
                        If Component.IsMirrored Then
                            JSONStr := JSONStr + '      "mirrored": true,' + #13#10
                        Else
                            JSONStr := JSONStr + '      "mirrored": false,' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "mirrored": false,' + #13#10;
                    End;
                    
                    // Pins
                    JSONStr := JSONStr + '      "pins": [';
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
                                        JSONStr := JSONStr + ',';
                                    PinFirst := False;
                                    
                                    JSONStr := JSONStr + #13#10 + '        {' + #13#10;
                                    Try
                                        JSONStr := JSONStr + '          "name": "' + EscapeJsonString(Pin.Name) + '",' + #13#10;
                                        JSONStr := JSONStr + '          "designator": "' + EscapeJsonString(Pin.Designator) + '",' + #13#10;
                                        If Pin.Net <> Nil Then
                                            JSONStr := JSONStr + '          "net": "' + EscapeJsonString(Pin.Net.Name) + '"' + #13#10
                                        Else
                                            JSONStr := JSONStr + '          "net": ""' + #13#10;
                                    Except
                                        JSONStr := JSONStr + '          "name": "",' + #13#10;
                                        JSONStr := JSONStr + '          "designator": "",' + #13#10;
                                        JSONStr := JSONStr + '          "net": ""' + #13#10;
                                    End;
                                    JSONStr := JSONStr + '        }';
                                    
                                    Pin := PinIterator.NextSchObject;
                                End;
                            Finally
                                Component.SchIterator_Destroy(PinIterator);
                            End;
                        End;
                    Except
                    End;
                    JSONStr := JSONStr + #13#10 + '      ],' + #13#10;
                    
                    // Parameters
                    JSONStr := JSONStr + '      "parameters": [';
                    PinFirst := True;
                    Try
                        For I := 0 To Component.ParameterCount - 1 Do
                        Begin
                            Parameter := Component.SchParameters(I);
                            If Parameter <> Nil Then
                            Begin
                                If Not PinFirst Then
                                    JSONStr := JSONStr + ',';
                                PinFirst := False;
                                
                                JSONStr := JSONStr + #13#10 + '        {' + #13#10;
                                Try
                                    JSONStr := JSONStr + '          "name": "' + EscapeJsonString(Parameter.Name) + '",' + #13#10;
                                    JSONStr := JSONStr + '          "value": "' + EscapeJsonString(Parameter.Text) + '"' + #13#10;
                                Except
                                    JSONStr := JSONStr + '          "name": "",' + #13#10;
                                    JSONStr := JSONStr + '          "value": ""' + #13#10;
                                End;
                                JSONStr := JSONStr + '        }';
                            End;
                        End;
                    Except
                    End;
                    JSONStr := JSONStr + #13#10 + '      ]' + #13#10;
                    
                    JSONStr := JSONStr + '    }';
                    
                    Component := Iterator.NextSchObject;
                End;
            Finally
                CurrentSheet.SchIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== WIRES ==========
    JSONStr := JSONStr + '  "wires": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eWire));
                
                Wire := Iterator.FirstSchObject;
                While Wire <> Nil Do
                Begin
                    Inc(WireCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    // Vertices (wire can have multiple segments)
                    JSONStr := JSONStr + '      "vertices": [' + #13#10;
                    Try
                        For I := 1 To Wire.VerticesCount Do
                        Begin
                            If I > 1 Then
                                JSONStr := JSONStr + ',' + #13#10;
                            JSONStr := JSONStr + '        {"x": ' + FormatFloat('0.00', CoordToMM(Wire.Vertex(I).X)) + 
                                       ', "y": ' + FormatFloat('0.00', CoordToMM(Wire.Vertex(I).Y)) + '}';
                        End;
                    Except
                    End;
                    JSONStr := JSONStr + #13#10 + '      ],' + #13#10;
                    
                    // Net name
                    Try
                        If Wire.Net <> Nil Then
                            JSONStr := JSONStr + '      "net": "' + EscapeJsonString(Wire.Net.Name) + '"' + #13#10
                        Else
                            JSONStr := JSONStr + '      "net": ""' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "net": ""' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    Wire := Iterator.NextSchObject;
                End;
            Finally
                CurrentSheet.SchIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== NET LABELS ==========
    JSONStr := JSONStr + '  "net_labels": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eNetLabel));
                
                NetLabel := Iterator.FirstSchObject;
                While NetLabel <> Nil Do
                Begin
                    Inc(NetLabelCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(NetLabel.Text) + '",' + #13#10;
                        JSONStr := JSONStr + '      "location": {' + #13#10;
                        JSONStr := JSONStr + '        "x": ' + FormatFloat('0.00', CoordToMM(NetLabel.Location.X)) + ',' + #13#10;
                        JSONStr := JSONStr + '        "y": ' + FormatFloat('0.00', CoordToMM(NetLabel.Location.Y)) + #13#10;
                        JSONStr := JSONStr + '      },' + #13#10;
                        JSONStr := JSONStr + '      "orientation": ' + IntToStr(NetLabel.Orientation) + #13#10;
                    Except
                        JSONStr := JSONStr + '      "name": "",' + #13#10;
                        JSONStr := JSONStr + '      "location": {"x": 0, "y": 0},' + #13#10;
                        JSONStr := JSONStr + '      "orientation": 0' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    NetLabel := Iterator.NextSchObject;
                End;
            Finally
                CurrentSheet.SchIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== POWER PORTS ==========
    JSONStr := JSONStr + '  "power_ports": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(ePowerObject));
                
                PowerPort := Iterator.FirstSchObject;
                While PowerPort <> Nil Do
                Begin
                    Inc(PowerCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(PowerPort.Text) + '",' + #13#10;
                        JSONStr := JSONStr + '      "style": "' + EscapeJsonString(PowerPort.Style) + '",' + #13#10;
                        JSONStr := JSONStr + '      "location": {' + #13#10;
                        JSONStr := JSONStr + '        "x": ' + FormatFloat('0.00', CoordToMM(PowerPort.Location.X)) + ',' + #13#10;
                        JSONStr := JSONStr + '        "y": ' + FormatFloat('0.00', CoordToMM(PowerPort.Location.Y)) + #13#10;
                        JSONStr := JSONStr + '      },' + #13#10;
                        If PowerPort.Net <> Nil Then
                            JSONStr := JSONStr + '      "net": "' + EscapeJsonString(PowerPort.Net.Name) + '"' + #13#10
                        Else
                            JSONStr := JSONStr + '      "net": "' + EscapeJsonString(PowerPort.Text) + '"' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "name": "",' + #13#10;
                        JSONStr := JSONStr + '      "style": "",' + #13#10;
                        JSONStr := JSONStr + '      "location": {"x": 0, "y": 0},' + #13#10;
                        JSONStr := JSONStr + '      "net": ""' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    PowerPort := Iterator.NextSchObject;
                End;
            Finally
                CurrentSheet.SchIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // ========== PORTS ==========
    JSONStr := JSONStr + '  "ports": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := CurrentSheet.SchIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(ePort));
                
                Port := Iterator.FirstSchObject;
                While Port <> Nil Do
                Begin
                    Inc(PortCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(Port.Name) + '",' + #13#10;
                        JSONStr := JSONStr + '      "io_type": "' + EscapeJsonString(Port.IOType) + '",' + #13#10;
                        JSONStr := JSONStr + '      "location": {' + #13#10;
                        JSONStr := JSONStr + '        "x": ' + FormatFloat('0.00', CoordToMM(Port.Location.X)) + ',' + #13#10;
                        JSONStr := JSONStr + '        "y": ' + FormatFloat('0.00', CoordToMM(Port.Location.Y)) + #13#10;
                        JSONStr := JSONStr + '      }' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "name": "",' + #13#10;
                        JSONStr := JSONStr + '      "io_type": "",' + #13#10;
                        JSONStr := JSONStr + '      "location": {"x": 0, "y": 0}' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    Port := Iterator.NextSchObject;
                End;
            Finally
                CurrentSheet.SchIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    // Statistics
    JSONStr := JSONStr + '  "statistics": {' + #13#10;
    JSONStr := JSONStr + '    "component_count": ' + IntToStr(CompCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "wire_count": ' + IntToStr(WireCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "net_label_count": ' + IntToStr(NetLabelCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "power_port_count": ' + IntToStr(PowerCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "port_count": ' + IntToStr(PortCount) + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    JSONStr := JSONStr + '  "status": "active"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\schematic_info.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('SUCCESS! Schematic information exported to:' + #13#10 + FileName + #13#10 + #13#10 +
                        'Components: ' + IntToStr(CompCount) + #13#10 +
                        'Wires: ' + IntToStr(WireCount) + #13#10 +
                        'Net Labels: ' + IntToStr(NetLabelCount) + #13#10 +
                        'Power Ports: ' + IntToStr(PowerCount) + #13#10 +
                        'Ports: ' + IntToStr(PortCount));
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;

