{$INCLUDE switches}

unit TechTree;

interface

uses
  ScreenTools,Messg,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB;

type
  TTechTreeDlg = class(TDrawDlg)
    CloseBtn: TButtonB;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure CloseBtnClick(Sender: TObject);
  private
    xOffset, yOffset, xDown, yDown: integer;
    Image: TBitmap;
    dragging: boolean;
  end;

var
  TechTreeDlg: TTechTreeDlg;

implementation

uses
  Directories;

{$R *.DFM}

const
BlackBorder=4;
LeftBorder=72; RightBorder=45; TopBorder=16; BottomBorder=48;
xStart=0; yStart=40;
xPitch=160; yPitch=90;
xLegend=44; yLegend=79; yLegendPitch=32;

function min(a,b: integer): integer;
begin
if a<b then
  result:=a
else result:=b;
end;

function max(a,b: integer): integer;
begin
if a>b then
  result:=a
else result:=b;
end;

procedure TTechTreeDlg.FormCreate(Sender: TObject);
begin
InitButtons;
Image:=nil;
end;

procedure TTechTreeDlg.FormPaint(Sender: TObject);
var
x,w: integer;
begin
with Canvas do
  begin
  // black border
  brush.color:=$000000;
  fillrect(rect(0,0,BlackBorder,ClientHeight));
  fillrect(rect(BlackBorder,0,ClientWidth-BlackBorder,BlackBorder));
  fillrect(rect(ClientWidth-BlackBorder,0,ClientWidth,ClientHeight));
  fillrect(rect(BlackBorder,ClientHeight-BlackBorder,ClientWidth-BlackBorder,
    ClientHeight));

  // texturize empty space
  brush.color:=$FFFFFF;
  if xOffset>0 then
    FillRectSeamless(Canvas,BlackBorder,BlackBorder,BlackBorder+xOffset,
      ClientHeight-BlackBorder,-BlackBorder-xOffset,-BlackBorder-yOffset,Paper);
  if xOffset+Image.width<ClientWidth-2*BlackBorder then
    FillRectSeamless(Canvas,BlackBorder+xOffset+Image.width,BlackBorder,
      ClientWidth-BlackBorder,ClientHeight-BlackBorder,-BlackBorder-xOffset,
      -BlackBorder-yOffset,Paper);
  x:=max(BlackBorder,BlackBorder+xOffset);
  w:=min(BlackBorder+xOffset+Image.width,ClientWidth-BlackBorder);
  if yOffset>0 then
    FillRectSeamless(Canvas,x,BlackBorder,w,BlackBorder+yOffset,
      -BlackBorder-xOffset,-BlackBorder-yOffset,Paper);
  if yOffset+Image.height<ClientHeight-2*BlackBorder then
    FillRectSeamless(Canvas,x,BlackBorder+yOffset+Image.height,w,
      ClientHeight-BlackBorder,-BlackBorder-xOffset,-BlackBorder-yOffset,Paper);
  end;
BitBlt(Canvas.Handle,max(BlackBorder,BlackBorder+xOffset),
  max(BlackBorder,BlackBorder+yOffset),
  min(Image.width,min(Image.width+xOffset,
    min(ClientWidth-2*BlackBorder,ClientWidth-2*BlackBorder-xOffset))),
  min(Image.Height,min(Image.height+yOffset,
    min(ClientHeight-2*BlackBorder,ClientHeight-2*BlackBorder-yOffset))),
  Image.Canvas.Handle,max(0,-xOffset),max(0,-yOffset),SRCCOPY);
end;

