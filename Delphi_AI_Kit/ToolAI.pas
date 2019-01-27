{$INCLUDE switches.pas}
unit ToolAI;

interface

uses
{$IFDEF DEBUG}SysUtils,{$ENDIF} // necessary for debug exceptions
{$IFDEF DEBUG}Names,{$ENDIF}
Protocol, CustomAI;


type
TGroupTransportPlan=record
  LoadLoc, uixTransport, nLoad, TurnsEmpty, TurnsLoaded: integer;
  uixLoad: array[0..15] of integer;
  end;


TToolAI = class(TCustomAI)
protected
  {$IFDEF DEBUG}DebugMap: array[0..lxmax*lymax-1] of integer;{$ENDIF}

  function CityTaxBalance(cix: integer; const CityReport: TCityReport): integer;
    // calculates exact difference of income and maintenance cost for a single city
    // positive result = income higher than maintenance
    // negative result = income lower than maintenance
    // respects production and food converted to gold
    // CityReport must have been prepared before
  procedure SumCities(TaxRate: integer; var TaxSum, ScienceSum: integer);
    // calculates exact total tax and science income
    // tax is reduced by maintenance (so might be negative)
    // luxury not supported

  procedure OptimizeCityTiles;
    // obsolete; use City_OptimizeTiles instead

  procedure GetCityProdPotential;
    // calculates potential collected production resources of a city
    // result: list for all cities in CityResult
  procedure GetCityTradePotential;
    // calculates potential collected trade resources of a city
    // result: list for all cities in CityResult

  procedure JobAssignment_Initialize;
    // initialization, must be called first of the JobAssignment functions
  procedure JobAssignment_AddJob(Loc, Job, Score: integer);
    // add job for settlers with certain score
    // jobs include founding cities!
  procedure JobAssignment_AddUnit(uix: integer);
    // add a settler unit to do jobs
  procedure JobAssignment_Go;
    // to be called after all jobs and the settlers for them have been added
    // assigns each job to one settler, moves the settlers and makes them work
    // settlers prefer jobs which are closer to their current location and jobs with a higher score
    // starting a job one turn earlier counts the same as 4 points of score
    // function does not cancel jobs that are already started
  function JobAssignment_GotJob(uix: integer): boolean;
    // can be called after JobAssignment_Go to find out whether
    // a certain settler has been assigned a job to

  procedure AnalyzeMap;
    // calculates formations and districts

  function CheckStep(MoveStyle, TimeBeforeStep, CrossCorner: integer;
    var TimeAfterStep, RecoverTurns: integer; FromTile, ToTile: integer): integer;
    // forecast single unit move between adjacent tiles
    // format of TimeBeforeStep and TimeAfterStep: $1000*number of turns + $800-MP left
    // RecoverTurns: number of turns needed to rest outside city in order to
    //   recover from damage taken in this move (rounded up)
    // FromTile and ToTile must be Map[FromLoc] and Map[ToLoc], no location codes
    // CrossCorner=1 for long moves that cross the tile corner, =0 for short ones that don't

  function GetMyMoveStyle(mix,Health: integer): integer;

  function Unit_MoveEx(uix,ToLoc: integer; Options: integer = 0): integer;

  procedure SeaTransport_BeginInitialize;
  procedure SeaTransport_EndInitialize;
    // sea transport, obligatory call order:
    // 1. BeginInitialize
    // [2. AddLoad/AddTransport/AddDestination]
    // 3. EndInitialize
    // [4. MakeGroupPlan, MakeGroupPlan, MakeGroupPlan...]
    // don't use Pile between BeginInitialize and EndInitialize
    // sea transport only works well if
    // - all transports have same speed
    // - all transports have same capacity
    // - no transport is damaged
  procedure SeaTransport_AddLoad(uix: integer);
  procedure SeaTransport_AddTransport(uix: integer);
  procedure SeaTransport_AddDestination(Loc: integer);
  function SeaTransport_MakeGroupPlan(var TransportPlan: TGroupTransportPlan): boolean;
    // make plan for group of units to transport from a single loading location by a single transport
    // the plan optimizes:
    // - time for the units to move to the loading location
    // - time for the transport to move to the loading location
    // - time for the transport to move to one of the destination locations
    // after the plan is made, units and transport are removed from the pool, so that
    //   subsequent calls to MakeGroupPlan result in plans that may be executed parallel
    // function returns false if no more transports are possible

  end;


const
// no-formations
nfUndiscovered=-1; nfPole=-2; nfPeace=-3;

// return codes of CheckStep
csOk=0;
  // step is valid
  // TimeAfterMove has been calculated
csForbiddenTile=1;
  // unit can not move onto this tile
  // TimeAfterMove not calculated
csForbiddenStep=2;
  // (ZoC unit only) unit can not do this step because of ZoC violation
  // maybe tile can be reached using another way
  // TimeAfterMove not calculated
csCheckTerritory=3;
  // move within other nations's territory shortly after making peace
  // step is only possible if RO.Territory is the same for both tiles
  // TimeAfterMove has been calculated

// Unit_MoveEx
mxAdjacent=$00000001;


var
nContinent, nOcean, nDistrict: integer;
Formation: array[0..lxmax*lymax-1] of integer;
  // water: ocean index, land: continent index, sorted by size
  // territory unpassable due to peace treaty divides a continent
District: array[0..lxmax*lymax-1] of integer;
  // index of coherent own territory, sorted by size
CityResult: array[0..nCmax-1] of integer;

Advancedness: array[0..nAdv-1] of integer; // total number of prerequisites for each advance


implementation

uses
Pile;

type
pinteger=^integer;

var
// for JobAssignment
MaxScore: integer;
TileJob,TileJobScore: array[0..lxmax*lymax-1] of byte;
JobLocOfSettler: array[0..nUmax-1] of integer; // ToAssign = find job

// for Transport
TransportMoveStyle, TransportCapacity, nTransportLoad: integer;
InitComplete, HaveDestinations: boolean;
uixTransportLoad, TransportAvailable: array[0..nUmax-1] of integer;
TurnsAfterLoad: array[0..lxmax*lymax-1] of shortint;


procedure ReplaceD(Start, Stop: pinteger; Raider,Twix: integer);
begin
while Start<>Stop do
  begin
  if Start^=Raider then Start^:=Twix;
  inc(Start)
  end;
end;

function NextZero(Start, Stop: pinteger; Mask: cardinal): pinteger;
begin
while (Start<>Stop) and (Start^ and Mask<>0) do inc(Start);
result:=Start;
end;


