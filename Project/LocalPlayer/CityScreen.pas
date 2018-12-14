{$INCLUDE switches}

unit CityScreen;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,IsoEngine,BaseWin,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,ExtCtrls,ButtonA,
  ButtonB, ButtonBase, ButtonC, Area;

const
WM_PLAYSOUND=WM_USER;

type
  TCityCloseAction=(None, RestoreFocus, StepFocus);

  TCityDlg = class(TBufferedDrawDlg)
    Timer1: TTimer;
    CloseBtn: TButtonA;
    PrevCityBtn: TButtonC;
    NextCityBtn: TButtonC;
    PageUpBtn: TButtonC;
    PageDownBtn: TButtonC;
    BuyBtn: TButtonC;
    ProjectArea: TArea;
    PrimacyArea: TArea;
    Imp2Area: TArea;
    Imp4Area: TArea;
    Imp0Area: TArea;
    Imp3Area: TArea;
    Imp5Area: TArea;
    Imp1Area: TArea;
    Pop0Area: TArea;
    Pop1Area: TArea;
    SupportArea: TArea;
    procedure FormCreate(Sender:TObject);
    procedure FormDestroy(Sender:TObject);
    procedure FormMouseDown(Sender:TObject;Button:TMouseButton;
      Shift:TShiftState;x,y:integer);
    procedure BuyClick(Sender:TObject);
    procedure CloseBtnClick(Sender:TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure NextCityBtnClick(Sender: TObject);
    procedure PrevCityBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    //procedure AdviceBtnClick(Sender: TObject);
    procedure PageUpBtnClick(Sender: TObject);
    procedure PageDownBtnClick(Sender: TObject);

  public
    RestoreUnFocus: integer;
    CloseAction: TCityCloseAction;
    procedure OffscreenPaint; override;
    procedure ShowNewContent(NewMode,Loc: integer; ShowEvent: cardinal);
    procedure Reset;
    procedure CheckAge;

  private
    c: TCity;
    Report:TCityReportNew;
    cOwner,cGov,
    emix{enemy model index of produced unit},
    cix,cLoc,Mode,ZoomArea,Page,PageCount,BlinkTime,OpenSoundEvent,
      SizeClass,AgePrepared: integer;
    Optimize_cixTileChange,Optimize_TilesBeforeChange: integer;
    Happened: cardinal;
    imix:array[0..15] of integer;
    CityAreaInfo: TCityAreaInfo;
    AreaMap: TIsoMap;
    CityMapTemplate, SmallCityMapTemplate, Back, SmallCityMap, ZoomCityMap, Template: TBitmap;
    IsPort,ProdHint,AllowChange: boolean;
    procedure InitSmallCityMap;
    procedure InitZoomCityMap;
    procedure ChooseProject;
    procedure ChangeCity(d: integer);
    procedure ChangeResourceWeights(iResourceWeights: integer);
    procedure OnPlaySound(var Msg:TMessage); message WM_PLAYSOUND;
  end;

var
  CityDlg:TCityDlg;

implementation

uses
  Select,Messg,MessgEx,Help,Inp,Tribes,Directories,

  Math;

{$R *.DFM}

const
{modes}
mSupp=1; mImp=2;

wBar=106;
xDiv=400; xService=296;
xmArea=197; ymArea=170;
xView=326; yView=275;
dxBar=wBar+12; dyBar=39;
xHapp=404; yHapp=9;
xFood=404; yFood=yHapp+3*dyBar+6;
xProd=404; yProd=yFood+3*dyBar+6;
xTrade=404; yTrade=yProd+2*dyBar+22;
xPoll=xmArea-186; yPoll=ymArea+64;
xmOpt=40; ymOpt=ymArea+96+34;
xSmallMap=271; ySmallMap=339; wSmallMap=98; hSmallMap=74;
xSupport=xSmallMap; ySupport=ySmallmap+hSmallmap+2; wSupport=64; hSupport=18;
xZoomMap=34; yZoomMap=338; wZoomMap=228; hZoomMap=124; wZoomEnvironment=68;

ImpPosition: array[28..nImp-1] of integer=
(-1, //imTrGoods
21, //imBarracks
6, //imGranary
1, //imTemple
7, //imMarket
14, //imLibrary
8, //imCourt
18, //imWalls
10, //imAqueduct
11, //imBank
5, //imCathedral
13, //imUniversity
29, //imHarbor
2, //imTheater
24, //imFactory
25, //imMfgPlant
28, //imRecycling
27, //imPower
27, //imHydro
27, //imNuclear
26, //imPlatform
8, //imTownHall
10, //imSewer
3, //imSupermarket
17, //imHighways
15, //imResLab
19, //imMissileBat
23, //imCoastalFort
22, //imAirport
20, //imDockyard
8, //imPalace
-1, //imGrWall
4, //imColosseum
16, //imObservatory
21, //imMilAcademy
-1, //imBunker
-1, //imAlgae
9, //imStockEx
-1, //imSpacePort
-1, //imShipComp
-1, //imShipPow
-1); //imShipHab


var
ImpSorted: array[0..nImp-1] of integer;


procedure TCityDlg.FormCreate(Sender:TObject);
begin
inherited;
AreaMap:=TIsoMap.Create;
AreaMap.SetOutput(offscreen);
AreaMap.SetPaintBounds(xmArea-192,ymArea-96-32,xmArea+192,ymArea+96);
Mode:=mImp;
ZoomArea:=1;
ProdHint:=false;
RestoreUnFocus:=-1;
OpenSoundEvent:=-1;
AgePrepared:=-2;
Optimize_cixTileChange:=-1;
InitButtons();
//InitWindowRegion;
CloseBtn.Caption:=Phrases.Lookup('BTN_OK');
BuyBtn.Hint:=Phrases.Lookup('BTN_BUY');
if not Phrases2FallenBackToEnglish then
  SupportArea.Hint:=Phrases2.Lookup('TIP_SUPUNITS')
else SupportArea.Hint:=Phrases.Lookup('SUPUNITS');
if not Phrases2FallenBackToEnglish then
  begin
  Pop0Area.Hint:=Phrases2.Lookup('TIP_WORKING');
  Pop1Area.Hint:=Phrases2.Lookup('TIP_CIVIL');
  PrimacyArea.Hint:=Phrases2.Lookup('TIP_PRIMACY');
  ProjectArea.Hint:=Phrases2.Lookup('TIP_PROJECT');
  end;

Back:=TBitmap.Create;
Back.PixelFormat:=pf24bit;
Back.Width:=ClientWidth; Back.Height:=ClientHeight;
Template:=TBitmap.Create;
LoadGraphicFile(Template, HomeDir+'Graphics\City', gfNoGamma);
Template.PixelFormat:=pf8bit;
CityMapTemplate:=TBitmap.Create;
LoadGraphicFile(CityMapTemplate, HomeDir+'Graphics\BigCityMap', gfNoGamma);
CityMapTemplate.PixelFormat:=pf8bit;
SmallCityMapTemplate:=TBitmap.Create;
LoadGraphicFile(SmallCityMapTemplate, HomeDir+'Graphics\SmallCityMap', gfNoGamma);
SmallCityMapTemplate.PixelFormat:=pf24bit;
SmallCityMap:=TBitmap.Create;
SmallCityMap.PixelFormat:=pf24bit;
SmallCityMap.Width:=98; SmallCityMap.Height:=74;
ZoomCityMap:=TBitmap.Create;
ZoomCityMap.PixelFormat:=pf24bit;
ZoomCityMap.Width:=228; ZoomCityMap.Height:=124;
end;

procedure TCityDlg.FormDestroy(Sender:TObject);
begin
AreaMap.Free;
SmallCityMap.Free;
ZoomCityMap.Free;
CityMapTemplate.Free;
Template.Free;
Back.Free;
end;

procedure TCityDlg.Reset;
begin
Mode:=mImp;
ZoomArea:=1;
end;

procedure TCityDlg.CheckAge;
begin
if MainTextureAge<>AgePrepared then
  begin
  AgePrepared:=MainTextureAge;
  bitblt(Back.Canvas.Handle,0,0,ClientWidth,ClientHeight,
    MainTexture.Image.Canvas.Handle,0,0,SRCCOPY);
  ImageOp_B(Back,Template,0,0,0,0,ClientWidth,ClientHeight);
  end
end;

procedure TCityDlg.CloseBtnClick(Sender:TObject);
begin
Close
end;

procedure TCityDlg.InitSmallCityMap;
var
i,iix,cli1,Color0,Color1,Color2: integer;
begin
if cix>=0 then c:=MyCity[cix];
case MyMap[cLoc] and fTerrain of
  fPrairie: cli1:=cliPrairie;
  fHills: cli1:=cliHills;
  fTundra: cli1:=cliTundra;
  else cli1:=cliPlains;
  end;
Color0:=Colors.Canvas.Pixels[clkAge0+Age,cliRoad];
Color1:=Colors.Canvas.Pixels[clkCity,cli1];
Color2:=Colors.Canvas.Pixels[clkAge0+Age,cliHouse];
BitBlt(SmallCityMap.Canvas.Handle,0,0,83,hSmallMap,SmallCityMapTemplate.Canvas.Handle,83*SizeClass,0,SRCCOPY);
if IsPort then
  begin
  BitBlt(SmallCityMap.Canvas.Handle,83,0,15,hSmallMap,SmallCityMapTemplate.Canvas.Handle,332+15,0,SRCCOPY);
  ImageOp_CCC(SmallCityMap,0,0,83,hSmallMap,Color0,Color1,Color2);
  Color2:=Colors.Canvas.Pixels[clkCity,cliWater];
  ImageOp_CCC(SmallCityMap,83,0,15,hSmallMap,Color0,Color1,Color2);
  end
else
  begin
  BitBlt(SmallCityMap.Canvas.Handle,83,0,15,hSmallMap,SmallCityMapTemplate.Canvas.Handle,332,0,SRCCOPY);
  ImageOp_CCC(SmallCityMap,0,0,wSmallMap,hSmallMap,Color0,Color1,Color2);
  end;

with SmallCityMap.canvas do
  begin
  brush.Color:=Colors.Canvas.Pixels[clkAge0+Age,cliImp];
  for i:=0 to 29 do
    begin
    for iix:=28 to nImp-1 do
      if (ImpPosition[iix]=i) and (c.Built[iix]>0) then
        begin
        FillRect(Rect(5+16*(i mod 3)+48*(i div 18), 3+12*(i mod 18 div 3),
          13+16*(i mod 3)+48*(i div 18), 11+12*(i mod 18 div 3)));
        break;
        end
    end;
  i:=30;
  for iix:=0 to nImp do
    if (c.Built[iix]>0) and ((iix<28) or (ImpPosition[iix]<0)) then
      begin
      FillRect(Rect(5+16*(i mod 3)+48*(i div 18), 3+12*(i mod 18 div 3),
        13+16*(i mod 3)+48*(i div 18), 11+12*(i mod 18 div 3)));
      inc(i);
      if i=36 then break; // area is full
      end;
  if c.Project and cpImp<>0 then
    begin
    iix:=c.Project and cpIndex;
    if iix<>imTrGoods then
      begin
      if (iix>=28) and (ImpPosition[iix]>=0) then
        i:=ImpPosition[iix];
      if i<36 then
        begin
        brush.Color:=Colors.Canvas.Pixels[clkAge0+Age,cliImpProject];
        FillRect(Rect(5+16*(i mod 3)+48*(i div 18), 3+12*(i mod 18 div 3),
          13+16*(i mod 3)+48*(i div 18), 11+12*(i mod 18 div 3)));
        end
      end
    end;
  brush.style:=bsClear;
  end
end;

procedure TCityDlg.InitZoomCityMap;
begin
bitblt(ZoomCityMap.canvas.handle,0,0,wZoomMap,hZoomMap,Back.Canvas.handle,
  xZoomMap,yZoomMap,SRCCOPY);
if Mode=mImp then
  begin
  if ZoomArea<3 then
    ImageOp_B(ZoomCityMap,CityMapTemplate,0,0,376*SizeClass,
      112*ZoomArea,wZoomMap,hZoomMap)
  else
    begin
    ImageOp_B(ZoomCityMap,CityMapTemplate,0,0,376*SizeClass+216,
      112*(ZoomArea-3),wZoomMap-wZoomEnvironment,hZoomMap);
    ImageOp_B(ZoomCityMap,CityMapTemplate,wZoomMap-wZoomEnvironment,0,
      1504+wZoomEnvironment*byte(IsPort),112*(ZoomArea-3),wZoomEnvironment,hZoomMap);
    end;
  end  
end;

procedure TCityDlg.OffscreenPaint;

  procedure FillBar(x,y,pos,Growth,max,Kind: integer; IndicateComplete: boolean);
  var
  Tex: TTexture;
  begin
  Tex:=MainTexture;
  if Kind=3 then
    begin
    Tex.clBevelLight:=GrExt[HGrSystem].Data.Canvas.Pixels[104,36];
    Tex.clBevelShade:=Tex.clBevelLight;
    end;
  PaintRelativeProgressBar(offscreen.Canvas,Kind,x-3,y,wBar-4,pos,Growth,max,
    IndicateComplete,Tex);
  end;

  procedure PaintResources(x,y,Loc:integer; Add4Happy: boolean);
  var
  d,i,Total,xGr,yGr:integer;
  TileInfo:TTileInfo;
  rare: boolean;
  begin
  if Server(sGetCityTileInfo,me,Loc,TileInfo)<>eOk then
    begin assert(cix<0); exit end;
  Total:=TileInfo.Food+TileInfo.Prod+TileInfo.Trade;
  rare:=MyMap[Loc] and $06000000>0;
  if rare then
    inc(Total);
  if Add4Happy then
    inc(Total,4);
  if Total>1 then d:=(xxt-11) div (Total-1);
  if d<1 then d:=1;
  if d>4 then d:=4;
  for i:=0 to Total-1 do
    begin
    yGr:=115;
    if Add4Happy and (i>=Total-4) then
      begin xGr:=132; yGr:=126 end
    else if rare and (i=Total-1) then xGr:=66+110
    else if i>=TileInfo.Food+TileInfo.Prod then xGr:=66+44
    else if i>=TileInfo.Prod then xGr:=66
    else xGr:=66+22;
    Sprite(offscreen,HGrSystem,x+xxt-5+d*(2*i+1-Total),y+yyt-5,10,10,xGr,yGr);
    end
  end;

  procedure MakeRed(x,y,w,h: integer);
  type
  TLine=array[0..99999,0..2] of Byte;
  PLine=^TLine;

    procedure RedLine(line: PLine; length: integer);
    var
    i,gray: integer;
    begin
    for i:=0 to length-1 do
      begin
      gray:=(integer(line[i,0])+integer(line[i,1])+integer(line[i,2])) *85 shr 8;
      line[i,0]:=0;
      line[i,1]:=0;
      line[i,2]:=gray; //255-(255-gray) div 2;
      end
    end;

  var
  i: integer;              
  begin
  for i:=0 to h-1 do
    RedLine(@(PLine(Offscreen.ScanLine[y+i])[x]),w)
  end;

var
line, MessageCount: integer;

  procedure CheckMessage(Flag: integer);
  var
  i, test: integer;
  s: string;
  begin
  if Happened and Flag<>0 then
    begin
    i:=0;
    test:=1;
    while test<Flag do begin inc(i); inc(test,test) end;

    if AllowChange and (Sounds<>nil) and (OpenSoundEvent=-1) then
      begin
      s:=CityEventSoundItem[i];
      if s<>'' then s:=Sounds.Lookup(s);
      if (Flag=chProduction) or (s<>'') and (s[1]<>'*') and (s[1]<>'[') then
        OpenSoundEvent:=i
      end;

    s:=CityEventName(i);
{    if Flag=chNoGrowthWarning then
      if c.Built[imAqueduct]=0 then
        s:=Format(s,[Phrases.Lookup('IMPROVEMENTS',imAqueduct)])
      else s:=Format(s,[Phrases.Lookup('IMPROVEMENTS',imSewer)]);}
    RisedTextOut(offscreen.Canvas,xmOpt+40,ymOpt-1-8*MessageCount+16*line,s);
    inc(line)
    end
  end;

var
x,y,xGr,i,i1,j,iix,d,dx,dy,PrCost,Cnt,Loc1,FreeSupp,Paintiix,HappyGain,
  OptiType,rx,ry,TrueFood,TrueProd,TruePoll: integer;
PrName,s:string;
UnitInfo: TUnitInfo;
UnitReport: TUnitReport;
RedTex: TTexture;
IsCityAlive,CanGrow: boolean;
begin
inherited;
if cix>=0 then c:=MyCity[cix];
Report.HypoTiles:=-1;
Report.HypoTaxRate:=-1;
Report.HypoLuxuryRate:=-1;
if cix>=0 then Server(sGetCityReportNew,me,cix,Report) // own city
else Server(sGetEnemyCityReportNew,me,cLoc,Report); // enemy city
TrueFood:=c.Food;
TrueProd:=c.Prod;
TruePoll:=c.Pollution;
if supervising or (cix<0) then
  begin // normalize city from after-turn state
  dec(TrueFood,Report.FoodSurplus);
  if TrueFood<0 then
    TrueFood:=0; // shouldn't happen
  dec(TrueProd,Report.Production);
  if TrueProd<0 then
    TrueProd:=0; // shouldn't happen
  dec(TruePoll,Report.AddPollution);
  if TruePoll<0 then
    TruePoll:=0; // shouldn't happen
  end;
IsCityAlive:= (cGov<>gAnarchy) and (c.Flags and chCaptured=0);
if not IsCityAlive then Report.Working:=c.Size;

RedTex:=MainTexture;
RedTex.clBevelLight:=$0000FF;
RedTex.clBevelShade:=$000000;
RedTex.clTextLight:=$000000;
RedTex.clTextShade:=$0000FF;

bitblt(offscreen.canvas.handle,0,0,640,480,Back.Canvas.handle,0,0,SRCCOPY);

offscreen.Canvas.Font.Assign(UniFont[ftCaption]);
RisedTextout(offscreen.Canvas,42,7,Caption);
with offscreen.canvas do
  begin // city size
  brush.color:=$000000;
  fillrect(rect(8+1,7+1,36+1,32+1));
  brush.color:=$FFFFFF;
  fillrect(rect(8,7,36,32));
  brush.style:=bsClear;
  font.color:=$000000;
  s:=inttostr(c.Size);
  TextOut(8+14-textwidth(s) div 2, 7, s);
  end;
offscreen.Canvas.Font.Assign(UniFont[ftSmall]);

if not IsCityAlive then
  begin
  MakeRed(18,280,298,40);
  if cGov=gAnarchy then s:=Phrases.Lookup('GOVERNMENT',gAnarchy)
  else {if c.Flags and chCaptured<>0 then}
    s:=Phrases.Lookup('CITYEVENTS',14);
  RisedTextout(offscreen.canvas,167-BiColorTextWidth(offscreen.canvas,s) div 2,ymOpt-9, s);
  end
else if AllowChange then
  begin
  OptiType:=c.Status shr 4 and $0F;
  Sprite(offscreen,HGrSystem2,xmOpt-32,ymOpt-32,64,64,1+OptiType mod 3*64,217+OptiType div 3*64);

  {display messages now}
  MessageCount:=0;
  for i:=0 to 31 do
    if Happened and ($FFFFFFFF-chCaptured) and (1 shl i)<>0 then
      inc(MessageCount);
  if MessageCount>3 then
    MessageCount:=3;
  if MessageCount>0 then
    begin
    MakeBlue(Offscreen,74,280,242,40);
    line:=0;
    for i:=0 to nCityEventPriority-1 do
      if line<MessageCount then
        CheckMessage(CityEventPriority[i]);
    end
  else
    begin
    s:=Phrases.Lookup('CITYMANAGETYPE',OptiType);
    j:=pos('\',s);
    if j=0 then
      LoweredTextout(offscreen.canvas, -1, MainTexture, xmOpt+40, ymOpt-9, s)
    else
      begin
      LoweredTextout(offscreen.canvas, -1, MainTexture, xmOpt+40, ymOpt-17,
        copy(s,1,j-1));
      LoweredTextout(offscreen.canvas, -1, MainTexture, xmOpt+40, ymOpt-1,
        copy(s,j+1,255));
      end
    end
  end;

rx:=(192+xxt*2-1) div (xxt*2);
ry:=(96+yyt*2-1) div (yyt*2);
AreaMap.Paint(xmArea-xxt*2*rx,ymArea-yyt*2*ry-3*yyt,dLoc(cLoc,-2*rx+1,-2*ry-1),4*rx-1,4*ry+1,cLoc,cOwner,
  false,AllowChange and IsCityAlive and (c.Status and csResourceWeightsMask=0));
bitblt(offscreen.canvas.handle,xmArea+102,42,90,33,Back.Canvas.handle,xmArea+102,42,SRCCOPY);

if IsCityAlive then
  for dy:=-3 to 3 do for dx:=-3 to 3 do
    if ((dx+dy) and 1=0) and (dx*dx*dy*dy<81) then
      begin
      Loc1:=dLoc(cLoc,dx,dy);
      if (CityAreaInfo.Available[(dy+3) shl 2+(dx+3) shr 1] in [faNotAvailable,faTreaty,faInvalid])
        and ((Loc1<0) or (Loc1>=G.lx*G.ly) or (MyMap[Loc1] and fCity=0)) then
        Sprite(offscreen,HGrTerrain,xmArea-xxt+xxt*dx,ymArea-yyt+yyt*dy,xxt*2,
          yyt*2,1+5*(xxt*2+1),1+yyt+15*(yyt*3+1));
      if (1 shl((dy+3) shl 2+(dx+3) shr 1) and c.Tiles<>0) then
        PaintResources(xmArea-xxt+xxt*dx,ymArea-yyt+yyt*dy,Loc1,(dx=0) and (dy=0));
      end;

if Report.Working>1 then d:=(xService-(xmArea-192)-8-32) div(Report.Working-1);
if d>28 then d:=28;
for i:=Report.Working-1 downto 0 do
  begin
  if IsCityAlive then xGr:=29
  else xGr:=141;
  BitBlt(offscreen.Canvas.Handle,xmArea-192+5+i*d,ymArea-96-29,
    27,30,GrExt[HGrSystem].Mask.Canvas.Handle,xGr,171,SRCAND); {shadow}
  Sprite(offscreen,HGrSystem,xmArea-192+4+i*d,ymArea-96-30,27,30,xGr,171);
  end;
if c.Size-Report.Working>1 then d:=(xmArea+192-xService-32) div(c.Size-Report.Working-1);
if d>28 then d:=28;
for i:=0 to c.Size-Report.Working-1 do
  begin
  xGr:=1+112;
  BitBlt(offscreen.Canvas.Handle,xmArea+192-27+1-i*d,29+1,
    27,30,GrExt[HGrSystem].Mask.Canvas.Handle,xGr,171,SRCAND); {shadow}
  Sprite(offscreen,HGrSystem,xmArea+192-27-i*d,29,27,30,xGr,171);
  Sprite(offscreen,HGrSystem,xmArea+192-27+4-i*d,29+32,10,10,121,126);
  Sprite(offscreen,HGrSystem,xmArea+192-27+13-i*d,29+32,10,10,121,126);
//  Sprite(offscreen,HGrSystem,xmArea+192-31+18-i*d,ymArea-96-80+32,10,10,88,115);
  end;

if c.Project and cpImp=0 then
  PrName:=Tribe[cOwner].ModelName[c.Project and cpIndex]
else PrName:=Phrases.Lookup('IMPROVEMENTS',c.Project and cpIndex);
PrCost:=Report.ProjectCost;

// happiness section
if IsCityAlive then
  begin
  if cGov=gFundamentalism then
    CountBar(offscreen,xHapp,yHapp+dyBar,wBar,17,Phrases.Lookup('FAITH'),
      Report.CollectedControl,MainTexture)
  else
    begin
    CountBar(offscreen,xHapp,yHapp+dyBar,wBar,17,Phrases.Lookup('HAPPINESS'),
      Report.Morale,MainTexture);
    CountBar(offscreen,xHapp,yHapp+2*dyBar,wBar,16,Phrases.Lookup('CONTROL'),
      Report.CollectedControl,MainTexture);
    end;
  CountBar(offscreen,xHapp,yHapp,wBar,8,Phrases.Lookup('LUX'),
    Report.Luxury,MainTexture);
  CountBar(offscreen,xHapp+dxBar,yHapp,wBar,19,Phrases.Lookup('UNREST'),
    2*Report.Deployed,MainTexture);
  CountBar(offscreen,xHapp+dxBar,yHapp+dyBar,wBar,17,Phrases.Lookup('HAPPINESSDEMAND'),
    c.Size,MainTexture);
  if Report.HappinessBalance>=0 then
    CountBar(offscreen,xHapp+dxBar,yHapp+2*dyBar,wBar,17,Phrases.Lookup('HAPPINESSPLUS'),
      Report.HappinessBalance,MainTexture)
  else
    begin
    MakeRed(xHapp+dxBar-6,yHapp+2*dyBar,wBar+10,38);
    CountBar(offscreen,xHapp+dxBar,yHapp+2*dyBar,wBar,18,Phrases.Lookup('LACK'),
      -Report.HappinessBalance,RedTex);
    end;
  end;

// food section
if IsCityAlive then
  begin
  CountBar(offscreen,xFood,yFood+dyBar div 2,wBar,0,Phrases.Lookup('FOOD'),Report.CollectedFood,MainTexture);
  CountBar(offscreen,xFood+dxBar,yFood+dyBar,wBar,0,Phrases.Lookup('DEMAND'),2*c.Size,MainTexture);
  CountBar(offscreen,xFood+dxBar,yFood,wBar,0,Phrases.Lookup('SUPPORT'),Report.FoodSupport,MainTexture);
  if Report.FoodSurplus>=0 then
    if (cGov=gFuture)
      or (c.Size>=NeedAqueductSize) and (Report.FoodSurplus<2) then
      CountBar(offscreen,xFood+dxBar,yFood+2*dyBar,wBar,6,Phrases.Lookup('PROFIT'),
        Report.FoodSurplus,MainTexture)
    else CountBar(offscreen,xFood+dxBar,yFood+2*dyBar,wBar,0,Phrases.Lookup('SURPLUS'),
      Report.FoodSurplus,MainTexture)
  else
    begin
    MakeRed(xFood+dxBar-6,yFood+2*dyBar,wBar+10,38);
    CountBar(offscreen,xFood+dxBar,yFood+2*dyBar,wBar,1,Phrases.Lookup('LACK'),
      -Report.FoodSurplus,RedTex);
    end;
  end;
CanGrow:= (c.Size<MaxCitySize) and (cGov<>gFuture)
  and (Report.FoodSurplus>0)
  and ((c.Size<NeedAqueductSize)
    or (c.Built[imAqueduct]=1) and (c.Size<NeedSewerSize)
    or (c.Built[imSewer]=1));
FillBar(xFood+3,yFood+102,TrueFood,
  CutCityFoodSurplus(Report.FoodSurplus,IsCityAlive,cGov,c.size),
  Report.Storage,1,CanGrow);
LoweredTextOut(offscreen.Canvas,-1,MainTexture,xFood+3-5,yFood+102-20,Format('%d/%d',[TrueFood,Report.Storage]));
LoweredTextOut(offscreen.Canvas,-1,MainTexture,xFood-2,yFood+66,Phrases.Lookup('STORAGE'));

// production section
if IsCityAlive then
  begin
  CountBar(offscreen,xProd,yProd,wBar,2,Phrases.Lookup('MATERIAL'),
    Report.CollectedMaterial,MainTexture);
  CountBar(offscreen,xProd+dxBar,yProd,wBar,2,Phrases.Lookup('SUPPORT'),
    Report.MaterialSupport,MainTexture);
  if Report.Production>=0 then
    if c.Project and (cpImp+cpIndex)=cpImp+imTrGoods then
      CountBar(offscreen,xProd+dxBar,yProd+dyBar+16,wBar,6,Phrases.Lookup('PROFIT'),
        Report.Production,MainTexture)
    else CountBar(offscreen,xProd+dxBar,yProd+dyBar+16,wBar,2,Phrases.Lookup('PROD'),
      Report.Production,MainTexture)
  else
    begin
    MakeRed(xProd+dxBar-6,yProd+dyBar,wBar+10,38);
    CountBar(offscreen,xProd+dxBar,yProd+dyBar+16,wBar,3,Phrases.Lookup('LACK'),
      -Report.Production,RedTex);
    end;
  end;
if c.Project and (cpImp+cpIndex)<>cpImp+imTrGoods then with offscreen.Canvas do
  begin
  i:=Report.Production;
  if (i<0) or not IsCityAlive then i:=0;
  FillBar(xProd+3,yProd+16+63,TrueProd,i,PrCost,4,true);
  LoweredTextOut(offscreen.Canvas,-1,MainTexture,xProd+3-5,yProd+16+43,
    Format('%d/%d',[TrueProd,PrCost]));
  if BiColorTextWidth(offscreen.Canvas,PrName)>wBar+dxBar then
    begin
    repeat Delete(PrName,Length(PrName),1)
    until BiColorTextWidth(offscreen.Canvas,PrName)<=wBar+dxBar;
    PrName:=PrName+'.'
    end;
  end;
RisedTextOut(offscreen.Canvas,xProd-2,yProd+36,PrName);

// pollution section
if IsCityAlive and (Report.AddPollution>0) then
  begin
  FillBar(xPoll+3,yPoll+20,TruePoll,Report.AddPollution,
    MaxPollution,3,true);
  RisedTextOut(offscreen.Canvas,xPoll+3-5,yPoll+20-20,Phrases.Lookup('POLL'));
  end;

// trade section
if IsCityAlive and (Report.CollectedTrade>0) then
  begin
  CountBar(offscreen,xTrade,yTrade+dyBar div 2,wBar,4,Phrases.Lookup('TRADE'),Report.CollectedTrade,MainTexture);
  CountBar(offscreen,xTrade+dxBar,yTrade+2*dyBar,wBar,5,Phrases.Lookup('CORR'),Report.Corruption,MainTexture);
  CountBar(offscreen,xTrade+dxBar,yTrade,wBar,6,Phrases.Lookup('TAX'),Report.Tax,MainTexture);
  CountBar(offscreen,xTrade+dxBar,yTrade+dyBar,wBar,12,Phrases.Lookup('SCIENCE'),Report.Science,MainTexture);
  end;

// small map
BitBlt(Offscreen.Canvas.Handle,xSmallMap,ySmallmap,wSmallMap,hSmallMap,SmallCitymap.Canvas.Handle,0,0,SRCCOPY);
if Mode=mImp then
  Frame(Offscreen.Canvas,xSmallMap+48*(ZoomArea div 3),ySmallmap+24*(ZoomArea mod 3),
    xSmallMap+48*(ZoomArea div 3)+49,ySmallmap+24*(ZoomArea mod 3)+25,
    MainTexture.clMark,MainTexture.clMark);
Frame(Offscreen.Canvas,xSmallMap-1,ySmallmap-1,xSmallMap+wSmallMap,ySmallmap+hSmallMap,$B0B0B0,$FFFFFF);
RFrame(Offscreen.Canvas,xSmallMap-2,ySmallmap-2,xSmallMap+wSmallMap+1,ySmallmap+hSmallMap+1,$FFFFFF,$B0B0B0);

Frame(Offscreen.Canvas,xSupport-1,ySupport-1,xSupport+wSupport,ySupport+hSupport,$B0B0B0,$FFFFFF);
RFrame(Offscreen.Canvas,xSupport-2,ySupport-2,xSupport+wSupport+1,ySupport+hSupport+1,$FFFFFF,$B0B0B0);
x:=xSupport+wSupport div 2;
y:=ySupport+hSupport div 2;
if Mode=mSupp then
  begin
  Offscreen.Canvas.brush.Color:=MainTexture.clMark;
  Offscreen.Canvas.FillRect(Rect(x-27,y-6,x+27,y+6));
  Offscreen.Canvas.brush.style:=bsClear;
  end;
Sprite(offscreen,HGrSystem,x-16,y-5,10,10,88,115);
Sprite(offscreen,HGrSystem,x-5,y-5,10,10,66,115);
Sprite(offscreen,HGrSystem,x+6,y-5,10,10,154,126);

BitBlt(Offscreen.Canvas.Handle,xZoomMap,yZoommap,wZoomMap,hZoomMap,ZoomCitymap.Canvas.Handle,0,0,SRCCOPY);

for i:=0 to 5 do imix[i]:=-1;
if Mode=mImp then
  begin
  if ZoomArea=5 then
    begin
    Cnt:=0;
    for iix:=0 to nImp-1 do
      if ((iix<28) or (ImpPosition[iix]<0)) and (c.Built[iix]>0) then
        begin
        i:=Cnt-Page*6;
        if (i>=0) and (i<6) then
          imix[i]:=iix;
        inc(Cnt);
        end;
    PageCount:=(Cnt+5) div 6;
    end
  else
    begin
    for iix:=28 to nImp-1 do
      begin
      i:=ImpPosition[iix]-6*ZoomArea;
      if (i>=0) and (i<6) and (c.Built[iix]>0) then
        imix[i]:=iix;
      end;
    PageCount:=0;
    end;
  for i:=0 to 5 do if imix[i]>=0 then
    begin
    iix:=imix[i];
    x:=xZoomMap+14+72*(i mod 3);
    y:=yZoomMap+14+56*(i div 3);
    ImpImage(offscreen.Canvas,x,y,iix,cGov,AllowChange and (ClientMode<scContact));
    if IsCityAlive then
      begin
      if iix=imColosseum then
        begin
        Sprite(offscreen,HGrSystem,x+46,y,14,14,82,100);
        end
      else
        begin
        HappyGain:=0;
        case iix of
          0..27,imTemple: HappyGain:=2;
          imTheater: HappyGain:=4;
          imCathedral:
            if MyRO.Wonder[woBach].EffectiveOwner=cOwner then HappyGain:=6
            else HappyGain:=4;
          end;
        if HappyGain>1 then
          begin d:=30 div(HappyGain-1);if d>10 then d:=10 end;
        for j:=0 to HappyGain-1 do
          Sprite(offscreen,HGrSystem,x+50,y+d*j,10,10,132,126);
        end;
      for j:=0 to Imp[iix].Maint-1 do
        Sprite(offscreen,HGrSystem,x-4,y+29-3*j,10,10,132,115);
      end
    end;
  if imix[0]>=0 then
    Imp0Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[0])
  else Imp0Area.Hint:='';
  if imix[1]>=0 then
    Imp1Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[1])
  else Imp1Area.Hint:='';
  if imix[2]>=0 then
    Imp2Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[2])
  else Imp2Area.Hint:='';
  if imix[3]>=0 then
    Imp3Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[3])
  else Imp3Area.Hint:='';
  if imix[4]>=0 then
    Imp4Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[4])
  else Imp4Area.Hint:='';
  if imix[5]>=0 then
    Imp5Area.Hint:=Phrases.Lookup('IMPROVEMENTS',imix[5])
  else Imp5Area.Hint:='';
  end
