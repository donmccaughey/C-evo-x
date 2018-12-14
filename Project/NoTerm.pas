{$INCLUDE switches}

unit NoTerm;

interface

uses
  ScreenTools,Protocol,Messg,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB;

type
  TNoTermDlg = class(TDrawDlg)
    QuitBtn: TButtonB;
    GoBtn: TButtonB;
    procedure GoBtnClick(Sender: TObject);
    procedure QuitBtnClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
  public
    procedure Client(Command, Player: integer; var Data);
  private
    me, Active, ToldAlive, Round: integer;
    PerfFreq,LastShowYearTime,LastShowTurnChange,LastNewTurn: int64;
    TurnTime,TotalStatTime: extended;
    G: TNewGameData;
    Server: TServerCall;
    Shade, State: TBitmap;
    WinStat, ExtStat, AloneStat: array[0..nPl-1] of integer;
    DisallowShowActive: array[0..nPl-1] of boolean;
    TimeStat: array[0..nPl-1] of extended;
    Mode: (Stop, Stopped, Running, Quit);
    procedure NewStat;
    procedure EndPlaying;
    procedure ShowActive(p: integer; Active: boolean);
    procedure ShowYear;
  end;

var
  NoTermDlg: TNoTermDlg;

procedure Client(Command,Player:integer;var Data); stdcall;

implementation

uses GameServer, log, Start;

{$R *.DFM}

const
UpdateInterval=0.1; // seconds
ShowActiveThreshold=0.05; // seconds

nPlOffered=9;
x0Brain=109+48+23; y0Brain=124+48+7+16;
dxBrain=128; dyBrain=128;
xBrain: array[0..nPlOffered-1] of integer =
  (x0Brain,x0Brain,x0Brain+dxBrain,x0Brain+dxBrain,x0Brain+dxBrain,x0Brain,
  x0Brain-dxBrain,x0Brain-dxBrain,x0Brain-dxBrain);
yBrain: array[0..nPlOffered-1] of integer =
  (y0Brain,y0Brain-dyBrain,y0Brain-dyBrain,y0Brain,y0Brain+dyBrain,
  y0Brain+dyBrain,y0Brain+dyBrain,y0Brain,y0Brain-dyBrain);
xActive: array[0..nPlOffered-1] of integer = (0,0,36,51,36,0,-36,-51,-36);
yActive: array[0..nPlOffered-1] of integer = (0,-51,-36,0,36,51,36,0,-36);

var
FormsCreated: boolean;

procedure TNoTermDlg.FormCreate(Sender: TObject);
begin
Left:=Screen.Width-Width-8; Top:=8;
Caption:=Phrases.Lookup('AIT');
Canvas.Brush.Style:=bsClear;
Canvas.Font.Assign(UniFont[ftSmall]);
TitleHeight:=36;
InitButtons();
QueryPerformanceFrequency(PerfFreq);
LastShowYearTime:=0;
end;

procedure TNoTermDlg.NewStat;
begin
Round:=0;
FillChar(WinStat,SizeOf(WinStat),0);
FillChar(ExtStat,SizeOf(ExtStat),0);
FillChar(AloneStat,SizeOf(AloneStat),0);
FillChar(TimeStat,SizeOf(TimeStat),0);
TotalStatTime:=0;
Mode:=Stop;
end;

procedure TNoTermDlg.EndPlaying;
var
EndCommand: integer;
begin
NewStat;
if G.RO[me].Turn>0 then with MessgDlg do
  begin
  MessgText:=Phrases.Lookup('ENDTOUR');
  Kind:=mkYesNo;
  ShowModal;
  if ModalResult=mrIgnore then EndCommand:=sResign
  else EndCommand:=sBreak
  end
else EndCommand:=sResign;
Server(EndCommand,me,0,nil^)
end;

procedure TNoTermDlg.ShowActive(p: integer; Active: boolean);
begin
if p<nPlOffered then
  Sprite(Canvas,HGrSystem,x0Brain+28+xActive[p],y0Brain+28+yActive[p],8,8,
    81+9*Byte(Active),16);
end;

procedure TNoTermDlg.ShowYear;
begin
Fill(State.Canvas,0,0,192,20,64,287+138);
RisedTextOut(State.Canvas,0,0,Format(Phrases.Lookup('AIT_ROUND'),[Round])+' '
  +TurnToString(G.RO[me].Turn));
BitBlt(Canvas.Handle,64,287+138,192,20,State.Canvas.Handle,0,0,SRCCOPY);
end;

