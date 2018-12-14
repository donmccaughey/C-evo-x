{$INCLUDE switches}

unit MessgEx;

interface

uses
  Messg,Protocol,ScreenTools,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,ButtonA,
  ButtonB, ButtonBase, StdCtrls;

type
  TMessgExDlg = class(TBaseMessgDlg)
    Button1: TButtonA;
    Button2: TButtonA;
    Button3: TButtonA;
    RemoveBtn: TButtonB;
    EInput: TEdit;
    procedure FormCreate(Sender:TObject);
    procedure FormPaint(Sender:TObject);
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure RemoveBtnClick(Sender: TObject);
  public
    Kind, IconKind, IconIndex, HelpKind, HelpNo, CenterTo: integer;
    OpenSound: string;
    function ShowModal: Integer; override;
    procedure CancelMovie;
  private
    MovieCancelled: boolean;
    procedure PaintBook(ca: TCanvas; x,y,clPage,clCover: integer);
    procedure PaintMyArmy;
    procedure PaintEnemyArmy;
    procedure OnPlaySound(var Msg:TMessage); message WM_PLAYSOUND;
  end;

const
// extra message kinds
mkYesNoCancel=4; mkOkCancelRemove=5; mkOkHelp=6; mkModel=7;


//message icon kinds
mikNone=-1; mikImp=0; mikModel=1; mikTribe=2; mikBook=3; mikAge=4;
mikPureIcon=5; mikMyArmy=6; mikEnemyArmy=7; mikFullControl=8; mikShip=9;
mikBigIcon=10; mikEnemyShipComplete=11;


var
  MessgExDlg:TMessgExDlg;

procedure SoundMessageEx(SimpleText, SoundItem: string);
procedure TribeMessage(p: integer; SimpleText, SoundItem: string);
function SimpleQuery(QueryKind: integer; SimpleText, SoundItem: string):
  integer;
procedure ContextMessage(SimpleText, SoundItem: string; ContextKind,
  ContextNo: integer);


implementation

uses
ClientTools,BaseWin,Term,Help, Select, Diplomacy, Inp, UnitStat, Tribes,
IsoEngine,Diagram;

{$R *.DFM}

const
LostUnitsPerLine=6;

var
PerfFreq: int64;


procedure TMessgExDlg.FormCreate(Sender:TObject);
begin
inherited;
IconKind:=mikNone;
CenterTo:=0;
OpenSound:='';
end;

procedure TMessgExDlg.FormShow(Sender: TObject);
var
i: integer;
begin
if IconKind=mikEnemyArmy then
  InitAllEnemyModels;

Button1.Visible:= GameMode<>cMovie;
Button2.Visible:= (GameMode<>cMovie) and (Kind<>mkOk);
Button3.Visible:= (GameMode<>cMovie) and (Kind=mkYesNoCancel);
RemoveBtn.Visible:= (GameMode<>cMovie) and (Kind=mkOkCancelRemove);
EInput.Visible:= (GameMode<>cMovie) and (Kind=mkModel);
if Button3.Visible then
  begin Button1.Left:=43; Button2.Left:=159; end
else if Button2.Visible then
  begin Button1.Left:=101; Button2.Left:=217; end
else Button1.Left:=159;
RemoveBtn.Left:=ClientWidth-38;
case Kind of
  mkYesNo, mkYesNoCancel:
    begin
    Button1.Caption:=Phrases.Lookup('BTN_YES');
    Button2.Caption:=Phrases.Lookup('BTN_NO')
    end;
  mkOKCancel, mkOkCancelRemove:
    begin
    Button1.Caption:=Phrases.Lookup('BTN_OK');
    Button2.Caption:=Phrases.Lookup('BTN_CANCEL');
    end;
  else
    begin
    Button1.Caption:=Phrases.Lookup('BTN_OK');
    Button2.Caption:=Phrases.Lookup('BTN_INFO');
    end;
  end;
