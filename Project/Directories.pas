{$INCLUDE switches}

unit Directories;

interface

var
HomeDir, DataDir: string;

function LocalizedFilePath(path: string): string;


implementation

uses
ShlObj,Windows,SysUtils;

function GetSpecialDirectory(const CSIDL: integer): string;
var
RecPath: PChar;
begin
RecPath:=StrAlloc(MAX_PATH);
try
  FillChar(RecPath^, MAX_PATH, 0);
  if SHGetSpecialFolderPath(0, RecPath, CSIDL, false) then
    result:=RecPath
  else result:='';
finally
  StrDispose(RecPath);
  end
end;

function DirectoryExists(path: string): boolean;
var
f: TSearchRec;
begin
result:=FindFirst(path,faDirectory,f)=0;
end;

function LocalizedFilePath(path: string): string;
begin
result:=DataDir+'Localization\'+path;
if not FileExists(result) then
  result:=HomeDir+path
end;


var
AppDataDir: string;
src,dst: TSearchRec;

initialization
HomeDir:=ExtractFilePath(ParamStr(0));


AppDataDir:=GetSpecialDirectory(CSIDL_APPDATA);
if AppDataDir='' then
  DataDir:=HomeDir
else
  begin
  if not DirectoryExists(AppDataDir+'\C-evo') then
    CreateDir(AppDataDir+'\C-evo');
  DataDir:=AppDataDir+'\C-evo\';
  end;
if not DirectoryExists(DataDir+'Saved') then
  CreateDir(DataDir+'Saved');
if not DirectoryExists(DataDir+'Maps') then
  CreateDir(DataDir+'Maps');

// copy appdata if not done yet
if FindFirst(HomeDir+'AppData\Saved\*.cevo',$21,src)=0 then
  repeat
    if (FindFirst(DataDir+'Saved\'+src.Name,$21,dst)<>0)
      or (dst.Time<src.Time) then
      CopyFile(PChar(HomeDir+'AppData\Saved\'+src.Name),
        PChar(DataDir+'Saved\'+src.Name),false);
  until FindNext(src)<>0;
end.
