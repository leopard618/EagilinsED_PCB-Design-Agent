{*
 * Altium Designer Script - EagilinsED Master Controller
 * Compatible with Altium Designer 25.5.2
 * 
 * ONE SCRIPT TO RULE THEM ALL!
 * This provides a single menu to access all EagilinsED functions.
 * 
 * QUICK ACCESS:
 * 1. File → Run Script (or use Ctrl+Shift+X if configured)
 * 2. Select "altium_master.pas"
 * 3. Choose "ShowMainMenu"
 * 4. Pick your action from the menu
 *}

Uses
    SysUtils;

Const
    BASE_PATH = 'E:\Workspace\AI\11.10.WayNe\new-version\';

Var
    GlobalPCB: IPCB_Board;
    GlobalSchematic: ISch_Document;
    GlobalWorkspace: IWorkspace;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

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

Function InitializeWorkspace: Boolean;
Begin
    Result := False;
    Try
        GlobalWorkspace := GetWorkspace;
        If GlobalWorkspace <> Nil Then
            Result := True;
    Except
    End;
End;

Function GetCurrentPCB: IPCB_Board;
Var
    Doc: IDocument;
Begin
    Result := Nil;
    Try
        Result := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If Result = Nil Then
    Begin
        Try
            If GlobalWorkspace <> Nil Then
            Begin
                Doc := GlobalWorkspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'PCB') Then
                    Result := PCBServer.GetPCBBoardByPath(Doc.DM_FullPath);
            End;
        Except
        End;
    End;
    GlobalPCB := Result;
End;

Function GetCurrentSchematic: ISch_Document;
Var
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
            If GlobalWorkspace <> Nil Then
            Begin
                Doc := GlobalWorkspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'SCH') Then
                    Result := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
            End;
        Except
        End;
    End;
    GlobalSchematic := Result;
End;

// ============================================================================
// QUICK ACTIONS - These are the main entry points
// ============================================================================

// Export PCB info for EagilinsED
Procedure QuickExportPCB;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    If GetCurrentPCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.' + #13#10 +
                    'Please open a PCB file first.');
        Exit;
    End;
    
    // Call the export procedure from altium_export_pcb_info.pas
    RunProcess('ScriptingSystem:RunScriptText', 'Text=Uses altium_export_pcb_info; Begin ExportPCBInfo; End;');
    
    // Since RunProcess may not work, do it inline
    ShowMessage('Please run altium_export_pcb_info.pas → ExportPCBInfo' + #13#10 +
                'to export PCB information.');
End;

