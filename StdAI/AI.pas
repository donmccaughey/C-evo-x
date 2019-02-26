{$INCLUDE switches.pas}
{//$DEFINE PERF}
unit AI;

interface

uses
{$IFDEF DEBUG}SysUtils,Names,{$ENDIF} // necessary for debug exceptions
{$IFDEF PERF}SysUtils,Windows,{$ENDIF} // necessary for performance measurement
Protocol, CustomAI, ToolAI, Barbarina;


const
WaitAfterReject=20; // don't try to contact this number of turn after contact was rejected
MinCityFood=3;
LeaveDespotism=80; // stay in despotism until this turn
TechReportOutdated=30;
MilProdShare=50; // minimum share of total production to specialize in military production

FutureTech=[futResearchTechnology,futProductionTechnology,futArmorTechnology,
  futMissileTechnology];

nResearchOrder=46;
ResearchOrder: array[0..1,0..nResearchOrder-1] of integer=
((adWheel,adWarriorCode,adHorsebackRiding,adCeremonialBurial,adPolytheism,
adMonarchy,adMysticism,adPoetry,adAstronomy,adMonotheism,
adTheology,adChivalry,adPottery,adMedicine,adGunpowder,adChemistry,
adExplosives,adUniversity,adTactics,adSeafaring,adNavigation,adRefining,adCombustionEngine,
adAutomobile,adPhysics,adMagnetism,adElectricity,adRefrigeration,
adRadioCommunication,adTheoryOfGravity,adAtomicTheory,adElectronics,
adMassProduction,adPlastics,adFlight,adEnvironmentalism,
adSanitation,adMin,adComputers,adRecycling,adSyntheticFood,
adSelfContainedEnvironment,adNuclearFission,adNuclearPower,adTheLaser,
adIntelligenArms),
(adWheel,adWarriorCode,adHorsebackRiding,adAlphabet,adMapMaking,adBronzeWorking,adWriting,
adCodeOfLaws,adCurrency,adTrade,adLiterature,adTheRepublic,adMathematics,
adPhilosophy,adScience,adMasonry,adConstruction,adEngineering,adInvention,
adIronWorking,adBridgeBuilding,adSteamEngine,adRailroad,adSteel,
adBanking,adIndustrialization,adConscription,adDemocracy,adEconomics,
adTheCorporation,adMassProduction,adRobotics,adCommunism,adMetallurgy,
adBallistics,adMobileWarfare,adAmphibiousWarfare,adMin,adComputers,adRocketry,adAdvancedRocketry,
adAdvancedFlight,adSpaceFlight,adComposites,adIntelligence,adCombinedArms));

LeaveOutTechs=[adPolytheism,adMysticism,adInvention,adEconomics,adPottery,
adMedicine,adEnvironmentalism,adRefining,adTrade,adLiterature,adMathematics,
adPhilosophy,adChemistry,adConscription,adCombustionEngine,adPhysics,
adTheoryOfGravity,adAtomicTheory,adSyntheticFood,adNuclearFission];

TechValue_ForResearch_LeaveOut=$700;
TechValue_ForResearch_Urgent=$600;
TechValue_ForResearch_Next=$400;
TechValue_ForResearch=$FF;
ForceNeeded_NoLeaveOut=20; // advancedness behind to state-of-art
ForceNeeded_LeaveOut=30; // advancedness behind of state-of-art
Compromise=6;

// basic strategies
bGender=$0001;
bMale=$0000;
bFemale=$0001;
bBarbarina=$0006;
bBarbarina_Hide=$0002;

// model categories
nModelCat=4;
mctNone=-1; mctGroundDefender=0; mctGroundAttacker=1; mctTransport=2; mctCruiser=3;

// mil research
BetterQuality: array[0..nModelCat-1] of integer=(50,50,80,80);
MaxBuildWorseThanBestModel=20; MaxExistWorseThanBestModel=50;

maxCOD=256;
PresenceUnknown=$10000;

nRequestedTechs=48;

PlayerHash: array[0..nPl-1] of integer=(7,6,0,2,10,8,12,14,4,1,3,5,9,11,13);

type
Suggestion=(suContact, suPeace, suFriendly);

TPersistentData=record
  LastResearchTech, BehaviorFlags, TheologyPartner: integer;
  RejectTurn: array[Suggestion,0..15] of smallint;
  RequestedTechs: array[0..nRequestedTechs-1] of integer;
    // ad + p shl 8 + Turn shl 16
  end;

TAI = class(TBarbarina)
  constructor Create(Nation: integer); override;

  procedure SetDataDefaults; override;

protected
  Data: ^TPersistentData;
  WarNations, BombardingNations, mixSettlers, mixCaravan, mixTownGuard,
    mixSlaves, mixMilitia, mixCruiser, OceanWithShip: integer;
  NegoCause: (Routine,CheckBarbarina);
  SettlerSurplus: array[0..maxCOD-1] of integer;
  uixPatrol: array[0..maxCOD-1] of integer;

  ContinentPresence: array[0..maxCOD-1] of integer;
  OceanPresence: array[0..maxCOD-1] of integer;
  UnitLack: array[0..maxCOD-1,mctGroundDefender..mctGroundAttacker] of integer;

  TotalPopulation: array[0..nPl-1] of integer;
  ContinentPopulation: array[0..nPl-1,0..maxCOD-1] of integer;
    // 1 means enemy territory spotted but no city
  DistrictPopulation: array[0..maxCOD-1] of integer;

  ModelCat: array[0..nMmax-1] of integer;
  ModelQuality: array[0..nMmax-1] of integer;
  ModelBestQuality: array[0..nModelCat-1] of integer;

  AdvanceValue: array[0..nAdv-1] of integer;
  AdvanceValuesSet: boolean;

  procedure DoTurn; override;
  procedure DoNegotiation; override;
  function ChooseResearchAdvance: integer; override;
  function ChooseStealAdvance: integer; override;
  function ChooseGovernment: integer; override;
  function WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean; override;
  function OnNegoRejected_CancelTreaty: boolean; override;

  procedure FindBestTrade(Nation: integer; var adWanted, adGiveAway: integer);
  procedure CheckGender;
  procedure AnalyzeMap;
  procedure CollectModelCatStat;
  procedure AttackAndPatrol;
  procedure MoveUnitsHome;
  procedure CheckAttack(uix: integer);
  procedure Patrol(uix: integer);
  procedure SetCityProduction;
  procedure SetAdvanceValues;
  function HavePort: boolean;
  {$IFDEF DEBUG}procedure TraceAdvanceValues(Nation: integer);{$ENDIF}

  // research
  procedure RateModel(const mi: TModelInfo; var Category, Quality: integer);
  procedure RateMyModel(mix: integer; var Category, Quality: integer);
  function IsBetterModel(const mi: TModelInfo): boolean;

  //terraforming
  procedure TileWorkPlan(Loc, cix: integer;
    var Value, NextJob, TotalWork: integer);
  procedure ProcessSettlers;

  // diplomacy
  function MostWanted(Nation, adGiveAway: integer): integer;

  end;


implementation

uses
Pile;

const
// fine adjustment
Aggressive=40; // 0 = never attacks, 100 = attacks even with heavy losses
DestroyBonus=30; // percent of building cost

var
LeaveOutValue: array[0..nAdv-1] of integer;


constructor TAI.Create(Nation: integer);
begin
inherited;
Data:=pointer(RO.Data);
{$IFDEF DEBUG}if Nation=1 then SetDebugMap(DebugMap);{$ENDIF}
AdvanceValuesSet:=false;
end;

procedure TAI.SetDataDefaults;
begin
with Data^ do
  begin
  LastResearchTech:=-1;
  if PlayerHash[me]>7 then BehaviorFlags:=bFemale else BehaviorFlags:=bMale;
  DebugMessage(1, 'Gender:='+char(48+BehaviorFlags and bGender));
  TheologyPartner:=-1;
  fillchar(RejectTurn,sizeof(RejectTurn),$FF);
  Fillchar(RequestedTechs, sizeof(RequestedTechs), $FF);
  end
end;

function TAI.OnNegoRejected_CancelTreaty: boolean;
begin
Data.RejectTurn[suContact,Opponent]:=RO.Turn;
result:= Data.BehaviorFlags and bBarbarina<>0;
end;


//-------------------------------
//            RESEARCH
//-------------------------------

procedure TAI.RateModel(const mi: TModelInfo; var Category, Quality: integer);
var
EffectiveTransport: integer;
begin
if mi.Kind>=mkScout then
  begin Category:=mctNone; exit end;
case mi.Domain of
  dGround:
    if mi.Speed>=250 then
      begin
      Category:=mctGroundAttacker;
      if mi.Attack=0 then Quality:=0
      else
        begin
        Quality:=trunc(100*(ln(mi.Attack)+ln(mi.Defense)+ln(mi.Speed/150)*1.7-ln(mi.Cost)));
        if mi.Cap and (1 shl (mcFanatic-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.5)));
        if mi.Cap and (1 shl (mcLongRange-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.5)));
        end
      end
    else
      begin
      Category:=mctGroundDefender;
      Quality:=trunc(100*(ln(mi.Defense)-ln(mi.Cost)*0.6));
      if mi.Cap and (1 shl (mcFanatic-mcFirstNonCap))<>0 then
        inc(Quality,trunc(100*ln(1.5)));
      end;
  dSea:
    if mi.Attack=0 then
      begin
      Category:=mctTransport;
      if mi.TTrans=0 then Quality:=0
      else
        begin
        EffectiveTransport:=mi.TTrans;
        if EffectiveTransport>4 then EffectiveTransport:=4; // rarely used more
        Quality:=100+trunc(100*(ln(EffectiveTransport)+ln(mi.Speed/150)+ln(mi.Defense)-ln(mi.Cost)));
        if mi.Cap and (1 shl (mcNav-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.5)));
        if mi.Cap and (1 shl (mcAirDef-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.3)));
        end
      end
    else
      begin
      Category:=mctCruiser;
      if mi.Attack=0 then Quality:=0
      else
        begin
        Quality:=trunc(100*(ln(mi.Attack)+ln(mi.Defense)*0.6-ln(mi.Cost)));
        if mi.Cap and (1 shl (mcNav-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.4)));
        if mi.Cap and (1 shl (mcAirDef-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.3)));
        if mi.Cap and (1 shl (mcLongRange-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(2.0)));
        if mi.Cap and (1 shl (mcRadar-mcFirstNonCap))<>0 then
          inc(Quality,trunc(100*ln(1.5)));
        end
      end;
  dAir:
    begin
    Category:=mctNone;
    Quality:=0
    end;
  end;
//!!!assert(Quality>0);
end;

procedure TAI.RateMyModel(mix: integer; var Category, Quality: integer);
var
mi: TModelInfo;
begin
MakeModelInfo(me,mix,MyModel[mix],mi);
RateModel(mi,Category,Quality);
end;

function TAI.IsBetterModel(const mi: TModelInfo): boolean;
var
mix,Cat,Quality,Cat1,Quality1: integer;
begin
RateModel(mi,Cat,Quality);
for mix:=0 to RO.nModel-1 do if mi.Domain=MyModel[mix].Domain then
  begin
  RateMyModel(mix,Cat1,Quality1);
  if (Cat=Cat1) and (Quality<Quality1+BetterQuality[Cat])then
    begin result:=false; exit end
  end;
result:=true;
end;

function TAI.ChooseResearchAdvance: integer;
var
adNext,iad,i,ad,Count,EarliestNeeded,EarliestNeeded_NoLeaveOut,
  NewResearch,StateOfArt,mix: integer;
mi: TModelInfo;
Entry: array[0..nAdv-1] of boolean;
ok: boolean;

  function MarkEntry(ad: integer): boolean;
  begin
  if RO.Tech[ad]>=tsApplicable then
    result:=false // nothing more to research here
  else if RO.Tech[ad]=tsSeen then
    begin
    Entry[ad]:=true;
    result:=true
    end
  else
    begin
    Entry[ad]:=true;
    if ad=adScience then
      begin
      if MarkEntry(adTheology) then Entry[ad]:=false;
      if MarkEntry(adPhilosophy) then Entry[ad]:=false;
      end
    else if ad=adMassProduction then
      begin
      if MarkEntry(adAutomobile) then Entry[ad]:=false;
      if Data.BehaviorFlags and bGender=bMale then
        begin if MarkEntry(adElectronics) then Entry[ad]:=false; end
      else begin if MarkEntry(adTheCorporation) then Entry[ad]:=false; end
      end
    else
      begin
      if AdvPreq[ad,0]>=0 then
        if MarkEntry(AdvPreq[ad,0]) then Entry[ad]:=false;
      if AdvPreq[ad,1]>=0 then
        if MarkEntry(AdvPreq[ad,1]) then Entry[ad]:=false;
      end;
    result:=true
    end
  end;

  procedure OptimizeDevModel(OptimizeCaps: integer);
  var
  f,Cat,OriginalCat,Quality,BestQuality,Best: integer;
  mi: TModelInfo;
  begin
  MakeModelInfo(me,0,RO.DevModel,mi);
  RateModel(mi,OriginalCat,BestQuality);
  repeat
    Best:=-1;
    for f:=0 to nFeature-1 do
      if (1 shl f and OptimizeCaps<>0)
        and ((Feature[f].Preq<0) or IsResearched(Feature[f].Preq)) // check prerequisite
        and (RO.DevModel.Weight+Feature[f].Weight<=RO.DevModel.MaxWeight)
        and not((f>=mcFirstNonCap) and (RO.DevModel.Cap[f]>0)) then
        begin
        if SetNewModelFeature(f,RO.DevModel.Cap[f]+1)>=rExecuted then
          begin
          MakeModelInfo(me,0,RO.DevModel,mi);
          RateModel(mi,Cat,Quality);
          assert(Cat=OriginalCat);
          if Quality>BestQuality then
            begin
            Best:=f;
            BestQuality:=Quality;
            end;
          SetNewModelFeature(f,RO.DevModel.Cap[f]-1)
          end
        end;
    if Best>=0 then
      SetNewModelFeature(Best,RO.DevModel.Cap[Best]+1)
  until Best<0
  end;

  function LeaveOutsMissing(ad: integer): boolean;
  var
  i: integer;
  begin
  result:=false;
  if RO.Tech[ad]<tsSeen then
    if ad in LeaveOutTechs then result:=true
    else if ad=adScience then
      begin
      result:=result or LeaveOutsMissing(adTheology);
      result:=result or LeaveOutsMissing(adPhilosophy);
      end
    else if ad=adMassProduction then
      result:=true
    else for i:=0 to 1 do
      if AdvPreq[ad,i]>=0 then
        result:=result or LeaveOutsMissing(AdvPreq[ad,i]);
  end;

