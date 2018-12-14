{$INCLUDE switches}

unit NatStat;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,BaseWin,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB, ButtonC, Menus, EOTButton;

type
  PEnemyReport=^TEnemyReport;

  TNatStatDlg = class(TBufferedDrawDlg)
    ToggleBtn: TButtonB;
    CloseBtn: TButtonB;
    Popup: TPopupMenu;
    ScrollUpBtn: TButtonC;
    ScrollDownBtn: TButtonC;
    ContactBtn: TEOTButton;
    TellAIBtn: TButtonC;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure DialogBtnClick(Sender: TObject);
    procedure ToggleBtnClick(Sender: TObject);
    procedure PlayerClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure FormDestroy(Sender: TObject);
    procedure ScrollUpBtnClick(Sender: TObject);
    procedure ScrollDownBtnClick(Sender: TObject);
    procedure TellAIBtnClick(Sender: TObject);

  public
    procedure CheckAge;
    procedure ShowNewContent(NewMode: integer; p: integer = -1);
    procedure EcoChange;

  protected
    procedure OffscreenPaint; override;

  private
    pView, AgePrepared, LinesDown: integer;
    SelfReport,CurrentReport: PEnemyReport;
    ShowContact,ContactEnabled: boolean;
    Back, Template: TBitmap;
    ReportText: TStringList;
    procedure GenerateReportText;
  end;

var
  NatStatDlg: TNatStatDlg;


implementation

{$R *.DFM}

uses
  Diagram,Select,Messg,MessgEx, Help,Tribes,Directories;

const
xIcon=326; yIcon=49;
xAttrib=96; yAttrib=40;
xRelation=16; yRelation=110;
PaperShade=3;
ReportLines=12;
LineSpacing=22;
xReport=24; yReport=165; wReport=352; hReport=ReportLines*LineSpacing;


procedure TNatStatDlg.FormCreate(Sender: TObject);
begin
inherited;
AgePrepared:=-2;
GetMem(SelfReport,SizeOf(TEnemyReport)-2*(INFIN+1));
ReportText:=TStringList.Create;
InitButtons();
ContactBtn.Template:=Templates;
HelpContext:='DIPLOMACY';
ToggleBtn.Hint:=Phrases.Lookup('BTN_SELECT');
ContactBtn.Hint:=Phrases.Lookup('BTN_DIALOG');

Back:=TBitmap.Create;
Back.PixelFormat:=pf24bit;
Back.Width:=ClientWidth; Back.Height:=ClientHeight;
Template:=TBitmap.Create;
LoadGraphicFile(Template, HomeDir+'Graphics\Nation', gfNoGamma);
Template.PixelFormat:=pf8bit;
end;

procedure TNatStatDlg.FormDestroy(Sender: TObject);
begin
ReportText.Free;
FreeMem(SelfReport);
Template.Free;
Back.Free;
end;

procedure TNatStatDlg.CheckAge;
begin
if MainTextureAge<>AgePrepared then
  begin
  AgePrepared:=MainTextureAge;
  bitblt(Back.Canvas.Handle,0,0,ClientWidth,ClientHeight,
    MainTexture.Image.Canvas.Handle,(wMainTexture-ClientWidth) div 2,
    (hMainTexture-ClientHeight) div 2,SRCCOPY);
  ImageOp_B(Back,Template,0,0,0,0,ClientWidth,ClientHeight);
  end
end;

procedure TNatStatDlg.FormShow(Sender: TObject);
begin
if pView=me then
  begin
  SelfReport.TurnOfCivilReport:=MyRO.Turn;
  SelfReport.TurnOfMilReport:=MyRO.Turn;
  move(MyRO.Treaty, SelfReport.Treaty, sizeof(SelfReport.Treaty));
  SelfReport.Government:=MyRO.Government;
  SelfReport.Money:=MyRO.Money;
  CurrentReport:=pointer(SelfReport);
  end
else CurrentReport:=pointer(MyRO.EnemyReport[pView]);
if CurrentReport.TurnOfCivilReport>=0 then
  GenerateReportText;
ShowContact:= (pView<>me) and (not supervising or (me<>0));
ContactEnabled:= ShowContact and not supervising
  and (1 shl pView and MyRO.Alive<>0);
ContactBtn.Visible:=ContactEnabled and (MyRO.Happened and phGameEnd=0)
  and (ClientMode<scContact);
ScrollUpBtn.Visible:=(CurrentReport.TurnOfCivilReport>=0)
  and (ReportText.Count>ReportLines);
ScrollDownBtn.Visible:=(CurrentReport.TurnOfCivilReport>=0)
  and (ReportText.Count>ReportLines);
