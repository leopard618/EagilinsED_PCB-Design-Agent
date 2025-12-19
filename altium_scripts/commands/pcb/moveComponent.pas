{*
 * Move Component Command
 * Moves a component to a new position on the PCB
 * 
 * Usage: Run this script directly, or call from main.pas
 * Command: move_component
 * Parameters: {"component_name": "U1", "new_coordinates": [50.0, 50.0]}
 *}

// Helper: Check if file exists
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

// Helper: Extract JSON string
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

// Helper: Extract JSON array element
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

// Helper: Convert mm to coordinates
Function MMsToCoord(MM: Double): TCoord;
Begin
    Result := Round(MM * 10000);
End;

// Helper: Find component by name
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
    End;
End;

// Main command: Move component
Function ExecuteMoveComponent(CommandJson: String): Boolean;
Var
    PCB: IPCB_Board;
    Component: IPCB_Component;
    CompName: String;
    X, Y: Double;
    XStr, YStr: String;
Begin
    Result := False;
    
    // Get PCB
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
    
    // Extract parameters
    CompName := ExtractJsonString(CommandJson, 'component_name');
    If CompName = '' Then
        CompName := ExtractJsonString(CommandJson, 'name');
    
    XStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 0);
    YStr := ExtractJsonArrayElement(CommandJson, 'new_coordinates', 1);
    If (XStr = '') Or (YStr = '') Then
    Begin
        XStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 0);
        YStr := ExtractJsonArrayElement(CommandJson, 'coordinates', 1);
    End;
    
    If (CompName = '') Or (XStr = '') Or (YStr = '') Then
    Begin
        ShowMessage('ERROR: Missing parameters. Required: component_name, new_coordinates [x, y]');
        Exit;
    End;
    
    Try
        X := StrToFloat(XStr);
        Y := StrToFloat(YStr);
    Except
        ShowMessage('ERROR: Invalid coordinates');
        Exit;
    End;
    
    // Find and move component
    Component := FindComponent(PCB, CompName);
    If Component = Nil Then
    Begin
        ShowMessage('ERROR: Component "' + CompName + '" not found.');
        Exit;
    End;
    
    Try
        PCBServer.PreProcess;
        Component.Moveable := True;
        Component.MoveToXY(MMsToCoord(X), MMsToCoord(Y));
        Component.GraphicallyInvalidate;
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        Result := True;
        ShowMessage('SUCCESS: Component "' + CompName + '" moved to (' + FloatToStr(X) + ', ' + FloatToStr(Y) + ') mm');
    Except
        ShowMessage('ERROR: Failed to move component');
    End;
End;

// Entry point: Read from pcb_commands.json and execute
Procedure RunMoveComponent;
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
        
        // Find move_component command
        CommandStart := Pos('"move_component"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No move_component command found in ' + FileName);
            Exit;
        End;
        
        // Extract command JSON (simplified - get surrounding context)
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteMoveComponent(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

