{*
 * Place Component Command
 * Places a component in the schematic
 * Command: place_component
 * Parameters: {"library_ref": "Resistor", "library_name": "Miscellaneous Devices", "designator": "R1", "value": "10k", "position": [100.0, 100.0]}
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

Function GetCurrentSchematic: ISch_Document;
Var
    Workspace: IWorkspace;
    Doc: IDocument;
Begin
    Result := Nil;
    Try
        Result := SchServer.GetCurrentSchDocument;
    Except
    End;
    
    If Result = Nil Then
    Begin
        Try
            Workspace := GetWorkspace;
            If Workspace <> Nil Then
            Begin
                Doc := Workspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'SCH') Then
                Begin
                    Result := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
                End;
            End;
        Except
        End;
    End;
End;

Function ExecutePlaceComponent(CommandJson: String): Boolean;
Var
    CurrentSheet: ISch_Document;
    Component: ISch_Component;
    LibRef, Designator, Value, LibraryName: String;
    X, Y, Rotation: Double;
Begin
    Result := False;
    
    CurrentSheet := GetCurrentSchematic;
    If CurrentSheet = Nil Then
    Begin
        ShowMessage('ERROR: No schematic document is open.');
        Exit;
    End;
    
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
    
    If LibRef = '' Then
    Begin
        ShowMessage('ERROR: Missing parameter: library_ref');
        Exit;
    End;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        Component := SchServer.SchObjectFactory(eSchComponent, eCreate_Default);
        If Component = Nil Then
        Begin
            ShowMessage('ERROR: Could not create component');
            Exit;
        End;
        
        Component.LibReference := LibRef;
        If LibraryName <> '' Then
            Component.SourceLibraryName := LibraryName;
        
        Component.Location := Point(MMsToCoord(X), MMsToCoord(Y));
        If Rotation <> 0.0 Then
            Component.Orientation := Rotation;
        
        If Designator <> '' Then
        Begin
            If Component.Designator <> Nil Then
                Component.Designator.Text := Designator;
        End;
        
        If Value <> '' Then
        Begin
            If Component.Comment <> Nil Then
                Component.Comment.Text := Value;
        End;
        
        CurrentSheet.AddSchObject(Component);
        SchServer.RobotManager.SendMessage(CurrentSheet.I_ObjectAddress, c_Broadcast, SCHM_PrimitiveRegistration, Component.I_ObjectAddress);
        
        SchServer.ProcessControl.PostProcess(CurrentSheet, '');
        
        Result := True;
        ShowMessage('SUCCESS: Component placed at (' + FloatToStr(X) + ', ' + FloatToStr(Y) + ') mm');
    Except
        ShowMessage('ERROR: Failed to place component');
    End;
End;

Procedure RunPlaceComponent;
Var
    CommandFile: TStringList;
    FileName: String;
    FileContent: String;
    CommandJson: String;
    CommandStart: Integer;
    Success: Boolean;
Begin
    FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\schematic_commands.json';
    
    If Not FileExists(FileName) Then
    Begin
        ShowMessage('ERROR: Command file not found: ' + FileName);
        Exit;
    End;
    
    CommandFile := TStringList.Create;
    Try
        CommandFile.LoadFromFile(FileName);
        FileContent := CommandFile.Text;
        
        CommandStart := Pos('"place_component"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No place_component command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecutePlaceComponent(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

