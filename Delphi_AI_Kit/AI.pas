{$INCLUDE switches.pas}
unit AI;        

interface

uses
{$IFDEF DEBUG}SysUtils,{$ENDIF} // necessary for debug exceptions
Protocol, CustomAI, ToolAI;

type
UnitRole= (Roam, Defend);

TAI = class(TToolAI)
  constructor Create(Nation: integer); override;

protected
  procedure DoTurn; override;
  procedure DoNegotiation; override;
  function ChooseResearchAdvance: integer; override;
  function ChooseGovernment: integer; override;
  function WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean; override;

  procedure ProcessSettlers;
  procedure ProcessUnit(uix: integer; Role: UnitRole);
  procedure SetCityProduction;
  end;


implementation

uses
Pile;

const
// fine adjustment
Aggressive=40; // 0 = never attacks, 100 = attacks even with heavy losses
DestroyBonus=30; // percent of building cost


constructor TAI.Create(Nation: integer);
begin
inherited;
end;


//-------------------------------
//            MY TURN
//-------------------------------

procedure TAI.DoTurn;
var
uix: integer;
begin
// correct tax rate if necessary
if RO.Money>RO.nCity*16 then
  ChangeRates(RO.TaxRate-10,0)
else if RO.Money<RO.nCity*8 then
  ChangeRates(RO.TaxRate+10,0);

// better government form available?
if RO.Government<>gAnarchy then
  if IsResearched(adTheRepublic) then
    begin
    if RO.Government<>gRepublic then
      Revolution
    end
  else if IsResearched(adMonarchy) then
    begin
    if RO.Government<>gMonarchy then
      Revolution
    end;

// do combat
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].Loc>=0)
    and not (MyModel[MyUnit[uix].mix].Kind in [mkSettler,mkSlaves]) then
    ProcessUnit(uix,Roam);

ProcessSettlers;

// do discover/patrol

OptimizeCityTiles;
SetCityProduction;
end;


// ProcessSettlers: move settlers, do terrain improvement, found cities
procedure TAI.ProcessSettlers;
var
uix,cix,ecix,Loc,RadiusLoc,TestScore,BestNearCityScore,TerrType,
Special,V21: integer;
Radius: TVicinity21Loc;
ResourceScore, CityScore: array[0..lxmax*lymax-1] of integer;

  procedure ReserveCityRadius(Loc: integer);
  var
  V21,RadiusLoc: integer;
  Radius: TVicinity21Loc;
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do
    begin
    RadiusLoc:=Radius[V21];
    if (RadiusLoc>=0) and (RadiusLoc<MapSize) then
      ResourceScore[RadiusLoc]:=0
    end
  end;

begin
JobAssignment_Initialize;

// rate resources of all tiles
fillchar(ResourceScore, MapSize*sizeof(integer), 0);
for Loc:=0 to MapSize-1 do
  if (Map[Loc] and fRare)=0 then
    if (Map[Loc] and fTerrain)=fGrass then
      if (Map[Loc] and fSpecial)<>0 then
        ResourceScore[Loc]:=3 // plains, 3 points
      else ResourceScore[Loc]:=2 // grassland, 2 points
    else if (Map[Loc] and fSpecial)<>0 then
      ResourceScore[Loc]:=4; // special resource, 4 points
for cix:=0 to RO.nCity-1 do
  if MyCity[cix].Loc>=0 then
    ReserveCityRadius(MyCity[cix].Loc); // these resources already have a city
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].Loc>=0) and (MyUnit[uix].Job=jCity) then
    ReserveCityRadius(MyUnit[uix].Loc); // these resources almost already have a city
for ecix:=0 to RO.nEnemyCity-1 do
  if RO.EnemyCity[ecix].Loc>=0 then
    ReserveCityRadius(RO.EnemyCity[ecix].Loc); // these resources already have an enemy city

