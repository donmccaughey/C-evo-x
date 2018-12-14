{$INCLUDE switches}
unit UnitProcessing;

interface

uses
Protocol, Database;

type
TMoveType = (mtInvalid, mtMove, mtCapture, mtSpyMission, mtAttack, mtBombard, mtExpel);

TMoveInfo=record
  MoveType: TMoveType;
  Cost,
  ToMaster,
  EndHealth,
  Defender,
  Dcix,
  Duix,
  EndHealthDef: integer;
  MountainDelay: boolean;
  end;

var
uixSelectedTransport: integer;
Worked: array[0..nPl-1] of integer; {settler work statistics}


//Moving/Combat
function HostileDamage(p, mix, Loc, MP: integer): integer;
function CalculateMove(p,uix,ToLoc,MoveLength: integer; TestOnly: boolean;
  var MoveInfo: TMoveInfo): integer;
function GetBattleForecast(Loc: integer; var BattleForecast: TBattleForecast;
  var Duix,Dcix,AStr,DStr,ABaseDamage,DBaseDamage: integer): integer;
function LoadUnit(p,uix: integer; TestOnly: boolean): integer;
function UnloadUnit(p,uix: integer; TestOnly: boolean): integer;
procedure Recover(p,uix: integer);
function GetMoveAdvice(p,uix: integer; var a: TMoveAdviceData): integer;
function CanPlaneReturn(p,uix: integer; PlaneReturnData: TPlaneReturnData): boolean;

// Terrain Improvement
function StartJob(p,uix,NewJob: integer; TestOnly: boolean): integer;
function Work(p,uix: integer): boolean;
function GetJobProgress(p,Loc: integer; var JobProgressData: TJobProgressData): integer;

// Start/End Game
procedure InitGame;
procedure ReleaseGame;


implementation

uses
IPQ;

const
eMountains=$6000FFFF; // additional return code for server internal use

// tile control flags
coKnown=$02; coTrue=$04;

ContraJobs: array[0..nJob-1] of Set of 0..nJob-1=
([],                             //jNone
[jCity],                         //jRoad
[jCity],                         //jRR
[jCity,jTrans],                  //jClear
[jCity,jFarm,jAfforest,jMine,jBase,jFort],         //jIrr
[jCity,jIrr,jAfforest,jMine,jBase,jFort],         //jFarm
[jCity,jIrr,jFarm,jTrans],       //jAfforest
[jCity,jTrans,jIrr,jFarm,jBase,jFort],       //jMine
[jCity,jTrans],                  //jCanal
[jCity,jClear,jAfforest,jMine,jCanal], //jTrans
[jCity,jIrr,jFarm,jMine,jBase],                         //jFort
[jCity],                         //jPoll
[jCity,jIrr,jFarm,jMine,jFort],                         //jBase
[jCity],                         //jPillage
[jRoad..jPillage]);              //jCity

type
TToWorkList = array[0..INFIN,0..nJob-1] of word;

var
ToWork: ^TToWorkList; {work left for each tile and job}


{
                            Moving/Combat
 ____________________________________________________________________
}
function HostileDamage(p, mix, Loc, MP: integer): integer;
var
Tile: integer;
begin
Tile:=RealMap[Loc];
if (RW[p].Model[mix].Domain>=dSea)
  or (RW[p].Model[mix].Kind=mkSettler) and (RW[p].Model[mix].Speed>=200)
  or (Tile and (fCity or fRiver or fCanal)<>0)
  or (Tile and fTerImp=tiBase)
  or (GWonder[woGardens].EffectiveOwner=p) then
  result:=0
else if (Tile and fTerrain=fDesert)
  and (Tile and fSpecial<>fSpecial1{Oasis}) then
  begin
  assert((Tile and fTerImp<>tiIrrigation) and (Tile and fTerImp<>tiFarm));
  result:=(DesertThurst*MP-1) div RW[p].Model[mix].Speed +1
  end
else if Tile and fTerrain=fArctic then
  begin
  assert((Tile and fTerImp<>tiIrrigation) and (Tile and fTerImp<>tiFarm));
  result:=(ArcticThurst*MP-1) div RW[p].Model[mix].Speed +1
  end
else result:=0
end;

function Controlled(p,Loc: integer; IsDest: boolean): integer;
{whether tile at Loc is in control zone of enemy unit
returns combination of tile control flags}
var
Loc1,V8: integer;
Adjacent: TVicinity8Loc;
begin
result:=0;
if IsDest and (Occupant[Loc]=p) and (ZoCMap[Loc]>0) then exit;
  // destination tile, not controlled if already occupied

if (RealMap[Loc] and fCity=0)
  or (integer(RealMap[Loc] shr 27)<>p) and (ServerVersion[p]>=$000EF0) then
  begin // not own city
  V8_to_Loc(Loc,Adjacent);
  for V8:=0 to 7 do
    begin
    Loc1:=Adjacent[V8];
    if (Loc1>=0) and (Loc1<MapSize)
      and (ZoCMap[Loc1]>0)
      and (Occupant[Loc1]>=0) and (Occupant[Loc1]<>p)
      and (RW[p].Treaty[Occupant[Loc1]]<trAlliance) then
      if ObserveLevel[Loc1] and (3 shl (p*2))>0 then
        begin // p observes tile
        result:=coKnown or coTrue;
        exit
        end
      else result:=coTrue; // p does not observe tile
    end;
  end
end;

function GetMoveCost(p,mix,FromLoc,ToLoc,MoveLength: integer; var MoveCost: integer): integer;
// MoveLength - 2 for short move, 3 for long move
var
FromTile,ToTile: integer;
begin
result:=eOK;
FromTile:=RealMap[FromLoc];
ToTile:=RealMap[ToLoc];
with RW[p].Model[mix] do
  begin
  case Domain of
    dGround:
      if (ToTile and fTerrain>=fGrass) then {domain ok}
