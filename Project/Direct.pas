{$INCLUDE switches}

unit Direct;

interface

uses
  Messg,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms;

const
WM_GO = WM_USER;
WM_CHANGECLIENT = WM_USER+1; // hand over control to other client
WM_NEXTPLAYER = WM_USER+2; // active player's turn ended, next player
WM_AIEXCEPTION = WM_USER+3;

type
  TDirectDlg = class(TDrawDlg)
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  public
    procedure DlgNotify(ID: integer);
  private
    Info: string;
    State: integer;
    Gone, Quick: boolean;
    procedure SetInfo(x: string);
    procedure SetState(x: integer);
    procedure OnGo(var m:TMessage); message WM_GO;
    procedure OnChangeClient(var m:TMessage); message WM_CHANGECLIENT;
    procedure OnNextPlayer(var m:TMessage); message WM_NEXTPLAYER;
    procedure OnAIException(var Msg:TMessage); message WM_AIEXCEPTION;
  end;

var
  DirectDlg: TDirectDlg;

implementation

uses
ScreenTools,Protocol,GameServer,Start,LocalPlayer,NoTerm,Back,ShellAPI;

{$R *.DFM}

procedure Notify(ID: integer);
begin
DirectDlg.DlgNotify(ID);
end;

procedure TDirectDlg.DlgNotify(ID: integer);
var
hMem: Cardinal;
p: pointer;
s: string;
begin
case ID of
  ntInitLocalHuman:
    begin
    SetMainTextureByAge(-1);
    State:=-1;
    Info:=Phrases.Lookup('BUSY_MODLH');
    Show; Invalidate; Update;
    end;
  ntInitModule..ntInitModule+maxBrain-1:
    if visible then
      begin
      s:=Format(Phrases.Lookup('BUSY_MOD'),[Brain[ID-ntInitModule].Name]);
      while BiColorTextWidth(Canvas,s)+64>ClientWidth do Delete(s,Length(s),1);
      SetInfo(s);
      end;
  ntCreateWorld:
    if visible then SetInfo(Phrases.Lookup('BUSY_START'));
  ntInitPlayers:
    if visible then SetInfo(Phrases.Lookup('BUSY_INIT'));
  ntDeactivationMissing..ntDeactivationMissing+nPl-1:
    SimpleMessage(Format(Phrases.Lookup('MISSDEACT'),[ID-ntDeactivationMissing]));
  ntSetAIName..ntSetAIName+nPl-1:
    LocalPlayer.SetAIName(ID-ntSetAIName, NotifyMessage);
  ntException..ntException+maxBrain-1:
    PostMessage(Handle,WM_AIEXCEPTION,ID-ntException,0);
  ntLoadBegin:
    begin Info:=Phrases.Lookup('BUSY_LOAD'); SetState(0); end;
  ntLoadState..ntLoadState+128:
    SetState(ID-ntLoadState);
  ntDLLError..ntDLLError+128:
    SimpleMessage(Format(Phrases.Lookup('DLLERROR'),[Brain[ID-ntDLLError].FileName]));
  ntAIError:
    SimpleMessage(Format(Phrases.Lookup('AIERROR'),[NotifyMessage]));
  ntClientError..ntClientError+128:
    SimpleMessage(Format(Phrases.Lookup('CLIENTERROR'),[Brain[ID-ntClientError].FileName]));
  ntEndInfo:
    begin Hide; background.update end;
  ntLoadError:
    begin
    if OpenClipboard(Handle) then
      begin // copy file path to clipboard
      NotifyMessage:=NotifyMessage+#0;
      hMem:=GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, Length(NotifyMessage));
      p:=GlobalLock(hMem);
      if p<>nil then
        move(NotifyMessage[1],p^,Length(NotifyMessage));
      GlobalUnlock(hMem);
      SetClipboardData(CF_TEXT, hMem);
      CloseClipboard;
      end;
    with MessgDlg do
      begin
      MessgText:=Phrases.Lookup('LOADERROR');
      Kind:=mkYesNo;
      ShowModal;
      if ModalResult=mrOK then
        ShellExecute(Handle,'open','http://c-evo.org/_sg/contact/cevobug.html',
          '','',SW_SHOWNORMAL);
      end
    end;
  ntStartDone:
    if not Quick then
      begin StartDlg.Hide; background.Update end;
  ntStartGo, ntStartGoRefresh, ntStartGoRefreshMaps:
    if Quick then Close
    else
      begin
      if ID=ntStartGoRefresh then
        StartDlg.UpdateFormerGames
      else if ID=ntStartGoRefreshMaps then
        StartDlg.UpdateMaps;
      StartDlg.Show;
      end;
  ntChangeClient:
    PostMessage(Handle,WM_CHANGECLIENT,0,0);
  ntNextPlayer:
    PostMessage(Handle,WM_NEXTPLAYER,0,0);
  ntDeinitModule..ntDeinitModule+maxBrain-1:
    begin
    Info:=Format(Phrases2.Lookup('BUSY_DEINIT'),
      [Brain[ID-ntDeinitModule].Name]);
    while BiColorTextWidth(Canvas,Info)+64>ClientWidth do
      Delete(Info,Length(Info),1);
    SetMainTextureByAge(-1);
    State:=-1;
    Show;
    Invalidate;
    Update;
    end;
  ntBackOn:
    begin
    background.Show;
    background.update;
    sleep(50); // prevent flickering
    end;
  ntBackOff:
    background.Close;
  end;