begin
if Data.BehaviorFlags and bBarbarina<>0 then
  begin
  result:=Barbarina_ChooseResearchAdvance;
  if result>=0 then exit
  end;

SetAdvanceValues;

// always complete traded techs first
result:=-1;
for ad:=0 to nAdv-1 do
  if (RO.Tech[ad]=tsSeen)
    and ((result<0) or (AdvanceValue[ad]>AdvanceValue[result])) then
    result:=ad;
if result>=0 then exit;

if Data.BehaviorFlags and bBarbarina=0 then
  begin
  // develop new model?
  if IsResearched(adWarriorCode) and IsResearched(adHorsebackRiding)
    and not ((Data.BehaviorFlags and bGender=bMale) and (RO.Tech[adIronWorking]>=tsApplicable) // wait for gunpowder
      and (RO.Tech[adGunPowder]<tsApplicable)) then
    begin // check new ground models
    PrepareNewModel(dGround);
    SetNewModelFeature(mcDefense,1);
    SetNewModelFeature(mcOffense,2);
    SetNewModelFeature(mcMob,2);
    OptimizeDevModel(1 shl mcOffense+1 shl mcDefense+1 shl mcMob
      +1 shl mcLongRange+1 shl mcFanatic);
    MakeModelInfo(me,0,RO.DevModel,mi);
    if IsBetterModel(mi) then
      begin result:=adMilitary; exit end;

    PrepareNewModel(dGround);
    SetNewModelFeature(mcDefense,2);
    SetNewModelFeature(mcOffense,1);
    OptimizeDevModel(1 shl mcOffense+1 shl mcDefense+1 shl mcFanatic);
    MakeModelInfo(me,0,RO.DevModel,mi);
    if IsBetterModel(mi) then
      begin result:=adMilitary; exit end;
    end;

  if IsResearched(adMapMaking) and IsResearched(adSeafaring)
    and IsResearched(adNavigation) and IsResearched(adSteamEngine) then
    begin
    result:=adMilitary;
    for mix:=0 to RO.nModel-1 do if MyModel[mix].Cap[mcNav]>0 then result:=-1;
    if result=adMilitary then
      begin
      PrepareNewModel(dSea);
      SetNewModelFeature(mcWeapons,0);
      SetNewModelFeature(mcDefense,3);
      exit
      end
    end;

  (*
  if IsResearched(adMapMaking) and IsResearched(adSeafaring) then
    begin // check new naval models
    PrepareNewModel(dSea);
    if RO.DevModel.MTrans>1 then
      begin // new transport?
      SetNewModelFeature(mcDefense,2);
      SetNewModelFeature(mcOffense,2);
      SetNewModelFeature(mcSeaTrans,1);
      OptimizeDevModel(1 shl mcDefense+1 shl mcSeaTrans+1 shl mcTurbines
        +1 shl mcAirDef);
      MakeModelInfo(me,0,RO.DevModel,mi);
      if IsBetterModel(mi) then
        begin result:=adMilitary; exit end;
      end;

    // new cruiser?
    if IsResearched(adBallistics) or IsResearched(adGunPowder) then
      begin
      PrepareNewModel(dSea);
      SetNewModelFeature(mcDefense,1);
      SetNewModelFeature(mcOffense,2);
      OptimizeDevModel(1 shl mcOffense+1 shl mcDefense
        +1 shl mcLongRange+1 shl mcAirDef+1 shl mcRadar);
      MakeModelInfo(me,0,RO.DevModel,mi);
      if IsBetterModel(mi) then
        begin result:=adMilitary; exit end;
      end
    end;
  *)
  end;

NewResearch:=-1;

// check if cooperation with other gender doesn't work -- go for old needed techs then
StateOfArt:=-1;
for ad:=0 to nAdv-1 do
  if (RO.Tech[ad]>=tsApplicable) and (Advancedness[ad]>StateOfArt) then
    StateOfArt:=Advancedness[ad];
EarliestNeeded:=-1;
EarliestNeeded_NoLeaveOut:=-1;
for ad:=0 to nAdv-1 do
  if (RO.Tech[ad]<tsSeen) and (AdvanceValue[ad]>=$100)
    and ((EarliestNeeded<0)
      or (Advancedness[ad]<Advancedness[EarliestNeeded])) then
    begin
    ok:=false;
    for iad:=0 to nResearchOrder-1 do
      if ResearchOrder[Data.BehaviorFlags and bGender,iad]=ad then
        begin ok:=true; break; end;
    if not ok then
      begin
      EarliestNeeded:=ad;
      if not LeaveOutsMissing(ad) then
        EarliestNeeded_NoLeaveOut:=ad;
      end
    end;
if EarliestNeeded>=0 then
  begin
  if (EarliestNeeded_NoLeaveOut>=0)
    and (Advancedness[EarliestNeeded_NoLeaveOut]+ForceNeeded_NoLeaveOut<StateOfArt) then
    begin
    {$IFDEF DEBUG}DebugMessage(2,'No partner found, go for '
      +Name_Advance[EarliestNeeded_NoLeaveOut]);{$ENDIF}
    NewResearch:=EarliestNeeded_NoLeaveOut
    end
  else if Advancedness[EarliestNeeded]+ForceNeeded_LeaveOut<StateOfArt then
    begin
    {$IFDEF DEBUG}DebugMessage(2,'No partner found, go for '
      +Name_Advance[EarliestNeeded]);{$ENDIF}
    NewResearch:=EarliestNeeded
    end
  end;

// choose first directly researchable advance from own branch
adNext:=-1;
if NewResearch<0 then
  for iad:=0 to nResearchOrder-1 do
    begin
    ad:=ResearchOrder[Data.BehaviorFlags and bGender,iad];
    if RO.Tech[ad]<tsApplicable then
      begin
      if adNext<0 then adNext:=ad;
      if AdvPreq[ad,2]<>preNone then
        begin // 2 of 3 required
        count:=0;
        for i:=0 to 2 do
          if RO.Tech[AdvPreq[ad,i]]>=tsApplicable then inc(count);
        if count>=2 then
          begin result:=ad; exit end
        end
      else if ((AdvPreq[ad,0]=preNone) or (RO.Tech[AdvPreq[ad,0]]>=tsApplicable))
        and ((AdvPreq[ad,1]=preNone) or (RO.Tech[AdvPreq[ad,1]]>=tsApplicable)) then
        begin result:=ad; exit end
      end
    end;

if NewResearch<0 then
  if adNext>=0 then
    NewResearch:=adNext // need tech from other gender
  else if EarliestNeeded_NoLeaveOut>=0 then
    NewResearch:=EarliestNeeded_NoLeaveOut // own branch complete, pick tech from other gender
  else if EarliestNeeded>=0 then
    NewResearch:=EarliestNeeded // own branch complete, pick tech from other gender
  else
    begin // go for future techs
    result:=-1;
    i:=0;
    for ad:=nAdv-4 to nAdv-1 do
      if (RO.Tech[ad]<MaxFutureTech) and (RO.Tech[AdvPreq[ad,0]]>=tsApplicable) then
        begin
        inc(i);
        if random(i)=0 then result:=ad
        end;
    assert((result<0) or AdvanceResearchable(result));
    exit;
    end;

assert(NewResearch>=0);
fillchar(Entry, sizeof(Entry), false);
MarkEntry(NewResearch);
result:=-1;
for ad:=0 to nAdv-1 do
  if Entry[ad]
    and ((result<0) or (Advancedness[ad]>Advancedness[result])) then
    result:=ad;
assert(result>=0);
end;

function TAI.ChooseStealAdvance: integer;
var
ad: integer;
begin
result:=-1;
for ad:=0 to nAdv-1 do
  if AdvanceStealable(ad)
    and ((result<0) or (Advancedness[ad]>Advancedness[result])) then
    result:=ad
end;


//-------------------------------
//         TERRAFORMING
//-------------------------------

const
twpAllowFarmland=$0001;

procedure TAI.TileWorkPlan(Loc, cix: integer;
  var Value, NextJob, TotalWork: integer);
var
OldTile,TerrType: Cardinal;
TileInfo: TTileInfo;
begin
TotalWork:=0;
NextJob:=jNone;
if Map[Loc] and (fRare1 or fRare2)<>0 then
  begin Value:=3*8-1; exit end; // better than any tile with 2 food

OldTile:=Map[Loc];
TerrType:=Map[Loc] and fTerrain;
if (TerrType>=fGrass) then
  begin
  if Map[Loc] and fPoll<>0 then
    begin // clean pollution
    if NextJob=jNone then NextJob:=jPoll;
    inc(TotalWork,PollWork);
    Map[Loc]:=Map[Loc] and not fPoll;
    end;
  if Map[Loc] and (fTerrain or fSpecial)=fSwamp then
    begin // drain swamp
    if NextJob=jNone then NextJob:=jClear;
    inc(TotalWork,Terrain[TerrType].IrrClearWork);
    Map[Loc]:=Map[Loc] and not fTerrain or fGrass;
    TerrType:=fGrass;
    Map[Loc]:=Map[Loc] or
      Cardinal(SpecialTile(Loc,TerrType,G.lx) shl 5);
    end
  else if IsResearched(adExplosives)
    and (Map[Loc] and (fTerrain or fSpecial) in [fTundra,fHills])
    and (Map[Loc] and fTerImp<>tiMine)
    and (SpecialTile(Loc,fHills,G.lx)=0) then
    begin // transform
    if NextJob=jNone then NextJob:=jTrans;
    inc(TotalWork,Terrain[TerrType].TransWork);
    Map[Loc]:=Map[Loc] and not fTerrain or fGrass;
    TerrType:=fGrass;
    Map[Loc]:=Map[Loc] or
      Cardinal(SpecialTile(Loc,TerrType,G.lx) shl 5);
    end;
  if (Terrain[TerrType].MineEff>0) and (RO.Government<>gDespotism) then
    begin
    if Map[Loc] and fTerImp<>tiMine then
      begin // add mine
      if NextJob=jNone then NextJob:=jMine;
      inc(TotalWork,Terrain[TerrType].MineAfforestWork);
      Map[Loc]:=Map[Loc] and not fTerImp or tiMine;
      end
    end
  else if Terrain[TerrType].IrrEff>0 then
    begin
    if Map[Loc] and fTerImp=tiIrrigation then
      begin // add farmland
      if (MyCity[cix].Built[imSupermarket]>0) and IsResearched(adRefrigeration) 
        and (RO.Government<>gDespotism) then
        begin
        if NextJob=jNone then NextJob:=jFarm;
        inc(TotalWork,Terrain[TerrType].IrrClearWork*FarmWork);
        Map[Loc]:=Map[Loc] and not fTerImp or tiFarm;
        end
      end
    else if Map[Loc] and fTerImp<>tiFarm then
      begin // add irrigation
      if (RO.Government<>gDespotism)
        or (Map[Loc] and (fTerrain or fSpecial)<>fGrass) then
        begin
        if NextJob=jNone then NextJob:=jIrr;
        inc(TotalWork,Terrain[TerrType].IrrClearWork);
        Map[Loc]:=Map[Loc] and not fTerImp or tiIrrigation;
        end
      end
    end;
  if (Terrain[TerrType].MoveCost=1)
    and (Map[Loc] and (fRoad or fRR)=0)
    and ((Map[Loc] and fRiver=0) or IsResearched(adBridgeBuilding)) then
    begin // add road
    if NextJob=jNone then NextJob:=jRoad;
    inc(TotalWork,RoadWork);
    Map[Loc]:=Map[Loc] or fRoad;
    end;
  if ((Map[Loc] and fTerImp=tiMine)
      or (Terrain[TerrType].ProdRes[Map[Loc] shr 5 and 3]>=2))
    and IsResearched(adRailroad) 
    and (Map[Loc] and fRR=0)
    and ((Map[Loc] and fRiver=0) or IsResearched(adBridgeBuilding))
    and (RO.Government<>gDespotism) then
    begin // add railroad
    if Map[Loc] and fRoad=0 then
      begin
      if NextJob=jNone then NextJob:=jRoad;
      inc(TotalWork,RoadWork*Terrain[TerrType].MoveCost);
      end;
    if NextJob=jNone then NextJob:=jRR;
    inc(TotalWork,RRWork*Terrain[TerrType].MoveCost);
    Map[Loc]:=Map[Loc] and not fRoad or fRR;
    end;
  end;
Server(sGetTileInfo,me,Loc,TileInfo);
Value:=TileInfo.Food*8+TileInfo.Prod*2+TileInfo.Trade;
Map[Loc]:=OldTile;
end;

// ProcessSettlers: move settlers, do terrain improvement, found cities
procedure TAI.ProcessSettlers;
var
i,uix,cix,ecix,dtr,Loc,RadiusLoc,Special,Food,Prod,Trade,CityFood,Happy,
  TestScore,BestNearCityScore,BestUnusedValue,BestUnusedLoc,
  Value,NextJob,TotalWork,V21,part,Loc1: integer;