else {if mode=mSupp then}
  begin
  LoweredTextOut(offscreen.Canvas,-1,MainTexture,xZoomMap+6,yZoomMap+2,Phrases.Lookup('SUPUNITS'));
  FreeSupp:=c.Size*SupportFree[cGov] shr 1;
  Cnt:=0;
  for i:=0 to MyRO.nUn-1 do if (MyUn[i].Loc>=0) and (MyUn[i].Home=cix) then
    with MyModel[MyUn[i].mix] do
      begin
      Server(sGetUnitReport, me, i, UnitReport);
      if (Cnt>=6*Page) and (Cnt<6*(Page+1)) then
        begin // unit visible in display
        imix[Cnt-6*Page]:=i;
        x:=((Cnt-6*Page) mod 3)*64+xZoomMap;
        y:=((Cnt-6*Page) div 3)*52+yZoomMap+20;
        MakeUnitInfo(me,MyUn[i],UnitInfo);
        NoMap.SetOutput(offscreen);
        NoMap.PaintUnit(x,y,UnitInfo,MyUn[i].Status);

        for j:=0 to UnitReport.FoodSupport-1 do
          Sprite(offscreen,HGrSystem,x+38+11*j,y+40,10,10,66,115);
        for j:=0 to UnitReport.ProdSupport-1 do
          begin
          if (FreeSupp>0) and (UnitReport.ReportFlags and urfAlwaysSupport=0) then
            begin
            Sprite(offscreen,HGrSystem,x+16-11*j,y+40,10,10,143,115);
            dec(FreeSupp);
            end
          else Sprite(offscreen,HGrSystem,x+16-11*j,y+40,10,10,88,115);
          end;
        if UnitReport.ReportFlags and urfDeployed<>0 then
          for j:=0 to 1 do
          Sprite(offscreen,HGrSystem,x+27+11*j,y+40,10,10,154,126)
        end // unit visible in display
      else dec(FreeSupp, UnitReport.ProdSupport);
      inc(Cnt);
      end;
  PageCount:=(Cnt+5) div 6;
  Imp0Area.Hint:='';
  Imp1Area.Hint:='';
  Imp2Area.Hint:='';
  Imp3Area.Hint:='';
  Imp4Area.Hint:='';
  Imp5Area.Hint:='';
  end;
