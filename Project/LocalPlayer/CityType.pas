{$INCLUDE switches}

unit CityType;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,BaseWin,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonB, ExtCtrls, ButtonA, ButtonBase;

type
  TCityTypeDlg = class(TFramedDlg)
    CloseBtn: TButtonB;
    DeleteBtn: TButtonB;
    procedure CloseBtnClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; x, y: integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; x, y: integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure DeleteBtnClick(Sender: TObject);
  public
    procedure ShowNewContent(NewMode: integer); 
  protected
    procedure OffscreenPaint; override;
  private
    nPool,dragiix,ctype: integer;
    Pooliix: array[0..nImp-1] of integer;
    listed: Set of 0..nImp;
    Changed: boolean;
    procedure LoadType(NewType: integer);
    procedure SaveType;
  end;

var
  CityTypeDlg: TCityTypeDlg;

implementation

uses Help;

{$R *.DFM}

const
xList=7; yList=0;
nListRow=4; nListCol=10;
xPool=7; yPool=220;
nPoolRow=4; nPoolCol=10;
xSwitch=7; ySwitch=150;
xView=226; yView=130;

procedure TCityTypeDlg.FormCreate(Sender:TObject);
begin
inherited;
CaptionRight:=CloseBtn.Left;
InitButtons();
HelpContext:='MACRO';
Caption:=Phrases.Lookup('TITLE_CITYTYPES');
DeleteBtn.Hint:=Phrases.Lookup('BTN_DELETE');
end;

procedure TCityTypeDlg.CloseBtnClick(Sender:TObject);
begin
Close
end;

procedure TCityTypeDlg.FormPaint(Sender:TObject);
begin
inherited;
BtnFrame(Canvas,DeleteBtn.BoundsRect,MainTexture);
end;

procedure TCityTypeDlg.OffscreenPaint;
var
i,iix: integer;
s: string;
begin
inherited;
offscreen.Canvas.Font.Assign(UniFont[ftSmall]);
FillOffscreen(xList-7,yList,42*nListCol+14,32*nListRow);
FillOffscreen(xPool-7,yPool,42*nPoolCol+14,32*nPoolRow);
FillOffscreen(0,yList+32*nListRow,42*nPoolCol+14,yPool-yList-32*nListRow);

