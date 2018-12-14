{$INCLUDE switches}

unit BaseWin;

interface

uses
  ScreenTools,Messg,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms;

type
  TBufferedDrawDlg = class(TDrawDlg)
  public
    UserLeft, UserTop: integer;
    constructor Create(AOwner: TComponent); override;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormPaint(Sender:TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormDeactivate(Sender: TObject);
    procedure SmartUpdateContent(ImmUpdate: boolean = false);
    procedure StayOnTop_Workaround;
  protected
    FWindowMode,ModalFrameIndent: integer;
    HelpContext: string;
    procedure ShowNewContent(NewMode: integer; forceclose: boolean = false);
    procedure MarkUsedOffscreen(xMax,yMax: integer);
    procedure OffscreenPaint; virtual;
    procedure VPaint; virtual;
  public
    property WindowMode: integer read FWindowMode;
  end;


  TFramedDlg = class(TBufferedDrawDlg)
  public
    constructor Create(AOwner: TComponent); override;
    procedure FormCreate(Sender:TObject);
    procedure SmartInvalidate; override;
  protected
    CaptionLeft, CaptionRight, InnerWidth, InnerHeight: integer;
    WideBottom, FullCaption, TexOverride, ModalIndication: boolean;
    procedure InitWindowRegion;
    procedure VPaint; override;
    procedure FillOffscreen(Left,Top,Width,Height: integer);
    end;


const
// window modes
wmNone=0; wmModal=$1; wmPersistent=$2; wmSubmodal=$3;


yUnused=161;
NarrowFrame=11; WideFrame=36; SideFrame=9;

var
UsedOffscreenWidth, UsedOffscreenHeight: integer;
Offscreen: TBitmap;
OffscreenUser: TForm;

procedure CreateOffscreen;


implementation

uses
Term, Help, ButtonBase, Area;


constructor TBufferedDrawDlg.Create;
begin
OnClose:=FormClose;
OnPaint:=FormPaint;
OnKeyDown:=FormKeyDown;
OnDeactivate:=FormDeactivate;
inherited;
FWindowMode:=wmNone;
HelpContext:='CONCEPTS';
TitleHeight:=WideFrame;
ModalFrameIndent:=45;
UserLeft:=(Screen.Width-Width) div 2;
UserTop:=(Screen.Height-Height) div 2;
end;

procedure TBufferedDrawDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
if FWindowMode=wmPersistent then
  begin UserLeft:=Left; UserTop:=Top end;
if OffscreenUser=self then OffscreenUser:=nil;
end;

procedure TBufferedDrawDlg.FormPaint(Sender:TObject);
begin
if OffscreenUser<>self then OffscreenPaint;
VPaint
end;

procedure TBufferedDrawDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if Key=VK_ESCAPE then
  begin
  if fsModal in FormState then ModalResult:=mrCancel
  end
else if Key=VK_RETURN then
  begin
  if fsModal in FormState then ModalResult:=mrOK
  end
else if Key=VK_F1 then
  HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkText, HelpDlg.TextIndex(HelpContext))
else if FWindowMode=wmPersistent then
  MainScreen.FormKeyDown(Sender, Key, Shift);
end;

procedure TBufferedDrawDlg.FormDeactivate(Sender: TObject);
begin
if FWindowMode=wmSubmodal then Close
end;

procedure TBufferedDrawDlg.OffscreenPaint;
begin
if (OffscreenUser<>nil) and (OffscreenUser<>self) then
  OffscreenUser.Update; // complete working with old owner to prevent rebound
OffscreenUser:=self;
end;

procedure TBufferedDrawDlg.VPaint;
begin
BitBlt(Canvas.Handle, 0, 0, ClientWidth,
  ClientHeight, offscreen.Canvas. Handle, 0, 0, SRCCOPY);
end;

procedure TBufferedDrawDlg.ShowNewContent(NewMode: integer; forceclose: boolean);
begin
if Visible then
  begin
  assert((NewMode=wmModal) or (FWindowMode<>wmModal)); // don't make modal window non-modal
  if (NewMode=wmModal) and (forceclose or (FWindowMode<>wmModal)) then
    begin // make modal
    UserLeft:=Left;
    UserTop:=Top;
    Visible:=false;
    FWindowMode:=NewMode;
    ShowModal;
    end
  else if forceclose then
    begin // make modal
    Visible:=false;
    FWindowMode:=NewMode;
    Left:=UserLeft;
    Top:=UserTop;
    Show;
    end
  else
    begin
    FWindowMode:=NewMode;
    if @OnShow<>nil then
      OnShow(nil);
    Invalidate;
    BringToFront
    end
  end