PageUpBtn.Visible:= PageCount>1;
PageDownBtn.Visible:= PageCount>1;

with offscreen.Canvas do
  begin
  {display project now}
  DLine(offscreen.Canvas,xView+9+xSizeBig,xProd+2*wBar+10,yProd+dyBar+16,
    $FFFFFF,$B0B0B0);
  if prodhint then
    begin
    Frame(offscreen.canvas,xView+9-1,yView+5-1,xView+9+xSizeBig,yView+5+ySizeBig,$B0B0B0,$FFFFFF);
    RFrame(offscreen.canvas,xView+9-2,yView+5-2,xView+9+xSizeBig+1,yView+5+ySizeBig+1,$FFFFFF,$B0B0B0);
    with offscreen.canvas do
      begin
      Brush.Color:=$000000;
      FillRect(Rect(xView+9,yView+5,xView+1+72-8,yView+5+40));
      Brush.Style:=bsClear;
      end
    end
  else if AllowChange and (c.Status and 7<>0) then
    begin // city type autobuild
    FrameImage(offscreen.canvas,bigimp,xView+9,yView+5,xSizeBig,ySizeBig,
      (c.Status and 7-1+3)*xSizeBig,0,
      (cix>=0) and (ClientMode<scContact));
    end
  else if c.Project and cpImp=0 then
    begin // project is unit
    FrameImage(offscreen.canvas,bigimp,xView+9,yView+5,xSizeBig,ySizeBig,0,0,
      AllowChange and (ClientMode<scContact));
    with Tribe[cOwner].ModelPicture[c.Project and cpIndex] do
      Sprite(offscreen,HGr,xView+5,yView+1,64,44,
        pix mod 10 *65+1,pix div 10*49+1);
    end
  else
    begin // project is building
    if ProdHint then Paintiix:=c.Project0 and cpIndex
    else Paintiix:=c.Project and cpIndex;
    ImpImage(Offscreen.Canvas,xView+9,yView+5,Paintiix,cGov,
      AllowChange and (ClientMode<scContact));
    end;
  end;