if OptionChecked and (1 shl soTellAI)<>0 then
  TellAIBtn.ButtonIndex:=3
else TellAIBtn.ButtonIndex:=2;
Caption:=Tribe[pView].TPhrase('TITLE_NATION');
LinesDown:=0;

OffscreenPaint;
end;

procedure TNatStatDlg.ShowNewContent(NewMode,p: integer);
begin
if p<0 then
  if ClientMode>=scContact then
    pView:=DipMem[me].pContact
  else
    begin
    pView:=0;
    while (pView<nPl) and ((MyRO.Treaty[pView]<trNone)
      or (1 shl pView and MyRO.Alive=0)) do
      inc(pView);
    if pView>=nPl then pView:=me;
    end
else pView:=p;
inherited ShowNewContent(NewMode);
end;

procedure TNatStatDlg.PlayerClick(Sender: TObject);
begin
ShowNewContent(FWindowMode, TComponent(Sender).Tag);
end;

procedure TNatStatDlg.GenerateReportText;
var
List: ^TChart;

  function StatText(no: integer): string;
  var
  i: integer;
  begin
  if (CurrentReport.TurnOfCivilReport>=0) and (Server(sGetChart+no shl 4,me,pView,List^)>=rExecuted) then
    begin
    i:=List[CurrentReport.TurnOfCivilReport];
    case no of
      stPop: result:=Format(Phrases.Lookup('FRSTATPOP'),[i]);
      stTerritory: result:=Format(Phrases.Lookup('FRSTATTER'),[i]);
      stScience: result:=Format(Phrases.Lookup('FRSTATTECH'),[i div nAdv]);
      stExplore: result:=Format(Phrases.Lookup('FRSTATEXP'),[i*100 div (G.lx*G.ly)]);
      end;
    end
  end;

var
p1,Treaty: integer;
s: string;
HasContact,ExtinctPart: boolean;
begin
GetMem(List,4*(MyRO.Turn+2));

ReportText.Clear;
ReportText.Add('');
if (MyRO.Turn-CurrentReport.TurnOfCivilReport>1)
  and (1 shl pView and MyRO.Alive<>0) then
  begin
  s:=Format(Phrases.Lookup('FROLDCIVILREP'),
    [TurnToString(CurrentReport.TurnOfCivilReport)]);
  ReportText.Add('C'+s);
  ReportText.Add('');
  end;

if (1 shl pView and MyRO.Alive<>0) then
  begin
  ReportText.Add('M'+Format(Phrases.Lookup('FRTREASURY'),[CurrentReport.Money]));
  ReportText.Add('P'+StatText(stPop));
  ReportText.Add('T'+StatText(stTerritory));
  end;
ReportText.Add('S'+StatText(stScience));
ReportText.Add('E'+StatText(stExplore));
HasContact:=false;
for p1:=0 to nPl-1 do
  if (p1<>me) and (CurrentReport.Treaty[p1]>trNoContact) then
    HasContact:=true;
if HasContact then
  begin
  ReportText.Add('');
  ReportText.Add(' '+Phrases.Lookup('FRRELATIONS'));
  for ExtinctPart:=false to true do
    for Treaty:=trAlliance downto trNone do
      for p1:=0 to nPl-1 do
        if (p1<>me) and (CurrentReport.Treaty[p1]=Treaty)
          and ((1 shl p1 and MyRO.Alive=0)=ExtinctPart) then
          begin
          s:=Tribe[p1].TString(Phrases.Lookup('HAVETREATY', Treaty));
          if ExtinctPart then s:='('+s+')';
          ReportText.Add(char(48+Treaty)+s);
          end;
  end;
ReportText.Add('');

FreeMem(List);
end;

procedure TNatStatDlg.OffscreenPaint;
var
i, y: integer;
s: string;
ps: pchar;
Extinct: boolean;

begin
inherited;

Extinct:= 1 shl pView and MyRO.Alive=0;

bitblt(offscreen.canvas.handle,0,0,ClientWidth,ClientHeight,Back.Canvas.handle,0,0,SRCCOPY);

offscreen.Canvas.Font.Assign(UniFont[ftCaption]);
RisedTextout(offscreen.Canvas,40{(ClientWidth-BiColorTextWidth(offscreen.canvas,caption)) div 2},7,Caption);

offscreen.Canvas.Font.Assign(UniFont[ftNormal]);

