{$INCLUDE switches}

unit Draft;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,PVSB,BaseWin,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,ExtCtrls,ButtonA,
  ButtonB, ButtonBase, Area;

type
  TDraftDlg = class(TBufferedDrawDlg)
    OKBtn: TButtonA;
    CloseBtn: TButtonB;
    GroundArea: TArea;
    SeaArea: TArea;
    AirArea: TArea;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; x, y: integer);
    procedure OKBtnClick(Sender: TObject);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; x, y: integer);
    procedure FormDestroy(Sender: TObject);
  public
    procedure ShowNewContent(NewMode: integer); 
  protected
    procedure OffscreenPaint; override;
  private
    Domain,MaxLines,Lines,Cut,yDomain,yFeature,yWeight,yTotal,yView,IncCap,
      DecCap: integer;
    code: array[0..nFeature-1] of integer;
    Template,Back: TBitmap;
    function IsFeatureInList(d,i: integer): boolean;
    procedure SetDomain(d: integer);
  end;

var
  DraftDlg: TDraftDlg;

implementation

uses Help,Tribes,Directories;

{$R *.DFM}

const
MaxLines0=11; LinePitch=20;
xDomain=30; yDomain0=464; DomainPitch=40;
xFeature=38; yFeature0=42;
xWeight=100; yWeight0=271;
xTotal=20; xTotal2=34; yTotal0=354;
xView=17; yView0=283;

procedure TDraftDlg.FormCreate(Sender: TObject);
begin
inherited;
InitButtons();
HelpContext:='CLASSES';
Caption:=Phrases.Lookup('TITLE_DRAFT');
OKBtn.Caption:=Phrases.Lookup('BTN_OK');

if not Phrases2FallenBackToEnglish then
  begin
  GroundArea.Hint:=Phrases2.Lookup('DRAFTDOMAIN',0);
  SeaArea.Hint:=Phrases2.Lookup('DRAFTDOMAIN',1);
  AirArea.Hint:=Phrases2.Lookup('DRAFTDOMAIN',2);
  end
else
  begin
  GroundArea.Hint:=Phrases.Lookup('DOMAIN',0);
  SeaArea.Hint:=Phrases.Lookup('DOMAIN',1);
  AirArea.Hint:=Phrases.Lookup('DOMAIN',2);
  end;

Back:=TBitmap.Create;
Back.PixelFormat:=pf24bit;
Back.Width:=ClientWidth; Back.Height:=ClientHeight;
Template:=TBitmap.Create;
LoadGraphicFile(Template, HomeDir+'Graphics\MiliRes', gfNoGamma);
Template.PixelFormat:=pf8bit;
end;

procedure TDraftDlg.FormDestroy(Sender: TObject);
begin
Template.Free;
end;

procedure TDraftDlg.CloseBtnClick(Sender: TObject);
begin
ModalResult:=mrCancel;
end;

