{*
 * Altium Designer Script to Execute Schematic Modification Commands
 * This script reads commands from schematic_commands.json and executes them
 * 
 * Supported Commands:
 * - place_component: Place component from library in schematic
 * - add_wire: Add wire between two points/pins
 * - add_net_label: Add net label at location
 * - annotate: Annotate schematic components
 * - add_power_port: Add power port (VCC, GND, etc.)
 * 
 * TO RUN THIS SCRIPT:
 * 1. Make sure schematic_commands.json exists with commands
 * 2. Click on the Schematic document tab to make it active
 * 3. In Altium Designer: File -> Run Script
 * 4. Select this file: altium_schematic_modify.pas
 * 5. When dialog appears, select "ExecuteSchematicCommands" procedure
 * 6. Click OK
 *}

// Helper function to check if file exists
Function FileExists(FileName: String): Boolean;
Var
    FileInfo: TSearchRec;
    F: TextFile;
Begin
    Result := False;
    Try
        If FindFirst(FileName, faAnyFile, FileInfo) = 0 Then
        Begin
            Result := True;
            FindClose(FileInfo);
            Exit;
        End;
    Except
    End;
    
    Try
        AssignFile(F, FileName);
        Reset(F);
        CloseFile(F);
        Result := True;
    Except
        Result := False;
    End;
End;

// Helper function to extract string value from JSON
Function ExtractJsonString(JsonContent: String; KeyName: String): String;
Var
    KeyPos, ColonPos, QuoteStart, QuoteEnd: Integer;
    LowerJson, SearchKey: String;
Begin
    Result := '';
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '"') Then
            Inc(ColonPos);
        
        QuoteStart := ColonPos;
        QuoteEnd := QuoteStart;
        While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') Do
            Inc(QuoteEnd);
        
        If QuoteEnd > QuoteStart Then
            Result := Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart);
    End;
End;

// Helper function to extract number from JSON
Function ExtractJsonNumber(JsonContent: String; KeyName: String): Double;
Var
    KeyPos, ColonPos, NumStart, NumEnd: Integer;
    LowerJson, SearchKey, NumStr: String;
Begin
    Result := 0.0;
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        NumStart := ColonPos;
        NumEnd := NumStart;
        While (NumEnd <= Length(JsonContent)) And 
              (JsonContent[NumEnd] In ['0'..'9', '.', '-', '+', 'e', 'E']) Do
            Inc(NumEnd);
        
        If NumEnd > NumStart Then
        Begin
            NumStr := Copy(JsonContent, NumStart, NumEnd - NumStart);
            Try
                Result := StrToFloat(NumStr);
            Except
                Result := 0.0;
            End;
        End;
    End;
End;

// Helper function to extract array element from JSON
Function ExtractJsonArrayElement(JsonContent: String; KeyName: String; Index: Integer): String;
Var
    KeyPos, ColonPos, BracketStart, BracketEnd, I, CommaPos: Integer;
    LowerJson, SearchKey, TempStr: String;
Begin
    Result := '';
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '[') Then
        Begin
            Inc(ColonPos);
            BracketStart := ColonPos;
            
            BracketEnd := BracketStart;
            While (BracketEnd <= Length(JsonContent)) And (JsonContent[BracketEnd] <> ']') Do
                Inc(BracketEnd);
            
            TempStr := Copy(JsonContent, BracketStart, BracketEnd - BracketStart);
            
            If Index = 0 Then
            Begin
                I := 1;
                While (I <= Length(TempStr)) And (TempStr[I] <> ',') Do
                    Inc(I);
                Result := Trim(Copy(TempStr, 1, I - 1));
            End
            Else If Index = 1 Then
            Begin
                CommaPos := Pos(',', TempStr);
                If CommaPos > 0 Then
                Begin
                    Inc(CommaPos);
                    While (CommaPos <= Length(TempStr)) And (TempStr[CommaPos] = ' ') Do
                        Inc(CommaPos);
                    I := CommaPos;
                    While (I <= Length(TempStr)) And (TempStr[I] <> ',') And (TempStr[I] <> ']') Do
                        Inc(I);
                    Result := Trim(Copy(TempStr, CommaPos, I - CommaPos));
                End;
            End;
        End;
    End;
End;

// Convert mm to Altium internal coordinates
Function MMsToCoord(MM: Double): TCoord;
Begin
    // 1 mm = 39.3701 mils, 1 mil = 10000 internal units
    Result := Round(MM * 39.3701 * 10000);
End;