with offscreen do
  begin
  // show leader picture
  Tribe[pView].InitAge(GetAge(pView));
  if Tribe[pView].faceHGr>=0 then
    begin
    Dump(offscreen,Tribe[pView].faceHGr,18,yIcon-4,64,48,
      1+Tribe[pView].facepix mod 10 *65,1+Tribe[pView].facepix div 10 *49);
    frame(offscreen.Canvas,18-1,yIcon-4-1,18+64,yIcon-4+48,$000000,$000000);
    end;

  if (pView=me) or not Extinct then
    LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib,
      Phrases.Lookup('GOVERNMENT',CurrentReport.Government)+Phrases.Lookup('FRAND'));
  if pView=me then
    begin
    LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+19,
      Phrases.Lookup('CREDIBILITY',RoughCredibility(MyRO.Credibility)));
    LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+38,
      Format(Phrases.Lookup('FRCREDIBILITY'),[MyRO.Credibility]));
    end
  else
    begin
    if Extinct then
      begin
      LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+9,
        Phrases.Lookup('FREXTINCT'));
      LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+28,
        TurnToString(CurrentReport.TurnOfCivilReport))
      end
    else
      begin
      LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+19,
        Phrases.Lookup('CREDIBILITY',RoughCredibility(CurrentReport.Credibility)));
      LoweredTextOut(Canvas,-1,MainTexture,xAttrib,yAttrib+38,
        Format(Phrases.Lookup('FRCREDIBILITY'),[CurrentReport.Credibility]));
      end;

    if MyRO.Treaty[pView]=trNoContact then
      begin
      s:=Phrases.Lookup('FRNOCONTACT');
      LoweredTextOut(Canvas,-1,MainTexture,
        (ClientWidth-BiColorTextWidth(canvas,s)) div 2,yRelation+9,s)
      end
    else if ShowContact then
      begin
      LoweredTextOut(Canvas,-1,MainTexture,xRelation,yRelation,
        Phrases.Lookup('FRTREATY'));
      LoweredTextOut(Canvas,-1,MainTexture,ClientWidth div 2,yRelation,
        Phrases.Lookup('TREATY',MyRO.Treaty[pView]));
      if CurrentReport.TurnOfContact<0 then
        LoweredTextOut(Canvas,-1,MainTexture,ClientWidth div 2,yRelation+19,
          Phrases.Lookup('FRNOVISIT'))
      else
        begin
        LoweredTextOut(Canvas,-1,MainTexture,xRelation,yRelation+19,
          Phrases.Lookup('FRLASTCONTACT'));
        if CurrentReport.TurnOfContact>=0 then
          LoweredTextOut(Canvas,-1,MainTexture,ClientWidth div 2,yRelation+19,
            TurnToString(CurrentReport.TurnOfContact));
        end;
      end;

    if Extinct then
      FrameImage(canvas,BigImp,xIcon,yIcon,xSizeBig,ySizeBig,0,200)
    {else if CurrentReport.Government=gAnarchy then
      FrameImage(canvas,BigImp,xIcon,yIcon,xSizeBig,ySizeBig,112,400,
        ContactEnabled and (MyRO.Happened and phGameEnd=0) and (ClientMode<scContact))
    else
      FrameImage(canvas,BigImp,xIcon,yIcon,xSizeBig,ySizeBig,
        56*(CurrentReport.Government-1),40,
        ContactEnabled and (MyRO.Happened and phGameEnd=0) and (ClientMode<scContact))};
    end;

  if CurrentReport.TurnOfCivilReport>=0 then
    begin // print state report
    FillSeamless(Canvas, xReport, yReport, wReport, hReport, 0, 0, Paper);
    with canvas do
      begin
      Brush.Color:=MainTexture.clBevelShade;
      FillRect(Rect(xReport+wReport, yReport+PaperShade,
        xReport+wReport+PaperShade, yReport+hReport+PaperShade));
      FillRect(Rect(xReport+PaperShade, yReport+hReport,
        xReport+wReport+PaperShade, yReport+hReport+PaperShade));
      Brush.Style:=bsClear;
      end;

    y:=0;
    for i:=0 to ReportText.Count-1 do
      begin
      if (i>=LinesDown) and (i<LinesDown+ReportLines) then
        begin
        s:=ReportText[i];
        if s<>'' then
          begin
//          LineType:=s[1];
          delete(s,1,1);
          BiColorTextOut(canvas,Colors.Canvas.Pixels[clkMisc,cliPaperText],
            $7F007F,xReport+8,yReport+LineSpacing*y,s);
          end;
        inc(y);
        end
      end;
    end
  else
    begin
    s:=Phrases.Lookup('FRNOCIVILREP');
    RisedTextOut(Canvas,(ClientWidth-BiColorTextWidth(Canvas,s)) div 2,
      yReport+hReport div 2-10,s);
    end;

  if OptionChecked and (1 shl soTellAI)<>0 then
    begin
    Server(sGetAIInfo,me,pView,ps);
    LoweredTextOut(Canvas,-1,MainTexture,42,445,ps);
    end
  else LoweredTextOut(Canvas,-2,MainTexture,42,445,Phrases2.Lookup('MENU_TELLAI'));
  end;
