unit Sound;

interface

uses
Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,MMSystem;


function PrepareSound(FileName: string): integer;
procedure PlaySound(FileName: string);


type
TSoundPlayer = class(TForm)
private
  procedure OnMCI(var m:TMessage); message MM_MCINOTIFY;
  end;


implementation

{$R *.DFM}


type
TSound = class
public
  FDeviceID: word;
  FFileName: string;
  constructor Create(const FileName : string);
  destructor Destroy; override;
  procedure Play(HWND: DWORD);
  procedure Stop;
  procedure Reset;
  end;


constructor TSound.Create(const FileName: string);
var
OpenParm: TMCI_Open_Parms;
begin
FDeviceID:=0;
FFileName:=FileName;
if FileExists(FFileName) then
  begin
  OpenParm.dwCallback:=0;
  OpenParm.lpstrDeviceType:='WaveAudio';
  OpenParm.lpstrElementName:=PChar(FFileName);
  mciSendCommand(0, MCI_Open,
    MCI_WAIT or MCI_OPEN_ELEMENT or MCI_OPEN_SHAREABLE, integer(@OpenParm));
  FDeviceID:=OpenParm.wDeviceID;
  end
end;

destructor TSound.Destroy;
begin
if FDeviceID<>0 then
  mciSendCommand(FDeviceID, MCI_CLOSE, MCI_WAIT, 0);
inherited Destroy;
end;

procedure TSound.Play(HWND: dword);
var
PlayParm: TMCI_Play_Parms;
begin
if FDeviceID<>0 then
  begin
  PlayParm.dwCallback:=HWND;
  mciSendCommand(FDeviceID, MCI_PLAY, MCI_NOTIFY, integer(@PlayParm));
  end
end;

procedure TSound.Stop;
begin
mciSendCommand(FDeviceID, MCI_STOP, 0, 0);
end;

procedure TSound.Reset;
begin
mciSendCommand(FDeviceID, MCI_SEEK, MCI_SEEK_TO_START, 0);
end;


type
TSoundList=array[0..99999] of TSound;

var
nSoundList: integer;
SoundPlayer: TSoundPlayer;
SoundList: ^TSoundList;
PlayingSound: TSound;


procedure TSoundPlayer.OnMCI(var m: TMessage);
begin
if (m.wParam=MCI_Notify_Successful) and (PlayingSound<>nil) then
  begin
  PlayingSound.Reset;
  PlayingSound:=nil;
  end;
end;


function PrepareSound(FileName: string): integer;
begin
for result:=1 to Length(FileName) do
  FileName[result]:=upcase(FileName[result]);
result:=0;
while (result<nSoundList) and (SoundList[result].FFileName<>FileName) do
  inc(result);
if result=nSoundList then
  begin // first time this sound is played
  if nSoundList=0 then
    ReallocMem(SoundList, 16*4)
  else if (nSoundList>=16) and (nSoundList and (nSoundList-1)=0) then
    ReallocMem(SoundList, nSoundList*(2*4));
  inc(nSoundList);
  SoundList[result]:=TSound.Create(FileName);
  end;
end;

procedure PlaySound(FileName: string);
begin
if PlayingSound<>nil then
  exit;
if SoundPlayer=nil then
  Application.CreateForm(TSoundPlayer, SoundPlayer);
PlayingSound:=SoundList[PrepareSound(FileName)];
if PlayingSound.FDeviceID=0 then PlayingSound:=nil
else PlayingSound.Play(SoundPlayer.Handle);
end;

var
i: integer;

initialization
nSoundList:=0;
SoundList:=nil;
PlayingSound:=nil;
SoundPlayer:=nil;

finalization
if PlayingSound<>nil then
  begin
  PlayingSound.Stop;
  Sleep(222);
  end;
for i:=0 to nSoundList-1 do
  SoundList[i].Free;
ReallocMem(SoundList,0);

end.