Tile: Cardinal;
FoodOk,Started: boolean;
Radius: TVicinity21Loc;
CityAreaInfo: TCityAreaInfo;
TileFood, ResourceScore, CityScore: array[0..lxmax*lymax-1] of integer;

  procedure AddJob(Loc,Job,Score: integer);
  // set Score=1 for low-priority jobs
  begin
  JobAssignment_AddJob(Loc,Job,Score);
  if (Score>1) and (District[Loc]>=0) and (District[Loc]<maxCOD) then
    dec(SettlerSurplus[District[Loc]]);
  end;

  procedure ReserveCityRadius(Loc: integer);
  var
  V21,RadiusLoc: integer;
  Radius: TVicinity21Loc;
  begin
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do
    begin
    RadiusLoc:=Radius[V21];
    if (RadiusLoc>=0) then
      begin
      ResourceScore[RadiusLoc]:=0;
      TileFood[RadiusLoc]:=0;
      end
    end
  end;

  procedure ScoreRoadConnections;
  var
  V8,nFragments,Loc,Loc1,History,RoadScore,a,b,FullyDeveloped,ConnectMask: integer;
  BridgeOk: boolean;
  Adjacent: TVicinity8Loc;
  begin
  BridgeOk:= IsResearched(adBridgeBuilding);
  if IsResearched(adRailroad) then FullyDeveloped:=fRR or fCity
  else FullyDeveloped:=fRoad or fRR or fCity;
  for Loc:=G.lx to G.lx*(G.ly-1)-1 do
    if ((1 shl (Map[Loc] and fTerrain)) and (1 shl fOcean or 1 shl fShore or 1 shl fDesert or 1 shl fArctic or 1 shl fUNKNOWN)=0)
      and (RO.Territory[Loc]=me)
      and (Map[Loc] and FullyDeveloped=0)
      and (BridgeOk or (Map[Loc] and fRiver=0)) then
      begin
      nFragments:=0;
      History:=0;
      if Map[Loc] and fRoad<>0 then ConnectMask:=fRR or fCity // check for railroad
      else ConnectMask:=fRoad or fRR or fCity; // check for road
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 9 do
        begin
        Loc1:=Adjacent[V8 and 7];
        History:=History shl 1;
        if (Loc1>=0) and (RO.Territory[Loc1]=me)
          and (Map[Loc1] and ConnectMask<>0) then
          begin
          inc(History);
          if V8>=2 then
            begin
            inc(nFragments);
            case V8 and 1 of
              0:
                if History and 6<>0 then
                  dec(nFragments);
              1:
                if History and 2<>0 then
                  dec(nFragments)
                else if History and 4<>0 then
                  begin
                  V8_to_ab((V8-1) and 7,a,b);
                  ab_to_Loc(Loc,a shl 1,b shl 1,Loc1);
                  if (Loc1>=0)
                    and (Map[Loc1] and ConnectMask<>0) then
                    dec(nFragments)
                  end
              end
            end;
          end;
        end;
      if nFragments>=2 then // road or railroad connection desirable
        begin
        if Map[Loc] and fRiver<>0 then RoadScore:=44+(nFragments-2)*4
        else RoadScore:=56-Terrain[Map[Loc] and fTerrain].MoveCost*4
          +(nFragments-2)*4;
        if Map[Loc] and fRoad<>0 then
          AddJob(Loc, jRR, RoadScore)
        else AddJob(Loc, jRoad, RoadScore)
        end;
      end;
  end;

begin
fillchar(SettlerSurplus, sizeof(SettlerSurplus), 0);
JobAssignment_Initialize;

if (Data.BehaviorFlags and bBarbarina=0) or (RO.nCity<3) then
  begin
  fillchar(TileFood,sizeof(TileFood),0);
  fillchar(ResourceScore,sizeof(ResourceScore),0);
  for Loc:=0 to MapSize-1 do
    if Map[Loc] and fTerrain<>fUNKNOWN then
      if Map[Loc] and fDeadLands<>0 then
        begin
        if not IsResearched(adMassProduction) or (Map[Loc] and fModern<>0) then
          ResourceScore[Loc]:=20;
        end
      else if Map[Loc] and fTerrain=fGrass then
        TileFood[Loc]:=Terrain[fGrass].FoodRes[Map[Loc] shr 5 and 3]-1
      else
        begin
        Special:=SpecialTile(Loc,Map[Loc] and fTerrain,G.lx);
        if Special<>0 then with Terrain[Map[Loc] and fTerrain] do
          begin
          Food:=FoodRes[Special];
          if MineEff=0 then inc(Food,IrrEff);
          Prod:=ProdRes[Special]+MineEff;
          Trade:=TradeRes[Special];
          if MoveCost=1 then inc(Trade);
          ResourceScore[Loc]:=Food+2*Prod+Trade-7;
          if Food>2 then TileFood[Loc]:=Food-2;
          end
        end;

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
    begin
    FoodOk:= (TileFood[Loc]>0)
      and ((Map[Loc] and fTerrain=fGrass)
          and ((RO.Government<>gDespotism) or (Map[Loc] and fSpecial=fSpecial1))
        or (Map[Loc] and (fTerrain or fSpecial)=fPrairie or fSpecial1));
    if FoodOk and ((RO.Territory[Loc]<0) or (RO.Territory[Loc]=me)) then
      begin
      TestScore:=0;
      CityFood:=0;
      BestNearCityScore:=0;
      V21_to_Loc(Loc,Radius);
      for V21:=1 to 26 do
        begin // sum resource scores in potential city radius
        RadiusLoc:=Radius[V21];
        if (RadiusLoc>=0) then
          begin
          inc(CityFood,TileFood[RadiusLoc]);
          if ResourceScore[RadiusLoc]>0 then
            inc(TestScore,ResourceScore[RadiusLoc]);
          if CityScore[RadiusLoc]>BestNearCityScore then
            BestNearCityScore:=CityScore[RadiusLoc]
          end
        end;
      if CityFood>=MinCityFood then // city is worth founding
        begin
        TestScore:=(72+2*TestScore) shl 8 + ((loc xor me)*4567) mod 251;
          // some unexactness, random but always the same for this tile
        if TestScore>BestNearCityScore then
          begin // better than all other sites in radius
          if BestNearCityScore>0 then // found no other cities in radius
            begin
            for V21:=1 to 26 do
              begin
              RadiusLoc:=Radius[V21];
              if (RadiusLoc>=0) then
                CityScore[RadiusLoc]:=0;
              end;
            end;
          CityScore[Loc]:=TestScore
          end;
        end
      end;
    end;
  for Loc:=0 to MapSize-1 do
    if CityScore[Loc]>0 then
      AddJob(Loc, jCity, CityScore[Loc] shr 8);
  end;

// improve terrain
for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
  begin // order terrain improvements
  BestUnusedValue:=0;
  City_GetAreaInfo(cix,CityAreaInfo);
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do if V21<>CityOwnTile then
    if 1 shl V21 and Tiles<>0 then
      begin // tile is being exploited!
      RadiusLoc:=Radius[V21];
      if not (Map[RadiusLoc] and fTerrain in [fDesert,fArctic]) then
        begin
        assert(RadiusLoc>=0);
        TileWorkPlan(RadiusLoc,cix,Value,NextJob,TotalWork);
        if (NextJob=jRoad)
          and (Built[imPalace]+Built[imCourt]+Built[imTownHall]=0) then
          AddJob(RadiusLoc, NextJob, 44)
        else if NextJob<>jNone then
          AddJob(RadiusLoc, NextJob, 84)
        end
      end
    else if CityAreaInfo.Available[V21]=faAvailable then
      begin // tile could be exploited
      RadiusLoc:=Radius[V21];
      assert(RadiusLoc>=0);
      if not (Map[RadiusLoc] and fTerrain in [fDesert,fArctic]) then
        begin
        TileWorkPlan(RadiusLoc,cix,Value,NextJob,TotalWork);
        Value:=Value shl 16 +$FFFF-TotalWork;
        if Value>BestUnusedValue then
          begin
          BestUnusedValue:=Value;
          BestUnusedLoc:=RadiusLoc;
          end
        end
      end;
  if BestUnusedValue>0 then
    begin
    TileWorkPlan(BestUnusedLoc,cix,Value,NextJob,TotalWork);
    if NextJob<>jNone then
      AddJob(BestUnusedLoc, NextJob, 44)
    end
  end;

ScoreRoadConnections;

if Data.BehaviorFlags and bBarbarina=0 then // low priority jobs
  for Loc:=0 to MapSize-1 do if RO.Territory[Loc]=me then
    begin
    Tile:=Map[Loc];
    if Tile and fPoll<>0 then
      AddJob(Loc, jPoll, 1)
    else case Tile and (fTerrain or fSpecial or fCity) of
      fGrass, fGrass+fSpecial1:
        if IsResearched(adExplosives) and (SpecialTile(Loc,fHills,G.lx)>0) then
          AddJob(Loc, jTrans, 1);
      fSwamp:
        if SpecialTile(Loc,fSwamp,G.lx)=0 then
          AddJob(Loc, jClear, 1);
      fTundra,fHills:
        if IsResearched(adExplosives) and (Tile and fTerImp<>tiMine)
          and (SpecialTile(Loc,fHills,G.lx)=0) then
          AddJob(Loc, jTrans, 1);
      end
    end;

// cities for colony ship production
if Data.BehaviorFlags and bBarbarina=bBarbarina then
  begin
  for part:=0 to nShipPart-1 do
    for i:=0 to ColonyShipPlan[part].nLocFoundCity-1 do
      begin
      Loc:=ColonyShipPlan[part].LocFoundCity[i];
      Started:=false;
      for uix:=0 to RO.nUn-1 do
        if (MyUnit[uix].Loc=Loc) and (MyUnit[uix].Job=jCity) then
          begin
          Started:=true;
          break
          end;
      if not Started then
        begin
        Tile:=RO.Map[Loc];
        if (Tile and fTerrain=fForest) or (Tile and fTerrain=fSwamp) then
          AddJob(Loc,jClear,235)
        else if Tile and fTerrain=fHills then
          begin
          if IsResearched(adExplosives) then
            AddJob(Loc,jTrans,235)
          end
        else AddJob(Loc,jCity,235);
        end;
      V21_to_Loc(Loc, Radius);
      for V21:=1 to 26 do
        begin
        Loc1:=Radius[V21];
        if (Loc1>=0) and (RO.Map[Loc1] and (fTerrain or fSpecial)=fSwamp) then
          AddJob(Loc1,jClear,255);
        end
      end
  end;

// choose all settlers to work
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and ((mix=mixSettlers) or (mix=mixSlaves)
    or (Data.BehaviorFlags and bBarbarina<>0) and (MyModel[mix].Kind=mkSettler)) then
    begin
    JobAssignment_AddUnit(uix);
    if (District[Loc]>=0) and (District[Loc]<maxCOD) then
      inc(SettlerSurplus[District[Loc]]);
    end;

JobAssignment_Go;

for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (Map[Loc] and fCity=0) and (Job=jNone)
    and ((mix=mixSettlers) or (mix=mixSlaves))
    and not JobAssignment_GotJob(uix) then
    Unit_MoveEx(uix, maNextCity);

//{$IFDEF DEBUG}DebugMessage(2, Format('Settler surplus in district 0: %d',[SettlerSurplus[0]]));{$ENDIF}

// add settlers to city
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (Map[Loc] and fCity<>0)
    and (MyModel[MyUnit[uix].mix].Kind=mkSettler) then
    begin
    dtr:=District[Loc];
    if (mix<>mixSettlers)
      or (dtr>=0) and (dtr<maxCOD)
      and (SettlerSurplus[dtr]>DistrictPopulation[dtr] div 8) then
      begin
      City_FindMyCity(Loc, cix);
      with MyCity[cix] do
        if (Built[imSewer]>0)
          or (Built[imAqueduct]>0) and (Size<=NeedSewerSize-2)
          or (Size<=NeedAqueductSize-2) then
          begin // settlers could be added to this city
          Happy:=BasicHappy;
          for i:=0 to 27 do if Built[i]>0 then inc(Happy);
          if Built[imTemple]>0 then inc(Happy);
          if Built[imCathedral]>0 then
            begin
            inc(Happy,2);
            if RO.Wonder[woBach].EffectiveOwner=me then inc(Happy,1)
            end;
          if Built[imTheater]>0 then inc(Happy,2);
          if (Built[imColosseum]>0) or (Happy shl 1>=Size+2) then
            begin // bigger city would be happy
//            {$IFDEF DEBUG}DebugMessage(2, Format('Adding settlers to city at %d',[Loc]));{$ENDIF}
            Unit_AddToCity(uix);
            if (dtr>=0) and (dtr<maxCOD) then dec(SettlerSurplus[dtr])
            end
          end;
      end
    end;
end; // ProcessSettlers


//-------------------------------
//            MY TURN
//-------------------------------

procedure TAI.DoTurn;
var
emix,i,p1,TaxSum,ScienceSum,NewTaxRate: integer;
AllHateMe: boolean;
{$IFDEF PERF}PF,t0,t1,t2,t3,t4,t5,t6,t7,t8,t9: int64;{$ENDIF}
begin
{$IFDEF DEBUG}fillchar(DebugMap, sizeof(DebugMap),0);{$ENDIF}

{$IFDEF PERF}QueryPerformanceFrequency(PF);{$ENDIF}
{$IFDEF PERF}QueryPerformanceCounter(t0);{$ENDIF}

WarNations:=PresenceUnknown;
for p1:=0 to nPl-1 do
  if (p1<>me) and (1 shl p1 and RO.Alive<>0) and (RO.Treaty[p1]<trPeace) then
    inc(WarNations,1 shl p1);
BombardingNations:=0;
for emix:=0 to RO.nEnemyModel-1 do with RO.EnemyModel[emix] do
  if (Domain=dSea) and (1 shl (mcLongRange-mcFirstNonCap) and Cap<>0) then
    BombardingNations:=BombardingNations or (1 shl Owner);
BombardingNations:=BombardingNations and WarNations;

AnalyzeMap;
//for i:=0 to MapSize-1 do DebugMap[i]:=Formation[i];

if (Data.BehaviorFlags and bBarbarina=0)
  and (RO.Tech[ResearchOrder[Data.BehaviorFlags and bGender,8]]<tsApplicable) then
  CheckGender;

