{$INCLUDE switches}
unit CityProcessing;

interface

uses
Protocol, Database;

// Reporting
procedure GetCityAreaInfo(p,Loc: integer; var CityAreaInfo: TCityAreaInfo);
function CanCityGrow(p,cix: integer): boolean;
function GetCityReport(p,cix: integer; var CityReport: TCityReport): integer;
function GetCityReportNew(p,cix: integer; var CityReportNew: TCityReportNew): integer;

// Internal Tile Picking
function AddBestCityTile(p,cix: integer): boolean;
procedure CityGrowth(p,cix: integer);
procedure CityShrink(p,cix: integer);
procedure Pollute(p,cix: integer);

// Turn Processing
procedure PayCityMaintenance(p,cix: integer);
procedure CollectCityResources(p,cix: integer);
function CityTurn(p,cix: integer): boolean;

// Tile Access
function SetCityTiles(p, cix, NewTiles: integer; TestOnly: boolean = false): integer;
procedure GetCityTileAdvice(p, cix: integer; var Advice: TCityTileAdviceData);

// Start/End Game
procedure InitGame;
procedure ReleaseGame;


implementation

type
TTradeProcessing=record
  TaxBonus,LuxBonus,ScienceBonus,FutResBonus,ScienceDoubling,HappyBase: integer;
  RelCorr: single;
  FlexibleLuxury: boolean;
  end;

TProdProcessing=record
  ProdBonus,PollBonus,FutProdBonus,PollThreshold: integer;
  end;

PCityReportEx=^TCityReportEx;
TCityReportEx=record
  BaseHappiness,BaseControl,Material: integer;
  ProdProcessing: TProdProcessing;
  TradeProcessing: TTradeProcessing;
  end;

var
MaxDist: integer;

{
                               Reporting
 ____________________________________________________________________
}
procedure GetCityAreaInfo(p,Loc: integer; var CityAreaInfo: TCityAreaInfo);
var
V21, Loc1, p1: integer;
Radius: TVicinity21Loc;
begin
{$IFOPT O-}assert(1 shl p and InvalidTreatyMap=0);{$ENDIF}
with CityAreaInfo do
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=0 to 26 do
    begin
    Loc1:=Radius[V21];
    if (Loc1<0) or (Loc1>=MapSize) then Available[V21]:=faInvalid
    else
      begin
      p1:=RealMap[Loc1] shr 27;
      if (p1<nPl) and (p1<>p) and (RW[p].Treaty[p1]>=trPeace) then
        Available[V21]:=faTreaty
      else if (ZoCMap[Loc1]>0) and (Occupant[Loc1]<>p)
        and (RW[p].Treaty[Occupant[Loc1]]<trAlliance) then
        Available[V21]:=faSiege
      else if (UsedByCity[Loc1]<>-1) and (UsedByCity[Loc1]<>Loc) then
        Available[V21]:=faNotAvailable
      else Available[V21]:=faAvailable
      end
    end;
  end
end;

function CanCityGrow(p,cix: integer): boolean;
begin
with RW[p].City[cix] do
  result:= (Size<MaxCitySize) and ((Size<NeedAqueductSize)
      or (Built[imAqueduct]=1) and (Size<NeedSewerSize)
      or (Built[imSewer]=1));
end;

procedure DetermineCityProdProcessing(p,cix: integer;
  var ProdProcessing: TProdProcessing);
begin
with RW[p].City[cix],ProdProcessing do
  begin
  ProdBonus:=0;
  PollBonus:=0;
  if Built[imFactory]=1 then
    inc(ProdBonus);
  if Built[imMfgPlant]=1 then
    inc(ProdBonus);
  if (Built[imPower]=1) or (Built[imHydro]=1)
    or (Built[imNuclear]=1) or (GWonder[woHoover].EffectiveOwner=p) then
    ProdBonus:=ProdBonus*2;
  if Built[imFactory]=1 then
    inc(PollBonus);
  if Built[imMfgPlant]=1 then
    inc(PollBonus);
  if (Built[imFactory]+Built[imMfgPlant]>0) then
    if (Built[imHydro]>0)
      or (GWonder[woHoover].EffectiveOwner=p) then
        dec(PollBonus)
    else if (Built[imNuclear]=0) and (Built[imPower]=1) then
      inc(PollBonus);
  if (RW[p].Government<=gDespotism) or (Built[imRecycling]=1) then
    PollBonus:=-2; // no pollution
  PollThreshold:=Size;
  FutProdBonus:=0;
  if RW[p].Tech[futProductionTechnology]>0 then
    begin // future tech benefits
    if Built[imFactory]=1 then
      inc(FutProdBonus,FactoryFutureBonus*RW[p].Tech[futProductionTechnology]);
    if Built[imMfgPlant]=1 then
      inc(FutProdBonus,MfgPlantFutureBonus*RW[p].Tech[futProductionTechnology]);
    end;
  end;
end;

procedure BoostProd(BaseProd: integer; ProdProcessing: TProdProcessing;
  var Prod,Poll: integer);
begin
Poll:=BaseProd*(2+ProdProcessing.PollBonus) shr 1;
if Poll<=ProdProcessing.PollThreshold then
  Poll:=0
else dec(Poll,ProdProcessing.PollThreshold);
if ProdProcessing.FutProdBonus>0 then
  Prod:=BaseProd*(100+ProdProcessing.ProdBonus*50+ProdProcessing.FutProdBonus) div 100
else Prod:=BaseProd*(2+ProdProcessing.ProdBonus) shr 1;
end;

procedure DetermineCityTradeProcessing(p,cix,HappinessBeforeLux: integer;
  var TradeProcessing: TTradeProcessing);
var
i,Dist: integer;
begin
with RW[p].City[cix],TradeProcessing do
  begin
  TaxBonus:=0;
  ScienceBonus:=0;
  if Built[imMarket]=1 then
    inc(TaxBonus,2);
  if Built[imBank]=1 then
    begin
    inc(TaxBonus,3);
    if RW[p].NatBuilt[imStockEx]=1 then
      inc(TaxBonus,3);
    end;
  LuxBonus:=TaxBonus;
  if Built[imLibrary]=1 then
    inc(ScienceBonus,2);
  if Built[imUniversity]=1 then
    inc(ScienceBonus,3);
  if Built[imResLab]=1 then
    inc(ScienceBonus,3);
  ScienceDoubling:=0;
  if Built[imNatObs]>0 then
    inc(ScienceDoubling);
  if RW[p].Government=gFundamentalism then
    dec(ScienceDoubling)
  else if (GWonder[woNewton].EffectiveOwner=p) and (RW[p].Government=gMonarchy) then
    inc(ScienceDoubling);
  FlexibleLuxury:=
    ((ServerVersion[p]>=$0100F1) and (GWonder[woLiberty].EffectiveOwner=p)
      or (ServerVersion[p]<$0100F1) and (GWonder[woMich].EffectiveOwner=p))
    and (RW[p].Government<>gAnarchy);
  FutResBonus:=0;
  if RW[p].Tech[futResearchTechnology]>0 then
    begin // future tech benefits
    if Built[imUniversity]=1 then
      inc(FutResBonus,UniversityFutureBonus*RW[p].Tech[futResearchTechnology]);
    if Built[imResLab]=1 then
      inc(FutResBonus,ResLabFutureBonus*RW[p].Tech[futResearchTechnology]);
    end;
  if (RW[p].NatBuilt[imPalace]>0) or (ServerVersion[p]<$010000) then
    begin // calculate corruption
    Dist:=MaxDist;
    for i:=0 to RW[p].nCity-1 do
      if (RW[p].City[i].Loc>=0) and (RW[p].City[i].Built[imPalace]=1) then
        Dist:=Distance(Loc,RW[p].City[i].Loc);
    if (Dist=0) or (CorrLevel[RW[p].Government]=0) then
      RelCorr:=0.0
    else
      begin
      RelCorr:=Dist/MaxDist;
      if CorrLevel[RW[p].Government]>1 then
        RelCorr:=
          Exp(ln(RelCorr)/CorrLevel[RW[p].Government]);
      if Built[imCourt]=1 then
        RelCorr:=RelCorr/2;
      // !!! floating point calculation always deterministic???
      end
    end
  else if Built[imCourt]=1 then
    RelCorr:=0.5
  else RelCorr:=1.0;
  HappyBase:=Size+HappinessBeforeLux;
  end