function TToolAI.CityTaxBalance(cix: integer; const CityReport: TCityReport): integer;
var
i: integer;
begin
result:=0;
if (CityReport.Working-CityReport.Happy<=MyCity[cix].Size shr 1) {no disorder}
  and (MyCity[cix].Flags and chCaptured=0) then // not captured
  begin
  inc(result, CityReport.Tax);
  if (MyCity[cix].Project and (cpImp+cpIndex)=cpImp+imTrGoods)
    and (CityReport.ProdRep>CityReport.Support) then
    inc(result, CityReport.ProdRep-CityReport.Support);
  if ((RO.Government=gLybertarianism)
      or (MyCity[cix].Size>=NeedAqueductSize)
      and (CityReport.FoodRep<CityReport.Eaten+2))
    and (CityReport.FoodRep>CityReport.Eaten) then
    inc(result, CityReport.FoodRep-CityReport.Eaten);
  end;
for i:=28 to nImp-1 do if MyCity[cix].Built[i]>0 then
  dec(result, Imp[i].Maint);
end;

procedure TToolAI.SumCities(TaxRate: integer; var TaxSum, ScienceSum: integer);
var
cix,p1: integer;
CityReport: TCityReport;
begin
TaxSum:=0; ScienceSum:=0;
if RO.Government=gAnarchy then exit;
for p1:=0 to nPl-1 do
  if RO.Tribute[p1]<=RO.TributePaid[p1] then // don't rely on tribute from bankrupt nations
    TaxSum:=TaxSum+RO.Tribute[p1];
for cix:=0 to RO.nCity-1 do if MyCity[cix].Loc>=0 then
  begin
  City_GetHypoReport(cix,-1,TaxRate,0,CityReport);
  if (CityReport.Working-CityReport.Happy<=MyCity[cix].Size shr 1) {no disorder}
    and (MyCity[cix].Flags and chCaptured=0) then // not captured
    ScienceSum:=ScienceSum+CityReport.Science;
  TaxSum:=TaxSum+CityTaxBalance(cix, CityReport);
  end;
end;


//------------------------------------------------------------------------------
// City Tiles Processing

const
pctOptimize=0; pctGetProdPotential=1; pctGetTradePotential=2;

procedure TToolAI.OptimizeCityTiles;
var
cix: integer;
begin
for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
  City_OptimizeTiles(cix);
end;

procedure TToolAI.GetCityProdPotential;
var
cix: integer;
Advice: TCityTileAdviceData;
begin
for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
  begin
  Advice.ResourceWeights:=rwMaxProd;
  Server(sGetCityTileAdvice, me, cix, Advice);
  CityResult[cix]:=Advice.CityReport.ProdRep; // considers factory, but shouldn't
  end;
end;

procedure TToolAI.GetCityTradePotential;
var
cix: integer;
Advice: TCityTileAdviceData;
begin
for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
  begin
  Advice.ResourceWeights:=rwMaxScience;
  Server(sGetCityTileAdvice, me, cix, Advice);
  CityResult[cix]:=Advice.CityReport.Trade;
  end;
end;


//------------------------------------------------------------------------------
// JobAssignment

const
ToAssign=lxmax*lymax;

procedure TToolAI.JobAssignment_Initialize;
begin
fillchar(JobLocOfSettler, RO.nUn*sizeof(integer), $FF); // -1
fillchar(TileJob, MapSize, jNone);
fillchar(TileJobScore, MapSize, 0);
MaxScore:=0;
end;

procedure TToolAI.JobAssignment_AddJob(Loc, Job, Score: integer);
begin
if Score>255 then Score:=255;
if Score>TileJobScore[Loc] then
  begin
  TileJob[Loc]:=Job;
  TileJobScore[Loc]:=Score;
  if Score>MaxScore then MaxScore:=Score
  end;
end;

procedure TToolAI.JobAssignment_AddUnit(uix: integer);
begin
assert(MyModel[MyUnit[uix].mix].Kind in [mkSettler,mkSlaves]);
JobLocOfSettler[uix]:=ToAssign
end;

function TToolAI.JobAssignment_GotJob(uix: integer): boolean;
begin
result:=JobLocOfSettler[uix]>=0;
end;

procedure TToolAI.JobAssignment_Go;
const
DistanceScore=4;
StepSizeByTerrain: array[0..11] of integer=
( 0, 0, 1, 2, 1, 1, 0, 1, 0, 1, 1, 2);
//Oc-Sh-Gr-De-Pr-Tu-Ar-Sw-XX-Fo-Hi-Mo
var
uix,BestScore,BestCount,BestLoc,BestJob,BestDistance,TestLoc,NextLoc,
TestDistance,V8,TestScore,StepSize,MoveResult: integer;
UnitsToAssign: boolean;
Adjacent: TVicinity8Loc;
SettlerOfJobLoc,DistToLoc: array[0..lxmax*lymax-1] of smallint;
  // DistToLoc is only defined where SettlerOfJobLoc>=0
TileChecked: array[0..lxmax*lymax-1] of boolean;
begin
fillchar(SettlerOfJobLoc, MapSize*2, $FF); // -1
BestCount:=0;
BestLoc:=0;
BestDistance:=0;

// keep up jobs that are already started
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].Loc>=0) and (MyUnit[uix].Job>jNone) then
    begin
    JobLocOfSettler[uix]:=MyUnit[uix].Loc;
    SettlerOfJobLoc[MyUnit[uix].Loc]:=uix;
    DistToLoc[MyUnit[uix].Loc]:=0
    end;

// assign remaining jobs to remaining settlers
UnitsToAssign:=true;
while UnitsToAssign do
  begin
  UnitsToAssign:=false;
  for uix:=0 to RO.nUn-1 do if JobLocOfSettler[uix]=ToAssign then
    begin
    BestJob:=jNone;
    BestScore:=-999999;
    FillChar(TileChecked,MapSize*sizeof(boolean),false);
    Pile.Create(MapSize);
    Pile.Put(MyUnit[uix].Loc,0); // start search for new job at current location
    while Pile.Get(TestLoc,TestDistance) do
      begin
      // add surrounding tiles to queue, but only if there's a chance to beat BestScore
      if MaxScore-DistanceScore*(TestDistance+1)>=BestScore then
        begin
        V8_to_Loc(TestLoc,Adjacent);
        for V8:=0 to 7 do
          begin
          NextLoc:=Adjacent[V8];
          if (NextLoc>=0) and not TileChecked[NextLoc]
            and (Map[NextLoc] and fTerrain<>fUNKNOWN) then
            begin
            StepSize:=StepSizeByTerrain[Map[NextLoc] and fTerrain];
            if (StepSize>0) // no water or arctic tile
              and (Map[NextLoc] and (fUnit or fOwned)<>fUnit) // no foreign unit
              and ((RO.Territory[NextLoc]<0) or (RO.Territory[NextLoc]=me)) // no foreign territory
              and (Map[TestLoc] and Map[NextLoc] and fInEnemyZoC=0) then // move not prevented by ZoC
              Pile.Put(NextLoc,TestDistance+StepSize)
              // simplification, only optimal for 150 mp units in land with no roads
            end;
          end;
        end;

      // check tile for job
      if (TileJob[TestLoc]>jNone)
        and ((MyModel[MyUnit[uix].mix].Kind<>mkSlaves)
          or (TileJob[TestLoc]<>jCity))
        and ((SettlerOfJobLoc[TestLoc]<0) or (DistToLoc[TestLoc]>TestDistance)) then
        begin
        TestScore:=integer(TileJobScore[TestLoc])-DistanceScore*TestDistance;
        if TestScore>BestScore then
          BestCount:=0;
        if TestScore>=BestScore then
          begin
          inc(BestCount);
          if random(BestCount)=0 then
            begin
            BestScore:=TestScore;
            BestLoc:=TestLoc;
            BestJob:=TileJob[TestLoc];
            BestDistance:=TestDistance
            end
          end;
        end;
      TileChecked[TestLoc]:=true;
      end;
    Pile.Free;

    if BestJob>jNone then
      begin // new job found for this unit
      if SettlerOfJobLoc[BestLoc]>=0 then
        begin // another unit was already assigned to this job, but is not as close -- reassign that unit!
        JobLocOfSettler[SettlerOfJobLoc[BestLoc]]:=ToAssign;
        UnitsToAssign:=true;
        end;
      JobLocOfSettler[uix]:=BestLoc;
      SettlerOfJobLoc[BestLoc]:=uix;
      DistToLoc[BestLoc]:=BestDistance
      end
    else JobLocOfSettler[uix]:=-1; // no jobs for this settler
    end; // for uix
  end;

