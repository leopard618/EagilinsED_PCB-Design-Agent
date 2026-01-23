{*
 * Optimized JSON String Escape Function
 * Uses pre-allocation to avoid repeated string concatenation
 * This is more memory-efficient than the standard EscapeJsonString
 *}

// Optimized escape function with pre-allocation
Function EscapeJsonStringFast(InputStr: String; MaxLen: Integer): String;
Var
    I, Len, ResultLen: Integer;
    Ch: Char;
    NeedsEscape: Boolean;
    EscapedCount: Integer;
Begin
    // Limit input length
    Len := Length(InputStr);
    If Len > MaxLen Then
        Len := MaxLen;
    
    If Len = 0 Then
    Begin
        Result := '';
        Exit;
    End;
    
    // First pass: count escape characters to pre-allocate
    EscapedCount := 0;
    For I := 1 To Len Do
    Begin
        Ch := InputStr[I];
        If (Ch = '"') Or (Ch = '\') Or (Ch = #13) Or (Ch = #10) Or (Ch = #9) Or 
           ((Ord(Ch) < 32) Or (Ord(Ch) > 126)) Then
            Inc(EscapedCount);
    End;
    
    // Pre-allocate result string (worst case: all chars need escaping = 2x length)
    ResultLen := Len + EscapedCount;
    SetLength(Result, ResultLen);
    
    // Second pass: build result
    ResultLen := 0;
    For I := 1 To Len Do
    Begin
        Ch := InputStr[I];
        If Ch = '"' Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '\';
            Inc(ResultLen);
            Result[ResultLen] := '"';
        End
        Else If Ch = '\' Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '\';
            Inc(ResultLen);
            Result[ResultLen] := '\';
        End
        Else If Ch = #13 Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '\';
            Inc(ResultLen);
            Result[ResultLen] := 'r';
        End
        Else If Ch = #10 Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '\';
            Inc(ResultLen);
            Result[ResultLen] := 'n';
        End
        Else If Ch = #9 Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '\';
            Inc(ResultLen);
            Result[ResultLen] := 't';
        End
        Else If (Ord(Ch) < 32) Or (Ord(Ch) > 126) Then
        Begin
            Inc(ResultLen);
            Result[ResultLen] := '?';
        End
        Else
        Begin
            Inc(ResultLen);
            Result[ResultLen] := Ch;
        End;
    End;
    
    // Trim to actual length
    SetLength(Result, ResultLen);
End;

// Standard escape function (backward compatible, but optimized)
Function EscapeJsonString(InputStr: String): String;
Begin
    Result := EscapeJsonStringFast(InputStr, 200);
End;
