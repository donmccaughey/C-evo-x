{$INCLUDE switches}

unit ClientTools;

interface

uses
  Protocol;

const
nOfferedResourceWeights=6;
OfferedResourceWeights: array[0..nOfferedResourceWeights-1] of cardinal=
(rwOff, rwMaxScience, rwForceScience, rwMaxGrowth, rwForceProd, rwMaxProd);

type
TImpOrder=array[0..(nImp+4) div 4 *4 -1] of ShortInt;
TEnhancementJobs=array[0..11,0..7] of Byte;
JobResultSet=set of 0..39;

var
Server: TServerCall;
G: TNewGameData;
me: integer;
MyRO: ^TPlayerContext;
MyMap: ^TTileList;
MyUn: ^TUnList;
MyCity: ^TCityList;
MyModel: ^TModelList;

AdvValue: array[0..nAdv-1] of integer;


function dLoc(Loc,dx,dy: integer): integer;
function Distance(Loc0,Loc1: integer): integer;
function UnrestAtLoc(uix,Loc: integer): boolean;
function GetMoveAdvice(uix, ToLoc: integer;
  var MoveAdviceData: TMoveAdviceData): integer;
function ColorOfHealth(Health: integer): integer;
function IsMultiPlayerGame: boolean;
procedure ItsMeAgain(p: integer);
function GetAge(p: integer): integer;
function IsCivilReportNew(Enemy: integer): boolean;
function IsMilReportNew(Enemy: integer): boolean;
function CutCityFoodSurplus(FoodSurplus: integer; IsCityAlive: boolean;
  gov,size: integer): integer;
function CityTaxBalance(cix: integer; const CityReport: TCityReportNew): integer;
procedure SumCities(var TaxSum, ScienceSum: integer);
function JobTest(uix,Job: integer; IgnoreResults: JobResultSet = []): boolean;
procedure GetUnitInfo(Loc: integer; var uix: integer; var UnitInfo: TUnitInfo);
procedure GetCityInfo(Loc: integer; var cix: integer; var CityInfo: TCityInfo);
function UnitExhausted(uix: integer): boolean;
function ModelHash(const ModelInfo: TModelInfo): integer;
function ProcessEnhancement(uix: integer; const Jobs: TEnhancementJobs): integer;
function AutoBuild(cix: integer; const ImpOrder: TImpOrder): boolean;
procedure DebugMessage(Level: integer; Text: string);
procedure CityOptimizer_BeginOfTurn;
procedure CityOptimizer_CityChange(cix: integer);
procedure CityOptimizer_TileBecomesAvailable(Loc: integer);
procedure CityOptimizer_ReleaseCityTiles(cix, ReleasedTiles: integer);
procedure CityOptimizer_BeforeRemoveUnit(uix: integer);
procedure CityOptimizer_AfterRemoveUnit;
procedure CityOptimizer_EndOfTurn;


implementation

var
CityNeedsOptimize: array[0..ncmax-1] of boolean;


function dLoc(Loc,dx,dy: integer): integer;
var
y0: integer;
begin
y0:=(Loc+G.lx*1024) div G.lx -1024;
result:=(Loc+(dx+y0 and 1+G.lx*1024) shr 1) mod G.lx +G.lx*(y0+dy)
end;

function Distance(Loc0,Loc1: integer): integer;
var
dx,dy: integer;
begin
inc(Loc0,G.lx*1024);
inc(Loc1,G.lx*1024);
dx:=abs(((Loc1 mod G.lx *2 +Loc1 div G.lx and 1)
  -(Loc0 mod G.lx *2 +Loc0 div G.lx and 1)+3*G.lx) mod (2*G.lx) -G.lx);
dy:=abs(Loc1 div G.lx-Loc0 div G.lx);
result:=dx+dy+abs(dx-dy) shr 1;
end;

