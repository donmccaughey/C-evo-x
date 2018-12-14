{$INCLUDE switches}

unit Select;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,IsoEngine,PVSB,BaseWin,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,
  ExtCtrls,ButtonB, ButtonBase, Menus;

const
MaxLayer=3;

type
  TListKind=(kProject,kAdvance,kFarAdvance,kCities,kCityEvents,kModels,kEModels,
    kAllEModels,kTribe,kScience,kShipPart,kEShipPart,kChooseTech,
    kChooseETech,kChooseModel,kChooseEModel,kChooseCity,kChooseECity,
    kStealTech,kGov,kMission);

  TListDlg = class(TFramedDlg)
    CloseBtn: TButtonB;
    Layer2Btn: TButtonB;
    Layer1Btn: TButtonB;
    Layer0Btn: TButtonB;
    ToggleBtn: TButtonB;
    Popup: TPopupMenu;
    procedure PaintBox1MouseMove(Sender:TObject;Shift:TShiftState;x,
      y:integer);
    procedure FormCreate(Sender:TObject);
    procedure PaintBox1MouseDown(Sender:TObject;Button:TMouseButton;
      Shift:TShiftState;x,y:integer);
    procedure FormPaint(Sender:TObject);
    procedure CloseBtnClick(Sender:TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormShow(Sender: TObject);
    procedure ModeBtnClick(Sender: TObject);
    procedure ToggleBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure PlayerClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

  public
    result: integer;
    function OnlyChoice(TestKind: TListKind): integer; // -2=empty, -1=ambiguous, other=only choice
    procedure OffscreenPaint; override;
    procedure ShowNewContent(NewMode: integer; ListKind: TListKind);
    procedure ShowNewContent_CityProject(NewMode, cix: integer);
    procedure ShowNewContent_MilReport(NewMode, p: integer);
    procedure EcoChange;
    procedure TechChange;
    procedure AddCity;
    procedure RemoveUnit;

  private
    Kind: TListKind;
    LineDistance,MaxLines,cixProject,pView,Sel,DispLines,Layer,nColumn,
      TechNameSpace,ScienceNation: integer;
    sb:TPVScrollbar;
    Lines, FirstShrinkedLine: array[0..MaxLayer-1] of integer;
    code: array[0..MaxLayer-1,0..4095] of integer;
    Column: array[0..nPl-1] of integer;
    Closable,MultiPage: boolean;
    ScienceNationDot: TBitmap;
    procedure InitLines;
    procedure line(ca: TCanvas; l: integer; NonText, lit: boolean);
    function RenameCity(cix: integer): boolean;
    function RenameModel(mix: integer): boolean;
    procedure OnScroll(var m:TMessage); message WM_VSCROLL;
    procedure OnMouseWheel(var m:TMessage); message WM_MOUSEWHEEL;
    procedure OnMouseLeave(var Msg:TMessage); message CM_MOUSELEAVE;
  end;

  TModalSelectDlg=TListDlg;

const
cpType=$10000;
mixAll=$10000;
adAll=$10000;

var
  ListDlg: TListDlg;
  ModalSelectDlg: TModalSelectDlg;

implementation

uses
CityScreen, Help, UnitStat, Tribes, Inp;

{$R *.DFM}

const
CityNameSpace=127;

MustChooseKind=[kTribe,kStealTech,kGov];


procedure TListDlg.FormCreate(Sender:TObject);
begin
inherited;
Canvas.Font.Assign(UniFont[ftNormal]);
CreatePVSB(sb,Handle,2,361,2+422);
InitButtons();
Kind:=kMission;
Layer0Btn.Hint:=Phrases.Lookup('BTN_IMPRS');
Layer1Btn.Hint:=Phrases.Lookup('BTN_WONDERS');
Layer2Btn.Hint:=Phrases.Lookup('BTN_CLASSES');
ScienceNationDot:=TBitmap.Create;
ScienceNationDot.PixelFormat:=pf24bit;
ScienceNationDot.Width:=17; ScienceNationDot.Height:=17;
end;

procedure TListDlg.FormDestroy(Sender: TObject);
begin
ScienceNationDot.Free;
end;

procedure TListDlg.CloseBtnClick(Sender:TObject);
begin
Closable:=true; Close
end;

procedure TListDlg.FormCloseQuery(Sender: TObject;
  var CanClose: boolean);
begin
CanClose:=Closable or not(Kind in MustChooseKind)
end;

procedure TListDlg.OnScroll(var m:TMessage);
begin
if ProcessPVSB(sb,m) then
  begin Sel:=-2; SmartUpdateContent(true) end
end;

procedure TListDlg.OnMouseWheel(var m:TMessage);
begin
if ProcessMouseWheel(sb,m) then
  begin
  Sel:=-2;
  SmartUpdateContent(true);
  PaintBox1MouseMove(nil, [], m.lParam and $FFFF-Left, m.lParam shr 16-Top);
  end
end;

procedure TListDlg.OnMouseLeave(var Msg:TMessage);
begin
if not Closable and (Sel<>-2) then
  begin
  line(Canvas,Sel,false,false);
  Sel:=-2;
  end
end;

procedure TListDlg.FormPaint(Sender:TObject);
var
s: string;
begin
inherited;
Canvas.Font.Assign(UniFont[ftNormal]);
if Sel<>-2 then line(Canvas,Sel,false,true);
s:='';
if (Kind=kAdvance) and (MyData.FarTech<>adNone) then
  s:=Format(Phrases.Lookup('TECHFOCUS'),
    [Phrases.Lookup('ADVANCES',MyData.FarTech)])
else if Kind=kModels then s:=Tribe[me].TPhrase('SHORTNAME')
else if Kind=kEModels then
  s:=Tribe[pView].TPhrase('SHORTNAME')
    +' ('+TurnToString(MyRO.EnemyReport[pView].TurnOfMilReport)+')';
if s<>'' then
  LoweredTextOut(Canvas, -1, MainTexture,
    (ClientWidth-BiColorTextWidth(Canvas,s)) div 2, 31, s);
if not MultiPage and (Kind in [kProject,kAdvance,kFarAdvance])
  and not Phrases2FallenBackToEnglish then
  begin
  s:=Phrases2.Lookup('SHIFTCLICK');
  LoweredTextOut(Canvas, -2, MainTexture,
    (ClientWidth-BiColorTextWidth(Canvas,s)) div 2, ClientHeight-29, s);
  end
end;

procedure TListDlg.line(ca: TCanvas; l: integer; NonText, lit: boolean);
// paint a line

  procedure DisplayProject(x,y,pix: integer);
  begin
  if pix and (cpType or cpImp)=0 then
    with Tribe[me].ModelPicture[pix and cpIndex] do
      Sprite(offscreen,HGr,x,y,64,48,pix mod 10*65+1, pix div 10 *49+1)
  else
    begin
    Frame(offscreen.Canvas,x+(16-1),y+(16-2),x+(16+xSizeSmall),
      y+(16-1+ySizeSmall),MainTexture.clBevelLight,MainTexture.clBevelShade);
    if pix and cpType=0 then
      if (pix and cpIndex=imPalace) and (MyRO.Government<>gAnarchy) then
        BitBlt(offscreen.Canvas.Handle,x+16,y+(16-1),xSizeSmall,ySizeSmall,
          SmallImp.Canvas.Handle,(MyRO.Government-1)*xSizeSmall,
          ySizeSmall,SRCCOPY)
      else BitBlt(offscreen.Canvas.Handle,x+16,y+(16-1),xSizeSmall,ySizeSmall,
        SmallImp.Canvas.Handle,pix and cpIndex mod 7*xSizeSmall,
        (pix and cpIndex+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY)
    else BitBlt(offscreen.Canvas.Handle,x+16,y+(16-1),xSizeSmall,ySizeSmall,
      SmallImp.Canvas.Handle,(3+pix and cpIndex)*xSizeSmall, 0,SRCCOPY)
    end;
  end;

  procedure ReplaceText(x,y,Color: integer; s: string);
  var
  TextSize: TSize;
  begin
  if ca=Canvas then
    begin
    TextSize.cx:=BiColorTextWidth(ca,s);
    TextSize.cy:=ca.TextHeight(s);
    if y+TextSize.cy>=TitleHeight+InnerHeight then
      TextSize.cy:=TitleHeight+InnerHeight-y;
    Fill(ca,x,y,TextSize.cx,TextSize.cy,(wMaintexture-ClientWidth) div 2,
      (hMaintexture-ClientHeight) div 2);
    end;
  LoweredTextOut(ca,Color,MainTexture,x,y,s);
  end;

var
icon,ofs,x,y,y0,lix,i,j,TextColor,Available,first,test,FutureCount,
  growth,TrueFood,TrueProd:integer;
CityReport: TCityReportNew;
mox: ^TModelInfo;
s,number: string;
CanGrow: boolean;
begin
lix:=code[Layer,sb.si.npos+l];
y0:=2+(l+1)*LineDistance;
if sb.si.npos+l>=FirstShrinkedLine[Layer] then
  ofs:=(sb.si.npos+l-FirstShrinkedLine[Layer]) and 1 *33
else {if FirstShrinkedLine[Layer]<Lines[Layer] then} ofs:=33;

if Kind in [kCities,kCityEvents] then with MyCity[lix] do
  begin
  x:=104-76; y:=y0;
  if ca=Canvas then
    begin x:=x+SideFrame; y:=y+TitleHeight end;
  if lit then TextColor:=MainTexture.clLitText else TextColor:=-1;
  s:=CityName(ID);
  while BiColorTextWidth(ca,s)>CityNameSpace do
    delete(s,length(s),1);
  ReplaceText(x+15,y,TextColor,s);

  if NonText then with offscreen.canvas do
    begin // city size
    brush.color:=$000000;
    fillrect(rect(x-4-11,y+1,x-4+13,y+21));
    brush.color:=$FFFFFF;
    fillrect(rect(x-4-12,y,x-4+12,y+20));
    brush.style:=bsClear;
    font.color:=$000000;
    s:=inttostr(MyCity[lix].Size);
    TextOut(x-4-textwidth(s) div 2, y, s);
    end;

  if Kind=kCityEvents then
    begin
    first:=-1;
    for j:=0 to nCityEventPriority-1 do
      if (Flags and CityRepMask and CityEventPriority[j]<>0) then
        begin first:=j; Break end;
    if first>=0 then
      begin
      i:=0;
      test:=1;
      while test<CityEventPriority[first] do
        begin inc(i); inc(test,test) end;
      s:=CityEventName(i);
{      if CityEventPriority[first]=chNoGrowthWarning then
        if Built[imAqueduct]=0 then
          s:=Format(s,[Phrases.Lookup('IMPROVEMENTS',imAqueduct)])
        else begin s:=Format(s,[Phrases.Lookup('IMPROVEMENTS',imSewer)]); i:=17 end;}
      ReplaceText(x+(CityNameSpace+4+40+18+8),y,TextColor,s);
      if NonText then
        begin
        Sprite(offscreen,HGrSystem,105-76+CityNameSpace+4+40,y0+1,18,18,
          1+i mod 3 *19,1+i div 3 *19);
        x:=InnerWidth-26;
        for j:=nCityEventPriority-1 downto first+1 do
          if (Flags and CityRepMask and CityEventPriority[j]<>0) then
            begin
            i:=0;
            test:=1;
            while test<CityEventPriority[j] do
              begin inc(i); inc(test,test) end;
            if (CityEventPriority[j]=chNoGrowthWarning)
              and (Built[imAqueduct]>0) then
              i:=17;
            Sprite(offscreen,HGrSystem,x,y0+1,18,18,1+i mod 3 *19,
              1+i div 3 *19);
            dec(x,20)
            end
        end
      end
    end
  else
    begin
    CityReport.HypoTiles:=-1;
    CityReport.HypoTaxRate:=-1;
    CityReport.HypoLuxuryRate:=-1;
    Server(sGetCityReportNew,me,lix,CityReport);
    TrueFood:=Food;
    TrueProd:=Prod;
    if supervising then
      begin // normalize city from after-turn state
      dec(TrueFood,CityReport.FoodSurplus);
      if TrueFood<0 then
        TrueFood:=0; // shouldn't happen
      dec(TrueProd,CityReport.Production);
      if TrueProd<0 then
        TrueProd:=0; // shouldn't happen
      end;

    s:=''; // disorder info
    if Flags and chCaptured<>0 then
      s:=Phrases.Lookup('CITYEVENTS',14)
    else if CityReport.HappinessBalance<0 then
      s:=Phrases.Lookup('CITYEVENTS',0);
    if s<>'' then
      begin {disorder}
      if NonText then
        begin
        DarkGradient(offscreen.Canvas,99+31+CityNameSpace+4,y0+2,131,3);
        ca.Font.Assign(UniFont[ftSmall]);
        RisedTextout(offscreen.canvas,103+CityNameSpace+4+31,y0+1,s);
        ca.Font.Assign(UniFont[ftNormal]);
        end
      end
    else
      begin
{      s:=IntToStr(CityReport.FoodSurplus);
      ReplaceText(x+(CityNameSpace+4+48)-BiColorTextWidth(ca,s),y,TextColor,s);}
      s:=IntToStr(CityReport.Science);
      ReplaceText(x+CityNameSpace+4+370+48-BiColorTextWidth(ca,s),y,TextColor,s);
      s:=IntToStr(CityReport.Production);
      ReplaceText(x+CityNameSpace+4+132-BiColorTextWidth(ca,s),y,TextColor,s);
      if NonText then
        begin
        //Sprite(offscreen,HGrSystem,x+CityNameSpace+4+333+1,y+6,10,10,66,115);
        Sprite(offscreen,HGrSystem,x+CityNameSpace+4+370+48+1,y+6,10,10,77,126);
        Sprite(offscreen,HGrSystem,x+CityNameSpace+4+132+1,y+6,10,10,88,115);
        end
      end;
    s:=IntToStr(CityTaxBalance(lix, CityReport));
    ReplaceText(x+CityNameSpace+4+370-BiColorTextWidth(ca,s),y,TextColor,s);
    //if Project and (cpImp+cpIndex)<>cpImp+imTrGoods then
    //  ReplaceText(x+CityNameSpace+4+333+1,y,TextColor,Format('%d/%d',[TrueProd,CityReport.ProjectCost]));
    if NonText then
      begin
      Sprite(offscreen,HGrSystem,x+CityNameSpace+4+370+1,y+6,10,10,132,115);

      // food progress
      CanGrow:=(Size<MaxCitySize) and (MyRO.Government<>gFuture)
        and (CityReport.FoodSurplus>0)
        and ((Size<NeedAqueductSize)
          or (Built[imAqueduct]=1) and (Size<NeedSewerSize)
          or (Built[imSewer]=1));
      PaintRelativeProgressBar(offscreen.canvas,1,x+15+CityNameSpace+4,y+7,68,TrueFood,
        CutCityFoodSurplus(CityReport.FoodSurplus,
        (MyRO.Government<>gAnarchy) and (Flags and chCaptured=0),
        MyRO.Government,Size),CityReport.Storage,CanGrow,MainTexture);

      if Project<>cpImp+imTrGoods then
        begin
        DisplayProject(ofs+104-76+x-28+CityNameSpace+4+206-60,y0-15,Project);

        // production progress
        growth:=CityReport.Production;
        if (growth<0) or (MyRO.Government=gAnarchy)
          or (Flags and chCaptured<>0) then
          growth:=0;
        PaintRelativeProgressBar(offscreen.canvas,4,x+CityNameSpace+4+304-60+9,y+7,68,
          TrueProd,growth,CityReport.ProjectCost,true,MainTexture);
        end;
      end
    end;
  end
else if Kind in [kModels,kEModels] then
  begin
  x:=104; y:=y0;
  if ca=Canvas then
    begin x:=x+SideFrame; y:=y+TitleHeight end;
  if lit then TextColor:=MainTexture.clLitText else TextColor:=-1;
  if Kind=kModels then
    begin
    Available:=0;
    for j:=0 to MyRO.nUn-1 do
      if (MyUn[j].Loc>=0) and (MyUn[j].mix=lix) then inc(Available);
    if MainScreen.mNames.Checked then
      s:=Tribe[me].ModelName[lix]
    else s:=Format(Tribe[me].TPhrase('GENMODEL'),[lix]);
    if NonText then DisplayProject(8+ofs,y0-15,lix);
    end
  else
    begin
    Available:=MyRO.EnemyReport[pView].UnCount[lix];
    if MainScreen.mNames.Checked then
      s:=Tribe[pView].ModelName[lix]
    else s:=Format(Tribe[pView].TPhrase('GENMODEL'),[lix]);
    if NonText then
      with Tribe[pView].ModelPicture[lix] do
        Sprite(offscreen,HGr,8+ofs,y0-15,64,48,pix mod 10*65+1, pix div 10 *49+1);
    end;
  if Available>0 then
    ReplaceText(x+32-BiColorTextWidth(ca,IntToStr(Available)),y,TextColor,
      IntToStr(Available));
  ReplaceText(x+40,y,TextColor,s);
  end
else
  begin
  case Kind of
    kAllEModels, kChooseEModel:
      if lix=mixAll then s:=Phrases.Lookup('PRICECAT_ALLMODEL')
      else
        begin
        mox:=@MyRO.EnemyModel[lix];
        if MainScreen.mNames.Checked then
          begin
          s:=Tribe[mox.Owner].ModelName[mox.mix];
          if (Kind=kAllEModels) and (code[1,sb.si.npos+l]=0) then
            s:=Format(Tribe[mox.Owner].TPhrase('OWNED'), [s]);
          end
        else s:=Format(Tribe[mox.Owner].TPhrase('GENMODEL'),[mox.mix]);
        if NonText then
          with Tribe[mox.Owner].ModelPicture[mox.mix] do
            Sprite(offscreen,HGr,8+ofs,y0-15,64,48,pix mod 10*65+1, pix div 10 *49+1);
        end;
    kChooseModel:
      if lix=mixAll then s:=Phrases.Lookup('PRICECAT_ALLMODEL')
      else
        begin
        s:=Tribe[me].ModelName[lix];
        if NonText then DisplayProject(8+ofs,y0-15,lix);
        end;
    kProject:
      begin
      if lix and cpType<>0 then s:=Phrases.Lookup('CITYTYPE',lix and cpIndex)
      else if lix and cpImp=0 then with MyModel[lix and cpIndex] do
        begin
        s:=Tribe[me].ModelName[lix and cpIndex];
        if lix and cpConscripts<>0 then
          s:=Format(Phrases.Lookup('CONSCRIPTS'),[s]);
        end
      else
        begin
        s:=Phrases.Lookup('IMPROVEMENTS',lix and cpIndex);
        if (Imp[lix and cpIndex].Kind in [ikNatLocal,ikNatGlobal])
            and (MyRO.NatBuilt[lix and cpIndex]>0)
          or (lix and cpIndex in [imPower,imHydro,imNuclear])
            and (MyCity[cixProject].Built[imPower]
              +MyCity[cixProject].Built[imHydro]
              +MyCity[cixProject].Built[imNuclear]>0) then
          s:=Format(Phrases.Lookup('NATEXISTS'),[s]);
        end;
      if NonText then DisplayProject(8+ofs,y0-15,lix);
      end;
    kAdvance, kFarAdvance, kScience, kChooseTech, kChooseETech, kStealTech:
      begin
      if lix=adAll then s:=Phrases.Lookup('PRICECAT_ALLTECH')
      else
        begin
        if lix=adNexus then s:=Phrases.Lookup('NEXUS')
        else if lix=adNone then s:=Phrases.Lookup('NOFARTECH')
        else if lix=adMilitary then s:=Phrases.Lookup('INITUNIT')
        else
          begin
          s:=Phrases.Lookup('ADVANCES',lix);
          if (Kind=kAdvance) and (lix in FutureTech) then
            if MyRO.Tech[lix]<tsApplicable then s:=s+' 1'
            else s:=s+' '+IntToStr(MyRO.Tech[lix]+1);
          end;
        if BiColorTextWidth(ca,s)>TechNameSpace+8 then
          begin
          repeat
            delete(s,length(s),1);
          until BiColorTextWidth(ca,s)<=TechNameSpace+5;
          s:=s+'.';
          end;

        if NonText then
          begin // show tech icon
          if lix=adNexus then
            begin
            Frame(offscreen.Canvas,(8+16-1),y0-1,(8+16+36),
              y0+20,MainTexture.clBevelLight,MainTexture.clBevelShade);
            Dump(offscreen,HGrSystem,(8+16),y0,36,20,223,295)
            end
          else if lix=adNone then
            begin
            Frame(offscreen.Canvas,(8+16-1),y0-1,(8+16+36),
              y0+20,MainTexture.clBevelLight,MainTexture.clBevelShade);
            Dump(offscreen,HGrSystem,(8+16),y0,36,20,260,295)
            end
          else if lix=adMilitary then
            begin
            Frame(offscreen.Canvas,(8+16-1),y0-1,(8+16+36),
              y0+20,MainTexture.clBevelLight,MainTexture.clBevelShade);
            Dump(offscreen,HGrSystem,(8+16),y0,36,20,38,295)
            end
          else
            begin
            Frame(offscreen.Canvas,(8+16-1),y0-1,(8+16+xSizeSmall),
              y0+ySizeSmall,MainTexture.clBevelLight,MainTexture.clBevelShade);
            if AdvIcon[lix]<84 then
              BitBlt(offscreen.Canvas.Handle,(8+16),y0,xSizeSmall,ySizeSmall,
                SmallImp.Canvas.Handle,(AdvIcon[lix]+SystemIconLines*7) mod 7*xSizeSmall,
                (AdvIcon[lix]+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY)
            else Dump(offscreen,HGrSystem,(8+16),y0,36,20,
              1+(AdvIcon[lix]-84) mod 8*37,295+(AdvIcon[lix]-84) div 8*21);
            j:=AdvValue[lix] div 1000;
            BitBlt(Handle,(8+16-4),y0+2,14,14,
              GrExt[HGrSystem].Mask.Canvas.Handle,127+j*15,85,SRCAND);
            Sprite(offscreen,HGrSystem,(8+16-5),y0+1,14,14,
              127+j*15,85);
            end;
          end;
        end;

      if NonText and (Kind in [kAdvance, kScience]) then
        begin // show research state
        for j:=0 to nColumn-1 do
          begin
          FutureCount:=0;
          if j=0 then // own science
            if lix=MyRO.ResearchTech then
              begin
              Server(sGetTechCost,me,0,icon);
              icon:=4+MyRO.Research*4 div icon;
              if icon>4+3 then icon:=4+3
              end
            else if (lix>=adMilitary) then
              icon:=-1
            else if lix in FutureTech then
              begin
              icon:=-1;
              FutureCount:=MyRO.Tech[lix];
              end
            else if MyRO.Tech[lix]=tsSeen then icon:=1
            else if MyRO.Tech[lix]>=tsApplicable then icon:=2
            else icon:=-1
          else with MyRO.EnemyReport[Column[j]]^ do // enemy science
            if (MyRO.Alive and (1 shl Column[j])<>0)
              and (TurnOfCivilReport>=0) and (lix=ResearchTech)
              and ((lix=adMilitary) or (lix in FutureTech)
                or (Tech[lix]<tsApplicable)) then
              begin
              icon:=4+ResearchDone div 25;
              if icon>4+3 then icon:=4+3
              end
            else if lix=adMilitary then
              icon:=-1
            else if lix in FutureTech then
              begin
              icon:=-1;
              FutureCount:=Tech[lix]
              end
            else if Tech[lix]>=tsApplicable then
              icon:=2
            else if Tech[lix]=tsSeen then
              icon:=1
            else icon:=-1;
          if icon>=0 then
            Sprite(offscreen,HGrSystem,104-33+15+3+TechNameSpace+24*j,y0+3,
              14,14,67+icon*15,85)
          else if (Kind=kScience) and (FutureCount>0) then
            begin
            number:=inttostr(FutureCount);
            RisedTextOut(ca,104-33+15+10+TechNameSpace+24*j
              -BiColorTextWidth(ca,number) div 2,y0,number);
            end
          end
        end;
      end; // kAdvance, kScience
    kTribe:
      s:=TribeNames[lix];
    kShipPart:
      begin
      s:=Phrases.Lookup('IMPROVEMENTS',imShipComp+lix)
        +' ('+inttostr(MyRO.Ship[me].Parts[lix])+')';
      if NonText then DisplayProject(8+ofs,y0-15,cpImp+imShipComp+lix);
      end;
    kEShipPart:
      begin
      s:=Phrases.Lookup('IMPROVEMENTS',imShipComp+lix)
        +' ('+inttostr(MyRO.Ship[DipMem[me].pContact].Parts[lix])+')';
      if NonText then DisplayProject(8+ofs,y0-15,cpImp+imShipComp+lix);
      end;
    kGov:
      begin
      s:=Phrases.Lookup('GOVERNMENT',lix);
      if NonText then
        begin
        Frame(offscreen.Canvas,8+16-1,y0-15+(16-2),8+16+xSizeSmall,
          y0-15+(16-1+ySizeSmall),MainTexture.clBevelLight,MainTexture.clBevelShade);
        BitBlt(offscreen.Canvas.Handle,8+16,y0-15+(16-1),xSizeSmall,ySizeSmall,
          SmallImp.Canvas.Handle,(lix-1)*xSizeSmall,ySizeSmall,SRCCOPY);
        end
      end;
    kMission:
      s:=Phrases.Lookup('SPYMISSION',lix);
    end;
  case Kind of
    kTribe,kMission: // center text
      if Lines[0]>MaxLines then
        x:=(InnerWidth-GetSystemMetrics(SM_CXVSCROLL)) div 2-BiColorTextWidth(ca,s) div 2
      else x:=InnerWidth div 2-BiColorTextWidth(ca,s) div 2;
    kAdvance, kFarAdvance, kScience, kChooseTech, kChooseETech, kStealTech, kGov:
      x:=104-33;
    kAllEModels: x:=104;
    else x:=104+15;
    end;
  y:=y0;
  if ca=Canvas then
    begin x:=x+SideFrame; y:=y+TitleHeight end;
  if lit then TextColor:=MainTexture.clLitText
  else TextColor:=-1;
{  if Kind=kTribe then ReplaceText_Tribe(x,y,TextColor,
    integer(TribeNames.Objects[lix]),s)
  else} ReplaceText(x,y,TextColor,s);
  end
end;

procedure TListDlg.OffscreenPaint;
var
i,j: integer;
begin
case Kind of
  kCities: Caption:=Tribe[me].TPhrase('TITLE_CITIES');
  kCityEvents: Caption:=Format(Phrases.Lookup('TITLE_EVENTS'),[TurnToString(MyRO.Turn)]);
  end;

inherited;
offscreen.Canvas.Font.Assign(UniFont[ftNormal]);
FillOffscreen(0,0,InnerWidth,InnerHeight);
with offscreen.Canvas do
  begin
  if Kind=kScience then
    for i:=1 to nColumn-1 do
      begin
      Pen.Color:=$000000;
      MoveTo(104-33+15+TechNameSpace+24*i,0);
      LineTo(104-33+15+TechNameSpace+24*i,InnerHeight);
      MoveTo(104-33+15+TechNameSpace+9*2+24*i,0);
      LineTo(104-33+15+TechNameSpace+9*2+24*i,InnerHeight);
      if MyRO.EnemyReport[Column[i]].TurnOfCivilReport>=MyRO.Turn-1 then
        begin
        brush.color:=Tribe[Column[i]].Color;
        FillRect(Rect(104-33+14+TechNameSpace+24*i+1*2,0,
          104-33+17+TechNameSpace+24*i+8*2,InnerHeight));
        brush.style:=bsClear;
        end
      else
        begin // colored player columns
        Pen.Color:=Tribe[Column[i]].Color;
        for j:=1 to 8 do
          begin
          MoveTo(104-33+15+TechNameSpace+24*i+j*2,0);
          LineTo(104-33+15+TechNameSpace+24*i+j*2,InnerHeight);
          end
        end;
      end;
  for i:=-1 to DispLines do if (i+sb.si.npos>=0) and (i+sb.si.npos<Lines[Layer]) then
    line(offscreen.Canvas,i,true,false)
  end;
MarkUsedOffscreen(InnerWidth,8+48+DispLines*LineDistance);
end;

procedure TListDlg.PaintBox1MouseMove(Sender:TObject;
  Shift:TShiftState;x,y:integer);
var
i0,Sel0,iColumn,OldScienceNation,xScreen: integer;
s: string;
begin
y:=y-TitleHeight;
i0:=sb.si.npos;
Sel0:=Sel;
if (x>=SideFrame) and (x<SideFrame+InnerWidth) and (y>=0) and (y<InnerHeight)
  and (y mod LineDistance>=4) and (y mod LineDistance<20) then
  Sel:=y div LineDistance-1
else Sel:=-2;
if (Sel<-1) or (Sel>DispLines) or (Sel+i0<0) or (Sel+i0>=Lines[Layer]) then
  Sel:=-2;
if Sel<>Sel0 then
  begin
  if Sel0<>-2 then line(Canvas,Sel0,false,false);
  if Sel<>-2 then line(Canvas,Sel,false,true)
  end;

if Kind=kScience then
  begin // show nation under cursor position
  OldScienceNation:=ScienceNation;
  ScienceNation:=-1;
  if (x>=SideFrame+(104-33+15+TechNameSpace)) and ((x-SideFrame-(104-33+15+TechNameSpace)) mod 24<=18)
    and (y>=0) and (y<InnerHeight) then
    begin
    iColumn:=(x-SideFrame-(104-33+15+TechNameSpace)) div 24;
    if (iColumn>=1) and (iColumn<nColumn) then
      ScienceNation:=Column[iColumn];
    end;
  if ScienceNation<>OldScienceNation then
    begin
    Fill(Canvas,9,ClientHeight-29,ClientWidth-18,24,
      (wMaintexture-ClientWidth) div 2,(hMaintexture-ClientHeight) div 2);
    if ScienceNation>=0 then
      begin
      s:=Tribe[ScienceNation].TPhrase('SHORTNAME');
      if MyRO.Alive and (1 shl ScienceNation)=0 then
        s:=Format(Phrases.Lookup('SCIENCEREPORT_EXTINCT'),[s]) // extinct
      else if MyRO.EnemyReport[ScienceNation].TurnOfCivilReport<MyRO.Turn-1 then
        s:=s+' ('+TurnToString(MyRO.EnemyReport[ScienceNation].TurnOfCivilReport)+')'; // old report
      xScreen:=(ClientWidth-BiColorTextWidth(Canvas,s)) div 2;
      LoweredTextOut(Canvas, -1, MainTexture, xScreen+10, ClientHeight-29, s);
      BitBlt(ScienceNationDot.Canvas.Handle,0,0,17,17,Canvas.Handle,xScreen-10,
        ClientHeight-27,SRCCOPY);
      ImageOp_BCC(ScienceNationDot,Templates,0,0,114,211,17,17,
        MainTexture.clBevelShade,Tribe[ScienceNation].Color);
      BitBlt(Canvas.Handle,xScreen-10,ClientHeight-27,17,17,
        ScienceNationDot.Canvas.Handle,0,0,SRCCOPY);
      end;
    end
  end;
end;

function TListDlg.RenameCity(cix: integer): boolean;
var
CityNameInfo: TCityNameInfo;
begin
InputDlg.Caption:=Phrases.Lookup('TITLE_CITYNAME');
InputDlg.EInput.Text:=CityName(MyCity[cix].ID);
InputDlg.CenterToRect(BoundsRect);
InputDlg.ShowModal;
if (InputDlg.ModalResult=mrOK) and (InputDlg.EInput.Text<>'')
  and (InputDlg.EInput.Text<>CityName(MyCity[cix].ID)) then
  begin
  CityNameInfo.ID:=MyCity[cix].ID;
  CityNameInfo.NewName:=InputDlg.EInput.Text;
  Server(cSetCityName+(Length(CityNameInfo.NewName)+8) div 4,me,0,CityNameInfo);
  if CityDlg.Visible then begin CityDlg.FormShow(nil); CityDlg.Invalidate end;
  result:=true
  end
else result:=false
end;

function TListDlg.RenameModel(mix: integer): boolean;
var
ModelNameInfo: TModelNameInfo;
begin
InputDlg.Caption:=Phrases.Lookup('TITLE_MODELNAME');
InputDlg.EInput.Text:=Tribe[me].ModelName[mix];
InputDlg.CenterToRect(BoundsRect);
InputDlg.ShowModal;
if (InputDlg.ModalResult=mrOK) and (InputDlg.EInput.Text<>'')
  and (InputDlg.EInput.Text<>Tribe[me].ModelName[mix]) then
  begin
  ModelNameInfo.mix:=mix;
  ModelNameInfo.NewName:=InputDlg.EInput.Text;
  Server(cSetModelName+(Length(ModelNameInfo.NewName)+1+4+3) div 4,
    me,0,ModelNameInfo);
  if UnitStatDlg.Visible then begin UnitStatDlg.FormShow(nil); UnitStatDlg.Invalidate end;
  result:=true
  end
else result:=false  
end;

procedure TListDlg.PaintBox1MouseDown(Sender:TObject;Button:TMouseButton;
  Shift:TShiftState;x,y:integer);
var
lix: integer;
begin
if sb.si.npos+Sel>=0 then lix:=code[Layer,sb.si.npos+Sel];
if Kind in [kScience,kCities,kCityEvents,kModels,kEModels,kAllEModels] then
  include(Shift, ssShift); // don't close list window
if (ssLeft in Shift) and not(ssShift in Shift) then
  begin
  if Sel<>-2 then
    begin result:=lix; Closable:=true; Close end
  end
else if (ssLeft in Shift) and (ssShift in Shift) then
  begin // show help/info popup
  if Sel<>-2 then
    case Kind of
      kCities:
        MainScreen.ZoomToCity(MyCity[lix].Loc);
      kCityEvents:
        MainScreen.ZoomToCity(MyCity[lix].Loc, false, MyCity[lix].Flags and CityRepMask);
      kModels,kChooseModel:
        if lix<>mixAll then
          UnitStatDlg.ShowNewContent_OwnModel(FWindowMode or wmPersistent, lix);
      kEModels:
        UnitStatDlg.ShowNewContent_EnemyModel(FWindowMode or wmPersistent, code[1,sb.si.npos+Sel]);
      kAllEModels,kChooseEModel:
        if lix<>mixAll then
          UnitStatDlg.ShowNewContent_EnemyModel(FWindowMode or wmPersistent, lix);
      kAdvance,kFarAdvance,kScience,kChooseTech,kChooseETech,kStealTech:
        if lix=adMilitary then
          HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkText, HelpDlg.TextIndex('MILRES'))
        else if lix<adMilitary then
          HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkAdv, lix);
      kProject:
        if lix=cpImp+imTrGoods then
          HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkText,HelpDlg.TextIndex('TRADINGGOODS'))
        else if lix and (cpImp+cpType)=0 then
          UnitStatDlg.ShowNewContent_OwnModel(FWindowMode or wmPersistent, lix and cpIndex)
        else if (lix and cpType=0) and (lix<>cpImp+imTrGoods) then
          HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkImp, lix and cpIndex);
      kGov:
        HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkMisc, miscGovList);
      kShipPart,kEShipPart:;
      end
  end