Button3.Caption:=Phrases.Lookup('BTN_CANCEL');
RemoveBtn.Hint:=Phrases.Lookup('BTN_DELGAME');

case IconKind of
  mikImp,mikModel,mikAge,mikPureIcon:
    TopSpace:=56;
  mikBigIcon:
    TopSpace:=152;
  mikEnemyShipComplete:
    TopSpace:=136;
  mikBook:
    if IconIndex>=0 then TopSpace:=84
    else TopSpace:=47;
  mikTribe:
    begin
    Tribe[IconIndex].InitAge(GetAge(IconIndex));
    if Tribe[IconIndex].faceHGr>=0 then
      TopSpace:=64
    end;
  mikFullControl:
    TopSpace:=80;  
  mikShip:
    TopSpace:=240;
  else TopSpace:=0;
  end;

SplitText(true);
ClientHeight:=72+Border+TopSpace+Lines*MessageLineSpacing;
if GameMode=cMovie then ClientHeight:=ClientHeight-32;
if Kind=mkModel then
  ClientHeight:=ClientHeight+36;
if IconKind in [mikMyArmy,mikEnemyArmy] then
  begin
  if nLostArmy>LostUnitsPerLine*6 then ClientHeight:=ClientHeight+6*48
  else ClientHeight:=ClientHeight+((nLostArmy-1) div LostUnitsPerLine +1)*48;
  end;
case CenterTo of
  0:
    begin
    Left:=(Screen.Width-ClientWidth) div 2;
    Top:=(Screen.Height-ClientHeight) div 2-MapCenterUp;
    end;
  1:
    begin
    Left:=(Screen.Width-ClientWidth) div 4;
    Top:=(Screen.Height-ClientHeight)*2 div 3-MapCenterUp;
    end;
  -1:
    begin
    Left:=(Screen.Width-ClientWidth) div 4;
    Top:=(Screen.Height-ClientHeight) div 3-MapCenterUp;
    end;
  end;
for i:=0 to ControlCount-1 do
  Controls[i].Top:=ClientHeight-(34+Border);
if Kind=mkModel then
  EInput.Top:=ClientHeight-(76+Border);
end;

function TMessgExDlg.ShowModal: Integer;
var
Ticks0,Ticks: int64;
begin
if GameMode=cMovie then
  begin
  if not ((GameMode=cMovie) and (MovieSpeed=4)) then
    begin
    MovieCancelled:=false;
    Show;
    QueryPerformanceCounter(Ticks0);
    repeat
      Application.ProcessMessages;
      Sleep(1);
      QueryPerformanceCounter(Ticks);
    until MovieCancelled or ((Ticks-Ticks0)*1000>=1500*PerfFreq);
    Hide;
    end;
  result:=mrOk;
  end
else
  result:=inherited ShowModal;
end;

procedure TMessgExDlg.CancelMovie;
begin
MovieCancelled:=true;
end;

procedure TMessgExDlg.PaintBook(ca: TCanvas; x,y,clPage,clCover: integer);
const
xScrewed=77; yScrewed=10; wScrewed=43; hScrewed=27;
type
TLine=array[0..9999,0..2] of Byte;
var
ix,iy,xDst,yDst,dx,dy,xIcon,yIcon,xb,yb,wb,hb: integer;
x1,xR,yR,share: single;
Screwed: array[0..wScrewed-1,0..hScrewed-1,0..3] of single;
SrcLine: ^TLine;