if AllowChange and (ClientMode<scContact) then
  begin
  i:=Server(sBuyCityProject-sExecute,me,cix,nil^);
  BuyBtn.Visible:= (i=eOk) or (i=eViolation);
  end
else BuyBtn.Visible:=false;

MarkUsedOffscreen(ClientWidth,ClientHeight);
end;{OffscreenPaint}

procedure TCityDlg.FormShow(Sender: TObject);
var
dx,dy,Loc1: integer;
GetCityData: TGetCityData;
begin
BlinkTime:=5;
if cix>=0 then
  begin {own city}
  c:=MyCity[cix];
  cOwner:=me;
  cGov:=MyRO.Government;
  ProdHint:= (cGov<>gAnarchy)
    and (Happened and (chProduction or chFounded or chCaptured or chAllImpsMade)<>0);
  Server(sGetCityAreaInfo,me,cix,CityAreaInfo);
  NextCityBtn.Visible:= WindowMode=wmPersistent;
  PrevCityBtn.Visible:= WindowMode=wmPersistent;
  end
else {enemy city}
  begin
  Mode:=mImp;
  Server(sGetCity,me,cLoc,GetCityData);
  c:=GetCityData.c;
  cOwner:=GetCityData.Owner;
  cGov:=MyRO.EnemyReport[cOwner].Government;
  Happened:=c.Flags and $7FFFFFFF;
  ProdHint:=false;
  Server(sGetEnemyCityAreaInfo,me,cLoc,CityAreaInfo);

  if c.Project and cpImp=0 then
    begin
    emix:=MyRO.nEnemyModel-1;
    while (emix>0) and ((MyRO.EnemyModel[emix].Owner<>cOwner)
      or (integer(MyRO.EnemyModel[emix].mix)<>c.Project and cpIndex)) do dec(emix);
    if Tribe[cOwner].ModelPicture[c.Project and cpIndex].HGr=0 then
      InitEnemyModel(emix);
    end;

  NextCityBtn.Visible:=false;
  PrevCityBtn.Visible:=false;
  end;