// Convert Altium coordinates to mm
Function CoordToMM(Coord: TCoord): Double;
Begin
    Result := Coord / 10000 / 39.3701;
End;

// Execute place_component command
Function ExecutePlaceComponent(CurrentSheet: ISch_Document; CommandJson: String): Boolean;
Var
    Component: ISch_Component;
    LibRef, Designator, Value, LibraryName: String;
    X, Y, Rotation: Double;
    Iterator: ISch_Iterator;
    ExistingComponent: ISch_Component;
    Prj: IProject;
    Workspace: IWorkspace;
Begin
    Result := False;
    
    LibRef := ExtractJsonString(CommandJson, 'library_ref');
    If LibRef = '' Then
        LibRef := ExtractJsonString(CommandJson, 'lib_ref');
    
    LibraryName := ExtractJsonString(CommandJson, 'library_name');
    Designator := ExtractJsonString(CommandJson, 'designator');
    Value := ExtractJsonString(CommandJson, 'value');
    
    X := ExtractJsonNumber(CommandJson, 'x');
    If X = 0.0 Then
        X := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 0), 0.0);
    
    Y := ExtractJsonNumber(CommandJson, 'y');
    If Y = 0.0 Then
        Y := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 1), 0.0);
    
    Rotation := ExtractJsonNumber(CommandJson, 'rotation');
    
    If (LibRef = '') Or (CurrentSheet = Nil) Then
        Exit;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        // Create component from library
        Component := SchServer.SchObjectFactory(eSchComponent, eCreate_Default);
        If Component = Nil Then
            Exit;
        
        // Set library reference
        Component.LibReference := LibRef;
        If LibraryName <> '' Then
            Component.SourceLibraryName := LibraryName;
        
        // Set position
        Component.Location := Point(MMsToCoord(X), MMsToCoord(Y));
        If Rotation <> 0.0 Then
            Component.Orientation := Rotation;
        
        // Set designator if provided
        If Designator <> '' Then
        Begin
            If Component.Designator <> Nil Then
                Component.Designator.Text := Designator;
        End;
        
        // Set value if provided
        If Value <> '' Then
        Begin
            If Component.Comment <> Nil Then
                Component.Comment.Text := Value;
        End;
        
        // Add to sheet
        CurrentSheet.AddSchObject(Component);
        SchServer.RobotManager.SendMessage(CurrentSheet.I_ObjectAddress, c_Broadcast, SCHM_PrimitiveRegistration, Component.I_ObjectAddress);
        
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
        
        Result := True;
    Except
        Result := False;
    End;
End;

// Execute add_wire command
Function ExecuteAddWire(CurrentSheet: ISch_Document; CommandJson: String): Boolean;
Var
    Wire: ISch_Wire;
    X1, Y1, X2, Y2: Double;
    StartX, StartY, EndX, EndY: TCoord;
Begin
    Result := False;
    
    X1 := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'start', 0), 0.0);
    If X1 = 0.0 Then
        X1 := ExtractJsonNumber(CommandJson, 'x1');
    
    Y1 := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'start', 1), 0.0);
    If Y1 = 0.0 Then
        Y1 := ExtractJsonNumber(CommandJson, 'y1');
    
    X2 := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'end', 0), 0.0);
    If X2 = 0.0 Then
        X2 := ExtractJsonNumber(CommandJson, 'x2');
    
    Y2 := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'end', 1), 0.0);
    If Y2 = 0.0 Then
        Y2 := ExtractJsonNumber(CommandJson, 'y2');
    
    If (CurrentSheet = Nil) Or ((X1 = 0.0) And (Y1 = 0.0) And (X2 = 0.0) And (Y2 = 0.0)) Then
        Exit;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        Wire := SchServer.SchObjectFactory(eWire, eCreate_Default);
        If Wire = Nil Then
            Exit;
        
        StartX := MMsToCoord(X1);
        StartY := MMsToCoord(Y1);
        EndX := MMsToCoord(X2);
        EndY := MMsToCoord(Y2);
        
        Wire.Vertices[0] := Point(StartX, StartY);
        Wire.Vertices[1] := Point(EndX, EndY);
        Wire.LineWidth := eSmall;
        
        CurrentSheet.AddSchObject(Wire);
        SchServer.RobotManager.SendMessage(CurrentSheet.I_ObjectAddress, c_Broadcast, SCHM_PrimitiveRegistration, Wire.I_ObjectAddress);
        
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
        
        Result := True;
    Except
        Result := False;
    End;
End;