procedure TNoTermDlg.Client(Command, Player: integer; var Data);
var
i,x,y,p: integer;
ActiveDuration: extended;
ShipComplete: boolean;
r: TRect;
now: int64;
begin
case Command of
  cDebugMessage:
    LogDlg.Add(Player, G.RO[0].Turn, pchar(@Data));

  cInitModule:
    begin
    Server:=TInitModuleData(Data).Server;
    TInitModuleData(Data).Flags:=aiThreaded;
    Shade:=TBitmap.Create;
    Shade.Width:=64; Shade.Height:=64;
    for x:=0 to 63 do for y:=0 to 63 do
      if Odd(x+y) then Shade.Canvas.Pixels[x,y]:=$FFFFFF
      else Shade.Canvas.Pixels[x,y]:=$000000;
    State:=TBitmap.Create;
    State.Width:=192; State.Height:=20;
    State.Canvas.Brush.Style:=bsClear;
    State.Canvas.Font.Assign(UniFont[ftSmall]);
    NewStat;
    end;

  cReleaseModule:
    begin
    Shade.Free;
    State.Free
    end;

  cNewGame,cLoadGame:
    begin
    inc(Round);
    if Mode=Running then
      begin Invalidate; Update end
    else Show;
    G:=TNewGameData(Data);
    LogDlg.mSlot.Visible:=false;
    LogDlg.Host:=nil;
    ToldAlive:=G.RO[me].Alive;
    Active:=-1;
    fillchar(DisallowShowActive, sizeof(DisallowShowActive), 0); // false
    LastShowTurnChange:=0;
    LastNewTurn:=0;
    TurnTime:=1.0;
    end;

  cBreakGame:
    begin
    LogDlg.List.Clear;
    if Mode<>Running then
      begin
      if LogDlg.Visible then LogDlg.Close;
      Close;
      end
    end;

  cTurn,cResume,cContinue:
    begin
    me:=Player;
    if Active>=0 then
      begin ShowActive(Active,false); Active:=-1 end; // should not happen

    QueryPerformanceCounter(now);
    if {$IFDEF VER100}(now.LowPart-LastShowYearTime.LowPart){$ELSE}(now-LastShowYearTime){$ENDIF}/PerfFreq>=UpdateInterval then
      begin
      ShowYear;
      LastShowYearTime:=now;
      end;
    TurnTime:={$IFDEF VER100}(now.LowPart-LastNewTurn.LowPart){$ELSE}(now-LastNewTurn){$ENDIF}/PerfFreq;
    LastNewTurn:=now;
    if (G.RO[me].Alive<>ToldAlive) then
      begin
      for p:=1 to nPlOffered-1 do
        if 1 shl p and (G.RO[me].Alive xor ToldAlive)<>0 then
          begin
          r:=Rect(xBrain[p],yBrain[p]-16,xBrain[p]+64,yBrain[p]-16+64);
          InvalidateRect(Handle,@r,false);
          end;
      ToldAlive:=G.RO[me].Alive;
      end;
    Application.ProcessMessages;
    if Mode=Quit then EndPlaying
    else if G.RO[me].Happened and phGameEnd<>0 then
      begin // game ended, update statistics
      for p:=1 to nPlOffered-1 do if bixView[p]>=0 then
        if 1 shl p and G.RO[me].Alive=0 then inc(ExtStat[p]) // extinct
        else if G.RO[me].Alive=1 shl p then inc(AloneStat[p]) // only player alive
        else
          begin // alive but not alone -- check colony ship
          ShipComplete:=true;
          for i:=0 to nShipPart-1 do
            if G.RO[me].Ship[p].Parts[i]<ShipNeed[i] then
              ShipComplete:=false;
          if ShipComplete then inc(WinStat[p])
          end;
      if Mode=Running then Server(sNextRound,me,0,nil^)
      end
    else if Mode=Running then Server(sTurn,me,0,nil^);
    if Mode=Stop then
      begin
      GoBtn.ButtonIndex:=22;
      Mode:=Stopped
      end
    end;

  cShowTurnChange:
    begin
    QueryPerformanceCounter(now);
    if Active>=0 then
      begin
      ActiveDuration:={$IFDEF VER100}(now.LowPart-LastShowTurnChange.LowPart){$ELSE}(now-LastShowTurnChange){$ENDIF}/PerfFreq;
      TimeStat[Active]:=TimeStat[Active]+ActiveDuration;
      TotalStatTime:=TotalStatTime+ActiveDuration;
      if not DisallowShowActive[Active] then
        ShowActive(Active,false);
      DisallowShowActive[Active]:= (ActiveDuration<TurnTime*0.25) and (ActiveDuration<ShowActiveThreshold);
      end;
    LastShowTurnChange:=now;

    Active:=integer(Data);
    if (Active>=0) and not DisallowShowActive[Active] then
      ShowActive(Active,true);
    end

  end
