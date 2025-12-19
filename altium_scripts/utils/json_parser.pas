{*
 * JSON Parser Utilities
 * Extract values from JSON strings
 *}

// Extract string value from JSON
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

// Extract numeric value from JSON
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
        ColonPos := KeyPos;
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] <> ':') Do
            Inc(ColonPos);
        Inc(ColonPos);
        
        While (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = ' ') Do
            Inc(ColonPos);
        
        IsQuoted := False;
        If (ColonPos <= Length(JsonContent)) And (JsonContent[ColonPos] = '"') Then
        Begin
            IsQuoted := True;
            Inc(ColonPos);
            QuoteStart := ColonPos;
            QuoteEnd := QuoteStart;
            While (QuoteEnd <= Length(JsonContent)) And (JsonContent[QuoteEnd] <> '"') Do
                Inc(QuoteEnd);
            TempStr := Trim(Copy(JsonContent, QuoteStart, QuoteEnd - QuoteStart));
        End
        Else
        Begin
            NumStart := ColonPos;
            NumEnd := NumStart;
            While (NumEnd <= Length(JsonContent)) And (JsonContent[NumEnd] <> ',') And (JsonContent[NumEnd] <> '}') And (JsonContent[NumEnd] <> ']') And (JsonContent[NumEnd] <> #13) And (JsonContent[NumEnd] <> #10) And (JsonContent[NumEnd] <> ' ') Do
                Inc(NumEnd);
            TempStr := Trim(Copy(JsonContent, NumStart, NumEnd - NumStart));
        End;
        
        TempStr := LowerCase(TempStr);
        If Pos('mm', TempStr) > 0 Then
            TempStr := Copy(TempStr, 1, Pos('mm', TempStr) - 1)
        Else If Pos('mil', TempStr) > 0 Then
        Begin
            TempStr := Copy(TempStr, 1, Pos('mil', TempStr) - 1);
            Try
                Result := StrToFloat(TempStr) * 0.0254;
                Exit;
            Except
            End;
        End
        Else If Pos('inch', TempStr) > 0 Then
        Begin
            TempStr := Copy(TempStr, 1, Pos('inch', TempStr) - 1);
            Try
                Result := StrToFloat(TempStr) * 25.4;
                Exit;
            Except
            End;
        End;
        
        Try
            Result := StrToFloat(Trim(TempStr));
        Except
            Result := 0;
        End;
    End;
End;

// Extract array element from JSON
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