procedure TDraftDlg.OffscreenPaint;

  function DomainAvailable(d: integer): boolean;
  begin
  result:=(upgrade[d,0].Preq=preNone)
    or (MyRO.Tech[upgrade[d,0].Preq]>=tsApplicable);
  end;

  procedure PaintTotalBars;
  var
  i,y,dx,num,w: integer;
  s: string;
  begin
  with offscreen.Canvas do
    begin
    // strength bar
    y:=yTotal;
    DarkGradient(Offscreen.Canvas,xTotal-6,y+1,184,2);
    DarkGradient(Offscreen.Canvas,xTotal2+172,y+1,95,2);
    RisedTextOut(Offscreen.Canvas,xTotal-2,y,Phrases.Lookup('UNITSTRENGTH'));
    RisedTextOut(Offscreen.Canvas,xTotal+112+30,y,'x'+IntToStr(MyRO.DevModel.MStrength));
    RisedTextOut(Offscreen.Canvas,xTotal2+148+30,y,'=');
    s:=IntToStr(MyRO.DevModel.Attack)+'/'+IntToStr(MyRO.DevModel.Defense);
    RisedTextOut(Offscreen.Canvas,xTotal2+170+64+30-BiColorTextWidth(Offscreen.Canvas,s),y,s);

    // transport bar
    if MyRO.DevModel.MTrans>0 then
      begin
      y:=yTotal+19;
      DarkGradient(Offscreen.Canvas,xTotal-6,y+1,184,1);
      DarkGradient(Offscreen.Canvas,xTotal2+172,y+1,95,1);
      RisedTextOut(Offscreen.Canvas,xTotal-2,y,Phrases.Lookup('UNITTRANSPORT'));
      RisedTextOut(Offscreen.Canvas,xTotal+112+30,y,'x'+IntToStr(MyRO.DevModel.MTrans));
      RisedTextOut(Offscreen.Canvas,xTotal2+148+30,y,'=');

      Font.Color:=$000000;
      dx:=-237-30;
      for i:=mcFirstNonCap-1 downto 3 do
        if i in [mcSeaTrans,mcCarrier,mcAirTrans] then
          begin
          num:=MyRO.DevModel.Cap[i]*MyRO.DevModel.MTrans;
          if num>0 then
            begin
            inc(dx,15);
            Brush.Color:=$C0C0C0;
            FrameRect(Rect(xTotal2-3-dx,y+2,xTotal2+11-dx,y+16));
            Brush.Style:=bsClear;
            Sprite(Offscreen,HGrSystem,xTotal2-1-dx,y+4,10,10,66+i mod 11 *11,137+i div 11 *11);
            if num>1 then
              begin
              s:=IntToStr(num);
              w:=TextWidth(s);
              inc(dx,w+1);
              Brush.Color:=$FFFFFF;
              FillRect(Rect(xTotal2-3-dx,y+2,xTotal2+w-1-dx,y+16));
              Brush.Style:=bsClear;
              Textout(xTotal2-3-dx+1,y,s);
              end;
            end;
          end
      end;

    // speed bar
    y:=yTotal+38;
    LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,y,Phrases.Lookup('UNITSPEED'));
    DLine(offscreen.Canvas,xTotal-2,xTotal+174,y+16,MainTexture.clBevelShade,
      MainTexture.clBevelLight);
    DLine(offscreen.Canvas,xTotal2+176,xTotal2+263,y+16,MainTexture.clBevelShade,
      MainTexture.clBevelLight);
    s:=MovementToString(MyRO.DevModel.Speed);
    RisedTextOut(offscreen.Canvas,xTotal2+170+64+30-TextWidth(s),y,s);

    // cost bar
    y:=yTotal+57;
    LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,y,Phrases.Lookup('UNITCOST'));
    LoweredTextOut(Offscreen.Canvas,-1,MainTexture,xTotal+112+30,y,'x'+IntToStr(MyRO.DevModel.MCost));
    LoweredTextOut(Offscreen.Canvas,-1,MainTexture,xTotal2+148+30,y,'=');
    DLine(offscreen.Canvas,xTotal-2,xTotal+174,y+16,MainTexture.clBevelShade,
      MainTexture.clBevelLight);
    DLine(offscreen.Canvas,xTotal2+176,xTotal2+263,y+16,MainTexture.clBevelShade,
      MainTexture.clBevelLight);
    s:=IntToStr(MyRO.DevModel.Cost);
    RisedTextOut(offscreen.Canvas,xTotal2+170+64+30-12-TextWidth(s),y,s);
    Sprite(offscreen,HGrSystem,xTotal2+170+54+30,y+4,10,10,88,115);

    if G.Difficulty[me]<>2 then
      begin // corrected cost bar
      y:=yTotal+76;
      LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,y,
        Phrases.Lookup('COSTDIFF'+char(48+G.Difficulty[me])));
      LoweredTextOut(Offscreen.Canvas,-1,MainTexture,xTotal2+148+30,y,'=');
      DLine(offscreen.Canvas,xTotal-2,xTotal+174,y+16,MainTexture.clBevelShade,
        MainTexture.clBevelLight);
      DLine(offscreen.Canvas,xTotal2+176,xTotal2+263,y+16,MainTexture.clBevelShade,
        MainTexture.clBevelLight);
      s:=IntToStr(MyRO.DevModel.Cost*BuildCostMod[G.Difficulty[me]] div 12);
      RisedTextOut(offscreen.Canvas,xTotal2+170+64+30-12-TextWidth(s),y,s);
      Sprite(offscreen,HGrSystem,xTotal2+170+54+30,y+4,10,10,88,115);
      end;
    end;
  end;

var
i,j,x,d,n,TextColor,CapWeight,DomainCount: integer;
begin
inherited;

ClientHeight:=Template.Height-Cut;
if ClientHeight>hMainTexture then // assemble background from 2 texture tiles
  begin
  bitblt(Back.Canvas.Handle,0,0,ClientWidth,64,MainTexture.Image.Canvas.Handle,
    (wMainTexture-ClientWidth) div 2,hMainTexture-64,SRCCOPY);
  bitblt(Back.Canvas.Handle,0,64,ClientWidth,ClientHeight-64,
    MainTexture.Image.Canvas.Handle,(wMainTexture-ClientWidth) div 2,0,SRCCOPY);
  end
