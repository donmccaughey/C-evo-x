{$INCLUDE switches}

unit Diagram;

interface

uses
  BaseWin,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonB, ButtonBase, Menus;

type
  TDiaDlg = class(TFramedDlg)
    CloseBtn: TButtonB;
    ToggleBtn: TButtonB;
    Popup: TPopupMenu;
    procedure CloseBtnClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ToggleBtnClick(Sender: TObject);
    procedure PlayerClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);

  public
    procedure OffscreenPaint; override;
    procedure ShowNewContent_Charts(NewMode: integer);
    procedure ShowNewContent_Ship(NewMode: integer; p: integer = -1);

  private
    Kind:(dkChart,dkShip);
    Player,Mode: integer;
  end;

var
  DiaDlg: TDiaDlg;

procedure PaintColonyShip(canvas: TCanvas; Player,Left,Width,Top: integer);


implementation

uses
Protocol, ScreenTools, ClientTools,Term,Tribes;

{$R *.DFM}

const
Border=24;
RoundPixels: array[0..nStat-1] of integer=(0,0,0,5,5,5);

yArea=48;
xComp: array[0..5] of integer=(-60,-28,4,4,36,68);
yComp: array[0..5] of integer=(-40,-40,-79,-1,-40,-40);
xPow: array[0..3] of integer=(-116,-116,-116,-116);
yPow: array[0..3] of integer=(-28,0,-44,16);
xHab: array[0..1] of integer=(23,23);
yHab: array[0..1] of integer=(-81,1);

procedure PaintColonyShip(canvas: TCanvas; Player,Left,Width,Top: integer);
var
i,x,r,nComp,nPow,nHab: integer;
begin
with canvas do
  begin
  Brush.Color:=$000000;
  FillRect(Rect(Left,Top,Left+Width,Top+200));
  Brush.Style:=bsClear;
  Frame(Canvas,Left-1,Top-1,Left+Width,Top+200,MainTexture.clBevelShade,MainTexture.clBevelLight);
  RFrame(Canvas,Left-2,Top-2,Left+Width+1,Top+200+1,MainTexture.clBevelShade,MainTexture.clBevelLight);

  // stars
  RandSeed:=Player*11111;
  for i:=1 to Width-16 do
    begin
    x:=Random((Width-16)*200);
    r:=Random(13)+28;
    Pixels[x div 200+8,x mod 200+Top]:=(r*r*r*r div 10001)*$10101;
    end;

  nComp:=MyRO.Ship[Player].Parts[spComp];
  nPow:=MyRO.Ship[Player].Parts[spPow];
  nHab:=MyRO.Ship[Player].Parts[spHab];
  if nComp>6 then nComp:=6;
  if nPow>4 then nPow:=4;
  if nHab>2 then nHab:=2;
  for i:=0 to nHab-1 do
    Sprite(canvas,HGrSystem2,Left+Width div 2+xHab[i],Top+100+yHab[i],
      80,80,34,1);
  for i:=0 to nComp-1 do
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[i],Top+100+yComp[i],
      32,80,1,1);
  if nComp>0 then
    for i:=3 downto nPow do
      Sprite(canvas,HGrSystem2,Left+Width div 2+xPow[i]+40,Top+100+yPow[i],
        16,27,1,82);
  for i:=nPow-1 downto 0 do
    Sprite(canvas,HGrSystem2,Left+Width div 2+xPow[i],Top+100+yPow[i],
      56,28,58,82);
  if (nComp<3) and (nHab>=1) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[2]+32-16,Top+100+7+yComp[2],
      16,27,1,82);
  if (nComp>=3) and (nHab<1) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[2]+32,Top+100+7+yComp[2],
      16,27,18,82);
  if (nComp<4) and (nHab>=2) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[3]+32-16,Top+100+46+yComp[3],
      16,27,1,82);
  if (nComp>=4) and (nHab<2) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[3]+32,Top+100+46+yComp[3],
      16,27,18,82);
  if (nComp<>6) and (nComp<>2) and not ((nComp=0) and (nPow<1)) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[nComp],Top+100+7+yComp[nComp],
      16,27,18,82);
  if (nComp<>6) and (nComp<>3) and not ((nComp=0) and (nPow<2)) then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[nComp],Top+100+46+yComp[nComp],
      16,27,18,82);
  if nComp=2 then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[3],Top+100+7+yComp[3],
      16,27,18,82);
  if nComp=3 then
    Sprite(canvas,HGrSystem2,Left+Width div 2+xComp[4],Top+100+7+yComp[4],
      16,27,18,82);
  end