// rate possible new cities
fillchar(CityScore, MapSize*sizeof(integer), 0);
for Loc:=0 to MapSize-1 do
  if ((Map[Loc] and fTerrain)=fGrass) and ((Map[Loc] and fRare)=0)
    and ((RO.Territory[Loc]<0) or (RO.Territory[Loc]=me)) then // don't consider founding cities in foreign nation territory
    begin
    TestScore:=0;
    BestNearCityScore:=0;
    V21_to_Loc(Loc,Radius);
    for V21:=1 to 26 do
      begin // sum resource scores in potential city radius
      RadiusLoc:=Radius[V21];
      if (RadiusLoc>=0) and (RadiusLoc<MapSize) then
        begin
        TestScore:=TestScore+ResourceScore[RadiusLoc];
        if CityScore[RadiusLoc]>BestNearCityScore then
          BestNearCityScore:=CityScore[RadiusLoc]
        end
      end;
    if TestScore>=10 then // city is worth founding
      begin
      TestScore:=TestScore shl 8 + ((loc xor me)*4567) mod 251;
        // some unexactness, random but always the same for this tile
      if TestScore>BestNearCityScore then
        begin // better than all other sites in radius
        if BestNearCityScore>0 then // found no other cities in radius
          begin
          for V21:=1 to 26 do
            begin
            RadiusLoc:=Radius[V21];
            if (RadiusLoc>=0) and (RadiusLoc<MapSize) then
              CityScore[RadiusLoc]:=0;
            end;
          end;
        CityScore[Loc]:=TestScore
        end;
      end
    end;
for Loc:=0 to MapSize-1 do
  if CityScore[Loc]>0 then
    JobAssignment_AddJob(Loc, jCity, 10);

// improve terrain
for cix:=0 to RO.nCity-1 do
  with MyCity[cix] do
    if Loc>=0 then
      begin
      V21_to_Loc(Loc,Radius);
      for V21:=1 to 26 do
        if (Tiles and (1 shl V21) and not (1 shl CityOwnTile))<>0 then
          begin // tile is exploited, but not the city own tile -- check if improvable
          RadiusLoc:=Radius[V21];
          assert((RadiusLoc>=0) and (RadiusLoc<MapSize));
          if (RadiusLoc>=0) and (RadiusLoc<MapSize) then
            begin
            TerrType:=Map[RadiusLoc] and fTerrain;
            Special:=Map[RadiusLoc] shr 5 and 3;
            if TerrType>=fGrass then // can't improve water tiles
              if (Terrain[TerrType].IrrEff>0) // terrain is irrigatable
                and not ((RO.Government=gDespotism) and (Terrain[TerrType].FoodRes[Special]>=3)) // improvement makes no sense when limit is depotism
                and ((Map[RadiusLoc] and fTerImp)=0) then // no terrain improvement yet
                JobAssignment_AddJob(RadiusLoc, jIrr, 50) // irrigate!
              else if (Terrain[TerrType].MoveCost=1) // plain terrain
                and ((Map[RadiusLoc] and (fRoad or fRR or fRiver))=0) then // no road or railroad yet, no river
                JobAssignment_AddJob(RadiusLoc, jRoad, 40); // build road (The Wheel trade benefit)
            end
          end;
      end;

// choose all settlers to work
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].Loc>=0)
    and (MyModel[MyUnit[uix].mix].Kind in [mkSettler,mkSlaves]) then
    JobAssignment_AddUnit(uix);

JobAssignment_Go;
end; // ProcessSettlers


// ProcessUnit: execute attack, capture, discover or patrol task according to unit role
procedure TAI.ProcessUnit(uix: integer; Role: UnitRole);
const
DistanceScore=4;
var
BestScore,BestCount,BestLoc,TerrType,TestLoc,NextLoc,TestDistance,Tile,V8,
TestScore,euix,MyDamage,EnemyDamage,TerrOwner,StepSize,OldLoc,
AttackForecast,MoveResult,AttackResult: integer;
Exhausted: boolean;
TestTask, BestTask: (utNone, utAttack, utCapture, utDiscover, utPatrol, utGoHome);
Adjacent: TVicinity8Loc;
AdjacentUnknown: array[0..lxmax*lymax-1] of integer;