function UnrestAtLoc(uix,Loc: integer): boolean;
var
uix1: integer;
begin
result:=false;
if MyModel[MyUn[uix].mix].Flags and mdCivil=0 then
  case MyRO.Government of
    gRepublic, gFuture:
      result:=(MyRO.Territory[Loc]>=0) and (MyRO.Territory[Loc]<>me)
        and (MyRO.Treaty[MyRO.Territory[Loc]]<trAlliance);
    gDemocracy:
      result:=(MyRO.Territory[Loc]<0) or (MyRO.Territory[Loc]<>me)
        and (MyRO.Treaty[MyRO.Territory[Loc]]<trAlliance);
    end;
with MyModel[MyUn[uix].mix] do
  if Cap[mcSeaTrans]+Cap[mcAirTrans]+Cap[mcCarrier]>0 then
    for uix1:=0 to MyRO.nUn-1 do // check transported units too
      if (MyUn[uix1].Loc>=0) and (MyUn[uix1].Master=uix) then
        result:=result or UnrestAtLoc(uix1,Loc);
end;

function GetMoveAdvice(uix, ToLoc: integer; var MoveAdviceData: TMoveAdviceData): integer;
var
MinEndHealth: integer;
begin
if MyModel[MyUn[uix].mix].Domain=dGround then MinEndHealth:=100
else MinEndHealth:=1; // resistent to hostile terrain -- don't consider
repeat
  if MyUn[uix].Health>=MinEndHealth then
    begin
    MoveAdviceData.ToLoc:=ToLoc;
    MoveAdviceData.MoreTurns:=999;
    MoveAdviceData.MaxHostile_MovementLeft:=MyUn[uix].Health-MinEndHealth;
    result:=Server(sGetMoveAdvice,me,uix,MoveAdviceData);
    if (MinEndHealth<=1) or (result<>eNoWay) then exit;
    end;
  case MinEndHealth of
    100: MinEndHealth:=50;
    50: MinEndHealth:=25;
    25: MinEndHealth:=12;
    else MinEndHealth:=1
    end;
until false
end;

function ColorOfHealth(Health: integer): integer;
var
red,green: integer;
begin
green:=400*Health div 100; if green>200 then green:=200;
red:=510*(100-Health) div 100; if red>255 then red:=255;
result:=green shl 8 + red
end;

function IsMultiPlayerGame: boolean;
var
p1: integer;
begin
result:=false;
for p1:=1 to nPl-1 do
  if G.RO[p1]<>nil then result:=true;
end;

procedure ItsMeAgain(p: integer);
begin
if G.RO[p]<>nil then
  MyRO:=pointer(G.RO[p])
else if G.SuperVisorRO[p]<>nil then
  MyRO:=pointer(G.SuperVisorRO[p])
else exit;
me:=p;
MyMap:=pointer(MyRO.Map);
MyUn:=pointer(MyRO.Un);
MyCity:=pointer(MyRO.City);
MyModel:=pointer(MyRO.Model);
end;

function GetAge(p: integer): integer;
var
i: integer;
begin
if p=me then
  begin
  result:=0;
  for i:=1 to 3 do
    if MyRO.Tech[AgePreq[i]]>=tsApplicable then result:=i;
  end
else
  begin
  result:=0;
  for i:=1 to 3 do
    if MyRO.EnemyReport[p].Tech[AgePreq[i]]>=tsApplicable then result:=i;
  end
end;

function IsCivilReportNew(Enemy: integer): boolean;
var
i: integer;
begin
assert(Enemy<>me);
i:=MyRO.EnemyReport[Enemy].TurnOfCivilReport;
result:= (i=MyRO.Turn) or (i=MyRO.Turn-1) and (Enemy>me);
end;

function IsMilReportNew(Enemy: integer): boolean;
var
i: integer;
begin
assert(Enemy<>me);
i:=MyRO.EnemyReport[Enemy].TurnOfMilReport;
result:= (i=MyRO.Turn) or (i=MyRO.Turn-1) and (Enemy>me);
end;

function CutCityFoodSurplus(FoodSurplus: integer; IsCityAlive: boolean;
  gov,size: integer): integer;