//          if (Flags and mdCivil<>0) and (ToTile and fDeadLands<>0) then result:=eEerie
//          else
          begin {valid move}
          if (FromTile and (fRR or fCity)<>0)
            and (ToTile and (fRR or fCity)<>0) then
            if GWonder[woShinkansen].EffectiveOwner=p then MoveCost:=0
            else MoveCost:=Speed*(4*1311) shr 17 //move along railroad
          else if (FromTile and (fRoad or fRR or fCity)<>0)
            and (ToTile and (fRoad or fRR or fCity)<>0)
            or (FromTile and ToTile and (fRiver or fCanal)<>0)
            or (Cap[mcAlpine]>0) then
            //move along road, river or canal
            if Cap[mcOver]>0 then MoveCost:=40
            else MoveCost:=20
          else if Cap[mcOver]>0 then result:=eNoRoad
          else case Terrain[ToTile and fTerrain].MoveCost of
            1: MoveCost:=50; // plain terrain
            2:
              begin
              assert(Speed-150<=600);
              MoveCost:=50+(Speed-150)*13 shr 7; // heavy terrain
              end;
            3:
              begin
              MoveCost:=Speed;
              result:=eMountains;
              exit
              end;
            end;
          MoveCost:=MoveCost*MoveLength;
          end
      else result:=eDomainMismatch;

    dSea:
      if (ToTile and (fCity or fCanal)<>0)
        or (ToTile and fTerrain<fGrass) then {domain ok}
        if (ToTile and fTerrain<>fOcean) or (Cap[mcNav]>0) then
          MoveCost:=50*MoveLength {valid move}
        else result:=eNoNav {navigation required for open sea}
      else result:=eDomainMismatch;

    dAir:
      MoveCost:=50*MoveLength; {always valid move}
    end
  end
end;

function CalculateMove(p,uix,ToLoc,MoveLength: integer; TestOnly: boolean;
  var MoveInfo: TMoveInfo): integer;
var
uix1,p1,FromLoc,DestControlled,AStr,DStr,ABaseDamage,DBaseDamage: integer;
PModel: ^TModel;
BattleForecast: TBattleForecast;
begin
with RW[p],Un[uix] do
  begin
  PModel:=@Model[mix];
  FromLoc:=Loc;

  BattleForecast.pAtt:=p;
  BattleForecast.mixAtt:=mix;
  BattleForecast.HealthAtt:=Health;
  BattleForecast.ExpAtt:=Exp;
  BattleForecast.FlagsAtt:=Flags;
  BattleForecast.Movement:=Movement;
  result:=GetBattleForecast(ToLoc,BattleForecast,MoveInfo.Duix,MoveInfo.Dcix,AStr,DStr,ABaseDamage,DBaseDamage);

  if result=eHiddenUnit then
    if TestOnly then result:=eOK // behave just like unit was moving
    else if Mode>moLoading_Fast then
      Map[ToLoc]:=Map[ToLoc] or fHiddenUnit;
  if result=eStealthUnit then
    if TestOnly then result:=eOK // behave just like unit was moving
    else if Mode>moLoading_Fast then
      Map[ToLoc]:=Map[ToLoc] or fStealthUnit;
  if result<rExecuted then exit;

  case result of
    eOk: MoveInfo.MoveType:=mtMove;
    eExpelled: MoveInfo.MoveType:=mtExpel;
    else MoveInfo.MoveType:=mtAttack;
    end;

  if MoveInfo.MoveType=mtMove then
    begin
    if Mode=moPlaying then
      begin
      p1:=RealMap[ToLoc] shr 27;
      if (p1<nPl) and (p1<>p)
        and ((RealMap[Loc] shr 27<>Cardinal(p1))
        and (PModel.Kind<>mkDiplomat)
        and (Treaty[p1]>=trPeace) and (Treaty[p1]<trAlliance)
        or (RealMap[ToLoc] and fCity<>0) and (Treaty[p1]>=trPeace)) then
        begin result:=eTreaty; exit end; // keep peace treaty!
      end;
    if (RealMap[ToLoc] and fCity<>0)
      and (RealMap[ToLoc] shr 27<>Cardinal(p)) then // empty enemy city
      if PModel.Kind=mkDiplomat then
        begin
        MoveInfo.MoveType:=mtSpyMission;
        end
      else if PModel.Domain=dGround then
        begin
        if PModel.Flags and mdCivil<>0 then
          begin result:=eNoCapturer; exit end;
        MoveInfo.MoveType:=mtCapture;
        end
      else
        begin
        if (PModel.Domain=dSea) and (PModel.Cap[mcArtillery]=0) then
          begin result:=eDomainMismatch; exit end
        else if (PModel.Attack=0)
          and not ((PModel.Cap[mcBombs]>0) and (Flags and unBombsLoaded<>0)) then
          begin result:=eNoBombarder; exit end
        else if Movement<100 then
          begin result:=eNoTime_Bombard; exit end;
        MoveInfo.MoveType:=mtBombard;
        result:=eBombarded;
        end
    end;

  MoveInfo.MountainDelay:=false;
  if MoveInfo.MoveType in [mtAttack,mtBombard,mtExpel] then
    begin
    if (Master>=0)
      or (PModel.Domain=dSea) and (RealMap[Loc] and fTerrain>=fGrass)
      or (PModel.Domain=dAir) and ((RealMap[Loc] and fCity<>0)
        or (RealMap[Loc] and fTerImp=tiBase)) then
      begin result:=eViolation; exit end;
    if MoveInfo.MoveType=mtBombard then
      begin
      MoveInfo.EndHealth:=Health;
      MoveInfo.EndHealthDef:=-1;
      end
    else
      begin
      MoveInfo.EndHealth:=BattleForecast.EndHealthAtt;
      MoveInfo.EndHealthDef:=BattleForecast.EndHealthDef;
      end
    end
  else // if MoveInfo.MoveType in [mtMove,mtCapture,mtSpyMission] then
    begin
    if (Master>=0) and (PModel.Domain<dSea) then
      begin // transport unload
      MoveInfo.Cost:=PModel.Speed;
      if RealMap[ToLoc] and fTerrain<fGrass then
        result:=eDomainMismatch;
      end
    else
      begin
      result:=GetMoveCost(p,mix,FromLoc,ToLoc,MoveLength,MoveInfo.Cost);
      if result=eMountains then
        begin result:=eOk; MoveInfo.MountainDelay:=true end;
      end;
    if (result>=rExecuted) and (MoveInfo.MoveType=mtSpyMission) then
      result:=eMissionDone;

    MoveInfo.ToMaster:=-1;
    if (result=eDomainMismatch) and (PModel.Domain<dSea)
      and (PModel.Cap[mcOver]=0) then
      begin
      for uix1:=0 to nUn-1 do with Un[uix1] do // check load to transport
        if (Loc=ToLoc)
          and (TroopLoad<Model[mix].MTrans*Model[mix].Cap[mcSeaTrans]) then
          begin
          result:=eLoaded;
          MoveInfo.Cost:=PModel.Speed;
          MoveInfo.ToMaster:=uix1;
          if (uixSelectedTransport>=0) and (uix1=uixSelectedTransport) then
            Break;
          end;
      end
    else if (PModel.Domain=dAir) and (PModel.Cap[mcAirTrans]=0)
      and (RealMap[ToLoc] and fCity=0) and (RealMap[ToLoc] and fTerImp<>tiBase) then
      begin
      for uix1:=0 to nUn-1 do with Un[uix1] do
        if (Loc=ToLoc)
          and (AirLoad<Model[mix].MTrans*Model[mix].Cap[mcCarrier]) then
          begin// load plane to ship
          result:=eLoaded;
          MoveInfo.ToMaster:=uix1;
          if (uixSelectedTransport>=0) and (uix1=uixSelectedTransport) then
            Break;
          end
      end;
    if result<rExecuted then exit;

    if (Master<0) and (MoveInfo.ToMaster<0) then
      MoveInfo.EndHealth:=Health-HostileDamage(p,mix,ToLoc,MoveInfo.Cost)
    else MoveInfo.EndHealth:=Health;

    if (Mode=moPlaying)
      and (PModel.Flags and mdZOC<>0)
      and (Master<0) and (MoveInfo.ToMaster<0)
      and (Controlled(p,FromLoc,false)>=coTrue) then
      begin
      DestControlled:=Controlled(p,ToLoc,true);
      if DestControlled>=coTrue+coKnown then
        begin result:=eZOC; exit end
      else if not TestOnly and (DestControlled>=coTrue) then
        begin result:=eZOC_EnemySpotted; exit end
      end;
    if (Movement=0) and (ServerVersion[p]>=$0100F1) or (MoveInfo.Cost>Movement) then
      if (Master>=0) or (MoveInfo.ToMaster>=0) then
        begin result:=eNoTime_Load; exit end
      else begin result:=eNoTime_Move; exit end;
    if (MoveInfo.EndHealth<=0) or (MoveInfo.MoveType=mtSpyMission) then
      result:=result or rUnitRemoved; // spy mission or victim of HostileDamage

    end; // if MoveInfo.MoveType in [mtMove,mtCapture,mtSpyMission]

  if MoveInfo.MoveType in [mtAttack,mtExpel] then
    MoveInfo.Defender:=Occupant[ToLoc]
  else if RealMap[ToLoc] and fCity<>0 then
    begin // MoveInfo.Dcix not set yet
    MoveInfo.Defender:=RealMap[ToLoc] shr 27;
    SearchCity(ToLoc,MoveInfo.Defender,MoveInfo.Dcix);
    end
  end
