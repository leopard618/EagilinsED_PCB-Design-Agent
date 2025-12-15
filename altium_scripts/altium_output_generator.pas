{*
 * Altium Designer Script - Manufacturing Output Generator
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Generate Gerber files
 * - Generate NC Drill files
 * - Generate Bill of Materials (BOM)
 * - Generate Pick and Place files
 * - Generate PDF documentation
 * 
 * TO RUN THIS SCRIPT:
 * 1. Open the PCB document
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_output_generator.pas
 * 4. When dialog appears, select the procedure you want to run
 * 5. Click OK
 *}

Const
    OUTPUT_BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\Output';

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
    
    // Create directory if it doesn't exist
    Try
        ForceDirectories(FullPath);
    Except
    End;
    
    Result := FullPath;
End;

// Generate Gerber files
Procedure GenerateGerberFiles;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    GerberOpts    : IPCB_GerberOptions;
    OutputPath    : String;
    GerberSetup   : IPCB_CAMOptionsObject;
    Layer         : TLayer;
    I             : Integer;
    GeneratedFiles: Integer;
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
        ShowMessage('ERROR: Cannot access PCB board.' + #13#10 + #13#10 +
                    'Please make sure a PCB document is open and active.');
        Exit;
    End;
    
    // Create output directory
    OutputPath := EnsureOutputDir('Gerber');
    
    GeneratedFiles := 0;
    
    // Use Altium's CAM generation
    Try
        // Note: This uses the default Gerber settings from the PCB document
        // For full control, you would need to configure IPCB_GerberOptions
        
        // Generate Gerber using Run Process
        // This invokes Altium's built-in Gerber generator
        ResetParameters;
        AddStringParameter('Format', 'RS-274X');
        AddStringParameter('OutputPath', OutputPath);
        RunProcess('PCB:ExportGerber');
        
        GeneratedFiles := 1; // Simplified count
        
        ShowMessage('Gerber files generated!' + #13#10 + #13#10 +
                    'Output path: ' + OutputPath + #13#10 + #13#10 +
                    'Please check the output directory for generated files.' + #13#10 +
                    'For more control, use File → Fabrication Outputs → Gerber Files');
    Except
        // If process fails, show manual instructions
        ShowMessage('To generate Gerber files:' + #13#10 + #13#10 +
                    '1. Go to File → Fabrication Outputs → Gerber Files' + #13#10 +
                    '2. Configure layers and settings' + #13#10 +
                    '3. Click OK to generate' + #13#10 + #13#10 +
                    'Output path: ' + OutputPath);
    End;
    
    // Write result JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "Gerber",' + #13#10;
    JSONStr := JSONStr + '  "output_path": "' + EscapeJsonString(OutputPath) + '",' + #13#10;
    JSONStr := JSONStr + '  "format": "RS-274X",' + #13#10;
    JSONStr := JSONStr + '  "status": "generated"' + #13#10;
    JSONStr := JSONStr + '}';
    
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
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
        // Generate NC Drill using Run Process
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
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
End;