else if ssRight in Shift then
  begin
  if Sel<>-2 then
    case Kind of
      kCities, kCityEvents:
        if RenameCity(lix) then SmartUpdateContent;
      kModels:
        if RenameModel(lix) then SmartUpdateContent;
      end
  end
end;

procedure TListDlg.InitLines;
var
required: array[0..nAdv-1] of integer;

  procedure TryAddImpLine(Layer,Project: integer);
  begin
  if Server(sSetCityProject-sExecute,me,cixProject,Project)>=rExecuted then
    begin code[Layer,Lines[Layer]]:=Project; inc(Lines[Layer]); end;
  end;

  procedure SortTechs;
  var
  i,j,swap: integer;
  begin // sort by advancedness
  for i:=0 to Lines[0]-2 do if code[0,i]<adMilitary then
    for j:=i+1 to Lines[0]-1 do
      if AdvValue[code[0,i]]*nAdv+code[0,i]<AdvValue[code[0,j]]*nAdv+code[0,j] then
        begin swap:=code[0,i]; code[0,i]:=code[0,j]; code[0,j]:=swap end;
  end;

  procedure SortCities;
  var
  i,j,swap: integer;
  begin
  for i:=0 to Lines[0]-2 do
    for j:=i+1 to Lines[0]-1 do
      if CityName(MyCity[code[0,i]].ID)>CityName(MyCity[code[0,j]].ID) then
        begin swap:=code[0,i]; code[0,i]:=code[0,j]; code[0,j]:=swap end;
  end;

  function ModelSortValue(const mi: TModelInfo; MixPlayers: boolean = false): integer;
  begin
  result:=(mi.Domain+1) shl 28 -mi.mix;
  if MixPlayers then dec(result, ModelCode(mi) shl 16);
  end;

  procedure SortModels;
  var
  i,j,swap: integer;
  begin // sort by code[2]
  for i:=0 to Lines[0]-2 do for j:=i+1 to Lines[0]-1 do
    if code[2,i]>code[2,j] then
      begin
      swap:=code[0,i]; code[0,i]:=code[0,j]; code[0,j]:=swap;
      swap:=code[1,i]; code[1,i]:=code[1,j]; code[1,j]:=swap;
      swap:=code[2,i]; code[2,i]:=code[2,j]; code[2,j]:=swap;
      end;
  end;

  procedure MarkPreqs(i: integer);
  begin
  required[i]:=1;
  if MyRO.Tech[i]<tsSeen then
    begin
    if (AdvPreq[i,0]>=0) then MarkPreqs(AdvPreq[i,0]);
    if (AdvPreq[i,1]>=0) then MarkPreqs(AdvPreq[i,1]);
    end
  end;