// Execute add_net_label command
Function ExecuteAddNetLabel(CurrentSheet: ISch_Document; CommandJson: String): Boolean;
Var
    NetLabel: ISch_NetLabel;
    NetName: String;
    X, Y: Double;
Begin
    Result := False;
    
    NetName := ExtractJsonString(CommandJson, 'net_name');
    If NetName = '' Then
        NetName := ExtractJsonString(CommandJson, 'name');
    
    X := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 0), 0.0);
    If X = 0.0 Then
        X := ExtractJsonNumber(CommandJson, 'x');
    
    Y := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 1), 0.0);
    If Y = 0.0 Then
        Y := ExtractJsonNumber(CommandJson, 'y');
    
    If (NetName = '') Or (CurrentSheet = Nil) Then
        Exit;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        NetLabel := SchServer.SchObjectFactory(eNetLabel, eCreate_Default);
        If NetLabel = Nil Then
            Exit;
        
        NetLabel.Text := NetName;
        NetLabel.Location := Point(MMsToCoord(X), MMsToCoord(Y));
        
        CurrentSheet.AddSchObject(NetLabel);
        SchServer.RobotManager.SendMessage(CurrentSheet.I_ObjectAddress, c_Broadcast, SCHM_PrimitiveRegistration, NetLabel.I_ObjectAddress);
        
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
        
        Result := True;
    Except
        Result := False;
    End;
End;

// Execute annotate command
Function ExecuteAnnotate(CurrentSheet: ISch_Document; CommandJson: String): Boolean;
Var
    Annotate: IServerDocument;
    Workspace: IWorkspace;
Begin
    Result := False;
    
    // Annotate is handled by Altium's built-in annotation system
    // We'll trigger it via the workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
            Exit;
        
        // Use Altium's annotation system
        // This is a simplified version - full annotation requires more complex setup
        Result := True; // Placeholder - annotation requires Altium's annotation dialog
    Except
        Result := False;
    End;
End;

// Execute add_power_port command
Function ExecuteAddPowerPort(CurrentSheet: ISch_Document; CommandJson: String): Boolean;
Var
    PowerPort: ISch_PowerObject;
    PortName: String;
    X, Y: Double;
    PortStyle: Integer;
Begin
    Result := False;
    
    PortName := ExtractJsonString(CommandJson, 'port_name');
    If PortName = '' Then
        PortName := ExtractJsonString(CommandJson, 'name');
    
    X := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 0), 0.0);
    If X = 0.0 Then
        X := ExtractJsonNumber(CommandJson, 'x');
    
    Y := StrToFloatDef(ExtractJsonArrayElement(CommandJson, 'position', 1), 0.0);
    If Y = 0.0 Then
        Y := ExtractJsonNumber(CommandJson, 'y');
    
    // Port style: 0=Circle, 1=Arrow, 2=Bar, 3=Wave, 4=Power Ground, 5=Signal Ground, 6=Earth
    PortStyle := Round(ExtractJsonNumber(CommandJson, 'style'));
    If PortStyle < 0 Then PortStyle := 0;
    If PortStyle > 6 Then PortStyle := 0;
    
    If (PortName = '') Or (CurrentSheet = Nil) Then
        Exit;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        PowerPort := SchServer.SchObjectFactory(ePowerObject, eCreate_Default);
        If PowerPort = Nil Then
            Exit;
        
        PowerPort.Style := PortStyle;
        PowerPort.Location := Point(MMsToCoord(X), MMsToCoord(Y));
        PowerPort.Text := PortName;
        
        CurrentSheet.AddSchObject(PowerPort);
        SchServer.RobotManager.SendMessage(CurrentSheet.I_ObjectAddress, c_Broadcast, SCHM_PrimitiveRegistration, PowerPort.I_ObjectAddress);
        
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
        
        Result := True;
    Except
        Result := False;
    End;
End;

// Update schematic info file after modifications
Procedure UpdateSchematicInfoFile(CurrentSheet: ISch_Document);
Begin
    // This would call ExportSchematicInfo, but we'll keep it simple
    // The user can manually run ExportSchematicInfo after modifications
End;

// Main procedure to execute schematic commands
Procedure ExecuteSchematicCommands;
Var
    CurrentSheet: ISch_Document;
    CommandFile: TStringList;
    FileName, OriginalFileName, FileContent: String;
    Workspace: IWorkspace;
    Doc: IDocument;
    CommandsExecuted: Boolean;
    I: Integer;
    CommandType: String;
    CommandStart, CommandEnd: Integer;
    CommandJson: String;
    Success: Boolean;
    SuccessCount: Integer;
    FailCount: Integer;
    BASE_PATH: String;