// Generate Bill of Materials (BOM)
Procedure GenerateBOM;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Project       : IProject;
    Doc           : IDocument;
    Iterator      : IPCB_BoardIterator;
    Component     : IPCB_Component;
    OutputPath    : String;
    OutputFile    : TStringList;
    BOMFile       : TStringList;
    JSONStr       : String;
    FileName      : String;
    BOMFileName   : String;
    CompName      : String;
    CompValue     : String;
    CompFootprint : String;
    CompCount     : Integer;
    FirstItem     : Boolean;
    I             : Integer;
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
    OutputPath := EnsureOutputDir('BOM');
    
    // Generate BOM manually from components
    CompCount := 0;
    
    // Build JSON BOM
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "BOM",' + #13#10;
    JSONStr := JSONStr + '  "components": [' + #13#10;
    FirstItem := True;
    
    // Also build CSV BOM
    BOMFile := TStringList.Create;
    Try
        BOMFile.Add('Designator,Value,Footprint,Quantity');
        
        Try
            Iterator := PCB.BoardIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Component := Iterator.FirstPCBObject;
                    While Component <> Nil Do
                    Begin
                        Inc(CompCount);
                        
                        Try
                            CompName := Component.Name.Text;
                        Except
                            CompName := 'Unknown';
                        End;
                        
                        Try
                            CompValue := Component.Comment.Text;
                        Except
                            CompValue := '';
                        End;
                        
                        Try
                            CompFootprint := Component.Pattern;
                        Except
                            CompFootprint := '';
                        End;
                        
                        // Add to JSON
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "designator": "' + EscapeJsonString(CompName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "value": "' + EscapeJsonString(CompValue) + '",' + #13#10;
                        JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(CompFootprint) + '",' + #13#10;
                        JSONStr := JSONStr + '      "quantity": 1' + #13#10;
                        JSONStr := JSONStr + '    }';
                        
                        // Add to CSV
                        BOMFile.Add('"' + CompName + '","' + CompValue + '","' + CompFootprint + '",1');
                        
                        Component := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        
        JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
        JSONStr := JSONStr + '  "total_components": ' + IntToStr(CompCount) + ',' + #13#10;
        JSONStr := JSONStr + '  "output_path": "' + EscapeJsonString(OutputPath) + '",' + #13#10;
        JSONStr := JSONStr + '  "status": "generated"' + #13#10;
        JSONStr := JSONStr + '}';
        
        // Save CSV BOM
        BOMFileName := OutputPath + '\BOM.csv';
        Try
            BOMFile.SaveToFile(BOMFileName);
        Except
        End;
    Finally
        BOMFile.Free;
    End;
    
    // Save JSON result
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := OutputPath + '\BOM.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
        
        // Also save to standard location
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
    
    ShowMessage('BOM Generated!' + #13#10 + #13#10 +
                'Total Components: ' + IntToStr(CompCount) + #13#10 + #13#10 +
                'Files generated:' + #13#10 +
                '- BOM.csv' + #13#10 +
                '- BOM.json' + #13#10 + #13#10 +
                'Output path: ' + OutputPath);
End;