// move settlers and start new jobs
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (Job=jNone) and (JobLocOfSettler[uix]>=0) then
    begin
    if Loc<>JobLocOfSettler[uix] then
      repeat
        MoveResult:=Unit_Move(uix,JobLocOfSettler[uix])
      until (MoveResult<rExecuted)
        or (MoveResult and (rLocationReached or rMoreTurns or rUnitRemoved)<>0);
    if (Loc=JobLocOfSettler[uix]) and (Movement>=100) then
      Unit_StartJob(uix,TileJob[JobLocOfSettler[uix]]);
    end;
end; // JobAssignment_Go


//------------------------------------------------------------------------------
// Map Analysis

procedure TToolAI.AnalyzeMap;
var
i,j,Loc,Loc1,V8,Count,Kind,MostIndex: integer;
Adjacent: TVicinity8Loc;
IndexOfID: array[0..lxmax*lymax-1] of smallint;
IDOfIndex: array[0..lxmax*lymax div 2 -1] of smallint;
begin
fillchar(District, MapSize*4, $FF);
for Loc:=0 to MapSize-1 do
  if Map[Loc] and fTerrain=fUNKNOWN then Formation[Loc]:=nfUndiscovered
  else if Map[Loc] and fTerrain=fArctic then Formation[Loc]:=nfPole
  else if Map[Loc] and fPeace<>0 then Formation[Loc]:=nfPeace
  else
    begin
    Formation[Loc]:=Loc;
    V8_to_Loc(Loc, Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1<Loc) and (Loc1>=0) and (Formation[Loc1]>=0)
        and ((Map[Loc1] and fTerrain>=fGrass) = (Map[Loc] and fTerrain>=fGrass)) then
        if Formation[Loc]=Loc then Formation[Loc]:=Formation[Loc1]
        else if Formation[Loc]<Formation[Loc1] then
          ReplaceD(@Formation[Formation[Loc1]],@Formation[Loc+1],Formation[Loc1],Formation[Loc])
        else if Formation[Loc]>Formation[Loc1] then
          ReplaceD(@Formation[Formation[Loc]],@Formation[Loc+1],Formation[Loc],Formation[Loc1]);
      end;
    if (RO.Territory[Loc]=me) and (Map[Loc] and fTerrain>=fGrass) then
      begin
      District[Loc]:=Loc;
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if (Loc1<Loc) and (Loc1>=0) and (District[Loc1]>=0) then
          if District[Loc]=Loc then District[Loc]:=District[Loc1]
          else if District[Loc]<District[Loc1] then
            ReplaceD(@District[District[Loc1]],@District[Loc+1],District[Loc1],District[Loc])
          else if District[Loc]>District[Loc1] then
            ReplaceD(@District[District[Loc]],@District[Loc+1],District[Loc],District[Loc1]);
        end
      end
    end;

// sort continents, oceans and districts by size
for Kind:=0 to 2 do
  begin
  FillChar(IndexOfID,MapSize*2,0);
  case Kind of
    0: // continents
      for Loc:=0 to MapSize-1 do
        if (Formation[Loc]>=0) and (Map[Loc] and fTerrain>=fGrass) then
          inc(IndexOfID[Formation[Loc]]);
    1: // oceans
      for Loc:=0 to MapSize-1 do
        if (Formation[Loc]>=0) and (Map[Loc] and fTerrain<fGrass) then
          inc(IndexOfID[Formation[Loc]]);
    2: // districts
      for Loc:=0 to MapSize-1 do
        if District[Loc]>=0 then
          inc(IndexOfID[District[Loc]]);
    end;

  Count:=0;
  for Loc:=0 to MapSize-1 do if IndexOfID[Loc]>0 then
    begin
    IDOfIndex[Count]:=Loc;
    inc(Count);
    end;
  for i:=0 to Count-2 do
    begin
    MostIndex:=i;
    for j:=i+1 to Count-1 do
      if IndexOfID[IDOfIndex[j]]>IndexOfID[IDOfIndex[MostIndex]] then MostIndex:=j;
    if MostIndex<>i then
      begin
      j:=IDOfIndex[i];
      IDOfIndex[i]:=IDOfIndex[MostIndex];
      IDOfIndex[MostIndex]:=j;
      end
    end;
  for i:=0 to Count-1 do
    IndexOfID[IDOfIndex[i]]:=i;

  case Kind of
    0: // continents
      begin
      nContinent:=Count;
      for Loc:=0 to MapSize-1 do
        if (Formation[Loc]>=0) and (Map[Loc] and fTerrain>=fGrass) then
          Formation[Loc]:=IndexOfID[Formation[Loc]];
      end;
    1: // oceans
      begin
      nOcean:=Count;
      for Loc:=0 to MapSize-1 do
        if (Formation[Loc]>=0) and (Map[Loc] and fTerrain<fGrass) then
          Formation[Loc]:=IndexOfID[Formation[Loc]];
      end;
    2: // districts
      begin
      nDistrict:=Count;
      for Loc:=0 to MapSize-1 do
        if District[Loc]>=0 then
          District[Loc]:=IndexOfID[District[Loc]];
      end;
    end
  end;
end;


//------------------------------------------------------------------------------
// Path Finding

const
// basic move styles
msGround=        $00000000;
msNoGround=      $10000000;
msAlpine=        $20000000;
msOver=          $40000000;
msSpy=           $50000000;

// other
msHostile=       $08000000;

// bits:   |31|30|29|28|27|26 .. 16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
// ground: |   Basic   |Ho| Speed  |       HeavyCost       |        RailCost       |
// other:  |   Basic   | 0| Speed  |              X X X             | MaxTerrType  |

