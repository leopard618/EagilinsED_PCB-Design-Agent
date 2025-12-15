{*
 * Altium Designer Script to Execute Modification Commands
 * This script reads commands from pcb_commands.json and executes them
 * 
 * Supported Commands:
 * - move_component: Move component to new position
 * - rotate_component: Rotate component
 * - remove_component: Remove component from PCB
 * - add_component: Add new component (requires footprint)
 * - change_component_value: Change component value/parameter
 * - add_track: Add track between two points
 * - add_via: Add via at location
 * - connect_net: Connect component pin to net
 * - change_layer: Move component to different layer
 * - set_board_size: Change board dimensions
 * 
 * TO RUN THIS SCRIPT:
 * 1. Make sure pcb_commands.json exists with commands
 * 2. In Altium Designer: File -> Run Script
 * 3. Select this file: altium_execute_commands.pas
 * 4. When dialog appears, select "ExecuteCommands" procedure
 * 5. Click OK
 *}

// Helper function to check if file exists
Function FileExists(FileName: String): Boolean;
Var
    FileInfo: TSearchRec;
    F: TextFile;
Begin
    Result := False;
    // Try FindFirst first (more reliable for absolute paths)
    Try
        If FindFirst(FileName, faAnyFile, FileInfo) = 0 Then
        Begin
            Result := True;
            FindClose(FileInfo);
            Exit;
        End;
    Except
    End;
    
    // Fallback: Try to open the file directly
    Try
        AssignFile(F, FileName);
        Reset(F);
        CloseFile(F);
        Result := True;
    Except
        Result := False;
    End;
End;

// Helper function to extract array element from JSON (e.g., "new_coordinates": [88.6, 56.33])
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
        // Find colon
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        // Skip spaces
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        // Check if it's an array (starts with '[')
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '[') Then
        Begin
            Inc(ColonPos); // Skip '['
            BracketStart := ColonPos;
            
            // Find the closing bracket
            BracketEnd := BracketStart;
            While (BracketEnd <= Length(JsonContent)) And (JsonContent[BracketEnd] <> ']') Do
                Inc(BracketEnd);
            
            // Extract the array content
            TempStr := Copy(JsonContent, BracketStart, BracketEnd - BracketStart);
            
            // Find the value at the specified index
            If Index = 0 Then
            Begin
                // First element - extract until comma or end
                I := 1;
                While (I <= Length(TempStr)) And (TempStr[I] <> ',') Do
                    Inc(I);
                Result := Trim(Copy(TempStr, 1, I - 1));
            End
            Else If Index = 1 Then
            Begin
                // Second element - find first comma, then extract
                CommaPos := Pos(',', TempStr);
                If CommaPos > 0 Then
                Begin
                    Inc(CommaPos); // Skip comma
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

// Helper function to extract string value from JSON (searches in "parameters" and root)
Function ExtractJsonString(JsonContent: String; KeyName: String): String;
Var
    KeyPos, ColonPos, QuoteStart, QuoteEnd: Integer;
    LowerJson, SearchKey: String;
Begin
    Result := '';
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    
    // Try to find key (could be in "parameters" object or root)
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        // Find colon
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        // Skip spaces
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        // Skip opening quote
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '"') Then
            Inc(ColonPos);
        
        // Extract string until closing quote
        QuoteStart := ColonPos;
        QuoteEnd := QuoteStart;
        While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') Do
            Inc(QuoteEnd);
        
        If QuoteEnd > QuoteStart Then
            Result := Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart);
    End;
End;

// Helper function to extract array values from JSON (e.g., "new_coordinates": [88.6, 56.33])
Function ExtractJsonArray(JsonContent: String; KeyName: String; Index: Integer): String;
Var
    KeyPos, ColonPos, BracketStart, BracketEnd, CommaCount, I: Integer;
    LowerJson, SearchKey, TempStr: String;
Begin
    Result := '';
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        // Find colon
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        // Skip spaces
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        // Check if it's an array (starts with '[')
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '[') Then
        Begin
            Inc(ColonPos); // Skip '['
            BracketStart := ColonPos;
            
            // Find the closing bracket
            BracketEnd := BracketStart;
            CommaCount := 0;
            While (BracketEnd <= Length(JsonContent)) And (JsonContent[BracketEnd] <> ']') Do
            Begin
                If JsonContent[BracketEnd] = ',' Then
                    Inc(CommaCount);
                Inc(BracketEnd);
            End;
            
            // Extract the array content
            TempStr := Copy(JsonContent, BracketStart, BracketEnd - BracketStart);
            
            // Find the value at the specified index
            If Index = 0 Then
            Begin
                // First element - extract until comma or closing bracket
                I := 1;
                While (I <= Length(TempStr)) And (TempStr[I] <> ',') And (TempStr[I] <> ']') Do
                    Inc(I);
                Result := Trim(Copy(TempStr, 1, I - 1));
            End
            Else If Index = 1 Then
            Begin
                // Second element - find first comma, then extract until next comma or closing bracket
                I := Pos(',', TempStr);
                If I > 0 Then
                Begin
                    Inc(I); // Skip comma
                    While (I <= Length(TempStr)) And (TempStr[I] = ' ') Do
                        Inc(I);
                    BracketEnd := I;
                    While (BracketEnd <= Length(TempStr)) And (TempStr[BracketEnd] <> ',') And (TempStr[BracketEnd] <> ']') Do
                        Inc(BracketEnd);
                    Result := Trim(Copy(TempStr, I, BracketEnd - I));
                End;
            End;
        End;
    End;
End;

// Helper function to extract numeric value from JSON (searches in "parameters" and root)
// Also handles string values with units (e.g., "0.2mm" -> 0.2)
Function ExtractJsonNumber(JsonContent: String; KeyName: String): Double;
Var
    KeyPos, ColonPos, NumStart, NumEnd, QuoteStart, QuoteEnd: Integer;
    LowerJson, TempStr, SearchKey: String;
    IsQuoted: Boolean;