begin
if IconIndex>=0 then
  begin
  xIcon:=IconIndex mod 7*xSizeBig;
  yIcon:=(IconIndex+SystemIconLines*7) div 7*ySizeBig;
  // prepare screwed icon
  fillchar(Screwed,sizeof(Screwed),0);
  for iy:=0 to 39 do
    begin
    SrcLine:=BigImp.ScanLine[iy+yIcon];
    for ix:=0 to 55 do
      begin
      xR:=ix*(37+iy*5/40)/56;
      xDst:=Trunc(xR);
      xR:=Frac(xR);
      x1:=(120-ix)*(120-ix)-10000;
      yR:=iy*18/40 +x1*x1/4000000;
      yDst:=Trunc(yR);
      yR:=Frac(yR);
      for dx:=0 to 1 do for dy:=0 to 1 do
        begin
        if dx=0 then share:=1-xR else share:=xR;
        if dy=0 then share:=share*(1-yR) else share:=share*yR;
        Screwed[xDst+dx,yDst+dy,0]:=
          Screwed[xDst+dx,yDst+dy,0]+share*SrcLine[ix+xIcon,0];
        Screwed[xDst+dx,yDst+dy,1]:=
          Screwed[xDst+dx,yDst+dy,1]+share*SrcLine[ix+xIcon,1];
        Screwed[xDst+dx,yDst+dy,2]:=
          Screwed[xDst+dx,yDst+dy,2]+share*SrcLine[ix+xIcon,2];
        Screwed[xDst+dx,yDst+dy,3]:=
          Screwed[xDst+dx,yDst+dy,3]+share;
        end
      end;
    end;
  xb:=xBBook; yb:=yBBook; wb:=wBBook; hb:=hBBook;
  end
else begin xb:=xSBook; yb:=ySBook; wb:=wSBook; hb:=hSBook; end;
x:=x-wb div 2;

// paint
BitBlt(LogoBuffer.Canvas.Handle,0,0,wb,hb,ca.handle,x,y,SRCCOPY);

if IconIndex>=0 then
  for iy:=0 to hScrewed-1 do for ix:=0 to wScrewed-1 do
    if Screwed[ix,iy,3]>0.01 then
    LogoBuffer.Canvas.Pixels[xScrewed+ix,yScrewed+iy]:=
      trunc(Screwed[ix,iy,2]/Screwed[ix,iy,3])
      +trunc(Screwed[ix,iy,1]/Screwed[ix,iy,3]) shl 8
      +trunc(Screwed[ix,iy,0]/Screwed[ix,iy,3]) shl 16;

ImageOp_BCC(LogoBuffer,Templates,0,0,xb,yb,wb,hb,clCover,clPage);

BitBlt(ca.handle,x,y,wb,hb,LogoBuffer.Canvas.Handle,0,0,SRCCOPY);
end;

procedure TMessgExDlg.PaintMyArmy;
begin
end;

procedure TMessgExDlg.PaintEnemyArmy;
var
emix,ix,iy,x,y,count,UnitsInLine: integer;
begin
ix:=0;
iy:=0;
if nLostArmy>LostUnitsPerLine then
  UnitsInLine:=LostUnitsPerLine
else UnitsInLine:=nLostArmy;
for emix:=0 to MyRO.nEnemyModel-1 do
  for count:=0 to LostArmy[emix]-1 do
    begin
    x:=ClientWidth div 2+ix*64-UnitsInLine*32;
    y:=26+Border+TopSpace+Lines*MessageLineSpacing+iy*48;
    with MyRO.EnemyModel[emix],Tribe[Owner].ModelPicture[mix] do
      begin
      BitBlt(Canvas.Handle,x,y,64,48,GrExt[HGr].Mask.Canvas.Handle,
        pix mod 10 *65+1,pix div 10 *49+1,SRCAND);
      BitBlt(Canvas.Handle,x,y,64,48,GrExt[HGr].Data.Canvas.Handle,
        pix mod 10 *65+1,pix div 10 *49+1,SRCPAINT);
      end;  

    // next position
    inc(ix);
    if ix=LostUnitsPerLine then
      begin // next line
      ix:=0;
      inc(iy);
      if iy=6 then
        exit;
      UnitsInLine:=nLostArmy-LostUnitsPerLine*iy;
      if UnitsInLine>LostUnitsPerLine then
        UnitsInLine:=LostUnitsPerLine;
      end
    end;