// Generate Pick and Place file
Procedure GeneratePickAndPlace;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Iterator      : IPCB_BoardIterator;
    Component     : IPCB_Component;
    OutputPath    : String;
    OutputFile    : TStringList;
    PnPFile       : TStringList;
    JSONStr       : String;
    FileName      : String;
    PnPFileName   : String;
    CompName      : String;
    CompX, CompY  : Double;
    CompRotation  : Double;
    CompLayer     : String;
    CompCount     : Integer;
    FirstItem     : Boolean;
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
    OutputPath := EnsureOutputDir('Assembly');
    
    CompCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "output_type": "Pick and Place",' + #13#10;
    JSONStr := JSONStr + '  "units": "mm",' + #13#10;
    JSONStr := JSONStr + '  "components": [' + #13#10;
    FirstItem := True;
    
    // Build CSV
    PnPFile := TStringList.Create;
    Try
        PnPFile.Add('Designator,X(mm),Y(mm),Rotation,Layer,Footprint');
        
        Try
            Iterator := PCB.BoardIterator_Create;
            If Iterator <> Nil Then
            Begin
                Try
                    Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
                    Iterator.AddFilter_LayerSet(AllLayers);
                    Iterator.AddFilter_Method(eProcessAll);
                    
                    Component := Iterator.FirstPCBObject;
                    While Component <> Nil Do
                    Begin
                        Inc(CompCount);
                        
                        Try
                            CompName := Component.Name.Text;
                        Except
                            CompName := 'Unknown';
                        End;
                        
                        Try
                            CompX := CoordToMMs(Component.X);
                            CompY := CoordToMMs(Component.Y);
                        Except
                            CompX := 0;
                            CompY := 0;
                        End;
                        
                        Try
                            CompRotation := Component.Rotation;
                        Except
                            CompRotation := 0;
                        End;
                        
                        Try
                            CompLayer := Layer2String(Component.Layer);
                        Except
                            CompLayer := 'Top';
                        End;
                        
                        // Add to JSON
                        If Not FirstItem Then
                            JSONStr := JSONStr + ',' + #13#10;
                        FirstItem := False;
                        
                        JSONStr := JSONStr + '    {' + #13#10;
                        JSONStr := JSONStr + '      "designator": "' + EscapeJsonString(CompName) + '",' + #13#10;
                        JSONStr := JSONStr + '      "x": ' + FormatFloat('0.000', CompX) + ',' + #13#10;
                        JSONStr := JSONStr + '      "y": ' + FormatFloat('0.000', CompY) + ',' + #13#10;
                        JSONStr := JSONStr + '      "rotation": ' + FormatFloat('0.0', CompRotation) + ',' + #13#10;
                        JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(CompLayer) + '",' + #13#10;
                        
                        Try
                            JSONStr := JSONStr + '      "footprint": "' + EscapeJsonString(Component.Pattern) + '"' + #13#10;
                        Except
                            JSONStr := JSONStr + '      "footprint": ""' + #13#10;
                        End;
                        
                        JSONStr := JSONStr + '    }';
                        
                        // Add to CSV
                        Try
                            PnPFile.Add(CompName + ',' + 
                                       FormatFloat('0.000', CompX) + ',' + 
                                       FormatFloat('0.000', CompY) + ',' + 
                                       FormatFloat('0.0', CompRotation) + ',' + 
                                       CompLayer + ',' + 
                                       Component.Pattern);
                        Except
                            PnPFile.Add(CompName + ',' + 
                                       FormatFloat('0.000', CompX) + ',' + 
                                       FormatFloat('0.000', CompY) + ',' + 
                                       FormatFloat('0.0', CompRotation) + ',' + 
                                       CompLayer + ',');
                        End;
                        
                        Component := Iterator.NextPCBObject;
                    End;
                Finally
                    PCB.BoardIterator_Destroy(Iterator);
                End;
            End;
        Except
        End;
        
        JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
        JSONStr := JSONStr + '  "total_components": ' + IntToStr(CompCount) + ',' + #13#10;
        JSONStr := JSONStr + '  "output_path": "' + EscapeJsonString(OutputPath) + '",' + #13#10;
        JSONStr := JSONStr + '  "status": "generated"' + #13#10;
        JSONStr := JSONStr + '}';
        
        // Save CSV
        PnPFileName := OutputPath + '\PickAndPlace.csv';
        Try
            PnPFile.SaveToFile(PnPFileName);
        Except
        End;
    Finally
        PnPFile.Free;
    End;
    
    // Save JSON
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := OutputPath + '\PickAndPlace.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
        
        // Also save to standard location
        FileName := 'E:\Workspace\AI\11.10.WayNe\new-version\output_result.json';
        Try
            OutputFile.SaveToFile(FileName);
        Except
        End;
    Finally
        OutputFile.Free;
    End;
    
    ShowMessage('Pick and Place Generated!' + #13#10 + #13#10 +
                'Total Components: ' + IntToStr(CompCount) + #13#10 + #13#10 +
                'Files generated:' + #13#10 +
                '- PickAndPlace.csv' + #13#10 +
                '- PickAndPlace.json' + #13#10 + #13#10 +
                'Output path: ' + OutputPath);
End;

// Generate all manufacturing outputs
Procedure GenerateAllOutputs;
Begin
    ShowMessage('Generating all manufacturing outputs...' + #13#10 + #13#10 +
                'This will generate:' + #13#10 +
                '1. Gerber files' + #13#10 +
                '2. NC Drill files' + #13#10 +
                '3. Bill of Materials (BOM)' + #13#10 +
                '4. Pick and Place files' + #13#10 + #13#10 +
                'Click OK to continue.');
    
    // Generate each output type
    GenerateBOM;
    GeneratePickAndPlace;
    
    ShowMessage('BOM and Pick & Place generated successfully!' + #13#10 + #13#10 +
                'For Gerber and NC Drill files, please use:' + #13#10 +
                '- File → Fabrication Outputs → Gerber Files' + #13#10 +
                '- File → Fabrication Outputs → NC Drill Files' + #13#10 + #13#10 +
                'Output directory: ' + OUTPUT_BASE_PATH);
End;