var
Loc1,i,j,p1,dx,dy,mix,emix,EnemyType,TestEnemyType:integer;
mi: TModelInfo;
PPicture, PTestPicture: ^TModelPicture;
ModelOk: array[0..4095] of boolean;
ok: boolean;
begin
for i:=0 to MaxLayer-1 do
  begin Lines[i]:=0; FirstShrinkedLine[i]:=MaxInt end;
case Kind of
  kProject:
    begin
    // improvements
    code[0,0]:=cpImp+imTrGoods;
    Lines[0]:=1;
    for i:=28 to nImp-1 do
      if Imp[i].Kind=ikCommon then
        TryAddImpLine(0,i+cpImp);
    for i:=28 to nImp-1 do
      if not (Imp[i].Kind in [ikCommon,ikTrGoods])
        and ((MyRO.NatBuilt[i]=0) or (Imp[i].Kind=ikNatLocal)) then
        TryAddImpLine(0,i+cpImp);
    for i:=0 to nCityType-1 do if MyData.ImpOrder[i,0]>=0 then
      begin code[0,Lines[0]]:=cpType+i; inc(Lines[0]); end;

    // wonders
    for i:=0 to 27 do
      TryAddImpLine(1,i+cpImp);

    // units
    for i:=0 to MyRO.nModel-1 do
      begin
{      if MyModel[i].Kind=mkSlaves then
        ok:= MyRO.Wonder[woPyramids].EffectiveOwner=me
      else} if MyModel[i].Domain=dSea then
        begin
        ok:=false;
        for dx:=-2 to 2 do for dy:=-2 to 2 do if abs(dx)+abs(dy)=2 then
          begin
          Loc1:=dLoc(MyCity[cixProject].Loc,dx,dy);
          if (Loc1>=0) and (Loc1<G.lx*G.ly)
            and ((MyMap[Loc1] and fTerrain=fShore) or (MyMap[Loc1] and fCanal>0)) then
            ok:=true;
          end
        end
      else ok:=true;
      if ok then
        begin
        if MyModel[i].Status and msObsolete=0 then
          begin code[2,Lines[2]]:=i; inc(Lines[2]) end;
        if MyModel[i].Status and msAllowConscripts<>0 then
          begin code[2,Lines[2]]:=i+cpConscripts; inc(Lines[2]) end;
        end;
      end;
    FirstShrinkedLine[2]:=0;
    end;
  kAdvance:
    begin
    nColumn:=1;
    if MyData.FarTech<>adNone then
      begin
      FillChar(required,SizeOf(required),0);
      MarkPreqs(MyData.FarTech);
      end;
    for i:=0 to nAdv-1 do
      if ((i in FutureTech) or (MyRO.Tech[i]<tsApplicable))
        and (Server(sSetResearch-sExecute,me,i,nil^)>=rExecuted)
        and ((MyData.FarTech=adNone) or (required[i]>0)) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    SortTechs;
    if Lines[0]=0 then // no more techs -- offer nexus
      begin code[0,Lines[0]]:=adNexus; inc(Lines[0]); end;
    ok:=false;
    for i:=0 to nDomains-1 do
      if (upgrade[i,0].Preq=preNone)
        or (MyRO.Tech[upgrade[i,0].Preq]>=tsApplicable) then
        ok:=true;
    if ok then {new unit class}
      begin code[0,Lines[0]]:=adMilitary; inc(Lines[0]) end;
    end;
  kFarAdvance:
    begin
    code[0,Lines[0]]:=adNone; inc(Lines[0]);
    for i:=0 to nAdv-1 do
      if not (i in FutureTech) and (MyRO.Tech[i]<tsApplicable)
        and ((AdvValue[i]<2000) or (MyRO.Tech[adMassProduction]>tsNA))
        and ((AdvValue[i]<1000) or (MyRO.Tech[adScience]>tsNA)) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    SortTechs;
    end;
  kChooseTech:
    begin
    for i:=0 to nAdv-1 do
      if not (i in FutureTech) and (MyRO.Tech[i]>=tsApplicable)
        and (MyRO.EnemyReport[DipMem[me].pContact].Tech[i]<tsSeen) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    SortTechs;