Page:=0;

if c.Size<5 then SizeClass:=0
else if c.Size<9 then SizeClass:=1
else if c.Size<13 then SizeClass:=2
else SizeClass:=3;

// check if port
IsPort:=false;
for dx:=-2 to 2 do for dy:=-2 to 2 do if abs(dx)+abs(dy)=2 then
  begin
  Loc1:=dLoc(cLoc,dx,dy);
  if (Loc1>=0) and (Loc1<G.lx*G.ly) and (MyMap[Loc1] and fTerrain<fGrass) then
    IsPort:=true;
  end;

if WindowMode=wmModal then
  begin {center on screen}
  Left:=(Screen.Width-Width) div 2;
  Top:=(Screen.Height-Height) div 2;
  end;

Caption:=CityName(c.ID);

InitSmallCityMap;
InitZoomCityMap;
OpenSoundEvent:=-1;
OffscreenPaint;
Timer1.Enabled:=true;
end;

procedure TCityDlg.ShowNewContent(NewMode,Loc: integer; ShowEvent: cardinal);
begin
if MyMap[Loc] and fOwned<>0 then
  begin // own city
  cix:=MyRO.nCity-1;
  while (cix>=0) and (MyCity[cix].Loc<>Loc) do dec(cix);
  assert(cix>=0);
  if (Optimize_cixTileChange>=0)
    and (Optimize_TilesBeforeChange
      and not MyCity[Optimize_cixTileChange].Tiles<>0) then
    begin
    CityOptimizer_ReleaseCityTiles(Optimize_cixTileChange,
      Optimize_TilesBeforeChange and not MyCity[Optimize_cixTileChange].Tiles);
    if WindowMode<>wmModal then
      MainScreen.UpdateViews;
    end;
  Optimize_cixTileChange:=cix;
  Optimize_TilesBeforeChange:=MyCity[cix].Tiles;
  end