begin
result:=FoodSurplus;
if not IsCityAlive
  or (result>0)
     and ((gov=gFuture)
       or (size>=NeedAqueductSize) and (result<2)) then
  result:=0; {no growth}
end;

function CityTaxBalance(cix: integer; const CityReport: TCityReportNew): integer;
var
i: integer;
begin
result:=0;
if (CityReport.HappinessBalance>=0) {no disorder}
  and (MyCity[cix].Flags and chCaptured=0) then // not captured
  begin
  inc(result, CityReport.Tax);
  if (MyCity[cix].Project and (cpImp+cpIndex)=cpImp+imTrGoods)
    and (CityReport.Production>0) then
    inc(result, CityReport.Production);
  if ((MyRO.Government=gFuture)
      or (MyCity[cix].Size>=NeedAqueductSize)
      and (CityReport.FoodSurplus<2))
    and (CityReport.FoodSurplus>0) then
    inc(result, CityReport.FoodSurplus);
  end;
for i:=28 to nImp-1 do if MyCity[cix].Built[i]>0 then
  dec(result, Imp[i].Maint);
end;

procedure SumCities(var TaxSum, ScienceSum: integer);
var
cix: integer;
CityReport: TCityReportNew;
begin
TaxSum:=MyRO.OracleIncome;
ScienceSum:=0;
if MyRO.Government=gAnarchy then exit;
for cix:=0 to MyRO.nCity-1 do if MyCity[cix].Loc>=0 then
  begin
  CityReport.HypoTiles:=-1;
  CityReport.HypoTaxRate:=-1;
  CityReport.HypoLuxuryRate:=-1;
  Server(sGetCityReportNew,me,cix,CityReport);
  if (CityReport.HappinessBalance>=0) {no disorder}
    and (MyCity[cix].Flags and chCaptured=0) then // not captured
    ScienceSum:=ScienceSum+CityReport.Science;
  TaxSum:=TaxSum+CityTaxBalance(cix, CityReport);
  end;
end;

function JobTest(uix,Job: integer; IgnoreResults: JobResultSet): boolean;
var
Test: integer;
begin
Test:=Server(sStartJob+Job shl 4-sExecute,me,uix,nil^);
result:= (Test>=rExecuted) or (Test in IgnoreResults);
end;

procedure GetUnitInfo(Loc: integer; var uix: integer; var UnitInfo: TUnitInfo);
var
i,Cnt: integer;
begin
if MyMap[Loc] and fOwned<>0 then
  begin
  Server(sGetDefender,me,Loc,uix);
  Cnt:=0;
  for i:=0 to MyRO.nUn-1 do
    if MyUn[i].Loc=Loc then inc(Cnt);
  MakeUnitInfo(me,MyUn[uix],UnitInfo);
  if Cnt>1 then UnitInfo.Flags:=UnitInfo.Flags or unMulti;
  end
else
  begin
  uix:=MyRO.nEnemyUn-1;
  while (uix>=0) and (MyRO.EnemyUn[uix].Loc<>Loc) do dec(uix);
  UnitInfo:=MyRO.EnemyUn[uix];
  end
end;{GetUnitInfo}

procedure GetCityInfo(Loc: integer; var cix: integer; var CityInfo: TCityInfo);
begin
if MyMap[Loc] and fOwned<>0 then
  begin
  CityInfo.Loc:=Loc;
  cix:=MyRO.nCity-1;
  while (cix>=0) and (MyCity[cix].Loc<>Loc) do dec(cix);
  with CityInfo do
    begin
    Owner:=me;
    ID:=MyCity[cix].ID;
    Size:=MyCity[cix].Size;
    Flags:=0;
    if MyCity[cix].Built[imPalace]>0 then inc(Flags,ciCapital);
    if (MyCity[cix].Built[imWalls]>0)
      or (MyMap[MyCity[cix].Loc] and fGrWall<>0) then inc(Flags,ciWalled);
    if MyCity[cix].Built[imCoastalFort]>0 then inc(Flags,ciCoastalFort);
    if MyCity[cix].Built[imMissileBat]>0 then inc(Flags,ciMissileBat);
    if MyCity[cix].Built[imBunker]>0 then inc(Flags,ciBunker);
    if MyCity[cix].Built[imSpacePort]>0 then inc(Flags,ciSpacePort);
    end
  end
