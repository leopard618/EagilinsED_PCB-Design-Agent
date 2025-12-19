{*
 * Add Component Command
 * Adds a new component to the PCB
 * Command: add_component
 * Parameters: {"component_name": "R1", "footprint": "R0805", "coordinates": [50.0, 50.0], "value": "10k"}
 *}

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

Function ExtractJsonNumber(JsonContent: String; KeyName: String): Double;
Var
    KeyPos, ColonPos, NumStart, NumEnd: Integer;
    LowerJson, TempStr, SearchKey: String;
Begin
    Result := 0;
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
        While (NumEnd <= Length(JsonContent)) And (JsonContent[NumEnd] <> ',') And (JsonContent[NumEnd] <> '}') And (JsonContent[NumEnd] <> ']') And (JsonContent[NumEnd] <> #13) And (JsonContent[NumEnd] <> #10) And (JsonContent[NumEnd] <> ' ') Do
            Inc(NumEnd);
        TempStr := Trim(Copy(JsonContent, NumStart, NumEnd - NumStart));
        Try
            Result := StrToFloat(TempStr);
        Except
            Result := 0;
        End;
    End;
End;

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

Function MMsToCoord(MM: Double): TCoord;
Begin
    Result := Round(MM * 10000);
End;

Function ExecuteAddComponent(CommandJson: String): Boolean;
Var
    PCB: IPCB_Board;
    Component, ExistingComponent: IPCB_Component;
    CompName, Footprint, Value, LayerName: String;
    X, Y, Rotation: Double;
    Layer: TLayer;
    XStr, YStr: String;
    Iterator: IPCB_BoardIterator;
Begin
    Result := False;
    
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
        If PCB = Nil Then
        Begin
            ShowMessage('ERROR: No PCB document is open.');
            Exit;
        End;
    Except
        ShowMessage('ERROR: Cannot access PCB.');
        Exit;
    End;
    
    CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    Footprint := ExtractJsonString(CommandJson, 'footprint');
    Value := ExtractJsonString(CommandJson, 'value');
    
    XStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 0);
    YStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 1);
    
    If (XStr = '') Or (YStr = '') Then
    Begin
        X := ExtractJsonNumber(CommandJson, 'x_position');
        Y := ExtractJsonNumber(CommandJson, 'y_position');
    End
    Else
    Begin
        Try
            X := StrToFloat(XStr);
            Y := StrToFloat(YStr);
        Except
            ShowMessage('ERROR: Invalid coordinates');
            Exit;
        End;
    End;
    
    Rotation := ExtractJsonNumber(CommandJson, 'rotation');
    LayerName := ExtractJsonString(CommandJson, 'layer');
    If LayerName = '' Then
        LayerName := 'Top Layer';
    
    Layer := eTopLayer;
    If Pos('bottom', LowerCase(LayerName)) > 0 Then
        Layer := eBottomLayer;
    
    If (CompName = '') Or (X = 0) Or (Y = 0) Then
    Begin
        ShowMessage('ERROR: Missing parameters. Required: component_name, coordinates [x, y]');
        Exit;
    End;
    
    Try
        PCBServer.PreProcess;
        Component := PCBServer.PCBObjectFactory(eComponentObject, eNoDimension, eCreate_Default);
        If Component <> Nil Then
        Begin
            Iterator := PCB.BoardIterator_Create;
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                Iterator.AddFilter_Method(eProcessAll);
                ExistingComponent := Iterator.FirstPCBObject;
                If ExistingComponent <> Nil Then
                    Component.Pattern := ExistingComponent.Pattern;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
            
            If Footprint <> '' Then
                Component.Pattern := Footprint;
            
            If Component.Name <> Nil Then
                Component.Name.Text := CompName;
            
            If Value <> '' Then
            Begin
                If Component.Comment <> Nil Then
                    Component.Comment.Text := Value;
            End;
            
            Component.X := MMsToCoord(X);
            Component.Y := MMsToCoord(Y);
            Component.Layer := Layer;
            Component.Moveable := True;
            If Rotation <> 0 Then
                Component.Rotation := Rotation;
            
            PCB.AddPCBObject(Component);
            Component.GraphicallyInvalidate;
            PCBServer.PostProcess;
            PCB.ViewManager_FullUpdate;
            Result := True;
            ShowMessage('SUCCESS: Component "' + CompName + '" added at (' + FloatToStr(X) + ', ' + FloatToStr(Y) + ') mm');
        End;
    Except
        ShowMessage('ERROR: Failed to add component');
    End;
End;

Procedure RunAddComponent;
Var
    CommandFile: TStringList;
    FileName: String;
    FileContent: String;
    CommandJson: String;
    CommandStart: Integer;
    Success: Boolean;
Begin
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\pcb_commands.json';
    
    If Not FileExists(FileName) Then
    Begin
        ShowMessage('ERROR: Command file not found: ' + FileName);
        Exit;
    End;
    
    CommandFile := TStringList.Create;
    Try
        CommandFile.LoadFromFile(FileName);
        FileContent := CommandFile.Text;
        
        CommandStart := Pos('"add_component"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No add_component command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteAddComponent(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

