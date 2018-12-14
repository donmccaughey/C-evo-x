{$INCLUDE switches}

unit UnitStat;

interface

uses
  Protocol,ClientTools,Term,ScreenTools,BaseWin,

  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,ButtonA,ButtonB,
  ButtonBase, ButtonC;

type
  TUnitStatDlg = class(TBufferedDrawDlg)
    SwitchBtn: TButtonB;
    CloseBtn: TButtonB;
    ConscriptsBtn: TButtonB;
    HelpBtn: TButtonC;
    procedure FormShow(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ModelBoxChange(Sender: TObject);
    procedure SwitchBtnClick(Sender: TObject);
    procedure ConscriptsBtnClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure HelpBtnClick(Sender: TObject);

  public
    procedure CheckAge;
    procedure ShowNewContent_OwnModel(NewMode, mix: integer);
    procedure ShowNewContent_OwnUnit(NewMode, uix: integer);
    procedure ShowNewContent_EnemyUnit(NewMode, euix: integer);
    procedure ShowNewContent_EnemyLoc(NewMode, Loc: integer);
    procedure ShowNewContent_EnemyModel(NewMode, emix: integer);
    procedure ShowNewContent_EnemyCity(NewMode, Loc: integer);

  protected
    mixShow, // for dkOwnModel
    uixShow,euixShow,ecixShow,
    UnitLoc,AgePrepared: integer; // for dkEnemyUnit, euixShow=-1 ->
    mox: ^TModelInfo; // for dkEnemyModel
    Kind:(dkOwnModel,dkOwnUnit,dkEnemyModel,dkEnemyUnit,dkEnemyCityDefense,dkEnemyCity);
    Back, Template: TBitmap;
    procedure OffscreenPaint; override;
  end;

var
  UnitStatDlg: TUnitStatDlg;

implementation

uses Inp, Select, Tribes, IsoEngine, Help, Directories;

{$R *.DFM}

const
xView=71;
xTotal=20; StatDown=112;
yImp=133;

// window size
wCommon=208; hOwnModel=293; hEnemyModel=236; hEnemyUnit=212;
hEnemyCityDefense=320; hEnemyCity=166; hMax=320;


procedure TUnitStatDlg.FormCreate(Sender: TObject);
begin
inherited;
AgePrepared:=-2;
TitleHeight:=Screen.Height;
InitButtons();

Back:=TBitmap.Create;
Back.PixelFormat:=pf24bit;
Back.Width:=5*wCommon; Back.Height:=hMax;
Template:=TBitmap.Create;
LoadGraphicFile(Template, HomeDir+'Graphics\Unit', gfNoGamma);
Template.PixelFormat:=pf8bit;
end;

procedure TUnitStatDlg.FormDestroy(Sender: TObject);
begin
Template.Free;
Back.Free;
end;

procedure TUnitStatDlg.CheckAge;
begin
if MainTextureAge<>AgePrepared then
  begin
  AgePrepared:=MainTextureAge;
  bitblt(Back.Canvas.Handle,0,0,wCommon,hOwnModel,
    MainTexture.Image.Canvas.Handle,(wMainTexture-wCommon) div 2,
    (hMainTexture-hOwnModel) div 2,SRCCOPY);
  bitblt(Back.Canvas.Handle,wCommon,0,wCommon,hEnemyModel,
    MainTexture.Image.Canvas.Handle,(wMainTexture-wCommon) div 2,
    (hMainTexture-hEnemyModel) div 2,SRCCOPY);
  bitblt(Back.Canvas.Handle,2*wCommon,0,wCommon,hEnemyUnit,
    MainTexture.Image.Canvas.Handle,(wMainTexture-wCommon) div 2,
    (hMainTexture-hEnemyUnit) div 2,SRCCOPY);
  bitblt(Back.Canvas.Handle,3*wCommon,0,wCommon,hEnemyCityDefense,
    MainTexture.Image.Canvas.Handle,(wMainTexture-wCommon) div 2,
    (hMainTexture-hEnemyCityDefense) div 2,SRCCOPY);
  bitblt(Back.Canvas.Handle,4*wCommon,0,wCommon,hEnemyCity,
    MainTexture.Image.Canvas.Handle,(wMainTexture-wCommon) div 2,
    (hMainTexture-hEnemyCity) div 2,SRCCOPY);
  ImageOp_B(Back,Template,0,0,0,0,5*wCommon,hMax);
  end
end;

procedure TUnitStatDlg.FormShow(Sender: TObject);
var
owner, mix: integer;
IsSpecialUnit: boolean;
begin
if Kind in [dkEnemyUnit,dkEnemyCityDefense,dkEnemyCity] then
  begin
  if MyMap[UnitLoc] and fUnit<>0 then
    begin // find model
    if euixShow<0 then
      begin
      euixShow:=MyRO.nEnemyUn-1;
      while (euixShow>=0) and (MyRO.EnemyUn[euixShow].Loc<>UnitLoc) do dec(euixShow);
      assert(euixShow>=0);
      end;
    with MyRO.EnemyUn[euixShow] do
      begin
      mox:=@MyRO.EnemyModel[emix];
      if Tribe[Owner].ModelPicture[mix].HGr=0 then
        InitEnemyModel(emix);
      end
    end
  else mox:=nil;
  if Kind in [dkEnemyCityDefense,dkEnemyCity] then
    begin
    ecixShow:=MyRO.nEnemyCity-1;
    while (ecixShow>=0) and (MyRO.EnemyCity[ecixShow].Loc<>UnitLoc) do dec(ecixShow);
    assert(ecixShow>=0);
    end
  end;
case Kind of
  dkOwnModel: ClientHeight:=hOwnModel;
  dkOwnUnit: ClientHeight:=hEnemyUnit;
  dkEnemyModel: ClientHeight:=hEnemyModel;
  dkEnemyUnit: ClientHeight:=hEnemyUnit;
  dkEnemyCityDefense: ClientHeight:=hEnemyCityDefense;
  dkEnemyCity: ClientHeight:=hEnemyCity;
  end;

if Kind in [dkOwnModel,dkEnemyModel] then
  begin
  Left:=UserLeft;
  Top:=UserTop;
  end
else
  begin
  Left:=(Screen.Width-Width) div 2;
  Top:=(Screen.Height-Height) div 2;
  end;

SwitchBtn.Visible:= not supervising and (Kind=dkOwnModel);
ConscriptsBtn.Visible:= not supervising and (Kind=dkOwnModel)
  and (MyRO.Tech[adConscription]>=tsApplicable)
  and (MyModel[mixShow].Domain=dGround) and (MyModel[mixShow].Kind<mkScout);
IsSpecialUnit:=false;
if Kind in [dkEnemyCity,dkEnemyCityDefense] then
   Caption:=CityName(MyRO.EnemyCity[ecixShow].ID)
else
  begin
  case Kind of
    dkOwnModel:
      begin
      owner:=me;
      mix:=mixShow;
      IsSpecialUnit:= MyModel[mix].Kind>=$10;
      end;
    dkOwnUnit:
      begin
      owner:=me;
      mix:=MyUn[uixShow].mix;
      IsSpecialUnit:= MyModel[mix].Kind>=$10;
      end
    else
      begin
      owner:=mox.owner;
      mix:=mox.mix;
      IsSpecialUnit:= mox.Kind>=$10;
      end;
    end;
  if MainScreen.mNames.Checked then
    Caption:=Tribe[Owner].ModelName[mix]
  else Caption:=Format(Tribe[Owner].TPhrase('GENMODEL'),[mix])
  end;
if IsSpecialUnit then
  HelpBtn.Hint:=Phrases.Lookup('CONTROLS',6);
HelpBtn.Visible:=IsSpecialUnit;
OffscreenPaint;
end;

procedure TUnitStatDlg.ShowNewContent_OwnModel(NewMode, mix: integer);
begin
Kind:=dkOwnModel;
mixShow:=mix;
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.ShowNewContent_OwnUnit(NewMode, uix: integer);
begin
Kind:=dkOwnUnit;
uixShow:=uix;
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.ShowNewContent_EnemyUnit(NewMode, euix: integer);
begin
Kind:=dkEnemyUnit;
euixShow:=euix;
UnitLoc:=MyRO.EnemyUn[euix].Loc;
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.ShowNewContent_EnemyLoc(NewMode, Loc: integer);
begin
Kind:=dkEnemyUnit;
UnitLoc:=Loc;
euixShow:=-1;
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.ShowNewContent_EnemyModel(NewMode, emix: integer);
begin
Kind:=dkEnemyModel;
mox:=@MyRO.EnemyModel[emix];
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.ShowNewContent_EnemyCity(NewMode, Loc: integer);
begin
if MyMap[Loc] and fUnit<>0 then
  Kind:=dkEnemyCityDefense
else Kind:=dkEnemyCity;
UnitLoc:=Loc;
euixShow:=-1;
inherited ShowNewContent(NewMode);
end;

procedure TUnitStatDlg.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
if Kind in [dkOwnModel,dkEnemyModel] then
  begin UserLeft:=Left; UserTop:=Top end;
if OffscreenUser=self then OffscreenUser:=nil;
end;

procedure TUnitStatDlg.CloseBtnClick(Sender: TObject);
begin
Close
end;

procedure TUnitStatDlg.OffscreenPaint;
var
PPicture: ^TModelPicture;

  function IsToCount(emix: integer): boolean;
  var
  PTestPicture: ^TModelPicture;
  begin
  if MainScreen.mNames.Checked then
    begin
    PTestPicture:=@Tribe[MyRO.EnemyModel[emix].Owner].ModelPicture[MyRO.EnemyModel[emix].mix];
    result:= (PPicture.HGr=PTestPicture.HGr) and (PPicture.pix=PTestPicture.pix)
      and (ModelHash(mox^)=ModelHash(MyRO.EnemyModel[emix]))
    end
  else result:= (MyRO.EnemyModel[emix].Owner=mox.Owner)
    and (MyRO.EnemyModel[emix].mix=mox.mix)
  end;

  procedure FeatureBar(dst: TBitmap; x,y: integer; const mi: TModelInfo;
    const T: TTexture);
  var
  i,w,dx,num: integer;
  s: string;
  begin
  DarkGradient(dst.Canvas,x-6,y+1,180,1);
  with dst.Canvas do
    if mi.Kind>=$10 then
      begin
      s:=Phrases.Lookup('UNITSPECIAL');
      Font.Color:=$000000;
      Textout(x-1,y+1,s);
      Font.Color:=$B0B0B0;
      Textout(x-2,y,s);
      end
    else
      begin
      Font.Color:=$000000;
      dx:=2;
      for i:=3 to nFeature-1 do
        begin
        num:=0;
        case i of
          mcSeaTrans: if mi.Domain=dSea then num:=mi.TTrans;
          mcCarrier: if mi.Domain=dSea then num:=mi.ATrans_Fuel;
          mcBombs: num:=mi.Bombs;
          mcFuel: if mi.Domain=dAir then num:=mi.ATrans_Fuel;
          mcAirTrans: if mi.Domain=dAir then num:=mi.TTrans;
          mcFirstNonCap..nFeature-1:
            if mi.Cap and (1 shl (i-mcFirstNonCap))<>0 then num:=1
          end;
        if (num>0) and ((i<>mcSE) or (mi.Cap and (1 shl (mcNP-mcFirstNonCap))=0)) then
          begin
          if num>1 then
            begin
            s:=IntToStr(num);
            w:=TextWidth(s);
            Brush.Color:=$FFFFFF;
            FillRect(Rect(x-3+dx,y+2,x+w-1+dx,y+16));
            Brush.Style:=bsClear;
            Textout(x-3+dx+1,y,s);
            inc(dx,w+1)
            end;
          Brush.Color:=$C0C0C0;
          FrameRect(Rect(x-3+dx,y+2,x+11+dx,y+16));
          Brush.Style:=bsClear;
          Sprite(dst,HGrSystem,x-1+dx,y+4,10,10,66+i mod 11 *11,137+i div 11 *11);
          inc(dx,15)
          end;
        end
      end
  end;{featurebar}

  procedure NumberBarS(dst:TBitmap; x,y:integer;
    Cap,s: string; const T: TTexture);
  begin
  DLine(dst.Canvas,x-2,x+170,y+16,T.clBevelShade,T.clBevelLight);
  LoweredTextOut(dst.Canvas,-1,T,x-2,y,Cap);
  RisedTextout(dst.canvas,x+170-BiColorTextWidth(dst.Canvas,s),y,s);
  end;

var
i,j,x,y,cix,uix,emix,InProd,Available,Destroyed,Loc,Cnt,yView,yTotal,
  yCaption: integer;
s: string;
ui: TUnitInfo;
mi: TModelInfo;
begin
inherited;

case Kind of
  dkOwnModel:
    begin
    bitblt(offscreen.canvas.handle,0,0,wCommon,hOwnModel,Back.Canvas.handle,0,0,SRCCOPY);
    yView:=13;
    yTotal:=92;
    end;
  dkEnemyModel:
    begin
    bitblt(offscreen.canvas.handle,0,0,wCommon,hEnemyModel,Back.Canvas.handle,wCommon,0,SRCCOPY);
    yView:=13;
    yTotal:=92;
    end;
  dkEnemyUnit,dkOwnUnit:
    begin
    bitblt(offscreen.canvas.handle,0,0,wCommon,hEnemyUnit,Back.Canvas.handle,2*wCommon,0,SRCCOPY);
    yView:=13;
    yTotal:=123;
    end;
  dkEnemyCityDefense:
    begin
    bitblt(offscreen.canvas.handle,0,0,wCommon,hEnemyCityDefense,Back.Canvas.handle,3*wCommon,0,SRCCOPY);
    yView:=171;
    yTotal:=231;
    end;
  dkEnemyCity:
    begin
    bitblt(offscreen.canvas.handle,0,0,wCommon,hEnemyCity,Back.Canvas.handle,4*wCommon,0,SRCCOPY);
    end;
  end;
MarkUsedOffscreen(ClientWidth,ClientHeight);
HelpBtn.Top:=yTotal+22;

if Kind in [dkEnemyCityDefense,dkEnemyCity] then
  begin // show city defense facilities
  cnt:=0;
  for i:=0 to 3 do
    if MyRO.EnemyCity[ecixShow].Flags and (2 shl i)<>0 then
      inc(cnt);
  x:=(wCommon-cnt*xSizeSmall) div 2 -(cnt-1)*2;
  for i:=0 to 3 do
    if MyRO.EnemyCity[ecixShow].Flags and (2 shl i)<>0 then
      begin
      case i of
        0: j:=imWalls;
        1: j:=imCoastalFort;
        2: j:=imMissileBat;
        3: j:=imBunker
        end;
      Frame(offscreen.Canvas,x-1,yImp-1,x+xSizeSmall,yImp+ySizeSmall,
        MainTexture.clBevelLight,MainTexture.clBevelShade);
      BitBlt(offscreen.Canvas.Handle,x,yImp,xSizeSmall,ySizeSmall,
        SmallImp.Canvas.Handle,j mod 7*xSizeSmall,
        (j+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY);
      inc(x,xSizeSmall+4)
      end;
  end;

if Kind=dkEnemyModel then
  begin
  PPicture:=@Tribe[mox.Owner].ModelPicture[mox.mix];
  Available:=0;
  if G.Difficulty[me]=0 then // supervisor -- count stacked units too
    for Loc:=0 to G.lx*G.ly-1 do
      begin
      if MyMap[Loc] and fUnit<>0 then
        begin
        Server(sGetUnits,me,Loc,Cnt);
        for uix:=0 to Cnt-1 do
          if IsToCount(MyRO.EnemyUn[MyRO.nEnemyUn+uix].emix) then
            inc(Available);
        end
      end
  else // no supervisor -- can only count stack top units
    for uix:=0 to MyRO.nEnemyUn-1 do
      if (MyRO.EnemyUn[uix].Loc>=0) and IsToCount(MyRO.EnemyUn[uix].emix) then
        inc(Available);
  Destroyed:=0;
  for emix:=0 to MyRO.nEnemyModel-1 do if IsToCount(emix) then
    inc(Destroyed,MyRO.EnemyModel[emix].Lost);
  end
else
  begin
  Available:=0;
  for uix:=0 to MyRO.nUn-1 do
    if (MyUn[uix].Loc>=0) and (MyUn[uix].mix=mixShow) then inc(Available);
  InProd:=0;
  for cix:=0 to MyRO.nCity-1 do
    if (MyCity[cix].Loc>=0) and (MyCity[cix].Project and (cpImp+cpIndex)=mixShow) then
      inc(InProd);
  end;

offscreen.Canvas.Font.Assign(UniFont[ftSmall]);
if Kind in [dkEnemyCityDefense,dkEnemyCity] then
  begin
  NoMap.SetOutput(offscreen);
  NoMap.PaintCity(ClientWidth div 2,53,MyRO.EnemyCity[ecixShow],false);

  s:=Tribe[MyRO.EnemyCity[ecixShow].Owner].TPhrase('UNITOWNER');
  LoweredTextOut(offscreen.Canvas, -1, MainTexture,
    (ClientWidth-BiColorTextWidth(offscreen.Canvas,s)) div 2, 105, s);
  end;

if Kind<>dkEnemyCity then
  begin // show unit stats
  if Kind=dkOwnModel then
    MakeModelInfo(me,mixShow,MyModel[mixShow],mi)
  else if Kind=dkOwnUnit then
    begin
    MakeUnitInfo(me,MyUn[uixShow],ui);
    MakeModelInfo(me,MyUn[uixShow].mix,MyModel[MyUn[uixShow].mix],mi)
    end
  else
    begin
    mi:=mox^;
    if Kind in [dkEnemyUnit,dkEnemyCityDefense] then
      ui:=MyRO.EnemyUn[euixShow]
    end;

  with Tribe[mi.Owner].ModelPicture[mi.mix] do
    begin
    if Kind in [dkOwnUnit,dkEnemyUnit,dkEnemyCityDefense] then with ui do
      begin
      {Frame(offscreen.canvas,xView-1,yView-1,xView+64,yView+48,
        MainTexture.clBevelShade,MainTexture.clBevelLight);
      RFrame(offscreen.canvas,xView-2,yView-2,xView+65,yView+49,
        MainTexture.clBevelShade,MainTexture.clBevelLight);}
      with offscreen.canvas do
        begin
        Brush.Color:=GrExt[HGrSystem].Data.Canvas.Pixels[98,67];
        offscreen.canvas.FillRect(Rect(xView,yView,xView+64,yView+16));
        Brush.Style:=bsClear;
        end;

      if MyMap[Loc] and fTerrain>=fForest then
        begin x:=1+2*(xxt*2+1); y:=1+yyt+2*(yyt*3+1) end
      else begin x:=integer(MyMap[Loc] and fTerrain) *(xxt*2+1)+1; y:=1+yyt end;
      for j:=-1 to 1 do for i:=-1 to 1 do if (i+j) and 1=0 then
        begin
        Sprite(Buffer,HGrTerrain,i*xxt,j*yyt,xxt*2,yyt*2,x,y);
        if MyMap[Loc] and (fTerrain or fSpecial)=fGrass or fSpecial1 then
          Sprite(Buffer,HGrTerrain,i*xxt,j*yyt,xxt*2,yyt*2,1+2*(xxt*2+1),
            1+yyt+1*(yyt*3+1))
        else if (MyMap[Loc] and fTerrain=fForest)
          and IsJungle(Loc div G.lx) then
          Sprite(Buffer,HGrTerrain,i*xxt,j*yyt,xxt*2,yyt*2,1+7*(xxt*2+1),
            1+yyt+19*(yyt*3+1))
        else if MyMap[Loc] and fTerrain>=fForest then
          Sprite(Buffer,HGrTerrain,i*xxt,j*yyt,xxt*2,yyt*2,1+7*(xxt*2+1),
            1+yyt+2*integer(2+MyMap[Loc] and fTerrain-fForest)*(yyt*3+1));
        end;
      BitBlt(offscreen.canvas.handle,xView,yView+16,64,32,Buffer.Canvas.Handle,1,0,
        SRCCOPY);

      // show unit, experience and health
      Sprite(offscreen,HGr,xView,yView,64,48,pix mod 10 *65+1,pix div 10*49+1);
      if Flags and unFortified<>0 then
        Sprite(offscreen,HGrStdUnits,xView,yView,xxu*2,yyu*2,1+6*(xxu*2+1),1);
      FrameImage(offscreen.canvas,GrExt[HGrSystem].Data,xView-20,yView+5,12,14,
        121+Exp div ExpCost *13,28);
      if Health<100 then
        begin
        s:=IntToStr(Health)+'%';
        LightGradient(offscreen.canvas,xView-45,yView+24,38,
          (ColorOfHealth(Health) and $FEFEFE shr 2)*3);
        RisedTextOut(offscreen.canvas,xView-45+20-BiColorTextWidth(offscreen.Canvas,s) div 2,
          yView+23,s);
        end;

      if Kind=dkEnemyUnit then
        begin
        s:=Tribe[mox.Owner].TPhrase('UNITOWNER');
        LoweredTextOut(offscreen.Canvas, -1, MainTexture,
          (ClientWidth-BiColorTextWidth(offscreen.Canvas,s)) div 2, yView+80, s);
        end
      end
    else
      begin
      FrameImage(offscreen.canvas,BigImp,xView+4,yView,56,40,0,0);
      Sprite(offscreen,HGr,xView,yView-4,64,44,pix mod 10 *65+1,pix div 10*49+1);
      end;

    DarkGradient(offscreen.Canvas,xTotal-6,yTotal+1,180,2);
    RisedTextOut(offscreen.Canvas,xTotal-2,yTotal,Phrases.Lookup('UNITSTRENGTH'));
    s:=IntToStr(mi.Attack)+'/'+IntToStr(mi.Defense);
    RisedTextOut(offscreen.Canvas,xTotal+170-BiColorTextWidth(Offscreen.Canvas,s),yTotal,s);
    FeatureBar(offscreen,xTotal,yTotal+19,mi,MainTexture);
    NumberBarS(offscreen,xTotal,yTotal+38,Phrases.Lookup('UNITSPEED'),MovementToString(mi.Speed),MainTexture);
    LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,yTotal+57,Phrases.Lookup('UNITCOST'));
    DLine(offscreen.Canvas,xTotal-2,xTotal+170,yTotal+57+16,
      MainTexture.clBevelShade,MainTexture.clBevelLight);
    if G.Difficulty[me]=0 then s:=IntToStr(mi.cost)
    else s:=IntToStr(mi.cost*BuildCostMod[G.Difficulty[me]] div 12);
    RisedTextout(offscreen.Canvas,xTotal+159-BiColorTextWidth(Offscreen.Canvas,s),yTotal+57,s);
    Sprite(offscreen,HGrSystem,xTotal+160,yTotal+57+5,10,10,88,115);

    if Kind=dkOwnModel then
      begin
      if MyModel[mixShow].IntroTurn>0 then
        begin
        if MyModel[mixShow].Kind=mkEnemyDeveloped then
          LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,(yTotal+StatDown-19),Phrases.Lookup('UNITADOPT'))
        else LoweredTextOut(offscreen.Canvas,-1,MainTexture,xTotal-2,(yTotal+StatDown-19),Phrases.Lookup('UNITINTRO'));
        DLine(offscreen.Canvas,xTotal-2,xTotal+170,(yTotal+StatDown-19)+16,
          MainTexture.clTextShade,MainTexture.clTextLight);
        s:=TurnToString(MyModel[mixShow].IntroTurn);
        RisedTextOut(offscreen.Canvas,xTotal+170-BiColorTextWidth(Offscreen.Canvas,s),(yTotal+StatDown-19),s);
        end;

      NumberBar(offscreen,xTotal,yTotal+StatDown,Phrases.Lookup('UNITBUILT'),MyModel[mixShow].Built,MainTexture);
      if MyModel[mixShow].Lost>0 then
        NumberBar(offscreen,xTotal,yTotal+StatDown+19,Phrases.Lookup('UNITLOST'),MyModel[mixShow].Lost,MainTexture);
      if InProd>0 then
        NumberBar(offscreen,xTotal,yTotal+StatDown+57,Phrases.Lookup('UNITINPROD'),InProd,MainTexture);
      if Available>0 then
        NumberBar(offscreen,xTotal,yTotal+StatDown+38,Phrases.Lookup('UNITAVAILABLE'),Available,MainTexture);

      if MyModel[mixShow].Status and msObsolete<>0 then
        begin
        SwitchBtn.ButtonIndex:=12;
        SwitchBtn.Hint:=Phrases.Lookup('BTN_OBSOLETE');
        end
      else
        begin
        SwitchBtn.ButtonIndex:=11;
        SwitchBtn.Hint:=Phrases.Lookup('BTN_NONOBSOLETE');
        end;
      if MyModel[mixShow].Status and msAllowConscripts=0 then
        begin
        ConscriptsBtn.ButtonIndex:=30;
        ConscriptsBtn.Hint:=Phrases.Lookup('BTN_NOCONSCRIPTS');
        end
      else
        begin
        ConscriptsBtn.ButtonIndex:=29;
        ConscriptsBtn.Hint:=Phrases.Lookup('BTN_ALLOWCONSCRIPTS');
        end
      end
    else if Kind=dkEnemyModel then
      begin
      if Destroyed>0 then
        NumberBar(offscreen,xTotal,yTotal+StatDown-19,Phrases.Lookup('UNITDESTROYED'),Destroyed,MainTexture);
      if Available>0 then
        NumberBar(offscreen,xTotal,yTotal+StatDown,Phrases.Lookup('UNITKNOWN'),Available,MainTexture);
      end
    end;
  end;