end;

procedure TNoTermDlg.GoBtnClick(Sender: TObject);
begin
if Mode=Running then Mode:=Stop
else if Mode=Stopped then
  begin
  Mode:=Running;
  GoBtn.ButtonIndex:=23;
  GoBtn.Update;
  Server(sTurn,me,0,nil^);
  end
end;

procedure TNoTermDlg.QuitBtnClick(Sender: TObject);
begin
if Mode=Stopped then EndPlaying
else Mode:=Quit
end;

procedure TNoTermDlg.FormPaint(Sender: TObject);
var
i,TimeShare: integer;
begin
Fill(Canvas,3,3,ClientWidth-6, ClientHeight-6, 0,0);
Frame(Canvas,0,0,ClientWidth-1,ClientHeight-1, $000000,$000000);
Frame(Canvas,1,1,ClientWidth-2,ClientHeight-2,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(Canvas,2,2,ClientWidth-3,ClientHeight-3,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Corner(Canvas,1,1,0,MainTexture);
Corner(Canvas,ClientWidth-9,1,1,MainTexture);
Corner(Canvas,1,ClientHeight-9,2,MainTexture);
Corner(Canvas,ClientWidth-9,ClientHeight-9,3,MainTexture);
Canvas.Font.Assign(UniFont[ftCaption]);
RisedTextOut(Canvas,(ClientWidth-BiColorTextWidth(Canvas,Caption)) div 2,7,Caption);
Canvas.Font.Assign(UniFont[ftSmall]);
for i:=1 to nPlOffered-1 do if bixView[i]>=0 then
  begin
  Frame(Canvas,xBrain[i]-24,yBrain[i]-8-16,xBrain[i]-24+111,yBrain[i]-8-16+111,
    MainTexture.clBevelShade,MainTexture.clBevelShade);
  FrameImage(Canvas,StartDlg.BrainPicture[bixView[i]],xBrain[i],yBrain[i]-16,64,64,0,0);
  if 1 shl i and G.RO[me].Alive=0 then
    BitBlt(Canvas.Handle,xBrain[i],yBrain[i]-16,64,64,
      Shade.Canvas.Handle,0,0,SRCAND);
  Sprite(Canvas,HGrSystem,xBrain[i]+30-14,yBrain[i]+53,14,14,1,316);
  RisedTextout(Canvas,xBrain[i]+30-16-BiColorTextWidth(Canvas,IntToStr(WinStat[i])),yBrain[i]+51,IntToStr(WinStat[i]));
  Sprite(Canvas,HGrSystem,xBrain[i]+34,yBrain[i]+53,14,14,1+15,316);
  RisedTextout(Canvas,xBrain[i]+34+16,yBrain[i]+51,IntToStr(AloneStat[i]));
  Sprite(Canvas,HGrSystem,xBrain[i]+30-14,yBrain[i]+53+16,14,14,1+30,316);
  RisedTextout(Canvas,xBrain[i]+30-16-BiColorTextWidth(Canvas,IntToStr(ExtStat[i])),yBrain[i]+51+16,IntToStr(ExtStat[i]));
  Sprite(Canvas,HGrSystem,xBrain[i]+34,yBrain[i]+53+16,14,14,1+45,316);
  if TotalStatTime>0 then
    begin
    TimeShare:=trunc(TimeStat[i]/TotalStatTime*100+0.5);
    RisedTextout(Canvas,xBrain[i]+34+16,yBrain[i]+51+16,IntToStr(TimeShare)+'%');
    end;
  ShowActive(i, i=Active);
  end;
Sprite(Canvas,HGrSystem2,x0Brain+32-20,y0Brain+32-20,40,40,115,1);
ShowYear;
BtnFrame(Canvas,GoBtn.BoundsRect,MainTexture);
BtnFrame(Canvas,QuitBtn.BoundsRect,MainTexture);
//BtnFrame(Canvas,StatBtn.BoundsRect,MainTexture);
end;

procedure Client;
begin
if not FormsCreated then
  begin
  FormsCreated:=true;
  Application.CreateForm(TNoTermDlg, NoTermDlg);
  end;
NoTermDlg.Client(Command,Player,Data);
end;

procedure TNoTermDlg.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
if (char(Key)='M') and (ssCtrl in Shift) then
  if LogDlg.Visible then LogDlg.Close else LogDlg.Show;
end;

initialization
FormsCreated:=false;

end.