if G.Difficulty[me]<MaxDiff then // not on beginner level
  begin
  if  (Data.LastResearchTech=adHorsebackRiding)
    and (RO.ResearchTech<0) and (random(6)=0)
    and (HavePort or (ContinentPresence[0] and not (1 shl me or PresenceUnknown)<>0)) then
    begin
    Data.BehaviorFlags:=Data.BehaviorFlags or bBarbarina_Hide;
    DebugMessage(1, 'Early Barbarina!');
    end;
  if Data.BehaviorFlags and bBarbarina=0 then
    begin
    AllHateMe:=false;
    for p1:=0 to nPl-1 do
      if (1 shl p1 and RO.Alive<>0) and (RO.Treaty[p1]>=trNone) then
        if (RO.Treaty[p1]<trPeace) and
          ((Data.RejectTurn[suContact,p1]>=0)
          or (Data.RejectTurn[suPeace,p1]>=0)) then
          AllHateMe:=true
        else begin AllHateMe:=false; break end;
    if AllHateMe then
      begin
      Data.BehaviorFlags:=Data.BehaviorFlags or bBarbarina_Hide;
      DebugMessage(1, 'All hate me!');
      end
    end;

  if Data.BehaviorFlags and bBarbarina=0 then
    if Barbarina_GoHidden then
      begin
      Data.BehaviorFlags:=Data.BehaviorFlags or bBarbarina_Hide;
      DebugMessage(1, 'Barbarina!');
      end;
  if Data.BehaviorFlags and bBarbarina=bBarbarina_Hide then
    if Barbarina_Go then
      begin
      Data.BehaviorFlags:=Data.BehaviorFlags or bBarbarina;
      DebugMessage(1, 'Barbarina - no mercy!');
      end;
  end;

{$IFDEF PERF}QueryPerformanceCounter(t1);{$ENDIF}

  // better government form available?
if (Data.BehaviorFlags and bBarbarina=0) and (RO.Turn>=LeaveDespotism)
  and (RO.Government<>gAnarchy) then
  if IsResearched(adDemocracy) then
    begin
    if RO.Government<>gDemocracy then
      Revolution //!!!
    end
  else if IsResearched(adTheRepublic) then
    begin
    if RO.Government<>gRepublic then
      Revolution
    end
  else if IsResearched(adMonarchy) then
    begin
    if RO.Government<>gMonarchy then
      Revolution
    end;

CollectModelCatStat;

if Data.BehaviorFlags and bBarbarina=bBarbarina then
  begin
  MakeColonyShipPlan;
  Barbarina_DoTurn
  end
else
  begin
  {$IFDEF PERF}QueryPerformanceCounter(t2);{$ENDIF}

  {$IFDEF PERF}QueryPerformanceCounter(t3);{$ENDIF}

  AttackAndPatrol;

  {$IFDEF PERF}QueryPerformanceCounter(t4);{$ENDIF}

  MoveUnitsHome;

  {$IFDEF PERF}QueryPerformanceCounter(t5);{$ENDIF}
  end;

ProcessSettlers;

{$IFDEF PERF}QueryPerformanceCounter(t6);{$ENDIF}

if Data.BehaviorFlags and bBarbarina<>0 then
  Barbarina_SetCityProduction
else
  SetCityProduction;

{$IFDEF PERF}QueryPerformanceCounter(t7);{$ENDIF}

// correct tax rate if necessary
if not IsResearched(adWheel) then
  ChangeRates(0,0)
else
  begin
  if (RO.TaxRate=0) or (RO.Money<(TotalPopulation[me]-4)*2) then
    NewTaxRate:=RO.TaxRate // don't check decreasing tax
  else NewTaxRate:=RO.TaxRate-10;
  while NewTaxRate<100 do
    begin
    SumCities(NewTaxRate,TaxSum,ScienceSum);
    if RO.Money+TaxSum>=(TotalPopulation[me]-4) then break; // enough
    inc(NewTaxRate,10);
    end;
  if NewTaxRate<>RO.TaxRate then
    begin
  //  {$IFDEF DEBUG}DebugMessage(3,Format('New tax rate: %d',[NewTaxRate]));{$ENDIF}
    ChangeRates(NewTaxRate,0)
    end;
  end;

// clean up RequestedTechs
if (Data.LastResearchTech>=0)
  and (Data.LastResearchTech<>RO.ResearchTech) then // research completed
  for p1:=0 to nPl-1 do
    if (p1<>me) and (1 shl p1 and RO.Alive<>0)
      and (RO.EnemyReport[p1].TurnOfCivilReport+TechReportOutdated>RO.Turn)
      and (RO.EnemyReport[p1].Tech[Data.LastResearchTech]<tsSeen) then
      begin // latest researched advance might be of interest to this nation
      for i:=0 to nRequestedTechs-1 do
        if (Data.RequestedTechs[i]>=0)
          and (Data.RequestedTechs[i] shr 8 and $F=p1) then
          Data.RequestedTechs[i]:=-1;
      end;
if RO.ResearchTech=adMilitary then Data.LastResearchTech:=-1
else Data.LastResearchTech:=RO.ResearchTech;
for i:=0 to nRequestedTechs-1 do
  if (Data.RequestedTechs[i]>=0)
    and (RO.Tech[Data.RequestedTechs[i] and $FF]>=tsSeen) then
    Data.RequestedTechs[i]:=-1;

// prepare negotiation
AdvanceValuesSet:=false;
SetAdvanceValues;


{$IFDEF DEBUG}
(*for p1:=0 to nPl-1 do
  if (p1<>me) and (1 shl p1 and RO.Alive<>0) and (RO.Treaty[p1]>=trPeace)
    and (RO.EnemyReport[p1].TurnOfCivilReport>=0) then
    TraceAdvanceValues(p1);*)
{$ENDIF}

{$IFDEF PERF}DebugMessage(2,Format('t1=%d t2=%d t3=%d t4=%d t5=%d t6=%d t7=%d t8=%d t9=%d (ns)',[(t1-t0)*1000000 div PF,(t2-t1)*1000000 div PF,(t3-t2)*1000000 div PF,(t4-t3)*1000000 div PF,(t5-t4)*1000000 div PF,(t6-t5)*1000000 div PF,(t7-t6)*1000000 div PF,(t8-t7)*1000000 div PF,(t9-t8)*1000000 div PF]));{$ENDIF}
end;

{$IFDEF DEBUG}
procedure TAI.TraceAdvanceValues(Nation: integer);
var
ad: integer;
begin
for ad:=0 to nAdv-1 do
  if (RO.Tech[ad]<tsSeen) and (RO.EnemyReport[Nation].Tech[ad]>=tsApplicable)
    and (AdvanceValue[ad]>0) then
    begin
    DebugMessage(2,Format('%s (%d): +%x',
      [Name_Advance[ad], Advancedness[ad], AdvanceValue[ad]]))
    end
end;
{$ENDIF}


procedure TAI.CheckGender;
var
p1,NewGender: integer;
begin
NewGender:=-1;
for p1:=0 to nPl-1 do
  if (p1<>me) and (1 shl p1 and RO.Alive<>0)
    and (RO.Treaty[p1]>=trFriendlyContact) then
    if PlayerHash[me]>PlayerHash[p1] then
      begin
      if NewGender=bMale then
        begin NewGender:=-2; break end; // ambiguous, don't change gender
      NewGender:=bFemale;
      end
    else
      begin
      if NewGender=bFemale then
        begin NewGender:=-2; break end; // ambiguous, don't change gender
      NewGender:=bMale;
      end;
if (NewGender>=0) and (NewGender<>Data.BehaviorFlags and bGender) then
  begin
  Data.BehaviorFlags:=Data.BehaviorFlags and not bGender or NewGender;
  DebugMessage(1, 'Gender:='+char(48+NewGender));
  end
end;


procedure TAI.SetAdvanceValues;

  procedure RateResearchAdv(ad, Time: integer);
  var
  Value: integer;
  begin
  if Time=0 then Value:=TechValue_ForResearch_Next
  else Value:=TechValue_ForResearch-Time;
  if AdvanceValue[ad]<Value then
    AdvanceValue[ad]:=Value;
  end;

  procedure SetPreqValues(ad, Value: integer);
  begin
  if (RO.Tech[ad]<tsSeen) and (ad<>RO.ResearchTech) then
    begin
    if AdvanceValue[ad]<Value then
      AdvanceValue[ad]:=Value;
    if ad=adScience then
      begin
      SetPreqValues(adTheology,Value-1);
      SetPreqValues(adPhilosophy,Value-1);
      end
    else if ad=adMassProduction then
      // preqs should be researched now
    else
      begin
      if AdvPreq[ad,0]>=0 then
        SetPreqValues(AdvPreq[ad,0],Value-1);
      if AdvPreq[ad,1]>=0 then
        SetPreqValues(AdvPreq[ad,1],Value-1);
      end;
    end
  end;

  procedure RateImpPreq(iix, Value: integer);
  begin
  if (Value>0) and (Imp[iix].Preq>=0) then
    inc(AdvanceValue[Imp[iix].Preq],Value);
  end;

var
emix,cix,adMissing,iad,ad,count,i,Time,d,CurrentCost,CurrentStrength,
  MaxSize, MaxTrade: integer;
PreView,Emergency,Bombarded: boolean;
begin
if AdvanceValuesSet then exit;
AdvanceValuesSet:=true;

fillchar(AdvanceValue,sizeof(AdvanceValue),0);

// rate techs to ensure research progress
Time:=0;
for ad:=0 to nAdv-1 do if RO.Tech[ad]=tsSeen then inc(Time);
adMissing:=-1;
Emergency:=true;
for iad:=0 to nResearchOrder-1 do
  begin
  ad:=ResearchOrder[Data.BehaviorFlags and bGender,iad];
  if (ad<>RO.ResearchTech) and (RO.Tech[ad]<tsSeen) then
    begin
    if adMissing<0 then adMissing:=ad;
    RateResearchAdv(ad,Time); // unseen tech of own gender
    if AdvPreq[ad,2]<>preNone then
      begin // 2 of 3 required
      count:=0;
      for i:=0 to 2 do
        if (AdvPreq[ad,i]=RO.ResearchTech)
          or (RO.Tech[AdvPreq[ad,i]]>=tsSeen) then
          inc(count);
      if count>=2 then Emergency:=false
      else
        begin
        if ad<>adMassProduction then // don't score third preq for MP
          begin
          for i:=0 to 2 do
            if (AdvPreq[ad,i]<>RO.ResearchTech)
              and (RO.Tech[AdvPreq[ad,i]]<tsSeen) then
              RateResearchAdv(AdvPreq[ad,i],Time);
          end;
        inc(Time,2-count)
        end
      end
    else
      begin
      count:=0;
      for i:=0 to 1 do
        if (AdvPreq[ad,i]<>preNone) and (AdvPreq[ad,i]<>RO.ResearchTech)
          and (RO.Tech[AdvPreq[ad,i]]<tsSeen) then
          begin
          RateResearchAdv(AdvPreq[ad,i],Time);
          inc(count)
          end;
      if count=0 then Emergency:=false;
      inc(Time,count);
      end;
    inc(Time,2);
    end
  end;
if Emergency and (adMissing>=0) then
  begin
  {$IFDEF DEBUG}DebugMessage(2, 'Research emergency: Go for'
    +Name_Advance[adMissing]+' now!');{$ENDIF}
  SetPreqValues(adMissing, TechValue_ForResearch_Urgent);
  end;
for iad:=0 to nResearchOrder-1 do
  begin
  ad:=ResearchOrder[Data.BehaviorFlags and bGender xor 1,iad];
  if ad=adScience then
    inc(AdvanceValue[ad], 5*TechValue_ForResearch_LeaveOut)
  else if LeaveOutValue[ad]>0 then
    if AdvanceValue[ad]>0 then
      inc(AdvanceValue[ad], LeaveOutValue[ad]*TechValue_ForResearch_LeaveOut)
//    else AdvanceValue[ad]:=1;
  end;

// rate military techs
for d:=0 to nDomains-1 do
  begin
  CurrentCost:=0;
  CurrentStrength:=0;
  for PreView:=true downto false do
    for i:=0 to nUpgrade-1 do with Upgrade[d,i] do
      if (Preq>=0) and not (Preq in FutureTech) then
        if ((Ro.ResearchTech=Preq) or (RO.Tech[Preq]>=tsSeen)) = PreView then
          if PreView then
            begin
            if Cost>CurrentCost then CurrentCost:=Cost;
            inc(CurrentStrength, Strength);
            end
          else
            begin // rate
            if (i>0) and (Trans>0) then inc(AdvanceValue[Preq],$400);
            if Cost<=CurrentCost then
              inc(AdvanceValue[Preq], (4-d)*Strength*$400 div (CurrentStrength+Upgrade[d,0].Strength))
            else inc(AdvanceValue[Preq], (4-d)*Strength*$200 div (CurrentStrength+Upgrade[d,0].Strength))
            end;
  end;
// speed
inc(AdvanceValue[adSteamEngine],$400);
inc(AdvanceValue[adNuclearPower],$400);
inc(AdvanceValue[adRocketry],$400);
// features
inc(AdvanceValue[adBallistics],$800);
inc(AdvanceValue[adCommunism],$800);
// weight
inc(AdvanceValue[adAutomobile],$800);
inc(AdvanceValue[adSteel],$800);
inc(AdvanceValue[adAdvancedFlight],$400);

// civil non-improvement
if RO.Turn>=LeaveDespotism then
  begin
  inc(AdvanceValue[adDemocracy],$80*RO.nCity);
  inc(AdvanceValue[adTheRepublic],$800);
  end;
inc(AdvanceValue[adRailroad],$800);
// inc(AdvanceValue[adExplosives],$800); // no, has enough 
inc(AdvanceValue[adBridgeBuilding],$200);
inc(AdvanceValue[adSpaceFlight],$200);
inc(AdvanceValue[adSelfContainedEnvironment],$200);
inc(AdvanceValue[adImpulseDrive],$200);
inc(AdvanceValue[adTransstellarColonization],$200);

// city improvements
MaxSize:=0;
for cix:=0 to RO.nCity-1 do
  if MyCity[cix].Size>MaxSize then
    MaxSize:=MyCity[cix].Size;
if RO.Government in [gRepublic,gDemocracy,gLybertarianism] then
  MaxTrade:=(MaxSize-1)*3
else MaxTrade:=(MaxSize-1)*2;

