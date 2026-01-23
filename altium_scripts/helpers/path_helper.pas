// Path Helper - Auto-detect BASE_PATH
// This eliminates the need for manual BASE_PATH configuration

Function GetBasePath: String;
Var
  ScriptPath: String;
  ProjectPath: String;
  BaseDir: String;
Begin
  Try
    // Get the path of the currently running script
    ScriptPath := GetRunningScriptProjectPath;
    
    // Script is typically in: ...\EagilinsED_PCB-Design-Agent\altium_scripts\...
    // We need: ...\EagilinsED_PCB-Design-Agent\
    
    // Go up directories until we find the project root
    BaseDir := ExtractFilePath(ScriptPath);
    
    // Remove altium_scripts\ and any subdirectories
    While (Pos('altium_scripts', BaseDir) > 0) Do
    Begin
      BaseDir := ExtractFilePath(ExcludeTrailingPathDelimiter(BaseDir));
    End;
    
    // Ensure it ends with backslash
    If BaseDir[Length(BaseDir)] <> '\' Then
      BaseDir := BaseDir + '\';
    
    Result := BaseDir;
  Except
    // Fallback: Use current directory
    Result := GetCurrentDir + '\';
  End;
End;

Function GetDataPath(FileName: String): String;
Begin
  Result := GetBasePath + FileName;
End;