end;

procedure SplitTrade(Trade,TaxRate,LuxRate,Working: integer;
  TradeProcessing :TTradeProcessing; var Corruption,Tax,Lux,Science: integer);
var
plus: integer;
begin
Corruption:=Trunc(Trade*TradeProcessing.RelCorr);
Tax:=(TaxRate*(Trade-Corruption)+50) div 100;
if TradeProcessing.FlexibleLuxury then
  begin
  plus:=Working*2-TradeProcessing.HappyBase; // required additional luxury
  if plus>0 then
    begin
    Lux:=(4*plus +3+TradeProcessing.LuxBonus) div (4+TradeProcessing.LuxBonus);
    if Lux>Trade-Corruption then Lux:=Trade-Corruption;
    if Tax>Trade-Corruption-Lux then Tax:=Trade-Corruption-Lux;
    end
  else Lux:=0;
  end
else if (LuxRate=0) or (TaxRate=100) then Lux:=0
else Lux:=(LuxRate*(Trade-Corruption)+49) div 100;
Science:=Trade-Corruption-Lux-Tax;
Tax:=Tax*(4+TradeProcessing.TaxBonus) shr 2;
Lux:=Lux*(4+TradeProcessing.LuxBonus) shr 2;
if TradeProcessing.FutResBonus>0 then
  Science:=Science*(100+TradeProcessing.ScienceBonus*25+TradeProcessing.FutResBonus) div 100
else Science:=Science*(4+TradeProcessing.ScienceBonus) shr 2;
Science:=Science shl 2 shr (2-TradeProcessing.ScienceDoubling);
end;

function GetProjectCost(p,cix: integer): integer;
var
i: integer;
begin
with RW[p].City[cix] do
  begin
  if Project and cpImp=0 then
    begin
    result:=RW[p].Model[Project and cpIndex].Cost; {unit project}
    if Project and cpConscripts<>0 then
      begin
      i:=RW[p].Model[Project and cpIndex].MCost;
      result:=result-3*i;
      if result<=0 then result:=i
      end
    else if RW[p].Model[Project and cpIndex].Cap[mcLine]>0 then
      if Project0 and (not cpAuto or cpRepeat)=Project and not cpAuto or cpRepeat then
        result:=result shr 1
      else result:=result*2
    end
  else
    begin {improvement project}
    result:=Imp[Project and cpIndex].Cost;
    if (Project and cpIndex<28) and (GWonder[woColossus].EffectiveOwner=p) then
      result:=result*ColossusEffect div 100;
    end;
  result:=result*BuildCostMod[Difficulty[p]] div 12;
  end
end;

function GetSmallCityReport(p,cix: integer; var CityReport: TCityReport;
  pCityReportEx: PCityReportEx = nil): integer;
var
i,uix,V21,Loc1,ForcedSupport,BaseHappiness,Control: integer;
ProdProcessing: TProdProcessing;
TradeProcessing: TTradeProcessing;
Radius: TVicinity21Loc;
UnitReport: TUnitReport;
RareOK: array[0..3] of integer;
TileInfo:TTileInfo;
begin
with RW[p].City[cix], CityReport do
  begin
  if HypoTiles<=0 then HypoTiles:=Tiles;
  if HypoTax<0 then HypoTax:=RW[p].TaxRate;
  if HypoLux<0 then HypoLux:=RW[p].LuxRate;

  if (Flags and chCaptured<>0) or (RW[p].Government=gAnarchy) then
    begin
    Working:=0;
    for V21:=1 to 26 do if HypoTiles and (1 shl V21)<>0 then
      inc(Working); // for backward compatibility

    if RW[p].Government=gFundamentalism then
      begin Happy:=Size; Control:=Size end // !!! old bug, kept for compatibility
    else begin Happy:=0; Control:=0 end;

    BaseHappiness:=BasicHappy*2;
    Support:=0;
    Deployed:=0;
    Eaten:=Size*2;
    FoodRep:=Size*2;
    ProdRep:=0;
    Trade:=0;
    PollRep:=0;
    Corruption:=0;
    Tax:=0;
    Lux:=0;
    Science:=0;

    if pCityReportEx<>nil then
      begin
      pCityReportEx.Material:=ProdRep;
      pCityReportEx.BaseHappiness:=BaseHappiness;
      pCityReportEx.BaseControl:=Control;
      end;
    end
  else // not captured, no anarchy
    begin
    Control:=0;
    BaseHappiness:=BasicHappy*2;
    Happy:=BasicHappy;
    if (Built[imColosseum]>0) then
      begin
      if (Happy<(Size+1) shr 1) then
        Happy:=(Size+1) shr 1;
      if Size>4 then
        BaseHappiness:=Size;
      end;
    for i:=0 to 27 do if Built[i]=1 then
      begin inc(Happy); inc(BaseHappiness,2) end;
    if Built[imTemple]=1 then
      begin inc(Happy); inc(BaseHappiness,2) end;
    if Built[imCathedral]=1 then
      begin
      inc(Happy,2); inc(BaseHappiness,4);
      if GWonder[woBach].EffectiveOwner=p then
        begin inc(Happy); inc(BaseHappiness,2) end;
      end;
    if Built[imTheater]>0 then
      begin inc(Happy,2); inc(BaseHappiness,4) end;

    // calculate unit support
    {$IFOPT O-}assert(InvalidTreatyMap=0);{$ENDIF}
    Support:=0; ForcedSupport:=0; Eaten:=Size*2; Deployed:=0;
    for uix:=0 to RW[p].nUn-1 do with RW[p].Un[uix] do
      if (Loc>=0) and (Home=cix) then
        begin
        GetUnitReport(p,uix,UnitReport);
        inc(Eaten,UnitReport.FoodSupport);
        if UnitReport.ReportFlags and urfAlwaysSupport<>0 then
          inc(ForcedSupport, UnitReport.ProdSupport)
        else inc(Support, UnitReport.ProdSupport);
        if UnitReport.ReportFlags and urfDeployed<>0 then
          inc(Deployed);
        end;
    if Deployed>=Happy then Happy:=0 else dec(Happy,Deployed);
    dec(Support,Size*SupportFree[RW[p].Government] shr 1);
    if Support<0 then Support:=0;
    inc(Support,ForcedSupport);

    {control}
    case RW[p].Government of
      gDespotism:
        for uix:=0 to RW[p].nUn-1 do
          if (RW[p].Un[uix].Loc=Loc)
            and (RW[p].Model[RW[p].Un[uix].mix].Kind=mkSpecial_TownGuard) then
            begin inc(Happy); inc(Control,2) end;
      gFundamentalism:
        begin
        BaseHappiness:=0; // done by control
        Happy:=Size;
        Control:=Size
        end;
      end;

    // collect processing parameters
    DetermineCityProdProcessing(p, cix, ProdProcessing);
    DetermineCityTradeProcessing(p, cix, BaseHappiness+Control-2*Deployed, TradeProcessing);

    // collect resources
    Working:=0;
    FoodRep:=0;ProdRep:=0;Trade:=0;
    FillChar(RareOK,SizeOf(RareOK),0);
    V21_to_Loc(Loc,Radius);
    for V21:=1 to 26 do if HypoTiles and (1 shl V21)<>0 then
      begin {sum resources of exploited tiles}
      Loc1:=Radius[V21];
      if (Loc1<0) or (Loc1>=MapSize) then // HypoTiles go beyond map border!
        begin result:=eInvalid; exit end;
      GetTileInfo(p,cix,Loc1,TileInfo);
      inc(FoodRep,TileInfo.Food);
      inc(ProdRep,TileInfo.Prod);
      inc(Trade,TileInfo.Trade);
      if (RealMap[Loc1] and fModern<>0) and (RW[p].Tech[adMassProduction]>=tsApplicable) then
        inc(RareOK[RealMap[Loc1] shr 25 and 3]);
      inc(Working)
      end;
    if Built[imAlgae]=1 then
      inc(FoodRep,12);

    if pCityReportEx<>nil then
      begin
      pCityReportEx.Material:=ProdRep;
      pCityReportEx.BaseHappiness:=BaseHappiness;
      pCityReportEx.BaseControl:=Control;
      pCityReportEx.ProdProcessing:=ProdProcessing;
      pCityReportEx.TradeProcessing:=TradeProcessing;
      end;

    BoostProd(ProdRep,ProdProcessing,ProdRep,PollRep);
    SplitTrade(Trade,HypoTax,HypoLux,Working,TradeProcessing,
      Corruption,Tax,Lux,Science);
    Happy:=Happy+(Lux+Size and 1) shr 1;
      //new style disorder requires 1 lux less for cities with odd size

    // check if rare resource available
    if (GTestFlags and tfNoRareNeed=0) and (ProdRep>Support)
      and (Project and cpImp<>0)
      and ((Project and cpIndex=imShipComp) and (RareOK[1]=0)
        or (Project and cpIndex=imShipPow) and (RareOK[2]=0)
        or (Project and cpIndex=imShipHab) and (RareOK[3]=0)) then
      ProdRep:=Support;
    end;
  end;