RateImpPreq(imCourt,(RO.nCity-1)*$100);
RateImpPreq(imLibrary,(MaxTrade-10)*$180);
RateImpPreq(imMarket,(MaxTrade-10)*$140);
RateImpPreq(imUniversity,(MaxTrade-10)*$140);
RateImpPreq(imBank,(MaxTrade-10)*$100);
RateImpPreq(imObservatory,(MaxTrade-10)*$100);
RateImpPreq(imResLab,(MaxTrade-14)*$140);
RateImpPreq(imStockEx,(MaxTrade-10)*$10*(RO.nCity-1));
RateImpPreq(imHighways,(MaxSize-5)*$200);
RateImpPreq(imFactory,(MaxSize-8)*$200);
RateImpPreq(imMfgPlant,(MaxSize-8)*$1C0);
RateImpPreq(imRecycling,(MaxSize-8)*$180);
RateImpPreq(imHarbor,(MaxSize-7)*$200);
RateImpPreq(imSuperMarket,$300);
if RO.Turn>=40 then RateImpPreq(imTemple,$400);
if RO.Government<>gDespotism then
  begin
  RateImpPreq(imCathedral,$400);
  RateImpPreq(imTheater,$400);
  end;
if MaxSize>=NeedAqueductSize-1 then
  begin
  RateImpPreq(imAqueduct,$600);
  RateImpPreq(imGrWall,$300);
  end;
if cixStateImp[imPalace]>=0 then
  with MyCity[cixStateImp[imPalace]] do
    if (Built[imColosseum]+Built[imObservatory]>0) and (Size>=NeedSewerSize-1) then
      RateImpPreq(imSewer,$400);
Bombarded:=false;
for emix:=0 to RO.nEnemyModel-1 do
  if 1 shl (mcLongRange-mcFirstNonCap) and RO.EnemyModel[emix].Cap<>0 then
    Bombarded:=true;
if Bombarded then
  RateImpPreq(imCoastalFort,$400);
end;

procedure TAI.AnalyzeMap;
var
cix,Loc,Loc1,V8,f1,p1: integer;
Adjacent: TVicinity8Loc;
begin
inherited AnalyzeMap;

// collect nation presence information for continents and oceans
fillchar(ContinentPresence, sizeof(ContinentPresence), 0);
fillchar(OceanPresence, sizeof(OceanPresence), 0);
for Loc:=0 to MapSize-1 do
  begin
  f1:=Formation[Loc];
  case f1 of
    0..maxCOD-1:
      begin
      p1:=RO.Territory[Loc];
      if p1>=0 then
        if Map[Loc] and fTerrain>=fGrass then
          ContinentPresence[f1]:=ContinentPresence[f1] or (1 shl p1)
        else OceanPresence[f1]:=OceanPresence[f1] or (1 shl p1);
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

fillchar(TotalPopulation, sizeof(TotalPopulation), 0);
fillchar(ContinentPopulation, sizeof(ContinentPopulation), 0);
fillchar(DistrictPopulation, 4*nDistrict, 0);

// count population
for cix:=0 to RO.nEnemyCity-1 do with RO.EnemyCity[cix] do if Loc>=0 then
  begin
  inc(TotalPopulation[Owner],Size);
  if (Formation[Loc]>=0) and (Formation[Loc]<maxCOD) then
    inc(ContinentPopulation[Owner,Formation[Loc]],Size);
  end;
for cix:=0 to RO.nCity-1 do with RO.City[cix] do if Loc>=0 then
  begin
  inc(TotalPopulation[me],Size);
  assert(District[Loc]>=0);
  if District[Loc]<maxCOD then
    inc(DistrictPopulation[District[Loc]],Size);
  end;
end;

procedure TAI.CollectModelCatStat;
var
i,uix,Cat,mix,Quality: integer;
begin
// categorize models
for Cat:=0 to nModelCat-1 do
  ModelBestQuality[Cat]:=0;
mixCaravan:=-1;
mixSlaves:=-1;
mixCruiser:=-1;
for mix:=0 to RO.nModel-1 do
  begin
  ModelCat[mix]:=mctNone;
  if mix=1 then mixMilitia:=mix
  else
    case MyModel[mix].Kind of
      $00..$0F: // common units
        if MyModel[mix].Cap[mcNav]>0 then mixCruiser:=mix // temporary!!!
        else
          begin
          RateMyModel(mix,Cat,Quality);
          ModelCat[mix]:=Cat;
          ModelQuality[mix]:=Quality;
          if (Cat>=0) and (Quality>ModelBestQuality[Cat]) then
            ModelBestQuality[Cat]:=Quality;
          end;
      mkSpecial_TownGuard: mixTownGuard:=mix;
      mkSettler: mixSettlers:=mix; // engineers always have higher mix
      mkCaravan: mixCaravan:=mix;
      mkSlaves: mixSlaves:=mix
      end
  end;

// mark obsolete models with quality=0
for mix:=0 to RO.nModel-1 do
  if (MyModel[mix].Kind<$10) and (ModelCat[mix]>=0)
    and (ModelQuality[mix]+MaxExistWorseThanBestModel
      < ModelBestQuality[ModelCat[mix]]) then
    ModelQuality[mix]:=ModelQuality[mix]-$40000000;

OceanWithShip:=0;
if mixCruiser>=0 then
  for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
    if (Loc>=0) and (mix=mixCruiser) and (Map[Loc] and fTerrain<fGrass) then
      begin
      i:=Formation[Loc];
      if (i>=0) and (i<maxCOD) then OceanWithShip:=OceanWithShip or (1 shl i)
      end;
end;


procedure TAI.MoveUnitsHome;
const
PatrolDestination=lxmax*lymax;
FirstSurplusLoop: array[mctGroundDefender..mctGroundAttacker] of integer= (2,1);
var
Cat,i,mix,cix,uix,Loop,nModelOrder: integer;
Adjacent: TVicinity8Loc;
LocNeed: array[0..lxmax*lymax-1] of shortint;
Destination: array[0..nUmax-1] of integer;
DistrictNeed,DistrictNeed0: array[0..maxCOD-1] of integer;
ModelOrder: array[0..nMmax-1] of integer;
complete,Fortified: boolean;

  function IsBombarded(cix: integer): boolean;
  var
  Loc1,V8: integer;
  Adjacent: TVicinity8Loc;
  begin
  result:=false;
  if BombardingNations<>0 then with MyCity[cix] do
    begin
    V8_to_Loc(Loc,Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1>=0) and (Map[Loc1] and fTerrain<fGrass)
        and (Formation[Loc1]>=0) and (Formation[Loc1]<maxCOD)
        and (OceanPresence[Formation[Loc1]] and (BombardingNations or PresenceUnknown)<>0) then
        begin result:=true; exit end
      end;
    end;
  end;

  procedure TryUtilize(uix: integer);
  var
  cix, ProdCost, UtilizeCost: integer;
  begin
  if (MyUnit[uix].Health=100)
    and (Map[MyUnit[uix].Loc] and (fCity or fOwned)=fCity or fOwned) then
    begin
    City_FindMyCity(MyUnit[uix].Loc,cix);
    with MyCity[cix] do if Project and cpImp=0 then
      begin
      ProdCost:=MyModel[Project and cpIndex].Cost;
      UtilizeCost:=MyModel[MyUnit[uix].mix].Cost;
      if Prod<(ProdCost-UtilizeCost*2 div 3)*BuildCostMod[G.Difficulty[me]] div 12 then
        Unit_Disband(uix);
      end
    end
  end;

  procedure FindDestination(uix: integer);
  var
  MoveStyle,V8,Loc1,Time,NextLoc,NextTime,RecoverTurns: integer;
  Reached: array[0..lxmax*lymax-1] of boolean;
  begin
  fillchar(Reached, MapSize, false);
  Pile.Create(MapSize);
  with MyUnit[uix] do
    begin
    Pile.Put(Loc, $800-Movement);
    MoveStyle:=GetMyMoveStyle(mix, 100);
    end;
  while Pile.Get(Loc1, Time) do
    begin
    if LocNeed[Loc1]>0 then
      begin
      LocNeed[Loc1]:=0;
      if (District[Loc1]>=0) and (District[Loc1]<maxCOD) then
        begin
        assert(DistrictNeed[District[Loc1]]>0);
        dec(DistrictNeed[District[Loc1]]);
        end;
      Destination[uix]:=Loc1;
      break;
      end;
    Reached[Loc1]:=true;
    V8_to_Loc(Loc1, Adjacent);
    for V8:=0 to 7 do
      begin
      NextLoc:=Adjacent[V8];
      if (NextLoc>=0) and not Reached[NextLoc] and (RO.Territory[NextLoc]=me) then
        case CheckStep(MoveStyle, Time, V8 and 1, NextTime, RecoverTurns, Map[Loc1], Map[NextLoc], false) of
          csOk:
            Pile.Put(NextLoc, NextTime);
          csForbiddenTile:
            Reached[NextLoc]:=true; // don't check moving there again
          csCheckTerritory:
            assert(false);
          end
      end;
    end;
  Pile.Free;
  end;

begin
if not (RO.Government in [gAnarchy, gDespotism]) then // utilize townguards
  for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
    if (Loc>=0) and (Master<0) and (mix=mixTownGuard) then
    Unit_Disband(uix);

fillchar(UnitLack,sizeof(UnitLack),0);
fillchar(Destination, 4*RO.nUn, $FF);
for i:=0 to maxCOD-1 do
  if uixPatrol[i]>=0 then
    Destination[uixPatrol[i]]:=PatrolDestination;
for uix:=0 to RO.nUn-1 do
  if (MyUnit[uix].mix=mixMilitia) or (MyUnit[uix].mix=mixCruiser) then
    Destination[uix]:=PatrolDestination;

// distribute attackers and defenders
for Cat:=mctGroundDefender to mctGroundAttacker do
  begin
  nModelOrder:=0;
  for mix:=0 to Ro.nModel-1 do
    if ModelCat[mix]=Cat then
      begin
      i:=nModelOrder;
      while (i>0) and (ModelQuality[mix]<ModelQuality[ModelOrder[i-1]]) do
        begin ModelOrder[i]:=ModelOrder[i-1]; dec(i) end;
      ModelOrder[i]:=mix;
      inc(nModelOrder);
      end;

  Loop:=0;
  repeat
    if Loop=FirstSurplusLoop[Cat] then
      for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
        if (Loc>=0) and (Destination[uix]<0) and (Master<0)
          and (ModelCat[mix]=Cat)
          and (ModelQuality[mix]<0) then
          TryUtilize(uix);

    fillchar(LocNeed, MapSize, 0);
    fillchar(DistrictNeed, sizeof(DistrictNeed), 0);

    for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
      if ((Cat<>mctGroundDefender) or (Loop<>0) or IsBombarded(cix))
        and ((Loop<>FirstSurplusLoop[Cat]) or (Built[imBarracks]+Built[imMilAcademy]>0))
        and ((Loop<>FirstSurplusLoop[Cat]+1) or (Built[imBarracks]+Built[imMilAcademy]=0)) then
        begin
        LocNeed[Loc]:=1;
        if (District[Loc]>=0) and (District[Loc]<maxCOD) then
          begin
          inc(DistrictNeed[District[Loc]]);
          if Loop<FirstSurplusLoop[Cat] then
            inc(UnitLack[District[Loc],Cat])
          end
        end;

    if Loop=0 then // protect city building sites
      for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
        if (Loc>=0) and (Job=jCity) and (RO.Territory[Loc]=me) then
          begin
          LocNeed[Loc]:=1;
          if (District[Loc]>=0) and (District[Loc]<maxCOD) then
            inc(DistrictNeed[District[Loc]]);
          end;

    complete:= Loop>=FirstSurplusLoop[Cat];
    for i:=nModelOrder-1 downto 0 do
      begin
      for Fortified:=true downto false do
        for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
          if (mix=ModelOrder[i])
            and (Loc>=0) and (Destination[uix]<0) and (Master<0)
            and ((Flags and unFortified<>0) = Fortified)
            and (LocNeed[Loc]>0) then
            begin
            LocNeed[Loc]:=0;
            if (District[Loc]>=0) and (District[Loc]<maxCOD) then
              dec(DistrictNeed[District[Loc]]);
            Destination[uix]:=Loc;
            complete:=false;
            end;

      for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
        if (mix=ModelOrder[i])
          and (Loc>=0) and (Destination[uix]<0) and (Master<0) then
          if (District[Loc]>=0) and (District[Loc]<maxCOD)
            and (DistrictNeed[District[Loc]]=0) then
          else
            begin // unassigned unit
            FindDestination(uix);
            if Destination[uix]>=0 then complete:=false;
            end;
      end;
    inc(Loop)
  until complete;
  end;

// distribute obsolete settlers
repeat
  fillchar(LocNeed, MapSize, 0);
  fillchar(DistrictNeed, sizeof(DistrictNeed), 0);

  for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
    if (Built[imSewer]>0)
      or (Built[imAqueduct]>0) and (Size<=NeedSewerSize-2)
      or (Size<=NeedAqueductSize-2)
      or (Project=mixSettlers) then
      begin
      LocNeed[Loc]:=1;
      if (District[Loc]>=0) and (District[Loc]<maxCOD) then
        inc(DistrictNeed[District[Loc]]);
      end;
  DistrictNeed0:=DistrictNeed;

  complete:=true;
  for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
    if (Loc>=0) and (Destination[uix]<0) and (Master<0) then
      if (MyModel[mix].Kind=mkSettler) and (mix<>mixSettlers)
        and (Job=jNone) then
        if (District[Loc]>=0) and (District[Loc]<maxCOD)
          and (DistrictNeed[District[Loc]]=0) then
          begin
          if DistrictNeed0[District[Loc]]>0 then
            complete:=false
          end
        else
          begin // unassigned unit
          FindDestination(uix);
//          if (Destination[uix]<0) and (RO.Territory[Loc]=me) then
//            complete:=false; // causes hangup when unit can't move due to zoc
          end;
until complete;

for uix:=0 to RO.nUn-1 do with MyUnit[uix] do if Loc>=0 then
  if Destination[uix]<0 then
    begin
    if (MyModel[mix].Kind<>mkSettler) and (MyModel[mix].Kind<>mkSlaves)
      and (Master<0) and (Map[Loc] and fCity=0) then
      Unit_MoveEx(uix, maNextCity);
    end
  else if (Destination[uix]<>PatrolDestination) and (Loc<>Destination[uix]) then
    Unit_MoveEx(uix, Destination[uix]);

for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (RO.Territory[Loc]=me)
    and (District[Loc]>=0) and (District[Loc]<maxCOD)
    and (ModelQuality[mix]>0) then
    case ModelCat[mix] of
      mctGroundDefender,mctGroundAttacker:
        dec(UnitLack[District[Loc],ModelCat[mix]])
      end;
