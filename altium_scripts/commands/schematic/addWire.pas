{*
 * Add Wire Command
 * Adds a wire between two points in the schematic
 * Command: add_wire
 * Parameters: {"start": [100.0, 100.0], "end": [200.0, 100.0]}
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

Function ExecuteAddWire(CommandJson: String): Boolean;
Var
    CurrentSheet: ISch_Document;
    Wire: ISch_Wire;
    X1, Y1, X2, Y2: Double;
    StartX, StartY, EndX, EndY: TCoord;
Begin
    Result := False;
    
    CurrentSheet := GetCurrentSchematic;
    If CurrentSheet = Nil Then
    Begin
        ShowMessage('ERROR: No schematic document is open.');
        Exit;
    End;
    
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
    
    If (X1 = 0.0) And (Y1 = 0.0) And (X2 = 0.0) And (Y2 = 0.0) Then
    Begin
        ShowMessage('ERROR: Missing parameters. Required: start [x, y], end [x, y]');
        Exit;
    End;
    
    Try
        SchServer.ProcessControl.PreProcess(CurrentSheet, '');
        
        Wire := SchServer.SchObjectFactory(eWire, eCreate_Default);
        If Wire = Nil Then
        Begin
            ShowMessage('ERROR: Could not create wire');
            Exit;
        End;
        
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
        ShowMessage('SUCCESS: Wire added from (' + FloatToStr(X1) + ', ' + FloatToStr(Y1) + ') to (' + FloatToStr(X2) + ', ' + FloatToStr(Y2) + ') mm');
    Except
        ShowMessage('ERROR: Failed to add wire');
    End;
End;

Procedure RunAddWire;
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
        
        CommandStart := Pos('"add_wire"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No add_wire command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteAddWire(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

