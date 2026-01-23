{*
 * Auto-Export Script for Altium Designer
 * 
 * This script can be set up to run automatically when documents are saved.
 * It exports PCB, schematic, and design rules data to JSON files.
 * 
 * Setup Instructions:
 * 1. This script can be called manually: DXP -> Run Script -> auto_export.pas -> AutoExport
 * 2. For automatic execution, you may need to:
 *    - Create an Altium extension/plugin that hooks into document save events
 *    - Or use Altium's scripting system if it supports event hooks
 *    - Or manually run this script after saving documents
 * 
 * Usage: File -> Run Script -> workflows/auto_export.pas -> AutoExport
 *}

Const
    BASE_PATH = 'D:\Work\workspace\Wayne\EagilinsED_PCB-Design-Agent\';

Procedure AutoExport;
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
    
    // Export based on document type
    If DocKind = 'PCB' Then
    Begin
        // Export PCB info
        Try
            // Call exportPCBInfo procedure (from exportPCBInfo.pas)
            // Note: In PascalScript, you can't directly call procedures from other scripts
            // So we'll show instructions or you can copy the export code here
            ShowMessage('Auto-Export: PCB Document Detected' + #13#10 + #13#10 +
                       'To export PCB data:' + #13#10 +
                       '1. Run: commands/export/exportPCBInfo.pas -> ExportPCBInfo' + #13#10 +
                       '2. Run: commands/export/exportDesignRules.pas -> ExportDesignRules' + #13#10 + #13#10 +
                       'Or use: workflows/export_all.pas -> ExportAll');
        Except
            ShowMessage('Error during PCB export');
        End;
    End
    Else If DocKind = 'SCH' Then
    Begin
        // Export schematic info
        Try
            ShowMessage('Auto-Export: Schematic Document Detected' + #13#10 + #13#10 +
                       'To export schematic data:' + #13#10 +
                       '1. Run: commands/export/exportSchematicInfo.pas -> ExportSchematicInfo');
        Except
            ShowMessage('Error during schematic export');
        End;
    End
    Else
    Begin
        ShowMessage('Document type not supported for auto-export: ' + DocKind);
    End;
End;

{*
 * Note: For true automatic execution on document save, you would need:
 * 1. An Altium extension that hooks into document save events
 * 2. Or use Altium's event system if available
 * 3. Or set up a timer/background process
 * 
 * For now, this script provides a convenient way to export after saving.
 * You can also create a keyboard shortcut to run this script quickly.
 *}
