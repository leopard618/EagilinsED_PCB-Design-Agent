{*
 * List Libraries Command
 * Lists installed component libraries
 * Command: list_libraries
 *}

Const
    BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\';

// Helper function to escape JSON strings
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

// List all installed libraries
Procedure ListInstalledLibraries;
Var
    IntLibMan     : IIntegratedLibraryManager;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    I             : Integer;
    LibPath       : String;
    LibCount      : Integer;
    FirstItem     : Boolean;
Begin
    Try
        IntLibMan := IntegratedLibraryManager;
        If IntLibMan = Nil Then
        Begin
            ShowMessage('ERROR: Library Manager not available');
            Exit;
        End;
    Except
        ShowMessage('ERROR: Cannot access Library Manager');
        Exit;
    End;
    
    LibCount := IntLibMan.InstalledLibraryCount;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "library_count": ' + IntToStr(LibCount) + ',' + #13#10;
    JSONStr := JSONStr + '  "libraries": [' + #13#10;
    FirstItem := True;
    
    For I := 0 To LibCount - 1 Do
    Begin
        If Not FirstItem Then
            JSONStr := JSONStr + ',' + #13#10;
        FirstItem := False;
        
        Try
            LibPath := IntLibMan.InstalledLibraryPath(I);
        Except
            LibPath := 'Unknown';
        End;
        
        JSONStr := JSONStr + '    {' + #13#10;
        JSONStr := JSONStr + '      "index": ' + IntToStr(I) + ',' + #13#10;
        JSONStr := JSONStr + '      "path": "' + EscapeJsonString(LibPath) + '",' + #13#10;
        JSONStr := JSONStr + '      "name": "' + EscapeJsonString(ExtractFileName(LibPath)) + '"' + #13#10;
        JSONStr := JSONStr + '    }';
    End;
    
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'library_list.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Library List Exported!' + #13#10 + #13#10 +
                        'Total Libraries: ' + IntToStr(LibCount) + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