end; // MoveUnitsHome


procedure TAI.CheckAttack(uix: integer);
var
AttackScore,BestCount,AttackLoc,TestLoc,NextLoc,TestTime,V8,
  TestScore,euix,MyDamage,EnemyDamage,OldLoc,
  AttackForecast,MoveResult,AttackResult,MoveStyle,NextTime,RecoverTurns: integer;
Tile: Cardinal;
Exhausted: boolean;
Adjacent: TVicinity8Loc;
Reached: array[0..lxmax*lymax-1] of boolean;

begin
with MyUnit[uix] do
  begin
  MoveStyle:=GetMyMoveStyle(mix,Health);
  repeat
    AttackScore:=-999999;
    AttackLoc:=-1;
    fillchar(Reached, MapSize, false);
    Pile.Create(MapSize);
    Pile.Put(Loc, $800-Movement); // start search for something to do at current location
    while Pile.Get(TestLoc,TestTime) do
      begin
      BestCount:=0;
      TestScore:=0;
      Tile:=Map[TestLoc];
      Reached[TestLoc]:=true;

      if ((Tile and fUnit)<>0) and ((Tile and fOwned)=0) then
        begin // enemy unit
        assert(TestTime<$1000);
        Unit_FindEnemyDefender(TestLoc,euix);
        if RO.Treaty[RO.EnemyUn[euix].Owner]<trPeace then
          if Unit_AttackForecast(uix,TestLoc,$800-TestTime,AttackForecast) then
            begin // attack possible, but advantageous?
            if AttackForecast=0 then
              begin // enemy unit would be destroyed
              MyDamage:=Health+DestroyBonus;
              EnemyDamage:=RO.EnemyUn[euix].Health+DestroyBonus;
              end
            else if AttackForecast>0 then
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
              if TestScore>AttackScore then
                BestCount:=0;
              if TestScore>=AttackScore then
                begin
                inc(BestCount);
                if random(BestCount)=0 then
                  begin
                  AttackScore:=TestScore;
                  AttackLoc:=TestLoc;
                  end
                end;
              end
            end;
        end // enemy unit

      else if ((Tile and fCity)<>0) and ((Tile and fOwned)=0) then
        // enemy city

      else
        begin // no enemy city or unit here
        V8_to_Loc(TestLoc,Adjacent);
        for V8:=0 to 7 do
          begin
          NextLoc:=Adjacent[V8];
          if (NextLoc>=0) and not Reached[NextLoc]
            and (Map[NextLoc] and fTerrain<>fUNKNOWN) then
            if Map[NextLoc] and (fUnit or fOwned)=fUnit then
              Pile.Put(NextLoc, TestTime) // foreign unit!
            else case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime,
              RecoverTurns, Map[Loc], Map[NextLoc], true) of
              csOk,csCheckTerritory:
                if NextTime<$1000 then Pile.Put(NextLoc, NextTime);
              csForbiddenTile:
                Reached[NextLoc]:=true; // don't check moving there again
              end
          end;
        end; // no enemy city or unit here
      end; // while Pile.Get
    Pile.Free;

    if AttackLoc>=0 then
      begin
      OldLoc:=Loc;
      MoveResult:=Unit_Move(uix,AttackLoc);
      Exhausted:= (Loc=OldLoc)
        or ((MoveResult and (rMoreTurns or rUnitRemoved))<>0);
      if MoveResult and rLocationReached<>0 then
        if Movement<100 then
          Exhausted:=true
        else
          begin
          AttackResult:=Unit_Attack(uix,AttackLoc);
          Exhausted:= ((AttackResult and rExecuted)=0)
            or ((AttackResult and rUnitRemoved)<>0);
          end;
      end
    else Exhausted:=true;
  until Exhausted;
  end;
end; // CheckAttack


procedure TAI.Patrol(uix: integer);
const
DistanceScore=4;
var
PatrolScore,BestCount,PatrolLoc,TestLoc,NextLoc,TestTime,V8,
  TestScore,OldLoc,MoveResult,MoveStyle,NextTime,RecoverTurns: integer;
Tile: Cardinal;
Exhausted,CaptureOnly: boolean;
Adjacent: TVicinity8Loc;
AdjacentUnknown: array[0..lxmax*lymax-1] of shortint;

begin
with MyUnit[uix] do
  begin
  CaptureOnly:= ((100-Health)*Terrain[Map[Loc] and fTerrain].Defense>60)
    and not (Map[Loc] and fTerrain in [fOcean, fShore, fArctic, fDesert]);
  MoveStyle:=GetMyMoveStyle(mix, Health);
  repeat
    BestCount:=0;
    PatrolScore:=-999999;
    PatrolLoc:=-1;
    FillChar(AdjacentUnknown,MapSize,$FF); // -1, indicates tiles not checked yet
    Pile.Create(MapSize);
    Pile.Put(Loc, $800-Movement);
    while Pile.Get(TestLoc,TestTime) do
      begin
      if (50*$1000-DistanceScore*TestTime<=PatrolScore) // assume a score of 50 is the best achievable
        or CaptureOnly and (TestTime>=$1000) then
        break;

      TestScore:=0;
      Tile:=Map[TestLoc];
      AdjacentUnknown[TestLoc]:=0;

      if ((Tile and fUnit)<>0) and ((Tile and fOwned)=0) then
        // enemy unit

      else if ((Tile and fCity)<>0) and ((Tile and fOwned)=0) then
        begin
        if ((Tile and fObserved)<>0)
          and (MyModel[mix].Domain=dGround) and (MyModel[mix].Attack>0)
          and ((RO.Territory[TestLoc]<0) // happens only for unobserved cities of extinct tribes, new owner unknown
            or (RO.Treaty[RO.Territory[TestLoc]]<trPeace)) then
          TestScore:=40 // unfriendly undefended city -- capture!
        end

      else
        begin // no enemy city or unit here
        V8_to_Loc(TestLoc,Adjacent);
        for V8:=0 to 7 do
          begin
          NextLoc:=Adjacent[V8];
          if (NextLoc>=0) and (AdjacentUnknown[NextLoc]<0) then
            if Map[NextLoc] and fTerrain=fUNKNOWN then
              inc(AdjacentUnknown[TestLoc])
            else if Formation[NextLoc]=Formation[TestLoc] then
              case CheckStep(MoveStyle, TestTime, V8 and 1, NextTime, RecoverTurns, Map[TestLoc], Map[NextLoc], true) of
                csOk:
                  Pile.Put(NextLoc, NextTime);
                csForbiddenTile:
                  AdjacentUnknown[NextLoc]:=0; // don't check moving there again
                csCheckTerritory:
                  if RO.Territory[NextLoc]=RO.Territory[TestLoc] then
                    Pile.Put(NextLoc, NextTime);
                end
          end;
        if not CaptureOnly then
          if AdjacentUnknown[TestLoc]>0 then
            TestScore:=20+AdjacentUnknown[TestLoc]
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

    if PatrolLoc>=0 then
      begin // attack/capture/discover/patrol task found, execute it
      OldLoc:=Loc;
      MoveResult:=Unit_Move(uix,PatrolLoc);
      Exhausted:= (Loc=OldLoc)
        or ((MoveResult and (rMoreTurns or rUnitRemoved))<>0);
      end
    else Exhausted:=true;
  until Exhausted;
  end;
end; // Patrol

procedure TAI.AttackAndPatrol;
const
nAttackCatOrder=3;
AttackCatOrder: array[0..nAttackCatOrder-1] of integer=
(mctGroundAttacker, mctCruiser, mctGroundDefender);
var
iCat,uix,uix1: integer;
IsPatrolUnit,Fortified: boolean;
begin
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do // utilize militia
  if (Loc>=0) and (mix=mixMilitia)
    and ((Formation[Loc]<0) or (Formation[Loc]>=maxCOD)
      or (ContinentPresence[Formation[Loc]] and PresenceUnknown=0)) then
    Unit_Disband(uix);

if RO.nEnemyUn>0 then
  for iCat:=0 to nAttackCatOrder-1 do
    for Fortified:=false to true do
      for uix:=RO.nUn-1 downto 0 do with MyUnit[uix] do
        if (Loc>=0) and (ModelCat[mix]=AttackCatOrder[iCat])
          and (MyModel[mix].Attack>0)
          and ((Flags and unFortified<>0) = Fortified) then
          CheckAttack(uix);

fillchar(uixPatrol, sizeof(uixPatrol), $FF);
for uix:=0 to RO.nUn-1 do with MyUnit[uix],MyModel[mix] do
  if (Loc>=0) and (Domain=dGround) and (Attack>0) and (Speed>=250)
    and (Map[Loc] and fTerrain>=fGrass)
    and (Formation[Loc]>=0) and (Formation[Loc]<maxCOD)
    and ((uixPatrol[Formation[Loc]]<0)
      or (MyUnit[uix].ID<MyUnit[uixPatrol[Formation[Loc]]].ID)) then
      uixPatrol[Formation[Loc]]:=uix;

for uix:=0 to RO.nUn-1 do with MyUnit[uix] do if Loc>=0 then
  begin
  if mix=mixMilitia then
    if (RO.nUn<3) and (RO.nCity=1) or (Map[Loc] and fCity=0) then
      IsPatrolUnit:=true
    else
      begin // militia
      IsPatrolUnit:=false;
      for uix1:=0 to RO.nUn-1 do
        if (uix1<>uix) and (MyUnit[uix1].Loc=Loc)
          and (MyUnit[uix1].mix<>mixSettlers) then
          IsPatrolUnit:=true
      end
  else IsPatrolUnit:=(mix=mixCruiser)
    or (Map[Loc] and fTerrain>=fGrass)
    and (Formation[Loc]>=0) and (Formation[Loc]<maxCOD)
    and (uix=uixPatrol[Formation[Loc]]);
  if IsPatrolUnit then Patrol(uix);
  end
end; // AttackAndPatrol


function TAI.HavePort: boolean;
var
V8, cix,AdjacentLoc,f: integer;
Adjacent: TVicinity8Loc;
begin
result:=false;
for cix:=0 to RO.nCity-1 do with MyCity[cix] do if Loc>=0 then
  begin
  V8_to_Loc(Loc,Adjacent);
  for V8:=0 to 7 do
    begin
    AdjacentLoc:=Adjacent[V8];
    if (AdjacentLoc>=0) and ((Map[AdjacentLoc] and fTerrain)<fGrass) then
      begin
      f:=Formation[AdjacentLoc];
      if (f>=0) and (f<maxCOD) and (OceanPresence[f] and not (1 shl me)<>0) then
        result:=true;
      end
    end;
  end
end;


procedure TAI.SetCityProduction;
var
uix,cix,iix,dtr,V8,V21,NewImprovement,AdjacentLoc,MaxSettlers,
  maxcount,cixMilAcademy: integer;
