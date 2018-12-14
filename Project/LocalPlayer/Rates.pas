{$INCLUDE switches}
unit Rates;

interface

uses
  Protocol,ScreenTools,BaseWin,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB, ButtonC;

type
  TRatesDlg = class(TBufferedDrawDlg)
    CloseBtn: TButtonB;
    LuxBtn: TButtonC;
    ScienceBtn: TButtonC;
    TaxUpBtn: TButtonC;
    TaxDownBtn: TButtonC;
    procedure FormShow(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure TaxLuxBtnClick(Sender: TObject);
  public
    procedure OffscreenPaint; override;
    procedure ShowNewContent(NewMode: integer);
  end;

var
  RatesDlg: TRatesDlg;

implementation

uses
  ClientTools,Term,Tribes;

{$R *.DFM}

const
MessageLineSpacing=20;


procedure TRatesDlg.FormCreate(Sender: TObject);
begin
TitleHeight:=Screen.Height;
InitButtons();
end;

procedure TRatesDlg.OffscreenPaint;
var
p,x,y,current,max,i: integer;
s,s1: string;
begin
if (OffscreenUser<>nil) and (OffscreenUser<>self) then OffscreenUser.Update;
  // complete working with old owner to prevent rebound
OffscreenUser:=self;

Fill(Offscreen.Canvas, 0,0,ClientWidth,ClientHeight,
  (wMaintexture-ClientWidth) div 2,(hMaintexture-ClientHeight) div 2);
Frame(Offscreen.Canvas,0,0,ClientWidth-1,ClientHeight-1,0,0);
Frame(Offscreen.Canvas,1,1,ClientWidth-2,ClientHeight-2,MainTexture.clBevelLight,MainTexture.clBevelShade);
Frame(Offscreen.Canvas,2,2,ClientWidth-3,ClientHeight-3,MainTexture.clBevelLight,MainTexture.clBevelShade);

BtnFrame(Offscreen.Canvas,CloseBtn.BoundsRect,MainTexture);
Offscreen.Canvas.Font.Assign(UniFont[ftCaption]);
s:=Phrases.Lookup('TITLE_RATES');
RisedTextOut(Offscreen.Canvas,(ClientWidth-BiColorTextWidth(Offscreen.Canvas,s)) div 2-1,7,s);

if MyRO.Wonder[woLiberty].EffectiveOwner=me then
  s:=Phrases.Lookup('NORATES')
else s:=Phrases.Lookup('RATES');
Offscreen.Canvas.Font.Assign(UniFont[ftNormal]);
p:=pos('\',s);
if p=0 then
  RisedTextout(Offscreen.Canvas,(ClientWidth-BiColorTextWidth(Canvas,s)) div 2, 114, s)
else
  begin
  s1:=copy(s,1,p-1);
  RisedTextout(Offscreen.Canvas,(ClientWidth-BiColorTextWidth(Offscreen.Canvas,s1)) div 2,
    114-MessageLineSpacing div 2, s1);
  s1:=copy(s,p+1,255);
  RisedTextout(Offscreen.Canvas,(ClientWidth-BiColorTextWidth(Offscreen.Canvas,s1)) div 2,
    114+(MessageLineSpacing-MessageLineSpacing div 2), s1);
  end;
Offscreen.Canvas.Font.Assign(UniFont[ftSmall]);

if MyRO.Wonder[woLiberty].EffectiveOwner=me then
  begin
  GlowFrame(Offscreen, ClientWidth div 2-xSizeBig div 2,
    52,xSizeBig, ySizeBig, Tribe[me].Color);
  BitBlt(Offscreen.Canvas.Handle, ClientWidth div 2-xSizeBig div 2,
    52, xSizeBig, ySizeBig,BigImp.Canvas.Handle,
    (woLiberty mod 7)*xSizeBig, (woLiberty div 7+SystemIconLines)*ySizeBig, SRCCOPY);
  end
else
  begin
//  ImageOp_CBC(Offscreen,Templates,260,40,145,112,36,36,$404000,$8B8BEB);

  s:=Phrases.Lookup('SCIENCE');
  RisedTextOut(Offscreen.Canvas,16+120-BiColorTextWidth(Offscreen.Canvas,s),44,s);
  s:=Format('%d%%',[100-MyRO.TaxRate-MyRO.LuxRate]);
  RisedTextOut(Offscreen.Canvas,16+120-BiColorTextWidth(Offscreen.Canvas,s),60,s);
  //PaintProgressBar(Offscreen.Canvas,2,16,81,(100-MyRO.LuxRate-MyRO.TaxRate)*120 div 100,0,120,MainTexture);

  // reverse progress bar for science
  x:=16;
  y:=81;
  current:=(100-MyRO.LuxRate-MyRO.TaxRate)*120 div 100;
  max:=120;
  Frame(Offscreen.Canvas,x-1,y-1,x+max,y+7,$000000,$000000);
  RFrame(Offscreen.Canvas,x-2,y-2,x+max+1,y+8,MainTexture.clBevelShade,MainTexture.clBevelLight);
  with Offscreen.Canvas do
    begin
    for i:=0 to current div 8-1 do
      BitBlt(Handle,x+max-8-i*8,y,8,7,GrExt[HGrSystem].Data.Canvas.Handle,104,
        9+8*2,SRCCOPY);
    BitBlt(Handle,x+max-current,y,
      current-8*(current div 8),7,GrExt[HGrSystem].Data.Canvas.Handle,104,9+8*2,SRCCOPY);
    Brush.Color:=$000000;
    FillRect(Rect(x,y,x+max-current,y+7));
    Brush.Style:=bsClear;
    end;

  RisedTextOut(Offscreen.Canvas,16+160,44,Phrases.Lookup('LUX'));
  s:=Format('%d%%',[MyRO.LuxRate]);
  RisedTextOut(Offscreen.Canvas,16+160{+120-BiColorTextWidth(Offscreen.Canvas,s)},60,s);
  PaintProgressBar(Offscreen.Canvas,5,16+160,81,MyRO.LuxRate*120 div 100,0,120,MainTexture);
  RFrame(Offscreen.Canvas,ScienceBtn.Left-1,LuxBtn.Top-1,LuxBtn.Left+12,
    LuxBtn.Top+12,MainTexture.clBevelShade,MainTexture.clBevelLight);
  end;

DLine(Offscreen.Canvas,1,ClientWidth-2,154, MainTexture.clBevelShade, MainTexture.clBevelLight);
RisedTextOut(Offscreen.Canvas,16+80,164,Phrases.Lookup('TAXRATE'));
s:=Format('%d%%',[MyRO.TaxRate]);
RisedTextOut(Offscreen.Canvas,16+80{+120-BiColorTextWidth(Offscreen.Canvas,s)},180,s);
PaintProgressBar(Offscreen.Canvas,0,16+80,201,MyRO.TaxRate*120 div 100,0,120,MainTexture);
RFrame(Offscreen.Canvas,TaxUpBtn.Left-1,TaxUpBtn.Top-1,TaxUpBtn.Left+12,
  TaxDownBtn.Top+12,MainTexture.clBevelShade,MainTexture.clBevelLight);

MarkUsedOffscreen(ClientWidth,ClientHeight);
end;

procedure TRatesDlg.ShowNewContent(NewMode: integer);
begin
inherited ShowNewContent(NewMode);
end;

procedure TRatesDlg.FormShow(Sender: TObject);
begin
if MyRO.Wonder[woLiberty].EffectiveOwner=me then
  begin
  ScienceBtn.Visible:=false;
  LuxBtn.Visible:=false;
  end
else
  begin
  ScienceBtn.Visible:=true;
  LuxBtn.Visible:=true;
  end;
OffscreenPaint;
end;

procedure TRatesDlg.CloseBtnClick(Sender: TObject);
begin
Close;
end;

procedure TRatesDlg.TaxLuxBtnClick(Sender: TObject);
var
NewTax, NewLux: integer;
begin
NewTax:=MyRO.TaxRate div 10;
NewLux:=MyRO.LuxRate div 10;
if Sender=TaxUpBtn then
  begin
  if NewTax<10 then inc(NewTax);
  if NewTax+NewLux>10 then dec(NewLux);
  end
else if (Sender=TaxDownBtn) and (NewTax>0) then
  dec(NewTax)
else if (Sender=ScienceBtn) and (NewLux>0) then
  dec(NewLux)
else if (Sender=LuxBtn) and (NewLux+NewTax<100) then
  inc(NewLux);
if Server(sSetRates,me,NewTax+NewLux shl 4,nil^)<>eNotChanged then
  begin
  CityOptimizer_BeginOfTurn;
  SmartUpdateContent;
  MainScreen.UpdateViews(true);
  end
end;

end.