end;

procedure TDiaDlg.FormCreate(Sender: TObject);
begin
inherited;
TitleHeight:=WideFrame+20;
InnerHeight:=ClientHeight-TitleHeight-NarrowFrame;
CaptionRight:=CloseBtn.Left;
CaptionLeft:=ToggleBtn.Left+ToggleBtn.Width;
InitButtons();
end;

procedure TDiaDlg.CloseBtnClick(Sender: TObject);
begin
Close;
end;

procedure TDiaDlg.OffscreenPaint;
type
TLine=array[0..99999,0..2] of Byte;
var
p,T,max,x,y,y0,Stop,r,RoundRange,LineStep: integer;
s: string;
List: ^TChart;

  function Round(T: integer): integer;
  var
  n,i: integer;
  begin
  if T<RoundRange then n:=T else n:=RoundRange;
  result:=0;
  for i:=T-n to T do inc(result,List[i]);
  result:=result div (n+1);
  end;

  procedure ShareBar(x,y:integer; Cap:string; val0,val1: integer);
  begin
  LoweredTextOut(offscreen.Canvas,-1,MainTexture,x-2,y,Cap);
  DLine(offscreen.Canvas,x-2,x+169,y+16,MainTexture.clTextShade,
    MainTexture.clTextLight);
  if val0>0 then s:=Format(Phrases.Lookup('SHARE'),[val0,val1])
  else s:='0';
  RisedTextOut(offscreen.Canvas,x+170-BiColorTextWidth(Offscreen.Canvas,s),y,s);
  end;

begin
inherited;
if Kind=dkChart then with offscreen.Canvas do
  begin
  Font.Assign(UniFont[ftTiny]);
  Font.Color:=$808080;

  RoundRange:=RoundPixels[Mode]*(MyRO.Turn-1) div (InnerWidth-2*Border);

  GetMem(List,4*(MyRO.Turn+2));
  if Mode=stExplore then max:=G.lx*G.ly
  else
    begin
    max:=-1;
    for p:=0 to nPl-1 do
      if (G.Difficulty[p]>0)
        and (Server(sGetChart+Mode shl 4,me,p,List^)>=rExecuted) then
        for T:=0 to MyRO.Turn-1 do
          begin r:=Round(T); if r>max then max:=r; end;
    end;

  Brush.Color:=$000000;
  FillRect(Rect(0,0,InnerWidth,InnerHeight));
  Brush.Style:=bsClear;
  Pen.Color:=$606060;
  MoveTo(Border,InnerHeight-Border);
  LineTo(InnerWidth-Border,InnerHeight-Border);
  if MyRO.Turn>=800 then LineStep:=200
  else if MyRO.Turn>=400 then LineStep:=100
  else LineStep:=50;
  for T:=0 to (MyRO.Turn-1) div LineStep do
    begin
    x:=Border+(InnerWidth-2*Border)*T*LineStep div (MyRO.Turn-1);
    MoveTo(x,Border);
    LineTo(x,InnerHeight-Border);
    s:=IntToStr(abs(TurnToYear(T*LineStep)));
    Textout(x-TextWidth(s) div 2,Border-16,s);
    end;

  if max>0 then
    begin
    for p:=0 to nPl-1 do
      if (G.Difficulty[p]>0)
        and (Server(sGetChart+Mode shl 4,me,p,List^)>=rExecuted) then
        begin
        Pen.Color:=Tribe[p].Color;
        Stop:=MyRO.Turn-1;
        while (Stop>0) and (List[Stop]=0) do dec(Stop);
        for T:=0 to Stop do
          begin
          r:=Round(T);
          x:=Border+(InnerWidth-2*Border)*T div (MyRO.Turn-1);
          y:=InnerHeight-Border-(InnerHeight-2*Border)*r div max;
          if T=0 then MoveTo(x,y)
//          else if Mode=stTerritory then
//            begin LineTo(x,y0); LineTo(x,y) end
          else if RoundPixels[Mode]=0 then
            begin
            if (y<>y0) or (T=Stop) then LineTo(x,y)
            end
          else LineTo(x,y);
          y0:=y;
          end;
        end;
    end;
  FreeMem(List);
  end