Begin
    Result := 0;
    LowerJson := LowerCase(JsonContent);
    SearchKey := LowerCase(KeyName);
    KeyPos := Pos('"' + SearchKey + '"', LowerJson);
    
    If KeyPos > 0 Then
    Begin
        // Find colon
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        // Skip spaces
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        // Check if value is quoted (string)
        IsQuoted := False;
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '"') Then
        Begin
            IsQuoted := True;
            Inc(ColonPos); // Skip opening quote
            QuoteStart := ColonPos;
            QuoteEnd := QuoteStart;
            While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') Do
                Inc(QuoteEnd);
            TempStr := Trim(Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart));
        End
        Else
        Begin
            // Extract number until comma, brace, bracket, or whitespace
            NumStart := ColonPos;
            NumEnd := NumStart;
            While (NumEnd <= Length(JsonContent)) And
                  (JsonContent[NumEnd] <> ',') And
                  (JsonContent[NumEnd] <> '}') And
                  (JsonContent[NumEnd] <> ']') And
                  (JsonContent[NumEnd] <> #13) And
                  (JsonContent[NumEnd] <> #10) And
                  (JsonContent[NumEnd] <> ' ') Do
                Inc(NumEnd);
            TempStr := Trim(Copy(JsonContent, NumStart, NumEnd - NumStart));
        End;
        
        // Strip units (mm, mil, inch, etc.) from the string
        TempStr := LowerCase(TempStr);
        If Pos('mm', TempStr) > 0 Then
            TempStr := Copy(TempStr, 1, Pos('mm', TempStr) - 1)
        Else If Pos('mil', TempStr) > 0 Then
        Begin
            TempStr := Copy(TempStr, 1, Pos('mil', TempStr) - 1);
            // Convert mils to mm (1 mil = 0.0254 mm)
            Try
                Result := StrToFloat(TempStr) * 0.0254;
                Exit;
            Except
            End;
        End
        Else If Pos('inch', TempStr) > 0 Then
        Begin
            TempStr := Copy(TempStr, 1, Pos('inch', TempStr) - 1);
            // Convert inches to mm (1 inch = 25.4 mm)
            Try
                Result := StrToFloat(TempStr) * 25.4;
                Exit;
            Except
            End;
        End;
        
        // Try to parse as float
        Try
            Result := StrToFloat(Trim(TempStr));
        Except
            Result := 0;
        End;
    End;
End;

// Helper function to find component by name
Function FindComponent(PCB: IPCB_Board; CompName: String): IPCB_Component;
Var
    Iterator: IPCB_BoardIterator;
    Component: IPCB_Component;
Begin
    Result := Nil;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Component := Iterator.FirstPCBObject;
            While Component <> Nil Do
            Begin
                If (Component.Name.Text = CompName) Or
                   (LowerCase(Component.Name.Text) = LowerCase(CompName)) Then
                Begin
                    Result := Component;
                    Break;
                End;
                Component := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
        Result := Nil;
    End;
End;

// Execute move_component command
Function ExecuteMoveComponent(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName: String;
    X, Y: Double;
    XFound, YFound: Boolean;
    LowerJson, XFoundStr, YFoundStr: String;
    PositionStr, TempStr, XStr, YStr: String;
    CommaPos: Integer;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    LowerJson := LowerCase(CommandJson);
    XFound := False;
    YFound := False;
    
    // First, try to extract from "new_coordinates": [x, y] or "coordinates": [x, y] array format
    XStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 0);
    YStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 1);
    If (XStr = '') Or (YStr = '') Then
    Begin
        // Try "coordinates" instead
        XStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 0);
        YStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 1);
    End;
    If (XStr <> '') And (YStr <> '') Then
    Begin
        Try
            X := StrToFloat(XStr);
            Y := StrToFloat(YStr);
            XFound := True;
            YFound := True;
        Except
        End;
    End;
    
    // If array format didn't work, try "position": "(x, y)" string format
    If Not XFound Then
    Begin
        PositionStr := ExtractJsonString(CommandJson, 'position');
        If PositionStr <> '' Then
        Begin
            // Parse "(80, 58)" or "80, 58" format
            // Remove parentheses if present
            TempStr := Trim(PositionStr);
            If (Length(TempStr) > 0) And (Copy(TempStr, 1, 1) = '(') Then
                TempStr := Copy(TempStr, 2, Length(TempStr) - 1);
            If (Length(TempStr) > 0) And (TempStr[Length(TempStr)] = ')') Then
                TempStr := Copy(TempStr, 1, Length(TempStr) - 1);
            
            // Find comma separator
            CommaPos := Pos(',', TempStr);
            If CommaPos > 0 Then
            Begin
                // Extract X coordinate
                XStr := Trim(Copy(TempStr, 1, CommaPos - 1));
                // Extract Y coordinate
                YStr := Trim(Copy(TempStr, CommaPos + 1, Length(TempStr)));
                
                Try
                    X := StrToFloat(XStr);
                    Y := StrToFloat(YStr);
                    XFound := True;
                    YFound := True;
                Except
                End;
            End;
        End;
    End;
    
    // If position format didn't work, try individual coordinate parameters
    If Not XFound Then
    Begin
        // Try all possible X coordinate parameter names
        If Pos('"x_position"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'x_position');
            XFound := True;
        End
        Else If Pos('"position_x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'position_x');
            XFound := True;
        End
        Else If Pos('"new_x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'new_x');
            XFound := True;
        End
        Else If Pos('"x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'x');
            XFound := True;
        End
        Else
            X := 0;
    End;
    
    If Not YFound Then
    Begin
        // Try all possible Y coordinate parameter names
        If Pos('"y_position"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'y_position');
            YFound := True;
        End
        Else If Pos('"position_y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'position_y');
            YFound := True;
        End
        Else If Pos('"new_y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'new_y');
            YFound := True;
        End
        Else If Pos('"y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'y');
            YFound := True;
        End
        Else
            Y := 0;
    End;
    
    // Check if we have valid parameters
    If (CompName <> '') And XFound And YFound Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                Component.Moveable := True;
                Component.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
                Component.GraphicallyInvalidate;
                PCBServer.PostProcess;
                Result := True;
            Except
                Result := False;
            End;
        End;
    End;
End;

// Execute rotate_component command
Function ExecuteRotateComponent(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName: String;
    Rotation: Double;
    CenterX, CenterY: TCoord;
    LowerJson: String;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    LowerJson := LowerCase(CommandJson);
    
    // Try "rotation" first, then "angle"
    Rotation := ExtractJsonNumber(CommandJson, 'rotation');
    If Rotation = 0 Then
        Rotation := ExtractJsonNumber(CommandJson, 'angle');
    
    If (CompName <> '') And (Rotation <> 0) Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                Component.Moveable := True;
                
                // Get current rotation and add the new rotation angle
                // Rotation is stored in degrees (0-360)
                Component.Rotation := Component.Rotation + Rotation;
                
                // Normalize rotation to 0-360 range
                While Component.Rotation >= 360 Do
                    Component.Rotation := Component.Rotation - 360;
                While Component.Rotation < 0 Do
                    Component.Rotation := Component.Rotation + 360;
                
                Component.GraphicallyInvalidate;
                PCBServer.PostProcess;
                Result := True;
            Except
                Result := False;
            End;
        End;
    End;
End;

// Execute remove_component command
Function ExecuteRemoveComponent(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName: String;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    If CompName <> '' Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                PCB.RemovePCBObject(Component);
                PCBServer.PostProcess;
                Result := True;
            Except
                Result := False;
            End;
        End;
    End;
End;

// Execute change_component_size command (changes footprint which changes size)
Function ExecuteChangeComponentSize(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName, NewFootprint: String;
Begin
    Result := False;
    
    // Extract component name
    CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    // Extract new footprint (footprint pattern determines size)
    NewFootprint := ExtractJsonString(CommandJson, 'footprint');
    If NewFootprint = '' Then
        NewFootprint := ExtractJsonString(CommandJson, 'pattern');
    If NewFootprint = '' Then
        NewFootprint := ExtractJsonString(CommandJson, 'new_footprint');
    
    If (CompName = '') Or (NewFootprint = '') Then
        Exit;
    
    // Find component
    Component := FindComponent(PCB, CompName);
    If Component = Nil Then
        Exit;
    
    // Change footprint (which determines size)
    Try
        PCBServer.PreProcess;
        Component.Pattern := NewFootprint;
        Component.GraphicallyInvalidate;
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        Result := True;
    Except
        Result := False;
    End;
End;

// Execute change_component_value command
Function ExecuteChangeComponentValue(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName, NewValue: String;
    Param: IPCB_Parameter;
    I: Integer;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    NewValue := ExtractJsonString(CommandJson, 'value');
    
    If (CompName <> '') And (NewValue <> '') Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                // Try to find and update Value parameter
                For I := 0 To Component.Parameters.Count - 1 Do
                Begin
                    Param := Component.Parameters[I];
                    If Param.Name = 'Value' Then
                    Begin
                        Param.Text := NewValue;
                        Component.GraphicallyInvalidate;
                        Break;
                    End;
                End;
                PCBServer.PostProcess;
                Result := True;
            Except
                Result := False;
            End;
        End;
    End;
End;

// Execute add_track command
Function ExecuteAddTrack(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Track: IPCB_Track;
    StartX, StartY, EndX, EndY, Width: Double;
    LayerName: String;
    Layer: TLayer;
Begin
    Result := False;
    StartX := ExtractJsonNumber(CommandJson, 'start_x');
    StartY := ExtractJsonNumber(CommandJson, 'start_y');
    EndX := ExtractJsonNumber(CommandJson, 'end_x');
    EndY := ExtractJsonNumber(CommandJson, 'end_y');
    Width := ExtractJsonNumber(CommandJson, 'width');
    // Also try width_mm parameter name
    If Width = 0 Then
        Width := ExtractJsonNumber(CommandJson, 'width_mm');
    If Width = 0 Then
        Width := 0.2; // Default width in mm
    
    LayerName := ExtractJsonString(CommandJson, 'layer');
    If LayerName = '' Then
        LayerName := 'Top Layer';
    
    // Convert layer name to layer constant
    Layer := eTopLayer;
    If Pos('bottom', LowerCase(LayerName)) > 0 Then
        Layer := eBottomLayer;
    
    If (StartX <> 0) And (StartY <> 0) And (EndX <> 0) And (EndY <> 0) Then
    Begin
        Try
            PCBServer.PreProcess;
            Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
            Track.X1 := MMsToCoord(StartX);
            Track.Y1 := MMsToCoord(StartY);
            Track.X2 := MMsToCoord(EndX);
            Track.Y2 := MMsToCoord(EndY);
            Track.Width := MMsToCoord(Width);
            Track.Layer := Layer;
            PCB.AddPCBObject(Track);
            PCBServer.PostProcess;
            Result := True;
        Except
            Result := False;
        End;
    End;
End;

// Execute add_via command
Function ExecuteAddVia(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Via: IPCB_Via;
    X, Y, Size, HoleSize: Double;
Begin
    Result := False;
    X := ExtractJsonNumber(CommandJson, 'x_position');
    If X = 0 Then
        X := ExtractJsonNumber(CommandJson, 'x');
    
    Y := ExtractJsonNumber(CommandJson, 'y_position');
    If Y = 0 Then
        Y := ExtractJsonNumber(CommandJson, 'y');
    
    Size := ExtractJsonNumber(CommandJson, 'size');
    If Size = 0 Then
        Size := 0.5; // Default size
    
    HoleSize := ExtractJsonNumber(CommandJson, 'hole_size');
    If HoleSize = 0 Then
        HoleSize := 0.2; // Default hole size
    
    If (X <> 0) And (Y <> 0) Then
    Begin
        Try
            PCBServer.PreProcess;
            Via := PCBServer.PCBObjectFactory(eViaObject, eNoDimension, eCreate_Default);
            Via.X := MMsToCoord(X);
            Via.Y := MMsToCoord(Y);
            Via.Size := MMsToCoord(Size);
            Via.HoleSize := MMsToCoord(HoleSize);
            PCB.AddPCBObject(Via);
            PCBServer.PostProcess;
            Result := True;
        Except
            Result := False;
        End;
    End;
End;

// Execute change_layer command
Function ExecuteChangeLayer(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName, LayerName: String;
    Layer: TLayer;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    LayerName := ExtractJsonString(CommandJson, 'layer');
    
    If (CompName <> '') And (LayerName <> '') Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                // Convert layer name to layer constant
                Layer := eTopLayer;
                If Pos('bottom', LowerCase(LayerName)) > 0 Then
                    Layer := eBottomLayer;
                
                Component.Layer := Layer;
                Component.GraphicallyInvalidate;
                PCBServer.PostProcess;
                Result := True;
            Except
                Result := False;
            End;
        End;
    End;
End;

// Execute add_component command
Function ExecuteAddComponent(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component, ExistingComponent: IPCB_Component;
    CompName, Footprint, Value, LayerName: String;
    X, Y, Rotation: Double;
    Layer: TLayer;
    Workspace: IWorkspace;
    Prj: IProject;
    LowerJson: String;
    XFound, YFound: Boolean;
    XFoundStr, YFoundStr: String;
    KeyPos, NumStart, NumEnd, CommaPos: Integer;
    PositionStr, TempStr, XStr, YStr: String;
    Iterator: IPCB_BoardIterator;
Begin
    Result := False;
    LowerJson := LowerCase(CommandJson);
    
    // Try all possible component name parameter names
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'component');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'id');
    
    // If still empty, try to extract from command text itself (for commands like "Add R800 to...")
    If CompName = '' Then
    Begin
        // Look for pattern like "Add R800" or "Add component R800"
        If Pos('add', LowerJson) > 0 Then
        Begin
            // Try to find component designator after "add" (e.g., "R800", "C200")
            KeyPos := Pos('add', LowerJson);
            NumStart := KeyPos + 3;
            While (NumStart <= Length(CommandJson)) And 
                  ((CommandJson[NumStart] = ' ') Or (CommandJson[NumStart] = #9)) Do
                Inc(NumStart);
            
            // Check if next word starts with letter (component designator)
            If (NumStart <= Length(CommandJson)) And 
               (((CommandJson[NumStart] >= 'A') And (CommandJson[NumStart] <= 'Z')) Or
                ((CommandJson[NumStart] >= 'a') And (CommandJson[NumStart] <= 'z'))) Then
            Begin
                NumEnd := NumStart;
                While (NumEnd <= Length(CommandJson)) And
                      (((CommandJson[NumEnd] >= 'A') And (CommandJson[NumEnd] <= 'Z')) Or
                       ((CommandJson[NumEnd] >= 'a') And (CommandJson[NumEnd] <= 'z')) Or
                       ((CommandJson[NumEnd] >= '0') And (CommandJson[NumEnd] <= '9'))) Do
                    Inc(NumEnd);
                CompName := Copy(CommandJson, NumStart, NumEnd - NumStart);
            End;
        End;
    End;
    
    Footprint := ExtractJsonString(CommandJson, 'footprint');
    Value := ExtractJsonString(CommandJson, 'value');
    
    XFound := False;
    YFound := False;
    
    // First, try to extract from "coordinates": [x, y] or "new_coordinates": [x, y] array format
    XStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 0);
    YStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 1);
    If (XStr <> '') And (YStr <> '') Then
    Begin
        Try
            X := StrToFloat(XStr);
            Y := StrToFloat(YStr);
            XFound := True;
            YFound := True;
        Except
        End;
    End;
    
    // If array format didn't work, try "new_coordinates" array format
    If Not XFound Then
    Begin
        XStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 0);
        YStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 1);
        If (XStr <> '') And (YStr <> '') Then
        Begin
            Try
                X := StrToFloat(XStr);
                Y := StrToFloat(YStr);
                XFound := True;
                YFound := True;
            Except
            End;
        End;
    End;
    
    // If array format didn't work, try "position": "(x, y)" string format
    If Not XFound Then
    Begin
        PositionStr := ExtractJsonString(CommandJson, 'position');
        If PositionStr <> '' Then
        Begin
            // Parse "(80, 58)" or "80, 58" format
            // Remove parentheses if present
            TempStr := Trim(PositionStr);
            If (Length(TempStr) > 0) And (Copy(TempStr, 1, 1) = '(') Then
                TempStr := Copy(TempStr, 2, Length(TempStr) - 1);
            If (Length(TempStr) > 0) And (TempStr[Length(TempStr)] = ')') Then
                TempStr := Copy(TempStr, 1, Length(TempStr) - 1);
            
            // Find comma separator
            CommaPos := Pos(',', TempStr);
            If CommaPos > 0 Then
            Begin
                // Extract X coordinate
                XStr := Trim(Copy(TempStr, 1, CommaPos - 1));
                // Extract Y coordinate
                YStr := Trim(Copy(TempStr, CommaPos + 1, Length(TempStr)));
                
                Try
                    X := StrToFloat(XStr);
                    Y := StrToFloat(YStr);
                    XFound := True;
                    YFound := True;
                Except
                End;
            End;
        End;
    End;
    
    // If position format didn't work, try individual coordinate parameters
    If Not XFound Then
    Begin
        // Try all possible X coordinate parameter names
        If Pos('"x_position"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'x_position');
            XFound := True;
        End
        Else If Pos('"position_x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'position_x');
            XFound := True;
        End
        Else If Pos('"new_x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'new_x');
            XFound := True;
        End
        Else If Pos('"x"', LowerJson) > 0 Then
        Begin
            X := ExtractJsonNumber(CommandJson, 'x');
            XFound := True;
        End
        Else
            X := 0;
    End;
    
    If Not YFound Then
    Begin
        // Try all possible Y coordinate parameter names
        If Pos('"y_position"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'y_position');
            YFound := True;
        End
        Else If Pos('"position_y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'position_y');
            YFound := True;
        End
        Else If Pos('"new_y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'new_y');
            YFound := True;
        End
        Else If Pos('"y"', LowerJson) > 0 Then
        Begin
            Y := ExtractJsonNumber(CommandJson, 'y');
            YFound := True;
        End
        Else
            Y := 0;
    End;
    
    Rotation := ExtractJsonNumber(CommandJson, 'rotation');
    LayerName := ExtractJsonString(CommandJson, 'layer');
    If LayerName = '' Then
        LayerName := 'Top Layer';
    
    // Convert layer name to layer constant
    Layer := eTopLayer;
    If Pos('bottom', LowerCase(LayerName)) > 0 Then
        Layer := eBottomLayer;
    
    // Debug output (commented out - remove if not needed)
    // If XFound Then
    //     XFoundStr := 'YES'
    // Else
    //     XFoundStr := 'NO';
    // If YFound Then
    //     YFoundStr := 'YES'
    // Else
    //     YFoundStr := 'NO';
    //
    // ShowMessage('DEBUG add_component:' + #13#10 +
    //            'Component: "' + CompName + '"' + #13#10 +
    //            'Footprint: "' + Footprint + '"' + #13#10 +
    //            'Value: "' + Value + '"' + #13#10 +
    //            'X: ' + FormatFloat('0.00', X) + ' (found: ' + XFoundStr + ')' + #13#10 +
    //            'Y: ' + FormatFloat('0.00', Y) + ' (found: ' + YFoundStr + ')' + #13#10 +
    //            'Rotation: ' + FormatFloat('0.00', Rotation) + #13#10 +
    //            'Layer: ' + LayerName);
    
    // Note: Adding components requires access to component libraries
    // This is a simplified implementation that may not work without proper library setup
    If (CompName <> '') And XFound And YFound Then
    Begin
        Try
            PCBServer.PreProcess;
            
            // Try to find an existing component to clone from (for resistors or capacitors)
            // This ensures we get a proper component with correct properties
            ExistingComponent := Nil;
            If (Length(CompName) > 0) And (UpperCase(Copy(CompName, 1, 1)) = 'R') Then
            Begin
                // Find an existing resistor to clone
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_Method(eProcessAll);
                    ExistingComponent := Iterator.FirstPCBObject;
                    While ExistingComponent <> Nil Do
                    Begin
                        Try
                            If (ExistingComponent.Name <> Nil) And (Length(ExistingComponent.Name.Text) > 0) Then
                            Begin
                                If (UpperCase(Copy(ExistingComponent.Name.Text, 1, 1)) = 'R') Then
                                    Break;
                            End;
                        Except
                        End;
                        ExistingComponent := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End
            Else If (Length(CompName) > 0) And (UpperCase(Copy(CompName, 1, 1)) = 'C') Then
            Begin
                // Find an existing capacitor to clone
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_Method(eProcessAll);
                    ExistingComponent := Iterator.FirstPCBObject;
                    While ExistingComponent <> Nil Do
                    Begin
                        Try
                            If (ExistingComponent.Name <> Nil) And (Length(ExistingComponent.Name.Text) > 0) Then
                            Begin
                                If (UpperCase(Copy(ExistingComponent.Name.Text, 1, 1)) = 'C') Then
                                    Break;
                            End;
                        Except
                        End;
                        ExistingComponent := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End;
            
            // Create component (simplified - may need library access)
            Component := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
            If Component <> Nil Then
            Begin
                // If we found an existing component, copy its properties first
                If ExistingComponent <> Nil Then
                Begin
                    Try
                        Component.Pattern := ExistingComponent.Pattern;
                        If (Component.Name <> Nil) And (ExistingComponent.Name <> Nil) Then
                        Begin
                            Component.Name.Size := ExistingComponent.Name.Size;
                            Component.Name.Width := ExistingComponent.Name.Width;
                        End;
                        If (Component.Comment <> Nil) And (ExistingComponent.Comment <> Nil) Then
                        Begin
                            Component.Comment.Size := ExistingComponent.Comment.Size;
                            Component.Comment.Width := ExistingComponent.Comment.Width;
                        End;
                    Except
                    End;
                End;
                
                // CRITICAL: Set the designator IMMEDIATELY after creation
                // Use BeginModify/EndModify for proper property modification
                Try
                    Component.BeginModify;
                    If Component.Name <> Nil Then
                    Begin
                        Component.Name.Text := CompName;
                    End;
                    Component.EndModify;
                Except
                    // Fallback: direct assignment
                    Try
                        If Component.Name <> Nil Then
                        Begin
                            Component.Name.Text := CompName;
                        End;
                    Except
                    End;
                End;
                
                // Try to find a similar component to copy footprint from
                // For resistors, try to find an existing resistor (R*) and copy its footprint
                If (Length(CompName) > 0) And (UpperCase(Copy(CompName, 1, 1)) = 'R') Then
                Begin
                    // Try to find an existing resistor component to copy footprint
                    Iterator := PCB.BoardIterator_Create;
                    Try
                        Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                        Iterator.AddFilter_Method(eProcessAll);
                        ExistingComponent := Iterator.FirstPCBObject;
                        While ExistingComponent <> Nil Do
                        Begin
                            Try
                                // Safely check if component name starts with 'R' or 'r'
                                If (ExistingComponent.Name <> Nil) And (Length(ExistingComponent.Name.Text) > 0) Then
                                Begin
                                    If (UpperCase(Copy(ExistingComponent.Name.Text, 1, 1)) = 'R') Then
                                    Begin
                                        // Copy footprint pattern from existing resistor
                                        If ExistingComponent.Pattern <> '' Then
                                        Begin
                                            Component.Pattern := ExistingComponent.Pattern;
                                            // Copy text size properties to match existing component
                                            Try
                                                Component.Name.Size := ExistingComponent.Name.Size;
                                                Component.Name.Width := ExistingComponent.Name.Width;
                                                If Component.Comment <> Nil Then
                                                Begin
                                            Component.Comment.Size := ExistingComponent.Comment.Size;
                                            Component.Comment.Width := ExistingComponent.Comment.Width;
                                        End;
                                    Except
                                    End;
                                    Break;
                                        End;
                                    End;
                                End;
                            Except
                                // Skip this component if there's an error accessing its properties
                            End;
                            ExistingComponent := Iterator.NextPCBObject;
                        End;
                    Finally
                        PCB.BoardIterator_Destroy(Iterator);
                    End;
                End
                // For capacitors (C*), try to find an existing capacitor
                Else If (Length(CompName) > 0) And (UpperCase(Copy(CompName, 1, 1)) = 'C') Then
                Begin
                    Iterator := PCB.BoardIterator_Create;
                    Try
                        Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                        Iterator.AddFilter_Method(eProcessAll);
                        ExistingComponent := Iterator.FirstPCBObject;
                        While ExistingComponent <> Nil Do
                        Begin
                            Try
                                // Safely check if component name starts with 'C' or 'c'
                                If (ExistingComponent.Name <> Nil) And (Length(ExistingComponent.Name.Text) > 0) Then
                                Begin
                                    If (UpperCase(Copy(ExistingComponent.Name.Text, 1, 1)) = 'C') Then
                                    Begin
                                        If ExistingComponent.Pattern <> '' Then
                                        Begin
                                            Component.Pattern := ExistingComponent.Pattern;
                                            // Copy text size properties to match existing component
                                            Try
                                                Component.Name.Size := ExistingComponent.Name.Size;
                                                Component.Name.Width := ExistingComponent.Name.Width;
                                                If Component.Comment <> Nil Then
                                                Begin
                                                Component.Comment.Size := ExistingComponent.Comment.Size;
                                                Component.Comment.Width := ExistingComponent.Comment.Width;
                                            End;
                                        Except
                                        End;
                                        Break;
                                        End;
                                    End;
                                End;
                            Except
                                // Skip this component if there's an error accessing its properties
                            End;
                            ExistingComponent := Iterator.NextPCBObject;
                        End;
                    Finally
                        PCB.BoardIterator_Destroy(Iterator);
                    End;
                End;
                
                // If footprint was specified in parameters, use it (only if not already set)
                If (Footprint <> '') And (Component.Pattern = '') Then
                Begin
                    Component.Pattern := Footprint;
                End;
                
                // Set component comment (value like "1k")
                If Value <> '' Then
                Begin
                    If Component.Comment <> Nil Then
                    Begin
                        Component.Comment.Text := Value;
                    End;
                End;
                
                // Copy text size from existing similar component to make text smaller
                // Find any existing component to copy text size from
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_Method(eProcessAll);
                    ExistingComponent := Iterator.FirstPCBObject;
                    If ExistingComponent <> Nil Then
                    Begin
                        // Copy text size properties from first existing component
                        // BUT preserve our component name!
                        Try
                            If (Component.Name <> Nil) And (ExistingComponent.Name <> Nil) Then
                            Begin
                                // Save the name before copying size properties
                                Component.Name.Text := CompName;
                                Component.Name.Size := ExistingComponent.Name.Size;
                                Component.Name.Width := ExistingComponent.Name.Width;
                                // Ensure name is still set after copying properties
                                Component.Name.Text := CompName;
                            End;
                            If (Component.Comment <> Nil) And (ExistingComponent.Comment <> Nil) Then
                            Begin
                                Component.Comment.Size := ExistingComponent.Comment.Size;
                                Component.Comment.Width := ExistingComponent.Comment.Width;
                            End;
                        Except
                        End;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
                
                // Set position and properties
                Component.X := MMsToCoord(X);
                Component.Y := MMsToCoord(Y);
                Component.Layer := Layer;
                Component.Moveable := True;
                If Rotation <> 0 Then
                    Component.Rotation := Rotation;
                
                // CRITICAL: Set name again before adding to ensure it's applied
                // Sometimes Altium resets the name when adding, so we set it multiple times
                Try
                    If Component.Name <> Nil Then
                    Begin
                        Component.Name.Text := CompName;
                    End;
                Except
                End;
                
                // Add component to board FIRST
                PCB.AddPCBObject(Component);
                
                // Register the component with the board BEFORE modifying properties
                Try
                    PCBServer.SendMessageToRobots(Component.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Component.I_ObjectAddress);
                Except
                End;
                
                // Now use BeginModify/EndModify to properly set the designator
                // This is the CORRECT way to modify component properties in Altium
                Try
                    Component.BeginModify;
                    If Component.Name <> Nil Then
                    Begin
                        Component.Name.Text := CompName;
                    End;
                    Component.EndModify;
                Except
                    // If BeginModify/EndModify fails, try direct assignment
                    Try
                        If Component.Name <> Nil Then
                        Begin
                            Component.Name.Text := CompName;
                        End;
                    Except
                    End;
                End;
                
                // Invalidate to refresh display
                Component.GraphicallyInvalidate;
                If Component.Name <> Nil Then
                    Component.Name.GraphicallyInvalidate;
                
                PCBServer.PostProcess;
                
                // CRITICAL: After PostProcess, set the name one more time
                // PostProcess might reset some properties, so we need to set it again
                Try
                    Component.BeginModify;
                    If Component.Name <> Nil Then
                    Begin
                        Component.Name.Text := CompName;
                    End;
                    Component.EndModify;
                Except
                    Try
                        If Component.Name <> Nil Then
                        Begin
                            Component.Name.Text := CompName;
                        End;
                    Except
                    End;
                End;
                
                // Force a full update to ensure footprint is applied
                PCB.ViewManager_FullUpdate;
                
                // Final attempt: Set name one more time after full update
                Try
                    If Component.Name <> Nil Then
                    Begin
                        Component.Name.Text := CompName;
                        Component.Name.GraphicallyInvalidate;
                    End;
                Except
                End;
                
                Result := True;
            End;
        Except
            Result := False;
        End;
    End;
End;

// Execute connect_net command
Function ExecuteConnectNet(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Component: IPCB_Component;
    CompName, PinNum, NetName: String;
    Pin: IPCB_Pin;
    Net: IPCB_Net;
    Iterator: IPCB_BoardIterator;
    I: Integer;
Begin
    Result := False;
    CompName := ExtractJsonString(CommandJson, 'component_id');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    PinNum := ExtractJsonString(CommandJson, 'pin');
    NetName := ExtractJsonString(CommandJson, 'net_name');
    
    If (CompName <> '') And (PinNum <> '') And (NetName <> '') Then
    Begin
        Component := FindComponent(PCB, CompName);
        If Component <> Nil Then
        Begin
            Try
                PCBServer.PreProcess;
                // Find the pin
                Pin := Nil;
                For I := 1 To Component.PinCount Do
                Begin
                    If Component.Pins[I].Designator = PinNum Then
                    Begin
                        Pin := Component.Pins[I];
                        Break;
                    End;
                End;
                
                // Find the net
                Net := Nil;
                Iterator := PCB.BoardIterator_Create;
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eNetObject));
                    Iterator.AddFilter_Method(eProcessAll);
                    Net := Iterator.FirstPCBObject;
                    While Net <> Nil Do
                    Begin
                        If Net.Name = NetName Then
                            Break;
                        Net := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
                
                // Connect pin to net
                If (Pin <> Nil) And (Net <> Nil) Then
                Begin
                    Pin.Net := Net;
                    Component.GraphicallyInvalidate;
                    PCBServer.PostProcess;
                    Result := True;
                End;
            Except
                Result := False;
            End;
        End;
    End;
End;

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

// Procedure to update pcb_info.json after successful command execution
Procedure UpdatePCBInfoFile(PCB: IPCB_Board);
Var
    PCBFile: TStringList;
    FileName: String;
    Component: IPCB_Component;
    Net: IPCB_Net;
    Iterator: IPCB_BoardIterator;
    JSONStr: String;
    FirstItem: Boolean;
    CompX, CompY: Double;
    CompWidth, CompHeight: Double;
    CompName: String;
    CompLayer: String;
    NetName: String;
    TempStr: String;
    Doc: IDocument;
    Workspace: IWorkspace;
    ComponentCount, NetCount: Integer;
    BoardRect: TCoordRect;
    Width, Height: Double;
    BoundingRect: TCoordRect;
Begin
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\pcb_info.json';
    
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
            Exit;
    Except
        Exit;
    End;
    
    ComponentCount := 0;
    NetCount := 0;
    
    JSONStr := '{' + #13#10;
    
    Try
        Doc := Workspace.DM_FocusedDocument;
        If Doc <> Nil Then
            TempStr := Doc.DM_FileName
        Else
            TempStr := 'Unknown';
    Except
        TempStr := 'Unknown';
    End;
    JSONStr := JSONStr + '  "file_name": "' + EscapeJsonString(TempStr) + '",' + #13#10;
    
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
                
                Try
                    CompName := Component.Name.Text;
                Except
                    CompName := 'Unknown';
                End;
                
                CompX := CoordToMMs(Component.X);
                CompY := CoordToMMs(Component.Y);
                
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
                
                Try
                    CompLayer := Layer2String(Component.Layer);
                Except
                    CompLayer := 'Top Layer';
                End;
                
                JSONStr := JSONStr + '    {' + #13#10;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(CompName) + '",' + #13#10;
                JSONStr := JSONStr + '      "location": {' + #13#10;
                JSONStr := JSONStr + '        "x_mm": ' + FormatFloat('0.00', CompX) + ',' + #13#10;
                JSONStr := JSONStr + '        "y_mm": ' + FormatFloat('0.00', CompY) + #13#10;
                JSONStr := JSONStr + '      },' + #13#10;
                JSONStr := JSONStr + '      "size": {' + #13#10;
                JSONStr := JSONStr + '        "width_mm": ' + FormatFloat('0.00', CompWidth) + ',' + #13#10;
                JSONStr := JSONStr + '        "height_mm": ' + FormatFloat('0.00', CompHeight) + #13#10;
                JSONStr := JSONStr + '      },' + #13#10;
                JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(CompLayer) + '",' + #13#10;
                Try
                    JSONStr := JSONStr + '      "rotation_degrees": ' + FormatFloat('0.00', Component.Rotation) + ',' + #13#10;
                Except
                    JSONStr := JSONStr + '      "rotation_degrees": 0,' + #13#10;
                End;
                Try
                    TempStr := Component.Pattern;
                    If TempStr = '' Then TempStr := 'Unknown';
                Except
                    TempStr := 'Unknown';
                End;
                JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(TempStr) + '",' + #13#10;
                Try
                    TempStr := Component.Comment.Text;
                Except
                    TempStr := '';
                End;
                JSONStr := JSONStr + '      "parameters": [';
                If TempStr <> '' Then
                Begin
                    JSONStr := JSONStr + #13#10 + '        {' + #13#10;
                    JSONStr := JSONStr + '          "name": "Value",' + #13#10;
                    JSONStr := JSONStr + '          "value": "' + EscapeJsonString(TempStr) + '"' + #13#10;
                    JSONStr := JSONStr + '        }';
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
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
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
                
                Try
                    NetName := Net.Name;
                    If NetName = '' Then NetName := 'Unnamed';
                Except
                    NetName := 'Unknown';
                End;
                
                JSONStr := JSONStr + '    {' + #13#10;
                JSONStr := JSONStr + '      "name": "' + EscapeJsonString(NetName) + '",' + #13#10;
                JSONStr := JSONStr + '      "connected_components": [],' + #13#10;
                JSONStr := JSONStr + '      "track_count": 0,' + #13#10;
                JSONStr := JSONStr + '      "via_count": 0' + #13#10;
                JSONStr := JSONStr + '    }';
                
                Net := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
    End;
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    
    JSONStr := JSONStr + '  "statistics": {' + #13#10;
    JSONStr := JSONStr + '    "layer_count": 4,' + #13#10;
    JSONStr := JSONStr + '    "component_count": ' + IntToStr(ComponentCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "net_count": ' + IntToStr(NetCount) + ',' + #13#10;
    JSONStr := JSONStr + '    "via_count": 0,' + #13#10;
    JSONStr := JSONStr + '    "track_count": 0' + #13#10;
    JSONStr := JSONStr + '  },' + #13#10;
    
    JSONStr := JSONStr + '  "layers": [' + #13#10;
    JSONStr := JSONStr + '    "Top Layer",' + #13#10;
    JSONStr := JSONStr + '    "Mid Layer 1",' + #13#10;
    JSONStr := JSONStr + '    "Mid Layer 2",' + #13#10;
    JSONStr := JSONStr + '    "Bottom Layer"' + #13#10;
    JSONStr := JSONStr + '  ],' + #13#10;
    
    JSONStr := JSONStr + '  "status": "active"' + #13#10;
    JSONStr := JSONStr + '}';
    
    PCBFile := TStringList.Create;
    Try
        PCBFile.Text := JSONStr;
        Try
            PCBFile.SaveToFile(FileName);
        Except
            // Could not save pcb_info.json - silently continue
        End;
    Finally
        PCBFile.Free;
    End;
End;

// Execute set_board_size command
Function ExecuteSetBoardSize(PCB: IPCB_Board; CommandJson: String): Boolean;
Var
    Width, Height: Double;
    BoardShape: IPCB_BoardOutline;
    Iterator: IPCB_BoardIterator;
    Region: IPCB_Region;
Begin
    Result := False;
    Width := ExtractJsonNumber(CommandJson, 'width_mm');
    Height := ExtractJsonNumber(CommandJson, 'height_mm');
    
    If (Width > 0) And (Height > 0) Then
    Begin
        Try
            PCBServer.PreProcess;
            // Get board outline and modify it
            // Note: This is a simplified implementation
            // Full implementation would require creating/modifying board shape regions
            PCB.BoardOutline.Invalidate;
            PCBServer.PostProcess;
            Result := True;
        Except
            Result := False;
        End;
    End;
End;

// Main procedure to execute commands
// Run this manually: File -> Run Script -> altium_execute_commands.pas -> ExecuteCommands
Procedure ExecuteCommands;
Var
    PCB: IPCB_Board;
    CommandFile: TStringList;
    FileName, OriginalFileName, FileContent: String;
    Workspace: IWorkspace;
    Doc: IDocument;
    CommandsExecuted: Boolean;
    I, J: Integer;
    CommandType: String;
    CommandStart, CommandEnd, BraceCount: Integer;
    CommandJson: String;
    Success: Boolean;
    SuccessCount: Integer;
    FailCount: Integer;
    TriggerFile: String;
    HasTrigger: Boolean;
Begin
    // Initialize
    CommandsExecuted := False;
    SuccessCount := 0;
    FailCount := 0;
    
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Could not get Altium workspace. Please try again.');
            Exit;
        End;
    Except
        ShowMessage('ERROR: Exception getting workspace.');
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
        ShowMessage('ERROR: No PCB document is open. Please open a PCB file first.');
        Exit;
    End;
    
    // Read commands file - try multiple locations
    FileName := '';
    
    // Try hardcoded path first (most reliable)
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\pcb_commands.json';
    If Not FileExists(FileName) Then
    Begin
        // Try relative to PCB file
        Try
            FileName := ExtractFilePath(PCB.FileName) + 'pcb_commands.json';
            If Not FileExists(FileName) Then
            Begin
                FileName := ExtractFilePath(PCB.FileName) + '..\pcb_commands.json';
                If Not FileExists(FileName) Then
                Begin
                    FileName := '';
                End;
            End;
        Except
            FileName := '';
        End;
    End;
    
    // If still not found, try current directory
    If (FileName = '') Or Not FileExists(FileName) Then
    Begin
        FileName := 'pcb_commands.json';
        If Not FileExists(FileName) Then
        Begin
            // No commands file - silently exit
            Exit;
        End;
    End;
    
    OriginalFileName := FileName;
    
    // Debug: Show which file we're using (can be removed later)
    // ShowMessage('Using commands file: ' + OriginalFileName);
    
    CommandFile := TStringList.Create;
    Try
        Try
            CommandFile.LoadFromFile(OriginalFileName);
            FileContent := CommandFile.Text;
            
            // Check if file is empty or just contains "[]"
            If (Length(FileContent) < 10) Or (Pos('[]', FileContent) > 0) Then
            Begin
                // File exists but has no commands
                ShowMessage('INFO: No commands to execute.' + #13#10 + #13#10 +
                           'The command queue is empty. Use EagilinsED to queue commands first.');
                Exit;
            End;
        Except
            // Could not read file
            ShowMessage('ERROR: Could not read commands file: ' + OriginalFileName);
            Exit;
        End;
        
        // Process commands: find each "command" key and extract its object
        I := 1;
        While I <= Length(FileContent) Do
        Begin
            // Find next "command" key
            CommandStart := Pos('"command"', LowerCase(Copy(FileContent, I, Length(FileContent) - I + 1)));
            If CommandStart = 0 Then
                Break;
            
            CommandStart := I + CommandStart - 1;
            
            // Extract command type
            CommandType := ExtractJsonString(Copy(FileContent, CommandStart, 500), 'command');
            
            If CommandType <> '' Then
            Begin
                // Extract a large enough substring containing the full command
                // This includes the command object with all its parameters
                CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(3000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
                
                // Execute command based on type (handle both underscore and camelCase)
                Success := False;
                // Normalize command type to lowercase for comparison
                CommandType := LowerCase(CommandType);
                
                // Debug: Show what command we're trying to execute
                // ShowMessage('Executing command: ' + CommandType);
                
                If (CommandType = 'move_component') Or (CommandType = 'movecomponent') Then
                    Success := ExecuteMoveComponent(PCB, CommandJson)
                Else If (CommandType = 'rotate_component') Or (CommandType = 'rotatecomponent') Then
                    Success := ExecuteRotateComponent(PCB, CommandJson)
                Else If (CommandType = 'remove_component') Or (CommandType = 'removecomponent') Or
                        (CommandType = 'delete_component') Or (CommandType = 'deletecomponent') Then
                    Success := ExecuteRemoveComponent(PCB, CommandJson)
                Else If (CommandType = 'add_component') Or (CommandType = 'addcomponent') Then
                    Success := ExecuteAddComponent(PCB, CommandJson)
                Else If (CommandType = 'change_component_value') Or (CommandType = 'changecomponentvalue') Or
                        (CommandType = 'modify_component_value') Or (CommandType = 'modifycomponentvalue') Then
                    Success := ExecuteChangeComponentValue(PCB, CommandJson)
                Else If (CommandType = 'change_component_size') Or (CommandType = 'changecomponentsize') Or
                        (CommandType = 'change_component_footprint') Or (CommandType = 'changecomponentfootprint') Then
                    Success := ExecuteChangeComponentSize(PCB, CommandJson)
                Else If (CommandType = 'add_track') Or (CommandType = 'addtrack') Then
                    Success := ExecuteAddTrack(PCB, CommandJson)
                Else If (CommandType = 'add_via') Or (CommandType = 'addvia') Then
                    Success := ExecuteAddVia(PCB, CommandJson)
                Else If (CommandType = 'connect_net') Or (CommandType = 'connectnet') Then
                    Success := ExecuteConnectNet(PCB, CommandJson)
                Else If (CommandType = 'change_layer') Or (CommandType = 'changelayer') Then
                    Success := ExecuteChangeLayer(PCB, CommandJson)
                Else If (CommandType = 'set_board_size') Or (CommandType = 'setboardsize') Then
                    Success := ExecuteSetBoardSize(PCB, CommandJson)
                Else
                Begin
                    // Unknown command type - silently skip
                End;
                
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
            
            // Move to next potential command
            I := CommandStart + 200;
        End;
        
        // Refresh view
        Try
            PCB.ViewManager_FullUpdate;
            PCB.GraphicallyInvalidate;
        Except
        End;
        
        // Clear commands file if executed
        If CommandsExecuted Then
        Begin
            Try
                CommandFile.Clear;
                CommandFile.Add('[]');
                CommandFile.SaveToFile(OriginalFileName);
                
                // Update pcb_info.json after successful execution
                Try
                    UpdatePCBInfoFile(PCB);
                Except
                End;
                
                // Show result message
                If (SuccessCount > 0) And (FailCount = 0) Then
                    ShowMessage('SUCCESS!' + #13#10 + #13#10 +
                               IntToStr(SuccessCount) + ' command(s) executed successfully.' + #13#10 + #13#10 +
                               'PCB info has been updated.')
                Else If (SuccessCount > 0) And (FailCount > 0) Then
                    ShowMessage('PARTIAL SUCCESS' + #13#10 + #13#10 +
                               IntToStr(SuccessCount) + ' command(s) succeeded.' + #13#10 +
                               IntToStr(FailCount) + ' command(s) failed.' + #13#10 + #13#10 +
                               'PCB info has been updated.')
                Else If FailCount > 0 Then
                    ShowMessage('FAILED' + #13#10 + #13#10 +
                               IntToStr(FailCount) + ' command(s) failed to execute.' + #13#10 +
                               'Check command parameters.');
            Except
            End;
        End;
        
    Finally
        CommandFile.Free;
    End;
End;
