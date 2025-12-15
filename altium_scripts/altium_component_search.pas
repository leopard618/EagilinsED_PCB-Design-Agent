{*
 * Altium Designer Script - Component Search
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Search installed libraries for components
 * - List available libraries
 * - Export search results to JSON
 * 
 * TO RUN THIS SCRIPT:
 * 1. In Altium Designer, go to: File -> Run Script
 * 2. Select this file: altium_component_search.pas
 * 3. When dialog appears, select the procedure you want to run
 * 4. Click OK
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

// Search for components in installed libraries
Procedure SearchComponents;
Var
    IntLibMan     : IIntegratedLibraryManager;
    SearchQuery   : String;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    I, J          : Integer;
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


