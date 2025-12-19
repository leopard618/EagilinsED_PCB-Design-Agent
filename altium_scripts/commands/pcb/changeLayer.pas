{*
 * Change Layer Command
 * Moves a component to a different layer on the PCB
 * Command: change_layer
 * Parameters: {"component_name": "U1", "layer": "BottomLayer"}
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

Function ExecuteChangeLayer(CommandJson: String): Boolean;
Var
    PCB: IPCB_Board;
    Component: IPCB_Component;
    CompName, LayerName: String;
    Layer: TLayer;
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
    
    LayerName := ExtractJsonString(CommandJson, 'layer');
    
    If (CompName = '') Or (LayerName = '') Then
    Begin
        ShowMessage('ERROR: Missing parameters. Required: component_name, layer');
        Exit;
    End;
    
    Component := FindComponent(PCB, CompName);
    If Component = Nil Then
    Begin
        ShowMessage('ERROR: Component "' + CompName + '" not found.');
        Exit;
    End;
    
    Layer := eTopLayer;
    If Pos('bottom', LowerCase(LayerName)) > 0 Then
        Layer := eBottomLayer;
    
    Try
        PCBServer.PreProcess;
        Component.Layer := Layer;
        Component.GraphicallyInvalidate;
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        Result := True;
        ShowMessage('SUCCESS: Component "' + CompName + '" moved to ' + LayerName);
    Except
        ShowMessage('ERROR: Failed to change layer');
    End;
End;

Procedure RunChangeLayer;
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
        
        CommandStart := Pos('"change_layer"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No change_layer command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteChangeLayer(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