//    if Lines[0]>1 then
      begin code[0,Lines[0]]:=adAll; inc(Lines[0]); end;
    end;
  kChooseETech:
    begin
    for i:=0 to nAdv-1 do
      if not (i in FutureTech) and (MyRO.Tech[i]<tsSeen)
        and (MyRO.EnemyReport[DipMem[me].pContact].Tech[i]>=tsApplicable) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    SortTechs;
//    if Lines[0]>1 then
      begin code[0,Lines[0]]:=adAll; inc(Lines[0]); end;
    end;
  kStealTech:
    begin
    for i:=0 to nAdv-1 do
      if Server(sStealTech-sExecute, me, i, nil^)>=rExecuted then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    SortTechs;
    end;
  kScience:
    begin
    Column[0]:=me;
    nColumn:=1;
    for EnemyType:=0 to 2 do
      for p1:=0 to nPl-1 do
        if (MyRO.EnemyReport[p1]<>nil)
          and ((MyRO.EnemyReport[p1].TurnOfContact>=0)
            or (MyRO.EnemyReport[p1].TurnOfCivilReport>=0)) then
          begin
          if MyRO.Alive and (1 shl p1)=0 then
            TestEnemyType:=2 // extinct enemy -- move to right end
          else if MyRO.EnemyReport[p1].TurnOfCivilReport>=MyRO.Turn-1 then
            TestEnemyType:=0 // current report -- move to left end
          else TestEnemyType:=1;
          if TestEnemyType=EnemyType then
            begin Column[nColumn]:=p1; inc(nColumn); end;
          end;
    for i:=0 to nAdv-1 do
      begin
      ok:= (MyRO.Tech[i]<>tsNA) or (MyRO.ResearchTech=i);
      for j:=1 to nColumn-1 do with MyRO.EnemyReport[Column[j]]^ do
        if (Tech[i]<>tsNA) or (TurnOfCivilReport>=0) and (ResearchTech=i) then
          ok:=true;
      if ok then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
      end;
    SortTechs;

    ok:= MyRO.ResearchTech=adMilitary;
    for j:=1 to nColumn-1 do with MyRO.EnemyReport[Column[j]]^ do
      if (MyRO.Alive and (1 shl Column[j])<>0)
        and (TurnOfCivilReport>=0) and (ResearchTech=adMilitary) then
        ok:=true;
    if ok then
      begin code[0,Lines[0]]:=adMilitary; inc(Lines[0]); end
    end;
  kCities{, kChooseCity}:
    begin
    if ClientMode<scContact then
      for i:=0 to MyRO.nCity-1 do if MyCity[i].Loc>=0 then
        begin code[0,Lines[0]]:=i; inc(Lines[0]) end;
    SortCities;
    FirstShrinkedLine[0]:=0
    end;
  kCityEvents:
    begin
    for i:=0 to MyRO.nCity-1 do
      if (MyCity[i].Loc>=0) and (MyCity[i].Flags and CityRepMask<>0) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]) end;
    SortCities;
    FirstShrinkedLine[0]:=0
    end;
{  kChooseECity:
    begin
    for i:=0 to MyRO.nEnemyCity-1 do
      if (MyRO.EnemyCity[i].Loc>=0)
        and (MyRO.EnemyCity[i].owner=DipMem[me].pContact) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    FirstShrinkedLine:=0
    end;}
  kModels:
    begin
    for mix:=0 to MyRO.nModel-1 do
      begin
      code[0,mix]:=mix;
      MakeModelInfo(me, mix, MyModel[mix], mi);
      code[2,mix]:=ModelSortValue(mi);
      end;
    Lines[0]:=MyRO.nModel;
    SortModels;
    FirstShrinkedLine[0]:=0
    end;
  kChooseModel:
    begin
    for mix:=3 to MyRO.nModel-1 do
      begin // check if opponent already has this model
      MakeModelInfo(me,mix,MyModel[mix],mi);
      ok:=true;
      for emix:=0 to MyRO.nEnemyModel-1 do
         if (MyRO.EnemyModel[emix].Owner=DipMem[me].pContact)
           and IsSameModel(MyRO.EnemyModel[emix],mi) then
           ok:=false;
      if ok then
        begin
        code[0,Lines[0]]:=mix;
        MakeModelInfo(me, mix, MyModel[mix], mi);
        code[2,Lines[0]]:=ModelSortValue(mi);
        inc(Lines[0]);
        end;
      end;
    SortModels;
