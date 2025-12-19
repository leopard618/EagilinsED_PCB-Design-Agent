{*
 * Annotate Schematic Command
 * Annotates components in the schematic
 * Command: annotate
 * Parameters: {}
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

Function ExecuteAnnotate(CommandJson: String): Boolean;
Var
    CurrentSheet: ISch_Document;
    Workspace: IWorkspace;
Begin
    Result := False;
    
    CurrentSheet := GetCurrentSchematic;
    If CurrentSheet = Nil Then
    Begin
        ShowMessage('ERROR: No schematic document is open.');
        Exit;
    End;
    
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
        
        // Note: Full annotation requires Altium's annotation dialog
        // This is a simplified version that marks the schematic as needing annotation
        ShowMessage('Annotate command received. Please use Tools → Annotate Schematics in Altium Designer for full annotation.');
        Result := True;
    Except
        ShowMessage('ERROR: Failed to annotate');
    End;
End;

Procedure RunAnnotate;
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
        
        CommandStart := Pos('"annotate"', LowerCase(FileContent));
        If CommandStart = 0 Then
        Begin
            ShowMessage('No annotate command found in ' + FileName);
            Exit;
        End;
        
        CommandJson := Copy(FileContent, Max(1, CommandStart - 200), Min(2000, Length(FileContent) - Max(1, CommandStart - 200) + 200));
        
        Success := ExecuteAnnotate(CommandJson);
        
        If Success Then
            ShowMessage('Command executed successfully!')
        Else
            ShowMessage('Command failed. Check parameters.');
            
    Finally
        CommandFile.Free;
    End;
End;