result:=eOk;
end; {GetSmallCityReport}

function GetCityReport(p,cix: integer; var CityReport: TCityReport): integer;
begin
result:=GetSmallCityReport(p,cix,CityReport);
CityReport.Storage:=StorageSize[Difficulty[p]];
CityReport.ProdCost:=GetProjectCost(p,cix);
end;

function GetCityReportNew(p,cix: integer; var CityReportNew: TCityReportNew): integer;
var
CityReport: TCityReport;
CityReportEx: TCityReportEx;
begin
with CityReportNew do
  begin
  CityReport.HypoTiles:=HypoTiles;
  CityReport.HypoTax:=HypoTaxRate;
  CityReport.HypoLux:=HypoLuxuryRate;
  result:=GetSmallCityReport(p,cix,CityReport,@CityReportEx);
  FoodSupport:=CityReport.Eaten-2*RW[p].City[cix].Size;
  MaterialSupport:=CityReport.Support;
  ProjectCost:=GetProjectCost(p,cix);
  Storage:=StorageSize[Difficulty[p]];
  Deployed:=CityReport.Deployed;
  Morale:=CityReportEx.BaseHappiness;
  CollectedControl:=CityReportEx.BaseControl+(RW[p].City[cix].Size-CityReport.Working)*2;
  CollectedFood:=CityReport.FoodRep;
  CollectedMaterial:=CityReportEx.Material;
  CollectedTrade:=CityReport.Trade;
  Working:=CityReport.Working;
  Production:=CityReport.ProdRep-CityReport.Support;
  AddPollution:=CityReport.PollRep;
  Corruption:=CityReport.Corruption;
  Tax:=CityReport.Tax;
  Science:=CityReport.Science;
  Luxury:=CityReport.Lux;
  FoodSurplus:=CityReport.FoodRep-CityReport.Eaten;
  HappinessBalance:=Morale+Luxury+CollectedControl
    -RW[p].City[cix].Size-2*Deployed;
  end;
end;

{
                        Internal Tile Picking
 ____________________________________________________________________
}
procedure NextBest(p,cix:integer; var SelectedLoc, SelectedV21: integer);
{best tile unused but available by city cix}
var
Resources,Most,Loc1,p1,V21:integer;
TileInfo:TTileInfo;
Radius: TVicinity21Loc;
begin
{$IFOPT O-}assert(1 shl p and InvalidTreatyMap=0);{$ENDIF}
Most:=0;
SelectedLoc:=-1;
SelectedV21:=-1;
with RW[p].City[cix] do
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize) and (UsedByCity[Loc1]=-1) then
      begin
      p1:=RealMap[Loc1] shr 27;
      if ((p1=nPl) or (p1=p) or (RW[p].Treaty[p1]<trPeace))
        and ((ZoCMap[Loc1]=0) or (Occupant[Loc1]=p)
          or (RW[p].Treaty[Occupant[Loc1]]=trAlliance)) then
        begin
        GetTileInfo(p,cix,Loc1,TileInfo);
        Resources:=TileInfo.Food shl 16+TileInfo.Prod shl 8+TileInfo.Trade;
          {priority: 1.food - 2.prod - 3.trade}
        if Resources>Most then
          begin
          SelectedLoc:=Loc1;
          SelectedV21:=V21;
          Most:=Resources
          end
        end
      end
    end;
  end;
end;

procedure NextWorst(p,cix:integer; var SelectedLoc, SelectedV21: integer);
{worst tile used by city cix}
var
Resources,Least,Loc1,V21:integer;
Radius: TVicinity21Loc;
TileInfo:TTileInfo;
begin
Least:=MaxInt;
SelectedLoc:=-1;
SelectedV21:=-1;
with RW[p].City[cix] do
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do if V21<>CityOwnTile then
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize) and (1 shl V21 and Tiles<>0) then
      begin
      GetTileInfo(p,cix,Loc1,TileInfo);
      Resources:=TileInfo.Food shl 16+TileInfo.Prod shl 8+TileInfo.Trade;
        {priority: 1.food - 2.prod - 3.trade}
      if Resources<Least then
        begin
        SelectedLoc:=Loc1;
        SelectedV21:=V21;
        Least:=Resources
        end
      end;
    end
  end
end;

function NextPoll(p,cix:integer):integer;
var
Resources,Best,dx,dy,Loc1,Dist,BestDist,V21,pTerr:integer;
Radius: TVicinity21Loc;
TileInfo:TTileInfo;
begin
{$IFOPT O-}assert(1 shl p and InvalidTreatyMap=0);{$ENDIF}
Best:=0;
result:=-1;
with RW[p].City[cix] do
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do if V21<>CityOwnTile then
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize)
      and (RealMap[Loc1] and fTerrain>=fGrass)
      and (RealMap[Loc1] and (fPoll or fDeadLands or fCity)=0) then
      begin
      pTerr:=RealMap[Loc1] shr 27;
      if (pTerr=nPl) or (pTerr=p) or (RW[p].Treaty[pTerr]<trPeace) then
        begin
        GetTileInfo(p,cix,Loc1,TileInfo);
        Resources:=TileInfo.Prod shl 16+TileInfo.Trade shl 8+TileInfo.Food;
          {priority: 1.prod - 2.trade - 3.food}
        dy:=V21 shr 2-3;
        dx:=V21 and 3 shl 1 -3 + (dy+3) and 1;
        Dist:=abs(dx)+abs(dy)+abs(abs(dx)-abs(dy)) shr 1;
        if (Resources>Best) or (Resources=Best) and (Dist<BestDist) then
          begin
          result:=Loc1;
          Best:=Resources;
          BestDist:=Dist
          end
        end
      end
    end;
  end