function TToolAI.GetMyMoveStyle(mix,Health: integer): integer;
begin
with MyModel[mix] do
  begin
  result:=Speed shl 16;
  case Domain of
    dGround:
      begin
      inc(result, (50+(Speed-150)*13 shr 7) shl 8); //HeavyCost
      if RO.Wonder[woShinkansen].EffectiveOwner<>me then
        inc(result, Speed*(4*1311) shr 17); // RailCost
      if RO.Wonder[woGardens].EffectiveOwner<>me then
        inc(result, msHostile);
      if Kind=mkDiplomat then
        inc(result,msSpy)
      else if Cap[mcOver]>0 then
        inc(result,msOver)
      else if Cap[mcAlpine]>0 then
        inc(result,msAlpine)
      else inc(result,msGround);
      end;
    dSea:
      begin
      result:=Speed;
      if RO.Wonder[woMagellan].EffectiveOwner=me then inc(result,200);
      if Health<100 then result:=((result-250)*Health div 5000)*50+250;
      result:=result shl 16;
      inc(result,msNoGround);
      if Cap[mcNav]>0 then inc(result);
      end;
    dAir:
      inc(result,msNoGround+fUNKNOWN xor 1 -1);
    end;
  end
end;

function TToolAI.CheckStep(MoveStyle, TimeBeforeStep, CrossCorner: integer;
  var TimeAfterStep, RecoverTurns: integer; FromTile, ToTile: integer): integer;
var
MoveCost,RecoverCost: integer;
begin
assert(((FromTile and fTerrain<=fMountains) or (FromTile and fTerrain=fUNKNOWN))
  and ((ToTile and fTerrain<=fMountains) or (ToTile and fTerrain=fUNKNOWN)));
  // do not pass location codes for FromTile and ToTile!
RecoverTurns:=0;
if MoveStyle<msGround+$10000000 then
  begin // common ground units
  if (ToTile+1) and fTerrain<fGrass+1 then
    result:=csForbiddenTile
  else if (ToTile and not FromTile and fPeace=0)
    and (ToTile and (fUnit or fOwned)<>fUnit) then
    if (FromTile and fCity<>0) or (ToTile and (fCity or fOwned)=fCity or fOwned)
      or (ToTile and FromTile and (fInEnemyZoc or fOwnZoCUnit)<>fInEnemyZoc) then
      begin // ZoC is ok
      if (ToTile and (fRR or fCity)=0) or (FromTile and (fRR or fCity)=0) then
        begin // no railroad
        if (ToTile and (fRoad or fRR or fCity)<>0)
          and (FromTile and (fRoad or fRR or fCity)<>0)
          or (FromTile and ToTile and (fRiver or fCanal)<>0) then
          MoveCost:=20 //move along road, river or canal
        else
          begin
          case Terrain[ToTile and fTerrain].MoveCost of
            1: MoveCost:=50; // plain terrain
            2: MoveCost:=MoveStyle shr 8 and $FF; // heavy terrain
            else // mountains
              begin
              if TimeBeforeStep and $FFF+MoveStyle shr 16 and $7FF<=$800 then
                TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800
              else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$2800; // must wait for next turn
              if (MoveStyle and msHostile<>0)
                and ((FromTile and (fTerrain or fSpecial1)=fDesert)
                  or (FromTile and fTerrain=fArctic))
                and (FromTile and (fCity or fRiver or fCanal)=0) then
                begin
                RecoverCost:=($800-TimeBeforeStep and $FFF)*5 shr 1;
                while RecoverCost>0 do
                  begin
                  inc(RecoverTurns);
                  dec(RecoverCost, MoveStyle shr 16 and $7FF);
                  end;
                end;  
              result:=csOk;
              if ToTile and fPeace<>0 then
                result:=csCheckTerritory;
              exit
              end;
            end
          end
        end
      else MoveCost:=MoveStyle and $FF; //move along railroad

      inc(MoveCost,MoveCost shl CrossCorner);
      if (MoveStyle and msHostile=0)
        or (ToTile and (fTerrain or fSpecial1)<>fDesert)
          and (ToTile and fTerrain<>fArctic)
        or (ToTile and (fCity or fRiver or fCanal)<>0) then
        RecoverCost:=0
      else RecoverCost:=(MoveCost*5) shr 1; // damage from movement: MoveCost*DesertThurst/NoCityRecovery
      if (TimeBeforeStep and $FFF+MoveCost<=$800) and (TimeBeforeStep and $FFF<$800) then
        TimeAfterStep:=TimeBeforeStep+MoveCost
      else
        begin
        TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800-MoveStyle shr 16 and $7FF+MoveCost; // must wait for next turn
        if (MoveStyle and msHostile<>0)
          and ((FromTile and (fTerrain or fSpecial1)=fDesert)
            or (FromTile and fTerrain=fArctic))
          and (FromTile and (fCity or fRiver or fCanal)=0) then
          inc(RecoverCost, ($800-TimeBeforeStep and $FFF)*5 shr 1);
        end;
      while RecoverCost>0 do
        begin
        inc(RecoverTurns);
        dec(RecoverCost, MoveStyle shr 16 and $7FF);
        end;
      result:=csOk;
      if ToTile and fPeace<>0 then
        result:=csCheckTerritory
      end
    else result:=csForbiddenStep // ZoC violation
  else result:=csForbiddenTile
  end

else if MoveStyle<msNoGround+$10000000 then
  begin // ships and aircraft
  if ((ToTile and fTerrain xor 1>MoveStyle and fTerrain)
      and (ToTile and (fCity or fCanal)=0))
    or (ToTile and not FromTile and fPeace<>0)
    or (ToTile and (fUnit or fOwned)=fUnit) then
    result:=csForbiddenTile
  else
    begin
    MoveCost:=50 shl CrossCorner+50;
    if TimeBeforeStep and $FFF+MoveCost<=$800 then
      TimeAfterStep:=TimeBeforeStep+MoveCost
    else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800-MoveStyle shr 16 and $7FF+MoveCost; // must wait for next turn
    result:=csOk;
    if ToTile and fPeace<>0 then
      result:=csCheckTerritory
    end
  end

else if MoveStyle<msAlpine+$10000000 then
  begin // alpine
  if (ToTile+1) and fTerrain<fGrass+1 then
    result:=csForbiddenTile
  else if (ToTile and not FromTile and fPeace=0)
    and (ToTile and (fUnit or fOwned)<>fUnit) then
    if (FromTile and fCity<>0) or (ToTile and (fCity or fOwned)=fCity or fOwned)
      or (ToTile and FromTile and (fInEnemyZoc or fOwnZoCUnit)<>fInEnemyZoc) then
      begin
      if (ToTile and (fRR or fCity)=0) or (FromTile and (fRR or fCity)=0) then
        MoveCost:=20 // no railroad
      else MoveCost:=MoveStyle and $FF; //move along railroad
      inc(MoveCost,MoveCost shl CrossCorner);
      if (TimeBeforeStep and $FFF+MoveCost<=$800) and (TimeBeforeStep and $FFF<$800) then
        TimeAfterStep:=TimeBeforeStep+MoveCost
      else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800-MoveStyle shr 16 and $7FF+MoveCost; // must wait for next turn
      result:=csOk;
      if ToTile and fPeace<>0 then
        result:=csCheckTerritory
      end
    else result:=csForbiddenStep // ZoC violation
  else result:=csForbiddenTile
  end