else cix:=-1;
AllowChange:=not supervising and (cix>=0);
cLoc:=Loc;
Happened:=ShowEvent;
inherited ShowNewContent(NewMode);
end;

procedure TCityDlg.FormMouseDown(Sender:TObject;
  Button:TMouseButton;Shift:TShiftState;x,y:integer);
var
i,qx,qy,dx,dy,fix,NewTiles,Loc1,iix,SellResult: integer;
Rebuild: boolean;
begin
if (ssLeft in Shift) and (x>=xSmallMap) and (x<xSmallMap+wSmallMap)
  and (y>=ySmallMap) and (y<ySmallMap+hSmallMap) then
  begin
  Mode:=mImp;
  ZoomArea:=(y-ySmallMap)*3 div hSmallMap+3*((x-xSmallMap)*2 div wSmallMap);
  Page:=0;
  InitZoomCityMap;
  SmartUpdateContent;
  exit;
  end;
if (ssLeft in Shift) and (x>=xSupport) and (x<xSupport+wSupport)
  and (y>=ySupport) and (y<ySupport+hSupport) then
  begin
  Mode:=mSupp;
  Page:=0;
  InitZoomCityMap;
  SmartUpdateContent;
  exit;
  end;
if not AllowChange then exit; // not an own city

if (ssLeft in Shift) then
  if (ClientMode<scContact)
    and (x>=xView) and (y>=yView) and (x<xView+73) and (y<yView+50) then
    if cGov=gAnarchy then with MessgExDlg do
      begin
{      MessgText:=Phrases.Lookup('OUTOFCONTROL');
      if c.Project and cpImp=0 then
        MessgText:=Format(MessgText,[Tribe[cOwner].ModelName[c.Project and cpIndex]])
      else MessgText:=Format(MessgText,[Phrases.Lookup('IMPROVEMENTS',c.Project and cpIndex)]);}
      MessgText:=Phrases.Lookup('NOCHANGEINANARCHY');
      Kind:=mkOk;
      ShowModal;
      end
    else
      begin
      if ProdHint then
        begin
        ProdHint:=false;
        SmartUpdateContent
        end;
      ChooseProject;
      end
  else if (Mode=mImp) and (x>=xZoomMap) and (x<xZoomMap+wZoomMap)
    and (y>=yZoomMap) and (y<yZoomMap+hZoomMap) then
    begin
    i:=5;
    while (i>=0) and
      not ((x>=xZoomMap+14+72*(i mod 3))
        and (x<xZoomMap+14+56+72*(i mod 3))
        and (y>=yZoomMap+14+56*(i div 3))
        and (y<yZoomMap+14+40+56*(i div 3))) do
      dec(i);
    if i>=0 then
      begin
      iix:=imix[i];
      if iix>=0 then
        if ssShift in Shift then
          HelpDlg.ShowNewContent(Mode or wmPersistent, hkImp, iix)
        else if (ClientMode<scContact) then with MessgExDlg do
          begin
          IconKind:=mikImp;
          IconIndex:=iix;
          if (iix=imPalace) or (Imp[iix].Kind=ikWonder) then
            begin
            MessgText:=Phrases.Lookup('IMPROVEMENTS',iix);
            if iix=woOracle then
              MessgText:=MessgText+'\'+Format(Phrases.Lookup('ORACLEINCOME'),
                [MyRO.OracleIncome]);
            Kind:=mkOk;
            ShowModal;
            end
          else
            begin
            SellResult:=Server(sSellCityImprovement-sExecute,me,cix,iix);
            if SellResult<rExecuted then
              begin
              if SellResult=eOnlyOnce then
                MessgText:=Phrases.Lookup('NOSELLAGAIN')
              else MessgText:=Phrases.Lookup('OUTOFCONTROL');
              MessgText:=Format(MessgText,[Phrases.Lookup('IMPROVEMENTS',iix)]);
              Kind:=mkOk;
              ShowModal;
              end
            else
              begin
              if Server(sRebuildCityImprovement-sExecute,me,cix,iix)<rExecuted then
                begin // no rebuild possible, ask for sell only
                Rebuild:=false;
                MessgText:=Phrases.Lookup('IMPROVEMENTS',iix);
                if not Phrases2FallenBackToEnglish then
                  MessgText:=Format(Phrases2.Lookup('SELL2'),[MessgText,
                    Imp[iix].Cost*BuildCostMod[G.Difficulty[me]] div 12])
                else MessgText:=Format(Phrases.Lookup('SELL'),[MessgText]);
                if iix=imSpacePort then with MyRO.Ship[me] do
                  if Parts[0]+Parts[1]+Parts[2]>0 then
                    MessgText:=MessgText+' '+Phrases.Lookup('SPDESTRUCTQUERY');
                Kind:=mkYesNo;
                ShowModal;
                if ModalResult<>mrOK then iix:=-1
                end
              else
                begin
                Rebuild:=true;
                MessgText:=Phrases.Lookup('IMPROVEMENTS',iix);
                if not Phrases2FallenBackToEnglish then
                  MessgText:=Format(Phrases2.Lookup('DISPOSE2'),[MessgText,
                    Imp[iix].Cost*BuildCostMod[G.Difficulty[me]] div 12 *2 div 3])
                else MessgText:=Format(Phrases.Lookup('DISPOSE'),[MessgText]);
                if iix=imSpacePort then with MyRO.Ship[me] do
                  if Parts[0]+Parts[1]+Parts[2]>0 then
                    MessgText:=MessgText+' '+Phrases.Lookup('SPDESTRUCTQUERY');
                Kind:=mkYesNo;
                ShowModal;
                if ModalResult<>mrOK then iix:=-1
                end;
              if iix>=0 then
                begin
                if Rebuild then
                  begin
                  Play('CITY_REBUILDIMP');
                  Server(sRebuildCityImprovement,me,cix,iix);
                  end
                else
                  begin
                  Play('CITY_SELLIMP');
                  Server(sSellCityImprovement,me,cix,iix);
                  end;
                CityOptimizer_CityChange(cix);
                InitSmallCityMap;
                SmartUpdateContent;
                if WindowMode<>wmModal then
                  MainScreen.UpdateViews;
                end
              end
            end
          end
      end
    end
  else if (Mode=mSupp) and (x>=xZoomMap) and (x<xZoomMap+wZoomMap)
    and (y>=yZoomMap) and (y<yZoomMap+hZoomMap) then
    begin
    i:=5;
    while (i>=0) and
      not ((x>=xZoomMap+64*(i mod 3))
        and (x<xZoomMap+64+64*(i mod 3))
        and (y>=yZoomMap+20+48*(i div 3))
        and (y<yZoomMap+20+52+48*(i div 3))) do
      dec(i);
    if (i>=0) and (imix[i]>=0) then
      if ssShift in Shift then
      else if (cix>=0) and (ClientMode<scContact) and (WindowMode<>wmModal) then
        begin
        CloseAction:=None;
        Close;
        MainScreen.CityClosed(imix[i],false,true);
        end
    end
  else if (x>=xmArea-192) and (x<xmArea+192) and (y>=ymArea-96) and (y<ymArea+96) then
    begin
    qx:=((4000*xxt*yyt)+(x-xmArea)*(yyt*2)+(y-ymArea+yyt)*(xxt*2)) div (xxt*yyt*4)-1000;
    qy:=((4000*xxt*yyt)+(y-ymArea+yyt)*(xxt*2)-(x-xmArea)*(yyt*2)) div (xxt*yyt*4)-1000;
    dx:=qx-qy;
    dy:=qx+qy;
    if (dx>=-3) and (dx<=3) and (dy>=-3) and (dy<=3) and (dx*dx*dy*dy<81)
      and ((dx<>0) or (dy<>0)) then
      if ssShift in Shift then
        begin // terrain help
        Loc1:=dLoc(cLoc,dx,dy);
        if (Loc1>=0) and (Loc1<G.lx*G.ly) then
          HelpOnTerrain(Loc1, Mode or wmPersistent)
        end
      else if (ClientMode<scContact) and (cGov<>gAnarchy)
        and (c.Flags and chCaptured=0) then
        begin // toggle exploitation
        assert(not supervising);
        if c.Status and csResourceWeightsMask<>0 then
          begin
          with MessgExDlg do
            begin
            MessgText:=Phrases.Lookup('CITYMANAGEOFF');
            OpenSound:='MSG_DEFAULT';
            Kind:=mkOkCancel;
            IconKind:=mikFullControl;
            ShowModal;
            end;
          if MessgExDlg.ModalResult=mrOK then
            begin
            MyCity[cix].Status:=MyCity[cix].Status
              and not csResourceWeightsMask; // off
            c.Status:=MyCity[cix].Status;
            SmartUpdateContent
            end;
          exit;
          end;
        fix:=(dy+3) shl 2+(dx+3) shr 1;
        NewTiles:=MyCity[cix].Tiles xor (1 shl fix);
        if Server(sSetCityTiles,me,cix,NewTiles)>=rExecuted then
          begin
          SmartUpdateContent;
          if WindowMode<>wmModal then
            MainScreen.UpdateViews;
          end
        end
    end
  else if (ClientMode<scContact) and (cGov<>gAnarchy) and (c.Flags and chCaptured=0)
    and (x>=xmOpt-32) and (x<xmOpt+32) and (y>=ymOpt-32) and (y<ymOpt+32) then
    begin
    i:=sqr(x-xmOpt)+sqr(y-ymOpt); // click radius
    if i<=32*32 then
      begin
      if i<16*16 then // inner area clicked
        if c.Status and csResourceWeightsMask<>0 then
          i:=(c.Status shr 4 and $0F) mod 5 +1 // rotate except off
        else i:=3 // rwGrowth
      else case trunc(arctan2(x-xmOpt,ymOpt-y)*180/pi) of
        -25-52*2..-26-52: i:=1;
        -25-52..-26: i:=2;
        -25..25: i:=3;
        26..25+52: i:=4;
        26+52..25+52*2: i:=5;
        180-26..180,-180..-180+26: i:=0;
        else i:=-1;
        end;
      if i>=0 then
        begin
        ChangeResourceWeights(i);
        SmartUpdateContent;
        if WindowMode<>wmModal then
          MainScreen.UpdateViews;
        end
      end
    end;