end;

function AddBestCityTile(p,cix: integer): boolean;
var
TileLoc,V21: integer;
begin
NextBest(p,cix,TileLoc,V21);
result:= TileLoc>=0;
if result then with RW[p].City[cix] do
  begin
  assert(1 shl V21 and Tiles=0);
  Tiles:=Tiles or (1 shl V21);
  UsedByCity[TileLoc]:=Loc
  end
end;

procedure CityGrowth(p,cix: integer);
var
TileLoc,V21: integer;
AltCityReport:TCityReport;
begin
with RW[p].City[cix] do
  begin
  inc(Size);
  NextBest(p,cix,TileLoc,V21);
  if TileLoc>=0 then
    begin {test whether exploitation of tile would lead to disorder}
    AltCityReport.HypoTiles:=Tiles+1 shl V21;
    AltCityReport.HypoTax:=-1;
    AltCityReport.HypoLux:=-1;
    GetSmallCityReport(p,cix,AltCityReport);
    if AltCityReport.Working-AltCityReport.Happy<=Size shr 1 then // !!! change to new style disorder
      begin {no disorder -- exploit tile}
      assert(1 shl V21 and Tiles=0);
      Tiles:=Tiles or (1 shl V21);
      UsedByCity[TileLoc]:=Loc
      end
    end;
  end
end;