end; //CalculateMove

function GetBattleForecast(Loc: integer; var BattleForecast: TBattleForecast;
  var Duix,Dcix,AStr,DStr,ABaseDamage,DBaseDamage: integer): integer;
var
Time,Defender,ABon,DBon,DCnt,MultiDamage: integer;
PModel,DModel: ^TModel;
begin
with BattleForecast do
  begin
  Defender:=Occupant[Loc];
  if (Defender<0) or (Defender=pAtt) then
    begin result:=eOK; exit end; // no attack, simple move

  PModel:=@RW[pAtt].Model[mixAtt];
  Strongest(Loc,Duix,DStr,DBon,DCnt); {get defense strength and bonus}
  if (PModel.Kind=mkDiplomat) and (RealMap[Loc] and fCity<>0) then
    begin // spy mission -- return as if move was possible
    EndHealthAtt:=HealthAtt;
    EndHealthDef:=RW[Defender].Un[Duix].Health;
    result:=eOk;
    exit
    end;

  DModel:=@RW[Defender].Model[RW[Defender].Un[Duix].mix];
  if (RealMap[Loc] and fCity=0) and (RealMap[Loc] and fTerImp<>tiBase) then
    begin
    if (DModel.Cap[mcSub]>0)
      and (RealMap[Loc] and fTerrain<fGrass)
      and (ObserveLevel[Loc] shr (2*pAtt) and 3<lObserveAll) then
      begin result:=eHiddenUnit; exit; end; //attacking submarine not allowed
    if (DModel.Cap[mcStealth]>0)
      and (ObserveLevel[Loc] shr (2*pAtt) and 3<>lObserveSuper) then
      begin result:=eStealthUnit; exit; end; //attacking stealth aircraft not allowed
    if (DModel.Domain=dAir) and (DModel.Kind<>mkSpecial_Glider)
      and (PModel.Domain<>dAir) then
      begin result:=eDomainMismatch; exit end; //can't attack plane
    end;
  if ((PModel.Cap[mcArtillery]=0)
    or ((ServerVersion[pAtt]>=$010200) and (RealMap[Loc] and fTerrain<fGrass)
      and (DModel.Cap[mcSub]>0))) // ground units can't attack submarines
    and ((PModel.Domain=dGround) and (RealMap[Loc] and fTerrain<fGrass)
      or (PModel.Domain=dSea) and (RealMap[Loc] and fTerrain>=fGrass)) then
    begin result:=eDomainMismatch; exit end;
  if (PModel.Attack=0)
    and not ((PModel.Cap[mcBombs]>0) and (FlagsAtt and unBombsLoaded<>0)
    and (DModel.Domain<dAir)) then
    begin result:=eInvalid; exit end;

  if Movement=0 then
    begin result:=eNoTime_Attack; exit end;

  {$IFOPT O-}assert(InvalidTreatyMap=0);{$ENDIF}
  if RW[pAtt].Treaty[Defender]>=trPeace then
    begin
    if (PModel.Domain<>dAir)
      and (PModel.Attack>0) and (integer(RealMap[Loc] shr 27)=pAtt) then
      if Movement>=100 then
        begin // expel friendly unit
        EndHealthDef:=RW[Defender].Un[Duix].Health;
        EndHealthAtt:=HealthAtt;
        result:=eExpelled
        end
      else result:=eNoTime_Expel
    else result:=eTreaty;
    exit;
    end;

  // calculate defender strength
  if RealMap[Loc] and fCity<>0 then
    begin // consider city improvements
    SearchCity(Loc,Defender,Dcix);
    if (PModel.Domain<dSea) and (PModel.Cap[mcArtillery]=0)
      and ((RW[Defender].City[Dcix].Built[imWalls]=1)
      or (Continent[RW[Defender].City[Dcix].Loc]=GrWallContinent[Defender])) then
      inc(DBon,8)
    else if (PModel.Domain=dSea)
      and (RW[Defender].City[Dcix].Built[imCoastalFort]=1) then
      inc(DBon,4)
    else if (PModel.Domain=dAir)
      and (RW[Defender].City[Dcix].Built[imMissileBat]=1) then
      inc(DBon,4);
    if RW[Defender].City[Dcix].Built[imBunker]=1 then
      inc(DBon,4)
    end;
  if (PModel.Domain=dAir) and (DModel.Cap[mcAirDef]>0) then
    inc(DBon,4);
  DStr:=DModel.Defense*DBon*100;
  if (DModel.Domain=dAir) and ((RealMap[Loc] and fCity<>0)
    or (RealMap[Loc] and fTerImp=tiBase)) then
    DStr:=0;
  if (DModel.Domain=dSea) and (RealMap[Loc] and fTerrain>=fGrass) then
    DStr:=DStr shr 1;

  // calculate attacker strength
  if PModel.Cap[mcWill]>0 then Time:=100
  else begin Time:=Movement; if Time>100 then Time:=100; end;
  ABon:=4+ExpAtt div ExpCost;
  AStr:=PModel.Attack;
  if (FlagsAtt and unBombsLoaded<>0) and (DModel.Domain<dAir) then // use bombs
    AStr:=AStr+PModel.Cap[mcBombs]*PModel.MStrength*2;
  AStr:=Time*AStr*ABon;

  // calculate base damage for defender
  if DStr=0 then
    DBaseDamage:=RW[Defender].Un[Duix].Health
  else
    begin
    DBaseDamage:=HealthAtt*AStr div DStr;
    if DBaseDamage=0 then
      DBaseDamage:=1;
    if DBaseDamage>RW[Defender].Un[Duix].Health then
      DBaseDamage:=RW[Defender].Un[Duix].Health
    end;

  // calculate base damage for attacker
  if AStr=0 then
    ABaseDamage:=HealthAtt
  else
    begin
    ABaseDamage:=RW[Defender].Un[Duix].Health*DStr div AStr;
    if ABaseDamage=0 then
      ABaseDamage:=1;
    if ABaseDamage>HealthAtt then
      ABaseDamage:=HealthAtt
    end;

  // calculate final damage for defender
  MultiDamage:=2;
  if (ABaseDamage=HealthAtt) and (PModel.Cap[mcFanatic]>0)
    and not (RW[pAtt].Government in [gRepublic,gDemocracy,gFuture]) then
    MultiDamage:=MultiDamage*2; // fanatic attacker died
  EndHealthDef:=RW[Defender].Un[Duix].Health-MultiDamage*DBaseDamage div 2;
  if EndHealthDef<0 then EndHealthDef:=0;

  // calculate final damage for attacker
  MultiDamage:=2;
  if DBaseDamage=RW[Defender].Un[Duix].Health then
    begin
    if (DModel.Cap[mcFanatic]>0)
      and not (RW[Defender].Government in [gRepublic,gDemocracy,gFuture]) then
      MultiDamage:=MultiDamage*2; // fanatic defender died
    if PModel.Cap[mcFirst]>0 then
      MultiDamage:=MultiDamage shr 1; // first strike unit wins
    end;
  Time:=Movement; if Time>100 then Time:=100;
  EndHealthAtt:=HealthAtt-MultiDamage*ABaseDamage div 2-HostileDamage(pAtt,mixAtt,Loc,Time);
  if EndHealthAtt<0 then EndHealthAtt:=0;

  if EndHealthDef>0 then result:=eLost
  else if EndHealthAtt>0 then result:=eWon
  else result:=eBloody
  end