//    if Lines[0]>1 then
      begin code[0,Lines[0]]:=mixAll; inc(Lines[0]); end;
    FirstShrinkedLine[0]:=0
    end;
  kChooseEModel:
    begin
    if MyRO.TestFlags and tfUncover<>0 then
      Server(sGetModels,me,0,nil^);
    for emix:=0 to MyRO.nEnemyModel-1 do
      ModelOk[emix]:= MyRO.EnemyModel[emix].Owner=DipMem[me].pContact;
    for mix:=0 to MyRO.nModel-1 do
      begin // don't list models I already have
      MakeModelInfo(me,mix,MyModel[mix],mi);
      for emix:=0 to MyRO.nEnemyModel-1 do
        ModelOk[emix]:=ModelOk[emix]
          and not IsSameModel(MyRO.EnemyModel[emix],mi);
      end;
    for emix:=0 to MyRO.nEnemyModel-1 do if ModelOk[emix] then
      begin
      if Tribe[DipMem[me].pContact].ModelPicture[MyRO.EnemyModel[emix].mix].HGr=0 then
        InitEnemyModel(emix);
      code[0,Lines[0]]:=emix;
      code[2,Lines[0]]:=ModelSortValue(MyRO.EnemyModel[emix]);
      inc(Lines[0]);
      end;
    SortModels;