TerrType: cardinal;
IsPort,IsNavalBase,NeedCruiser,CheckProd,Destructed,ProduceSettlers,ProduceMil: boolean;
Adjacent: TVicinity8Loc;
Radius: TVicinity21Loc;
Report: TCityReport;
HomeCount, CityProdRep: array[0..nCmax-1] of integer;
MilProdCity: array[0..nCmax-1] of boolean;

  procedure TryBuild(Improvement: integer);
  begin
  if (NewImprovement=imTrGoods) // not already improvement of higher priority found
    and (MyCity[cix].Built[Improvement]=0) // not built yet
    and ((Imp[Improvement].Preq=preNone)
      or (RO.Tech[Imp[Improvement].Preq]>=tsApplicable))
    and City_Improvable(cix, Improvement) then
    NewImprovement:=Improvement;
  end;

  procedure TryDestruct(Improvement: integer);
  begin
  if Destructed or (MyCity[cix].Built[Improvement]=0) then exit;
  if City_CurrentImprovementProject(cix)>=0 then
    City_RebuildImprovement(cix,Improvement)
  else City_SellImprovement(cix, Improvement);
{    if (CurrentImprovementProject>=0)
      and (Imp[CurrentImprovementProject].Kind in [ikCommon,ikNatGlobal,ikNatLocal])
      and ((Imp[CurrentImprovementProject].Cost*3-Imp[Improvement].Cost*2)
      *BuildCostMod[G.Difficulty[me]]>MyCity[cix].Prod*(12*3)) then}
  Destructed:=true
  end;

  function ChooseBuildModel(Cat: integer): integer;
  var
  count, mix: integer;
  begin
  count:=0;
  for mix:=0 to RO.nModel-1 do
    if (ModelCat[mix]=Cat)
      and (ModelQuality[mix]>=ModelBestQuality[Cat]-MaxBuildWorseThanBestModel) then
      begin inc(count); if random(count)=0 then result:=mix end;
  assert(count>0);
  end;

  procedure NominateMilProdCities;
  // find military production cities
  var
  cix, Total, d, Threshold, NewThreshold, Share, SharePlus, cixWorst: integer;
  begin
  fillchar(MilProdCity, RO.nCity, 0);
  GetCityProdPotential;
  for d:=0 to maxCOD-1 do
    begin
    Total:=0;
    for cix:=0 to RO.nCity-1 do with MyCity[cix] do
      if (Loc>=0) and (District[Loc]=d) then
        Total:=Total+CityResult[cix];
    if Total=0 then continue; // district does not exist

    Share:=0;
    cixWorst:=-1;
    for cix:=0 to RO.nCity-1 do with MyCity[cix] do
      if (Loc>=0) and (District[Loc]=d)
        and (Built[imBarracks]+Built[imMilAcademy]>0) then
        begin
        MilProdCity[cix]:=true;
        inc(Share,CityResult[cix]);
        if (cixWorst<0) or (CityResult[cix]<CityResult[cixWorst]) then
          cixWorst:=cix
        end;

    Threshold:=$FFFF;
    while (Threshold>0) and (Share<Total*MilProdShare div 100) do
      begin
      NewThreshold:=-1;
      SharePlus:=0;
      for cix:=0 to RO.nCity-1 do with MyCity[cix] do
        if (Loc>=0) and (District[Loc]=d)
          and (Built[imBarracks]+Built[imMilAcademy]=0) and (Built[imObservatory]=0)
          and (CityResult[cix]<Threshold)
          and (CityResult[cix]>=NewThreshold) then
          if CityResult[cix]>NewThreshold then
            begin
            NewThreshold:=CityResult[cix];
            SharePlus:=CityResult[cix]
            end
          else inc(SharePlus,CityResult[cix]);
      Threshold:=NewThreshold;
      inc(Share,SharePlus);
      end;

    for cix:=0 to RO.nCity-1 do with MyCity[cix] do
      if (Loc>=0) and (District[Loc]=d)
        and (Built[imBarracks]+Built[imMilAcademy]=0)
        and (CityResult[cix]>=Threshold) then
        MilProdCity[cix]:=true;
{    if (cixWorst>=0)
      and (Share-CityResult[cixWorst]*2>=Total*MilProdShare div 100) then
      MilProdCity[cixWorst]:=false;}
    end;

  // check best city for military academy
  cixMilAcademy:=cixStateImp[imMilAcademy];
  if cixStateImp[imPalace]>=0 then
    begin
    d:=District[MyCity[cixStateImp[imPalace]].Loc];
    if (d>=0) and (d<maxCOD) then
      begin
      cixMilAcademy:=-1;
      for cix:=0 to RO.nCity-1 do with MyCity[cix] do
        if (Loc>=0) and (District[Loc]=d)
          and (Built[imObservatory]+Built[imPalace]=0)
          and ((cixMilAcademy<0) or (CityResult[cix]>CityResult[cixMilAcademy])) then
          cixMilAcademy:=cix;
      end;
    if (cixMilAcademy>=0) and (cixStateImp[imMilAcademy]>=0)
      and (cixMilAcademy<>cixStateImp[imMilAcademy])
      and (MyCity[cixStateImp[imMilAcademy]].Built[imObservatory]=0)
      and (CityResult[cixMilAcademy]<=CityResult[cixStateImp[imMilAcademy]]*3 div 2) then
      cixMilAcademy:=cixStateImp[imMilAcademy] // because not so much better
    end
  end;

  procedure ChangeHomeCities;
  var
  uix,NewHome,HomeSupport,NewHomeSupport,SingleSupport: integer;
  begin
  if RO.Government in [gAnarchy, gFundamentalism] then exit;
  for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
    if (Loc>=0) and (Home>=0) and (Map[Loc] and fCity<>0)
      and (MyCity[Home].Loc<>Loc) and (MyModel[mix].Kind<>mkSettler) then
      begin
      City_FindMyCity(Loc, NewHome);
      case RO.Government of
        gDespotism:
          begin
          HomeSupport:=HomeCount[Home]-MyCity[Home].Size;
          NewHomeSupport:=HomeCount[NewHome]-MyCity[NewHome].Size;
          end;
        gMonarchy, gCommunism:
          begin
          HomeSupport:=HomeCount[Home]-MyCity[Home].Size div 2;
          NewHomeSupport:=HomeCount[NewHome]-MyCity[NewHome].Size div 2;
          end;
        else
          begin
          HomeSupport:=HomeCount[Home];
          NewHomeSupport:=HomeCount[NewHome];
          end;
        end;
      if HomeSupport>0 then
        begin
        if MyModel[mix].Flags and mdDoubleSupport=0 then SingleSupport:=1
        else SingleSupport:=2;
        HomeSupport:=HomeSupport-SingleSupport;
        NewHomeSupport:=NewHomeSupport+SingleSupport;
        if HomeSupport<0 then HomeSupport:=0;
        if NewHomeSupport<0 then NewHomeSupport:=0;
        if (NewHomeSupport<=0)
          or (CityProdRep[Home]-HomeSupport<=CityProdRep[NewHome]-NewHomeSupport) then
          begin
          dec(HomeCount[Home],SingleSupport);
          inc(HomeCount[NewHome],SingleSupport);
          Unit_SetHomeHere(uix)
          end
        end
      end
  end;

begin
fillchar(HomeCount, 4*RO.nCity, 0);
for uix:=0 to RO.nUn-1 do with MyUnit[uix] do
  if (Loc>=0) and (Home>=0) then
    if MyModel[mix].Flags and mdDoubleSupport=0 then
      inc(HomeCount[Home])
    else inc(HomeCount[Home],2);

NominateMilProdCities;

for cix:=0 to RO.nCity-1 do with MyCity[cix] do
  if (Loc>=0) and (Flags and chCaptured=0) and (District[Loc]>=0) then
    begin
    if size<4 then
      City_OptimizeTiles(cix,rwMaxGrowth)
    else City_OptimizeTiles(cix,rwForceProd);

    City_GetReport(cix, Report);
    CityProdRep[cix]:=Report.ProdRep;

    Destructed:=false;
    CheckProd:= (RO.Turn=0) or ((Flags and chProduction)<>0) // city production complete
      or not City_HasProject(cix);
    if not CheckProd then
      begin // check whether producing double state improvement or wonder
      iix:=City_CurrentImprovementProject(cix);
      if (iix>=0)
        and (((Imp[iix].Kind in [ikNatLocal,ikNatGlobal]) and (RO.NatBuilt[iix]>0))
          or ((Imp[iix].Kind=ikWonder) and (RO.Wonder[iix].CityID<>-1))) then
        CheckProd:=true;
      end;
    if CheckProd then
      begin // check production
      IsPort:=false;
      IsNavalBase:=false;
      NeedCruiser:=false;
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        AdjacentLoc:=Adjacent[V8];
        if (AdjacentLoc>=0) and ((Map[AdjacentLoc] and fTerrain)<fGrass) then
          begin
          IsPort:=true; // shore tile at adjacent location -- city is port!
          if (Formation[AdjacentLoc]>=0) and (Formation[AdjacentLoc]<maxCOD)
            and (OceanPresence[Formation[AdjacentLoc]] and WarNations<>0) then
            begin
            IsNavalBase:=true;
            if (1 shl Formation[AdjacentLoc]) and OceanWithShip=0 then
              NeedCruiser:=true
            end
          end
        end;

      if RO.Turn=0 then
        begin
        NewImprovement:=-1;
        City_StartUnitProduction(cix,mixMilitia); // militia
        end
      else NewImprovement:=imTrGoods;

      dtr:=District[Loc]; // formation of city

      if NewImprovement=imTrGoods then
        begin
        if (Built[imPalace]+Built[imCourt]+Built[imTownHall]=0) then
          TryBuild(imTownHall);
        end;

      if (NewImprovement=imTrGoods)
        and (RO.Government=gDespotism) and (Report.Support=0) then
        begin // produce town guard
        NewImprovement:=-1;
        City_StartUnitProduction(cix,mixTownGuard);
        end;

      if NewImprovement=imTrGoods then
        begin
        if RO.Government=gDespotism then maxcount:=Size
        else maxcount:=Size div 2;

        if IsResearched(adRailroad) and (mixSettlers=0) // better wait for engineers
          or (Built[imColosseum]+Built[imObservatory]>0) then
          MaxSettlers:=1
        else MaxSettlers:=(Size+2) div 6;
        ProduceSettlers:=(HomeCount[cix]<maxcount+Size div 2)
          and ((Report.Eaten-Size*2) div SettlerFood[RO.Government]<MaxSettlers)
          and ((dtr<0) or (dtr>=maxCOD) or (SettlerSurplus[dtr]<=0));

        ProduceMil:=(HomeCount[cix]<maxcount+Size div 2)
          and (Built[imBarracks]+Built[imMilAcademy]>0)
          and ((ModelBestQuality[mctGroundDefender]>0)
            or (ModelBestQuality[mctGroundAttacker]>0))
          and ((dtr<maxCOD)
            and ((UnitLack[dtr,mctGroundAttacker]>0)
              or (UnitLack[dtr,mctGroundDefender]>0))
            or (HomeCount[cix]<maxcount));

        if ProduceMil or not ProduceSettlers and (HomeCount[cix]<maxcount) then
          begin
          NewImprovement:=-1;
          if (dtr>=maxCOD)
            or (ModelBestQuality[mctGroundDefender]=0)
            or (UnitLack[dtr,mctGroundAttacker]
              >=UnitLack[dtr,mctGroundDefender]) then
            City_StartUnitProduction(cix,ChooseBuildModel(mctGroundAttacker))
          else City_StartUnitProduction(cix,ChooseBuildModel(mctGroundDefender))
          end
        else if ProduceSettlers then
          begin
          NewImprovement:=-1;
          City_StartUnitProduction(cix,mixSettlers);
          end
        end;

      if NewImprovement>=0 then
        begin // produce improvement
        if (RO.Turn>=40) and (Report.Happy*2<=Size)
          and (Built[imColosseum]=0) then
          TryBuild(imTemple);
        if cix=cixMilAcademy then
          TryBuild(imMilAcademy)
        else if ((Built[imPalace]>0) or MilProdCity[cix] and (Built[imTemple]>0))
          and (Built[imObservatory]=0) then
          TryBuild(imBarracks);
        if Report.Trade-Report.Corruption>=11 then
          TryBuild(imLibrary);
        if Report.Trade-Report.Corruption>=11 then
          TryBuild(imMarket);
        if (Report.Trade-Report.Corruption>=11) and (Report.Happy>=4) then
          TryBuild(imUniversity);
        if (Built[imPalace]>0) and (Report.Trade-Report.Corruption>=11)
          and (Report.Happy>=4) and (RO.NatBuilt[imObservatory]=0) then
          TryBuild(imObservatory); // always build observatory in capital
        if (Report.Trade-Report.Corruption>=15) and (Report.Happy>=4) then
          TryBuild(imResLab);
        if (Size>=9) and (Built[imPalace]+Built[imCourt]>0) then
          TryBuild(imHighways);
        if (RO.Government<>gDespotism) and (Report.Happy*2<=Size)
          and (Built[imCathedral]+Built[imTheater]+Built[imColosseum]=0) then
          begin
          TryBuild(imCathedral);
          TryBuild(imTheater);
          end;
        if (RO.Government<>gDespotism) and (Size>=NeedAqueductSize) then
          TryBuild(imAqueduct);
        if (Built[imColosseum]+Built[imObservatory]>0) and (Size>=NeedSewerSize) then
          TryBuild(imSewer);
        if (RO.NatBuilt[imGrWall]=0) and (Built[imObservatory]+Built[imMilAcademy]=0)
          and (RO.nCity>=6) and (cixStateImp[imPalace]>=0)
          and (Formation[Loc]=Formation[MyCity[cixStateImp[imPalace]].Loc])
          and (Report.ProdRep-Report.Support>=6) then
          TryBuild(imGrWall);
  //        if Map[Loc] and fGrWall=0 then
  //          TryBuild(imWalls);
  //        if IsNavalBase then
  //          TryBuild(imCoastalFort);
        if (RO.NatBuilt[imSpacePort]=0) and (Built[imObservatory]+Built[imMilAcademy]=0)
          and (Report.ProdRep-Report.Support>=10) then
          TryBuild(imSpacePort);
        if Report.ProdRep>=8 then
          TryBuild(imFactory);
        if Report.ProdRep>=12 then
          TryBuild(imMfgPlant);
        if IsPort then
          if Size>8 then
            TryBuild(imHarbor)
          else if (Built[imHarbor]=0) and (Size>4)
            and ((Size and 1<>0) and (Report.Happy*2>Size)
              or (Built[imColosseum]>0)) then
            begin // check building harbor
            V21_to_Loc(Loc,Radius);
            for V21:=1 to 26 do // city is in growth mode - using any 1-food tile?
              if Tiles and (1 shl V21)<>0 then
                begin
                TerrType:=Map[Radius[V21]] and (fTerrain or fSpecial);
                if TerrType in [fDesert,fTundra,fSwamp,fForest,fHills,fMountains] then
                  begin TryBuild(imHarbor); break end
                end
            end;
        if (Size<=10) and (Report.FoodRep-Report.Eaten<2) and
          (Report.Happy*2>=Size+2) then
          TryBuild(imSuperMarket);

        // less important
        if (Built[imPalace]>0) and (RO.NatBuilt[imColosseum]=0)
          and (Size>=10) then
          TryBuild(imColosseum); // always build colosseum in capital
        if (Built[imPalace]+Built[imCourt]=0)
          and ((Report.Corruption>2) or IsResearched(Imp[imHighways].Preq)) then
          TryBuild(imCourt); // replace courthouse
        if Report.PollRep>=15 then
          TryBuild(imRecycling);
        if (Report.Trade-Report.Corruption>=11)
          and (RO.Money<TotalPopulation[me]*2) then
          TryBuild(imBank);
        if (RO.NatBuilt[imStockEx]=0) and (Built[imObservatory]+Built[imMilAcademy]=0)
          and (Report.ProdRep-Report.Support>=8) then
          TryBuild(imStockEx);

        // every improvement checked -- start production now
        if NewImprovement<>imTrGoods then
          begin
          if City_StartImprovement(cix, NewImprovement)<rExecuted then
            NewImprovement:=imTrGoods
          end;
        if (NewImprovement=imTrGoods) and (RO.Turn and $F=0) then
          begin // try colony ship parts
          NewImprovement:=imShipComp;
          while (NewImprovement<=imShipHab)
            and ((RO.Tech[Imp[NewImprovement].Preq]<0)
            or (City_StartImprovement(cix, NewImprovement)<rExecuted)) do
            inc(NewImprovement);
          if NewImprovement>imShipHab then NewImprovement:=imTrGoods
          end
        end;

      if (NewImprovement=imTrGoods) and NeedCruiser and (mixCruiser>=0)
        and (Project and (cpImp or cpIndex)<>mixCruiser)
        and (Report.ProdRep-Report.Support>=6) then
        begin
        NewImprovement:=-1;
        City_StartUnitProduction(cix,mixCruiser);
        end;

      if (NewImprovement=imTrGoods) and City_HasProject(cix) then
        City_StopProduction(cix);

      // rebuild imps no longer needed
      if (RO.TaxRate=0) and (RO.Money>=TotalPopulation[me]*4) then
        TryDestruct(imBank)
      else if Report.Happy*2>=Size+6 then
        TryDestruct(imTheater)
      else if Report.Happy*2>=Size+4 then
        TryDestruct(imTemple)
      end;

    // rebuild imps no longer needed, no report needed
    if (Built[imObservatory]>0)
      or (Project and (cpImp or cpIndex)=cpImp or imObservatory)
      {or not MilProdCity[cix]} then
      TryDestruct(imBarracks);
    if Map[Loc] and fGrWall<>0 then
      TryDestruct(imWalls);
    if Built[imColosseum]>0 then
      begin
      TryDestruct(imTheater);
      TryDestruct(imCathedral);
      TryDestruct(imTemple);
      end;
    end;