else bitblt(Back.Canvas.Handle,0,0,ClientWidth,ClientHeight,MainTexture.Image.Canvas.Handle,
  (wMainTexture-ClientWidth) div 2,(hMainTexture-ClientHeight) div 2,SRCCOPY);
ImageOp_B(Back,Template,0,0,0,0,Template.Width,64);
ImageOp_B(Back,Template,0,64,0,64+Cut,Template.Width,Template.Height-64-Cut);

bitblt(offscreen.canvas.handle,0,0,ClientWidth,ClientHeight,Back.Canvas.handle,0,0,SRCCOPY);

offscreen.Canvas.Font.Assign(UniFont[ftCaption]);
RisedTextout(offscreen.Canvas,10,7,Caption);
offscreen.Canvas.Font.Assign(UniFont[ftSmall]);

with MyRO.DevModel do
  begin
  DomainCount:=0;
  for d:=0 to nDomains-1 do
    if DomainAvailable(d) then
      inc(DomainCount);
  if DomainCount>1 then
    begin
    for d:=0 to nDomains-1 do
      if DomainAvailable(d) then
        begin
        x:=xDomain+d*DomainPitch;
        if d=Domain then
          ImageOp_BCC(Offscreen,Templates,x,yDomain,142,246+37*d,36,36,0,$00C0FF)
        else ImageOp_BCC(Offscreen,Templates,x,yDomain,142,246+37*d,36,36,0,$606060);
        end;
    Frame(Offscreen.Canvas,xDomain-11,yDomain-3,xDomain+2*DomainPitch+46,
      yDomain+38,$B0B0B0,$FFFFFF);
    RFrame(Offscreen.Canvas,xDomain-12,yDomain-4,xDomain+2*DomainPitch+47,
      yDomain+39,$FFFFFF,$B0B0B0);
    end;
  GroundArea.Top:=yDomain;
  GroundArea.Visible:=DomainAvailable(dGround);
  SeaArea.Top:=yDomain;
  SeaArea.Visible:=DomainAvailable(dSea);
  AirArea.Top:=yDomain;
  AirArea.Visible:=DomainAvailable(dAir);

  PaintTotalBars;

  // display weight
  with offscreen.Canvas do
    begin
    for i:=0 to MaxWeight-1 do
      if i<Weight then
        ImageOp_BCC(Offscreen,Templates,xWeight+20*i,
          yWeight,123,400,18,20,0,$949494)
      else ImageOp_BCC(Offscreen,Templates,xWeight+20*i,
        yWeight,105,400,18,20,0,$949494);
    end;

  with offscreen.Canvas do for i:=0 to Lines-1 do
    begin
    if not (code[i] in AutoFeature) then
      begin
      // paint +/- butttons
      if code[i]<mcFirstNonCap then
        begin
        Dump(offscreen,HGrSystem,xFeature-21,yFeature+2+LinePitch*i,
          12,12,169,172);
        Dump(offscreen,HGrSystem,xFeature-9,yFeature+2+LinePitch*i,
          12,12,169,159);
        RFrame(offscreen.Canvas,xFeature-(21+1),yFeature+2+LinePitch*i-1,
          xFeature-(21-24),yFeature+2+LinePitch*i+12,
          MainTexture.clBevelShade,MainTexture.clBevelLight);
        end
      else
        begin
        Dump(offscreen,HGrSystem,xFeature-9,yFeature+2+LinePitch*i,
          12,12,169,185+13*MyRO.DevModel.Cap[code[i]]);
        RFrame(offscreen.Canvas,xFeature-(9+1),yFeature+2+LinePitch*i-1,
          xFeature-(21-24),yFeature+2+LinePitch*i+12,
          MainTexture.clBevelShade,MainTexture.clBevelLight);
        end;

      // paint cost
      LightGradient(offscreen.Canvas,xFeature+34,yFeature+LinePitch*i,50,
        GrExt[HGrSystem].Data.Canvas.Pixels[187,137]);
      if (Domain=dGround) and (code[i]=mcDefense) then CapWeight:=2
      else CapWeight:=Feature[code[i]].Weight;
      n:=CapWeight+Feature[code[i]].Cost;
      d:=6;
      while (n-1)*d*2>48-10 do dec(d);
      for j:=0 to n-1 do
        if j<CapWeight then
          Sprite(offscreen,HGrSystem,xFeature+54+(j*2+1-n)*d,
            yFeature+2+LinePitch*i+1,10,10,88,126)
          else Sprite(offscreen,HGrSystem,xFeature+54+(j*2+1-n)*d,
            yFeature+2+LinePitch*i+1,10,10,88,115);
      end; // if not (code[i] in AutoFeature)
    DarkGradient(offscreen.Canvas,xFeature+17,yFeature+LinePitch*i,16,1);
    Frame(offscreen.canvas,xFeature+18,yFeature+1+LinePitch*i,
      xFeature+20-2+13,yFeature+2+1-2+13+LinePitch*i,$C0C0C0,$C0C0C0);
    Sprite(offscreen,HGrSystem,xFeature+20,yFeature+2+1+LinePitch*i,
      10,10,66+code[i] mod 11 *11,137+code[i] div 11 *11);

    if MyRO.DevModel.Cap[code[i]]>0 then TextColor:=MainTexture.clLitText
    else TextColor:=-1;

    if code[i]<mcFirstNonCap then
      LoweredTextOut(offscreen.Canvas,TextColor,MainTexture,xFeature+7,
        yFeature+LinePitch*i-1,IntToStr(MyRO.DevModel.Cap[code[i]]));
    LoweredTextOut(offscreen.Canvas,TextColor,MainTexture,xFeature+88,
      yFeature+LinePitch*i-1,Phrases.Lookup('FEATURES',code[i]));
    end;
  end;

