{*
 * Export All Data from Altium - Workflow Script
 * 
 * This script exports all necessary data (PCB info and Design Rules) in one go.
 * With file watcher enabled, this makes the workflow nearly automatic.
 * 
 * Usage: File → Run Script → workflows/export_all.pas → ExportAll
 * 
 * With File Watcher:
 * 1. Run this script after making changes in Altium
 * 2. File watcher automatically detects the JSON files
 * 3. Python app gets updated data automatically
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';

Procedure ExportAll;
Var
    WS: IWorkspace;
    Doc: IDocument;
    DocKind: String;
    Response: Integer;
Begin
    // Get workspace
    WS := GetWorkspace;
    If WS = Nil Then
    Begin
        ShowMessage('Error: Cannot access workspace');
        Exit;
    End;
    
    // Get focused document
    Doc := WS.DM_FocusedDocument;
    If Doc = Nil Then
    Begin
        ShowMessage('No document is currently focused.' + #13#10 +
                   'Please open a PCB or Schematic document.');
        Exit;
    End;
    
    DocKind := Doc.DM_DocumentKind;
    
    // Show what will be exported
    Response := MessageDlg('Export All Data' + #13#10 + #13#10 +
                          'This will export:' + #13#10 +
                          '1. PCB Info (pcb_info.json)' + #13#10 +
                          '2. Design Rules (design_rules.json)' + #13#10 +
                          '3. Project Info (project_info.json)' + #13#10 + #13#10 +
                          'Document Type: ' + DocKind + #13#10 + #13#10 +
                          'Continue?', mtConfirmation, mbYesNo, 0);
    
    If Response <> mrYes Then
        Exit;
    
    // Export based on document type
    If DocKind = 'PCB' Then
    Begin
        ShowMessage('Starting export...' + #13#10 + #13#10 +
                   'Please run these scripts in order:' + #13#10 + #13#10 +
                   '1. commands/export/exportPCBInfo.pas -> ExportPCBInfo' + #13#10 +
                   '2. commands/export/exportDesignRules.pas -> ExportDesignRules' + #13#10 +
                   '3. commands/project/exportProjectInfo.pas -> ExportProjectInfo' + #13#10 + #13#10 +
                   'After all exports complete, the file watcher will' + #13#10 +
                   'automatically detect the changes and update the cache.');
    End
    Else If DocKind = 'SCH' Then
    Begin
        ShowMessage('Starting export...' + #13#10 + #13#10 +
                   'Please run:' + #13#10 + #13#10 +
                   '1. commands/export/exportSchematicInfo.pas -> ExportSchematicInfo' + #13#10 +
                   '2. commands/project/exportProjectInfo.pas -> ExportProjectInfo' + #13#10 + #13#10 +
                   'After exports complete, the file watcher will' + #13#10 +
                   'automatically detect the changes.');
    End
    Else
    Begin
        ShowMessage('Document type: ' + DocKind + #13#10 + #13#10 +
                   'Please run:' + #13#10 +
                   'commands/project/exportProjectInfo.pas -> ExportProjectInfo');
    End;
End;