else
  begin
  FWindowMode:=NewMode;
  Left:=UserLeft;
  Top:=UserTop;
  if FWindowMode=wmModal then ShowModal
  else Show
  end
end;

procedure TBufferedDrawDlg.SmartUpdateContent(ImmUpdate: boolean);
begin
if Visible then
  begin
  OffscreenPaint;
  SmartInvalidate;
  if ImmUpdate then Update
  end
end;

procedure TBufferedDrawDlg.MarkUsedOffscreen(xMax,yMax: integer);
begin
if xMax>UsedOffscreenWidth then UsedOffscreenWidth:=xMax;
if yMax>UsedOffscreenHeight then UsedOffscreenHeight:=yMax;
end;

procedure TBufferedDrawDlg.StayOnTop_Workaround;
// stayontop doesn't work when window is shown for the first time
// after application lost focus, so show all stayontop-windows in first turn
var
SaveOnShow, SaveOnPaint: TNotifyEvent;
begin
Top:=Screen.Height;
SaveOnShow:=OnShow;
OnShow:=nil;
SaveOnPaint:=OnPaint;
OnPaint:=nil;
FWindowMode:=wmNone;
Show;
Hide;
OnShow:=SaveOnShow;
OnPaint:=SaveOnPaint;
end;


constructor TFramedDlg.Create;
begin
OnCreate:=FormCreate;
inherited;
end;

procedure TFramedDlg.FormCreate(Sender:TObject);
begin
CaptionLeft:=0; CaptionRight:=$FFFF;
WideBottom:=false;
FullCaption:=true;
TexOverride:=false;
ModalIndication:=true;
Canvas.Brush.Style:=bsClear;
InnerWidth:=ClientWidth-2*SideFrame;
InnerHeight:=ClientHeight-TitleHeight-NarrowFrame;
end;

procedure TFramedDlg.SmartInvalidate;
var
i,BottomFrame: integer;
r0,r1: HRgn;
begin
if WideBottom then BottomFrame:=WideFrame else BottomFrame:=NarrowFrame;
r0:=CreateRectRgn(SideFrame,TitleHeight,ClientWidth-SideFrame,
  ClientHeight-BottomFrame);
for i:=0 to ControlCount-1 do
  if not (Controls[i] is TArea) and Controls[i].Visible then
    begin
    with Controls[i].BoundsRect do
      r1:=CreateRectRgn(Left,Top,Right,Bottom);
    CombineRgn(r0,r0,r1,RGN_DIFF);
    DeleteObject(r1);
    end;
InvalidateRgn(Handle,r0,false);
DeleteObject(r0);
end;

procedure TFramedDlg.VPaint;

  procedure CornerFrame(x0,y0,x1,y1: integer);
  begin
  Frame(Canvas,x0+1,y0+1,x1-2,y1-2,MainTexture.clBevelLight,MainTexture.clBevelShade);
  Frame(Canvas,x0+2,y0+2,x1-3,y1-3,MainTexture.clBevelLight,MainTexture.clBevelShade);
  Corner(Canvas,x0+1,y0+1,0,MainTexture);
  Corner(Canvas,x1-9,y0+1,1,MainTexture);
  Corner(Canvas,x0+1,y1-9,2,MainTexture);
  Corner(Canvas,x1-9,y1-9,3,MainTexture);
  end;

var
i,l,FrameTop,FrameBottom,InnerBottom,Cut,xTexOffset,yTexOffset: integer;
R: TRect;
begin
if not TexOverride then
  begin
  if (FWindowMode=wmModal) and ModalIndication then MainTexture:=MainTexture
  else MainTexture:=MainTexture;
  MainTexture:=MainTexture
  end;
Canvas.Font.Assign(UniFont[ftCaption]);
l:=BiColorTextWidth(Canvas,Caption);
Cut:=(ClientWidth-l) div 2;
xTexOffset:=(wMaintexture-ClientWidth) div 2;
yTexOffset:=(hMaintexture-ClientHeight) div 2;
if WideBottom then InnerBottom:=ClientHeight-WideFrame
else InnerBottom:=ClientHeight-NarrowFrame;
if FullCaption then begin FrameTop:=0; FrameBottom:=ClientHeight end
else
  begin
  FrameTop:=TitleHeight-NarrowFrame;
  if WideBottom then FrameBottom:=ClientHeight-(WideFrame-NarrowFrame)
  else FrameBottom:=ClientHeight
  end;