else if MoveStyle<msOver+$10000000 then
  begin // overweight
  if (ToTile+1) and fTerrain<fGrass+1 then
    result:=csForbiddenTile
  else if (ToTile and not FromTile and fPeace=0)
    and (ToTile and (fUnit or fOwned)<>fUnit) then
    if (FromTile and fCity<>0) or (ToTile and (fCity or fOwned)=fCity or fOwned)
      or (ToTile and FromTile and (fInEnemyZoc or fOwnZoCUnit)<>fInEnemyZoc) then
      begin
      if (ToTile and (fRR or fCity)=0) or (FromTile and (fRR or fCity)=0) then
        begin // no railroad
        if (ToTile and (fRoad or fRR or fCity)<>0)
          and (FromTile and (fRoad or fRR or fCity)<>0)
          or (FromTile and ToTile and (fRiver or fCanal)<>0) then
          MoveCost:=40 //move along road, river or canal
        else begin result:=csForbiddenTile; exit end
        end
      else MoveCost:=MoveStyle and $FF; //move along railroad
      inc(MoveCost,MoveCost shl CrossCorner);
      if (TimeBeforeStep and $FFF+MoveCost<=$800) and (TimeBeforeStep and $FFF<$800) then
        TimeAfterStep:=TimeBeforeStep+MoveCost
      else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800-MoveStyle shr 16 and $7FF+MoveCost; // must wait for next turn
      result:=csOk;
      if ToTile and fPeace<>0 then
        result:=csCheckTerritory
      end
    else result:=csForbiddenStep // ZoC violation
  else result:=csForbiddenTile
  end

else {if MoveStyle<msSpy+$10000000 then}
  begin // spies
  if (ToTile+1) and fTerrain<fGrass+1 then
    result:=csForbiddenTile
  else if ToTile and (fUnit or fOwned)<>fUnit then
    begin
    if (ToTile and (fRR or fCity)=0) or (FromTile and (fRR or fCity)=0) then
      begin // no railroad
      if (ToTile and (fRoad or fRR or fCity)<>0)
        and (FromTile and (fRoad or fRR or fCity)<>0)
        or (FromTile and ToTile and (fRiver or fCanal)<>0) then
        MoveCost:=20 //move along road, river or canal
      else
        begin
        case Terrain[ToTile and fTerrain].MoveCost of
          1: MoveCost:=50; // plain terrain
          2: MoveCost:=MoveStyle shr 8 and $FF; // heavy terrain
          else // mountains
            begin
            if TimeBeforeStep and $FFF+MoveStyle shr 16 and $7FF<=$800 then
              TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800
            else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$2800; // must wait for next turn
            result:=csOk;
            exit
            end;
          end
        end
      end
    else MoveCost:=MoveStyle and $FF; //move along railroad
    inc(MoveCost,MoveCost shl CrossCorner);
    if (TimeBeforeStep and $FFF+MoveCost<=$800) and (TimeBeforeStep and $FFF<$800) then
      TimeAfterStep:=TimeBeforeStep+MoveCost
    else TimeAfterStep:=TimeBeforeStep and $7FFFF000+$1800-MoveStyle shr 16 and $7FF+MoveCost; // must wait for next turn
    result:=csOk;
    end
  else result:=csForbiddenTile
  end;
end; // CheckStep

(*
-------- Pathfinding Reference Implementation --------
var
MoveStyle,V8,Loc,Time,NextLoc,NextTime,RecoverTurns: integer;
Adjacent: TVicinity8Loc;
Reached: array[0..lxmax*lymax-1] of boolean;
begin
fillchar(Reached, MapSize, false);
MoveStyle:=GetMyMoveStyle(MyUnit[uix].mix, MyUnit[uix].Health);
Pile.Create(MapSize);
Pile.Put(MyUnit[uix].Loc, $800-MyUnit[uix].Movement);
while Pile.Get(Loc, Time) do
  begin
  // todo: check exit condition, e.g. whether destination reached

  Reached[Loc]:=true;
  V8_to_Loc(Loc, Adjacent);
  for V8:=0 to 7 do
    begin
    NextLoc:=Adjacent[V8];
    if (NextLoc>=0) and not Reached[NextLoc] then
      case CheckStep(MoveStyle, Time, V8 and 1, NextTime, RecoverTurns, Map[Loc], Map[NextLoc]) of
        csOk:
          Pile.Put(NextLoc, NextTime+RecoverTurns*$1000);
        csForbiddenTile:
          Reached[NextLoc]:=true; // don't check moving there again
        csCheckTerritory:
          if RO.Territory[NextLoc]=RO.Territory[Loc] then
            Pile.Put(NextLoc, NextTime+RecoverTurns*$1000);
        end
    end;
  end;
Pile.Free;
end;
*)

function TToolAI.Unit_MoveEx(uix,ToLoc: integer; Options: integer): integer;
var
Loc,NextLoc,Temp,FromLoc,EndLoc,Time,V8,MoveResult,RecoverTurns,NextTime,
  MoveStyle: integer;
Adjacent: TVicinity8Loc;
PreLoc: array[0..lxmax*lymax-1] of integer;
Reached: array[0..lxmax*lymax-1] of boolean;
begin
result:=eOk;
FromLoc:=MyUnit[uix].Loc;
if FromLoc=ToLoc then exit;

FillChar(Reached,MapSize,false);
MoveStyle:=GetMyMoveStyle(MyUnit[uix].mix, MyUnit[uix].Health);
EndLoc:=-1;
Pile.Create(MapSize);
Pile.Put(FromLoc, $800-MyUnit[uix].Movement);
while Pile.Get(Loc,Time) do
  begin
  if (Loc=ToLoc)
    or (ToLoc=maNextCity) and (Map[Loc] and fCity<>0)
    and (Map[Loc] and fOwned<>0) then
    begin EndLoc:=Loc; Break; end;
  Reached[Loc]:=true;
  V8_to_Loc(Loc,Adjacent);
  for V8:=0 to 7 do
    begin
    NextLoc:=Adjacent[V8];
    if NextLoc>=0 then
      if (NextLoc=ToLoc) and (Options and mxAdjacent<>0) then
        begin EndLoc:=Loc; Break end
      else if not Reached[NextLoc] then
        case CheckStep(MoveStyle, Time, V8 and 1, NextTime, RecoverTurns,
          Map[Loc], Map[NextLoc]) of
          csOk:
            if Pile.Put(NextLoc, NextTime+RecoverTurns*$1000) then
              PreLoc[NextLoc]:=Loc;
          csForbiddenTile:
            Reached[NextLoc]:=true; // don't check moving there again
          csCheckTerritory:
            if RO.Territory[NextLoc]=RO.Territory[Loc] then
              if Pile.Put(NextLoc, NextTime+RecoverTurns*$1000) then
                PreLoc[NextLoc]:=Loc;
          end
    end;
  if EndLoc>=0 then Break;
  end;
