{$INCLUDE switches}

unit Wonders;

interface

uses
  ScreenTools,BaseWin,Protocol,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB;

type
  TWondersDlg = class(TBufferedDrawDlg)
    CloseBtn: TButtonB;
    procedure FormCreate(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormShow(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);

  public
    procedure OffscreenPaint; override;
    procedure ShowNewContent(NewMode: integer); 

  private
    xm,ym,Selection: integer;
  end;

var
  WondersDlg: TWondersDlg;

implementation

uses
Term, ClientTools, Help,Tribes;

{$R *.DFM}

const
RingPosition: array[0..20,0..1] of integer=
((-80,-32), // Pyramids
(80,-32), // Zeus
(0,-64), // Gardens
(0,0), // Colossus
(0,64), // Lighthouse
(-80,32), // GrLibrary
(-90,114), // Oracle
(80,32), // Sun
(90,-114), // Leo
(-180,0), // Magellan
(90,114), // Mich
(0,0), //{11;}
(180,0), // Newton
(-90,-114), // Bach
(0,0), //{14;}
(-160,-64), // Liberty
(0,128), // Eiffel
(160,-64), // Hoover
(-160,64), // Shinkansen
(0,-128), // Manhattan
(160,64)); // Mir


procedure TWondersDlg.FormCreate(Sender: TObject);
begin
Canvas.Font.Assign(UniFont[ftNormal]);
Canvas.Brush.Style:=bsClear;
InitButtons();
end;

procedure TWondersDlg.FormShow(Sender: TObject);
begin
Selection:=-1;
OffscreenPaint;
end;

procedure TWondersDlg.ShowNewContent(NewMode: integer);
begin
inherited ShowNewContent(NewMode);
end;

procedure TWondersDlg.OffscreenPaint;
type
TLine=array[0..649,0..2] of Byte;

  procedure DarkIcon(i: integer);
  var
  x,y,ch,x0Dst,y0Dst,x0Src,y0Src,darken,c: integer;
  Src,Dst: ^TLine;
  begin
  x0Dst:=ClientWidth div 2-xSizeBig div 2+RingPosition[i,0];
  y0Dst:=ClientHeight div 2-ySizeBig div 2+RingPosition[i,1];
  x0Src:=(i mod 7)*xSizeBig;
  y0Src:=(i div 7+SystemIconLines)*ySizeBig;
  for y:=0 to ySizeBig-1 do
    begin
    Src:=BigImp.ScanLine[y0Src+y];
    Dst:=Offscreen.ScanLine[y0Dst+y];
    for x:=0 to xSizeBig-1 do
      begin
      darken:=((255-Src[x0Src+x][0])*3
        +(255-Src[x0Src+x][1])*15
        +(255-Src[x0Src+x][2])*9) div 128;
      for ch:=0 to 2 do
        begin
        c:=Dst[x0Dst+x][ch]-darken;
        if c<0 then Dst[x0Dst+x][ch]:=0
        else Dst[x0Dst+x][ch]:=c;
        end
      end
    end;
  end;

  procedure Glow(i,GlowColor: integer);
  begin
  GlowFrame(Offscreen, ClientWidth div 2-xSizeBig div 2+RingPosition[i,0],
    ClientHeight div 2-ySizeBig div 2+RingPosition[i,1],
    xSizeBig, ySizeBig, GlowColor);
  end;

const
darken=24;
// space=pi/120;
amax0=15734; // 1 shl 16*tan(pi/12-space);
amin1=19413; // 1 shl 16*tan(pi/12+space);
amax1=62191; // 1 shl 16*tan(pi/4-space);
amin2=69061; // 1 shl 16*tan(pi/4+space);
amax2=221246; // 1 shl 16*tan(5*pi/12-space);
amin3=272977; // 1 shl 16*tan(5*pi/12+space);
var
i,x,y,r,ax,ch,c: integer;
HaveWonder: boolean;
Line: array[0..1] of ^TLine;
s: string;
begin
if (OffscreenUser<>nil) and (OffscreenUser<>self) then OffscreenUser.Update;
  // complete working with old owner to prevent rebound
OffscreenUser:=self;

Fill(Offscreen.Canvas,3,3,ClientWidth-6,ClientHeight-6,
  (wMaintexture-ClientWidth) div 2,(hMaintexture-ClientHeight) div 2);
Frame(Offscreen.Canvas,0,0,ClientWidth-1,ClientHeight-1,0,0);
Frame(Offscreen.Canvas,1,1,ClientWidth-2,ClientHeight-2,MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(Offscreen.Canvas,2,2,ClientWidth-3,ClientHeight-3,MainTexture.clBevelLight,MainTexture.clBevelShade);
Corner(Offscreen.Canvas,1,1,0,MainTexture);
Corner(Offscreen.Canvas,ClientWidth-9,1,1,MainTexture);
Corner(Offscreen.Canvas,1,ClientHeight-9,2,MainTexture);
Corner(Offscreen.Canvas,ClientWidth-9,ClientHeight-9,3,MainTexture);

BtnFrame(Offscreen.Canvas,CloseBtn.BoundsRect,MainTexture);

Offscreen.Canvas.Font.Assign(UniFont[ftCaption]);
s:=Phrases.Lookup('TITLE_WONDERS');
RisedTextOut(Offscreen.Canvas,(ClientWidth-BiColorTextWidth(Offscreen.Canvas,s)) div 2-1,7,s);
Offscreen.Canvas.Font.Assign(UniFont[ftNormal]);

xm:=ClientWidth div 2;
ym:=ClientHeight div 2;
for y:=0 to 127 do
  begin
  Line[0]:=Offscreen.Scanline[ym+y];
  Line[1]:=Offscreen.Scanline[ym-1-y];
  for x:=0 to 179 do
    begin
    r:=x*x*(32*32)+y*y*(45*45);
    ax:=((1 shl 16 div 32)*45)*y;
    if (r<8*128*180*180)
      and ((r>=32*64*90*90) and (ax<amax2*x) and ((ax<amax0*x) or (ax>amin2*x))
        or (ax>amin1*x) and ((ax<amax1*x) or (ax>amin3*x))) then
        for i:=0 to 1 do for ch:=0 to 2 do
          begin
          c:=Line[i][xm+x][ch]-darken;
          if c<0 then Line[i][xm+x][ch]:=0
          else Line[i][xm+x][ch]:=c;
          c:=Line[i][xm-1-x][ch]-darken;
          if c<0 then Line[i][xm-1-x][ch]:=0
          else Line[i][xm-1-x][ch]:=c;
          end
    end;
  end;

HaveWonder:=false;
for i:=0 to 20 do if Imp[i].Preq<>preNA then
  begin
  case MyRO.Wonder[i].CityID of
    -1: // not built yet
      begin
      Fill(Offscreen.Canvas,
        xm-xSizeBig div 2+RingPosition[i,0]-3,
        ym-ySizeBig div 2+RingPosition[i,1]-3,
        xSizeBig+6, ySizeBig+6,
        (wMaintexture-ClientWidth) div 2,(hMaintexture-ClientHeight) div 2);
      DarkIcon(i);
      end;
    -2: // destroyed
      begin
      HaveWonder:=true;
      Glow(i,$000000);
      BitBlt(Offscreen.Canvas.Handle, xm-xSizeBig div 2+RingPosition[i,0],
        ym-ySizeBig div 2+RingPosition[i,1], xSizeBig, ySizeBig,
        BigImp.Canvas.Handle, 0, (SystemIconLines+3)*ySizeBig, SRCCOPY);
      end;
    else
      begin
      HaveWonder:=true;
      if MyRO.Wonder[i].EffectiveOwner>=0 then
        Glow(i,Tribe[MyRO.Wonder[i].EffectiveOwner].Color)
      else Glow(i,$000000);
      BitBlt(Offscreen.Canvas.Handle, xm-xSizeBig div 2+RingPosition[i,0],
        ym-ySizeBig div 2+RingPosition[i,1], xSizeBig, ySizeBig,
        BigImp.Canvas.Handle, (i mod 7)*xSizeBig,
        (i div 7+SystemIconLines)*ySizeBig, SRCCOPY);
      end
    end
  end;

if not HaveWonder then
  begin
  s:=Phrases.Lookup('NOWONDER');
  RisedTextout(Offscreen.Canvas,xm-BiColorTextWidth(Offscreen.Canvas,s) div 2,
    ym-Offscreen.Canvas.TextHeight(s) div 2, s);
  end;

MarkUsedOffscreen(ClientWidth,ClientHeight);
end; {OffscreenPaint}

procedure TWondersDlg.CloseBtnClick(Sender: TObject);
begin
Close
end;

procedure TWondersDlg.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
i,OldSelection: integer;
s: string;
begin
OldSelection:=Selection;
Selection:=-1;
for i:=0 to 20 do
  if (Imp[i].Preq<>preNA) and (x>=xm-xSizeBig div 2+RingPosition[i,0])
    and (x<xm+xSizeBig div 2+RingPosition[i,0])
    and (y>=ym-ySizeBig div 2+RingPosition[i,1])
    and (y<ym+ySizeBig div 2+RingPosition[i,1]) then
    begin Selection:=i; break end;
if Selection<>OldSelection then
  begin
  Fill(Canvas,9,ClientHeight-3-46,ClientWidth-18,44,
    (wMaintexture-ClientWidth) div 2,(hMaintexture-ClientHeight) div 2);
  if Selection>=0 then
    begin
    if MyRO.Wonder[Selection].CityID=-1 then
      begin // not built yet
{      s:=Phrases.Lookup('IMPROVEMENTS',Selection);
      Canvas.Font.Color:=$000000;
      Canvas.TextOut(
        (ClientWidth-BiColorTextWidth(Canvas,s)) div 2+1,
        ClientHeight-3-36+1, s);
      Canvas.Font.Color:=MainTexture.clBevelLight;
      Canvas.TextOut(
        (ClientWidth-BiColorTextWidth(Canvas,s)) div 2,
        ClientHeight-3-36, s);}
      end
    else
      begin
      s:=Phrases.Lookup('IMPROVEMENTS',Selection);
      if MyRO.Wonder[Selection].CityID<>-2 then
        s:=Format(Phrases.Lookup('WONDEROF'),
          [s,CityName(MyRO.Wonder[Selection].CityID)]);
      LoweredTextOut(Canvas, -1, MainTexture, (ClientWidth-BiColorTextWidth(Canvas,s)) div 2,
        ClientHeight-3-36-10, s);
      if MyRO.Wonder[Selection].CityID=-2 then
        s:=Phrases.Lookup('DESTROYED')
      else if MyRO.Wonder[Selection].EffectiveOwner<0 then
        s:=Phrases.Lookup('EXPIRED')
      else s:=Tribe[MyRO.Wonder[Selection].EffectiveOwner].TPhrase('WONDEROWNER');
      LoweredTextOut(Canvas, -1, MainTexture, (ClientWidth-BiColorTextWidth(Canvas,s)) div 2,
        ClientHeight-3-36+10, s);
      end
    end;
  end
end;

procedure TWondersDlg.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
if Selection>=0 then
  HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkImp, Selection);
end;

end.