Fill(Canvas,3,InnerBottom+1,ClientWidth-6,ClientHeight-InnerBottom-4,
  xTexOffset,yTexOffset);
Fill(Canvas,3,TitleHeight-2,SideFrame-3,InnerBottom-TitleHeight+4,
  xTexOffset,yTexOffset);
Fill(Canvas,ClientWidth-SideFrame,TitleHeight-2,SideFrame-3,
  InnerBottom-TitleHeight+4,xTexOffset,yTexOffset);
Frame(Canvas,0,FrameTop,ClientWidth-1,FrameBottom-1,0,0);
Frame(Canvas,SideFrame-1,TitleHeight-1,ClientWidth-SideFrame,
  InnerBottom,MainTexture.clBevelShade,MainTexture.clBevelLight);
//RFrame(Canvas,SideFrame-2,TitleHeight-2,ClientWidth-SideFrame+1,
//  InnerBottom+1,MainTexture.clBevelShade,MainTexture.clBevelLight);
if FullCaption then
  begin
  if (FWindowMode<>wmModal) or not ModalIndication then
    begin
    Fill(Canvas,3,3+FrameTop,ClientWidth-6,TitleHeight-FrameTop-4,
      xTexOffset,yTexOffset);
    CornerFrame(0,FrameTop,ClientWidth,FrameBottom);
    end
  else with Canvas do
    begin
    Fill(Canvas,3+ModalFrameIndent,3+FrameTop,ClientWidth-6-2*ModalFrameIndent,
      TitleHeight-FrameTop-4,xTexOffset,yTexOffset);
    Fill(Canvas,ClientWidth-3-ModalFrameIndent,3+FrameTop,ModalFrameIndent,
      TitleHeight-FrameTop-4,xTexOffset,yTexOffset);
    Fill(Canvas,3,3+FrameTop,ModalFrameIndent,TitleHeight-FrameTop-4,
      xTexOffset,yTexOffset);
    CornerFrame(0,FrameTop,ClientWidth,FrameBottom);
    Pen.Color:=MainTexture.clBevelShade;
    MoveTo(3+ModalFrameIndent,2); LineTo(3+ModalFrameIndent,TitleHeight);
    Pen.Color:=MainTexture.clBevelShade;
    MoveTo(4+ModalFrameIndent,TitleHeight-1);
    LineTo(ClientWidth-4-ModalFrameIndent,TitleHeight-1);
    LineTo(ClientWidth-4-ModalFrameIndent,1);
    Pen.Color:=MainTexture.clBevelLight;
    MoveTo(ClientWidth-5-ModalFrameIndent,2);
    LineTo(4+ModalFrameIndent,2);
    LineTo(4+ModalFrameIndent,TitleHeight);
    MoveTo(ClientWidth-4-ModalFrameIndent,1);
    LineTo(3+ModalFrameIndent,1);
    Pen.Color:=MainTexture.clBevelLight;
    MoveTo(ClientWidth-3-ModalFrameIndent,3); LineTo(ClientWidth-3-ModalFrameIndent,TitleHeight);
    end
  end