Pile.Free;

if EndLoc>=0 then
  begin
  Loc:=EndLoc;
  NextLoc:=PreLoc[Loc];
  while Loc<>FromLoc do
    begin // invert meaning of PreLoc
    Temp:=Loc;
    Loc:=NextLoc;
    NextLoc:=PreLoc[Loc];
    PreLoc[Loc]:=Temp;
    end;
  while Loc<>EndLoc do
    begin
    Loc:=PreLoc[Loc];
    MoveResult:=Unit_Step(uix, Loc);
    if (MoveResult<>eOK) and (MoveResult<>eLoaded) then
      begin result:=MoveResult; break end;
    end;
  end
else result:=eNoWay;
end;


//------------------------------------------------------------------------------
// Oversea Transport

procedure TToolAI.SeaTransport_BeginInitialize;
begin
fillchar(TransportAvailable, RO.nUn*sizeof(integer), $FF); // -1
InitComplete:=false;
HaveDestinations:=false;
nTransportLoad:=0;
TransportMoveStyle:=0;
TransportCapacity:=$100;
Pile.Create(MapSize);
end;

procedure TToolAI.SeaTransport_AddLoad(uix: integer);
var
i: integer;
begin
assert(not InitComplete); // call order violation!
if Map[MyUnit[uix].Loc] and fTerrain<fGrass then exit;
for i:=0 to nTransportLoad-1 do
  if uix=uixTransportLoad[i] then exit;
uixTransportLoad[nTransportLoad]:=uix;
inc(nTransportLoad);
end;

procedure TToolAI.SeaTransport_AddTransport(uix: integer);
var
MoveStyle: integer;
begin
assert(not InitComplete); // call order violation!
assert(MyModel[MyUnit[uix].mix].Cap[mcSeaTrans]>0);
TransportAvailable[uix]:=1;
with MyModel[MyUnit[uix].mix] do
  begin
  if MTrans*Cap[mcSeaTrans]<TransportCapacity then
    TransportCapacity:=MTrans*Cap[mcSeaTrans];
  MoveStyle:=GetMyMoveStyle(MyUnit[uix].mix, 100);
  if (TransportMoveStyle=0)
    or (MoveStyle<TransportMoveStyle)
      and (MoveStyle and not TransportMoveStyle and 1=0)
    or (not MoveStyle and TransportMoveStyle and 1<>0) then
    TransportMoveStyle:=MoveStyle;
  end
end;

procedure TToolAI.SeaTransport_AddDestination(Loc: integer);
begin
assert(not InitComplete); // call order violation!
Pile.Put(Loc, $800);
HaveDestinations:=true;
end;

procedure TToolAI.SeaTransport_EndInitialize;
var
Loc0,Time0,V8,Loc1,ArriveTime,RecoverTurns: integer;
Adjacent: TVicinity8Loc;
begin
assert(not InitComplete); // call order violation!
InitComplete:=true;
if HaveDestinations then
  begin // calculate TurnsAfterLoad from destination locs
  fillchar(TurnsAfterLoad, MapSize, $FF); // -1
  while Pile.Get(Loc0, Time0) do
    begin // search backward
    if Time0=$800 then TurnsAfterLoad[Loc0]:=1
    else TurnsAfterLoad[Loc0]:=Time0 shr 12;
    V8_to_Loc(Loc0, Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1>=0) and (TurnsAfterLoad[Loc1]=-1) then
        begin
        case CheckStep(TransportMoveStyle, Time0, V8 and 1, ArriveTime,
          RecoverTurns, Map[Loc0], Map[Loc1]) of
          csOk: Pile.Put(Loc1, ArriveTime);
          csForbiddenStep: TurnsAfterLoad[Loc1]:=-2;
          end;
        end
      end
    end;
  end;
Pile.Free;
end;


function TToolAI.SeaTransport_MakeGroupPlan(var TransportPlan: TGroupTransportPlan): boolean;
var
V8,i,j,iPicked,uix,Loc0,Time0,Loc1,RecoverTurns,MoveStyle, TurnsLoaded,
  TurnCount, tuix, tuix1, ArriveTime, TotalDelay, BestTotalDelay, GroupCount,
  BestGroupCount, BestLoadLoc, FullMovementLoc, nSelectedLoad, f,
  OriginContinent,a,b: integer;
CompleteFlag, NotReachedFlag, ContinueUnit: Cardinal;
IsComplete,ok,IsFirstLoc: boolean;
StartLocPtr, ArrivedEnd: pinteger;
Adjacent: TVicinity8Loc;
uixSelectedLoad: array[0..15] of integer;
tuixSelectedLoad: array[0..15] of integer;
Arrived: array[0..lxmax*lymax] of cardinal;
ResponsibleTransport: array[0..lxmax*lymax-1] of smallint;
TurnsBeforeLoad: array[0..lxmax*lymax-1] of shortint;
GroupComplete: array[0..lxmax*lymax-1] of boolean;
begin
assert(InitComplete); // call order violation!

if HaveDestinations and (nTransportLoad>0) then
  begin // transport and units already adjacent?
  for uix:=0 to RO.nUn-1 do
    if (TransportAvailable[uix]>0)
      and (Map[MyUnit[uix].Loc] and fTerrain=fShore) then
      begin
      GroupCount:=0;
      for tuix:=0 to nTransportLoad-1 do
        begin
        Loc_to_ab(MyUnit[uix].Loc, MyUnit[uixTransportLoad[tuix]].Loc, a, b);
        if (abs(a)<=1) and (abs(b)<=1) then
          begin
          assert((a<>0) or (b<>0));
          inc(GroupCount);
          end
        end;
      if (GroupCount=nTransportLoad) or (GroupCount>=TransportCapacity) then
        begin
        TransportPlan.LoadLoc:=MyUnit[uix].Loc;
        TransportPlan.uixTransport:=uix;
        TransportAvailable[uix]:=0;
        TransportPlan.TurnsEmpty:=0;
        TransportPlan.TurnsLoaded:=TurnsAfterLoad[TransportPlan.LoadLoc];
        TransportPlan.nLoad:=0;
        for tuix:=nTransportLoad-1 downto 0 do
          begin
          Loc_to_ab(TransportPlan.LoadLoc, MyUnit[uixTransportLoad[tuix]].Loc, a, b);
          if (abs(a)<=1) and (abs(b)<=1) then
            begin
            TransportPlan.uixLoad[TransportPlan.nLoad]:=uixTransportLoad[tuix];
            uixTransportLoad[tuix]:=uixTransportLoad[nTransportLoad-1];
            dec(nTransportLoad);
            inc(TransportPlan.nLoad);
            if TransportPlan.nLoad=TransportCapacity then break;
            end;
          end;
        result:=true;
        exit;
        end
      end
  end;