ContactBtn.SetBack(Offscreen.Canvas,ContactBtn.Left,ContactBtn.Top);

MarkUsedOffscreen(ClientWidth,ClientHeight);
end; {OffscreenPaint}

procedure TNatStatDlg.CloseBtnClick(Sender: TObject);
begin
Close
end;

procedure TNatStatDlg.DialogBtnClick(Sender: TObject);
var
ContactResult: integer;
begin
ContactResult:=MainScreen.DipCall(scContact+pView shl 4);
if ContactResult<rExecuted then
  begin
  if ContactResult=eColdWar then
    SoundMessage(Phrases.Lookup('FRCOLDWAR'),'MSG_DEFAULT')
  else if MyRO.Government=gAnarchy then
    SoundMessage(Tribe[me].TPhrase('FRMYANARCHY'),'MSG_DEFAULT')
  else if ContactResult=eAnarchy then
    if MyRO.Treaty[pView]>=trPeace then
      begin
      if MainScreen.ContactRefused(pView, 'FRANARCHY') then
        SmartUpdateContent
      end
    else SoundMessage(Tribe[pView].TPhrase('FRANARCHY'),'MSG_DEFAULT');
  end
else Close
end;

procedure TNatStatDlg.ToggleBtnClick(Sender: TObject);
var
p1,StartCount: integer;
m: TMenuItem;
ExtinctPart: boolean;
begin
EmptyMenu(Popup.Items);

// own nation
if G.Difficulty[me]<>0 then
  begin
  m:=TMenuItem.Create(Popup);
  m.RadioItem:=true;
  m.Caption:=Tribe[me].TPhrase('TITLE_NATION');
  m.Tag:=me;
  m.OnClick:=PlayerClick;
  if me=pView then m.Checked:=true;
  Popup.Items.Add(m);
  end;

// foreign nations
for ExtinctPart:=false to true do
  begin
  StartCount:=Popup.Items.Count;
  for p1:=0 to nPl-1 do
    if ExtinctPart and (G.Difficulty[p1]>0) and (1 shl p1 and MyRO.Alive=0)
      or not ExtinctPart and (1 shl p1 and MyRO.Alive<>0)
      and (MyRO.Treaty[p1]>=trNone) then
      begin
      m:=TMenuItem.Create(Popup);
      m.RadioItem:=true;
      m.Caption:=Tribe[p1].TPhrase('TITLE_NATION');
      if ExtinctPart then
        m.Caption:='('+m.Caption+')';
      m.Tag:=p1;
      m.OnClick:=PlayerClick;
      if p1=pView then m.Checked:=true;
      Popup.Items.Add(m);
      end;
  if (StartCount>0) and (Popup.Items.Count>StartCount) then
    begin //seperator
    m:=TMenuItem.Create(Popup);
    m.Caption:='-';
    Popup.Items.Insert(StartCount,m);
    end;
  end;

Popup.Popup(Left+ToggleBtn.Left, Top+ToggleBtn.Top+ToggleBtn.Height);
end;

procedure TNatStatDlg.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
var
i: integer;
begin
if Key=VK_F9 then // my key
  begin // toggle nation
  i:=0;
  repeat
    pView:=(pView+1) mod nPl;
    inc(i);
  until (i>=nPl)
    or (1 shl pView and MyRO.Alive<>0) and (MyRO.Treaty[pView]>=trNone);
  if i>=nPl then pView:=me;
  Tag:=pView;
  PlayerClick(self); // no, this is not nice
  end
else inherited  
end;

procedure TNatStatDlg.EcoChange;
begin
if Visible and (pView=me) then
  begin
  SelfReport.Government:=MyRO.Government;
  SelfReport.Money:=MyRO.Money;
  SmartUpdateContent
  end
end;

procedure TNatStatDlg.ScrollUpBtnClick(Sender: TObject);
begin
if LinesDown>0 then
  begin
  dec(LinesDown);
  SmartUpdateContent;
  end
end;

procedure TNatStatDlg.ScrollDownBtnClick(Sender: TObject);
begin
if LinesDown+ReportLines<ReportText.Count then
  begin
  inc(LinesDown);
  SmartUpdateContent;
  end
end;

procedure TNatStatDlg.TellAIBtnClick(Sender: TObject);
begin
OptionChecked:=OptionChecked xor (1 shl soTellAI);
if OptionChecked and (1 shl soTellAI)<>0 then
  TellAIBtn.ButtonIndex:=3
else TellAIBtn.ButtonIndex:=2;
SmartUpdateContent
end;

end.