end; //GetBattleForecast

function LoadUnit(p,uix: integer; TestOnly: boolean): integer;
var
uix1,d,Cost,ToMaster: integer;
begin
result:=eOk;
with RW[p].Un[uix] do
  begin
  d:=RW[p].Model[mix].Domain;
  if (Master>=0) or (d=dSea)
    or (RW[p].Model[mix].Cap[mcAirTrans]
    +RW[p].Model[mix].Cap[mcOver]>0) then
    result:=eViolation
  else
    begin
    ToMaster:=-1;
    for uix1:=0 to RW[p].nUn-1 do if RW[p].Un[uix1].Loc=Loc then
      with RW[p].Un[uix1], RW[p].Model[mix] do
        if (d<dSea) and (TroopLoad<MTrans*(Cap[mcSeaTrans]+Cap[mcAirTrans]))
          or (d=dAir) and (AirLoad<MTrans*Cap[mcCarrier]) then
          begin {load onto unit uix1}
          if (uixSelectedTransport<0) or (uix1=uixSelectedTransport) then
            begin ToMaster:=uix1; Break end
          else if ToMaster<0 then
            ToMaster:=uix1;
          end;
    if ToMaster<0 then result:=eNoLoadCapacity
    else
      begin
      if d=dAir then Cost:=100
      else Cost:=RW[p].Model[mix].Speed;
      if Movement<Cost then result:=eNoTime_Load
      else if not TestOnly then
        begin
        FreeUnit(p,uix);
        dec(Movement,Cost);
        if d=dAir then inc(RW[p].Un[ToMaster].AirLoad)
        else inc(RW[p].Un[ToMaster].TroopLoad);
        Master:=ToMaster;
        UpdateUnitMap(Loc);
        end
      end
    end
  end
end;

function UnloadUnit(p,uix: integer; TestOnly: boolean): integer;
var
Cost: integer;
begin
result:=eOk;
with RW[p].Un[uix] do
  if Master<0 then result:=eNotChanged
  else if (RW[p].Model[mix].Domain<dSea)
    and (RealMap[Loc] and fTerrain<fGrass) then result:=eDomainMismatch
//    else if (RW[p].Model[mix].Domain<dSea)
//      and (RW[p].Model[mix].Flags and mdCivil<>0)
//      and (RealMap[Loc] and fDeadLands<>0) then result:=eEerie
  else
    begin
    if RW[p].Model[mix].Domain=dAir then Cost:=100
    else Cost:=RW[p].Model[mix].Speed;
    if Movement<Cost then result:=eNoTime_Load
    else if not TestOnly then
      begin
      dec(Movement,Cost);
      if RW[p].Model[mix].Domain=dAir then
        dec(RW[p].Un[Master].AirLoad)
      else
        begin
        dec(RW[p].Un[Master].TroopLoad);
//            Movement:=0 // no more movement after unload
        end;
      Master:=-1;
      PlaceUnit(p,uix);
      UpdateUnitMap(Loc);
      end;
    end
end;