end;

procedure TMessgExDlg.FormPaint(Sender:TObject);
var
p1,clSaveTextLight,clSaveTextShade: integer;
begin
if (IconKind=mikImp) and (IconIndex=27) then
  begin // "YOU WIN" message
  clSaveTextLight:=MainTexture.clTextLight;
  clSaveTextShade:=MainTexture.clTextShade;
  MainTexture.clTextLight:=$000000; // gold
  MainTexture.clTextShade:=$0FDBFF;
  inherited;
  MainTexture.clTextLight:=clSaveTextLight;
  MainTexture.clTextShade:=clSaveTextShade;
  end
else
  inherited;

case IconKind of
  mikImp:
    if Imp[IconIndex].Kind=ikWonder then
      begin
      p1:=MyRO.Wonder[IconIndex].EffectiveOwner;
      BitBlt(Buffer.Canvas.Handle,0,0,xSizeBig+2*GlowRange,ySizeBig+2*GlowRange,
        Canvas.Handle,ClientWidth div 2-(28+GlowRange),24-GlowRange,SRCCOPY);
      BitBlt(Buffer.Canvas.Handle,GlowRange,GlowRange,xSizeBig,ySizeBig,
        BigImp.Canvas.Handle,IconIndex mod 7*xSizeBig,
        (IconIndex+SystemIconLines*7) div 7*ySizeBig,SRCCOPY);
      if p1<0 then
        GlowFrame(Buffer, GlowRange, GlowRange, xSizeBig, ySizeBig, $000000)
      else GlowFrame(Buffer, GlowRange, GlowRange, xSizeBig, ySizeBig,
        Tribe[p1].Color);
      BitBlt(Canvas.Handle,ClientWidth div 2-(28+GlowRange),24-GlowRange,
        xSizeBig+2*GlowRange,ySizeBig+2*GlowRange,Buffer.Canvas.Handle,0,0,
        SRCCOPY);
      end
    else ImpImage(Canvas,ClientWidth div 2-28,24,IconIndex);
  mikAge:
    begin
    if IconIndex=0 then
      ImpImage(Canvas,ClientWidth div 2-28,24,-7)
    else ImpImage(Canvas,ClientWidth div 2-28,24,24+IconIndex)
    end;
  mikModel:
    with Tribe[me].ModelPicture[IconIndex] do
      begin
      FrameImage(Canvas,BigImp,ClientWidth div 2-28,24,xSizeBig,ySizeBig,0,0);
      BitBlt(Canvas.Handle,ClientWidth div 2-32,20,64,44,
        GrExt[HGr].Mask.Canvas.Handle,pix mod 10 *65+1,pix div 10*49+1,SRCAND);
      BitBlt(Canvas.Handle,ClientWidth div 2-32,20,64,44,
        GrExt[HGr].Data.Canvas.Handle,pix mod 10 *65+1,pix div 10*49+1,SRCPAINT);
      end;
  mikBook:
    PaintBook(Canvas,ClientWidth div 2,24,MainTexture.clPage,MainTexture.clCover);
  mikTribe:
    if Tribe[IconIndex].faceHGr>=0 then
      begin
      Frame(Canvas,ClientWidth div 2-32-1,24-1,ClientWidth div 2+32,
        24+48,$000000,$000000);
      BitBlt(Canvas.Handle,ClientWidth div 2-32,24,64,48,
        GrExt[Tribe[IconIndex].faceHGr].Data.Canvas.Handle,
        1+Tribe[IconIndex].facepix mod 10 *65,
        1+Tribe[IconIndex].facepix div 10 *49, SRCCOPY)
      end;
  mikPureIcon:
    FrameImage(Canvas, BigImp, ClientWidth div 2-28,24,xSizeBig, ySizeBig,
      IconIndex mod 7*xSizeBig,
      IconIndex div 7*ySizeBig);
  mikBigIcon:
    FrameImage(Canvas, BigImp, ClientWidth div 2-3*28,32,xSizeBig*3, ySizeBig*3,
      IconIndex mod 2*3*xSizeBig,
      IconIndex div 2*3*ySizeBig);
  mikEnemyShipComplete:
    begin
    BitBlt(Buffer.Canvas.Handle,0,0,140,120,Canvas.Handle,
      (ClientWidth-140) div 2,24,SRCCOPY);
    ImageOp_BCC(Buffer,Templates,0,0,1,279,140,120,0,$FFFFFF);
    BitBlt(Canvas.Handle,(ClientWidth-140) div 2,24,140,
      120,Buffer.Canvas.Handle,0,0,SRCCOPY);
    end;
  mikMyArmy:
    PaintMyArmy;
  mikEnemyArmy:
    PaintEnemyArmy;
  mikFullControl:
    Sprite(Canvas,HGrSystem2,ClientWidth div 2-31,24,63,63,1,281);
  mikShip:
    PaintColonyShip(Canvas,IconIndex,17,ClientWidth-34,38);
  end;