begin
Pile.Create(MapSize);
with MyUnit[uix] do
  repeat
    BestCount:=0;
    BestLoc:=0;
    BestScore:=-999999;
    BestTask:=utNone;
    TestTask:=utNone;
    FillChar(AdjacentUnknown,SizeOf(AdjacentUnknown),$FF); // -1, indicates tiles not checked yet
    Pile.Empty;
    Pile.Put(Loc,0); // start search for something to do at current location
    while Pile.Get(TestLoc,TestDistance) do
      begin
      TestScore:=0;
      Tile:=Map[TestLoc];
      AdjacentUnknown[TestLoc]:=0;

      if ((Tile and fUnit)<>0) and ((Tile and fOwned)=0) then
        begin // enemy unit
        Unit_FindEnemyDefender(TestLoc,euix);
        if RO.Treaty[RO.EnemyUn[euix].Owner]<trPeace then
          begin // unfriendly unit -- check attack
          if Unit_AttackForecast(uix,TestLoc,100,AttackForecast) then
            begin // attack possible, but advantageous?
            if AttackForecast>0 then
              begin // enemy unit would be destroyed
              MyDamage:=Health-AttackForecast;
              EnemyDamage:=RO.EnemyUn[euix].Health+DestroyBonus;
              end
            else // own unit would be destroyed
              begin
              MyDamage:=Health+DestroyBonus;
              EnemyDamage:=RO.EnemyUn[euix].Health+AttackForecast;
              end;
            TestScore:=Aggressive*2
              *(EnemyDamage*RO.EnemyModel[RO.EnemyUn[euix].emix].Cost)
              div (MyDamage*MyModel[mix].Cost);
            if TestScore<=100 then TestScore:=0 // own losses exceed enemy losses, no good
            else
              begin
              TestScore:=(TestScore-100) div 10 +30;
              TestTask:=utAttack
              end
            end
          end
        end // enemy unit

      else if ((Tile and fCity)<>0) and ((Tile and fOwned)=0) then
        begin // enemy city, empty or unobserved
        if (MyModel[mix].Domain=dGround) // ships of this AI have no long-range guns, so don't try to attack cities with them
          and ((RO.Territory[TestLoc]<0) // happens only for unobserved cities of extinct tribes, new owner unknown
          or (RO.Treaty[RO.Territory[TestLoc]]<trPeace)) then
          begin // unfriendly city -- check attack/capture
          if (Tile and fObserved)<>0 then
            begin // observed and no unit present -- city is undefended, capture!
            TestScore:=40;
            TestTask:=utCapture
            end
          else if Role=Roam then
            begin // unobserved city, possibly defended -- go for attack
            TestScore:=30;
            TestTask:=utPatrol
            end
          end
        end // enemy city, empty or unobserved

      else
        begin // no enemy city or unit here
        // add surrounding tiles to queue, but only if there's a chance to beat BestScore
        if 50-DistanceScore*(TestDistance+1)>=BestScore then // assume a score of 50 is the best achievable
          begin
          V8_to_Loc(TestLoc,Adjacent);
          for V8:=0 to 7 do
            begin
            NextLoc:=Adjacent[V8];
            if (NextLoc>=0) and (NextLoc<MapSize)
              and (AdjacentUnknown[NextLoc]<0) then // tile not checked yet
              begin
              TerrType:=Map[NextLoc] and fTerrain;
              if TerrType=fUNKNOWN then
                inc(AdjacentUnknown[TestLoc])
              else
                begin
                case MyModel[mix].Domain of
                  dGround:
                    begin
                    TerrOwner:=RO.Territory[NextLoc];
                    if (TerrType>=fGrass) and (TerrType<>fArctic) // terrain can be walked
                      and ((TerrOwner<0) or (TerrOwner=me) or (RO.Treaty[TerrOwner]<trPeace)) // no peace treaty violated
                      and (((Map[NextLoc] and (fUnit or fCity))<>0)
                        or (Map[TestLoc] and Map[NextLoc] and fInEnemyZoC=0)) then // no ZoC violated
                      begin // yes, consider walking this tile
                      if TerrType=fMountains then
                        StepSize:=2 // mountains cause delay
                      else StepSize:=1
                      end
                    else StepSize:=0 // no, don't walk here
                    end;
                  dSea:
                    if TerrType=fShore then // ships of this AI can only move along shore
                      StepSize:=1
                    else StepSize:=0;
                  dAir:
                    StepSize:=1;
                  else
                    StepSize:=0;
                  end;
                if StepSize>0 then
                  Pile.Put(NextLoc,TestDistance+StepSize)
                end
              end;
            end;
          end;
        if Role=Defend then TestScore:=0 // don't discover/patrol
        else if AdjacentUnknown[TestLoc]>0 then
          begin
          TestScore:=20+AdjacentUnknown[TestLoc];
          TestTask:=utDiscover
          end
        else
          begin
          TestScore:=(RO.Turn-RO.MapObservedLast[TestLoc]) div 10;
          TestTask:=utPatrol
          end
        end; // no enemy city or unit here

      if TestScore>0 then
        begin
        TestScore:=TestScore-DistanceScore*TestDistance;
        if TestScore>BestScore then
          BestCount:=0;
        if TestScore>=BestScore then
          begin
          inc(BestCount);
          if random(BestCount)=0 then
            begin
            BestScore:=TestScore;
            BestLoc:=TestLoc;
            BestTask:=TestTask;
            end
          end;
        end
      end;

    if (BestTask=utNone) and ((Map[Loc] and fCity)=0) then
      begin // nothing to do, move home
      if Home>=0 then
        BestLoc:=MyCity[Home].Loc
      else BestLoc:=maNextCity;
      BestTask:=utGoHome;
      end;
    if BestTask<>utNone then
      begin // attack/capture/discover/patrol task found, execute it
      OldLoc:=Loc;
      MoveResult:=Unit_Move(uix,BestLoc);
      Exhausted:= (Loc=OldLoc)
        or ((MoveResult and (rMoreTurns or rUnitRemoved))<>0);
      if (BestTask=utAttack) and ((MoveResult and rLocationReached)<>0) then
        if Movement<100 then
          Exhausted:=true
        else
          begin
          AttackResult:=Unit_Attack(uix,BestLoc);
          Exhausted:= ((AttackResult and rExecuted)=0)
            or ((AttackResult and rUnitRemoved)<>0);
          end;
      if not Exhausted then
        Exhausted:= (Movement<100) and ((Map[Loc] and (fRoad or fRR or fRiver or fCity))=0); // no road, too few movement points for further movement
      end
    else Exhausted:=true;
  until Exhausted;