// Execute pending commands from EagilinsED
Procedure QuickExecuteCommands;
Var
    CommandFile: TStringList;
    FileName, Content: String;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    If GetCurrentPCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.' + #13#10 +
                    'Please open a PCB file first.');
        Exit;
    End;
    
    // Check if there are commands to execute
    FileName := BASE_PATH + 'pcb_commands.json';
    CommandFile := TStringList.Create;
    Try
        Try
            CommandFile.LoadFromFile(FileName);
            Content := CommandFile.Text;
            
            If (Length(Content) < 10) Or (Pos('[]', Content) > 0) Then
            Begin
                ShowMessage('No commands to execute.' + #13#10 + #13#10 +
                            'Use EagilinsED to queue commands first.');
                Exit;
            End;
            
            ShowMessage('Commands found! Running execution...' + #13#10 + #13#10 +
                        'Please run altium_execute_commands.pas → ExecuteCommands');
        Except
            ShowMessage('No command file found at:' + #13#10 + FileName);
        End;
    Finally
        CommandFile.Free;
    End;
End;

// Export Schematic info for EagilinsED
Procedure QuickExportSchematic;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    If GetCurrentSchematic = Nil Then
    Begin
        ShowMessage('ERROR: No Schematic document is open.' + #13#10 +
                    'Please open a Schematic file first.');
        Exit;
    End;
    
    ShowMessage('Please run altium_export_schematic_info.pas → ExportSchematicInfo' + #13#10 +
                'to export schematic information.');
End;

// Run DRC
Procedure QuickRunDRC;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    If GetCurrentPCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    ShowMessage('Please run altium_verification.pas → RunDRCAndExport' + #13#10 +
                'to run Design Rule Check.');
End;

// Generate BOM
Procedure QuickGenerateBOM;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    If GetCurrentPCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    ShowMessage('Please run altium_output_generator.pas → GenerateBOM' + #13#10 +
                'to generate Bill of Materials.');
End;

// ============================================================================
// MAIN MENU
// ============================================================================

Procedure ShowMainMenu;
Var
    Choice: String;
    DocType: String;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access Altium workspace.' + #13#10 +
                    'Please make sure a project is open.');
        Exit;
    End;
    
    // Detect current document type
    DocType := 'Unknown';
    If GetCurrentPCB <> Nil Then
        DocType := 'PCB'
    Else If GetCurrentSchematic <> Nil Then
        DocType := 'Schematic';
    
    Choice := InputBox('EagilinsED - Quick Actions',
        'Current Document: ' + DocType + #13#10 + #13#10 +
        'Enter number to execute:' + #13#10 + #13#10 +
        '--- EXPORT DATA ---' + #13#10 +
        '1 - Export PCB Info' + #13#10 +
        '2 - Export Schematic Info' + #13#10 +
        '3 - Export Project Info' + #13#10 + #13#10 +
        '--- EXECUTE ---' + #13#10 +
        '4 - Execute Pending Commands' + #13#10 + #13#10 +
        '--- VERIFY ---' + #13#10 +
        '5 - Run DRC (Design Rule Check)' + #13#10 +
        '6 - Run ERC (Electrical Rule Check)' + #13#10 +
        '7 - Check Connectivity' + #13#10 + #13#10 +
        '--- OUTPUTS ---' + #13#10 +
        '8 - Generate BOM' + #13#10 +
        '9 - Generate Pick & Place' + #13#10 + #13#10 +
        '0 - Cancel',
        '');
    
    If Choice = '' Then Exit;
    If Choice = '0' Then Exit;
    
    Case StrToIntDef(Choice, 0) Of
        1: ShowMessage('Run: File → Run Script → altium_export_pcb_info.pas → ExportPCBInfo');
        2: ShowMessage('Run: File → Run Script → altium_export_schematic_info.pas → ExportSchematicInfo');
        3: ShowMessage('Run: File → Run Script → altium_project_manager.pas → ExportProjectInfo');
        4: ShowMessage('Run: File → Run Script → altium_execute_commands.pas → ExecuteCommands');
        5: ShowMessage('Run: File → Run Script → altium_verification.pas → RunDRCAndExport');
        6: ShowMessage('Run: File → Run Script → altium_verification.pas → RunERCAndExport');
        7: ShowMessage('Run: File → Run Script → altium_verification.pas → CheckConnectivityAndExport');
        8: ShowMessage('Run: File → Run Script → altium_output_generator.pas → GenerateBOM');
        9: ShowMessage('Run: File → Run Script → altium_output_generator.pas → GeneratePickAndPlace');
    Else
        ShowMessage('Invalid choice. Please enter a number 0-9.');
    End;
End;

// Quick status check
Procedure CheckStatus;
Var
    StatusMsg: String;
    PCB: IPCB_Board;
    Sch: ISch_Document;
    Project: IProject;
Begin
    If Not InitializeWorkspace Then
    Begin
        ShowMessage('ERROR: Cannot access workspace');
        Exit;
    End;
    
    StatusMsg := '=== EagilinsED Status ===' + #13#10 + #13#10;
    
    // Workspace
    StatusMsg := StatusMsg + '✓ Workspace: Connected' + #13#10;
    
    // Project
    Try
        Project := GlobalWorkspace.DM_FocusedProject;
        If Project <> Nil Then
            StatusMsg := StatusMsg + '✓ Project: ' + Project.DM_ProjectFileName + #13#10
        Else
            StatusMsg := StatusMsg + '✗ Project: None' + #13#10;
    Except
        StatusMsg := StatusMsg + '✗ Project: Error' + #13#10;
    End;
    
    // PCB
    PCB := GetCurrentPCB;
    If PCB <> Nil Then
        StatusMsg := StatusMsg + '✓ PCB: ' + ExtractFileName(PCB.FileName) + #13#10
    Else
        StatusMsg := StatusMsg + '- PCB: Not active' + #13#10;
    
    // Schematic
    Sch := GetCurrentSchematic;
    If Sch <> Nil Then
        StatusMsg := StatusMsg + '✓ Schematic: ' + Sch.DocumentName + #13#10
    Else
        StatusMsg := StatusMsg + '- Schematic: Not active' + #13#10;
    
    // File paths
    StatusMsg := StatusMsg + #13#10 + '=== File Paths ===' + #13#10;
    StatusMsg := StatusMsg + 'Base: ' + BASE_PATH + #13#10;
    
    ShowMessage(StatusMsg);
End;