end;{FormMouseDown}

procedure TCityDlg.ChooseProject;
const
ptSelect=0; ptTrGoods=1; ptUn=2; ptCaravan=3; ptImp=4; ptWonder=6;
ptShip=7; ptInvalid=8;

  function ProjectType(Project: integer): integer;
  begin
  if Project and cpCompleted<>0 then result:=ptSelect
  else if Project and (cpImp+cpIndex)=cpImp+imTrGoods then result:=ptTrGoods
  else if Project and cpImp=0 then
    if MyModel[Project and cpIndex].Kind=mkCaravan then result:=ptCaravan
    else result:=ptUn
  else if Project and cpIndex>=nImp then result:=ptInvalid
  else if Imp[Project and cpIndex].Kind=ikWonder then result:=ptWonder
  else if Imp[Project and cpIndex].Kind=ikShipPart then result:=ptShip
  else result:=ptImp
  end;

var
NewProject, OldMoney,pt0,pt1,cix1: integer;
QueryOk: boolean;
begin
assert(not supervising);
ModalSelectDlg.ShowNewContent_CityProject(wmModal,cix);
if ModalSelectDlg.result<>-1 then
  begin
  if ModalSelectDlg.result and cpType<>0 then
    begin
    MyCity[cix].Status:=MyCity[cix].Status and not 7
      or (1+ModalSelectDlg.result and cpIndex);
    AutoBuild(cix, MyData.ImpOrder[ModalSelectDlg.result and cpIndex]);
    end
  else
    begin
    NewProject:=ModalSelectDlg.result;
    QueryOk:=true;
    if (NewProject and cpImp<>0) and (NewProject and cpIndex>=28)
      and (MyRO.NatBuilt[NewProject and cpIndex]>0) then
      with MessgExDlg do
        begin
        cix1:=MyRO.nCity-1;
        while (cix1>=0) and (MyCity[cix1].Built[NewProject and cpIndex]=0) do
          dec(cix1);
        MessgText:=Format(Phrases.Lookup('DOUBLESTATEIMP'),
          [Phrases.Lookup('IMPROVEMENTS', NewProject and cpIndex),
          CityName(MyCity[cix1].ID)]);
        OpenSound:='MSG_DEFAULT';
        Kind:=mkOkCancel;
        IconKind:=mikImp;
        IconIndex:=NewProject and cpIndex;
        ShowModal;
        QueryOk:= ModalResult=mrOK;
        end;
    if not QueryOk then
      exit;

    if (MyCity[cix].Prod>0) then
      begin
      pt0:=ProjectType(MyCity[cix].Project0);
      pt1:=ProjectType(NewProject);
      if (pt0<>ptSelect) and (pt1<>ptTrGoods) then
        begin
        if NewProject and (cpImp or cpIndex)<>MyCity[cix].Project0 and (cpImp or cpIndex) then
          begin // loss of material -- do query
          if (pt1=ptTrGoods) or (pt1=ptShip) or (pt1<>pt0) and (pt0<>ptCaravan) then
            QueryOk:=SimpleQuery(mkOkCancel,Format(Phrases.Lookup('LOSEMAT'),
              [MyCity[cix].Prod0,MyCity[cix].Prod0]),'MSG_DEFAULT')=mrOK
          else if MyCity[cix].Project and (cpImp or cpIndex)=MyCity[cix].Project0 and (cpImp or cpIndex) then
            QueryOk:=SimpleQuery(mkOkCancel,Phrases.Lookup('LOSEMAT3'),'MSG_DEFAULT')=mrOK
          end;
        end
      end;
    if not QueryOk then
      exit;

    OldMoney:=MyRO.Money;
    MyCity[cix].Status:=MyCity[cix].Status and not 7;
    if (NewProject and cpImp=0)
      and ((MyCity[cix].Size<4) and (MyModel[NewProject and cpIndex].Kind=mkSettler)
        or (MyCity[cix].Size<3) and ((MyModel[NewProject and cpIndex].Kind=mkSlaves)
          or (NewProject and cpConscripts<>0))) then
      if SimpleQuery(mkYesNo,Phrases.Lookup('EMIGRATE'),'MSG_DEFAULT')<>mrOK then
        NewProject:=NewProject or cpDisbandCity;
    Server(sSetCityProject,me,cix,NewProject);
    c.Project:=MyCity[cix].Project;
    if MyRO.Money>OldMoney then
      Play('CITY_SELLIMP');
    end;
  CityOptimizer_CityChange(cix);

  if WindowMode<>wmModal then
    MainScreen.UpdateViews;
  InitSmallCityMap;
  SmartUpdateContent;
  end;
