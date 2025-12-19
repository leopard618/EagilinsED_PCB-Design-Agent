{*
 * Add Via Command
 * Adds a via to the PCB
 * Command: add_via
 * Parameters: {"coordinates": [15.0, 15.0], "diameter": 0.5, "hole_diameter": 0.2}
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

Function ExecuteAddVia(CommandJson: String): Boolean;
Var
    PCB: IPCB_Board;
    Via: IPCB_Via;
    X, Y, Size, HoleSize: Double;
    XStr, YStr: String;
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
    
    XStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 0);
    YStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 1);
    
    If (XStr <> '') And (YStr <> '') Then
    Begin
        Try
            X := StrToFloat(XStr);
            Y := StrToFloat(YStr);
        Except
            X := 0;
            Y := 0;
        End;
    End
    Else
    Begin
        X := ExtractJsonNumber(CommandJson, 'x_position');
        If X = 0 Then
            X := ExtractJsonNumber(CommandJson, 'x');
        Y := ExtractJsonNumber(CommandJson, 'y_position');
        If Y = 0 Then
            Y := ExtractJsonNumber(CommandJson, 'y');
    End;
    
    Size := ExtractJsonNumber(CommandJson, 'diameter');
    If Size = 0 Then
        Size := ExtractJsonNumber(CommandJson, 'size');
    If Size = 0 Then
        Size := 0.5;
    
    HoleSize := ExtractJsonNumber(CommandJson, 'hole_diameter');
    If HoleSize = 0 Then
        HoleSize := ExtractJsonNumber(CommandJson, 'hole_size');
    If HoleSize = 0 Then
        HoleSize := 0.2;
    
    If (X = 0) Or (Y = 0) Then
    Begin
        ShowMessage('ERROR: Missing parameters. Required: coordinates [x, y]');
        Exit;
    End;
    
    Try
        PCBServer.PreProcess;
        Via := PCBServer.PCBObjectFactory(eViaObject, eNoDimension, eCreate_Default);
        Via.X := MMsToCoord(X);
        Via.Y := MMsToCoord(Y);
        Via.Size := MMsToCoord(Size);
        Via.HoleSize := MMsToCoord(HoleSize);
        PCB.AddPCBObject(Via);
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        Result := True;
        ShowMessage('SUCCESS: Via added at (' + FloatToStr(X) + ', ' + FloatToStr(Y) + ') mm');
    Except
        ShowMessage('ERROR: Failed to add via');
    End;
End;

Procedure RunAddVia;
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
        
        CommandStart := Pos('"add_via"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No add_via command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteAddVia(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