offscreen.Canvas.Font.Assign(UniFont[ftNormal]);
case Kind of
  dkOwnModel,dkEnemyModel: yCaption:=yView+46;
  dkEnemyUnit,dkOwnUnit: yCaption:=yView+54;
  dkEnemyCityDefense,dkEnemyCity: yCaption:=79;
  end;
RisedTextOut(offscreen.Canvas, (ClientWidth-BiColorTextWidth(offscreen.Canvas,caption)) div 2, yCaption, caption);
end; {OffscreenPaint}

procedure TUnitStatDlg.ModelBoxChange(Sender: TObject);
begin
SmartUpdateContent
end;

procedure TUnitStatDlg.SwitchBtnClick(Sender: TObject);
begin
MyModel[mixShow].Status:=MyModel[mixShow].Status xor msObsolete;
if MyModel[mixShow].Status and msObsolete<>0 then
  begin
  SwitchBtn.ButtonIndex:=12;
  SwitchBtn.Hint:=Phrases.Lookup('BTN_OBSOLETE');
  end
else
  begin
  SwitchBtn.ButtonIndex:=11;
  SwitchBtn.Hint:=Phrases.Lookup('BTN_NONOBSOLETE');
  end
end;

procedure TUnitStatDlg.ConscriptsBtnClick(Sender: TObject);
begin
MyModel[mixShow].Status:=MyModel[mixShow].Status xor msAllowConscripts;
if MyModel[mixShow].Status and msAllowConscripts=0 then
  begin
  ConscriptsBtn.ButtonIndex:=30;
  ConscriptsBtn.Hint:=Phrases.Lookup('BTN_NOCONSCRIPTS');
  end
else
  begin
  ConscriptsBtn.ButtonIndex:=29;
  ConscriptsBtn.Hint:=Phrases.Lookup('BTN_ALLOWCONSCRIPTS');
  end
end;

procedure TUnitStatDlg.HelpBtnClick(Sender: TObject);
begin
HelpDlg.ShowNewContent(wmPersistent, hkModel, 0)
end;

end.