else
  begin
  Fill(Canvas,3,3+FrameTop,ClientWidth-6,TitleHeight-FrameTop-4,
    xTexOffset,yTexOffset);
  CornerFrame(0,FrameTop,ClientWidth,FrameBottom);

  Frame(Canvas,CaptionLeft,0,ClientWidth-CaptionLeft-1,FrameTop,0,0);
  Fill(Canvas,CaptionLeft+3,3,ClientWidth-2*(CaptionLeft)-6,TitleHeight-4,
    xTexOffset,yTexOffset);

  Frame(Canvas,CaptionLeft+1,0+1,
    ClientWidth-CaptionLeft-2,TitleHeight-1,MainTexture.clBevelLight,MainTexture.clBevelShade);
  Frame(Canvas,CaptionLeft+2,0+2,
    ClientWidth-CaptionLeft-3,TitleHeight-1,MainTexture.clBevelLight,MainTexture.clBevelShade);
  Corner(Canvas,CaptionLeft+1,0+1,0,MainTexture);
  Corner(Canvas,ClientWidth-CaptionLeft-9,0+1,1,MainTexture);

  with Canvas do
    begin
    Pen.Color:=MainTexture.clBevelShade;
    MoveTo(CaptionLeft+1,FrameTop+2);
    LineTo(CaptionLeft+1,TitleHeight);
    Pen.Color:=MainTexture.clBevelLight;
    MoveTo(ClientWidth-CaptionLeft-2,FrameTop+2);
    LineTo(ClientWidth-CaptionLeft-2,TitleHeight);
    end;
  if WideBottom then
    begin
    Frame(Canvas,CaptionLeft,FrameBottom,ClientWidth-CaptionLeft-1,ClientHeight-1,0,0);
    Fill(Canvas,CaptionLeft+3,ClientHeight-3-(WideFrame-5),
      ClientWidth-2*(CaptionLeft)-6,WideFrame-5,xTexOffset,yTexOffset);
    Frame(Canvas,CaptionLeft+1,ClientHeight-WideFrame-1+1,
      ClientWidth-CaptionLeft-2,ClientHeight-2,MainTexture.clBevelLight,MainTexture.clBevelShade);
    Frame(Canvas,CaptionLeft+2,ClientHeight-WideFrame-1+1,
      ClientWidth-CaptionLeft-3,ClientHeight-3,MainTexture.clBevelLight,MainTexture.clBevelShade);
    Corner(Canvas,CaptionLeft+1,ClientHeight-9,2,MainTexture);
    Corner(Canvas,ClientWidth-CaptionLeft-9,ClientHeight-9,3,MainTexture);

    with Canvas do
      begin
      Pen.Color:=MainTexture.clBevelShade;
      MoveTo(CaptionLeft+1,ClientHeight-WideFrame);
      LineTo(CaptionLeft+1,FrameBottom-2);
      Pen.Color:=MainTexture.clBevelLight;
      MoveTo(ClientWidth-CaptionLeft-2,ClientHeight-WideFrame);
      LineTo(ClientWidth-CaptionLeft-2,FrameBottom-2);
      end;
    end
  end;
RisedTextOut(Canvas,Cut-1,7,Caption);

for i:=0 to ControlCount-1 do
  if Controls[i].Visible and (Controls[i] is TButtonBase) then
    begin
    R:=Controls[i].BoundsRect;
    if (R.Bottom<=TitleHeight) or (R.Top>=InnerBottom) then
      BtnFrame(Canvas,R,MainTexture);
    end;

BitBlt(Canvas.Handle,SideFrame,TitleHeight,ClientWidth-2*SideFrame,
  InnerBottom-TitleHeight,offscreen.Canvas.Handle,0,0,SRCCOPY);
end;

procedure TFramedDlg.InitWindowRegion;
var
r0,r1: HRgn;
begin
if FullCaption then exit;
r0:=CreateRectRgn(0,0,ClientWidth,ClientHeight);
r1:=CreateRectRgn(0,0,CaptionLeft,TitleHeight-NarrowFrame);
CombineRgn(r0,r0,r1,RGN_DIFF);
//DeleteObject(r1);
r1:=CreateRectRgn(ClientWidth-CaptionLeft,0,ClientWidth,TitleHeight-NarrowFrame);
CombineRgn(r0,r0,r1,RGN_DIFF);
//DeleteObject(r1);
if WideBottom then
  begin
  r1:=CreateRectRgn(0,ClientHeight-(WideFrame-NarrowFrame),CaptionLeft,
    ClientHeight);
  CombineRgn(r0,r0,r1,RGN_DIFF);
  //DeleteObject(r1);
  r1:=CreateRectRgn(ClientWidth-CaptionLeft,
    ClientHeight-(WideFrame-NarrowFrame),ClientWidth,ClientHeight);
  CombineRgn(r0,r0,r1,RGN_DIFF);
  //DeleteObject(r1);
  end;
SetWindowRgn(Handle,r0,false);
//DeleteObject(r0); // causes crash with Windows 95
end;

procedure TFramedDlg.FillOffscreen(Left,Top,Width,Height: integer);
begin
Fill(Offscreen.Canvas,Left,Top,Width,Height,SideFrame+(wMaintexture-ClientWidth) div 2,
  TitleHeight+(hMaintexture-ClientHeight) div 2);
end;


procedure CreateOffscreen;
begin
if OffScreen<>nil then exit;
offscreen:=TBitmap.Create;
Offscreen.PixelFormat:=pf24bit;
offscreen.Width:=Screen.Width;
if Screen.Height-yUnused<480 then offscreen.Height:=480
else offscreen.Height:=Screen.Height-yUnused;
offscreen.Canvas.Brush.Style:=bsClear;
end;


initialization
offscreen:=nil;
OffscreenUser:=nil;

finalization
offscreen.Free;

end.