procedure Recover(p,uix: integer);
var
cix,Recovery: integer;
begin
with RW[p],Un[uix] do
  begin
  if (Master>=0) and (Model[Un[Master].mix].Cap[mcSupplyShip]>0) then
    Recovery:=FastRecovery {hospital ship}
  else if RealMap[Loc] and fTerImp=tiBase then
    Recovery:=CityRecovery
  else if RealMap[Loc] and fCity<>0 then
    begin {unit in city}
    cix:=nCity-1;
    while (cix>=0) and (City[cix].Loc<>Loc) do dec(cix);
    if City[cix].Flags and chDisorder<>0 then
      Recovery:=NoCityRecovery
    else if (Model[mix].Domain=dGround)
        and (City[cix].Built[imBarracks]+City[cix].Built[imElite]>0)
      or (Model[mix].Domain=dSea) and (City[cix].Built[imDockyard]=1)
      or (Model[mix].Domain=dAir) and (City[cix].Built[imAirport]=1) then
      Recovery:=FastRecovery {city has baracks/shipyard/airport}
    else Recovery:=CityRecovery
    end
  else if (RealMap[Loc] and fTerrain>=fGrass) and (Model[mix].Domain<>dAir) then
    Recovery:=NoCityRecovery
  else Recovery:=0;

  Recovery:=Recovery*Movement div Model[mix].Speed; {recovery depends on movement unused}
  if Recovery>Health then Recovery:=Health; // health max. doubled each turn
  if Recovery>100-Health then Recovery:=100-Health;
  inc(Health,Recovery);
  end;
end;

function GetMoveAdvice(p,uix: integer; var a: TMoveAdviceData): integer;
const
//domains
gmaAir=0; gmaSea=1; gmaGround_NoZoC=2; gmaGround_ZoC=3;
//flags
gmaNav=4; gmaOver=4; gmaAlpine=8;
var
i,FromLoc,EndLoc,T,T1,maxmov,initmov,Loc,Loc1,FromTile,ToTile,V8,
  MoveInfo,HeavyCost,RailCost,MoveCost,AddDamage,MaxDamage,MovementLeft: integer;
Map: ^TTileList;
Q: TIPQ;
Adjacent: TVicinity8Loc;
From: array[0..lxmax*lymax-1] of integer;
Time: array[0..lxmax*lymax-1] of integer;
Damage: array[0..lxmax*lymax-1] of integer;
MountainDelay, Resistant: boolean;
//  tt,tt0: int64;
begin
//  QueryPerformanceCounter(tt0);

MaxDamage:=RW[p].Un[uix].Health-1;
if MaxDamage>a.MaxHostile_MovementLeft then
  if a.MaxHostile_MovementLeft>=0 then
    MaxDamage:=a.MaxHostile_MovementLeft
  else MaxDamage:=0;

Map:=@(RW[p].Map^);
if (a.ToLoc<>maNextCity) and ((a.ToLoc<0) or (a.ToLoc>=MapSize)) then
  begin result:=eInvalid; exit end;
if (a.ToLoc<>maNextCity) and (Map[a.ToLoc] and fTerrain=fUNKNOWN) then
  begin result:=eNoWay; exit end;

with RW[p].Model[RW[p].Un[uix].mix] do
  case Domain of
    dGround:
      if (a.ToLoc<>maNextCity) and (Map[a.ToLoc] and fTerrain=fOcean) then
        begin result:=eDomainMismatch; exit end
      else
        begin
        if Flags and mdZOC<>0 then MoveInfo:=gmaGround_ZoC
        else MoveInfo:=gmaGround_NoZoC;
        if Cap[mcOver]>0 then inc(MoveInfo,gmaOver);
        if Cap[mcAlpine]>0 then inc(MoveInfo,gmaAlpine);
        HeavyCost:=50+(Speed-150)*13 shr 7;
        if GWonder[woShinkansen].EffectiveOwner=p then RailCost:=0
        else RailCost:=Speed*(4*1311) shr 17;
        maxmov:=Speed;
        initmov:=0;
        Resistant:= (GWonder[woGardens].EffectiveOwner=p) or
          (Kind=mkSettler) and (Speed>=200);
        end;
    dSea:
      if (a.ToLoc<>maNextCity) and (Map[a.ToLoc] and fTerrain>=fGrass)
        and (Map[a.ToLoc] and (fCity or fUnit or fCanal)=0) then
        begin result:=eDomainMismatch; exit end
      else
        begin
        MoveInfo:=gmaSea;
        if Cap[mcNav]>0 then inc(MoveInfo,gmaNav);
        maxmov:=UnitSpeed(p,RW[p].Un[uix].mix,100);
        initmov:=maxmov-UnitSpeed(p,RW[p].Un[uix].mix,
          RW[p].Un[uix].Health);
        end;
    dAir:
      begin
      MoveInfo:=gmaAir;
      maxmov:=Speed;
      initmov:=0;
      end
    end;

