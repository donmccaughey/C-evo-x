unit ButtonBase;

interface

uses
  WinProcs, Classes, Graphics, Controls;

type
  TButtonBase = class(TGraphicControl)
    constructor Create(aOwner: TComponent); override;
  protected
    FDown,FPermanent: boolean;
    FGraphic: TBitmap;
//    FDownSound, FUpSound: string;
    ClickProc: TNotifyEvent;
    DownChangedProc: TNotifyEvent;
    procedure SetDown(x: boolean);
//    procedure PlayDownSound;
//    procedure PlayUpSound;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      x, y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      x, y: integer); override;
    procedure MouseMove(Shift: TShiftState; x, y: integer); override;
  private
    Active: boolean;
  public
    property Graphic: TBitmap read FGraphic write FGraphic;
//    property DownSound: string read FDownSound write FDownSound;
//    property UpSound: string read FUpSound write FUpSound;
  published
    property Visible;
    property Down: boolean read FDown write SetDown;
    property Permanent: boolean read FPermanent write FPermanent;
    property OnClick: TNotifyEvent read ClickProc write ClickProc;
    property OnDownChanged: TNotifyEvent read DownChangedProc write DownChangedProc;
  end;

implementation

//uses
//  MMSystem;

constructor TButtonBase.Create;
begin
inherited Create(aOwner);
//FDownSound:='';
//FUpSound:='';
FGraphic:=nil; Active:=false; FDown:=false; FPermanent:=false;
ClickProc:=nil;
end;

procedure TButtonBase.MouseDown;
begin
Active:=true;
MouseMove(Shift,x,y)
end;

procedure TButtonBase.MouseUp;
begin
if ssLeft in Shift then exit;
MouseMove(Shift,x,y);
if Active and FDown then
  begin
//  PlayUpSound;
  Active:=false;
  if FDown<>FPermanent then
    begin
    FDown:=FPermanent;
    Invalidate;
    if @DownChangedProc<>nil then DownChangedProc(self);
    end;
  if (Button=mbLeft) and (@ClickProc<>nil) then ClickProc(self)
  end
else
  begin
//  if FDown then PlayUpSound;
  Active:=false;
  if FDown then
    begin
    FDown:=false;
    Invalidate;
    if @DownChangedProc<>nil then DownChangedProc(self);
    end;
  end
end;

procedure TButtonBase.MouseMove;
begin
if Active then
   if (x>=0) and (x<Width) and (y>=0) and (y<Height) then
     if (ssLeft in Shift) and not FDown then
       begin
       {PlayDownSound;}
       FDown:=true;
       Paint;
       if @DownChangedProc<>nil then DownChangedProc(self);
       end
   else else if FDown and not FPermanent then
     begin
     {PlayUpSound;}
     FDown:=false;
     Paint;
     if @DownChangedProc<>nil then DownChangedProc(self);
     end
end;

procedure TButtonBase.SetDown(x: boolean);
begin
FDown:=x;
Invalidate
end;

//procedure TButtonBase.PlayDownSound;
//begin
//if DownSound<>'' then SndPlaySound(pchar(DownSound),SND_ASYNC)
//end;

//procedure TButtonBase.PlayUpSound;
//begin
//if UpSound<>'' then SndPlaySound(pchar(UpSound),SND_ASYNC)
//end;

end.

