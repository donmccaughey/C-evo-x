{$INCLUDE switches.pas}
unit Barbarina;

interface

uses
{$IFDEF DEBUG}SysUtils,{$ENDIF} // necessary for debug exceptions
{$IFDEF DEBUG}Names,{$ENDIF}
Protocol, ToolAI, CustomAI;


const
nModelCategory=4;
ctGroundSlow=0; ctGroundFast=1; ctSeaTrans=2; ctSeaArt=3;

maxCOD=256;

maxModern=16;
  // maximum number of modern resources of one type being managed
  // (for designed maps only, number is 2 in standard game)


type
TColonyShipPlan = array[0..nShipPart-1] of record
  cixProducing: integer;
  LocResource: array[0..maxModern-1] of integer;
  nLocResource: integer;
  LocFoundCity: array[0..maxModern-1] of integer;
  nLocFoundCity: integer;
  end;

TBarbarina = class(TToolAI)
  constructor Create(Nation: integer); override;

protected
  ColonyShipPlan: TColonyShipPlan;
  function Barbarina_GoHidden: boolean; // whether we should prepare for barbarina mode
  function Barbarina_Go: boolean; // whether we should switch to barbarina mode now
  procedure Barbarina_DoTurn;
  procedure Barbarina_SetCityProduction;
  function Barbarina_ChooseResearchAdvance: integer;
  function Barbarina_WantCheckNegotiation(Nation: integer): boolean;
  procedure Barbarina_DoCheckNegotiation;
  function Barbarina_WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean;
  procedure Barbarina_DoNegotiation;
  procedure MakeColonyShipPlan;

private
  TurnOfMapAnalysis, Neighbours: integer;
  ContinentPresence: array[0..maxCOD-1] of integer;
  OceanPresence: array[0..maxCOD-1] of integer;
  ContinentSize: array[0..maxCOD-1] of integer;
  OceanSize: array[0..maxCOD-1] of integer;
  mixBest: array[0..nModelCategory-1] of integer;
  NegoCause: (CancelTreaty);
  function IsModelAvailable(rmix: integer): boolean;
  procedure FindBestModels;
  procedure AnalyzeMap;
  procedure RateAttack(uix: integer);
  function DoAttack(uix,AttackLoc: integer): boolean;
  function ProcessMove(uix: integer): boolean;
  procedure AttackAndPatrol;
  end;


implementation

uses
Pile;

type
TResearchModel=record
  Category,Domain,Weight,adStop,FutMStrength: integer;
  Upgrades: cardinal;
  Cap: array [0..nFeature-1] of integer;
  end;

const
//UnitKind
ukSlow=$01; ukFast=$02;

neumax=4096;
mixTownGuard=2;

PresenceUnknown=$10000;

WonderProductionThreshold=15;
WonderInclination=24.0; // higher value means lower probability of building wonder
ReduceDefense=16; // if this is x, 1/x of all units is used to defend cities

nResearchOrder=40;
ResearchOrder: array[0..nResearchOrder-1] of integer=
(adBronzeWorking,-adMapMaking,adChivalry,adMonotheism,adIronWorking,
adGunPowder,adTheology,adConstruction,adCodeOfLaws,-adEngineering,-adSeafaring,
-adNavigation,adMetallurgy,adBallistics,adScience,adExplosives,
adTactics,adSteel,-adSteamEngine,-adAmphibiousWarfare,-adMagnetism,adRadio,
adAutomobile,adMobileWarfare,adRailroad,adCommunism,adDemocracy,
adTheCorporation,adMassProduction,adIndustrialization,adRobotics,adComposites,
adTheLaser,adFlight,adAdvancedFlight,adSpaceFlight,
adSyntheticFood,adTransstellarColonization,adElectronics,adSmartWeapons);