//    if not IsMilReportNew(DipMem[me].pContact) or (Lines[0]>1) then
      begin code[0,Lines[0]]:=mixAll; inc(Lines[0]); end;
    FirstShrinkedLine[0]:=0
    end;
  kEModels:
    begin
    for i:=0 to MyRO.EnemyReport[pView].nModelCounted-1 do
      begin
      code[1,Lines[0]]:=MyRO.nEnemyModel-1;
      while (code[1,Lines[0]]>=0)
        and not ((MyRO.EnemyModel[code[1,Lines[0]]].Owner=pView)
        and (MyRO.EnemyModel[code[1,Lines[0]]].mix=i)) do
        dec(code[1,Lines[0]]);
      if Tribe[pView].ModelPicture[i].HGr=0 then
        InitEnemyModel(code[1,Lines[0]]);
      code[0,Lines[0]]:=i;
      code[2,Lines[0]]:=ModelSortValue(MyRO.EnemyModel[code[1,Lines[0]]]);
      inc(Lines[0]);
      end;
    SortModels;
    FirstShrinkedLine[0]:=0
    end;
  kAllEModels:
    begin
    if (MyRO.TestFlags and tfUncover<>0) or (G.Difficulty[me]=0) then
      Server(sGetModels,me,0,nil^);
    for emix:=0 to MyRO.nEnemyModel-1 do
      if (MyRO.EnemyModel[emix].mix>=3)
        and (MyRO.EnemyModel[emix].Kind in [mkSelfDeveloped,mkEnemyDeveloped]) then
        begin
        PPicture:=@Tribe[MyRO.EnemyModel[emix].Owner].ModelPicture[MyRO.EnemyModel[emix].mix];
        if PPicture.HGr=0 then InitEnemyModel(emix);
        ok:=true;
        if MainScreen.mNames.Checked then
          for j:=0 to Lines[0]-1 do
            begin
            PTestPicture:=@Tribe[MyRO.EnemyModel[code[0,j]].Owner].ModelPicture[MyRO.EnemyModel[code[0,j]].mix];
            if (PPicture.HGr=PTestPicture.HGr) and (PPicture.pix=PTestPicture.pix)
              and (ModelHash(MyRO.EnemyModel[emix])=ModelHash(MyRO.EnemyModel[code[0,j]])) then
              begin code[1,j]:=1; ok:=false; Break end;
            end;
        if ok then
          begin
          code[0,Lines[0]]:=emix;
          code[1,Lines[0]]:=0;
          code[2,Lines[0]]:=ModelSortValue(MyRO.EnemyModel[emix],true);
          inc(Lines[0]);
          end
        end;
    SortModels;
    FirstShrinkedLine[0]:=0
    end;
  kTribe:
    for i:=0 to TribeNames.Count-1 do
      begin code[0,Lines[0]]:=i; inc(Lines[0]) end;
