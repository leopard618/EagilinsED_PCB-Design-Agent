{*
 * Search Components Command
 * Searches for components in libraries
 * Command: search_components
 * Parameters: {"search_term": "resistor"}
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

// Search for components in installed libraries
Procedure SearchComponents;
Var
    IntLibMan     : IIntegratedLibraryManager;
    SearchQuery   : String;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    I             : Integer;
    LibPath       : String;
    LibCount      : Integer;
    ResultCount   : Integer;
    FirstItem     : Boolean;
    CompInfo      : IComponentInfo;
    Iterator      : ILibCompInfoIterator;
Begin
    // Get search query from user
    SearchQuery := InputBox('Component Search', 
                           'Enter search term (e.g., "resistor", "10k", "0805"):',
                           '');
    
    If SearchQuery = '' Then
    Begin
        ShowMessage('Search cancelled.');
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
    
    LibCount := IntLibMan.InstalledLibraryCount;
    ResultCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "query": "' + EscapeJsonString(SearchQuery) + '",' + #13#10;
    JSONStr := JSONStr + '  "libraries_searched": ' + IntToStr(LibCount) + ',' + #13#10;
    JSONStr := JSONStr + '  "results": [' + #13#10;
    FirstItem := True;
    
    // Search through libraries
    For I := 0 To LibCount - 1 Do
    Begin
        Try
            LibPath := IntLibMan.InstalledLibraryPath(I);
            
            // Get component iterator for this library
            Iterator := IntLibMan.GetComponentIterator(LibPath);
            If Iterator <> Nil Then
            Begin
                Try
                    CompInfo := Iterator.FirstComponentInfo;
                    While CompInfo <> Nil Do
                    Begin
                        // Check if component matches search
                        If (Pos(LowerCase(SearchQuery), LowerCase(CompInfo.Name)) > 0) Or
                           (Pos(LowerCase(SearchQuery), LowerCase(CompInfo.Description)) > 0) Then
                        Begin
                            Inc(ResultCount);
                            
                            If Not FirstItem Then
                                JSONStr := JSONStr + ',' + #13#10;
                            FirstItem := False;
                            
                            JSONStr := JSONStr + '    {' + #13#10;
                            JSONStr := JSONStr + '      "name": "' + EscapeJsonString(CompInfo.Name) + '",' + #13#10;
                            JSONStr := JSONStr + '      "description": "' + EscapeJsonString(CompInfo.Description) + '",' + #13#10;
                            JSONStr := JSONStr + '      "library": "' + EscapeJsonString(ExtractFileName(LibPath)) + '",' + #13#10;
                            JSONStr := JSONStr + '      "library_path": "' + EscapeJsonString(LibPath) + '"' + #13#10;
                            JSONStr := JSONStr + '    }';
                            
                            // Limit results to avoid huge files
                            If ResultCount >= 50 Then
                            Begin
                                JSONStr := JSONStr + ',' + #13#10 + '    {"note": "Results limited to 50"}';
                                Break;
                            End;
                        End;
                        
                        CompInfo := Iterator.NextComponentInfo;
                    End;
                Finally
                    // Iterator is automatically cleaned up
                End;
            End;
        Except
            // Skip library on error
        End;
        
        If ResultCount >= 50 Then Break;
    End;
    
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    JSONStr := JSONStr + '  "result_count": ' + IntToStr(ResultCount) + ',' + #13#10;
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'component_search.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Search Complete!' + #13#10 + #13#10 +
                        'Query: "' + SearchQuery + '"' + #13#10 +
                        'Results: ' + IntToStr(ResultCount) + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file to:' + #13#10 + FileName);
        End;
    Finally
        OutputFile.Free;
    End;
End;