nResearchModel=16;
ResearchModel: array[0..nResearchModel-1] of TResearchModel=
//       Wea Arm Mob Sea Car Tur Bom Fue Air Nav Rad Sub Art Alp Sup Ove Air Spy SE  NP  Jet Ste Fan Fir Wil Aca Lin
((Category:ctGroundSlow; Domain:dGround;Weight: 7;adStop:adIronWorking;Upgrades:$0003;
    Cap:(  3,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundFast; Domain:dGround;Weight: 7;adStop:adIronWorking;Upgrades:$0003;
    Cap:(  3,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundSlow; Domain:dGround;Weight: 7;adStop:adExplosives;Upgrades:$003F;
    Cap:(  3,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundFast; Domain:dGround;Weight: 7;adStop:adExplosives;Upgrades:$003F;
    Cap:(  3,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctSeaTrans;   Domain:dSea;   Weight: 7;adStop:adExplosives;Upgrades:$000F;
    Cap:(  0,  3,  0,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctSeaArt;     Domain:dSea;   Weight: 7;adStop:adExplosives;Upgrades:$000F;
    Cap:(  4,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundSlow; Domain:dGround;Weight: 7;adStop:adAutomobile;Upgrades:$00FF;
    Cap:(  1,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundFast; Domain:dGround;Weight: 7;adStop:adAutomobile;Upgrades:$00FF;
    Cap:(  3,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctSeaTrans;   Domain:dSea;   Weight: 9;adStop:-1;Upgrades:$00FF;
    Cap:(  0,  4,  0,  2,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctSeaArt;     Domain:dSea;   Weight: 9;adStop:-1;Upgrades:$00FF;
    Cap:(  5,  3,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundSlow; Domain:dGround;Weight: 10;adStop:adCommunism;Upgrades:$05FF;
    Cap:(  3,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundFast; Domain:dGround;Weight: 10;adStop:adCommunism;Upgrades:$05FF;
    Cap:(  5,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0)),
 (Category:ctGroundSlow; Domain:dGround;Weight: 10;adStop:adComposites;Upgrades:$07FF;
    Cap:(  3,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1)),
 (Category:ctGroundFast; Domain:dGround;Weight: 10;adStop:adComposites;Upgrades:$07FF;
    Cap:(  5,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1)),
 (Category:ctGroundSlow; Domain:dGround;Weight: 10;adStop:-1;Upgrades:$3FFF;
    Cap:(  3,  3,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1)),
 (Category:ctGroundFast; Domain:dGround;Weight: 10;adStop:-1;Upgrades:$3FFF;
    Cap:(  5,  1,  2,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  0,  0,  0,  1)));
EntryModel_Base=1;
EntryModel_GunPowder=3;
EntryModel_MassProduction=13;


var
Moved: array[0..numax-1] of boolean;
UnitPresence: array[0..lxmax*lymax-1] of byte;
euixMap: array[0..lxmax*lymax-1] of smallint;
uixAttack: array[0..neumax-1] of smallint;
AttackScore: array[0..neumax-1] of integer;

constructor TBarbarina.Create(Nation: integer);
begin
inherited;
TurnOfMapAnalysis:=-1;
end;

// whether one of the existing models matches a specific research model
function TBarbarina.IsModelAvailable(rmix: integer): boolean;
var
i,mix,MStrength: integer;
begin
result:=false;
with ResearchModel[rmix] do
  begin
  MStrength:=CurrentMStrength(Domain);
  for mix:=3 to RO.nModel-1 do
    if ((MyModel[mix].kind=mkSelfDeveloped) or (MyModel[mix].kind=mkEnemyDeveloped))
      and (MyModel[mix].Domain=Domain)
      and (Upgrades and not MyModel[mix].Upgrades=0) then
      begin
      result:= MStrength<(MyModel[mix].MStrength*3) div 2; // for future techs: don't count model available if 50% stronger possible
      for i:=0 to nFeature-1 do if MyModel[mix].Cap[i]<Cap[i] then
        begin result:=false; break end;
      if result then break;
      end;
  end
end;

function TBarbarina.Barbarina_GoHidden: boolean;
var
V21,Loc1,cix: integer;
Radius: TVicinity21Loc;
begin
if IsResearched(adMassProduction) then
  begin
  result:=true;
  for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
    begin // search for modern resource
    V21_to_Loc(Loc, Radius);
    for V21:=1 to 26 do
      begin
      Loc1:=Radius[V21];
      if (Loc1>=0) and (RO.Map[Loc1] and fModern<>0) then
        result:=false;
      end
    end
  end
else if IsResearched(adGunPowder) then
  result:=(RO.Tech[adTheRepublic]<tsSeen) and IsResearched(adTheology)
else result:=false;
end;

function TBarbarina.Barbarina_Go: boolean;
begin
if IsResearched(adMassProduction) then
  result:= IsResearched(adTheology)
    and IsModelAvailable(EntryModel_MassProduction)
else if IsResearched(adGunPowder) then
  result:= IsResearched(adTheology) and IsResearched(adMapMaking)
    and IsModelAvailable(EntryModel_GunPowder)
else
  begin
  result:=(RO.nCity>=3) and IsResearched(adMapMaking)
    and IsModelAvailable(EntryModel_Base);
  exit
  end;  
result:=result and ((RO.nUn>=RO.nCity*3) or (RO.Wonder[woZeus].EffectiveOwner=me));
end;

procedure TBarbarina.AnalyzeMap;
var
Loc,Loc1,V8,f1,p1,cix: integer;
Adjacent: TVicinity8Loc;
begin
if TurnOfMapAnalysis=RO.Turn then exit;

// inherited AnalyzeMap;

// collect nation presence information for continents and oceans
fillchar(ContinentPresence, sizeof(ContinentPresence), 0);
fillchar(OceanPresence, sizeof(OceanPresence), 0);
fillchar(ContinentSize, sizeof(ContinentSize), 0);
fillchar(OceanSize, sizeof(OceanSize), 0);
for Loc:=0 to MapSize-1 do
  begin
  f1:=Formation[Loc];
  case f1 of
    0..maxCOD-1:
      begin
      p1:=RO.Territory[Loc];
      if p1>=0 then
        if Map[Loc] and fTerrain>=fGrass then
          begin
          inc(ContinentSize[f1]);
          ContinentPresence[f1]:=ContinentPresence[f1] or (1 shl p1)
          end
        else
          begin
          inc(OceanSize[f1]);
          OceanPresence[f1]:=OceanPresence[f1] or (1 shl p1);
          end
      end;
    nfUndiscovered:
      begin // adjacent formations are not completely discovered
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if Loc1>=0 then
          begin
          f1:=Formation[Loc1];
          if (f1>=0) and (f1<maxCOD) then
            if Map[Loc1] and fTerrain>=fGrass then
              ContinentPresence[f1]:=ContinentPresence[f1] or PresenceUnknown
            else OceanPresence[f1]:=OceanPresence[f1] or PresenceUnknown
          end
        end
      end;
    nfPeace:
      begin // nation present in adjacent formations
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if Loc1>=0 then
          begin
          f1:=Formation[Loc1];
          if (f1>=0) and (f1<maxCOD) then
            if Map[Loc1] and fTerrain>=fGrass then
              ContinentPresence[f1]:=ContinentPresence[f1]
                or (1 shl RO.Territory[Loc])
            else OceanPresence[f1]:=OceanPresence[f1]
              or (1 shl RO.Territory[Loc])
          end
        end
      end;
    end;
  end;

Neighbours:=0;
for cix:=0 to RO.nCity-1 do with MyCity[cix] do
  if (Loc>=0) and (Formation[Loc]>=0) and (Formation[Loc]<maxCOD) then
    Neighbours:=Neighbours or ContinentPresence[Formation[Loc]];
Neighbours:= Neighbours and not PresenceUnknown;

TurnOfMapAnalysis:=RO.Turn;
end;

procedure TBarbarina.FindBestModels;
var
i,mix,rmix,cat: integer;
begin
for i:=0 to nModelCategory-1 do mixBest[i]:=-1;
for rmix:=nResearchModel-1 downto 0 do with ResearchModel[rmix] do
  if mixBest[Category]<0 then
      for mix:=3 to RO.nModel-1 do
        if (MyModel[mix].Domain=Domain)
          and (Upgrades and not MyModel[mix].Upgrades=0) then
          begin
          mixBest[Category]:=mix;
          for i:=0 to nFeature-1 do if MyModel[mix].Cap[i]<Cap[i] then
            begin mixBest[Category]:=-1; break end;
          if mixBest[Category]>=0 then break;
          end;
for mix:=3 to RO.nModel-1 do with MyModel[mix] do if Kind<=mkEnemyDeveloped then
  begin
  cat:=-1;
  case Domain of
    dGround:
      if Speed>=250 then cat:=ctGroundFast
      else cat:=ctGroundSlow;
    dSea:
      if Cap[mcSeaTrans]>0 then cat:=ctSeaTrans
      else if Cap[mcArtillery]>0 then cat:=ctSeaArt;
    end;
  if (cat>=0) and (mix<>mixBest[cat])
    and ((mixBest[cat]<0) or (Weight*MStrength
    >MyModel[mixBest[cat]].Weight+MyModel[mixBest[cat]].MStrength)) then
    mixBest[cat]:=mix;
  end;
if (mixBest[ctSeaTrans]<0) and not IsResearched(adExplosives) then // longboat?
  for mix:=3 to RO.nModel-1 do if MyModel[mix].Cap[mcSeaTrans]>0 then
    begin mixBest[ctSeaTrans]:=mix; break end;
end;

procedure TBarbarina.Barbarina_DoTurn;
begin
if (RO.Government in [gRepublic,gDemocracy,gFuture])
  or (RO.Government<>gFundamentalism) and (RO.Government<>gAnarchy)
  and IsResearched(adTheology) then
  Revolution;

AnalyzeMap;

FindBestModels;

AttackAndPatrol;
end;

// find one unit to destroy each known enemy unit, result in uixAttack
procedure TBarbarina.RateAttack(uix: integer);
var
MoveStyle,TestLoc,TestTime,NextLoc,NextTime,V8,RemHealth,RecoverTurns,
  Score,BestScore,euixBest,uixOld: integer;
NextTile: cardinal;
Adjacent: TVicinity8Loc;
Defense: ^TUnitInfo;
Reached: array[0..lxmax*lymax-1] of boolean;
begin
with MyUnit[uix] do if Movement>0 then
  begin
  BestScore:=0;
  euixBest:=0;
  fillchar(Reached, MapSize, false);
  MoveStyle:=GetMyMoveStyle(mix, Health);
  Pile.Create(MapSize);
  Pile.Put(Loc, $800-Movement);
  while Pile.Get(TestLoc, TestTime) do
    begin
    Reached[TestLoc]:=true;
    V8_to_Loc(TestLoc, Adjacent);
    for V8:=0 to 7 do
      begin
      NextLoc:=Adjacent[V8];
      if (NextLoc>=0) and not Reached[NextLoc] then
        begin
        NextTile:=Map[NextLoc];
        if euixMap[NextLoc]>=0 then
          begin // check attack
          Defense:=@RO.EnemyUn[euixMap[NextLoc]];
          if Unit_AttackForecast(uix, NextLoc, $800-TestTime, RemHealth) then
            begin
            if RemHealth<=0 then // send unit into death?
              begin
              Score:=0;
              if ($800-TestTime>=100)
                and ((MyModel[mix].Domain=dGround) and (NextTile and fTerrain>=fGrass)
                  or (MyModel[mix].Domain=dSea) and (NextTile and fTerrain<fGrass))
                and (MyModel[mix].Attack>MyModel[mix].Defense) then
                begin
                Score:=(Defense.Health+RemHealth)
                  *RO.EnemyModel[Defense.emix].Cost*2 div MyModel[mix].Cost;
                if NextTile and fCity<>0 then
                  Score:=Score*4;
                end
              end
            else Score:=RO.EnemyModel[Defense.emix].Cost*25-(Health-RemHealth)*MyModel[mix].Cost shr 4;
            if (Score>BestScore) and (Score>AttackScore[euixMap[NextLoc]]) then
              begin
              BestScore:=Score;
              euixBest:=euixMap[NextLoc]
              end
            end
          end
        else if (NextTile and (fUnit or fCity)=0)
          or (NextTile and fOwned<>0) then
          case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime,
            RecoverTurns, Map[TestLoc], NextTile, true) of
            csOk:
              if NextTime<$800 then
                Pile.Put(NextLoc, NextTime);
            csForbiddenTile:
              Reached[NextLoc]:=true; // don't check moving there again
            csCheckTerritory:
              if (NextTime<$800) and (RO.Territory[NextLoc]=RO.Territory[TestLoc]) then
                Pile.Put(NextLoc, NextTime);
            end
        end
      end;
    end;
  Pile.Free;

  if BestScore>0 then
    begin
    uixOld:=uixAttack[euixBest];
    AttackScore[euixBest]:=BestScore;
    uixAttack[euixBest]:=uix;
    if uixOld>=0 then
      RateAttack(uixOld);
    end
  end
end;

function TBarbarina.DoAttack(uix,AttackLoc: integer): boolean;
// AttackLoc=maNextCity means bombard only
var
MoveResult,Kind,Temp,MoveStyle,TestLoc,TestTime,NextLoc,NextTime,V8,
  RecoverTurns,ecix: integer;
NextTile: cardinal;
AttackPositionReached, IsBombardment: boolean;
Adjacent: TVicinity8Loc;
PreLoc: array[0..lxmax*lymax-1] of word;
Reached: array[0..lxmax*lymax-1] of boolean;
begin
result:=false;
IsBombardment:= AttackLoc=maNextCity;
with MyUnit[uix] do
  begin
  if (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0) then
    if MyModel[mix].Speed>=250 then Kind:=ukFast
    else Kind:=ukSlow
  else Kind:=0;
  fillchar(Reached, MapSize, false);
  AttackPositionReached:=false;
  MoveStyle:=GetMyMoveStyle(mix, Health);
  Pile.Create(MapSize);
  Pile.Put(Loc, $800-Movement);
  while Pile.Get(TestLoc, TestTime) do
    begin
    if (TestTime>=$800) or (AttackLoc=maNextCity) and (TestTime>$800-100) then
      break;
    Reached[TestLoc]:=true;
    V8_to_Loc(TestLoc, Adjacent);
    for V8:=0 to 7 do
      begin
      NextLoc:=Adjacent[V8];
      if NextLoc>=0 then
        begin
        if IsBombardment and (Map[NextLoc] and
          (fCity or fUnit or fOwned or fObserved)=fCity or fObserved)
          and (RO.Treaty[RO.Territory[NextLoc]]<trPeace) then
          begin
          City_FindEnemyCity(NextLoc, ecix);
          assert(ecix>=0);
          with RO.EnemyCity[ecix] do
            if (Size>2) and (Flags and ciCoastalFort=0) then
              AttackLoc:=NextLoc
          end;
        if (NextLoc=AttackLoc)
          and ((MyModel[mix].Domain<>dSea) or (Map[TestLoc] and fTerrain<fGrass)) then
            // ships can only attack from water
          begin AttackPositionReached:=true; break end
        else if not Reached[NextLoc] then
          begin
          NextTile:=Map[NextLoc];
          if (NextTile and (fUnit or fCity)=0)
            or (NextTile and fOwned<>0) then
            case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime,
              RecoverTurns, Map[TestLoc], NextTile, true) of
              csOk:
                if Pile.Put(NextLoc, NextTime) then
                  PreLoc[NextLoc]:=TestLoc;
              csForbiddenTile:
                Reached[NextLoc]:=true; // don't check moving there again
              csCheckTerritory:
                if RO.Territory[NextLoc]=RO.Territory[TestLoc] then
                  if Pile.Put(NextLoc, NextTime) then
                    PreLoc[NextLoc]:=TestLoc;
              end
          end
        end
      end;
    if AttackPositionReached then
      begin
      PreLoc[NextLoc]:=TestLoc;
      break
      end
    end;
  Pile.Free;
  if not AttackPositionReached then exit;

  TestLoc:=AttackLoc;
  NextLoc:=PreLoc[TestLoc];
  while TestLoc<>Loc do
    begin
    Temp:=TestLoc;
    TestLoc:=NextLoc;
    NextLoc:=PreLoc[TestLoc];
    PreLoc[TestLoc]:=Temp;
    end;

  UnitPresence[Loc]:=UnitPresence[Loc] and not Kind; // assume unit was only one of kind here
  repeat
    NextLoc:=PreLoc[Loc];
    MoveResult:=Unit_Step(uix, NextLoc);
  until (NextLoc=AttackLoc) or (MoveResult and rExecuted=0)
    or (MoveResult and rUnitRemoved<>0);
  result:= (NextLoc=AttackLoc) and (MoveResult and rExecuted<>0);

  if IsBombardment and result then
    begin
    City_FindEnemyCity(AttackLoc, ecix);
    assert(ecix>=0);
    while (Movement>=100) and (RO.EnemyCity[ecix].Size>2) do
      Unit_Step(uix, AttackLoc);
    end;

  if Loc>=0 then
    UnitPresence[Loc]:=UnitPresence[Loc] or Kind;
  end
end;

function TBarbarina.ProcessMove(uix: integer): boolean;
// return true if no new enemy spotted
const
DistanceScore=4;
var
PatrolScore,BestCount,PatrolLoc,TestLoc,NextLoc,TestTime,V8,
  TestScore,MoveResult,MoveStyle,NextTime,TerrOwner,Kind,Temp,RecoverTurns,
  MaxScore: integer;
Tile,NextTile: cardinal;
CaptureOnly,PeaceBorder, done, NextToEnemyCity: boolean;
Adjacent: TVicinity8Loc;
AdjacentUnknown: array[0..lxmax*lymax-1] of shortint;
PreLoc: array[0..lxmax*lymax-1] of word;
MoreTurn: array[0..lxmax*lymax-1] of byte;

begin
result:=true;
done:=false;
while not done do with MyUnit[uix] do
  begin
  if (MyModel[mix].Domain=dSea) and (Health<100)
    and ((Health<34) or (MyModel[mix].Cap[mcSeaTrans]>0)) then
    begin
    if Map[Loc] and fCity=0 then
      Unit_MoveEx(uix,maNextCity);
    exit;
    end;

  if (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0) then
    if MyModel[mix].Speed>=250 then Kind:=ukFast
    else Kind:=ukSlow
  else Kind:=0;
  CaptureOnly:=(Health<100)
    and ((Map[Loc] and fCity<>0)
    or ((100-Health)*Terrain[Map[Loc] and fTerrain].Defense>60)
      and not (Map[Loc] and fTerrain in [fOcean, fShore, fArctic, fDesert]));
  MoveStyle:=GetMyMoveStyle(mix, Health);

  if MyModel[mix].Attack>0 then MaxScore:=$400
  else MaxScore:=$400-32+5;
  PatrolScore:=-999999;
  PatrolLoc:=-1;
  FillChar(AdjacentUnknown,MapSize,$FF); // -1, indicates tiles not checked yet
  Pile.Create(MapSize);
  Pile.Put(Loc, $800-Movement);
  while Pile.Get(TestLoc,TestTime) do
    begin
    if (MaxScore*$1000-DistanceScore*TestTime<=PatrolScore) // assume a score of $400 is the best achievable
      or CaptureOnly and (TestTime>=$1000) then
      break;

    TestScore:=0;
    Tile:=Map[TestLoc];
    assert(Tile and (fUnit or fOwned)<>fUnit);
    TerrOwner:=RO.Territory[TestLoc];
    AdjacentUnknown[TestLoc]:=0;
    PeaceBorder:=false;
    NextToEnemyCity:=false;

    if ((Tile and fCity)<>0) and ((Tile and fOwned)=0) then
      begin
      if (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0)
        and ((TerrOwner<0) // happens only for unobserved cities of extinct tribes, new owner unknown
          or (RO.Treaty[TerrOwner]<trPeace)) then
        if (Tile and fObserved<>0) and (Tile and fUnit=0) then
          TestScore:=$400 // unfriendly undefended city -- capture!
        else TestScore:=$400-14 // unfriendly city, not observed or defended
      end

    else
      begin // no enemy city or unit here
      V8_to_Loc(TestLoc,Adjacent);
      for V8:=0 to 7 do
        begin
        NextLoc:=Adjacent[V8];
        if (NextLoc>=0) and (AdjacentUnknown[NextLoc]<0) then
          begin
          NextTile:=Map[NextLoc];
          if NextTile and fTerrain=fUNKNOWN then
            inc(AdjacentUnknown[TestLoc])
          else if NextTile and fTerrain=fArctic then
          else if NextTile and (fCity or fUnit or fOwned or fObserved)=
            fCity or fUnit or fObserved then
            NextToEnemyCity:=true
          else case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime, RecoverTurns, Tile, NextTile, true) of
            csOk:
{              if (NextTime and $7FFFF000=TestTime and $7FFFF000)
                or (UnitPresence[TestLoc] and Kind=0)
                or (Tile and fCity<>0)
                or (Tile and fTerImp=tiFort) or (Tile and fTerImp=tiBase) then}
                begin
                if Pile.Put(NextLoc, NextTime+RecoverTurns*$1000) then
                  begin
                  PreLoc[NextLoc]:=TestLoc;
                  MoreTurn[NextLoc]:=NextTime shr 12 and $FFF;
                  end
                end;
            csForbiddenTile:
              begin
              AdjacentUnknown[NextLoc]:=0; // don't check moving there again
              if NextTile and fPeace<>0 then PeaceBorder:=true;
              end;
            csCheckTerritory:
              if RO.Territory[NextLoc]=TerrOwner then
                begin
                if Pile.Put(NextLoc, NextTime+RecoverTurns*$1000) then
                  begin
                  PreLoc[NextLoc]:=TestLoc;
                  MoreTurn[NextLoc]:=NextTime shr 12 and $FFF;
                  end
                end
              else PeaceBorder:=true;
            end
          end
        end;
      if not CaptureOnly then
        if NextToEnemyCity and (MyModel[mix].Attack>0)
          and (MyModel[mix].Domain=dGround) then
          TestScore:=$400-14
        else if AdjacentUnknown[TestLoc]>0 then
          if PeaceBorder or (TerrOwner>=0) and (TerrOwner<>me)
            and (RO.Treaty[TerrOwner]<trPeace) then
            TestScore:=$400-32+AdjacentUnknown[TestLoc]
          else TestScore:=$400-64+AdjacentUnknown[TestLoc]
        else if PeaceBorder then TestScore:=$400-32
        else TestScore:=(RO.Turn-RO.MapObservedLast[TestLoc]) div 16;
      end; // no enemy city or unit here

    if TestScore>0 then
      begin
      TestScore:=TestScore*$1000-DistanceScore*TestTime;
      if TestScore>PatrolScore then
        BestCount:=0;
      if TestScore>=PatrolScore then
        begin
        inc(BestCount);
        if random(BestCount)=0 then
          begin
          PatrolScore:=TestScore;
          PatrolLoc:=TestLoc;
          end
        end;
      end
    end; // while Pile.Get
  Pile.Free;

  if (PatrolLoc>=0) and (PatrolLoc<>Loc) then
    begin // capture/discover/patrol task found, execute it
    while (PatrolLoc<>Loc) and (MoreTurn[PatrolLoc]>0)
      and ((MoreTurn[PatrolLoc]>1)
        or not (Map[PatrolLoc] and fTerrain in [fMountains,fDesert,fArctic])) do
      begin
      PatrolLoc:=PreLoc[PatrolLoc];
      done:=true // no effect if enemy spotted
      end;
    while (PatrolLoc<>Loc) and (UnitPresence[PatrolLoc] and Kind<>0)
      and (Map[PatrolLoc] and fCity=0)
      and (Map[PatrolLoc] and fTerImp<>tiFort)
      and (Map[PatrolLoc] and fTerImp<>tiBase)
      and not (Map[PreLoc[PatrolLoc]] and fTerrain in [fDesert,fArctic]) do
      begin
      PatrolLoc:=PreLoc[PatrolLoc];
      done:=true // no effect if enemy spotted
      end;
    if PatrolLoc=Loc then exit;
    TestLoc:=PatrolLoc;
    NextLoc:=PreLoc[TestLoc];
    while TestLoc<>Loc do
      begin
      Temp:=TestLoc;
      TestLoc:=NextLoc;
      NextLoc:=PreLoc[TestLoc];
      PreLoc[TestLoc]:=Temp;
      end;

    UnitPresence[Loc]:=UnitPresence[Loc] and not Kind; // assume unit was only one of kind here
    while Loc<>PatrolLoc do
      begin
      NextLoc:=PreLoc[Loc];
      MoveResult:=Unit_Step(uix, NextLoc);
      if (MoveResult and (rUnitRemoved or rEnemySpotted)<>0)
        or (MoveResult and rExecuted=0) then
        begin
        if MoveResult and rExecuted=0 then Moved[uix]:=true;
        result:= MoveResult and rEnemySpotted=0;
        done:=true;
        break
        end;
      assert(Loc=NextLoc);
      end;
    if Loc>=0 then
      begin
      UnitPresence[Loc]:=UnitPresence[Loc] or Kind;
      if Map[Loc] and fCity<>0 then
        begin
        Moved[uix]:=true;
        done:=true; // stay in captured city as defender
        end
      end  
    end
  else done:=true;
  end; // while not done
if result then Moved[uix]:=true;
end; // ProcessMove

procedure TBarbarina.AttackAndPatrol;

  procedure SetCityDefenders;
  var
  uix,cix,V8,Loc1,Best,uixBest,det: integer;
  Adjacent: TVicinity8Loc;
  IsPort: boolean;
  begin
  for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
    begin
    IsPort:=false;
    V8_to_Loc(Loc,Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1>=0) and (Map[Loc1] and fTerrain<fGrass)
        and (Formation[Loc1]>=0) and (Formation[Loc1]<maxCOD)
        and (OceanPresence[Formation[Loc1]] and not Neighbours<>0) then
        IsPort:=true
      end;
    Best:=-1;
    for uix:=0 to RO.nUn-1 do if MyUnit[uix].Loc=Loc then
      with MyUnit[uix] do
        if (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0) then
          begin
          if (mix=2) and (RO.Government=gDespotism) then
            begin det:=1 shl 16; Moved[uix]:=true end // town guard
          else if IsPort then det:=MyModel[mix].Defense shl 8+Flags and unFortified shl 7-health
          else det:=MyModel[mix].Speed shl 8+Flags and unFortified shl 7-health;
          if det>Best then
            begin Best:=det; uixBest:=uix end
          end;
    if Best>=0 then Moved[uixBest]:=true
    end;
  end;

  procedure ProcessSeaTransport;
  var
  i,f,uix,Loc1,a,b: integer;
  ready,go: boolean;
  TransportPlan: TGroupTransportPlan;
  begin
  go:=false;
  for f:=0 to maxCOD-1 do
    if (f<nContinent) and (ContinentPresence[f] and not (1 shl me or PresenceUnknown)<>0) then
      go:=true; // any enemy island known?
  if not go then exit;

  SeaTransport_BeginInitialize;
  go:=false;
  for uix:=0 to RO.nUn-1 do if not Moved[uix] then with MyUnit[uix] do
    if (Loc>=0) and (MyModel[mix].Domain=dGround)
      and (MyModel[mix].Attack>0) and (Map[Loc] and fTerrain>=fGrass) then
      begin
      f:=Formation[Loc];
      if (f>=0) and (f<maxCOD) and (ContinentPresence[f] and not (1 shl me)=0) then
        begin go:=true; SeaTransport_AddLoad(uix); end;
      end;
  if go then
    begin
    go:=false;
    for uix:=0 to RO.nUn-1 do if not Moved[uix] then with MyUnit[uix] do
      if (Loc>=0) and (mix=mixBest[ctSeaTrans]) and (TroopLoad=0)
        and (Health=100) then
        begin go:=true; SeaTransport_AddTransport(uix) end;
    end;
  if go then
    for Loc1:=0 to MapSize-1 do if Map[Loc1] and fTerrain>=fGrass then
      begin
      f:=Formation[Loc1];
      if (f>=0) and (f<maxCOD)
        and (ContinentPresence[f] and not (1 shl me or PresenceUnknown)<>0) then
        SeaTransport_AddDestination(Loc1);
      end;
  SeaTransport_EndInitialize;
  while SeaTransport_MakeGroupPlan(TransportPlan) do
    begin
    Moved[TransportPlan.uixTransport]:=true;
    ready:=MyUnit[TransportPlan.uixTransport].Loc=TransportPlan.LoadLoc;
    if not ready then
      begin
      Unit_MoveEx(TransportPlan.uixTransport, TransportPlan.LoadLoc);
      ready:=MyUnit[TransportPlan.uixTransport].Loc=TransportPlan.LoadLoc;
      end;
    if ready then
      for i:=0 to TransportPlan.nLoad-1 do
        begin
        Loc_to_ab(TransportPlan.LoadLoc,
          MyUnit[TransportPlan.uixLoad[i]].Loc, a, b);
        ready:=ready and (abs(a)<=1) and (abs(b)<=1);
        end;
    if ready then
      begin
      for i:=0 to TransportPlan.nLoad-1 do
        begin
        Unit_Step(TransportPlan.uixLoad[i], TransportPlan.LoadLoc);
        Moved[TransportPlan.uixLoad[i]]:=true;
        end
      end
    else
      begin
      for i:=0 to TransportPlan.nLoad-1 do
        begin
        Unit_MoveEx(TransportPlan.uixLoad[i], TransportPlan.LoadLoc, mxAdjacent);
        Moved[TransportPlan.uixLoad[i]]:=true;
        end
      end;
    end
  end;

  procedure ProcessUnload(uix: integer);

    procedure Unload(Kind, ToLoc: integer);
    var
    uix1: integer;
    begin
    for uix1:=0 to RO.nUn-1 do with MyUnit[uix1] do
      if (Loc>=0) and (Master=uix)
        and (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0)
        and (Movement=MyModel[mix].Speed)
        and ((MyModel[mix].Speed>=250)=(Kind=ukFast)) then
        begin
        Unit_Step(uix1,ToLoc);
        UnitPresence[ToLoc]:=UnitPresence[ToLoc] or Kind;
        break
        end
    end;

  var
  uix1,MoveStyle,TestLoc,TestTime,NextLoc,NextTime,V8,
    RecoverTurns,nSlow,nFast,SlowUnloadLoc,FastUnloadLoc,EndLoc,f: integer;
  NextTile: cardinal;
  Adjacent: TVicinity8Loc;
  Reached: array[0..lxmax*lymax-1] of boolean;
  begin
  // inventory
  nSlow:=0;
  nFast:=0;
  for uix1:=0 to RO.nUn-1 do with MyUnit[uix1] do
    if (Loc>=0) and (Master=uix)
      and (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0) then
      if MyModel[mix].Speed>=250 then inc(nFast)
      else inc(nSlow);

  with MyUnit[uix] do
    begin
    MoveStyle:=GetMyMoveStyle(mix, Health);
    repeat
      SlowUnloadLoc:=-1;
      FastUnloadLoc:=-1;
      EndLoc:=-1;
      fillchar(Reached, MapSize, false);
      Pile.Create(MapSize);
      Pile.Put(Loc, $800-Movement);
      while (SlowUnloadLoc<0) and (FastUnloadLoc<0)
        and Pile.Get(TestLoc, TestTime) do
        begin
        Reached[TestLoc]:=true;
        V8_to_Loc(TestLoc, Adjacent);
        for V8:=0 to 7 do
          begin
          NextLoc:=Adjacent[V8];
          if (NextLoc>=0) and not Reached[NextLoc] then
            begin
            NextTile:=Map[NextLoc];
            if NextTile and fTerrain=fUnknown then
            else if NextTile and fTerrain>=fGrass then
              begin
              f:=Formation[NextLoc];
              if (f>=0) and (f<maxCOD)
                and (ContinentPresence[f] and not (1 shl me or PresenceUnknown)<>0)
                and (NextTile and (fUnit or fOwned)<>fUnit) then
                begin
                if (nSlow>0) and (UnitPresence[NextLoc] and ukSlow=0)
                  and ((SlowUnloadLoc<0) or (Terrain[Map[NextLoc] and fTerrain].Defense
                    >Terrain[Map[SlowUnloadLoc] and fTerrain].Defense)) then
                  begin EndLoc:=TestLoc; SlowUnloadLoc:=NextLoc end;
                if (nFast>0) and (UnitPresence[NextLoc] and ukFast=0)
                  and ((FastUnloadLoc<0) or (Terrain[Map[NextLoc] and fTerrain].Defense
                    >Terrain[Map[FastUnloadLoc] and fTerrain].Defense)) then
                  begin EndLoc:=TestLoc; FastUnloadLoc:=NextLoc end;
                end
              end
            else if EndLoc<0 then
              case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime,
                RecoverTurns, Map[TestLoc], NextTile, true) of
                csOk:
                  Pile.Put(NextLoc, NextTime);
                csForbiddenTile:
                  Reached[NextLoc]:=true; // don't check moving there again
                csCheckTerritory:
                  if RO.Territory[NextLoc]=RO.Territory[TestLoc] then
                    Pile.Put(NextLoc, NextTime);
                end
            end
          end;
        end;
      Pile.Free;

      if EndLoc<0 then exit;
      if Loc<>EndLoc then
        Unit_MoveEx(uix,EndLoc);
      if Loc<>EndLoc then exit;
      if SlowUnloadLoc>=0 then
        begin Unload(ukSlow,SlowUnloadLoc); dec(nSlow) end;
      if FastUnloadLoc>=0 then
        begin Unload(ukFast,FastUnloadLoc); dec(nFast) end;
      if TroopLoad=0 then
        begin Moved[uix]:=false; exit end
    until false
    end
  end;

var
uix,euix,Kind,euixBest,AttackLoc: integer;
OldTile: cardinal;
BackToStart,FirstLoop: boolean;
begin
fillchar(UnitPresence, MapSize, 0);
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0) then
    begin
    if MyModel[mix].Speed>=250 then Kind:=ukFast
    else Kind:=ukSlow;
    UnitPresence[Loc]:=UnitPresence[Loc] or Kind
    end;

fillchar(Moved, RO.nUn, false);
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].Master>=0) or (MyUnit[uix].TroopLoad>0) then
    Moved[uix]:=true;

FirstLoop:=true;
repeat
  // ATTACK
  repeat
    BackToStart:=false;
    if RO.nEnemyUn>0 then
      begin
      fillchar(euixMap, MapSize*2, $FFFF);
      fillchar(AttackScore,RO.nEnemyUn*4,0);
      for euix:=0 to RO.nEnemyUn-1 do with RO.EnemyUn[euix] do
        if (Loc>=0) and (RO.Treaty[Owner]<trPeace) then
          begin
          BackToStart:=true;
          euixMap[Loc]:=euix;
          uixAttack[euix]:=-1;
          end;
      end;
    if not BackToStart then break;

    for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
      if (Loc>=0) and (Master<0) and (MyModel[mix].Attack>0) then
        RateAttack(uix);

    BackToStart:=false;
    repeat
      euixBest:=-1;
      for euix:=0 to RO.nEnemyUn-1 do
        if (AttackScore[euix]>0)
          and ((euixBest<0) or (AttackScore[euix]>AttackScore[euixBest])) then
          euixBest:=euix;
      if euixBest<0 then break;
      uix:=uixAttack[euixBest];
      AttackLoc:=RO.EnemyUn[euixBest].Loc;
      OldTile:=Map[AttackLoc];
      if (AttackLoc<0) // only happens when city was destroyd with attack and enemy units have disappeared
        or (DoAttack(uix,AttackLoc)
          and ((Map[AttackLoc] and fUnit<>0)
            or (OldTile and fCity<>0) and (Map[AttackLoc] and fCity=0))) then
        BackToStart:=true // new situation, rethink
      else
        begin
        euixMap[AttackLoc]:=-1;
        AttackScore[euixBest]:=0;
        uixAttack[euixBest]:=-1;
        if MyUnit[uix].Loc>=0 then
          RateAttack(uix);
        end
    until BackToStart
  until not BackToStart;

  if FirstLoop then
    begin
    SetCityDefenders;
    ProcessSeaTransport;
    for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
      if (Loc>=0) and (TroopLoad>0) then
        ProcessUnload(uix);
    end;
  FirstLoop:=false;

  for uix:=0 to RO.nUn-1 do with MyUnit[uix],MyModel[mix] do
    if not Moved[uix] and (Loc>=0) and (Domain=dSea) and (Attack>0)
      and (Cap[mcArtillery]>0) then
      DoAttack(uix,maNextCity); // check bombardments

  // MOVE
  for uix:=0 to RO.nUn-1 do if not Moved[uix] then with MyUnit[uix] do
    if (Loc>=0) and ((MyModel[mix].Attack>0) or (MyModel[mix].Domain=dSea)) then
      if not ProcessMove(uix) then
        begin BackToStart:=true; break end
until not BackToStart;
end; // AttackAndPatrol

procedure TBarbarina.Barbarina_SetCityProduction;

const
CoastalWonder=1 shl woLighthouse + 1 shl woMagellan;
PrimeWonder=1 shl woColossus + 1 shl woGrLibrary + 1 shl woSun
  + 1 shl woMagellan + 1 shl woEiffel + 1 shl woLiberty + 1 shl woShinkansen;

  function LowPriority(cix: integer): boolean;
  var
  part,cixHighPriority,TestDistance: integer;
  begin
  result:=false;
  for part:=0 to nShipPart-1 do
    begin
    cixHighPriority:=ColonyShipPlan[part].cixProducing;
    if (cixHighPriority>=0) and (cixHighPriority<>cix) then
      begin
      TestDistance:=Distance(MyCity[cix].Loc,MyCity[cixHighPriority].Loc);
      if TestDistance<11 then
        begin result:=true; exit end
      end
    end
  end;

  function ChooseWonderToBuild(WonderAvailable: integer; AllowCoastal: boolean): integer;
  var
  Count,iix: integer;
  begin
  if (WonderAvailable and PrimeWonder>0)
    and (AllowCoastal or (WonderAvailable and PrimeWonder and not CoastalWonder>0)) then
    WonderAvailable:=WonderAvailable and PrimeWonder; // alway prefer prime wonders
  Count:=0;
  for iix:=0 to 27 do
    begin
    if (1 shl iix) and WonderAvailable<>0 then
      if (1 shl iix) and CoastalWonder<>0 then
        begin
        if AllowCoastal then inc(Count,2)
        end
      else inc(Count);
    end;
  Count:=Random(Count);
  for iix:=0 to 27 do
    begin
    if (1 shl iix) and WonderAvailable<>0 then
      if (1 shl iix) and CoastalWonder<>0 then
        begin
        if AllowCoastal then dec(Count,2)
        end
      else dec(Count);
    if Count<0 then
      begin
      result:=iix;
      exit
      end
    end
  end;

var
i,iix,cix,mix,uix,mixProduce,mixShip,V8,V21,Loc1,TotalPop,AlonePop,f,f1,
  nTownGuard,ShipPart,ProduceShipPart,TestDistance,part,WonderAvailable,
  WonderInWork,cixNewCapital,Center,Score,BestScore: integer;
mixCount: array[0..nmmax-1] of integer;
//RareLoc: array[0..5] of integer;
Adjacent: TVicinity8Loc;
IsCoastal,IsPort,IsUnitProjectObsolete,HasSettler,SpezializeShipProduction,
  AlgaeAvailable,ProjectComplete,DoLowPriority,WillProduceColonyShip,
  ImportantCity: boolean;
Radius: TVicinity21Loc;
Report: TCityReportNew;
begin
AnalyzeMap;

FindBestModels;

fillchar(mixCount, RO.nModel*4, 0);
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if Loc>=0 then inc(mixCount[mix]);
if (mixBest[ctGroundSlow]>=0)
  and ((mixBest[ctGroundFast]<0)
  or (mixCount[mixBest[ctGroundSlow]]<mixCount[mixBest[ctGroundFast]])) then
  mixProduce:=mixBest[ctGroundSlow]
else mixProduce:=mixBest[ctGroundFast];
if (mixBest[ctSeaTrans]>=0)
  and ((mixBest[ctSeaArt]<0)
  or (mixCount[mixBest[ctSeaTrans]]<mixCount[mixBest[ctSeaArt]])) then
  mixShip:=mixBest[ctSeaTrans]
else mixShip:=mixBest[ctSeaArt];
if (mixProduce>=0) and (mixBest[ctSeaTrans]>=0)  
  and (mixCount[mixShip]*RO.Model[mixBest[ctSeaTrans]].Cap[mcSeaTrans]
    *RO.Model[mixBest[ctSeaTrans]].MTrans div 2>=mixCount[mixProduce]) then
  mixShip:=-1;

// produce ships only on certain continents?
TotalPop:=0;
AlonePop:=0;
for cix:=0 to RO.nCity-1 do with MyCity[cix] do
  if (Loc>=0) and (Flags and chCaptured=0) then
    begin
    inc(TotalPop, Size);
    f:=Formation[Loc];
    if (f<0) or (f>=maxCOD) or (ContinentPresence[f]=1 shl me) then
      inc(AlonePop, Size);
    end;
SpezializeShipProduction:= AlonePop*2>=TotalPop;

cixNewCapital:=-1;
WonderAvailable:=0;
WonderInWork:=0;
for iix:=0 to 27 do
  if (Imp[iix].Preq<>preNA)
    and ((Imp[iix].Preq=preNone) or IsResearched(Imp[iix].Preq))
    and (RO.Wonder[iix].CityID=-1) then
    inc(WonderAvailable,1 shl iix);
for cix:=0 to RO.nCity-1 do if MyCity[cix].Loc>=0 then
  begin
  iix:=City_CurrentImprovementProject(cix);
  if (iix>=0) and (iix<28) then
    inc(WonderInWork,1 shl iix)
  else if iix=imPalace then
    cixNewCapital:=cix;
  end;

if (RO.NatBuilt[imPalace]=0) and (cixNewCapital<0) then
  begin // palace was destroyed, build new one
  Center:=CenterOfEmpire;
  BestScore:=0;
  for cix:=0 to RO.nCity-1 do with MyCity[cix] do
    if (Loc>=0) and (Flags and chCaptured=0) then
      begin // evaluate city as new capital
      Score:=Size*12 + 512-Distance(Loc,Center);
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if (Loc1>=0) and (Map[Loc1] and fTerrain<fGrass) then
          begin
          f1:=Formation[Loc1];
          if (f1>=0) and (f1<maxCOD)
            and ((OceanSize[f1]>=8) or (OceanPresence[f1] and not (1 shl me)<>0)) then
            begin // prefer non-coastal cities
            dec(Score,18);
            break
            end
          end
        end;
      if Score>BestScore then
        begin
        BestScore:=Score;
        cixNewCapital:=cix
        end
      end
  end;

AlgaeAvailable:= (RO.NatBuilt[imAlgae]=0) and (RO.Tech[Imp[imAlgae].Preq]>=tsApplicable);
for cix:=0 to RO.nCity-1 do with MyCity[cix] do
  if (Loc>=0) and (Project and (cpImp+cpIndex)=cpImp+imAlgae) then
    AlgaeAvailable:=false;

for cix:=0 to RO.nCity-1 do with MyCity[cix] do
  if (Loc>=0) and (Flags and chCaptured=0) and LowPriority(cix) then
    City_SetTiles(cix,1 shl CityOwnTile); // free all tiles of low-prio cities
for DoLowPriority:=false to true do
  for cix:=0 to RO.nCity-1 do with MyCity[cix] do
    if (Loc>=0) and (Flags and chCaptured=0) and (LowPriority(cix)=DoLowPriority) then
      begin
      f:=Formation[Loc];
      IsCoastal:=false;
      IsPort:=false;
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if (Loc1>=0) and (Map[Loc1] and fTerrain<fGrass) then
          begin
          IsCoastal:=true;
          f1:=Formation[Loc1];
          if (f1>=0) and (f1<maxCOD) and (OceanSize[f1]>=8)
            and (OceanPresence[f1] and not (1 shl me)<>0) then
            begin
            IsPort:=true;
            break;
            end
          end
        end;
      if (City_CurrentUnitProject(cix)>=0)
        and (RO.Model[City_CurrentUnitProject(cix)].Kind<>mkSettler) then
        begin
        i:=nModelCategory-1;
        while (i>=0) and (City_CurrentUnitProject(cix)<>mixBest[i]) do
          dec(i);
        IsUnitProjectObsolete:= i<0;
        end
      else IsUnitProjectObsolete:=false;
      if RO.Government=gDespotism then
        begin
        nTownGuard:=0;
        for uix:=0 to RO.nUn-1 do
          if (MyUnit[uix].mix=mixTownGuard) and (MyUnit[uix].Loc=Loc) then
            inc(nTownGuard);
        end;

      iix:=City_CurrentImprovementProject(cix);
      if (iix>=0) and (iix<28)
        or (iix=imPalace) or (iix=imShipComp) or (iix=imShipPow) or (iix=imShipHab) then
        City_OptimizeTiles(cix,rwMaxProd)
      else if size<8 then
        City_OptimizeTiles(cix,rwMaxGrowth)
      else City_OptimizeTiles(cix,rwForceProd);

      WillProduceColonyShip:=false;
      ProduceShipPart:=-1;
      for part:=0 to nShipPart-1 do
        if ColonyShipPlan[part].cixProducing=cix then
          begin
          WillProduceColonyShip:=true;
          ProduceShipPart:=ShipImpIndex[part];
          end;

      if cix=cixNewCapital then
        City_StartImprovement(cix,imPalace)
      else if (iix>=0) and (iix<28) and ((1 shl iix) and WonderAvailable<>0) then
        // complete wonder production first
      else if (mixProduce>=0) and (City_CurrentUnitProject(cix)>=0)
        and not IsUnitProjectObsolete
        and ((Flags and chProduction=0)
          or (RO.Model[City_CurrentUnitProject(cix)].Cap[mcLine]>0)
          and (mixCount[City_CurrentUnitProject(cix)]<RO.nCity*(2+cix and 3))) then
        // complete unit production first
      else
        begin
        if ProduceShipPart>=0 then
          begin
          if (Built[imGranary]=0) and (Size<10) and City_Improvable(cix,imGranary) then
            City_StartImprovement(cix,imGranary)
          else if (Built[imAqueduct]=0) and City_Improvable(cix,imAqueduct) then
            City_StartImprovement(cix,imAqueduct)
          else if (Built[imAqueduct]>0) and (Size<12)
            and (AlgaeAvailable or (Project and (cpImp+cpIndex)=cpImp+imAlgae)) then
            City_StartImprovement(cix,imAlgae)
          else if (Built[imFactory]=0) and City_Improvable(cix,imFactory) then
            City_StartImprovement(cix,imFactory)
          else if (Built[imPower]+Built[imHydro]+Built[imNuclear]=0)
            and (City_Improvable(cix,imPower)
              or City_Improvable(cix,imHydro)
              or City_Improvable(cix,imNuclear)) then
            begin
            if City_Improvable(cix,imHydro) then
              City_StartImprovement(cix,imHydro)
            else if City_Improvable(cix,imPower) then
              City_StartImprovement(cix,imPower)
            else City_StartImprovement(cix,imNuclear)
            end
          else if (Built[imMfgPlant]=0) and City_Improvable(cix,imMfgPlant) then
            City_StartImprovement(cix,imMfgPlant)
          else if City_Improvable(cix, ProduceShipPart) then
            City_StartImprovement(cix,ProduceShipPart)
          else ProduceShipPart:=-1;
          end;
        if ProduceShipPart<0 then
          begin
          ProjectComplete:= not City_HasProject(cix) or (Flags and chProduction<>0);
          HasSettler:=false;
          for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
            if (Loc>=0) and (Home=cix)
              and (MyModel[mix].Kind=mkSettler) then
              HasSettler:=true;
          if ((RO.Government<>gDespotism) or (RO.nUn>=RO.nCity*4))
            and not IsResearched(adMassProduction)
            and (Built[imPalace]>0) and (RO.Wonder[woZeus].CityID=-1)
            and City_Improvable(cix,woZeus) then
            City_StartImprovement(cix,woZeus)
          else if (City_CurrentImprovementProject(cix)>=0)
            and (City_CurrentImprovementProject(cix)<28) then
            begin// wonder already built, try to switch to different one
            if (WonderAvailable and not WonderInWork>0)
              and (IsCoastal or (WonderAvailable and not WonderInWork and not CoastalWonder>0)) then
              begin
              iix:=ChooseWonderToBuild(WonderAvailable and not WonderInWork,IsCoastal);
              City_StartImprovement(cix,iix);
              WonderInWork:=WonderInWork or (1 shl iix);
              end
            else City_StopProduction(cix);  
            end
          else if (Built[imPalace]>0) and (RO.NatBuilt[imSpacePort]=0)
            and City_Improvable(cix,imSpacePort) then
            City_StartImprovement(cix,imSpacePort)
          else if Built[imPalace]+Built[imCourt]+Built[imTownHall]=0 then
            begin
            if City_Improvable(cix,imCourt) then
              City_StartImprovement(cix,imCourt)
            else City_StartImprovement(cix,imTownHall);
            end
          else if not HasSettler and (RO.nUn>=RO.nCity*4) then
            begin
            if ProjectComplete and (City_CurrentUnitProject(cix)<>0) then
              begin
              mix:=RO.nModel-1;
              while RO.Model[mix].Kind<>mkSettler do dec(mix);
              City_StartUnitProduction(cix,mix)
              end
            end
          else if (RO.Government=gDespotism) and (nTownGuard<2)
            and (nTownGuard*2+3<Size) then
            begin
            if ProjectComplete then
              City_StartUnitProduction(cix,2)
            end
          else if (RO.Government=gFundamentalism)
            and (Size>=8) and (Built[imAqueduct]=0)
            and City_Improvable(cix,imAqueduct) and (RO.nUn>=RO.nCity*4) then
            begin
            if ProjectComplete then
              City_StartImprovement(cix,imAqueduct)
            end
          else if ProjectComplete then
            begin // low prio projects
            ImportantCity:=WillProduceColonyShip or (Built[imPalace]>0);
            for iix:=0 to 27 do if Built[iix]>0 then
              ImportantCity:=true;
            City_GetReportNew(cix, Report);
            if (Report.Corruption>=6) and (RO.nUn>=RO.nCity*4)
              and City_Improvable(cix,imCourt) then
              City_StartImprovement(cix,imCourt)
            else if (Report.Production>=WonderProductionThreshold)
              and (WonderAvailable and not WonderInWork>0)
              and (IsCoastal or (WonderAvailable and not WonderInWork and not CoastalWonder>0))
              and (Random>=(1+WonderInclination)/(RO.nCity+WonderInclination)) then
              begin
              iix:=ChooseWonderToBuild(WonderAvailable and not WonderInWork,IsCoastal);
              City_StartImprovement(cix,iix);
              WonderInWork:=WonderInWork or (1 shl iix);
              end
            else if (ImportantCity or (Loc mod 9=0)) and (Built[imWalls]=0)
              and City_Improvable(cix,imWalls) then
              City_StartImprovement(cix,imWalls)
            else if IsPort and (ImportantCity or (Loc mod 7=0))
              and (Built[imCoastalFort]=0)
              and City_Improvable(cix,imCoastalFort) then
              City_StartImprovement(cix,imCoastalFort)
            {else if (ImportantCity or (Loc mod 11=0)) and (Built[imMissileBat]=0)
              and City_Improvable(cix,imMissileBat) then
              City_StartImprovement(cix,imMissileBat)}
            else if IsPort and (not SpezializeShipProduction or (f<0)
                or (f>=maxCOD) or (ContinentPresence[f]=1 shl me))
              and (Built[imDockyard]=0)
              and City_Improvable(cix,imDockyard) then
              City_StartImprovement(cix,imDockyard)
            else if IsPort and (mixShip>=0) and
              (not SpezializeShipProduction or (f<0) or (f>=maxCOD) or
                (ContinentPresence[f]=1 shl me)) then
              City_StartUnitProduction(cix,mixShip)
            else if (Built[imBarracks]+Built[imMilAcademy]=0)
              and City_Improvable(cix,imBarracks) then
              City_StartImprovement(cix,imBarracks)
            else if mixProduce>=0 then
              City_StartUnitProduction(cix,mixProduce)
            else if City_HasProject(cix) then
              City_StopProduction(cix);
            end
          end;
        end;
      if (City_CurrentImprovementProject(cix)=imCourt)
        and (Built[imTownHall]>0)
        and (prod>=imp[imCourt].cost*BuildCostMod[G.Difficulty[me]] div 12
          -(imp[imTownHall].cost*BuildCostMod[G.Difficulty[me]] div 12)*2 div 3) then
        City_RebuildImprovement(cix,imTownHall)
      else if (RO.Government=gFundamentalism) and not WillProduceColonyShip then
        for iix:=28 to nImp-1 do
          if (Built[iix]>0)
            and ((iix in [imTemple,imTheater,imCathedral,imColosseum,imLibrary,
              imUniversity,imResLab,imHarbor,imSuperMarket])
              or (iix in [imFactory,imMfgPlant,imPower,imHydro,imNuclear])
                and (Built[imRecycling]=0)) then
            begin
            if City_RebuildImprovement(cix,iix)<rExecuted then
              City_SellImprovement(cix,iix);
            break
            end
      end
end;

function TBarbarina.Barbarina_ChooseResearchAdvance: integer;
var
nPreq,rmix,rmixChosen,i,MaxWeight,MaxDefense,ChosenPreq: integer;
NeedSeaUnits,ready: boolean;
ModelExists: set of 0..nModelCategory-1;
known: array[0..nAdv-1] of integer;

  procedure ChoosePreq(ad: integer);
  var
  i: integer;
  PreqOk: boolean;
  begin
  assert(RO.Tech[ad]<tsApplicable);
  if known[ad]=0 then
    begin
    known[ad]:=1;
    PreqOk:=true;
    if not (ad in [adScience,adMassProduction]) and (RO.Tech[ad]<tsSeen) then
      for i:=0 to 1 do
        if (AdvPreq[ad,i]>=0) and (RO.Tech[AdvPreq[ad,i]]<tsApplicable) then
          begin
          PreqOk:=false;
          ChoosePreq(AdvPreq[ad,i]);
          end;
    if PreqOk then
      begin
      inc(nPreq);
      if random(nPreq)=0 then ChosenPreq:=ad
      end
    end
  end;

begin
// check military research
rmixChosen:=-1;
ModelExists:=[];
for rmix:=nResearchModel-1 downto 0 do with ResearchModel[rmix] do
  if not (Category in ModelExists)
    and ((adStop<0) or not IsResearched(adStop)) then
    begin
    MaxWeight:=0;
    case Domain of
      dGround:
        begin
        if IsResearched(adWarriorCode) then MaxWeight:=5;
        if IsResearched(adHorsebackRiding) then MaxWeight:=7;
        if IsResearched(adAutomobile) then MaxWeight:=10;
        end;
      dSea:
        begin
        if IsResearched(adMapMaking) then MaxWeight:=5;
        if IsResearched(adSeaFaring) then MaxWeight:=7;
        if IsResearched(adSteel) then MaxWeight:=9;
        end;
      dAir:
        begin
        if IsResearched(adFlight) then MaxWeight:=5;
        if IsResearched(adAdvancedFlight) then MaxWeight:=7;
        end;
      end;
    if Domain=dGround then MaxDefense:=2
    else MaxDefense:=3;
    if IsResearched(adSteel) then inc(MaxDefense);
    ready:= (MaxWeight>=Weight) and (MaxDefense>=Cap[mcDefense]);
    if ready then
      for i:=0 to nFeature-1 do
        if (Cap[i]>0) and (Feature[i].Preq<>preNone)
          and ((Feature[i].Preq<0) or not IsResearched(Feature[i].Preq)) then
          ready:=false;
    if ready then
      begin
      for i:=0 to nUpgrade-1 do
        if (Upgrades and (1 shl i)<>0) and not IsResearched(Upgrade[Domain,i].Preq) then
          ready:=false;
      end;
    if ready then
      begin
      include(ModelExists,Category);
      if not IsModelAvailable(rmix) then
        rmixChosen:=rmix;
      end
    end;
if rmixChosen>=0 then with ResearchModel[rmixChosen] do
  begin
  PrepareNewModel(Domain);
  for i:=0 to nFeature-1 do if (i<2) or (Cap[i]>0) then
    SetNewModelFeature(i,Cap[i]);
  if RO.Wonder[woSun].EffectiveOwner=me then
    begin
    //if Cap[mcWeapons]>=2*Cap[mcArmor] then
    //  SetNewModelFeature(mcFirst,1);
    if Cap[mcWeapons]>=Cap[mcArmor] then
      SetNewModelFeature(mcWill,1);
    end;
  result:=adMilitary;
  exit;
  end;

NeedSeaUnits:=true;
i:=0;
while (i<nResearchOrder)
  and (not NeedSeaUnits and (ResearchOrder[i]<0)
    or IsResearched(abs(ResearchOrder[i]))) do
  inc(i);
if i>=nResearchOrder then // list done, continue with future tech
  begin
  if random(2)=1 then
    result:=futArtificialIntelligence
  else result:=futMaterialTechnology;
  end
else
  begin
  FillChar(known,SizeOf(known),0);
  nPreq:=0;
  ChosenPreq:=-1;
  ChoosePreq(abs(ResearchOrder[i]));
  assert(nPreq>0);
  result:=ChosenPreq
  end
end;

function TBarbarina.Barbarina_WantCheckNegotiation(Nation: integer): boolean;
begin
if (RO.Tech[adTheRepublic]<tsSeen) and (RO.Tech[adTheology]>=tsApplicable)
  and (RO.Tech[adGunPowder]>=tsApplicable)
  and (RO.EnemyReport[Nation].Tech[adTheRepublic]>=tsApplicable) then
  result:=true
else result:=false;
end;

procedure TBarbarina.Barbarina_DoCheckNegotiation;
begin
if RO.Tech[adTheRepublic]>=tsSeen then exit; // default reaction
if MyLastAction=scContact then
  begin
  MyAction:=scDipOffer;
  MyOffer.nDeliver:=1;
  MyOffer.nCost:=1;
  if (RO.Tech[adTheology]>=tsApplicable)
    and (RO.EnemyReport[Opponent].Tech[adTheology]<tsSeen) then
    MyOffer.Price[0]:=opTech+adTheology
  else MyOffer.Price[0]:=opChoose;
  MyOffer.Price[1]:=opTech+adTheRepublic;
  end
else if OppoAction=scDipAccept then
else if OppoAction=scDipOffer then
  begin
  if (OppoOffer.nDeliver=1) and (OppoOffer.Price[0]=opTech+adTheRepublic)
    and ((OppoOffer.nCost=0)
      or (OppoOffer.nCost=1)
      and (OppoOffer.Price[1] and opMask=opTech)
      and (RO.Tech[OppoOffer.Price[1]-opTech]>=tsApplicable)) then
    MyAction:=scDipAccept
  else MyAction:=scDipBreak
  end
else if OppoAction<>scDipBreak then
  MyAction:=scDipBreak
end;

function TBarbarina.Barbarina_WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean;
var
uix,TestLoc,V8: integer;
Adjacent: TVicinity8Loc;
begin
result:=false;
case NegoTime of
  EnemyCalled:
    result:=false;
  EndOfTurn:
    result:=false;
  BeginOfTurn:
    if RO.Turn>=RO.LastCancelTreaty[Nation]+CancelTreatyTurns then
      begin
      if (RO.Turn and 3=(Nation+$F-me) and 3) and (RO.Treaty[Nation]>trPeace) then
        begin
        DebugMessage(1, 'End alliance/friendly contact with P'+char(48+Nation));
        NegoCause:=CancelTreaty;
        result:=true
        end
      else if RO.Treaty[Nation]=trPeace then
        begin // declare war now?
        for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
          if (Loc>=0) and (MyModel[mix].Attack>0) then
            begin
            V8_to_Loc(Loc,Adjacent);
            for V8:=0 to 7 do
              begin
              TestLoc:=Adjacent[V8];
              if (TestLoc>=0) and (RO.Territory[TestLoc]=Nation)
                and ((Map[TestLoc] and fTerrain>=fGrass) or (Master>=0)
                  or (MyModel[mix].Domain<>dGround))
                and ((Map[TestLoc] and fTerrain<fGrass) or (MyModel[mix].Domain<>dSea)) then
                begin
                DebugMessage(1, 'Declare war on P'+char(48+Nation));
                NegoCause:=CancelTreaty;
                result:=true;
                exit;
                end
              end
            end
        end
      end;
  end
end;

procedure TBarbarina.Barbarina_DoNegotiation;
begin
if OppoAction=scDipStart then
  begin
  if NegoCause=CancelTreaty then
    MyAction:=scDipCancelTreaty
  end
end;

procedure TBarbarina.MakeColonyShipPlan;
var
i,V21,V21C,CityLoc,Loc1,part,cix,BestValue,TestValue,FoodCount,ProdCount,
  ProdExtra,Score,BestScore: integer;
Tile: cardinal;
ok,check: boolean;
Radius,RadiusC: TVicinity21Loc;
begin
for part:=0 to nShipPart-1 do
  begin
  ColonyShipPlan[part].cixProducing:=-1;
  ColonyShipPlan[part].nLocResource:=0;
  ColonyShipPlan[part].nLocFoundCity:=0;
  end;
if RO.Tech[adMassProduction]>=tsApplicable then // able to recognize ressources yet
  begin
  // check already existing cities
  for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
    begin
    V21_to_Loc(Loc, Radius);
    for V21:=1 to 26 do
      begin
      Loc1:=Radius[V21];
      if Loc1>=0 then
        begin
        Tile:=RO.Map[Loc1];
        if Tile and fModern<>0 then
          begin
          part:=(Tile and fModern) shr 25 -1;
          if RO.Ship[me].Parts[part]<ShipNeed[part] then // not enough of this kind already
            begin
            ok:=true;
            if ColonyShipPlan[part].cixProducing>=0 then
              begin // another city is already assigned to this ship part, choose one of the two
              TestValue:=(ID and $FFF) shl 4
                + ((ID shr 12)+15-me) and $F;
              BestValue:=(MyCity[ColonyShipPlan[part].cixProducing].ID and $FFF) shl 4
                + ((MyCity[ColonyShipPlan[part].cixProducing].ID shr 12)+15-me) and $F;
              if TestValue<=BestValue then
                ok:=false;
              end;
            if ok then
              ColonyShipPlan[part].cixProducing:=cix;
            end
          end
        end
      end
    end;

  // for parts without existing city, look for location of city to found
  check:=false;
  for part:=0 to nShipPart-1 do
    if (RO.Ship[me].Parts[part]<ShipNeed[part]) // not enough of this kind already
      and (ColonyShipPlan[part].cixProducing<0) then // no city to produce
      check:=true;
  if check then
    begin
    for Loc1:=0 to MapSize-1 do
      begin
      Tile:=RO.Map[Loc1];
      if Tile and fModern<>0 then
        begin
        part:=(Tile and fModern) shr 25 -1;
        if ColonyShipPlan[part].nLocResource<maxModern then
          begin
          ColonyShipPlan[part].LocResource[ColonyShipPlan[part].nLocResource]:=Loc1;
          inc(ColonyShipPlan[part].nLocResource);
          end;
        end
      end;
    for part:=0 to nShipPart-1 do
      if (RO.Ship[me].Parts[part]<ShipNeed[part]) // not enough of this kind already
        and (ColonyShipPlan[part].cixProducing<0) // no city to produce
        and (ColonyShipPlan[part].nLocResource>0) then // resource is known
        begin
        for i:=0 to ColonyShipPlan[part].nLocResource-1 do
          begin
          BestScore:=0;
          V21_to_Loc(ColonyShipPlan[part].LocResource[i],Radius);
          for V21:=1 to 26 do
            begin // check all potential cities in range
            CityLoc:=Radius[V21];
            if CityLoc>=0 then
              begin
              Tile:=RO.Map[CityLoc];
              if (Tile and fTerrain<>fUNKNOWN)
                and ((Tile and fTerrain=fForest)
                  or (Tile and fTerrain=fSwamp)
                  or (Terrain[Tile and fTerrain].IrrEff>0)) then
                begin
                FoodCount:=0;
                ProdCount:=0;
                ProdExtra:=0;
                V21_to_Loc(CityLoc,RadiusC);
                for V21C:=1 to 26 do
                  begin
                  Loc1:=RadiusC[V21C];
                  if Loc1>=0 then
                    begin
                    case RO.Map[Loc1] and (fTerrain or fSpecial) of
                      fGrass, fGrass+fSpecial1, fSwamp: inc(FoodCount);
                      fHills, fHills+fSpecial1: inc(ProdCount);
                      fShore+fSpecial1, fDesert+fSpecial1, fPrairie+fSpecial1,
                        fForest+fSpecial1:
                        inc(FoodCount,2);
                      fSwamp+fSpecial1, fShore+fSpecial2, fDesert+fSpecial2,
                      fPrairie+fSpecial2, fTundra+fSpecial2, fArctic+fSpecial1,
                      fHills+fSpecial2, fMountains+fSpecial1:
                        begin
                        inc(ProdCount);
                        inc(ProdExtra);
                        end;
                      end
                    end
                  end;
                if FoodCount=0 then
                  Score:=0
                else
                  begin
                  if ProdCount>7 then
                    ProdCount:=7;
                  if FoodCount<5 then
                    dec(ProdCount, 5-FoodCount);
                  Score:=ProdCount*4+ProdExtra*8+FoodCount;
                  Score:=Score shl 8 + ((CityLoc xor me)*4567) mod 251;
                    // some unexactness, random but always the same for this tile
                  end;  
                if Score>BestScore then
                  begin
                  BestScore:=Score;
                  ColonyShipPlan[part].LocFoundCity[ColonyShipPlan[part].nLocFoundCity]:=CityLoc;
                  end
                end
              end
            end;
          if BestScore>0 then
            inc(ColonyShipPlan[part].nLocFoundCity);
          end;
        end
    end
  end
end;

end.