ChangeHomeCities;
end; // SetCityProduction


function TAI.ChooseGovernment: integer;
begin
if Data.BehaviorFlags and bBarbarina<>0 then
  if IsResearched(adTheology) then result:=gFundamentalism
  else result:=gDespotism
else if IsResearched(adDemocracy) then
  result:=gDemocracy //!!!
else if IsResearched(adTheRepublic) then
  result:=gRepublic
else if IsResearched(adMonarchy) then
  result:=gMonarchy
else result:=gDespotism
end;


//-------------------------------
//           DIPLOMACY
//-------------------------------

function TAI.MostWanted(Nation, adGiveAway: integer): integer;
var
ad: integer;
begin
result:=-1;
if RO.Tech[adGiveAway]>=tsApplicable then
  if (adGiveAway=adTheRepublic) and (Data.BehaviorFlags and bGender=bFemale)
    and (RO.Tech[adTheology]<tsSeen) then
    begin
    if RO.EnemyReport[Nation].Tech[adTheology]>=tsApplicable then
      result:=adTheology
    end
  else for ad:=0 to nAdv-5 do // no future techs
      if (AdvanceValue[ad]>0)
        and (RO.Tech[ad]<tsSeen) and (ad<>RO.ResearchTech)
        and (RO.EnemyReport[Nation].Tech[ad]>=tsApplicable)
        and ((Advancedness[adGiveAway]<=Advancedness[ad]+AdvanceValue[ad] shr 8+Compromise)
          or (adGiveAway=adScience) and (Nation=Data.TheologyPartner))
        and ((result<0)
          or ((Advancedness[adGiveAway]+Compromise>=Advancedness[ad]) // acceptable for opponent
            or (ad=adScience))
          and (AdvanceValue[ad]>AdvanceValue[result])
          or (result<>adScience)
          and (Advancedness[adGiveAway]+Compromise<Advancedness[result])
          and (Advancedness[ad]<Advancedness[result]))
        and ((ad<>adTheRepublic) or (Data.BehaviorFlags and bGender=bFemale)
          or (RO.EnemyReport[Nation].Tech[adTheology]>=tsSeen)) then
        result:=ad
end;

procedure TAI.FindBestTrade(Nation: integer; var adWanted, adGiveAway: integer);
var
i,ad,ead,adTestGiveAway: integer;
begin
adWanted:=-1;
adGiveAway:=-1;
for ead:=0 to nAdv-5 do // no future techs
  if (AdvanceValue[ead]>=$100)
    and (RO.Tech[ead]<tsSeen) and (ead<>RO.ResearchTech)
    and (RO.EnemyReport[Nation].Tech[ead]>=tsApplicable)
    and ((adWanted<0) or (AdvanceValue[ead]>AdvanceValue[adWanted])) then
    begin
    adTestGiveAway:=-1;
    for i:=0 to nRequestedTechs-1 do
      if (Data.RequestedTechs[i]>=0)
        and (Data.RequestedTechs[i] and $FFFF=Nation shl 8+ead) then
        adTestGiveAway:=-2; // already requested before
    if adTestGiveAway=-1 then
      begin
      for ad:=0 to nAdv-5 do // no future techs
        if (RO.Tech[ad]>=tsApplicable)
          and (ad<>RO.EnemyReport[Nation].ResearchTech)
          and (RO.EnemyReport[Nation].Tech[ad]<tsSeen)
          and ((Advancedness[ad]+Compromise>=Advancedness[ead]) or (ead=adScience))
          and (Advancedness[ad]<=Advancedness[ead]+AdvanceValue[ead] shr 8+Compromise)
          and ((adTestGiveAway<0) or (Advancedness[ad]<Advancedness[adTestGiveAway])) then
          adTestGiveAway:=ad;
      if adTestGiveAway>=0 then
        begin
        adWanted:=ead;
        adGiveAway:=adTestGiveAway
        end
      end
    end;
end;


function TAI.WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean;
var
p1,count,adWanted,adGiveAway: integer;
begin
if Data.BehaviorFlags and bBarbarina=bBarbarina then
  begin result:=Barbarina_WantNegotiation(Nation,NegoTime); exit end;

if RO.Treaty[Nation]<trPeace then
  begin
  if Data.BehaviorFlags and bBarbarina<>0 then
    begin result:=false; exit end;
  count:=0;
  for p1:=0 to nPl-1 do
    if (p1<>me) and (1 shl p1 and RO.Alive<>0) and (RO.Treaty[p1]>=trPeace) then
      inc(count);
  if count>=3 then // enough peace made
    begin result:=false; exit; end
  end;

NegoCause:=Routine;
case NegoTime of
  EnemyCalled:
    result:=true;
  EndOfTurn:
    if (Data.RejectTurn[suContact,Nation]>=0)
      and (Data.RejectTurn[suContact,Nation]+WaitAfterReject>=RO.Turn) then
      result:=false
    else if RO.Treaty[Nation]<trPeace then
      result:=(Data.RejectTurn[suPeace,Nation]<0)
        or (Data.RejectTurn[suPeace,Nation]+WaitAfterReject<RO.Turn)
    else if RO.Treaty[Nation]=trPeace then
      result:= (Data.BehaviorFlags and bBarbarina=0)
        and ((Data.RejectTurn[suFriendly,Nation]<0)
          or (Data.RejectTurn[suFriendly,Nation]+WaitAfterReject<RO.Turn))
    else
      begin
      FindBestTrade(Nation,adWanted,adGiveAway);
      result:= adWanted>=0;
      end;
  BeginOfTurn:
    if (Data.RejectTurn[suContact,Nation]>=0)
      and (Data.RejectTurn[suContact,Nation]+WaitAfterReject>=RO.Turn) then
      result:=false
    else if (Data.BehaviorFlags and bGender=bMale) and Barbarina_WantCheckNegotiation(Nation) then
      begin NegoCause:=CheckBarbarina; result:=true; end
    else result:=false;
  end;
end;

procedure TAI.DoNegotiation;
var
i, adWanted, adGiveAway, adToGet, Slot: integer;
BuildFreeOffer: boolean;
begin
if MyLastAction=scDipOffer then
  if OppoAction=scDipAccept then
    begin // evaluate accepted offers
    AdvanceValuesSet:=false;
    if (MyLastOffer.nDeliver=1) and (MyLastOffer.nCost>0)
      and (MyLastOffer.Price[1]=opTech+adTheology) then
      Data.TheologyPartner:=Opponent;
    end
  else
    begin // evaluate rejected offers
    if MyLastOffer.nDeliver+MyLastOffer.nCost=1 then
      if MyLastOffer.Price[0]=opTreaty+trPeace then
        Data.RejectTurn[suPeace,Opponent]:=RO.Turn
      else if MyLastOffer.Price[0]=opTreaty+trFriendlyContact then
        Data.RejectTurn[suFriendly,Opponent]:=RO.Turn;
    end;
if OppoAction=scDipBreak then
  Data.RejectTurn[suContact,Opponent]:=RO.Turn
else if OppoAction=scDipCancelTreaty then
  begin
  case RO.Treaty[Opponent] of
    trNone: Data.RejectTurn[suPeace,Opponent]:=RO.Turn;
    trPeace: Data.RejectTurn[suFriendly,Opponent]:=RO.Turn;
    end;
  end;

if Data.BehaviorFlags and bBarbarina=bBarbarina then
  begin Barbarina_DoNegotiation; exit end;

if NegoCause=CheckBarbarina then
  begin Barbarina_DoCheckNegotiation; exit end;

SetAdvanceValues; // in case no turn played after loading this game

BuildFreeOffer:=false;
if (OppoAction=scDipStart) or (OppoAction=scDipAccept) then
  BuildFreeOffer:=true
else if (OppoAction=scDipOffer) and (OppoOffer.nDeliver+OppoOffer.nCost=0) then
  BuildFreeOffer:=true
else if OppoAction=scDipOffer then
  begin
  if (Data.BehaviorFlags and bBarbarina=0)
    and (OppoOffer.nDeliver+OppoOffer.nCost=1)
    and (OppoOffer.Price[0] and opMask=opTreaty)
    and (integer(OppoOffer.Price[0]-opTreaty)>RO.Treaty[Opponent])
    and ((OppoOffer.Price[0]-opTreaty<trAlliance) or (RO.Tech[adScience]>=tsSeen)) then
    MyAction:=scDipAccept // accept all treaties
  else if (RO.Treaty[Opponent]>=trPeace)
    and (OppoOffer.nDeliver=1)
    and (OppoOffer.Price[0] and $FFFF0000=opCivilReport+cardinal(Opponent) shl 16)
    and (OppoOffer.nCost=1)
    and (OppoOffer.Price[1] and $FFFF0000=opCivilReport+cardinal(me) shl 16) then
    MyAction:=scDipAccept // accept exchange of civil reports
  else if (OppoOffer.nDeliver=1) and (OppoOffer.nCost=1)
    and (OppoOffer.Price[1] and opMask=opTech) then
    begin // opponent wants tech
    BuildFreeOffer:=true;
    adGiveAway:=OppoOffer.Price[1]-opTech;
    if (OppoOffer.Price[0] and opMask=opTech)
      and (MyLastAction=scDipOffer)
      and (MyLastOffer.nDeliver=1) and (MyLastOffer.nCost=1)
      and (OppoOffer.Price[0]=MyLastOffer.Price[1]) then
      begin // opponent makes counter offer, check whether to accept
      adToGet:=OppoOffer.Price[0]-opTech;
      if (adGiveAway=adTheRepublic) and (Data.BehaviorFlags and bGender=bFemale)
        and (RO.Tech[adTheology]<tsSeen) then
        begin
        if adToGet=adTheology then MyAction:=scDipAccept;
        end
      else if (RO.Tech[adGiveAway]>=tsApplicable) and (RO.Tech[adToGet]<tsSeen)
        and (AdvanceValue[adToGet]>0)
        and ((Advancedness[adGiveAway]<=Advancedness[adToGet]
          +AdvanceValue[adToGet] shr 8+Compromise)
          or (adGiveAway=adScience) and (Opponent=Data.TheologyPartner)) then
        MyAction:=scDipAccept
      end
    else if (OppoOffer.Price[0] and opMask=opChoose)
      or (OppoOffer.Price[0] and opMask=opTech) then
      begin // choose price
      adWanted:=MostWanted(Opponent,OppoOffer.Price[1]-opTech);
      if (OppoOffer.Price[0] and opMask=opTech)
        and (Cardinal(adWanted)=OppoOffer.Price[0]-opTech) then
        MyAction:=scDipAccept // opponent's offer is already perfect
      else if adWanted>=0 then
        begin // make improved counter offer
        MyOffer.nDeliver:=1;
        MyOffer.nCost:=1;
        MyOffer.Price[0]:=OppoOffer.Price[1];
        MyOffer.Price[1]:=opTech+adWanted;
        MyAction:=scDipOffer;
        BuildFreeOffer:=false
        end
      end;
    if MyAction=scDipAccept then BuildFreeOffer:=false
    end
  else BuildFreeOffer:=true
  end;
if (MyAction=scDipAccept) and (OppoAction=scDipOffer) then
  begin
  AdvanceValuesSet:=false;
  if (OppoOffer.nDeliver>0) and (OppoOffer.Price[0]=opTech+adTheology) then
    Data.TheologyPartner:=Opponent
  end;

if BuildFreeOffer then
  begin
  if (Data.BehaviorFlags and bBarbarina=0)
    and (RO.Treaty[Opponent]<trPeace)
    and ((Data.RejectTurn[suPeace,Opponent]<0)
      or (Data.RejectTurn[suPeace,Opponent]+WaitAfterReject<RO.Turn)) then
    begin
    MyOffer.nDeliver:=1;
    MyOffer.nCost:=0;
    MyOffer.Price[0]:=opTreaty+trPeace;
    MyAction:=scDipOffer
    end
  else if (Data.BehaviorFlags and bBarbarina=0)
    and (RO.Treaty[Opponent]=trPeace)
    and ((Data.RejectTurn[suFriendly,Opponent]<0)
      or (Data.RejectTurn[suFriendly,Opponent]+WaitAfterReject<RO.Turn)) then
    begin
    MyOffer.nDeliver:=1;
    MyOffer.nCost:=0;
    MyOffer.Price[0]:=opTreaty+trFriendlyContact;
    MyAction:=scDipOffer
    end
  else
    begin
    FindBestTrade(Opponent, adWanted, adGiveAway);
    if adWanted>=0 then
      begin
      MyOffer.nDeliver:=1;
      MyOffer.nCost:=1;
      MyOffer.Price[0]:=opTech+adGiveAway;
      MyOffer.Price[1]:=opTech+adWanted;
      MyAction:=scDipOffer;
      for i:=0 to nRequestedTechs-1 do
        if Data.RequestedTechs[i]<0 then
          begin Slot:=i; break end
        else if (i=0) or (Data.RequestedTechs[i] shr 16
          <Data.RequestedTechs[Slot] shr 16) then // find most outdated entry
          Slot:=i;
      Data.RequestedTechs[Slot]:=RO.Turn shl 16+Opponent shl 8+adWanted
      end
    end
  end;
end; // Negotiation


procedure SetLeaveOutValue;
  procedure Process(ad: integer);
  var
  i: integer;
  begin
  if LeaveOutValue[ad]<0 then
    begin
    LeaveOutValue[ad]:=0;
    for i:=0 to 1 do if AdvPreq[ad,i]>=0 then
      begin
      Process(AdvPreq[ad,i]);
      if AdvPreq[ad,i] in LeaveOutTechs then
        inc(LeaveOutValue[ad], LeaveOutValue[AdvPreq[ad,i]]+1)
      end
    end
  end;
var
ad: integer;
begin
FillChar(LeaveOutValue,SizeOf(LeaveOutValue),$FF);
for ad:=0 to nAdv-5 do Process(ad);
end;


initialization
RWDataSize:=sizeof(TPersistentData);
SetLeaveOutValue;

end.