Pile.Free;
end; // ProcessUnit


// SetCityProduction: choose production of each city
procedure TAI.SetCityProduction;
var
cix,mix,mixSettler,mixShip,mixArmy,V8,NewImprovement,count,wix,AdjacentLoc: integer;
IsPort: boolean;
Adjacent: TVicinity8Loc;
Report: TCityReport;

  procedure TryBuild(Improvement: integer);
  begin
  if (NewImprovement<0) // already improvement of higher priority found
    and (MyCity[cix].Built[Improvement]=0) // not built yet
    and City_Improvable(cix, Improvement) then
    NewImprovement:=Improvement;
  end;

begin
// only produce newest models
mixSettler:=-1;
mixArmy:=-1;
mixShip:=-1;
for mix:=0 to RO.nModel-1 do
  with MyModel[mix] do
    if Kind=mkSettler then
      mixSettler:=mix
    else if (Domain=dGround) and (Kind<mkSpecial_TownGuard) then
      mixArmy:=mix
    else if Domain=dSea then
      mixShip:=mix;

for cix:=0 to RO.nCity-1 do
  with MyCity[cix] do
    if (RO.Turn=0) or ((Flags and chProduction)<>0) // city production complete
      or not City_HasProject(cix) then
      begin // check production
      IsPort:=false;
      V8_to_Loc(Loc,Adjacent);
      for v8:=0 to 7 do
        begin
        AdjacentLoc:=Adjacent[V8];
        if (AdjacentLoc>=0) and (AdjacentLoc<MapSize)
          and ((Map[AdjacentLoc] and fTerrain)=fShore) then
          IsPort:=true; // shore tile at adjacent location -- city is port!
        end;
      City_GetReport(cix, Report);

      if (Report.Support=0)
        or (SupportFree[RO.Government]<2) and (Report.Support<Report.ProdRep div 2) then
        begin // enough material to support more units
        if (RO.Turn>4)
          and ((Report.Eaten-Size*2) div SettlerFood[RO.Government]<Size div 4) then
          // less than 1 settler per 4 citizens -- produce more!
          City_StartUnitProduction(cix, mixSettler)
        else if IsPort and (mixShip>=0) and (random(2)=0) then
          City_StartUnitProduction(cix, mixShip)
        else City_StartUnitProduction(cix, mixArmy)
        end
      else
        begin // check for building a city improvement
        NewImprovement:=-1;
        if Built[imPalace]+Built[imCourt]+Built[imTownHall]=0 then
          begin
          TryBuild(imCourt);
          TryBuild(imTownHall);
          end;
        if Report.Trade-Report.Corruption>=11 then
          TryBuild(imLibrary);
        if Report.Trade-Report.Corruption>=11 then
          TryBuild(imMarket);
        if Size>=9 then
          TryBuild(imHighways);
        if (RO.Government<>gDespotism) and (Size>=4) then
          TryBuild(imTemple);
        if (RO.Government<>gDespotism) and (Size>=6) then
          TryBuild(imTheater);
        if (RO.Government<>gDespotism) and (Size>=8) then
          TryBuild(imAqueduct);
        if (Report.ProdRep>=4) or (RO.nCity=1) then
          TryBuild(imBarracks);
        TryBuild(imWalls);
        if IsPort then
          TryBuild(imCoastalFort);
        if NewImprovement<0 then
          begin // nothing to produce -- check for building a wonder
          count:=0;
          for wix:=0 to nImp-1 do
            if (Imp[wix].Kind=ikWonder) and (RO.Wonder[wix].CityID=-1) // not built yet
              and ((Report.ProdRep-Report.Support)*40>=Imp[wix].Cost) // takes less than 40 turns to produce
              and City_Improvable(cix, wix) then
              begin
              inc(count);
              if random(count)=0 then
                NewImprovement:=wix // yes, build this wonder!
              end;
          end;
        if NewImprovement>=0 then
          City_StartImprovement(cix, NewImprovement)
        else if City_HasProject(cix) then
          City_StopProduction(cix); // nothing to produce
        end
      end // check production
