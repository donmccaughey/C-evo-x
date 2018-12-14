{$INCLUDE switches}

unit Messg;

interface

uses
  ScreenTools,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,ButtonBase,ButtonA,
  ButtonB,Area;

const
WM_PLAYSOUND=WM_USER;

type
  TDrawDlg = class(TForm)
    constructor Create(AOwner: TComponent); override;
  public
    procedure SmartInvalidate; virtual;
  protected
    TitleHeight: integer; // defines area to grip the window for moving (from top)
    procedure InitButtons();
    procedure OnEraseBkgnd(var m:TMessage); message WM_ERASEBKGND;
    procedure OnHitTest(var Msg:TMessage); message WM_NCHITTEST;
  end;

  TBaseMessgDlg = class(TDrawDlg)
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender:TObject);
  public
    MessgText: string;
  protected
    Lines, TopSpace: integer;
    procedure SplitText(preview: boolean);
    procedure CorrectHeight;
  end;

  TMessgDlg = class(TBaseMessgDlg)
    Button1: TButtonA;
    Button2: TButtonA;
    procedure FormCreate(Sender:TObject);
    procedure FormPaint(Sender:TObject);
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
  public
    Kind: integer;
    OpenSound: string;
  private
    procedure OnPlaySound(var Msg:TMessage); message WM_PLAYSOUND;
  end;

const
// message kinds
mkOK=1; mkOKCancel=2; mkYesNo=3;

Border=3;
MessageLineSpacing=20;

var
  MessgDlg:TMessgDlg;

procedure SimpleMessage(SimpleText: string);
procedure SoundMessage(SimpleText, SoundItem: string);


implementation

{$R *.DFM}

constructor TDrawDlg.Create(AOwner: TComponent);
begin
inherited;
TitleHeight:=0;
end;

procedure TDrawDlg.OnEraseBkgnd(var m:TMessage);
begin
end;

procedure TDrawDlg.OnHitTest(var Msg:TMessage);
var
i: integer;
ControlBounds: TRect;
begin
if BorderStyle<>bsNone then
  inherited
else
  begin
  if integer(Msg.LParamHi)>=Top+TitleHeight then
    Msg.result:=HTCLIENT
  else
    begin
    for i:=0 to ControlCount-1 do if Controls[i].Visible then
      begin
      ControlBounds:=Controls[i].BoundsRect;
      if (integer(Msg.LParamLo)>=Left+ControlBounds.Left)
        and (integer(Msg.LParamLo)<Left+ControlBounds.Right)
        and (integer(Msg.LParamHi)>=Top+ControlBounds.Top)
        and (integer(Msg.LParamHi)<Top+ControlBounds.Bottom) then
        begin
        Msg.result:=HTCLIENT;
        exit;
        end;
      end;
    Msg.result:=HTCAPTION
    end;
  end
end;

procedure TDrawDlg.InitButtons();
var
cix: integer;
//ButtonDownSound, ButtonUpSound: string;
begin
//ButtonDownSound:=Sounds.Lookup('BUTTON_DOWN');
//ButtonUpSound:=Sounds.Lookup('BUTTON_UP');
for cix:=0 to ComponentCount-1 do
  if Components[cix] is TButtonBase then
    begin
    TButtonBase(Components[cix]).Graphic:=GrExt[HGrSystem].Data;
//      if ButtonDownSound<>'*' then
//        DownSound:=HomeDir+'Sounds\'+ButtonDownSound+'.wav';
//      if ButtonUpSound<>'*' then
//        UpSound:=HomeDir+'Sounds\'+ButtonUpSound+'.wav';
    if Components[cix] is TButtonA then
      TButtonA(Components[cix]).Font:=UniFont[ftButton];
    if Components[cix] is TButtonB then
      TButtonB(Components[cix]).Mask:=GrExt[HGrSystem].Mask;
    end;
end;

procedure TDrawDlg.SmartInvalidate;
var
i: integer;
r0,r1: HRgn;
begin
r0:=CreateRectRgn(0,0,ClientWidth,ClientHeight);
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

procedure TBaseMessgDlg.FormCreate(Sender: TObject);
begin
Left:=(Screen.Width-ClientWidth) div 2;
Canvas.Font.Assign(UniFont[ftNormal]);
Canvas.Brush.Style:=bsClear;
MessgText:='';
TopSpace:=0;
TitleHeight:=Screen.Height;
InitButtons();
end;