FromLoc:=RW[p].Un[uix].Loc;
FillChar(Time,SizeOf(Time),255); {-1}
Damage[FromLoc]:=0;
Q:=TIPQ.Create(MapSize);
Q.Put(FromLoc,(maxmov-RW[p].Un[uix].Movement) shl 8);
while Q.Get(Loc,T) do
  begin
  Time[Loc]:=T;
  if T>=(a.MoreTurns+1) shl 20 then begin Loc:=-1; Break end;
  FromTile:=Map[Loc];
  if (Loc=a.ToLoc) or (a.ToLoc=maNextCity) and (FromTile and fCity<>0) then
    Break;
  if T and $FFF00=$FFF00 then inc(T,$100000); // indicates mountain delay
  V8_to_Loc(Loc,Adjacent);
  for V8:=0 to 7 do
    begin
    Loc1:=Adjacent[V8];
    if (Loc1>=0) and (Loc1<MapSize) and (Time[Loc1]<0) then
      begin
      ToTile:=Map[Loc1];
      if (Loc1=a.ToLoc) and (ToTile and (fUnit or fOwned)=fUnit)
        and not ((MoveInfo and 3=gmaSea) and (FromTile and fTerrain>=fGrass))
        and not ((MoveInfo and 3=gmaAir) and ((FromTile and fCity<>0)
          or (FromTile and fTerImp=tiBase))) then
        begin // attack position found
        if Q.Put(Loc1,T+1) then From[Loc1]:=Loc;
        end
      else if (ToTile and fTerrain<>fUNKNOWN)
        and ((Loc1=a.ToLoc) or (ToTile and (fCity or fOwned)<>fCity)) // don't move through enemy cities
        and ((Loc1=a.ToLoc) or (ToTile and (fUnit or fOwned)<>fUnit)) // way is blocked
        and (ToTile and not FromTile and fPeace=0)
        and ((MoveInfo and 3<gmaGround_ZoC)
          or (ToTile and FromTile and fInEnemyZoc=0)
          or (ToTile and fOwnZoCUnit<>0)
          or (FromTile and fCity<>0)
          or (ToTile and (fCity or fOwned)=fCity or fOwned)) then
        begin
        // calculate move cost, must be identic to GetMoveCost function
        AddDamage:=0;
        MountainDelay:=false;
        case MoveInfo of

          gmaAir:
            MoveCost:=50; {always valid move}

          gmaSea:
            if (ToTile and (fCity or fCanal)<>0)
              or (ToTile and fTerrain=fShore) then {domain ok}
              MoveCost:=50 {valid move}
            else MoveCost:=-1;

          gmaSea+gmaNav:
            if (ToTile and (fCity or fCanal)<>0)
              or (ToTile and fTerrain<fGrass) then {domain ok}
              MoveCost:=50 {valid move}
            else MoveCost:=-1;

          else // ground unit
            if (ToTile and fTerrain>=fGrass) then {domain ok}
              begin {valid move}
              if (FromTile and (fRR or fCity)<>0)
                and (ToTile and (fRR or fCity)<>0) then
                MoveCost:=RailCost //move along railroad
              else if (FromTile and (fRoad or fRR or fCity)<>0)
                and (ToTile and (fRoad or fRR or fCity)<>0)
                or (FromTile and ToTile and (fRiver or fCanal)<>0)
                or (MoveInfo and gmaAlpine<>0) then
                //move along road, river or canal
                if MoveInfo and gmaOver<>0 then MoveCost:=40
                else MoveCost:=20
              else if MoveInfo and gmaOver<>0 then MoveCost:=-1
              else case Terrain[ToTile and fTerrain].MoveCost of
                1: MoveCost:=50; // plain terrain
                2: MoveCost:=HeavyCost; // heavy terrain
                3:
                  begin
                  MoveCost:=maxmov;
                  MountainDelay:=true;
                  end;
                end;

              // calculate HostileDamage
              if not resistant and (ToTile and fTerImp<>tiBase) then
                if ToTile and (fTerrain or fCity or fRiver or fCanal or fSpecial1{Oasis})=fDesert then
                  begin
                  if V8 and 1<>0 then
                    AddDamage:=((DesertThurst*3)*MoveCost-1) div maxmov +1
                  else AddDamage:=((DesertThurst*2)*MoveCost-1) div maxmov +1
                  end
                else if ToTile and (fTerrain or fCity or fRiver or fCanal)=fArctic then
                  begin
                  if V8 and 1<>0 then
                    AddDamage:=((ArcticThurst*3)*MoveCost-1) div maxmov +1
                  else AddDamage:=((ArcticThurst*2)*MoveCost-1) div maxmov +1
                  end;
              end
            else MoveCost:=-1;

          end;

        if (MoveCost>0) and not MountainDelay then
          if V8 and 1<>0 then inc(MoveCost,MoveCost*2)
          else inc(MoveCost,MoveCost);

        if (MoveInfo and 2<>0) // ground unit, check transport load/unload
          and ((MoveCost<0)
            and (ToTile and (fUnit or fOwned)=fUnit or fOwned) // assume ship/airplane is transport -- load!
            or (MoveCost>=0) and (FromTile and fTerrain<fGrass)) then
          MoveCost:=maxmov; // transport load or unload

        if MoveCost>=0 then
          begin {valid move}
          MovementLeft:=maxmov-T shr 8 and $FFF-MoveCost;
          if (MovementLeft<0) or ((MoveCost=0) and (MovementLeft=0)) then
            begin // must wait for next turn
            // calculate HostileDamage
            if (MoveInfo and 2<>0){ground unit}
              and not resistant and (FromTile and fTerImp<>tiBase) then
              if FromTile and (fTerrain or fCity or fRiver or fCanal or fSpecial1{Oasis})=fDesert then
                inc(AddDamage, (DesertThurst*(maxmov-T shr 8 and $FFF)-1) div maxmov +1)
              else if FromTile and (fTerrain or fCity or fRiver or fCanal)=fArctic then
                inc(AddDamage, (ArcticThurst*(maxmov-T shr 8 and $FFF)-1) div maxmov +1);

            T1:=T and $7FF000FF +$100000+(initmov+MoveCost) shl 8;
            end
          else T1:=T+MoveCost shl 8+1;
          if MountainDelay then T1:=T1 or $FFF00;
          if (Damage[Loc]+AddDamage<=MaxDamage) and (T1 and $FF<$FF) then
            if Q.Put(Loc1,T1) then
              begin
              From[Loc1]:=Loc;
              Damage[Loc1]:=Damage[Loc]+AddDamage;
              end
          end
        end
      end
    end
  end;
Q.Free;
if (Loc=a.ToLoc) or (a.ToLoc=maNextCity) and (Loc>=0)
  and (Map[Loc] and fCity<>0) then
  begin
  a.MoreTurns:=T shr 20;
  EndLoc:=Loc;
  a.nStep:=0;
  while Loc<>FromLoc do
    begin
    if Time[Loc]<$100000 then inc(a.nStep);
    Loc:=From[Loc];
    end;
  Loc:=EndLoc;
  i:=a.nStep;
  while Loc<>FromLoc do
    begin
    if Time[Loc]<$100000 then
      begin
      dec(i);
      if i<25 then
        begin
        a.dx[i]:=((Loc mod lx *2 +Loc div lx and 1)
          -(From[Loc] mod lx *2 +From[Loc] div lx and 1)+3*lx) mod (2*lx) -lx;
        a.dy[i]:=Loc div lx-From[Loc] div lx;
        end
      end;
    Loc:=From[Loc];
    end;
  a.MaxHostile_MovementLeft:=maxmov-Time[EndLoc] shr 8 and $FFF;
  if a.nStep>25 then a.nStep:=25;
  result:=eOK
  end
else result:=eNoWay;

//  QueryPerformanceCounter(tt);{time in s is: (tt-tt0)/PerfFreq}
end; // GetMoveAdvice

function CanPlaneReturn(p,uix: integer; PlaneReturnData: TPlaneReturnData): boolean;
const
mfEnd=1; mfReached=2;
var
uix1,T,T1,Loc,Loc1,FromTile,ToTile,V8,MoveCost,maxmov: integer;
Map: ^TTileList;
Q: TIPQ;
Adjacent: TVicinity8Loc;
MapFlags: array[0..lxmax*lymax-1] of byte;
begin
Map:=@(RW[p].Map^);