end;

procedure TDirectDlg.FormCreate(Sender: TObject);
begin
Gone:=false;
State:=-1;
Info:='';
GameServer.Init(Notify);
Brain[bixNoTerm].Client:=NoTerm.Client;
Brain[bixSuper_Virtual].Client:=nil;
Brain[bixTerm].Client:=LocalPlayer.Client;
Brain[bixNoTerm].Name:=Phrases.Lookup('AIT');
Brain[bixSuper_Virtual].Name:=Phrases.Lookup('SUPER');
Brain[bixTerm].Name:=Phrases.Lookup('HUMAN');
Brain[bixRandom].name:=Phrases.Lookup('RANDOMAI');
Canvas.Font.Assign(UniFont[ftNormal]);
Canvas.Brush.Style:=bsClear;
end;

procedure TDirectDlg.FormShow(Sender: TObject);
begin
if not Gone then
  begin PostMessage(Handle,WM_GO,0,0); Gone:=true end
end;

procedure TDirectDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
GameServer.Done;
end;

procedure TDirectDlg.OnGo(var m:TMessage);
var
i: integer;
s: string;
begin
Hide;
if nBrain=3 then
  begin
  Application.MessageBox(PChar(Phrases.Lookup('NOAI')), 'C-evo', 0);
  close;
  exit
  end;
Quick:=false;
if ParamCount>0 then
  begin
  s:=ParamStr(1);
  if (s[1]='-') or (s[1]='/') then
    begin // special mode
    Delete(s,1,1);
    for i:=1 to Length(s) do if s[i] in ['a'..'z'] then dec(s[i],32);
    if s='MAN' then
      begin Quick:=true; DirectHelp(cHelpOnly); Close end;
    end
  else if (FileExists(ParamStr(1))) then
    begin
    Quick:=true;
    if not LoadGame(ExtractFilePath(ParamStr(1)),ExtractFileName(ParamStr(1)),-1,false) then
      begin
      SimpleMessage(Phrases.Lookup('LOADERR'));
      Close
      end
    end
  end;
if not Quick then
  begin background.Show; StartDlg.Show end
end;

procedure TDirectDlg.OnChangeClient(var m:TMessage);
begin
ChangeClient;
end;

procedure TDirectDlg.OnNextPlayer(var m:TMessage);
begin
NextPlayer;
end;

procedure TDirectDlg.OnAIException(var Msg:TMessage);
begin
Application.MessageBox(PChar(Format(Phrases.Lookup('AIEXCEPTION'),
  [Brain[Msg.WParam].Name])), 'C-evo', 0);
end;

procedure TDirectDlg.FormPaint(Sender: TObject);
begin
PaintBackground(self,3,3,ClientWidth-6,ClientHeight-6);
Frame(Canvas,0,0,ClientWidth-1,ClientHeight-1,0,0);
Frame(Canvas,1,1,ClientWidth-2,ClientHeight-2,MainTexture.clBevelLight,
  MainTexture.clBevelShade);
Frame(Canvas,2,2,ClientWidth-3,ClientHeight-3,MainTexture.clBevelLight,
  MainTexture.clBevelShade);
if State>=0 then
  RisedTextOut(Canvas,(ClientWidth-BiColorTextWidth(Canvas,Info)) div 2,16,Info)
else RisedTextOut(Canvas,(ClientWidth-BiColorTextWidth(Canvas,Info)) div 2,
  (ClientHeight-Canvas.TextHeight(Info)) div 2,Info);
if State>=0 then
  PaintProgressBar(Canvas,3,ClientWidth div 2 -64,40,State,0,128,MainTexture);
end;

procedure TDirectDlg.SetInfo(x: string);
begin
Info:=x;
Invalidate;
Update;
end;

procedure TDirectDlg.SetState(x: integer);
begin
if (x<0)<>(State<0) then
  begin State:=x; Invalidate; Update end
else if x<>State then
  begin
  State:=x;
  PaintProgressBar(Canvas,6,ClientWidth div 2 -64,40,State,128-State,128,MainTexture);
  end
end;

end.