procedure TBaseMessgDlg.FormPaint(Sender:TObject);
var
i,cix: integer;
begin
PaintBackground(self,3+Border,3+Border,ClientWidth-(6+2*Border),
  ClientHeight-(6+2*Border));
for i:=0 to Border do
  Frame(Canvas,i,i,ClientWidth-1-i,ClientHeight-1-i,
    $000000,$000000);
Frame(Canvas,Border+1,Border+1,ClientWidth-(2+Border),ClientHeight-(2+Border),
  MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(Canvas,2+Border,2+Border,ClientWidth-(3+Border),ClientHeight-(3+Border),
  MainTexture.clBevelLight,MainTexture.clBevelShade);
SplitText(false);

for cix:=0 to ControlCount-1 do
  if (Controls[cix].Visible) and (Controls[cix] is TButtonBase) then
    BtnFrame(Canvas,Controls[cix].BoundsRect,MainTexture);
end;

procedure TBaseMessgDlg.SplitText(preview: boolean);
var
Start,Stop,OrdinaryStop,LinesCount: integer;
s: string;
begin
Start:=1;
LinesCount:=0;
while Start<Length(MessgText) do
  begin
  Stop:=Start;
  while(Stop<Length(MessgText)) and (MessgText[Stop]<>'\')
    and (BiColorTextWidth(Canvas,Copy(MessgText,Start,Stop-Start+1))
      <ClientWidth-56) do
    inc(Stop);
  if Stop<>Length(MessgText) then
    begin
    OrdinaryStop:=Stop;
    repeat dec(OrdinaryStop)
    until (MessgText[OrdinaryStop+1]=' ') or (MessgText[OrdinaryStop+1]='\');
    if (OrdinaryStop+1-Start)*2>=Stop-Start then
      Stop:=OrdinaryStop
    end;
  if not preview then
    begin
    s:=Copy(MessgText,Start,Stop-Start+1);
    LoweredTextOut(Canvas,-1,MainTexture,
      (ClientWidth-BiColorTextWidth(Canvas,s)) div 2,19+Border+TopSpace+LinesCount*MessageLineSpacing,s);
    end;
  Start:=Stop+2;
  inc(LinesCount)
  end;
if preview then Lines:=LinesCount;
end;

procedure TBaseMessgDlg.CorrectHeight;
var
i: integer;
begin
ClientHeight:=72+Border+TopSpace+Lines*MessageLineSpacing;
Top:=(Screen.Height-ClientHeight) div 2;
for i:=0 to ControlCount-1 do
  Controls[i].Top:=ClientHeight-(34+Border);
end;

procedure TMessgDlg.FormCreate(Sender:TObject);
begin
inherited;
OpenSound:='';
end;

procedure TMessgDlg.FormShow(Sender: TObject);
begin
Button1.Visible:=true;
Button2.Visible:= not (Kind in [mkOK]);
if Button2.Visible then Button1.Left:=101
else Button1.Left:=159;
if Kind=mkYesNo then
  begin
  Button1.Caption:=Phrases.Lookup('BTN_YES');
  Button2.Caption:=Phrases.Lookup('BTN_NO')
  end
else
  begin
  Button1.Caption:=Phrases.Lookup('BTN_OK');
  Button2.Caption:=Phrases.Lookup('BTN_CANCEL');
  end;

SplitText(true);
CorrectHeight;
end;

procedure TMessgDlg.FormPaint(Sender:TObject);
begin
inherited;
if OpenSound<>'' then PostMessage(Handle, WM_PLAYSOUND, 0, 0);
end; {FormPaint}

procedure TMessgDlg.Button1Click(Sender: TObject);
begin
ModalResult:=mrOK;
end;

procedure TMessgDlg.Button2Click(Sender: TObject);
begin
ModalResult:=mrIgnore;
end;

procedure TMessgDlg.FormKeyPress(Sender: TObject; var Key: char);
begin
if Key=#13 then ModalResult:=mrOK
//else if (Key=#27) and (Button2.Visible) then ModalResult:=mrCancel
end;

procedure SimpleMessage(SimpleText: string);
begin
with MessgDlg do
  begin
  MessgText:=SimpleText;
  Kind:=mkOK;
  ShowModal;
  end
end;

procedure SoundMessage(SimpleText, SoundItem: string);
begin
with MessgDlg do
  begin
  MessgText:=SimpleText;
  OpenSound:=SoundItem;
  Kind:=mkOK;
  ShowModal;
  end
end;

procedure TMessgDlg.OnPlaySound(var Msg:TMessage);
begin
Play(OpenSound);
OpenSound:='';
end;

end.