end; // SetCityProduction


function TAI.ChooseResearchAdvance: integer;
var
mix: integer;
begin
if not IsResearched(adWheel) then
  begin
  result:=adWheel;
  exit
  end // research the wheel first
else if not IsResearched(adWarriorCode) then
  begin
  result:=adWarriorCode;
  exit
  end // research warrior code first
else if not IsResearched(adHorsebackRiding) then
  begin
  result:=adHorsebackRiding;
  exit
  end; // research horseback riding first

result:=-1; // random advance
if random(10)=0 then
  begin // check military research
  result:=adMilitary;
  if IsResearched(adMapMaking) and (random(2)=0) then
    begin // try to develop new ship
    PrepareNewModel(dSea);
    SetNewModelFeature(mcDefense, 3);
    SetNewModelFeature(mcOffense, RO.DevModel.MaxWeight-3);
    end
  else
    begin // try to develop new ground unit
    PrepareNewModel(dGround);
    SetNewModelFeature(mcDefense, 1);
    SetNewModelFeature(mcOffense, RO.DevModel.MaxWeight-4);
    SetNewModelFeature(mcMob, 2);
    end;

  // don't develop model twice
  for mix:=0 to RO.nModel-1 do
    if (RO.DevModel.Domain=MyModel[mix].Domain)
      and (RO.DevModel.Attack=MyModel[mix].Attack)
      and (RO.DevModel.Defense=MyModel[mix].Defense) then
      result:=-1; // already have this model
  end;
end; // ChooseResearchAdvance


function TAI.ChooseGovernment: integer;
begin
if IsResearched(adTheRepublic) then
  result:=gRepublic
else if IsResearched(adMonarchy) then
  result:=gMonarchy
else result:=gDespotism
end;


//-------------------------------
//           DIPLOMACY
//-------------------------------

function TAI.WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean;
begin
result:= (NegoTime=EnemyCalled) // always accept contact
  or (NegoTime=EndOfTurn) and (RO.Turn mod 20=Nation+me) // ask for contact only once in 20 turns
end;

procedure TAI.DoNegotiation;
begin
if (RO.Treaty[Opponent]<trPeace) and Odd(me+Opponent) then // make peace with some random nations
  if (OppoAction=scDipOffer) and (OppoOffer.nCost=0) and (OppoOffer.nDeliver=1)
    and (OppoOffer.Price[0]=opTreaty+trPeace) then
    MyAction:=scDipAccept // accept peace
  else if OppoAction=scDipStart then
    begin
    MyOffer.nCost:=0;
    MyOffer.nDeliver:=1;
    MyOffer.Price[0]:=opTreaty+trPeace; // offer peace in exchange of nothing
    MyAction:=scDipOffer;
    end
end;

end.