else
  begin
  cix:=MyRO.nEnemyCity-1;
  while (cix>=0) and (MyRO.EnemyCity[cix].Loc<>Loc) do dec(cix);
  CityInfo:=MyRO.EnemyCity[cix];
  end
end;

function UnitExhausted(uix: integer): boolean;
// check if another move of this unit is still possible
var
dx, dy: integer;
begin
result:=true;
if (MyUn[uix].Movement>0) or (MyRO.Wonder[woShinkansen].EffectiveOwner=me) then
  if (MyUn[uix].Movement>=100) or ((MyModel[MyUn[uix].mix].Kind=mkCaravan)
    and (MyMap[MyUn[uix].Loc] and fCity<>0)) then
    result:=false
  else for dx:=-2 to 2 do for dy:=-2 to 2 do if abs(dx)+abs(dy)=2 then
    if Server(sMoveUnit-sExecute+dx and 7 shl 4+dy and 7 shl 7,me,uix,nil^)>=rExecuted then
      result:=false;
end;

function ModelHash(const ModelInfo: TModelInfo): integer;
var
i,FeatureCode,Hash1,Hash2,Hash2r,d: cardinal;
begin
with ModelInfo do
  if Kind>mkEnemyDeveloped then
    result:=integer($C0000000+Speed div 50+Kind shl 8)
  else
    begin
    FeatureCode:=0;
    for i:=mcFirstNonCap to nFeature-1 do
      if 1 shl Domain and Feature[i].Domains<>0 then
        begin
        FeatureCode:=FeatureCode*2;
        if 1 shl (i-mcFirstNonCap)<>0 then
          inc(FeatureCode);
        end;
    case Domain of
      dGround:
        begin
        assert(FeatureCode<1 shl 8);
        assert(Attack<5113);
        assert(Defense<2273);
        assert(Cost<1611);
        Hash1:=(Attack*2273+Defense)*9+(Speed-150) div 50;
        Hash2:=FeatureCode*1611+Cost;
        end;
      dSea:
        begin
        assert(FeatureCode<1 shl 9);
        assert(Attack<12193);
        assert(Defense<6097);
        assert(Cost<4381);
        Hash1:=((Attack*6097+Defense)*5+(Speed-350) div 100)*2;
        if Weight>=6 then inc(Hash1);
        Hash2:=((TTrans*17+ATrans_Fuel) shl 9+FeatureCode)*4381+Cost;
        end;
      dAir:
        begin
        assert(FeatureCode<1 shl 5);
        assert(Attack<2407);
        assert(Defense<1605);
        assert(Bombs<4813);
        assert(Cost<2089);
        Hash1:=(Attack*1605+Defense) shl 5+FeatureCode;
        Hash2:=((Bombs*7+ATrans_Fuel)*4+TTrans)*2089+Cost;
        end;
      end;
    Hash2r:=0;
    for i:=0 to 7 do
      begin
      Hash2r:=Hash2r*13;
      d:=Hash2 div 13;
      inc(Hash2r,Hash2-d*13);
      Hash2:=d
      end;
    result:=integer(Domain shl 30+Hash1 xor Hash2r)
    end
end;

function ProcessEnhancement(uix: integer; const Jobs: TEnhancementJobs): integer;
{ return values:
eJobDone - all applicable jobs done
eOK - enhancement not complete
eDied - job done and died (thurst) }
var
stage, NextJob, Tile: integer;
Done: Set of jNone..jTrans;
begin
Done:=[];
Tile:=MyMap[MyUn[uix].Loc];
if Tile and fRoad<>0 then include(Done,jRoad);
if Tile and fRR<>0 then include(Done,jRR);
if (Tile and fTerImp=tiIrrigation) or (Tile and fTerImp=tiFarm) then
  include(Done,jIrr);
