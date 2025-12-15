{*
 * Altium Designer Script - PCB Drawing Operations
 * Compatible with Altium Designer 25.5.2
 * 
 * Features:
 * - Add text to silkscreen or other layers
 * - Add lines and graphics
 * - Add dimensions
 * - Export existing drawings/text
 * 
 * TO RUN THIS SCRIPT:
 * 1. Open a PCB document
 * 2. In Altium Designer, go to: File -> Run Script
 * 3. Select this file: altium_pcb_drawing.pas
 * 4. When dialog appears, select the procedure you want to run
 * 5. Click OK
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

// Get layer ID from name
Function GetLayerFromName(LayerName: String): TLayer;
Begin
    Result := eTopOverlay;  // Default
    LayerName := LowerCase(LayerName);
    
    If Pos('top overlay', LayerName) > 0 Then
        Result := eTopOverlay
    Else If Pos('bottom overlay', LayerName) > 0 Then
        Result := eBottomOverlay
    Else If Pos('top', LayerName) > 0 Then
        Result := eTopLayer
    Else If Pos('bottom', LayerName) > 0 Then
        Result := eBottomLayer
    Else If Pos('mechanical 1', LayerName) > 0 Then
        Result := eMechanical1
    Else If Pos('mechanical 2', LayerName) > 0 Then
        Result := eMechanical2
    Else If Pos('keep', LayerName) > 0 Then
        Result := eKeepOutLayer;
End;

// Add text to PCB
Procedure AddTextToPCB;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Text          : IPCB_Text;
    TextStr       : String;
    XStr, YStr    : String;
    HeightStr     : String;
    LayerStr      : String;
    X, Y, Height  : Double;
    Layer         : TLayer;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
    Except
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    // Get text from user
    TextStr := InputBox('Add Text to PCB', 'Enter text:', 'Sample Text');
    If TextStr = '' Then Exit;
    
    // Get position
    XStr := InputBox('Add Text to PCB', 'X position (mm):', '50');
    If XStr = '' Then Exit;
    
    YStr := InputBox('Add Text to PCB', 'Y position (mm):', '50');
    If YStr = '' Then Exit;
    
    // Get height
    HeightStr := InputBox('Add Text to PCB', 'Text height (mm):', '1.5');
    If HeightStr = '' Then HeightStr := '1.5';
    
    // Get layer
    LayerStr := InputBox('Add Text to PCB', 
                         'Layer (Top Overlay, Bottom Overlay, Mechanical 1):', 
                         'Top Overlay');
    If LayerStr = '' Then LayerStr := 'Top Overlay';
    
    // Parse values
    Try
        X := StrToFloat(XStr);
        Y := StrToFloat(YStr);
        Height := StrToFloat(HeightStr);
    Except
        ShowMessage('ERROR: Invalid numeric values');
        Exit;
    End;
    
    Layer := GetLayerFromName(LayerStr);
    
    // Create text
    Try
        PCBServer.PreProcess;
        
        Text := PCBServer.PCBObjectFactory(eTextObject, eNoDimension, eCreate_Default);
        If Text <> Nil Then
        Begin
            Text.XLocation := MMsToCoord(X);
            Text.YLocation := MMsToCoord(Y);
            Text.Layer := Layer;
            Text.Size := MMsToCoord(Height);
            Text.Width := MMsToCoord(Height * 0.15);  // 15% of height
            Text.Text := TextStr;
            Text.UseTTFonts := False;
            
            PCB.AddPCBObject(Text);
        End;
        
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        
        ShowMessage('Text added successfully!' + #13#10 + #13#10 +
                    'Text: "' + TextStr + '"' + #13#10 +
                    'Position: (' + XStr + ', ' + YStr + ') mm' + #13#10 +
                    'Layer: ' + LayerStr);
    Except
        ShowMessage('ERROR: Failed to add text');
    End;
End;

// Add line to PCB
Procedure AddLineToPCB;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Track         : IPCB_Track;
    X1Str, Y1Str  : String;
    X2Str, Y2Str  : String;
    WidthStr      : String;
    LayerStr      : String;
    X1, Y1, X2, Y2: Double;
    Width         : Double;
    Layer         : TLayer;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
    Except
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    // Get start position
    X1Str := InputBox('Add Line to PCB', 'Start X (mm):', '10');
    If X1Str = '' Then Exit;
    
    Y1Str := InputBox('Add Line to PCB', 'Start Y (mm):', '10');
    If Y1Str = '' Then Exit;
    
    // Get end position
    X2Str := InputBox('Add Line to PCB', 'End X (mm):', '50');
    If X2Str = '' Then Exit;
    
    Y2Str := InputBox('Add Line to PCB', 'End Y (mm):', '10');
    If Y2Str = '' Then Exit;
    
    // Get width
    WidthStr := InputBox('Add Line to PCB', 'Line width (mm):', '0.2');
    If WidthStr = '' Then WidthStr := '0.2';
    
    // Get layer
    LayerStr := InputBox('Add Line to PCB', 
                         'Layer (Top Overlay, Mechanical 1, Top, Bottom):', 
                         'Top Overlay');
    If LayerStr = '' Then LayerStr := 'Top Overlay';
    
    // Parse values
    Try
        X1 := StrToFloat(X1Str);
        Y1 := StrToFloat(Y1Str);
        X2 := StrToFloat(X2Str);
        Y2 := StrToFloat(Y2Str);
        Width := StrToFloat(WidthStr);
    Except
        ShowMessage('ERROR: Invalid numeric values');
        Exit;
    End;
    
    Layer := GetLayerFromName(LayerStr);
    
    // Create line (track)
    Try
        PCBServer.PreProcess;
        
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        If Track <> Nil Then
        Begin
            Track.X1 := MMsToCoord(X1);
            Track.Y1 := MMsToCoord(Y1);
            Track.X2 := MMsToCoord(X2);
            Track.Y2 := MMsToCoord(Y2);
            Track.Width := MMsToCoord(Width);
            Track.Layer := Layer;
            
            PCB.AddPCBObject(Track);
        End;
        
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        
        ShowMessage('Line added successfully!' + #13#10 + #13#10 +
                    'From: (' + X1Str + ', ' + Y1Str + ') mm' + #13#10 +
                    'To: (' + X2Str + ', ' + Y2Str + ') mm' + #13#10 +
                    'Layer: ' + LayerStr);
    Except
        ShowMessage('ERROR: Failed to add line');
    End;
End;

// Export all text objects on the board
Procedure ExportTextObjects;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Text          : IPCB_Text;
    Iterator      : IPCB_BoardIterator;
    OutputFile    : TStringList;
    FileName      : String;
    JSONStr       : String;
    FirstItem     : Boolean;
    TextCount     : Integer;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
    Except
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    TextCount := 0;
    
    // Build JSON
    JSONStr := '{' + #13#10;
    JSONStr := JSONStr + '  "text_objects": [' + #13#10;
    FirstItem := True;
    
    Try
        Iterator := PCB.BoardIterator_Create;
        If Iterator <> Nil Then
        Begin
            Try
                Iterator.AddFilter_ObjectSet(MkSet(eTextObject));
                Iterator.AddFilter_LayerSet(AllLayers);
                Iterator.AddFilter_Method(eProcessAll);
                
                Text := Iterator.FirstPCBObject;
                While Text <> Nil Do
                Begin
                    Inc(TextCount);
                    
                    If Not FirstItem Then
                        JSONStr := JSONStr + ',' + #13#10;
                    FirstItem := False;
                    
                    JSONStr := JSONStr + '    {' + #13#10;
                    
                    Try
                        JSONStr := JSONStr + '      "text": "' + EscapeJsonString(Text.Text) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "text": "",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "x_mm": ' + FormatFloat('0.00', CoordToMMs(Text.XLocation)) + ',' + #13#10;
                        JSONStr := JSONStr + '      "y_mm": ' + FormatFloat('0.00', CoordToMMs(Text.YLocation)) + ',' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "x_mm": 0,' + #13#10;
                        JSONStr := JSONStr + '      "y_mm": 0,' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "height_mm": ' + FormatFloat('0.00', CoordToMMs(Text.Size)) + ',' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "height_mm": 1,' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "layer": "' + EscapeJsonString(Layer2String(Text.Layer)) + '",' + #13#10;
                    Except
                        JSONStr := JSONStr + '      "layer": "Unknown",' + #13#10;
                    End;
                    
                    Try
                        JSONStr := JSONStr + '      "rotation": ' + FormatFloat('0.0', Text.Rotation) + #13#10;
                    Except
                        JSONStr := JSONStr + '      "rotation": 0' + #13#10;
                    End;
                    
                    JSONStr := JSONStr + '    }';
                    
                    Text := Iterator.NextPCBObject;
                End;
            Finally
                PCB.BoardIterator_Destroy(Iterator);
            End;
        End;
    Except
    End;
    
    JSONStr := JSONStr + #13#10 + '  ],' + #13#10;
    JSONStr := JSONStr + '  "text_count": ' + IntToStr(TextCount) + ',' + #13#10;
    JSONStr := JSONStr + '  "status": "success"' + #13#10;
    JSONStr := JSONStr + '}';
    
    // Write to file
    OutputFile := TStringList.Create;
    Try
        OutputFile.Text := JSONStr;
        FileName := BASE_PATH + 'text_objects.json';
        
        Try
            OutputFile.SaveToFile(FileName);
            ShowMessage('Text Objects Exported!' + #13#10 + #13#10 +
                        'Count: ' + IntToStr(TextCount) + #13#10 + #13#10 +
                        'Saved to: ' + FileName);
        Except
            ShowMessage('ERROR: Could not save file');
        End;
    Finally
        OutputFile.Free;
    End;
End;

// Add rectangle (4 lines) to PCB
Procedure AddRectangleToPCB;
Var
    PCB           : IPCB_Board;
    Workspace     : IWorkspace;
    Doc           : IDocument;
    Track         : IPCB_Track;
    XStr, YStr    : String;
    WStr, HStr    : String;
    WidthStr      : String;
    LayerStr      : String;
    X, Y, W, H    : Double;
    LineWidth     : Double;
    Layer         : TLayer;
Begin
    // Get workspace
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
    Except
        Exit;
    End;
    
    // Get PCB board
    PCB := Nil;
    Try
        PCB := PCBServer.GetCurrentPCBBoard;
    Except
    End;
    
    If PCB = Nil Then
    Begin
        ShowMessage('ERROR: No PCB document is open.');
        Exit;
    End;
    
    // Get corner position
    XStr := InputBox('Add Rectangle', 'Lower-left X (mm):', '10');
    If XStr = '' Then Exit;
    
    YStr := InputBox('Add Rectangle', 'Lower-left Y (mm):', '10');
    If YStr = '' Then Exit;
    
    // Get size
    WStr := InputBox('Add Rectangle', 'Width (mm):', '20');
    If WStr = '' Then Exit;
    
    HStr := InputBox('Add Rectangle', 'Height (mm):', '15');
    If HStr = '' Then Exit;
    
    // Get line width
    WidthStr := InputBox('Add Rectangle', 'Line width (mm):', '0.2');
    If WidthStr = '' Then WidthStr := '0.2';
    
    // Get layer
    LayerStr := InputBox('Add Rectangle', 'Layer:', 'Top Overlay');
    If LayerStr = '' Then LayerStr := 'Top Overlay';
    
    // Parse values
    Try
        X := StrToFloat(XStr);
        Y := StrToFloat(YStr);
        W := StrToFloat(WStr);
        H := StrToFloat(HStr);
        LineWidth := StrToFloat(WidthStr);
    Except
        ShowMessage('ERROR: Invalid numeric values');
        Exit;
    End;
    
    Layer := GetLayerFromName(LayerStr);
    
    // Create rectangle (4 tracks)
    Try
        PCBServer.PreProcess;
        
        // Bottom line
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.X1 := MMsToCoord(X);
        Track.Y1 := MMsToCoord(Y);
        Track.X2 := MMsToCoord(X + W);
        Track.Y2 := MMsToCoord(Y);
        Track.Width := MMsToCoord(LineWidth);
        Track.Layer := Layer;
        PCB.AddPCBObject(Track);
        
        // Right line
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.X1 := MMsToCoord(X + W);
        Track.Y1 := MMsToCoord(Y);
        Track.X2 := MMsToCoord(X + W);
        Track.Y2 := MMsToCoord(Y + H);
        Track.Width := MMsToCoord(LineWidth);
        Track.Layer := Layer;
        PCB.AddPCBObject(Track);
        
        // Top line
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.X1 := MMsToCoord(X + W);
        Track.Y1 := MMsToCoord(Y + H);
        Track.X2 := MMsToCoord(X);
        Track.Y2 := MMsToCoord(Y + H);
        Track.Width := MMsToCoord(LineWidth);
        Track.Layer := Layer;
        PCB.AddPCBObject(Track);
        
        // Left line
        Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
        Track.X1 := MMsToCoord(X);
        Track.Y1 := MMsToCoord(Y + H);
        Track.X2 := MMsToCoord(X);
        Track.Y2 := MMsToCoord(Y);
        Track.Width := MMsToCoord(LineWidth);
        Track.Layer := Layer;
        PCB.AddPCBObject(Track);
        
        PCBServer.PostProcess;
        PCB.ViewManager_FullUpdate;
        
        ShowMessage('Rectangle added successfully!' + #13#10 + #13#10 +
                    'Position: (' + XStr + ', ' + YStr + ') mm' + #13#10 +
                    'Size: ' + WStr + ' x ' + HStr + ' mm' + #13#10 +
                    'Layer: ' + LayerStr);
    Except
        ShowMessage('ERROR: Failed to add rectangle');
    End;
End;


