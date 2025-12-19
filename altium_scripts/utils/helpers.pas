{*
 * Shared Helper Functions
 * Used by all command scripts
 *}

// Check if file exists
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

// Escape JSON strings
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

// Convert mm to coordinates
Function MMsToCoord(MM: Double): TCoord;
Begin
    Result := Round(MM * 10000);  // 1mm = 10000 internal units
End;

// Convert coordinates to mm
Function CoordToMMs(Coord: TCoord): Double;
Begin
    Result := Coord / 10000.0;
End;

// Convert coordinates to mm (for schematic)
Function CoordToMM(Coord: TCoord): Double;
Begin
    Result := Coord / 10000 / 39.3701;  // Altium internal units to mm
End;

