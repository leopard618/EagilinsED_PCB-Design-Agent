{*
 * Get Component Details Command
 * Gets detailed information about a component
 * Command: get_component_details
 * Parameters: {"library_ref": "Resistor", "library_name": "Miscellaneous Devices"}
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

// Get details of a specific component
Procedure GetComponentDetails;
Var
    IntLibMan     : IIntegratedLibraryManager;
    LibPath       : String;
    CompName      : String;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    CompInfo      : IComponentInfo;
    Found         : Boolean;
    I             : Integer;
    Iterator      : ILibCompInfoIterator;
Begin
    // Get library path
    LibPath := InputBox('Component Details', 
                        'Enter library path or name:',
                        '');
    
    If LibPath = '' Then
    Begin
        ShowMessage('Cancelled.');
        Exit;
    End;
    
    // Get component name
    CompName := InputBox('Component Details', 
                         'Enter component name:',
                         '');
    
    If CompName = '' Then
    Begin
        ShowMessage('Cancelled.');
        Exit;
    End;
    
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
    
    Found := False;
    
    // Search through libraries
    For I := 0 To IntLibMan.InstalledLibraryCount - 1 Do
    Begin
        Try
            If (Pos(LowerCase(LibPath), LowerCase(IntLibMan.InstalledLibraryPath(I))) > 0) Then
            Begin
                LibPath := IntLibMan.InstalledLibraryPath(I);
                
                // Get component iterator
                Iterator := IntLibMan.GetComponentIterator(LibPath);
                If Iterator <> Nil Then
                Begin
                    Try
                        CompInfo := Iterator.FirstComponentInfo;
                        While CompInfo <> Nil Do
                        Begin
                            If LowerCase(CompInfo.Name) = LowerCase(CompName) Then
                            Begin
                                Found := True;
                                
                                // Build JSON
                                JSONStr := '{' + #13#10;
                                JSONStr := JSONStr + '  "component": {' + #13#10;
                                JSONStr := JSONStr + '    "name": "' + EscapeJsonString(CompInfo.Name) + '",' + #13#10;
                                JSONStr := JSONStr + '    "description": "' + EscapeJsonString(CompInfo.Description) + '",' + #13#10;
                                JSONStr := JSONStr + '    "library": "' + EscapeJsonString(ExtractFileName(LibPath)) + '",' + #13#10;
                                JSONStr := JSONStr + '    "library_path": "' + EscapeJsonString(LibPath) + '"' + #13#10;
                                JSONStr := JSONStr + '  },' + #13#10;
                                JSONStr := JSONStr + '  "status": "found"' + #13#10;
                                JSONStr := JSONStr + '}';
                                
                                Break;
                            End;
                            
                            CompInfo := Iterator.NextComponentInfo;
                        End;
                    Finally
                    End;
                End;
                
                If Found Then Break;
            End;
        Except
        End;
    End;
    
    If Not Found Then
    Begin
        JSONStr := '{' + #13#10;
        JSONStr := JSONStr + '  "query": {' + #13#10;
        JSONStr := JSONStr + '    "library": "' + EscapeJsonString(LibPath) + '",' + #13#10;
        JSONStr := JSONStr + '    "component": "' + EscapeJsonString(CompName) + '"' + #13#10;
        JSONStr := JSONStr + '  },' + #13#10;
        JSONStr := JSONStr + '  "status": "not_found"' + #13#10;
        JSONStr := JSONStr + '}';
    End;
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'component_details.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            If Found Then
                ShowMessage('Component Found!' + #13#10 + #13#10 +
                            'Name: ' + CompName + #13#10 +
                            'Library: ' + LibPath + #13#10 + #13#10 +
                            'Details saved to: ' + FileName)
            Else
                ShowMessage('Component not found: ' + CompName + #13#10 + #13#10 +
                            'Try using SearchComponents to find available components.');
        Except
            ShowMessage('ERROR: Could not save file');
        End;
    Finally
        OutputFile.Free;
    End;
End;