procedure TTechTreeDlg.FormShow(Sender: TObject);
type
TLine=array[0..9999,0..2] of Byte;
var
x,y,ad,TexWidth,TexHeight: integer;
s: string;
SrcLine, DstLine: ^TLine;
begin
if Image=nil then
  begin
  Image:=TBitmap.Create;
  LoadGraphicFile(Image, HomeDir+'Help\AdvTree',gfNoGamma);
  Image.PixelFormat:=pf24bit;

  with Image.Canvas do
    begin
    // write advance names
    Font.Assign(UniFont[ftSmall]);
    Font.Color:=clBlack;
    Brush.Style:=bsClear;
    for x:=0 to (Image.width-xStart) div xPitch do
      for y:=0 to (Image.height-yStart) div yPitch do
        begin
        ad:=Pixels[xStart+x*xPitch+10,yStart+y*yPitch-1];
        if ad and $FFFF00=0 then
          begin
          s:=Phrases.Lookup('ADVANCES',ad);
          while TextWidth(s)>112 do
            Delete(s,Length(s),1);
          TextOut(xStart+x*xPitch+2,yStart+y*yPitch,s);
          Pixels[xStart+x*xPitch+10,yStart+y*yPitch-1]:=$7F007F;
          end
        end;

    // write legend
    TextOut(xLegend,yLegend,Phrases2.Lookup('ADVTREE_UP0'));
    TextOut(xLegend,yLegend+yLegendPitch,Phrases2.Lookup('ADVTREE_UP1'));
    TextOut(xLegend,yLegend+2*yLegendPitch,Phrases2.Lookup('ADVTREE_UP2'));
    TextOut(xLegend,yLegend+3*yLegendPitch,Phrases2.Lookup('ADVTREE_GOV'));
    TextOut(xLegend,yLegend+4*yLegendPitch,Phrases2.Lookup('ADVTREE_OTHER'));
    end;

  // texturize background
  TexWidth:=Paper.width;
  TexHeight:=Paper.height;
  for y:=0 to Image.height-1 do
    begin
    SrcLine:=Paper.ScanLine[y mod TexHeight];
    DstLine:=Image.ScanLine[y];
    for x:=0 to Image.Width-1 do
      begin
      if Cardinal((@DstLine[x])^) and $FFFFFF=$7F007F then // transparent
        DstLine[x]:=SrcLine[x mod TexWidth];
      end
    end
  end;

// fit window to image, center image in window, center window to screen
Width:=min(Screen.Width-40,Image.Width+LeftBorder+RightBorder+2*BlackBorder);
Height:=min(Screen.Height-40,Image.Height+TopBorder+BottomBorder+2*BlackBorder);
Left:=(Screen.Width-Width) div 2;
Top:=(Screen.Height-Height) div 2;
CloseBtn.Left:=Width-CloseBtn.Width-BlackBorder-8;
CloseBtn.Top:=BlackBorder+8;
xOffset:=(ClientWidth-Image.width+LeftBorder-RightBorder) div 2-BlackBorder;
yOffset:=ClientHeight-2*BlackBorder-Image.height-BottomBorder;
end;

procedure TTechTreeDlg.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
if Button=mbLeft then
  begin
  dragging:=true;
  xDown:=x;
  yDown:=y;
  end
end;

procedure TTechTreeDlg.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
dragging:=false;
end;

procedure TTechTreeDlg.FormMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
if dragging then
  begin
  xOffset:=xOffset+x-xDown;
  yOffset:=yOffset+y-yDown;
  xDown:=x;
  yDown:=y;

  if xOffset>LeftBorder then
    xOffset:=LeftBorder;
  if xOffset<ClientWidth-2*BlackBorder-Image.width-RightBorder then
    xOffset:=ClientWidth-2*BlackBorder-Image.width-RightBorder;
  if yOffset>TopBorder then
    yOffset:=TopBorder;
  if yOffset<ClientHeight-2*BlackBorder-Image.height-BottomBorder then
    yOffset:=ClientHeight-2*BlackBorder-Image.height-BottomBorder;

  SmartInvalidate;
  end
end;

procedure TTechTreeDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if key=VK_ESCAPE then
  Close;
end;

procedure TTechTreeDlg.CloseBtnClick(Sender: TObject);
begin
Close();
end;

end.
