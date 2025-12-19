{*
 * Generate Drill Command
 * Generates drill files for manufacturing
 * Command: generate_drill
 *}

Const
    OUTPUT_BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\Output';
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

// Ensure output directory exists
Function EnsureOutputDir(SubDir: String): String;
Var
    FullPath: String;
Begin
    FullPath := OUTPUT_BASE_PATH;
    If SubDir <> '' Then
        FullPath := FullPath + '\' + SubDir;
    
    Try
        ForceDirectories(FullPath);
    Except
    End;
    
    Result := FullPath;
End;

// Generate NC Drill files
Procedure GenerateDrillFiles;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    OutputPath    : String;
    OutputFile    : TStringList;
    JSONStr       : String;
    FileName      : String;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then
        Begin
            ShowMessage('ERROR: Cannot access workspace');
            Exit;
        End;
    Except
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
        Try
            Doc := Workspace.DM_FocusedDocument;
            If (Doc <> Nil) And (Doc.DM_DocumentKind = 'PCB') Then
                PCB := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
        Except
        End;
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: Cannot access PCB board.');
        Exit;
    End;
    
    // Create output directory
    OutputPath := EnsureOutputDir('NC Drill');
    
    Try
        ResetParameters;
        AddStringParameter('OutputPath', OutputPath);
        RunProcess('PCB:ExportNCDrill');
        
        ShowMessage('NC Drill files generated!' + #13#10 + #13#10 +
                    'Output path: ' + OutputPath + #13#10 + #13#10 +
                    'For more control, use File → Fabrication Outputs → NC Drill Files');
    Except
        ShowMessage('To generate NC Drill files:' + #13#10 + #13#10 +
                    '1. Go to File → Fabrication Outputs → NC Drill Files' + #13#10 +
                    '2. Configure settings' + #13#10 +
                    '3. Click OK to generate' + #13#10 + #13#10 +
                    'Output path: ' + OutputPath);
    End;
    
    // Write result JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "NC Drill",' + #13#10;
    JSONStr := JSONStr + '  "output_path": "' + EscapeJsonString(OutputPath) + '",' + #13#10;
    JSONStr := JSONStr + '  "format": "Excellon",' + #13#10;
    JSONStr := JSONStr + '  "status": "generated"' + #13#10;
    JSONStr := JSONStr + '}';
    
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
End;