(*  kDeliver:
    if MyRO.Treaty[DipMem[me].pContact]<trAlliance then
      begin // suggest next treaty level
      code[0,Lines[0]]:=opTreaty+MyRO.Treaty[DipMem[me].pContact]+1;
      inc(Lines[0]);
      end;
    if MyRO.Treaty[DipMem[me].pContact]=trNone then
      begin // suggest peace
      code[0,Lines[0]]:=opTreaty+trPeace;
      inc(Lines[0]);
      end;
    if MyRO.Treaty[DipMem[me].pContact]>trNone then
      begin // suggest next treaty level
      code[0,Lines[0]]:=opTreaty+MyRO.Treaty[DipMem[me].pContact]-1;
      inc(Lines[0]);
      end;*)
  kShipPart:
    begin
    Lines[0]:=0;
    for i:=0 to nShipPart-1 do
      if MyRO.Ship[me].Parts[i]>0 then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    end;
  kEShipPart:
    begin
    Lines[0]:=0;
    for i:=0 to nShipPart-1 do
      if MyRO.Ship[DipMem[me].pContact].Parts[i]>0 then
        begin code[0,Lines[0]]:=i; inc(Lines[0]); end;
    end;
  kGov:
    for i:=1 to nGov-1 do
      if (GovPreq[i]<>preNA) and ((GovPreq[i]=preNone)
        or (MyRO.Tech[GovPreq[i]]>=tsApplicable)) then
        begin code[0,Lines[0]]:=i; inc(Lines[0]) end;
  kMission:
    for i:=0 to nSpyMission-1 do
      begin code[0,Lines[0]]:=i; inc(Lines[0]) end;
  end;

if Kind=kProject then // test if choice fitting to one screen
  if Lines[0]+Lines[1]+Lines[2]<=MaxLines then
    begin
    for i:=0 to Lines[1]-1 do // add wonders to first page
      begin code[0,Lines[0]]:=code[1,i]; inc(Lines[0]); end;
    Lines[1]:=0;
    FirstShrinkedLine[0]:=Lines[0];
    for i:=0 to Lines[2]-1 do // add models to first page
      begin code[0,Lines[0]]:=code[2,i]; inc(Lines[0]); end;
    Lines[2]:=0;
    end;
end; // InitLines

function TListDlg.OnlyChoice(TestKind: TListKind): integer;
begin
Kind:=TestKind;
InitLines;
if Lines[0]=0 then result:=-2
else if Lines[0]>1 then result:=-1
else result:=code[0,0];
end;

procedure TListDlg.FormShow(Sender: TObject);
var
i: integer;
begin
result:=-1;
Closable:=false;

if Kind=kTribe then
  begin
  LineDistance:=21; // looks ugly with scrollbar
  MaxLines:=(hMainTexture-(24+TitleHeight+NarrowFrame)) div LineDistance -1;
  end
else
  begin
  LineDistance:=24;
  MaxLines:=(hMainTexture-(24+TitleHeight+WideFrame)) div LineDistance -1;
  end;
InitLines;

MultiPage:=false;
for i:=1 to MaxLayer-1 do if Lines[i]>0 then MultiPage:=true;
WideBottom:=MultiPage or (Kind=kScience)
  or not Phrases2FallenBackToEnglish
    and (Kind in [kProject,kAdvance,kFarAdvance]);
if (Kind=kAdvance) and (MyData.FarTech<>adNone)
  or (Kind=kModels) or (Kind=kEModels) then
  TitleHeight:=WideFrame+20
else TitleHeight:=WideFrame;

DispLines:=Lines[0];
for i:=0 to MaxLayer-1 do if Lines[i]>DispLines then DispLines:=Lines[i];
if WideBottom then
  begin
  if DispLines>MaxLines then
    DispLines:=MaxLines;
  InnerHeight:=LineDistance*(DispLines+1)+24;
  ClientHeight:=InnerHeight+TitleHeight+WideFrame
  end
else
  begin
  if DispLines>MaxLines then
    DispLines:=MaxLines;
  InnerHeight:=LineDistance*(DispLines+1)+24;
  ClientHeight:=InnerHeight+TitleHeight+NarrowFrame;
  end;
assert(ClientHeight<=hMainTexture);

TechNameSpace:=224;
case Kind of
  kGov: InnerWidth:=272;
  kCities, kCityEvents: InnerWidth:=640-18;
  kTribe:
    if Lines[0]>MaxLines then InnerWidth:=280+GetSystemMetrics(SM_CXVSCROLL)
    else InnerWidth:=280;
  kScience:
    begin
    InnerWidth:=104-33+15+8+TechNameSpace+24*nColumn+GetSystemMetrics(SM_CXVSCROLL);
    if InnerWidth+2*SideFrame>640 then
      begin
      TechNameSpace:=TechNameSpace+640-InnerWidth-2*SideFrame;
      InnerWidth:=640-2*SideFrame
      end
    end;
  kAdvance,kFarAdvance:
    InnerWidth:=104-33+15+8+TechNameSpace+24+GetSystemMetrics(SM_CXVSCROLL);
  kChooseTech, kChooseETech, kStealTech:
    InnerWidth:=104-33+15+8+TechNameSpace+GetSystemMetrics(SM_CXVSCROLL);
  else InnerWidth:=363;
  end;
ClientWidth:=InnerWidth+2*SideFrame;

CloseBtn.Left:=ClientWidth-38;
CaptionLeft:=ToggleBtn.Left+ToggleBtn.Width;
CaptionRight:=CloseBtn.Left;
SetWindowPos(sb.h,0,SideFrame+InnerWidth-GetSystemMetrics(SM_CXVSCROLL),
  TitleHeight,GetSystemMetrics(SM_CXVSCROLL),LineDistance*DispLines+48,
  SWP_NOZORDER or SWP_NOREDRAW);

if WindowMode=wmModal then
  begin {center on screen}
  if Kind=kTribe then
    Left:=(Screen.Width-800)*3 div 8+130
  else Left:=(Screen.Width-Width) div 2;
  Top:=(Screen.Height-Height) div 2;
  if Kind=kProject then
    Top:=Top+48;
  end;