if Tile and fTerImp=tiFarm then include(Done,jFarm);
if Tile and fTerImp=tiMine then include(Done,jMine);
if Tile and fPoll=0 then include(Done,jPoll);

if MyUn[uix].Job=jNone then result:=eJobDone
else result:=eOK;
while (result<>eOK) and (result<>eDied) do
  begin
  stage:=-1;
  repeat
    if stage=-1 then NextJob:=jPoll
    else NextJob:=Jobs[Tile and fTerrain,stage];
    if (NextJob=jNone) or not (NextJob in Done) then Break;
    inc(stage);
  until stage=5;
  if (stage=5) or (NextJob=jNone) then
    begin result:=eJobDone; Break; end; // tile enhancement complete
  result:=Server(sStartJob+NextJob shl 4,me,uix,nil^);
  include(Done,NextJob)
  end;
end;

function AutoBuild(cix: integer; const ImpOrder: TImpOrder): boolean;
var
i,NewProject: integer;
begin
result:=false;
if (MyCity[cix].Project and (cpImp+cpIndex)=cpImp+imTrGoods)
  or (MyCity[cix].Flags and chProduction<>0) then
  begin
  i:=0;
  repeat
    while (ImpOrder[i]>=0) and (MyCity[cix].Built[ImpOrder[i]]>0) do inc(i);
    if ImpOrder[i]<0 then Break;
    assert(i<nImp);
    NewProject:=cpImp+ImpOrder[i];
    if Server(sSetCityProject,me,cix,NewProject)>=rExecuted then
      begin
      result:=true;
      CityOptimizer_CityChange(cix);
      Break;
      end;
    inc(i);
  until false
  end
end;

procedure CalculateAdvValues;
var
i,j: integer;
known: array[0..nAdv-1] of integer;

  procedure MarkPreqs(i: integer);
  begin
  if known[i]=0 then
    begin
    known[i]:=1;
    if (i<>adScience) and (i<>adMassProduction) then
      begin
      if (AdvPreq[i,0]>=0) then MarkPreqs(AdvPreq[i,0]);
      if (AdvPreq[i,1]>=0) then MarkPreqs(AdvPreq[i,1]);
      end
    end
  end;

begin
FillChar(AdvValue,SizeOf(AdvValue),0);
for i:=0 to nAdv-1 do
  begin
  FillChar(known,SizeOf(known),0);
  MarkPreqs(i);
  for j:=0 to nAdv-1 do if known[j]>0 then inc(AdvValue[i]);
  if i in FutureTech then inc(AdvValue[i],3000)
  else if known[adMassProduction]>0 then inc(AdvValue[i],2000)
  else if known[adScience]>0 then inc(AdvValue[i],1000)
  end;
end;

procedure DebugMessage(Level: integer; Text: string);
begin
Server(sMessage,me,Level,pchar(Text)^)
end;

function MarkCitiesAround(Loc,cixExcept: integer): boolean;
// return whether a city was marked
var
cix: integer;
begin
result:=false;
for cix:=0 to MyRO.nCity-1 do
  if (cix<>cixExcept) and (MyCity[cix].Loc>=0)
    and (MyCity[cix].Flags and chCaptured=0)
    and (Distance(MyCity[cix].Loc,Loc)<=5) then
    begin
    CityNeedsOptimize[cix]:=true;
    result:=true;
    end
end;