// free features
j:=0;
for i:=0 to nFeature-1 do
  if (i in AutoFeature)
    and (1 shl Domain and Feature[i].Domains<>0) and (Feature[i].Preq<>preNA)
    and ((Feature[i].Preq=preSun) and (MyRO.Wonder[woSun].EffectiveOwner=me)
      or (Feature[i].Preq>=0) and (MyRO.Tech[Feature[i].Preq]>=tsApplicable))
    and not ((Feature[i].Preq=adSteamEngine)
      and (MyRO.Tech[adNuclearPower]>=tsApplicable)) then
    begin
    DarkGradient(offscreen.Canvas,xWeight+4,yWeight+32+LinePitch*j,16,1);
    Frame(offscreen.canvas,xWeight+5,yWeight+33+LinePitch*j,
      xWeight+18,yWeight+47+LinePitch*j,$C0C0C0,$C0C0C0);
    Sprite(offscreen,HGrSystem,xWeight+7,yWeight+36+LinePitch*j,
      10,10,66+i mod 11 *11,137+i div 11 *11);
    LoweredTextOut(offscreen.Canvas,-1,MainTexture,xWeight+26,
      yWeight+31+LinePitch*j,Phrases.Lookup('FEATURES',i));
    inc(j);
    end;

with Tribe[me].ModelPicture[MyRO.nModel] do
  begin
  FrameImage(offscreen.canvas,BigImp,xView+4,yView+4,xSizeBig,ySizeBig,0,0);
  Sprite(offscreen,HGr,xView,yView,64,44,pix mod 10 *65+1,pix div 10*49+1);
  end;
MarkUsedOffscreen(ClientWidth,ClientHeight);
end;{MainPaint}

procedure TDraftDlg.SetDomain(d: integer);

  function Prio(fix: integer): integer;
  var
  FeaturePreq: integer;
  begin
  FeaturePreq:=Feature[fix].Preq;
  assert(FeaturePreq<>preNA);
  if fix<mcFirstNonCap then result:=10000+fix
  else if FeaturePreq=preNone then result:=20000
  else if FeaturePreq<0 then result:=40000
  else result:=30000+AdvValue[FeaturePreq];
  if not (fix in AutoFeature) then inc(result,90000);
  end;

var
i,j,x: integer;
begin
Domain:=d;
Lines:=0;
for i:=0 to nFeature-1 do
  if IsFeatureInList(Domain,i) then
    begin code[Lines]:=i; inc(Lines) end;
yFeature:=yFeature0+(MaxLines-Lines)*LinePitch div 2;

// sort features
for i:=0 to Lines-2 do for j:=i+1 to Lines-1 do
  if Prio(code[i])>Prio(code[j]) then
    begin // exchange
    x:=code[i];
    code[i]:=code[j];
    code[j]:=x
    end;
end;

function TDraftDlg.IsFeatureInList(d,i: integer): boolean;
begin
result:= not (i in AutoFeature)
  and (1 shl d and Feature[i].Domains<>0) and (Feature[i].Preq<>preNA)
  and ((Feature[i].Preq=preNone)
    or (Feature[i].Preq=preSun) and (MyRO.Wonder[woSun].EffectiveOwner=me)
    or (Feature[i].Preq>=0) and (MyRO.Tech[Feature[i].Preq]>=tsApplicable));
end;