end;

procedure TCityDlg.BuyClick(Sender:TObject);
var
NextProd,Cost:integer;
begin
if (cix<0) or (ClientMode>=scContact) then exit;
with MyCity[cix],MessgExDlg do
  begin
  Cost:=Report.ProjectCost;
  NextProd:=Report.Production;
  if NextProd<0 then NextProd:=0;
  Cost:=Cost-Prod-NextProd;
  if (MyRO.Wonder[woMich].EffectiveOwner=me) and (Project and cpImp<>0) then
    Cost:=Cost*2
  else Cost:=Cost*4;
  if (Cost<=0) and (Report.HappinessBalance>=0) {no disorder} then
    begin MessgText:=Phrases.Lookup('READY'); Kind:=mkOK; end
  else if Cost>MyRO.Money then
    begin
    OpenSound:='MSG_DEFAULT';
    MessgText:=Format(Phrases.Lookup('NOMONEY'),[Cost,MyRO.Money]);
    Kind:=mkOK;
    end
  else begin MessgText:=Format(Phrases.Lookup('BUY'),[Cost]); Kind:=mkYesNo; end;
  ShowModal;
  if (Kind=mkYesNo) and (ModalResult=mrOK) then
    begin
    if Server(sBuyCityProject,me,cix,nil^)>=rExecuted then
      begin
      Play('CITY_BUYPROJECT');
      SmartUpdateContent;
      if WindowMode<>wmModal then
        MainScreen.UpdateViews;
      end
    end
  end
end;

procedure TCityDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
Timer1.Enabled:=false;
ProdHint:=false;
MarkCityLoc:=-1;
if Optimize_cixTileChange>=0 then
  begin
  if Optimize_TilesBeforeChange
    and not MyCity[Optimize_cixTileChange].Tiles<>0 then
    begin
    CityOptimizer_ReleaseCityTiles(Optimize_cixTileChange,
      Optimize_TilesBeforeChange and not MyCity[Optimize_cixTileChange].Tiles);
    if WindowMode<>wmModal then
      MainScreen.UpdateViews;
    end;
  Optimize_cixTileChange:=-1;
  end;
if CloseAction>None then
  MainScreen.CityClosed(RestoreUnFocus,CloseAction=StepFocus);
RestoreUnFocus:=-1;
inherited;
end;

procedure TCityDlg.Timer1Timer(Sender: TObject);
begin
if ProdHint then
  begin
  BlinkTime:=(BlinkTime+1) mod 12;
  if BlinkTime=0 then with Canvas do
    begin
    BitBlt(canvas.Handle,xView+5,yView+1,64,2,
      back.Canvas.Handle,xView+5,yView+1,SRCCOPY);
    BitBlt(canvas.Handle,xView+5,yView+3,2,42,
      back.Canvas.Handle,xView+5,yView+3,SRCCOPY);
    BitBlt(canvas.Handle,xView+5+62,yView+3,2,42,
      back.Canvas.Handle,xView+5+62,yView+3,SRCCOPY);
    Frame(canvas,xView+9-1,yView+5-1,xView+9+xSizeBig,yView+5+ySizeBig,$B0B0B0,$FFFFFF);
    RFrame(canvas,xView+9-2,yView+5-2,xView+9+xSizeBig+1,yView+5+ySizeBig+1,$FFFFFF,$B0B0B0);
    Brush.Color:=$000000;
    FillRect(Rect(xView+9,yView+5,xView+1+72-8,yView+5+40));
    Brush.Style:=bsClear;
    end
  else if BlinkTime=6 then
    begin
    if AllowChange and (c.Status and 7<>0) then
      begin // city type autobuild
      FrameImage(canvas,bigimp,xView+9,yView+5,xSizeBig,ySizeBig,
        (c.Status and 7-1+3)*xSizeBig,0,true);
      end
    else if c.Project and cpImp=0 then
      begin // project is unit
      BitBlt(canvas.Handle,xView+9,yView+5,xSizeBig,ySizeBig,
        bigimp.Canvas.Handle,0,0,SRCCOPY);
      with Tribe[cOwner].ModelPicture[c.Project and cpIndex] do
        Sprite(canvas,HGr,xView+5,yView+1,64,44,
          pix mod 10 *65+1,pix div 10*49+1);
      end
    else ImpImage(Canvas,xView+9,yView+5,
      c.Project0 and cpIndex,cGov,true);
    end
  end
end;

procedure TCityDlg.FormPaint(Sender: TObject);
begin
inherited;
if OpenSoundEvent>=0 then PostMessage(Handle, WM_PLAYSOUND, 0, 0);
end;

procedure TCityDlg.OnPlaySound(var Msg:TMessage);
begin
if 1 shl OpenSoundEvent=chProduction then
  begin
  if c.Project0 and cpImp<>0 then
    begin
    if c.Project0 and cpIndex>=28 then // wonders have already extra message with sound
      if Imp[c.Project0 and cpIndex].Kind=ikShipPart then Play('SHIP_BUILT')
      else Play('CITY_IMPCOMPLETE')
    end
  else Play('CITY_UNITCOMPLETE');
  end
else Play(CityEventSoundItem[OpenSoundEvent]);
OpenSoundEvent:=-2;
end;

function Prio(iix: integer): integer;
begin
case Imp[iix].Kind of
  ikWonder: result:=iix+10000;
  ikNatLocal, ikNatGlobal:
    case iix of
      imPalace: result:=0;
      else result:=iix+20000;
      end;
  else case iix of
    imTownHall, imCourt: result:=iix+30000;
    imAqueduct, imSewer: result:=iix+40000;
    imTemple, imTheater, imCathedral: result:=iix+50000;
    else result:=iix+90000;
    end;
  end;
end;

procedure TCityDlg.NextCityBtnClick(Sender: TObject);
begin
ChangeCity(+1);
end;

procedure TCityDlg.PrevCityBtnClick(Sender: TObject);
begin
ChangeCity(-1);
end;

procedure TCityDlg.ChangeCity(d: integer);
var
cixNew: integer;
begin
cixNew:=cix;
repeat
  cixNew:=(cixNew+MyRO.nCity+d) mod MyRO.nCity;
until (MyCity[cixNew].Loc>=0) or (cixNew=cix);
if cixNew<>cix then
  MainScreen.ZoomToCity(MyCity[cixNew].Loc);
end;

procedure TCityDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if ((Key=VK_UP) or (Key=VK_NUMPAD8))
  and (cix>=0) and (WindowMode=wmPersistent) then
  ChangeCity(-1)
else if ((Key=VK_DOWN) or (Key=VK_NUMPAD2))
  and (cix>=0) and (WindowMode=wmPersistent) then
  ChangeCity(+1)
else inherited  
end;

{procedure TCityDlg.AdviceBtnClick(Sender: TObject);
begin
AdvisorDlg.GiveCityAdvice(cix);
end;}

var
i,j,k: integer;

procedure TCityDlg.PageUpBtnClick(Sender: TObject);
begin
if Page>0 then
  begin
  dec(Page);
  SmartUpdateContent
  end
end;

procedure TCityDlg.PageDownBtnClick(Sender: TObject);
begin
if Page<PageCount-1 then
  begin
  inc(Page);
  SmartUpdateContent
  end
end;

procedure TCityDlg.ChangeResourceWeights(iResourceWeights: integer);
var
Advice: TCityTileAdviceData;
begin
assert(not supervising);
assert(cix>=0);
MyCity[cix].Status:=MyCity[cix].Status
  and not csResourceWeightsMask or (iResourceWeights shl 4);
c.Status:=MyCity[cix].Status;
if iResourceWeights>0 then
  begin
  Advice.ResourceWeights:=OfferedResourceWeights[iResourceWeights];
  Server(sGetCityTileAdvice,me,cix,Advice);
  if Advice.Tiles<>MyCity[cix].Tiles then
    Server(sSetCityTiles,me,cix,Advice.Tiles);
  end  
end;


initialization
for i:=0 to nImp-1 do ImpSorted[i]:=i;
for i:=0 to nImp-2 do for j:=i+1 to nImp-1 do
  if Prio(ImpSorted[i])>Prio(ImpSorted[j]) then
    begin k:=ImpSorted[i]; ImpSorted[i]:=ImpSorted[j]; ImpSorted[j]:=k end;
end.