if EInput.Visible then EditFrame(Canvas,EInput.BoundsRect,MainTexture);

if OpenSound<>'' then PostMessage(Handle, WM_PLAYSOUND, 0, 0);
end; {FormPaint}

procedure TMessgExDlg.Button1Click(Sender: TObject);
begin
ModalResult:=mrOK;
end;

procedure TMessgExDlg.Button2Click(Sender: TObject);
begin
if Kind=mkOkHelp then
  HelpDlg.ShowNewContent(wmSubmodal, HelpKind, HelpNo)
else if Kind=mkModel then
  UnitStatDlg.ShowNewContent_OwnModel(wmSubmodal, IconIndex)
else ModalResult:=mrIgnore;
end;

procedure TMessgExDlg.Button3Click(Sender: TObject);
begin
ModalResult:=mrCancel
end;

procedure TMessgExDlg.RemoveBtnClick(Sender: TObject);
begin
ModalResult:=mrNo
end;

procedure TMessgExDlg.FormKeyPress(Sender: TObject; var Key: char);
begin
if Key=#13 then ModalResult:=mrOK
else if (Key=#27) then
  if Button3.Visible then ModalResult:=mrCancel
  else if Button2.Visible then ModalResult:=mrIgnore
end;

procedure SoundMessageEx(SimpleText, SoundItem: string);
// because Messg.SoundMessage not capable of movie mode
begin
with MessgExDlg do
  begin
  MessgText:=SimpleText;
  OpenSound:=SoundItem;
  Kind:=mkOK;
  ShowModal;
  end
end;

procedure TribeMessage(p: integer; SimpleText, SoundItem: string);
begin
with MessgExDlg do
  begin
  OpenSound:=SoundItem;
  MessgText:=SimpleText;
  Kind:=mkOK;
  IconKind:=mikTribe;
  IconIndex:=p;
  ShowModal;
  end;
end;

function SimpleQuery(QueryKind: integer; SimpleText, SoundItem: string):
  integer;
begin
with MessgExDlg do
  begin
  MessgText:=SimpleText;
  OpenSound:=SoundItem;
  Kind:=QueryKind;
  ShowModal;
  result:=ModalResult
  end
end;

procedure ContextMessage(SimpleText, SoundItem: string; ContextKind,
  ContextNo: integer);
begin
with MessgExDlg do
  begin
  MessgText:=SimpleText;
  OpenSound:=SoundItem;
  Kind:=mkOkHelp;
  HelpKind:=ContextKind;
  HelpNo:=ContextNo;
  ShowModal;
  end
end;

procedure TMessgExDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
IconKind:=mikNone;
CenterTo:=0;
end;

procedure TMessgExDlg.OnPlaySound(var Msg:TMessage);
begin
Play(OpenSound);
OpenSound:='';
end;


initialization
QueryPerformanceFrequency(PerfFreq);

end.