procedure CityShrink(p,cix: integer);
var
TileLoc, V21, Working: integer;
AltCityReport:TCityReport;
begin
with RW[p].City[cix] do
  begin
  Working:=0;
  for V21:=1 to 26 do if Tiles and (1 shl V21)<>0 then inc(Working);
  dec(Size);
  if Food>StorageSize[Difficulty[p]] then Food:=StorageSize[Difficulty[p]];
  NextWorst(p,cix,TileLoc,V21);
  if Working>Size then
    begin {all citizens were working -- worst tile no longer exploited}
    assert(1 shl V21 and Tiles<>0);
    Tiles:=Tiles and not (1 shl V21);
    UsedByCity[TileLoc]:=-1
    end
  else {test whether exploitation of tile would lead to disorder}
    begin
    AltCityReport.HypoTiles:=-1;
    AltCityReport.HypoTax:=-1;
    AltCityReport.HypoLux:=-1;
    GetSmallCityReport(p,cix,AltCityReport);
    if AltCityReport.Working-AltCityReport.Happy>Size shr 1 then // !!! change to new style disorder
      begin {disorder -- don't exploit tile}
      assert(1 shl V21 and Tiles<>0);
      Tiles:=Tiles and not (1 shl V21);
      UsedByCity[TileLoc]:=-1
      end
    end;
  end
end;

procedure Pollute(p,cix: integer);
var
PollutionLoc: integer;
begin
with RW[p].City[cix] do
  begin
  Pollution:=Pollution-MaxPollution;
  PollutionLoc:=NextPoll(p,cix);
  if PollutionLoc>=0 then
    begin
    inc(Flags,chPollution);
    RealMap[PollutionLoc]:=RealMap[PollutionLoc] or fPoll;
    end
  end;
end;

{
                           Turn Processing
 ____________________________________________________________________
}
procedure PayCityMaintenance(p,cix: integer);
var
i: integer;
begin
with RW[p],City[cix] do
  for i:=28 to nImp-1 do
    if (Built[i]>0)
      and (Project0 and (cpImp or cpIndex)<>(cpImp or i)) then // don't pay maintenance when just completed
      begin
      dec(Money,Imp[i].Maint);
      if Money<0 then
        begin {out of money - sell improvement}
        inc(Money,Imp[i].Cost*BuildCostMod[Difficulty[p]] div 12);
        Built[i]:=0;
        if Imp[i].Kind<>ikCommon then
          begin
          assert(i<>imSpacePort); // never sell automatically! (solution: no maintenance)
          NatBuilt[i]:=0;
          if i=imGrWall then GrWallContinent[p]:=-1;
          end;
        inc(Flags,chImprovementLost)
        end
      end;
end;

procedure CollectCityResources(p,cix: integer);
var
CityStorage,CityProjectCost: integer;
CityReport: TCityReportNew;
Disorder: boolean;
begin
with RW[p],City[cix],CityReport do
  if Flags and chCaptured<>0 then
    begin
    Flags:=Flags and not chDisorder;
    dec(Flags,$10000);
    if Flags and chCaptured=0 then
      Flags:=Flags or chAfterCapture;
    end
  else if Government=gAnarchy then
    Flags:=Flags and not chDisorder
  else
    begin
    HypoTiles:=-1;
    HypoTaxRate:=-1;
    HypoLuxuryRate:=-1;
    GetCityReportNew(p,cix,CityReport);
    CityStorage:=StorageSize[Difficulty[p]];
    CityProjectCost:=GetProjectCost(p,cix);

    Disorder:= (HappinessBalance<0);
    if Disorder and (Flags and chDisorder<>0) then
      CollectedMaterial:=0; // second turn disorder
    if Disorder then
      Flags:=Flags or chDisorder
    else Flags:=Flags and not chDisorder;

    if not Disorder
      and ((Government=gFuture)
        or (Size>=NeedAqueductSize) and (FoodSurplus<2)) and (FoodSurplus>0) then
      inc(Money,FoodSurplus)
    else if not (Disorder and (FoodSurplus>0)) then
      begin {calculate new food storage}
      Food:=Food+FoodSurplus;
      if ((GTestFlags and tfImmGrow<>0)
          or (Food>=CityStorage) and (Food-FoodSurplus<CityStorage)) // only warn once
        and (Size<MaxCitySize)
        and (Project and (cpImp+cpIndex)<>cpImp+imAqueduct)
        and (Project and (cpImp+cpIndex)<>cpImp+imSewer)
        and not CanCityGrow(p,cix) then
        inc(Flags,chNoGrowthWarning);
      end;

    if Prod>CityProjectCost then
      begin inc(Money,Prod-CityProjectCost); Prod:=CityProjectCost end;
    if Production<0 then
      Flags:=Flags or chUnitLost
    else if not Disorder and (Flags and chProductionSabotaged=0) then
      if Project and (cpImp+cpIndex)=cpImp+imTrGoods then
        inc(Money,Production)
      else inc(Prod,Production);

    if not Disorder then
      begin
      {sum research points and taxes}
      inc(Research,Science);
      inc(Money,Tax);
      Pollution:=Pollution+AddPollution;
      end;
    end;
end;

function CityTurn(p,cix: integer): boolean;
// return value: whether city keeps existing
var
i,uix,cix2,p1,SizeMod,CityStorage,CityProjectCost,NewImp,Det,TestDet: integer;
LackOfMaterial, CheckGrow, DoProd, IsActive: boolean;
begin
with RW[p],City[cix] do
  begin
  SizeMod:=0;
  CityStorage:=StorageSize[Difficulty[p]];
  CityProjectCost:=GetProjectCost(p,cix);

  LackOfMaterial:= Flags and chUnitLost<>0;
  Flags:=Flags and not chUnitLost;

  IsActive:= (Government<>gAnarchy) and (Flags and chCaptured=0);
  CheckGrow:=(Flags and chDisorder=0) and IsActive
    and (Government<>gFuture);
  if CheckGrow and (GTestFlags and tfImmGrow<>0) then {fast growth}
    begin
    if CanCityGrow(p,cix) then inc(SizeMod)
    end
  else if CheckGrow and (Food>=CityStorage) then {normal growth}
    begin
    if CanCityGrow(p,cix) then
      begin
      if Built[imGranary]=1 then dec(Food,CityStorage shr 1)
      else dec(Food,CityStorage);
      inc(SizeMod)
      end
    end
  else if Food<0 then {famine}
    begin
    Food:=0;
    // check if settlers or conscripts there to disband
    uix:=-1;
    for i:=0 to nUn-1 do
      if (Un[i].Loc>=0) and (Un[i].Home=cix)
        and ((Model[Un[i].mix].Kind=mkSettler)
        {and (GWonder[woFreeSettlers].EffectiveOwner<>p)}
        or (Un[i].Flags and unConscripts<>0))
        and ((uix=-1) or (Model[Un[i].mix].Cost<Model[Un[uix].mix].Cost)
        or (Model[Un[i].mix].Cost=Model[Un[uix].mix].Cost)
        and (Un[i].Exp<Un[uix].Exp)) then
        uix:=i;

    if uix>=0 then
      begin RemoveUnit_UpdateMap(p,uix); inc(Flags,chUnitLost); end
    else begin dec(SizeMod); inc(Flags,chPopDecrease) end
    end;
  if Food>CityStorage then Food:=CityStorage;

  if LackOfMaterial then
    begin
    if Flags and chUnitLost=0 then
      begin {one unit lost}
      uix:=-1;
      Det:=MaxInt;
      for i:=0 to nUn-1 do if (Un[i].Loc>=0) and (Un[i].Home=cix) then
        with Model[Un[i].mix] do
          begin
          if Kind=mkSpecial_TownGuard then
            TestDet:=Un[i].Health+Un[i].Exp shl 8 // disband townguards first
          else
            begin
            TestDet:=Un[i].Health+Un[i].Exp shl 8+Cost shl 16; // value of unit
            if Flags and mdDoubleSupport<>0 then
              TestDet:=TestDet shr 1; // double support, tend to disband first
            end;
          if TestDet<Det then
            begin uix:=i; Det:=TestDet end;
          end;
      if uix>=0 then
        begin
        RemoveUnit_UpdateMap(p,uix);
        inc(Flags,chUnitLost);
        end
      end
    end;

  if GTestFlags and tfImmImprove<>0 then Prod:=CityProjectCost;
  DoProd:= (Project and (cpImp+cpIndex)<>cpImp+imTrGoods)
    and (Prod>=CityProjectCost);

  // check if wonder already built
  if (Project and cpImp<>0) and (Project and cpIndex<28)
    and (GWonder[Project and cpIndex].CityID<>-1) then
    begin inc(Flags,chOldWonder); DoProd:=false; end;

  // check if producing settlers would disband city
  if DoProd and (Project and (cpImp or cpDisbandCity)=0)
    and ((Size+SizeMod-2<2) and (Model[Project and cpIndex].Kind=mkSettler)
      or (Size+SizeMod-1<2) and ((Model[Project and cpIndex].Kind=mkSlaves)
      or (Project and cpConscripts<>0))) then
    begin inc(Flags,chNoSettlerProd); DoProd:=false; end;

  if DoProd then
    begin {project complete}
    dec(Prod,CityProjectCost);
    if Project and cpImp=0 then {produce unit}
      begin
      if nUn<numax then
        begin
        CreateUnit(p,Project and cpIndex);
        Un[nUn-1].Loc:=Loc;
        with Un[nUn-1] do
          begin
          Home:=cix;
          if (Model[mix].Domain<dSea) and (Built[imElite]=1) then
            Exp:=ExpCost*(nExp-1){elite}
          else if (Model[mix].Domain<dSea) and (Built[imBarracks]=1)
            or (Model[mix].Domain=dSea) and (Built[imDockyard]=1)
            or (Model[mix].Domain=dAir) and (Built[imAirport]=1) then
            Exp:=ExpCost*2;{vet}
          if Project and cpConscripts<>0 then Flags:=Flags or unConscripts
          end;
        PlaceUnit(p,nUn-1);
        UpdateUnitMap(Loc);
        if Model[Project and cpIndex].Kind=mkSettler then
          dec(SizeMod,2) {settler produced - city shrink}
        else if (Model[Project and cpIndex].Kind=mkSlaves)
          or (Project and cpConscripts<>0) then
          dec(SizeMod); {slaves/conscripts produced - city shrink}
        end;
      Project0:=Project or cpRepeat or cpCompleted;
      end
    else if Imp[Project and cpIndex].Kind=ikShipPart then
      begin {produce ship parts}
      inc(GShip[p].Parts[Project and cpIndex-imShipComp]);
      Project0:=Project or cpCompleted;
      end
    else {produce improvement}
      begin
      NewImp:=Project and cpIndex;
      inc(Money,Prod);{change rest to money}
      Project0:=Project or cpCompleted;
      Project:=cpImp+imTrGoods;
      Prod:=0;

      if Imp[NewImp].Kind in [ikNatLocal,ikNatGlobal] then
        begin // nat. project
        for i:=0 to nCity-1 do
          if (City[i].Loc>=0) and (City[i].Built[NewImp]=1) then
            begin {allowed only once}
            inc(Money,Imp[NewImp].Cost
              *BuildCostMod[Difficulty[p]] div 12);
            City[i].Built[NewImp]:=0;
            end;
        NatBuilt[NewImp]:=1;

        // immediate nat. project effects
        case NewImp of
          imGrWall: GrWallContinent[p]:=Continent[Loc];
          end;
        end;

      if NewImp<28 then
        begin // wonder
        GWonder[NewImp].CityID:=ID;
        GWonder[NewImp].EffectiveOwner:=p;
        CheckExpiration(NewImp);

        // immediate wonder effects
        case NewImp of
          woEiffel:
            begin // reactivate wonders
            for i:=0 to 27 do if Imp[i].Expiration>=0 then
              for cix2:=0 to nCity-1 do
                if (City[cix2].Loc>=0) and (City[cix2].Built[i]=1) then
                  GWonder[i].EffectiveOwner:=p
            end;
          woLighthouse: CheckSpecialModels(p,preLighthouse);
          woLeo:
            begin
            inc(Research,
              TechBaseCost(nTech[p],Difficulty[p])
              +TechBaseCost(nTech[p]+2,Difficulty[p]));
            CheckSpecialModels(p,preLeo);
            end;
          woPyramids: CheckSpecialModels(p,preBuilder);
          woMir:
            begin
            for p1:=0 to nPl-1 do
              if (p1<>p) and (1 shl p1 and GAlive<>0) then
                begin
                if RW[p].Treaty[p1]=trNoContact then
                  IntroduceEnemy(p,p1);
                GiveCivilReport(p, p1);
                GiveMilReport(p, p1)
                end;
            end
          end;
        end;

      for i:=0 to nImpReplacement-1 do // sell obsolete buildings
        if (ImpReplacement[i].NewImp=NewImp)
          and (Built[ImpReplacement[i].OldImp]>0) then
          begin
          inc(RW[p].Money, Imp[ImpReplacement[i].OldImp].Cost
            *BuildCostMod[Difficulty[p]] div 12);
          Built[ImpReplacement[i].OldImp]:=0;
          end;

      if NewImp in [imPower,imHydro,imNuclear] then
        for i:=0 to nImp-1 do
          if (i<>NewImp) and (i in [imPower,imHydro,imNuclear])
            and (Built[i]>0) then
            begin // sell obsolete power plant
            inc(RW[p].Money, Imp[i].Cost*BuildCostMod[Difficulty[p]] div 12);
            Built[i]:=0;
            end;

      Built[NewImp]:=1;
      end;
    Prod0:=Prod;
    inc(Flags,chProduction)
    end
  else
    begin
    Project0:=Project0 and not cpCompleted;
    if Project0 and not cpAuto<>Project and not cpAuto then
      Project0:=Project;
    Prod0:=Prod;
    end;

  if SizeMod>0 then
    begin
    CityGrowth(p,cix);
    inc(Flags,chPopIncrease);
    end;
  result:= Size+SizeMod>=2;
  if result then
    while SizeMod<0 do
      begin CityShrink(p,cix); inc(SizeMod) end;
  end
end; //CityTurn

{
                              Tile Access
 ____________________________________________________________________
}
function SetCityTiles(p, cix, NewTiles: integer; TestOnly: boolean = false): integer;
var
V21,Working,ChangeTiles,AddTiles,Loc1: integer;
CityAreaInfo: TCityAreaInfo;
Radius: TVicinity21Loc;
begin
with RW[p].City[cix] do
  begin
  ChangeTiles:=NewTiles xor integer(Tiles);
  AddTiles:=NewTiles and not Tiles;
  if Mode=moPlaying then
    begin // do all checks
    if NewTiles and not $67F7F76<>0 then
      begin result:=eInvalid; exit end; // invalid tile index included
    if NewTiles and (1 shl 13)=0 then
      begin result:=eViolation; exit end; // city tile must be exploited
    if ChangeTiles=0 then
      begin result:=eNotChanged; exit end;
    if AddTiles<>0 then
      begin
      // check if new tiles possible
      GetCityAreaInfo(p, Loc, CityAreaInfo);
      for V21:=1 to 26 do if AddTiles and (1 shl V21)<>0 then
        if CityAreaInfo.Available[V21]<>faAvailable then
          begin result:=eTileNotAvailable; exit end;
      // not more tiles than inhabitants
      Working:=0;
      for V21:=1 to 26 do if NewTiles and (1 shl V21)<>0 then inc(Working);
      if Working>Size then
        begin result:=eNoWorkerAvailable; exit end;
      end;
    end;
  result:=eOK;
  if not TestOnly then
    begin
    V21_to_Loc(Loc,Radius);
    for V21:=1 to 26 do if ChangeTiles and (1 shl V21)<>0 then
      begin
      Loc1:=Radius[V21];
      assert((Loc1>=0) and (Loc1<MapSize));
      if NewTiles and (1 shl V21)<>0 then UsedByCity[Loc1]:=Loc // employ tile
      else if UsedByCity[Loc1]<>Loc then
        assert(Mode<moPlaying)
          // should only happen during loading, because of wrong sSetCityTiles command order
      else UsedByCity[Loc1]:=-1 // unemploy tile
      end;
    Tiles:=NewTiles
    end
  end;
end;

procedure GetCityTileAdvice(p, cix: integer; var Advice: TCityTileAdviceData);
const
oFood=0; oProd=1; oTax=2; oScience=3;
type
TTileData=record
  Food,Prod,Trade,SubValue,V21: integer;
  end;
var
i,V21,Loc1,nHierarchy,iH,iT,iH_Switch,MinWorking,MaxWorking,
  WantedProd,MinFood,MinProd,count,Take,MaxTake,AreaSize,FormulaCode,
  NeedRare, RareTiles,cix1,dx,dy,BestTiles,ProdBeforeBoost,TestTiles,
  SubPlus,SuperPlus: integer;
SuperValue,BestSuperValue,SubValue,BestSubValue: integer;
Value,BestValue,ValuePlus: extended;
ValueFormula_Weight: array[oFood..oScience] of extended;
ValueFormula_Multiply: array[oFood..oScience] of boolean;
Output: array[oFood..oScience] of integer;
TileInfo, BaseTileInfo: TTileInfo;
Radius, Radius1: TVicinity21Loc;
TestReport: TCityReport;
CityReportEx: TCityReportEx;
CityAreaInfo: TCityAreaInfo;
Hierarchy: array[0..20,0..31] of TTileData;
nTile,nSelection: array[0..20] of integer;
SubCriterion: array[0..27] of integer;
FoodWasted, FoodToTax, ProdToTax, RareOk, NeedStep2, IsBest: boolean;
begin
if (RW[p].Government=gAnarchy) or (RW[p].City[cix].Flags and chCaptured<>0) then
  begin
  Fillchar(Advice.CityReport, sizeof(Advice.CityReport), 0);
  Advice.Tiles:=1 shl CityOwnTile;
  Advice.CityReport.HypoTiles:=1 shl CityOwnTile;
  exit;
  end;

for i:=oFood to oScience do
  begin //decode evaluation formula from weights parameter
  FormulaCode:=Advice.ResourceWeights shr (24-8*i) and $FF;
  ValueFormula_Multiply[i]:= FormulaCode and $80<>0;
  if FormulaCode and $40<>0 then
    ValueFormula_Weight[i]:=(FormulaCode and $0F)
      *(1 shl (FormulaCode and $30 shr 4))/16
  else ValueFormula_Weight[i]:=(FormulaCode and $0F)
    *(1 shl (FormulaCode and $30 shr 4));
  end;

TestReport.HypoTiles:=1 shl CityOwnTile;
TestReport.HypoTax:=-1;
TestReport.HypoLux:=-1;
GetSmallCityReport(p,cix,TestReport,@CityReportEx);
with RW[p].City[cix] do
  begin
  V21_to_Loc(Loc,Radius);
  FoodToTax:= RW[p].Government=gFuture;
  ProdToTax:= Project and (cpImp+cpIndex)=cpImp+imTrGoods;
  FoodWasted:=not FoodToTax and (Food=StorageSize[Difficulty[p]])
    and not CanCityGrow(p,cix);

  // sub criteria
  for V21:=1 to 26 do
    begin
    Loc1:=Radius[V21];
    if Loc1>=0 then
      SubCriterion[V21]:=3360-(Distance(Loc,Loc1)-1)*32-V21 xor $15;
    end;
  for cix1:=0 to RW[p].nCity-1 do if cix1<>cix then
    begin
    Loc1:=RW[p].City[cix1].Loc;
    if Loc1>=0 then
      begin
      if Distance(Loc,Loc1)<=10 then
        begin // cities overlap -- prefer tiles outside common range
        V21_to_Loc(Loc1,Radius1);
        for V21:=1 to 26 do
          begin
          Loc1:=Radius1[V21];
          if (Loc1>=0) and (Loc1<MapSize) and (Distance(Loc,Loc1)<=5) then
            begin
            dxdy(Loc,Loc1,dx,dy);
            dec(SubCriterion[(dy+3) shl 2+(dx+3) shr 1],160);
            end
          end
        end
      end
    end;

  GetCityAreaInfo(p,Loc,CityAreaInfo);
  AreaSize:=0;
  for V21:=1 to 26 do
    if CityAreaInfo.Available[V21]=faAvailable then
      inc(AreaSize);

  if RW[p].Government=gFundamentalism then
    begin
    MinWorking:=Size;
    MaxWorking:=Size;
    end
  else
    begin
    MinWorking:=CityReportEx.TradeProcessing.HappyBase shr 1;
    if MinWorking>Size then
      MinWorking:=Size;
    if (RW[p].LuxRate=0)
      and not CityReportEx.TradeProcessing.FlexibleLuxury then
      MaxWorking:=MinWorking
    else MaxWorking:=Size;
    end;
  if MaxWorking>AreaSize then
    begin
    MaxWorking:=AreaSize;
    if MinWorking>AreaSize then
      MinWorking:=AreaSize;
    end;
  if TestReport.Support=0 then
    WantedProd:=0
  else WantedProd:=1+(TestReport.Support*100-1)
    div (100+CityReportEx.ProdProcessing.ProdBonus*50+CityReportEx.ProdProcessing.FutProdBonus);

  // consider resources for ship parts
  NeedRare:=0;
  if (GTestFlags and tfNoRareNeed=0) and (Project and cpImp<>0) then
    case Project and cpIndex of
      imShipComp: NeedRare:=fCobalt;
      imShipPow: NeedRare:=fUranium;
      imShipHab: NeedRare:=fMercury;
      end;
  if NeedRare>0 then
    begin
    RareTiles:=0;
    for V21:=1 to 26 do
      begin
      Loc1:=Radius[V21];
      if (Loc1>=0) and (Loc1<MapSize) and (RealMap[Loc1] and fModern=cardinal(NeedRare)) then
        RareTiles:=RareTiles or (1 shl V21);
      end
    end;

  // step 1: sort tiles to hierarchies
  nHierarchy:=0;
  for V21:=1 to 26 do // non-rare tiles
    if (CityAreaInfo.Available[V21]=faAvailable)
      and ((NeedRare=0) or (1 shl V21 and RareTiles=0)) then
      begin
      Loc1:=Radius[V21];
      assert((Loc1>=0) and (Loc1<MapSize));
      GetTileInfo(p,cix,Loc1,TileInfo);
      if V21=CityOwnTile then
        BaseTileInfo:=TileInfo
      else
        begin
        iH:=0;
        while iH<nHierarchy do
          begin
          iT:=0;
          while (iT<nTile[iH])
            and (TileInfo.Food<=Hierarchy[iH,iT].Food)
            and (TileInfo.Prod<=Hierarchy[iH,iT].Prod)
            and (TileInfo.Trade<=Hierarchy[iH,iT].Trade)
            and not ((TileInfo.Food=Hierarchy[iH,iT].Food)
              and (TileInfo.Prod=Hierarchy[iH,iT].Prod)
              and (TileInfo.Trade=Hierarchy[iH,iT].Trade)
              and (SubCriterion[V21]>=SubCriterion[Hierarchy[iH,iT].V21])) do
            inc(iT);
          if (iT=nTile[iH]) // new worst tile in this hierarchy
            or ((TileInfo.Food>=Hierarchy[iH,iT].Food) // new middle tile in this hierarchy
              and (TileInfo.Prod>=Hierarchy[iH,iT].Prod)
              and (TileInfo.Trade>=Hierarchy[iH,iT].Trade)) then
            break; // insert position found!
          inc(iH);
          end;
        if iH=nHierarchy then
          begin // need to start new hierarchy
          nTile[iH]:=0;
          inc(nHierarchy);
          iT:=0;
          end;
        move(Hierarchy[iH,iT], Hierarchy[iH,iT+1], (nTile[iH]-iT)*sizeof(TTileData));
        inc(nTile[iH]);
        Hierarchy[iH,iT].V21:=V21;
        Hierarchy[iH,iT].Food:=TileInfo.Food;
        Hierarchy[iH,iT].Prod:=TileInfo.Prod;
        Hierarchy[iH,iT].Trade:=TileInfo.Trade;
        Hierarchy[iH,iT].SubValue:=SubCriterion[V21];
        end
      end;
  if NeedRare<>0 then
    begin // rare tiles need own hierarchy
    iH:=nHierarchy;
    for V21:=1 to 26 do
      if (CityAreaInfo.Available[V21]=faAvailable)
        and (1 shl V21 and RareTiles<>0) then
        begin
        Loc1:=Radius[V21];
        assert((V21<>CityOwnTile) and (Loc1>=0) and (Loc1<MapSize));
        GetTileInfo(p,cix,Loc1,TileInfo);
        if iH=nHierarchy then
          begin // need to start new hierarchy
          nTile[iH]:=0;
          inc(nHierarchy);
          iT:=0;
          end
        else iT:=nTile[iH];
        inc(nTile[iH]);
        Hierarchy[iH,iT].V21:=V21;
        Hierarchy[iH,iT].Food:=TileInfo.Food; // = 0
        Hierarchy[iH,iT].Prod:=TileInfo.Prod; // = 1
        Hierarchy[iH,iT].Trade:=TileInfo.Trade; // = 0
        Hierarchy[iH,iT].SubValue:=SubCriterion[V21];
        end;
    end;
  if Built[imAlgae]>0 then
    inc(BaseTileInfo.Food,12);

  // step 2: summarize resources
  for iH:=0 to nHierarchy-1 do
    begin
    move(Hierarchy[iH,0], Hierarchy[iH,1], nTile[iH]*sizeof(TTileData));
    Hierarchy[iH,0].Food:=0;
    Hierarchy[iH,0].Prod:=0;
    Hierarchy[iH,0].Trade:=0;
    Hierarchy[iH,0].SubValue:=0;
    Hierarchy[iH,0].V21:=0;
    for iT:=1 to nTile[iH] do
      begin
      inc(Hierarchy[iH,iT].Food, Hierarchy[iH,iT-1].Food);
      inc(Hierarchy[iH,iT].Prod, Hierarchy[iH,iT-1].Prod);
      inc(Hierarchy[iH,iT].Trade, Hierarchy[iH,iT-1].Trade);
      inc(Hierarchy[iH,iT].SubValue, Hierarchy[iH,iT-1].SubValue);
      Hierarchy[iH,iT].V21:=1 shl Hierarchy[iH,iT].V21+Hierarchy[iH,iT-1].V21;
      end;
    end;

  // step 3: try all combinations
  BestValue:=0.0;
  BestSuperValue:=0;
  BestSubValue:=0;
  BestTiles:=0;
  fillchar(nSelection, sizeof(nSelection),0);
  TestReport.FoodRep:=BaseTileInfo.Food;
  ProdBeforeBoost:=BaseTileInfo.Prod;
  TestReport.Trade:=BaseTileInfo.Trade;
  TestReport.Working:=1;
  MinFood:=0;
  MinProd:=0;
  iH_Switch:=nHierarchy;
  count:=0;
  repeat
    // ensure minima
    iH:=0;
    while (TestReport.Working<MaxWorking) and (iH<iH_Switch)
      and ((TestReport.Working<MinWorking) or (TestReport.FoodRep<TestReport.Eaten)
        or (ProdBeforeBoost<WantedProd)) do
      begin
      assert(nSelection[iH]=0);
      Take:=MinWorking-TestReport.Working;
      if Take>nTile[iH] then
        Take:=nTile[iH]
      else
        begin
        if Take<0 then
          Take:=0;
        MaxTake:=nTile[iH];
        if TestReport.Working+MaxTake>MaxWorking then
          MaxTake:=MaxWorking-TestReport.Working;
        while (Take<MaxTake) and (TestReport.FoodRep+Hierarchy[iH,Take].Food<MinFood) do
          inc(Take);
        while (Take<MaxTake) and (ProdBeforeBoost+Hierarchy[iH,Take].Prod<MinProd) do
          inc(Take);
        end;
      nSelection[iH]:=Take;
      inc(TestReport.Working, Take);
      with Hierarchy[iH,Take] do
        begin
        inc(TestReport.FoodRep,Food);
        inc(ProdBeforeBoost,Prod);
        inc(TestReport.Trade,Trade);
        end;
      inc(iH);
      end;

    assert((TestReport.Working>=MinWorking) and (TestReport.Working<=MaxWorking));
    if (TestReport.FoodRep>=MinFood) and (ProdBeforeBoost>=MinProd) then
      begin
      SplitTrade(TestReport.Trade,RW[p].TaxRate,RW[p].LuxRate,TestReport.Working,
        CityReportEx.TradeProcessing, TestReport.Corruption, TestReport.Tax,
        TestReport.Lux, TestReport.Science);

      if CityReportEx.BaseHappiness+CityReportEx.BaseControl+TestReport.Lux
        +2*(Size-TestReport.Working)-2*TestReport.Deployed>=Size then
        begin // city is not in disorder -- evaluate combination
        inc(count);
        if (MinProd<WantedProd) and (ProdBeforeBoost>MinProd) then
          begin // no combination reached wanted prod yet
          MinProd:=ProdBeforeBoost;
          if MinProd>WantedProd then
            MinProd:=WantedProd
          end;
        if MinProd=WantedProd then // do not care for food before prod is ensured
          if (MinFood<TestReport.Eaten) and (TestReport.FoodRep>MinFood) then
            begin // no combination reached wanted food yet
            MinFood:=TestReport.FoodRep;
            if MinFood>TestReport.Eaten then
              MinFood:=TestReport.Eaten
            end;
        BoostProd(ProdBeforeBoost, CityReportEx.ProdProcessing,
          TestReport.ProdRep, TestReport.PollRep);
        SuperValue:=0;

        // super-criterion A: unit support granted?
        if TestReport.ProdRep>=TestReport.Support then
          SuperValue:=SuperValue or 1 shl 30;

        // super-criterion B: food demand granted?
        if TestReport.FoodRep>=TestReport.Eaten then
          SuperValue:=SuperValue or 63 shl 24
        else if TestReport.FoodRep>TestReport.Eaten-63 then
          SuperValue:=SuperValue or (63-(TestReport.Eaten-TestReport.FoodRep)) shl 24;

        SuperPlus:=SuperValue-BestSuperValue;
        if SuperPlus>=0 then
          begin
          Output[oTax]:=TestReport.Tax;
          Output[oScience]:=TestReport.Science;

          if TestReport.FoodRep<TestReport.Eaten then
            Output[oFood]:=TestReport.FoodRep
            // appreciate what we have, combination will have bad supervalue anyway
          else if FoodWasted then
            Output[oFood]:=0
          else
            begin
            Output[oFood]:=TestReport.FoodRep-TestReport.Eaten;
            if FoodToTax or (Size>=NeedAqueductSize) and (Output[oFood]=1) then
              begin
              inc(Output[oTax],Output[oFood]);
              Output[oFood]:=0;
              end;
            end;

          if TestReport.ProdRep<TestReport.Support then
            Output[oProd]:=TestReport.ProdRep
            // appreciate what we have, combination will have bad supervalue anyway
          else
            begin
            if NeedRare>0 then
              begin
              RareOk:=false;
              for iH:=0 to nHierarchy-1 do
                if Hierarchy[iH,nSelection[iH]].V21 and RareTiles<>0 then
                  RareOk:=true;
              if not RareOk then
                TestReport.ProdRep:=TestReport.Support;
              end;
            Output[oProd]:=TestReport.ProdRep-TestReport.Support;
            if ProdToTax then
              begin
              inc(Output[oTax],Output[oProd]);
              Output[oProd]:=0;
              end;
            end;

          NeedStep2:=false;
          Value:=0;
          for i:=oFood to oScience do
            if ValueFormula_Multiply[i] then
              NeedStep2:=true
            else Value:=Value+ValueFormula_Weight[i]*Output[i];
          if NeedStep2 then
            begin
            if Value>0 then
              Value:=ln(Value)+123;
            for i:=oFood to oScience do
              if ValueFormula_Multiply[i] and (Output[i]>0) then
                Value:=Value+ValueFormula_Weight[i]*(ln(Output[i])+123);
            end;

          ValuePlus:=Value-BestValue;
          if (SuperPlus>0) or (ValuePlus>=0.0) then
            begin
            SubValue:=(TestReport.FoodRep+ProdBeforeBoost+TestReport.Trade) shl 18;
            TestTiles:=1 shl CityOwnTile;
            for iH:=0 to nHierarchy-1 do
              begin
              inc(TestTiles, Hierarchy[iH,nSelection[iH]].V21);
              inc(SubValue, Hierarchy[iH,nSelection[iH]].SubValue);
              end;
            IsBest:=true;
            if (SuperPlus=0) and (ValuePlus=0.0) then
              begin
              SubPlus:=SubValue-BestSubValue;
              if SubPlus<0 then
                IsBest:=false
              else if SubPlus=0 then
                begin
                assert(TestTiles<>BestTiles);
                IsBest:= TestTiles>BestTiles
                end
              end;
            if IsBest then
              begin
              BestSuperValue:=SuperValue;
              BestValue:=Value;
              BestSubValue:=SubValue;
              BestTiles:=TestTiles;
              TestReport.Happy:=(CityReportEx.TradeProcessing.HappyBase-Size) div 2
                +TestReport.Lux shr 1;
              Advice.CityReport:=TestReport;
              end
            end // if (SuperPlus>0) or (ValuePlus>=0.0)
          end // if SuperPlus>=0
        end
      end;

    // calculate next combination
    iH_Switch:=0;
    repeat
      with Hierarchy[iH_Switch,nSelection[iH_Switch]] do
        begin
        dec(TestReport.FoodRep,Food);
        dec(ProdBeforeBoost,Prod);
        dec(TestReport.Trade,Trade);
        end;
      inc(nSelection[iH_Switch]);
      inc(TestReport.Working);
      if (nSelection[iH_Switch]<=nTile[iH_Switch]) and (TestReport.Working<=MaxWorking) then
        begin
        with Hierarchy[iH_Switch,nSelection[iH_Switch]] do
          begin
          inc(TestReport.FoodRep,Food);
          inc(ProdBeforeBoost,Prod);
          inc(TestReport.Trade,Trade);
          end;
        break;
        end;
      dec(TestReport.Working,nSelection[iH_Switch]);
      nSelection[iH_Switch]:=0;
      inc(iH_Switch);
    until iH_Switch=nHierarchy;
  until iH_Switch=nHierarchy; // everything tested -- done
  end;
assert(BestSuperValue>0); // advice should always be possible
Advice.Tiles:=BestTiles;
Advice.CityReport.HypoTiles:=BestTiles;
end; // GetCityTileAdvice

{
                              Start/End Game
 ____________________________________________________________________
}
procedure InitGame;
var
p,i,mixTownGuard: integer;
begin
MaxDist:=Distance(0,MapSize-lx shr 1);
for p:=0 to nPl-1 do if (1 shl p and GAlive<>0) then with RW[p] do
  begin // initialize capital
  mixTownGuard:=0;
  while Model[mixTownGuard].Kind<>mkSpecial_TownGuard do
    inc(mixTownGuard);
  with City[0] do
    begin
    Built[imPalace]:=1;
    Size:=4;
    for i:=2 to Size do
      AddBestCityTile(p,0);
    Project:=mixTownGuard;
    end;
  NatBuilt[imPalace]:=1;
  end;
end;

procedure ReleaseGame;
begin
end;

end.