Layer0Btn.Visible:= MultiPage and (Lines[0]>0);
Layer1Btn.Visible:= MultiPage and (Lines[1]>0);
Layer2Btn.Visible:= MultiPage and (Lines[2]>0);
if Kind=kProject then
  begin
  Layer0Btn.Top:=ClientHeight-31;
  Layer0Btn.Left:=ClientWidth div 2-(12+29);
  Layer0Btn.Down:=true;
  Layer1Btn.Top:=ClientHeight-31;
  Layer1Btn.Left:=ClientWidth div 2-(12-29);
  Layer1Btn.Down:=false;
  Layer2Btn.Top:=ClientHeight-31;
  Layer2Btn.Left:=ClientWidth div 2-12;
  Layer2Btn.Down:=false;
  end;

Layer:=0;
Sel:=-2;
ScienceNation:=-1;
InitPVSB(sb,Lines[Layer]-1,DispLines);

OffscreenPaint;
end;

procedure TListDlg.ShowNewContent(NewMode: integer; ListKind: TListKind);
var
i: integer;
ShowFocus, forceclose: boolean;
begin
forceclose:= (ListKind<>Kind)
  and not ((Kind=kCities) and (ListKind=kCityEvents))
  and not ((Kind=kCityEvents) and (ListKind=kCities))
  and not ((Kind=kModels) and (ListKind=kEModels))
  and not ((Kind=kEModels) and (ListKind=kModels));

Kind:=ListKind;
ModalIndication:= not (Kind in MustChooseKind);
case Kind of
  kProject: Caption:=Phrases.Lookup('TITLE_PROJECT');
  kAdvance: Caption:=Phrases.Lookup('TITLE_TECHSELECT');
  kFarAdvance: Caption:=Phrases.Lookup('TITLE_FARTECH');
  kModels, kEModels: Caption:=Phrases.Lookup('FRMILREP');
  kAllEModels: Caption:=Phrases.Lookup('TITLE_EMODELS');
  kTribe: Caption:=Phrases.Lookup('TITLE_TRIBE');
  kScience: Caption:=Phrases.Lookup('TITLE_SCIENCE');
  kShipPart, kEShipPart: Caption:=Phrases.Lookup('TITLE_CHOOSESHIPPART');
  kChooseTech, kChooseETech: Caption:=Phrases.Lookup('TITLE_CHOOSETECH');
  kChooseModel, kChooseEModel: Caption:=Phrases.Lookup('TITLE_CHOOSEMODEL');
  kStealTech: Caption:=Phrases.Lookup('TITLE_CHOOSETECH');
  kGov: Caption:=Phrases.Lookup('TITLE_GOV');
  kMission: Caption:=Phrases.Lookup('TITLE_SPYMISSION');
  end;

case Kind of
  kMission: HelpContext:='SPYMISSIONS';
  else HelpContext:='CONCEPTS'
  end;

if Kind=kAdvance then
  begin
  ToggleBtn.ButtonIndex:=13;
  ToggleBtn.Hint:=Phrases.Lookup('FARTECH')
  end
else if Kind=kCities then
  begin
  ToggleBtn.ButtonIndex:=15;
  ToggleBtn.Hint:=Phrases.Lookup('BTN_PAGE')
  end
else
  begin
  ToggleBtn.ButtonIndex:=28;
  ToggleBtn.Hint:=Phrases.Lookup('BTN_SELECT')
  end;

if Kind=kAdvance then // show focus button?
  if MyData.FarTech<>adNone then
    ShowFocus:=true
  else
    begin
    ShowFocus:=false;
    for i:=0 to nAdv-1 do
      if not (i in FutureTech) and (MyRO.Tech[i]<tsApplicable)
        and ((AdvValue[i]<2000) or (MyRO.Tech[adMassProduction]>tsNA))
        and ((AdvValue[i]<1000) or (MyRO.Tech[adScience]>tsNA))
        and (Server(sSetResearch-sExecute,me,i,nil^)<rExecuted) then
        ShowFocus:=true;
    end;
ToggleBtn.Visible:= (Kind=kCities) and not supervising
  or (Kind=kAdvance) and ShowFocus
  or (Kind=kModels)
  or (Kind=kEModels);
CloseBtn.Visible:= not(Kind in MustChooseKind);

inherited ShowNewContent(NewMode, forceclose);
end; // ShowNewContent

procedure TListDlg.ShowNewContent_CityProject(NewMode, cix: integer);
begin
cixProject:=cix;
ShowNewContent(NewMode, kProject);
end;

procedure TListDlg.ShowNewContent_MilReport(NewMode, p: integer);
begin
pView:=p;
if p=me then ShowNewContent(NewMode, kModels)
else ShowNewContent(NewMode, kEModels)
end;

procedure TListDlg.PlayerClick(Sender: TObject);
begin
if TComponent(Sender).Tag=me then Kind:=kModels
else
  begin
  Kind:=kEModels;
  pView:=TComponent(Sender).Tag;
  end;
InitLines;
Sel:=-2;
InitPVSB(sb,Lines[Layer]-1,DispLines);
OffscreenPaint;
Invalidate
end;

procedure TListDlg.ModeBtnClick(Sender: TObject);
begin
Layer0Btn.Down:= Sender=Layer0Btn;
Layer1Btn.Down:= Sender=Layer1Btn;
Layer2Btn.Down:= Sender=Layer2Btn;
Layer:=TComponent(Sender).Tag;

Sel:=-2;
InitPVSB(sb,Lines[Layer]-1,DispLines);
SmartUpdateContent
end;

procedure TListDlg.ToggleBtnClick(Sender: TObject);
var
p1: integer;
m: TMenuItem;
begin
case Kind of
  kAdvance:
    begin
    result:=adFar;
    Closable:=true;
    Close
    end;
  kCities, kCityEvents:
    begin
    if Kind=kCities then Kind:=kCityEvents
    else Kind:=kCities;
    OffscreenPaint;
    Invalidate;
    end;
  kModels, kEModels:
    begin
    EmptyMenu(Popup.Items);
    if G.Difficulty[me]>0 then
      begin
      m:=TMenuItem.Create(Popup);
      m.RadioItem:=true;
      m.Caption:=Tribe[me].TPhrase('SHORTNAME');
      m.Tag:=me;
      m.OnClick:=PlayerClick;
      if Kind=kModels then m.Checked:=true;
      Popup.Items.Add(m);
      end;
    for p1:=0 to nPl-1 do
      if (p1<>me) and (MyRO.EnemyReport[p1]<>nil)
        and (MyRO.EnemyReport[p1].TurnOfMilReport>=0) then
        begin
        m:=TMenuItem.Create(Popup);
        m.RadioItem:=true;
        m.Caption:=Tribe[p1].TPhrase('SHORTNAME');
        m.Tag:=p1;
        m.OnClick:=PlayerClick;
        if (Kind=kEModels) and (p1=pView) then m.Checked:=true;
        Popup.Items.Add(m);
        end;
    Popup.Popup(Left+ToggleBtn.Left, Top+ToggleBtn.Top+ToggleBtn.Height);
    end
  end
end;

procedure TListDlg.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
if (Key=VK_F2) and (Kind in [kModels,kEModels]) then // my key
  // !!! toggle
else if (Key=VK_F3) and (Kind in [kCities,kCityEvents]) then // my key
  ToggleBtnClick(nil)
else if ((Key=VK_ESCAPE) or (Key=VK_RETURN)) and not CloseBtn.Visible then // prevent closing
else inherited
end;

procedure TListDlg.EcoChange;
begin
if Visible and (Kind=kCities) then SmartUpdateContent
end;

procedure TListDlg.TechChange;
begin
if Visible and (Kind=kScience) then
  begin
  FormShow(nil);
  Invalidate;
  end;
end;

procedure TListDlg.AddCity;
begin
if Visible and (Kind=kCities) then
  begin
  FormShow(nil);
  Invalidate;
  end;
end;

procedure TListDlg.RemoveUnit;
begin
if ListDlg.Visible and (Kind=kModels) then
  SmartUpdateContent;
end;

end.