// calculate possible return points
FillChar(MapFlags,SizeOf(MapFlags),0);
if RW[p].Model[RW[p].Un[uix].mix].Kind=mkSpecial_Glider then
  begin
  for Loc:=0 to MapSize-1 do
    if Map[Loc] and fTerrain>=fGrass then
      MapFlags[Loc]:=MapFlags[Loc] or mfEnd;
  end
else
  begin
  for Loc:=0 to MapSize-1 do
    if (Map[Loc] and (fCity or fOwned)=fCity or fOwned)
      or (Map[Loc] and fTerImp=tiBase) and (Map[Loc] and fObserved<>0)
        and (Map[Loc] and (fUnit or fOwned)<>fUnit) then
      MapFlags[Loc]:=MapFlags[Loc] or mfEnd;
  if RW[p].Model[RW[p].Un[uix].mix].Cap[mcAirTrans]=0 then // plane can land on carriers
    for uix1:=0 to RW[p].nUn-1 do
      with RW[p].Un[uix1], RW[p].Model[mix] do
        if AirLoad<MTrans*Cap[mcCarrier] then
          MapFlags[Loc]:=MapFlags[Loc] or mfEnd;
  end;

with RW[p].Un[uix] do
  begin
  if Master>=0 then // can return to same carrier, even if full now
    MapFlags[Loc]:=MapFlags[Loc] or mfEnd;
  maxmov:=RW[p].Model[mix].Speed;
  end;

result:=false;
Q:=TIPQ.Create(MapSize);
Q.Put(PlaneReturnData.Loc,(maxmov-PlaneReturnData.Movement) shl 8);
while Q.Get(Loc,T) do
  begin
  MapFlags[Loc]:=MapFlags[Loc] or mfReached;
  if T>=(PlaneReturnData.Fuel+1) shl 20 then
    begin result:=false; break end;
  if MapFlags[Loc] and mfEnd<>0 then
    begin result:=true; break end;
  FromTile:=Map[Loc];
  V8_to_Loc(Loc,Adjacent);
  for V8:=0 to 7 do
    begin
    Loc1:=Adjacent[V8];
    if (Loc1>=0) and (Loc1<MapSize) and (MapFlags[Loc1] and mfReached=0) then
      begin
      ToTile:=Map[Loc1];
      if (ToTile and fTerrain<>fUNKNOWN)
        and (ToTile and (fCity or fOwned)<>fCity) // don't move through enemy cities
        and (ToTile and (fUnit or fOwned)<>fUnit) // way is blocked
        and (ToTile and not FromTile and fPeace=0) then
        begin
        if V8 and 1<>0 then MoveCost:=150
        else MoveCost:=100;
        if MoveCost+T shr 8 and $FFF>maxmov then // must wait for next turn
          T1:=T and $7FF000FF +$100000+MoveCost shl 8
        else T1:=T+MoveCost shl 8;
        Q.Put(Loc1,T1);
        end
      end
    end
  end;
Q.Free;
end; // CanPlaneReturn

{
                          Terrain Improvement
 ____________________________________________________________________
}
function CalculateJobWork(p,Loc,Job: integer; var JobWork: integer): integer;
var
TerrType: integer;
begin
result:=eOK;
TerrType:=RealMap[Loc] and fTerrain;
with Terrain[TerrType] do case Job of
  jCity:
    if RealMap[Loc] and fCity<>0 then result:=eInvalid
    else if IrrEff=0 then result:=eNoCityTerrain
    else JobWork:=CityWork;
  jRoad:
    if RealMap[Loc] and (fRoad or fRR)=0 then
      begin
      JobWork:=MoveCost*RoadWork;
      if RealMap[Loc] and fRiver<>0 then
        if RW[p].Tech[adBridgeBuilding]>=tsApplicable then
          inc(JobWork,RoadBridgeWork) {across river}
        else result:=eNoBridgeBuilding
      end
    else result:=eInvalid;
  jRR:
    if RealMap[Loc] and fRoad=0 then result:=eNoPreq
    else if RealMap[Loc] and fRR<>0 then result:=eInvalid
    else
      begin
      JobWork:=MoveCost*RRWork;
      if RealMap[Loc] and fRiver<>0 then
        inc(JobWork,RRBridgeWork); {across river}
      end;
  jClear:
    if (TerrType=fDesert)
      and (GWonder[woGardens].EffectiveOwner<>p) then
      result:=eInvalid
    else if ClearTerrain>=0 then
      JobWork:=IrrClearWork
    else result:=eInvalid;
  jIrr:
    begin
    JobWork:=IrrClearWork;
    if (IrrEff=0)
      or (RealMap[Loc] and fTerImp=tiIrrigation)
      or (RealMap[Loc] and fTerImp=tiFarm) then
      result:=eInvalid
    end;
  jFarm:
    if RealMap[Loc] and fTerImp<>tiIrrigation then result:=eNoPreq
    else
      begin
      JobWork:=IrrClearWork*FarmWork;
      if (JobWork<=0) or (RealMap[Loc] and fTerImp=tiFarm) then
        result:=eInvalid
      end;
  jAfforest:
    if AfforestTerrain>=0 then
      JobWork:=MineAfforestWork
    else result:=eInvalid;
  jMine:
    begin
    JobWork:=MineAfforestWork;
    if (MineEff=0)
      or (RealMap[Loc] and fTerImp=tiMine) then
      result:=eInvalid
    end;
  jFort:
    if RealMap[Loc] and fTerImp<>tiFort then
      JobWork:=MoveCost*FortWork
    else result:=eInvalid;
  jCanal:
    if (RealMap[Loc] and fCanal=0) and (TerrType in TerrType_Canalable) then
      JobWork:=CanalWork
    else result:=eInvalid;
  jTrans:
    begin
    JobWork:=TransWork;
    if JobWork<=0 then result:=eInvalid
    end;
  jPoll:
    if RealMap[Loc] and fPoll<>0 then JobWork:=PollWork
    else result:=eInvalid;
  jBase:
    if RealMap[Loc] and fTerImp<>tiBase then
      JobWork:=MoveCost*BaseWork
    else result:=eInvalid;
  jPillage:
    if RealMap[Loc] and (fRoad or fRR or fCanal or fTerImp)<>0 then
      JobWork:=PillageWork
    else result:=eInvalid;
  end;
end; //CalculateJobWork