procedure OptimizeCities(CheckOnly: boolean);
var
cix,fix,dx,dy,Loc1,OptiType: integer;
done: boolean;
Advice: TCityTileAdviceData;
begin
repeat
  done:=true;
  for cix:=0 to MyRO.nCity-1 do if CityNeedsOptimize[cix] then
    begin
    OptiType:=MyCity[cix].Status shr 4 and $0F;
    if OptiType<>0 then
      begin
      Advice.ResourceWeights:=OfferedResourceWeights[OptiType];
      Server(sGetCityTileAdvice,me,cix,Advice);
      if Advice.Tiles<>MyCity[cix].Tiles then
        if CheckOnly then
          assert(false)
        else
          begin
          for fix:=1 to 26 do
            if MyCity[cix].Tiles and not Advice.Tiles and (1 shl fix)<>0 then
              begin // tile no longer used by this city -- check using it by another
              dy:=fix shr 2-3; dx:=fix and 3 shl 1 -3 + (dy+3) and 1;
              Loc1:=dLoc(MyCity[cix].Loc,dx,dy);
              if MarkCitiesAround(Loc1,cix) then
                done:=false;
              end;
          Server(sSetCityTiles,me,cix,Advice.Tiles);
          end;
      end;
    CityNeedsOptimize[cix]:=false;
    end;
until done;
end;

procedure CityOptimizer_BeginOfTurn;
var
cix: integer;
begin
fillchar(CityNeedsOptimize,MyRO.nCity-1,0); //false
if MyRO.Government<>gAnarchy then
  begin
  for cix:=0 to MyRO.nCity-1 do
    if (MyCity[cix].Loc>=0) and (MyCity[cix].Flags and chCaptured=0) then
      CityNeedsOptimize[cix]:=true;
  OptimizeCities(false); // optimize all cities
  end
end;

procedure CityOptimizer_CityChange(cix: integer);
begin
if (MyRO.Government<>gAnarchy) and (MyCity[cix].Flags and chCaptured=0) then
  begin
  CityNeedsOptimize[cix]:=true;
  OptimizeCities(false);
  end
end;

procedure CityOptimizer_TileBecomesAvailable(Loc: integer);
begin
if (MyRO.Government<>gAnarchy) and MarkCitiesAround(Loc,-1) then
  OptimizeCities(false);
end;

procedure CityOptimizer_ReleaseCityTiles(cix, ReleasedTiles: integer);
var
fix,dx,dy,Loc1: integer;
done: boolean;
begin
if (MyRO.Government<>gAnarchy) and (ReleasedTiles<>0) then
  begin
  done:=true;
  for fix:=1 to 26 do if ReleasedTiles and (1 shl fix)<>0 then
    begin
    dy:=fix shr 2-3; dx:=fix and 3 shl 1 -3 + (dy+3) and 1;
    Loc1:=dLoc(MyCity[cix].Loc,dx,dy);
    if MarkCitiesAround(Loc1,cix) then
      done:=false;
    end;
  if not done then
    OptimizeCities(false);
  end
end;

procedure CityOptimizer_BeforeRemoveUnit(uix: integer);
var
uix1: integer;
begin
if MyRO.Government<>gAnarchy then
  begin
  if MyUn[uix].Home>=0 then
    CityNeedsOptimize[MyUn[uix].Home]:=true;

  // transported units are also removed
  for uix1:=0 to MyRO.nUn-1 do
    if (MyUn[uix1].Loc>=0) and (MyUn[uix1].Master=uix)
      and (MyUn[uix1].Home>=0) then
      CityNeedsOptimize[MyUn[uix1].Home]:=true;
  end
end;

procedure CityOptimizer_AfterRemoveUnit;
begin
if MyRO.Government<>gAnarchy then
  OptimizeCities(false);
end;

procedure CityOptimizer_EndOfTurn;
// all cities should already be optimized here -- only check this
var
cix: integer;
begin
{$IFOPT O-}
if MyRO.Government<>gAnarchy then
  begin
  fillchar(CityNeedsOptimize,MyRO.nCity-1,0); //false
  for cix:=0 to MyRO.nCity-1 do
    if (MyCity[cix].Loc>=0) and (MyCity[cix].Flags and chCaptured=0) then
      CityNeedsOptimize[cix]:=true;
  OptimizeCities(true); // check all cities
  end;
{$ENDIF}
end;


initialization
assert(nImp<128);
CalculateAdvValues;

end.