while HaveDestinations and (nTransportLoad>0) do
  begin
  // select units from same continent
  fillchar(Arrived, 4*nContinent, 0); // misuse Arrived as counter
  for tuix:=0 to nTransportLoad-1 do
    begin
    assert(Map[MyUnit[uixTransportLoad[tuix]].Loc] and fTerrain>=fGrass);
    f:=Formation[MyUnit[uixTransportLoad[tuix]].Loc];
    if f>=0 then inc(Arrived[f]);
    end;
  OriginContinent:=0;
  for f:=1 to nContinent-1 do
    if Arrived[f]>Arrived[OriginContinent] then OriginContinent:=f;
  nSelectedLoad:=0;
  for tuix:=0 to nTransportLoad-1 do
    if Formation[MyUnit[uixTransportLoad[tuix]].Loc]=OriginContinent then
      begin
      tuixSelectedLoad[nSelectedLoad]:=tuix;
      uixSelectedLoad[nSelectedLoad]:=uixTransportLoad[tuix];
      inc(nSelectedLoad);
      if nSelectedLoad=16 then break;
      end;

  Pile.Create(MapSize);
  fillchar(ResponsibleTransport, MapSize*2, $FF); // -1
  fillchar(TurnsBeforeLoad, MapSize, $FF); // -1
  ok:=false;
  for uix:=0 to RO.nUn-1 do if TransportAvailable[uix]>0 then
    begin
    ok:=true;
    Pile.Put(MyUnit[uix].Loc, ($800-MyUnit[uix].Movement) shl 12 + uix);
    end;
  if not ok then // no transports
    begin TransportPlan.LoadLoc:=-1; result:=false; Pile.Free; exit end;
  while Pile.Get(Loc0, Time0) do
    begin
    uix:=Time0 and $FFF;
    Time0:=Time0 shr 12;
    ResponsibleTransport[Loc0]:=uix;
    TurnsBeforeLoad[Loc0]:=Time0 shr 12;
    V8_to_Loc(Loc0, Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1>=0) and (ResponsibleTransport[Loc1]<0) then
        case CheckStep(GetMyMoveStyle(MyUnit[uix].mix, MyUnit[uix].Health),
          Time0, V8 and 1, ArriveTime, RecoverTurns, Map[Loc0], Map[Loc1]) of
          csOk: Pile.Put(Loc1, ArriveTime shl 12 + uix);
          csForbiddenTile: ResponsibleTransport[Loc1]:=RO.nUn; // don't check again
          end
      end
    end;

  fillchar(Arrived, MapSize*4, $55); // set NotReachedFlag for all tiles
  fillchar(GroupComplete, MapSize, false);
  BestLoadLoc:=-1;

  // check direct loading
  for tuix:=0 to nSelectedLoad-1 do
    begin
    uix:=uixSelectedLoad[tuix];
    if MyUnit[uix].Movement=integer(MyModel[MyUnit[uix].mix].Speed) then
      begin
      NotReachedFlag:=1 shl (2*tuix);
      CompleteFlag:=NotReachedFlag shl 1;
      V8_to_Loc(MyUnit[uix].Loc, Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if (Loc1>=0) and (Map[Loc1] and fTerrain<fGrass)
          and not GroupComplete[Loc1] then
          begin // possible transport start location
          Arrived[Loc1]:=(Arrived[Loc1] or CompleteFlag) and not NotReachedFlag;
          if (TurnsBeforeLoad[Loc1]>=0) and (TurnsAfterLoad[Loc1]>=0) then
            begin
            i:=1;
            GroupCount:=0;
            for tuix1:=0 to nSelectedLoad-1 do
              begin
              if Arrived[loc1] and i=0 then inc(GroupCount);
              i:=i shl 2;
              end;
            assert(GroupCount<=TransportCapacity);
            if (GroupCount=TransportCapacity) or (GroupCount=nSelectedLoad) then
              GroupComplete[loc1]:=true;
            TotalDelay:=TurnsBeforeLoad[Loc1]+TurnsAfterLoad[Loc1];
            if (BestLoadLoc<0)
              or (GroupCount shl 16-TotalDelay
                >BestGroupCount shl 16-BestTotalDelay) then
              begin
              BestLoadLoc:=Loc1;
              BestGroupCount:=GroupCount;
              BestTotalDelay:=TotalDelay
              end
            end
          end
        end;
      end
    end;

  TurnCount:=0;
  ArrivedEnd:=@Arrived[MapSize];

  // check moving+loading
  ContinueUnit:=1 shl nSelectedLoad-1;
  while (ContinueUnit>0) and ((BestLoadLoc<0) or (TurnCount<BestTotalDelay-2)) do
    begin
    for tuix:=0 to nSelectedLoad-1 do if 1 shl tuix and ContinueUnit<>0 then
      begin
      uix:=uixSelectedLoad[tuix];
      MoveStyle:=GetMyMoveStyle(MyUnit[uix].mix, MyUnit[uix].Health);
      NotReachedFlag:=1 shl (2*tuix);
      CompleteFlag:=NotReachedFlag shl 1;
      FullMovementLoc:=-1;

      Pile.Empty;
      if TurnCount=0 then
        begin
        Pile.Put(MyUnit[uix].Loc, $1800-MyUnit[uix].Movement);
        if MyUnit[uix].Movement=integer(MyModel[MyUnit[uix].mix].Speed) then
          FullMovementLoc:=MyUnit[uix].Loc; // surrounding tiles can be loaded immediately
        StartLocPtr:=ArrivedEnd;
        end
      else StartLocPtr:=@Arrived;
      IsFirstLoc:=true;

      repeat
        if StartLocPtr<>ArrivedEnd then // search next movement start location for this turn
          StartLocPtr:=NextZero(StartLocPtr, ArrivedEnd, CompleteFlag or NotReachedFlag);
        if StartLocPtr<>ArrivedEnd then
          begin
          Loc0:=(integer(StartLocPtr)-integer(@Arrived)) shr 2;
          inc(StartLocPtr);
          Time0:=$800
          end
        else if not Pile.Get(Loc0, Time0) then
          begin
          if IsFirstLoc then ContinueUnit:=ContinueUnit and not (1 shl tuix);
          break;
          end;
        IsFirstLoc:=false;

        Arrived[Loc0]:=Arrived[Loc0] and not NotReachedFlag;
        if not GroupComplete[Loc0] and (Map[Loc0] and fTerrain<>fMountains) then
          begin // check whether group complete -- no mountains because complete flag might be faked there
          i:=1;
          GroupCount:=0;
          for tuix1:=0 to nSelectedLoad-1 do 
            begin
            if Arrived[Loc0] and i=0 then inc(GroupCount);
            i:=i shl 2;
            end;
          assert(GroupCount<=TransportCapacity);
          if (GroupCount=TransportCapacity) or (GroupCount=nSelectedLoad) then
            GroupComplete[Loc0]:=true
          end;

        V8_to_Loc(Loc0, Adjacent);
        IsComplete:=true;
        for V8:=0 to 7 do
          begin
          Loc1:=Adjacent[V8];
          if (Loc1<G.ly) or (Loc1>=MapSize-G.ly) then
            Adjacent[V8]:=-1 // pole, don't consider moving here
          else if Arrived[Loc1] and NotReachedFlag=0 then
            Adjacent[V8]:=-1 // unit has already arrived this tile
          else if GroupComplete[Loc1] then
            Adjacent[V8]:=-1 // already other group complete
          else if Map[Loc1] and fTerrain<fGrass then
            begin // possible transport start location
            Arrived[Loc1]:=(Arrived[Loc1] or CompleteFlag) and not NotReachedFlag;
            Adjacent[V8]:=-1;
            if (TurnsBeforeLoad[Loc1]>=0) and (TurnsAfterLoad[Loc1]>=0) then
              begin
              i:=1;
              GroupCount:=0;
              for tuix1:=0 to nSelectedLoad-1 do 
                begin
                if Arrived[loc1] and i=0 then inc(GroupCount);
                i:=i shl 2;
                end;
              assert(GroupCount<=TransportCapacity);
              if (GroupCount=TransportCapacity) or (GroupCount=nSelectedLoad) then
                GroupComplete[loc1]:=true;
              if TurnsBeforeLoad[Loc1]>TurnCount+1 then
                TotalDelay:=TurnsBeforeLoad[Loc1]+TurnsAfterLoad[Loc1]
              else TotalDelay:=TurnCount+1+TurnsAfterLoad[Loc1];
              if (BestLoadLoc<0)
                or (GroupCount shl 16-TotalDelay
                  >BestGroupCount shl 16-BestTotalDelay) then
                begin
                BestLoadLoc:=Loc1;
                BestGroupCount:=GroupCount;
                BestTotalDelay:=TotalDelay
                end
              end
            end
          else if (Map[Loc1] and fTerrain=fMountains)
            and ((Map[Loc0] and (fRoad or fRR or fCity)=0)
              or (Map[Loc1] and (fRoad or fRR or fCity)=0))
            and (Map[Loc0] and Map[Loc1] and (fRiver or fCanal)=0) then
            begin // mountain delay too complicated for this algorithm
            Arrived[Loc1]:=(Arrived[Loc1] or CompleteFlag) and not NotReachedFlag;
            Adjacent[V8]:=-1;
            end
          else IsComplete:=false;
          end;
        if IsComplete then
          begin
          Arrived[Loc0]:=(Arrived[Loc0] or CompleteFlag) and not NotReachedFlag;
          continue
          end;
        IsComplete:=true;
        for V8:=0 to 7 do
          begin
          Loc1:=Adjacent[V8];
          if Loc1>=0 then
            begin
            ok:=false;
            case CheckStep(MoveStyle, Time0, V8 and 1, ArriveTime, RecoverTurns,
              Map[Loc0], Map[Loc1]) of
              csOk: ok:=true;
              csForbiddenTile:
                ;// !!! don't check moving there again
              csCheckTerritory:
                ok:= RO.Territory[Loc1]=RO.Territory[Loc0];
              end;
            if ok and Pile.TestPut(Loc1, ArriveTime) then
              if ArriveTime<$2000 then Pile.Put(Loc1, ArriveTime)
              else IsComplete:=false
            end
          end;
        if IsComplete then
          Arrived[Loc0]:=(Arrived[Loc0] or CompleteFlag) and not NotReachedFlag;
      until false;
      end;

    inc(TurnCount);
    end;
  Pile.Free;

  if BestLoadLoc>=0 then
    begin
    TransportPlan.LoadLoc:=BestLoadLoc;
    TransportPlan.uixTransport:=ResponsibleTransport[BestLoadLoc];
    TransportAvailable[TransportPlan.uixTransport]:=0;
    TransportPlan.TurnsEmpty:=BestTotalDelay-TurnsAfterLoad[BestLoadLoc];
    TransportPlan.TurnsLoaded:=TurnsAfterLoad[BestLoadLoc];
    TransportPlan.nLoad:=0;
    for tuix:=nSelectedLoad-1 downto 0 do
      if 1 shl (2*tuix) and Arrived[BestLoadLoc]=0 then
        begin
        assert(uixTransportLoad[tuixSelectedLoad[tuix]]=uixSelectedLoad[tuix]);
        TransportPlan.uixLoad[TransportPlan.nLoad]:=uixSelectedLoad[tuix];
        uixTransportLoad[tuixSelectedLoad[tuix]]:=
          uixTransportLoad[nTransportLoad-1];
        dec(nTransportLoad);
        inc(TransportPlan.nLoad)
        end;
    result:=true;
    exit
    end;

  // no loading location for a single of these units -- remove all
  // should be pretty rare case
  for tuix:=nSelectedLoad-1 downto 0 do
    begin
    assert(uixTransportLoad[tuixSelectedLoad[tuix]]=uixSelectedLoad[tuix]);
    uixTransportLoad[tuixSelectedLoad[tuix]]:=
      uixTransportLoad[nTransportLoad-1];
    dec(nTransportLoad);
    end;
  end;
TransportPlan.LoadLoc:=-1;
result:=false;
end;


//------------------------------------------------------------------------------


procedure SetAdvancedness;
var
ad,j,Reduction,AgeThreshold: integer;
known: array[0..nAdv-1] of integer;
  procedure MarkPreqs(ad: integer);
  var
  i: integer;
  begin
  if known[ad]=0 then
    begin
    known[ad]:=1;
    for i:=0 to 2 do
      if AdvPreq[ad,i]>=0 then MarkPreqs(AdvPreq[ad,i]);
    end
  end;
begin
FillChar(Advancedness,SizeOf(Advancedness),0);
for ad:=0 to nAdv-1 do
  begin
  FillChar(known,SizeOf(known),0);
  MarkPreqs(ad);
  for j:=0 to nAdv-1 do if known[j]>0 then inc(Advancedness[ad]);
  end;
AgeThreshold:=Advancedness[adScience];
Reduction:=Advancedness[adScience] div 3;
for ad:=0 to nAdv-5 do
  if Advancedness[ad]>=AgeThreshold then
    dec(Advancedness[ad], Reduction);
AgeThreshold:=Advancedness[adMassProduction];
Reduction:=(Advancedness[adMassProduction]-Advancedness[adScience]) div 3;
for ad:=0 to nAdv-5 do
  if Advancedness[ad]>=AgeThreshold then
    dec(Advancedness[ad], Reduction)
end;


initialization
SetAdvancedness;

end.