function StartJob(p,uix,NewJob: integer; TestOnly: boolean): integer;
var
JobWork, Loc0, p1, uix1, TerrType: integer;
begin
{$IFOPT O-}assert(1 shl p and InvalidTreatyMap=0);{$ENDIF}
result:=eOK;
with RW[p].Un[uix] do
  begin
  if NewJob=Job then
    begin result:=eNotChanged; exit end;
  if NewJob=jNone then
    begin if not TestOnly then Job:=jNone; exit end;
  Loc0:=Loc;
  if (RealMap[Loc0] and fDeadLands<>0) and (NewJob<>jRoad) and (NewJob<>jRR) then
    begin result:=eDeadLands; exit end;
  TerrType:=RealMap[Loc0] and fTerrain;
  if (RealMap[Loc0] and fCity<>0) or (TerrType<fGrass)
    or (Master>=0)
    or not ((NewJob=jPillage) and (RW[p].Model[mix].Domain=dGround)
      or (RW[p].Model[mix].Kind=mkSettler)
      or (NewJob<>jCity) and (RW[p].Model[mix].Kind=mkSlaves)
        and (GWonder[woPyramids].EffectiveOwner>=0)) then
    begin result:=eInvalid; exit end;
  if (JobPreq[NewJob]<>preNone)
    and (RW[p].Tech[JobPreq[NewJob]]<tsApplicable) then
    begin result:=eNoPreq; exit end;

  result:=CalculateJobWork(p,Loc0,NewJob,JobWork);
  if (Mode=moPlaying) and (result=eOk) and (NewJob<>jPoll) then
    begin // not allowed in territory of friendly nation
    p1:=RealMap[Loc0] shr 27; // owner of territory
    if (p1<nPl) and (p1<>p) and (RW[p].Treaty[p1]>=trPeace) then
      result:=eTreaty; // keep peace treaty!
    end;
  if TestOnly or (result<rExecuted) then exit;

  if (ToWork[Loc0,NewJob]=0) or (ToWork[Loc0,NewJob]>JobWork) then
    ToWork[Loc0,NewJob]:=JobWork;
  Job:=NewJob;
  Flags:=Flags and not unFortified;
  for uix1:=0 to RW[p].nUn-1 do
    if (RW[p].Un[uix1].Loc=Loc)
      and (RW[p].Un[uix1].Job in ContraJobs[NewJob]) then
      RW[p].Un[uix1].Job:=jNone; // stop contradictive jobs
  if ServerVersion[p]<$000EF0 then
    if Work(p,uix) then result:=eJobDone;
  if (NewJob=jCity) and (result=eJobDone) then
    begin
    RemoveUnit_UpdateMap(p,uix);
    result:=eCity
    end
  else if Health<=0 then
    begin // victim of HostileDamage
    RemoveUnit_UpdateMap(p,uix);
    result:=result or rUnitRemoved;
    end;
  if Mode>moLoading_Fast then
    begin
    if result=eCity then
      begin
      ObserveLevel[Loc0]:=ObserveLevel[Loc0] and not (3 shl (2*p));
      Discover21(Loc0,p,lObserveUnhidden,true,true);
//        CheckContact;
      end
    end
  end; // with
end; //StartJob

function Work(p,uix: integer): boolean;
var
uix1,j0: integer;
begin
result:=false;
with RW[p].Un[uix] do if Movement>=100 then
  begin
  assert(ToWork[Loc,Job]<$FFFF); // should have been set by StartJob
  if Job>=jRoad then
    if integer(Movement)>=integer(ToWork[Loc,Job]) then {work complete}
      begin
      result:=true;
      if Job<>jIrr then
        Health:=Health-HostileDamage(p,mix,Loc,ToWork[Loc,Job]);
      dec(Movement,ToWork[Loc,Job]);
      if not (Job in [jCity,jPillage,jPoll]) then
        inc(Worked[p],ToWork[Loc,Job]);
      if Job=jCity then
        begin // found new city
        FoundCity(p,Loc);
        inc(Founded[p]);
        with RW[p].City[RW[p].nCity-1] do
          begin
          ID:=p shl 12+Founded[p]-1;
          Flags:=chFounded;
          end;
        if Mode=moPlaying then
          begin
          LogCheckBorders(p,RW[p].nCity-1);
          RecalcPeaceMap(p);
          end;
        {$IFOPT O-}if Mode<moPlaying then InvalidTreatyMap:=not(1 shl p);{$ENDIF}
          // territory should not be considered for the rest of the command
          // execution, because during loading a game it's incorrect before
          // subsequent sIntExpandTerritory is processed
        RW[p].Un[uix].Health:=0; // causes unit to be removed later
        end
      else CompleteJob(p,Loc,Job);
      ToWork[Loc,Job]:=0;
      j0:=Job;
      for uix1:=0 to RW[p].nUn-1 do
        if (RW[p].Un[uix1].Loc=Loc) and (RW[p].Un[uix1].Job=j0) then
          RW[p].Un[uix1].Job:=jNone
      end
    else
      begin
      dec(ToWork[Loc,Job],Movement);
      if not (Job in [jCity,jPillage,jPoll]) then
        inc(Worked[p],Movement);
      Health:=Health-HostileDamage(p,mix,Loc,Movement);
      Movement:=0;
      end
  end
end; // work

function GetJobProgress(p,Loc: integer; var JobProgressData: TJobProgressData): integer;
var
Job,JobResult,uix: integer;
begin
for Job:=0 to nJob-1 do
  begin
  JobResult:=CalculateJobWork(p,Loc,Job,JobProgressData[Job].Required);
  if JobResult=eOk then
    begin
    if ToWork[Loc,Job]=$FFFF then // not calculated yet
      JobProgressData[Job].Done:=0
    else JobProgressData[Job].Done:=JobProgressData[Job].Required-ToWork[Loc,Job]
    end
  else
    begin
    JobProgressData[Job].Required:=0;
    JobProgressData[Job].Done:=0;
    end;
  JobProgressData[Job].NextTurnPlus:=0;
  end;
for uix:=0 to RW[p].nUn-1 do
  if (RW[p].Un[uix].Loc=Loc) and (RW[p].Un[uix].Movement>=100) then
    inc(JobProgressData[RW[p].Un[uix].Job].NextTurnPlus, RW[p].Un[uix].Movement);
result:=eOk;
end;


{
                             Start/End Game
 ____________________________________________________________________
}
procedure InitGame;
begin
GetMem(ToWork,2*MapSize*nJob);
FillChar(ToWork^,2*MapSize*nJob,$FF);
end;

procedure ReleaseGame;
begin
FreeMem(ToWork);
end;

end.