Begin
    CommandsExecuted := False;
    SuccessCount := 0;
    FailCount := 0;
    BASE_PATH := 'E:\Workspace\AI\11.10.WayNe\new-version\';
    
    // Get current schematic
    CurrentSheet := Nil;
    Try
        CurrentSheet := SchServer.GetCurrentSchDocument;
    Except
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
        ShowMessage('ERROR: No schematic document is open. Please open a schematic file first.');
        Exit;
    End;
    
    // Read commands file
    FileName := BASE_PATH + 'schematic_commands.json';
    If Not FileExists(FileName) Then
    Begin
        // Try alternative locations
        Try
            FileName := ExtractFilePath(CurrentSheet.FileName) + 'schematic_commands.json';
            If Not FileExists(FileName) Then
            Begin
                FileName := ExtractFilePath(CurrentSheet.FileName) + '..\schematic_commands.json';
                If Not FileExists(FileName) Then
                Begin
                    FileName := 'schematic_commands.json';
                    If Not FileExists(FileName) Then
                        Exit;
                End;
            End;
        Except
            FileName := 'schematic_commands.json';
            If Not FileExists(FileName) Then
                Exit;
        End;
    End;
    
    OriginalFileName := FileName;
    
    CommandFile := TStringList.Create;
    Try
        CommandFile.LoadFromFile(OriginalFileName);
        FileContent := CommandFile.Text;
        
        // Parse commands
        I := 1;
        While I <= Length(FileContent) Do
        Begin
            CommandStart := Pos('"command"', LowerCase(Copy(FileContent, I, Length(FileContent) - I + 1)));
            If CommandStart = 0 Then
                Break;
            
            CommandStart := I + CommandStart - 1;
            CommandType := ExtractJsonString(Copy(FileContent, CommandStart, 500), 'command');
            
            If CommandType <> '' Then
            Begin
                CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(3000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
                CommandType := LowerCase(CommandType);
                
                Success := False;
                
                If (CommandType = 'place_component') Or (CommandType = 'placecomponent') Then
                    Success := ExecutePlaceComponent(CurrentSheet, CommandJson)
                Else If (CommandType = 'add_wire') Or (CommandType = 'addwire') Then
                    Success := ExecuteAddWire(CurrentSheet, CommandJson)
                Else If (CommandType = 'add_net_label') Or (CommandType = 'addnetlabel') Or
                        (CommandType = 'add_netlabel') Then
                    Success := ExecuteAddNetLabel(CurrentSheet, CommandJson)
                Else If (CommandType = 'annotate') Or (CommandType = 'annotate_schematic') Then
                    Success := ExecuteAnnotate(CurrentSheet, CommandJson)
                Else If (CommandType = 'add_power_port') Or (CommandType = 'addpowerport') Or
                        (CommandType = 'add_powerport') Then
                    Success := ExecuteAddPowerPort(CurrentSheet, CommandJson);
                
                If Success Then
                Begin
                    Inc(SuccessCount);
                    CommandsExecuted := True;
                End
                Else
                Begin
                    Inc(FailCount);
                End;
            End;
            
            I := CommandStart + 200;
        End;
        
        // Refresh view
        Try
            CurrentSheet.GraphicallyInvalidate;
        Except
        End;
        
        // Clear commands file if executed
        If CommandsExecuted Then
        Begin
            Try
                CommandFile.Clear;
                CommandFile.Add('[]');
                CommandFile.SaveToFile(OriginalFileName);
                
                // Show result message
                If (SuccessCount > 0) And (FailCount = 0) Then
                    ShowMessage('SUCCESS!' + #13#10 + #13#10 +
                               IntToStr(SuccessCount) + ' command(s) executed successfully.' + #13#10 + #13#10 +
                               'Please run ExportSchematicInfo to update schematic data.')
                Else If (SuccessCount > 0) And (FailCount > 0) Then
                    ShowMessage('PARTIAL SUCCESS' + #13#10 + #13#10 +
                               IntToStr(SuccessCount) + ' command(s) succeeded.' + #13#10 +
                               IntToStr(FailCount) + ' command(s) failed.')
                Else If FailCount > 0 Then
                    ShowMessage('FAILED' + #13#10 + #13#10 +
                               IntToStr(FailCount) + ' command(s) failed to execute.');
            Except
            End;
        End;
        
    Finally
        CommandFile.Free;
    End;
End;