Frame(offscreen.Canvas,0,yList+32*nListRow,InnerWidth-255,yPool-23,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(offscreen.Canvas,InnerWidth-254,yList+32*nListRow,InnerWidth-89,yPool-23,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(offscreen.Canvas,InnerWidth-88,yList+32*nListRow,InnerWidth-1,yPool-23,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(offscreen.Canvas,0,yPool-22,InnerWidth-1,yPool-1,
  MainTexture.clBevelLight,MainTexture.clBevelShade);
for i:=0 to nCityType-1 do
  begin
  RFrame(offscreen.Canvas,xSwitch+i*42,ySwitch,xSwitch+39+i*42,ySwitch+23,
    MainTexture.clBevelShade,MainTexture.clBevelLight);
  if i=ctype then
    Frame(offscreen.Canvas,xSwitch+1+i*42,ySwitch+1,xSwitch+38+i*42,ySwitch+22,
      MainTexture.clBevelShade,MainTexture.clBevelLight)
  else Frame(offscreen.Canvas,xSwitch+1+i*42,ySwitch+1,xSwitch+38+i*42,ySwitch+22,
    MainTexture.clBevelLight,MainTexture.clBevelShade);
  BitBlt(offscreen.Canvas.Handle,xSwitch+2+i*42,ySwitch+2,xSizeSmall,
    ySizeSmall,SmallImp.Canvas.Handle,(i+3)*xSizeSmall,0,SRCCOPY)
  end;
RisedTextOut(offscreen.Canvas,8,yList+32*nListRow+2,Phrases.Lookup('BUILDORDER'));
RisedTextOut(offscreen.Canvas,8,ySwitch+26,Phrases.Lookup('CITYTYPE',ctype));
s:=Phrases.Lookup('BUILDREST');
RisedTextOut(offscreen.Canvas,(InnerWidth-BiColorTextWidth(Offscreen.Canvas,s)) div 2,
  yList+72+32*nListRow,s);

with offscreen.Canvas do
  begin
  for i:=1 to nListRow-1 do
    DLine(offscreen.Canvas,xList-5,xList+4+42*nListCol,yList-1+32*i,
      MainTexture.clBevelLight,MainTexture.clBevelShade);
  for i:=0 to nListCol*nListRow-1 do
    begin
    s:=IntToStr(i+1);
    Font.Color:=MainTexture.clTextLight;
    Textout(xList+20+i mod nListCol *42-TextWidth(s) div 2,
      yList+15+i div nListCol *32-TextHeight(s) div 2,s);
    end
  end;

i:=0;
while MyData.ImpOrder[ctype,i]>=0 do
  begin
  RFrame(offscreen.Canvas,
    xList+20-xSizeSmall div 2 + i mod nListCol *42,
    yList+15-ySizeSmall div 2 + i div nListCol *32,
    xList+21+xSizeSmall div 2 + i mod nListCol *42,
    yList+16+ySizeSmall div 2 + i div nListCol *32,
    MainTexture.clBevelLight,MainTexture.clBevelShade);
  BitBlt(offscreen.Canvas.Handle,
    xList+21-xSizeSmall div 2 + i mod nListCol *42,
    yList+16-ySizeSmall div 2 + i div nListCol *32,
    xSizeSmall,ySizeSmall,SmallImp.Canvas.Handle,
    MyData.ImpOrder[ctype,i] mod 7*xSizeSmall,
    (MyData.ImpOrder[ctype,i]+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY);
  inc(i);
  end;

nPool:=0;
for iix:=28 to nImp-1 do
  if not (iix in listed) and (Imp[iix].Kind=ikCommon) and (iix<>imTrGoods)
    and (Imp[iix].Preq<>preNA)
    and ((Imp[iix].Preq=preNone) or (MyRO.Tech[Imp[iix].Preq]>=tsApplicable)) then
    begin
    Pooliix[nPool]:=iix;
    RFrame(offscreen.Canvas,
      xPool+20-xSizeSmall div 2 + nPool mod nPoolCol *42,
      yPool+15-ySizeSmall div 2 + nPool div nPoolCol *32,
      xPool+21+xSizeSmall div 2 + nPool mod nPoolCol *42,
      yPool+16+ySizeSmall div 2 + nPool div nPoolCol *32,
      MainTexture.clBevelLight, MainTexture.clBevelShade);
    BitBlt(offscreen.Canvas.Handle,
      xPool+21-xSizeSmall div 2 + nPool mod nPoolCol *42,
      yPool+16-ySizeSmall div 2 + nPool div nPoolCol *32,
      xSizeSmall,ySizeSmall,SmallImp.Canvas.Handle,
      iix mod 7*xSizeSmall,(iix+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY);
    inc(nPool)
    end;
DeleteBtn.Visible:= MyData.ImpOrder[ctype,0]>=0;

if dragiix>=0 then
  begin
  ImpImage(offscreen.Canvas,xView+9,yView+5,dragiix);
  s:=Phrases.Lookup('IMPROVEMENTS',dragiix);
  RisedTextOut(offscreen.Canvas,xView+36-BiColorTextWidth(Offscreen.Canvas,s) div 2,
    ySwitch+26,s);
  end;
MarkUsedOffscreen(InnerWidth,InnerHeight);
end; {MainPaint}

procedure TCityTypeDlg.LoadType(NewType: integer);
var
i: integer;
begin
ctype:=NewType;
listed:=[];
i:=0;
while MyData.ImpOrder[ctype,i]>=0 do
  begin include(listed,MyData.ImpOrder[ctype,i]); inc(i) end;
Changed:=false
end;

procedure TCityTypeDlg.SaveType;
var
cix: integer;
begin
if Changed then
  begin
  for cix:=0 to MyRO.nCity-1 do
    if (MyCity[cix].Loc>=0) and (MyCity[cix].Status and 7=ctype+1) then
      AutoBuild(cix, MyData.ImpOrder[ctype]);
  Changed:=false
  end;
end;

procedure TCityTypeDlg.FormShow(Sender: TObject);
begin
LoadType(0);
dragiix:=-1;
OffscreenPaint;
end;

procedure TCityTypeDlg.ShowNewContent(NewMode: integer);
begin
inherited ShowNewContent(NewMode);
end;

procedure TCityTypeDlg.PaintBox1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; x, y: integer);
var
i: integer;
begin
x:=x-SideFrame; y:=y-WideFrame;
i:=(x-xList) div 42+(y-yList) div 32 *nListCol;
if (i<nImp) and (MyData.ImpOrder[ctype,i]>=0)
  and (x>xList+2+ i mod nListCol *42) and (y>yList+5+ i div nListCol *32)
  and (x<xList+3+36+ i mod nListCol *42) and (y<yList+6+20+ i div nListCol *32) then
  begin
  if ssShift in Shift then
    HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkImp, MyData.ImpOrder[ctype,i])
  else
    begin
    dragiix:=MyData.ImpOrder[ctype,i];
    Screen.Cursor:=crImpDrag;
    SmartUpdateContent
    end;
  exit;
  end;
i:=(x-xPool) div 42+(y-yPool) div 32 *nPoolCol;
if (i<nPool) and (x>xPool+2+ i mod nPoolCol *42)
  and (y>yPool+5+ i div nPoolCol *32) and (x<xPool+3+36+ i mod nPoolCol *42)
  and (y<yPool+6+20+ i div nPoolCol *32) then
  begin
  if ssShift in Shift then
    HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkImp, Pooliix[i])
  else
    begin
    dragiix:=Pooliix[i];
    Screen.Cursor:=crImpDrag;
    SmartUpdateContent
    end;
  exit;
  end;
i:=(x-xSwitch) div 42;
if (i<nCityType) and (x>xSwitch+2+ i*42) and (x<xSwitch+3+36+i*42)
  and (y>=ySwitch+2) and (y<ySwitch+22) then
  begin
  SaveType;
  LoadType(i);
  SmartUpdateContent
  end
end;

procedure TCityTypeDlg.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);

  procedure UnList(iix: integer);
  var
  i: integer;
  begin
  i:=0;
  while (MyData.ImpOrder[ctype,i]>=0) and (MyData.ImpOrder[ctype,i]<>iix) do
    inc(i);
  assert(MyData.ImpOrder[ctype,i]=iix);
  move(MyData.ImpOrder[ctype,i+1],MyData.ImpOrder[ctype,i],nImp-i);
  Exclude(listed,iix);
  end;

var
i: integer;
begin
x:=x-SideFrame; y:=y-WideFrame;
if dragiix>=0 then
  begin
  if (x>=xList) and (x<xList+nListCol*42)
    and (y>=yList) and (y<yList+nListRow*32) then
    begin
    if dragiix in listed then UnList(dragiix);
    i:=(x-xList) div 42+(y-yList) div 32 *nListCol;
    while (i>0) and (MyData.ImpOrder[ctype,i-1]<0) do dec(i);
    move(MyData.ImpOrder[ctype,i],MyData.ImpOrder[ctype,i+1],nImp-i-1);
    MyData.ImpOrder[ctype,i]:=dragiix;
    include(listed,dragiix);
    Changed:=true
    end
  else if (dragiix in listed) and (x>=xPool) and (x<xPool+nPoolCol*42)
    and (y>=yPool) and (y<yPool+nPoolRow*32) then
    begin
    UnList(dragiix);
    Changed:=true
    end;
  dragiix:=-1;
  SmartUpdateContent
  end;
Screen.Cursor:=crDefault
end;

procedure TCityTypeDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
SaveType;
inherited;
end;

procedure TCityTypeDlg.DeleteBtnClick(Sender: TObject);
begin
fillchar(MyData.ImpOrder[ctype],sizeof(MyData.ImpOrder[ctype]),-1);
listed:=[];
Changed:=true;
SmartUpdateContent
end;

end.