procedure TDraftDlg.FormShow(Sender: TObject);
var
count,d,i: integer;
begin
Domain:=dGround;
while (Domain<dAir) and (upgrade[Domain,0].Preq<>preNone)
  and (MyRO.Tech[upgrade[Domain,0].Preq]<tsApplicable) do inc(Domain);

// count max number of features in any domain
MaxLines:=0;
for d:=0 to nDomains-1 do
  if (upgrade[d,0].Preq=preNone)
    or (MyRO.Tech[upgrade[d,0].Preq]>=tsApplicable) then
    begin
    count:=0;
    for i:=0 to nFeature-1 do
      if IsFeatureInList(d,i) then
        inc(count);
    if count>MaxLines then
      MaxLines:=count;
    end;
Cut:=(MaxLines0-MaxLines)*LinePitch;
OKBtn.Top:=477-Cut;
yDomain:=yDomain0-Cut;
yWeight:=yWeight0-Cut;
yTotal:=yTotal0-Cut;
yView:=yView0-Cut;

if WindowMode=wmModal then
  begin {center on screen}
  Left:=(Screen.Width-Template.Width) div 2;
  Top:=(Screen.Height-(Template.Height-Cut)) div 2;
  end;

SetDomain(Domain);
Server(sCreateDevModel,me,Domain,nil^);
MyModel[MyRO.nModel]:=MyRO.DevModel;
InitMyModel(MyRO.nModel,false);
OffscreenPaint;
IncCap:=-1; DecCap:=-1;
end;

procedure TDraftDlg.ShowNewContent(NewMode: integer);
begin
inherited ShowNewContent(NewMode);
end;

procedure TDraftDlg.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
var
i,d: integer;
begin
if Button=mbLeft then
  begin
  for d:=0 to nDomains-1 do
    if (d<>Domain) and ((upgrade[d,0].Preq=preNone)
      or (MyRO.Tech[upgrade[d,0].Preq]>=tsApplicable))
      and (x>=xDomain+d*DomainPitch) and (x<xDomain+d*DomainPitch+36)
      and (y>=yDomain) and (y<yDomain+36) then
      begin
      SetDomain(d);
      Server(sCreateDevModel,me,Domain,nil^);
      MyModel[MyRO.nModel]:=MyRO.DevModel;
      InitMyModel(MyRO.nModel,false);
      SmartUpdateContent;
      end;

  if (y>=yFeature) and (y<yFeature+LinePitch*Lines) then
    begin
    i:=(y-yFeature) div LinePitch;
    if (x>=xFeature-21) and (x<ClientWidth) and (ssShift in Shift) then
      HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkFeature, code[i])
    else if not (code[i] in AutoFeature) then
      begin
      if (code[i]<mcFirstNonCap) and (x>=xFeature-21) and (x<xFeature-21+12) then
        begin
        IncCap:=code[i];
        Dump(offscreen,HGrSystem,xFeature-21,yFeature+2+LinePitch*i,12,12,182,172);
        SmartInvalidate;
        end
      else if (x>=xFeature-9) and (x<xFeature-9+12) then
        begin
        DecCap:=code[i];
        if code[i]<mcFirstNonCap then
          Dump(offscreen,HGrSystem,xFeature-9,yFeature+2+LinePitch*i,12,12,182,159)
        else Dump(offscreen,HGrSystem,xFeature-9,yFeature+2+LinePitch*i,
          12,12,182,185+13*MyRO.DevModel.Cap[code[i]]);
        SmartInvalidate;
        end;
      end
    end
  end
end;

procedure TDraftDlg.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; x, y: integer);
var
NewValue: integer;
begin
if IncCap>=0 then
  begin
  NewValue:=MyRO.DevModel.Cap[IncCap]+1;
  Server(sSetDevModelCap+NewValue shl 4,me,IncCap,nil^);
  MyModel[MyRO.nModel]:=MyRO.DevModel;
  InitMyModel(MyRO.nModel,false);
  SmartUpdateContent;
  IncCap:=-1;
  end
else if DecCap>=0 then
  begin
  if (DecCap>=mcFirstNonCap) or (MyRO.DevModel.Cap[DecCap]>0) then
    begin
    NewValue:=MyRO.DevModel.Cap[DecCap]-1;
    if DecCap>=mcFirstNonCap then NewValue:=-NewValue;
    Server(sSetDevModelCap+NewValue shl 4,me,DecCap,nil^);
    MyModel[MyRO.nModel]:=MyRO.DevModel;
    InitMyModel(MyRO.nModel,false);
    end;
  SmartUpdateContent;
  DecCap:=-1;
  end;
end;

procedure TDraftDlg.OKBtnClick(Sender: TObject);
begin
ModalResult:=mrOK;
end;

end.

