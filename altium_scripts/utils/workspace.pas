{*
 * Workspace Utilities
 * Get workspace, PCB, schematic interfaces
 *}

// Get workspace interface
Function GetWorkspace: IWorkspace;
Begin
    Result := GetWorkSpace;
End;

// Get current PCB board
Function GetCurrentPCB: IPCB_Board;
Var
    Workspace: IWorkspace;
    Doc: IDocument;
Begin
    Result := Nil;
    Try
        Workspace := GetWorkspace;
        If Workspace = Nil Then Exit;
        
        Doc := Workspace.DM_FocusedDocument;
        If (Doc <> Nil) And (Doc.DM_DocumentKind = 'PCB') Then
        Begin
            Result := PCBServer.GetCurrentPCBBoard;
        End;
    Except
    End;
End;

// Get current schematic document
Function GetCurrentSchematic: ISch_Document;
Var
    Workspace: IWorkspace;
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
            Workspace := GetWorkspace;
            If Workspace <> Nil Then
            Begin
                Doc := Workspace.DM_FocusedDocument;
                If (Doc <> Nil) And (Doc.DM_DocumentKind = 'SCH') Then
                Begin
                    Result := SchServer.GetSchDocumentByPath(Doc.DM_FullPath);
                End;
            End;
        Except
        End;
    End;
End;

// Find component by name in PCB
Function FindComponent(PCB: IPCB_Board; CompName: String): IPCB_Component;
Var
    Iterator: IPCB_BoardIterator;
    Component: IPCB_Component;
Begin
    Result := Nil;
    Try
        Iterator := PCB.BoardIterator_Create;
        Try
            Iterator.AddFilter_ObjectSet(MkSet(eComponentObject));
            Iterator.AddFilter_LayerSet(AllLayers);
            Iterator.AddFilter_Method(eProcessAll);
            
            Component := Iterator.FirstPCBObject;
            While Component <> Nil Do
            Begin
                If (Component.Name.Text = CompName) Or
                   (LowerCase(Component.Name.Text) = LowerCase(CompName)) Then
                Begin
                    Result := Component;
                    Break;
                End;
                Component := Iterator.NextPCBObject;
            End;
        Finally
            PCB.BoardIterator_Destroy(Iterator);
        End;
    Except
    End;
End;