else with offscreen.Canvas do
  begin
  Font.Assign(UniFont[ftSmall]);
  FillOffscreen(0,0,InnerWidth,InnerHeight);

  PaintColonyShip(offscreen.Canvas,Player,8,InnerWidth-16,yArea);

  ShareBar(InnerWidth div 2-85,InnerHeight-62,Phrases.Lookup('SHIPHAB'),
    MyRO.Ship[Player].Parts[spHab],2);
  ShareBar(InnerWidth div 2-85,InnerHeight-43,Phrases.Lookup('SHIPPOW'),
    MyRO.Ship[Player].Parts[spPow],4);
  ShareBar(InnerWidth div 2-85,InnerHeight-24,Phrases.Lookup('SHIPCOMP'),
    MyRO.Ship[Player].Parts[spComp],6);
  end;
MarkUsedOffscreen(InnerWidth,InnerHeight);
end; // OffscreenPaint

procedure TDiaDlg.FormPaint(Sender: TObject);
var
s: string;
begin
inherited;
Canvas.Font.Assign(UniFont[ftNormal]);
if Kind=dkChart then s:=Phrases.Lookup('DIAGRAM',Mode)
else s:=Tribe[Player].TPhrase('SHORTNAME');
LoweredTextOut(Canvas, -1, MainTexture,
  (ClientWidth-BiColorTextWidth(Canvas,s)) div 2, 31, s);
end;

procedure TDiaDlg.FormShow(Sender: TObject);
begin
if WindowMode=wmModal then
  begin {center on screen}
  Left:=(Screen.Width-Width) div 2;
  Top:=(Screen.Height-Height) div 2;
  end;
OffscreenPaint;
end;

procedure TDiaDlg.ShowNewContent_Charts(NewMode: integer);
begin
Kind:=dkChart;
Mode:=stPop;
ToggleBtn.ButtonIndex:=15;
ToggleBtn.Hint:=Phrases.Lookup('BTN_PAGE');
Caption:=Phrases.Lookup('TITLE_DIAGRAMS');
inherited ShowNewContent(NewMode);
end;

procedure TDiaDlg.ShowNewContent_Ship(NewMode,p: integer);
begin
Kind:=dkShip;
if p<0 then
  begin
  Player:=me;
  while MyRO.Ship[Player].Parts[spComp]+MyRO.Ship[Player].Parts[spPow]
    +MyRO.Ship[Player].Parts[spHab]=0 do
    Player:=(Player+1) mod nPl;
  end
else Player:=p;
ToggleBtn.ButtonIndex:=28;
ToggleBtn.Hint:=Phrases.Lookup('BTN_SELECT');
Caption:=Phrases.Lookup('TITLE_SHIPS');
inherited ShowNewContent(NewMode);
end;

procedure TDiaDlg.ToggleBtnClick(Sender: TObject);
var
p1: integer;
m: TMenuItem;
begin
if Kind=dkChart then
  begin
  Mode:=(Mode+1) mod nStat;
  OffscreenPaint;
  Invalidate;
  end
else
  begin
  EmptyMenu(Popup.Items);
  for p1:=0 to nPl-1 do
    if MyRO.Ship[p1].Parts[spComp]+MyRO.Ship[p1].Parts[spPow]
      +MyRO.Ship[p1].Parts[spHab]>0 then
      begin
      m:=TMenuItem.Create(Popup);
      m.RadioItem:=true;
      m.Caption:=Tribe[p1].TPhrase('SHORTNAME');
      m.Tag:=p1;
      m.OnClick:=PlayerClick;
      if p1=Player then m.Checked:=true;
      Popup.Items.Add(m);
      end;
  Popup.Popup(Left+ToggleBtn.Left, Top+ToggleBtn.Top+ToggleBtn.Height);
  end
end;

procedure TDiaDlg.PlayerClick(Sender: TObject);
begin
ShowNewContent_Ship(FWindowMode, TComponent(Sender).Tag);
end;

procedure TDiaDlg.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
if (Key=VK_F6) and (Kind=dkChart) then // my key
  ToggleBtnClick(nil)
else if (Key=VK_F8) and (Kind=dkShip) then // my other key
else inherited
end;

end.

