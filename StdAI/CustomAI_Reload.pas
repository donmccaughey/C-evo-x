{$INCLUDE switches.pas}
unit CustomAI;

interface

uses
{$IFDEF DEBUG}SysUtils,{$ENDIF} // necessary for debug exceptions
  Protocol;

type
TNegoTime=(BeginOfTurn, EndOfTurn, EnemyCalled);

TCustomAI=class
public
  procedure Process(Command: integer; var Data);

  // overridables
  constructor Create(Nation: integer); virtual;
  destructor Destroy; override;
  procedure SetDataDefaults; virtual;
  procedure SetDataRandom; virtual;
  procedure OnBeforeEnemyAttack(UnitInfo: TUnitInfo;
    ToLoc, EndHealth, EndHealthDef: integer); virtual;
  procedure OnBeforeEnemyCapture(UnitInfo: TUnitInfo; ToLoc: integer); virtual;
  procedure OnAfterEnemyAttack; virtual;
  procedure OnAfterEnemyCapture; virtual;

protected
  me: integer; // index of the controlled nation
  RO: ^TPlayerContext;
  Map: ^TTileList;
  MyUnit: ^TUnList;
  MyCity: ^TCityList;
  MyModel: ^TModelList;

  cixStateImp: array[imPalace..imSpacePort] of integer;

  // negotiation
  Opponent: integer; // nation i'm in negotiation with, -1 indicates no-negotiation mode
  MyAction, MyLastAction, OppoAction: integer;
  MyOffer, MyLastOffer, OppoOffer: TOffer;

  // overridables
  procedure DoTurn; virtual;
  procedure DoNegotiation; virtual;
  function ChooseResearchAdvance: integer; virtual;
  function ChooseStealAdvance: integer; virtual;
  function ChooseGovernment: integer; virtual;
  function WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean; virtual;
  function OnNegoRejected_CancelTreaty: boolean; virtual;

  // general functions
  function IsResearched(Advance: integer): boolean;
  function ResearchCost: integer;
  function ChangeAttitude(Nation, Attitude: integer): integer;
  function Revolution: integer;
  function ChangeRates(Tax,Lux: integer): integer;
  function PrepareNewModel(Domain: integer): integer;
  function SetNewModelFeature(F, Count: integer): integer;
  function AdvanceResearchable(Advance: integer): boolean;
  function AdvanceStealable(Advance: integer): boolean;
  function DebugMessage(Level: integer; Text: string): boolean;
  function SetDebugMap(var DebugMap): boolean;

  // unit functions
  procedure Unit_FindMyDefender(Loc: integer; var uix: integer);
  procedure Unit_FindEnemyDefender(Loc: integer; var euix: integer);
  function Unit_Move(uix,ToLoc: integer): integer;
  function Unit_Step(uix,ToLoc: integer): integer;
  function Unit_Attack(uix,ToLoc: integer): integer;
  function Unit_DoMission(uix,MissionType,ToLoc: integer): integer;
  function Unit_MoveForecast(uix,ToLoc: integer; var RemainingMovement: integer): boolean;
  function Unit_AttackForecast(uix,ToLoc,AttackMovement: integer; var RemainingHealth: integer): boolean;
  function Unit_DefenseForecast(euix,ToLoc: integer; var RemainingHealth: integer): boolean;
  function Unit_Disband(uix: integer): integer;
  function Unit_StartJob(uix,NewJob: integer): integer;
  function Unit_SetHomeHere(uix: integer): integer;
  function Unit_Load(uix: integer): integer;
  function Unit_Unload(uix: integer): integer;
  function Unit_AddToCity(uix: integer): integer;

  // city functions
  procedure City_FindMyCity(Loc: integer; var cix: integer);
  procedure City_FindEnemyCity(Loc: integer; var ecix: integer);
  function City_HasProject(cix: integer): boolean;
  function City_CurrentImprovementProject(cix: integer): integer;
  function City_CurrentUnitProject(cix: integer): integer;
  function City_GetTileInfo(cix,TileLoc: integer; var TileInfo: TTileInfo): integer;
  function City_GetReport(cix: integer; var Report: TCityReport): integer;
  function City_GetHypoReport(cix, HypoTiles, HypoTax, HypoLux: integer; var Report: TCityReport): integer;
  function City_GetAreaInfo(cix: integer; var AreaInfo: TCityAreaInfo): integer;
  function City_StartUnitProduction(cix,mix: integer): integer;
  function City_StartEmigration(cix,mix: integer; AllowDisbandCity, AsConscripts: boolean): integer;
  function City_StartImprovement(cix,iix: integer): integer;
  function City_Improvable(cix,iix: integer): boolean;
  function City_StopProduction(cix: integer): integer;
  function City_BuyProject(cix: integer): integer;
  function City_SellImprovement(cix,iix: integer): integer;
  function City_RebuildImprovement(cix,iix: integer): integer;
  function City_SetTiles(cix,NewTiles: integer): integer;

  // negotiation
  function Nego_CheckMyAction: integer;

private
  HaveTurned: boolean;
  UnwantedNego: set of 0..nPl-1;
  Contacted: set of 0..nPl-1;
  procedure StealAdvance;
  end;


var
Server: TServerCall;
G: TNewGameData;
RWDataSize, MapSize: integer;
decompose24: cardinal;
nodata: pointer;

const
CityOwnTile = 13; // = ab_to_V21(0,0)

// additional return codes
rLocationReached=       $00010000; // Unit_Move: move was not interrupted, location reached
rMoreTurns=             $00020000; // Unit_Move: move was not interrupted, location not reached yet

type
TVicinity8Loc=array[0..7] of integer;
TVicinity21Loc=array[0..27] of integer;


procedure Init(NewGameData: TNewGameData);

procedure ab_to_Loc(Loc0,a,b: integer; var Loc: integer);
procedure Loc_to_ab(Loc0,Loc: integer; var a,b: integer);
procedure ab_to_V8(a,b: integer; var V8: integer);
procedure V8_to_ab(V8: integer; var a,b: integer);
procedure ab_to_V21(a,b: integer; var V21: integer);
procedure V21_to_ab(V21: integer; var a,b: integer);
procedure V8_to_Loc(Loc0: integer; var VicinityLoc: TVicinity8Loc);
procedure V21_to_Loc(Loc0: integer; var VicinityLoc: TVicinity21Loc);


implementation

const
ab_v8: array[-4..4] of integer = (5,6,7,4,-1,0,3,2,1);
v8_a: array[0..7] of integer = (1,1,0,-1,-1,-1,0,1);
v8_b: array[0..7] of integer = (0,1,1,1,0,-1,-1,-1);


procedure ab_to_Loc(Loc0,a,b: integer; var Loc: integer);
{relative location from Loc0}
var
y0: integer;
begin
assert((Loc0>=0) and (Loc0<MapSize) and (a-b+G.lx>=0));
y0:=cardinal(Loc0)*decompose24 shr 24;
Loc:=(Loc0+(a-b+y0 and 1+G.lx+G.lx) shr 1) mod G.lx +G.lx*(y0+a+b);
if Loc>=MapSize then Loc:=-$1000
end;

procedure Loc_to_ab(Loc0,Loc: integer; var a,b: integer);
{$IFDEF FPC} // freepascal
var
dx,dy: integer;
begin
dx:=((Loc mod G.lx *2 +Loc div G.lx and 1)
  -(Loc0 mod G.lx *2 +Loc0 div G.lx and 1)+3*G.lx) mod (2*G.lx) -G.lx;
dy:=Loc div G.lx-Loc0 div G.lx;
a:=(dx+dy) div 2;
b:=(dy-dx) div 2;
end;
{$ELSE} // delphi
register;
asm
push ebx

// calculate
push ecx
div byte ptr [G]
xor ebx,ebx
mov bl,ah  // ebx:=Loc0 mod G.lx
mov ecx,eax
and ecx,$000000FF // ecx:=Loc0 div G.lx
mov eax,edx
div byte ptr [G]
xor edx,edx
mov dl,ah // edx:=Loc mod G.lx
and eax,$000000FF // eax:=Loc div G.lx
sub edx,ebx // edx:=Loc mod G.lx-Loc0 mod G.lx
mov ebx,eax
sub ebx,ecx // ebx:=dy
and eax,1
and ecx,1
add edx,edx
add eax,edx
sub eax,ecx // eax:=dx, not normalized
pop ecx

// normalize
mov edx,dword ptr [G]
cmp eax,edx
jl @a
  sub eax,edx
  sub eax,edx
  jmp @ok
@a:
neg edx
cmp eax,edx
jnl @ok
  sub eax,edx
  sub eax,edx

// return results
@ok:
mov edx,ebx
sub edx,eax
add eax,ebx
sar edx,1 // edx:=b
mov ebx,[b]
mov [ebx],edx
sar eax,1 // eax:=a
mov [a],eax

pop ebx
end;
{$ENDIF}

procedure ab_to_V8(a,b: integer; var V8: integer);
begin
assert((abs(a)<=1) and (abs(b)<=1) and ((a<>0) or (b<>0)));
V8:=ab_v8[2*b+b+a];
end;

procedure V8_to_ab(V8: integer; var a,b: integer);
begin
a:=v8_a[V8]; b:=V8_b[V8];
end;

procedure ab_to_V21(a,b: integer; var V21: integer);
begin
V21:=(a+b+3) shl 2+(a-b+3) shr 1;
end;

procedure V21_to_ab(V21: integer; var a,b: integer);
var
dx,dy: integer;
begin
dy:=V21 shr 2-3;
dx:=V21 and 3 shl 1 -3 + (dy+3) and 1;
a:=(dx+dy) div 2;
b:=(dy-dx) div 2;
end;

procedure V8_to_Loc(Loc0: integer; var VicinityLoc: TVicinity8Loc);
var
x0,y0,lx: integer;
begin
lx:=G.lx;
y0:=cardinal(Loc0)*decompose24 shr 24;
x0:=Loc0-y0*lx; // Loc0 mod lx;
VicinityLoc[1]:=Loc0+lx*2;
VicinityLoc[3]:=Loc0-1;
VicinityLoc[5]:=Loc0-lx*2;
VicinityLoc[7]:=Loc0+1;
inc(Loc0,y0 and 1);
VicinityLoc[0]:=Loc0+lx;
VicinityLoc[2]:=Loc0+lx-1;
VicinityLoc[4]:=Loc0-lx-1;
VicinityLoc[6]:=Loc0-lx;

// world is round!
if x0<lx-1 then
  begin
  if x0=0 then
    begin
    inc(VicinityLoc[3],lx);
    if y0 and 1=0 then
      begin
      inc(VicinityLoc[2],lx);
      inc(VicinityLoc[4],lx);
      end
    end
  end
else
  begin
  dec(VicinityLoc[7],lx);
  if y0 and 1=1 then
    begin
    dec(VicinityLoc[0],lx);
    dec(VicinityLoc[6],lx);
    end
  end;

// check south pole
case G.ly-y0 of
  1:
    begin
    VicinityLoc[0]:=-$1000;
    VicinityLoc[1]:=-$1000;
    VicinityLoc[2]:=-$1000;
    end;
  2: VicinityLoc[1]:=-$1000;
  end
end;

procedure V21_to_Loc(Loc0: integer; var VicinityLoc: TVicinity21Loc);
var
dx,dy,bit,y0,xComp,yComp,xComp0,xCompSwitch: integer;
dst: ^integer;
begin
y0:=cardinal(Loc0)*decompose24 shr 24;
xComp0:=Loc0-y0*G.lx-1; // Loc0 mod G.lx -1
xCompSwitch:=xComp0-1+y0 and 1;
if xComp0<0 then inc(xComp0,G.lx);
if xCompSwitch<0 then inc(xCompSwitch,G.lx);
xCompSwitch:=xCompSwitch xor xComp0;
yComp:=G.lx*(y0-3);
dst:=@VicinityLoc;
bit:=1;
for dy:=0 to 6 do
  if yComp<MapSize then
    begin
    xComp0:=xComp0 xor xCompSwitch;
    xComp:=xComp0;
    for dx:=0 to 3 do
      begin
      if bit and $67F7F76<>0 then dst^:=xComp+yComp
      else dst^:=-1;
      inc(xComp);
      if xComp>=G.lx then dec(xComp, G.lx);
      inc(dst);
      bit:=bit shl 1;
      end;
    inc(yComp,G.lx);
    end
  else
    begin
    for dx:=0 to 3 do
      begin dst^:=-$1000; inc(dst); end;
    end
end;


procedure Init(NewGameData: TNewGameData);
{$IFDEF DEBUG}var Loc: integer;{$ENDIF}
begin
G:=NewGameData;
MapSize:=G.lx*G.ly;
decompose24:=(1 shl 24-1) div G.lx +1;
{$IFDEF DEBUG}for Loc:=0 to MapSize-1 do assert(cardinal(Loc)*decompose24 shr 24=cardinal(Loc div G.lx));{$ENDIF}
end;


constructor TCustomAI.Create(Nation: integer);
begin
inherited Create;
me:=Nation;
RO:=pointer(G.RO[Nation]);
Map:=pointer(RO.Map);
MyUnit:=pointer(RO.Un);
MyCity:=pointer(RO.City);
MyModel:=pointer(RO.Model);
Opponent:=-1;
end;

destructor TCustomAI.Destroy;
begin
Server(sSetDebugMap,me,0,nodata^);
end;


procedure TCustomAI.Process(Command: integer; var Data);
var
Nation,NewResearch,NewGov,count,ad,cix,iix: integer;
NegoTime: TNegoTime;
begin
case Command of
  cTurn, cContinue:
    begin
    if RO.Alive and (1 shl me)=0 then
      begin // I'm dead, huhu
      Server(sTurn,me,0,nodata^);
      exit
      end;
    if Command=cTurn then
      begin
      fillchar(cixStateImp, sizeof(cixStateImp), $FF);
      for cix:=0 to RO.nCity-1 do if MyCity[cix].Loc>=0 then
        for iix:=imPalace to imSpacePort do
          if MyCity[cix].Built[iix]>0 then
            cixStateImp[iix]:=cix;
      if RO.Happened and phChangeGov<>0 then
        begin
        NewGov:=ChooseGovernment;
        if NewGov>gAnarchy then
          Server(sSetGovernment,me,NewGov,nodata^);
        end;
      HaveTurned:=false;
      Contacted:=[];
      end;
    if (Command=cContinue) and (MyAction=scContact) then
      begin
      if OnNegoRejected_CancelTreaty then
        if RO.Treaty[Opponent]>=trPeace then
          if Server(sCancelTreaty,me,0,nodata^)<rExecuted then
            assert(false)
      end
    else UnwantedNego:=[];
    Opponent:=-1;
    repeat
      if HaveTurned then NegoTime:=EndOfTurn
      else NegoTime:=BeginOfTurn;
      if RO.Government<>gAnarchy then
        for Nation:=0 to nPl-1 do
           if (Nation<>me) and (1 shl Nation and RO.Alive<>0)
             and (RO.Treaty[Nation]>=trNone)
             and not (Nation in Contacted) and not (Nation in UnwantedNego)
             and (Server(scContact-sExecute + Nation shl 4, me, 0, nodata^)>=rExecuted) then
             if WantNegotiation(Nation, NegoTime) then
               begin
               if Server(scContact + Nation shl 4, me, 0, nodata^)>=rExecuted then
                 begin
                 include(Contacted, Nation);
                 Opponent:=Nation;
                 MyAction:=scContact;
                 exit;
                 end;
               end
             else include(UnwantedNego,Nation);
      if NegoTime=BeginOfTurn then
        begin
        DoTurn;
        HaveTurned:=true;
        Contacted:=[];
        UnwantedNego:=[];
        end
      else break;
    until false;
    if RO.Happened and phTech<>0 then
      begin
      NewResearch:=ChooseResearchAdvance;
      if NewResearch<0 then
        begin // choose random research
        count:=0;
        for ad:=0 to nAdv-1 do if AdvanceResearchable(ad) then
          begin inc(count); if random(count)=0 then NewResearch:=ad end
        end;
      Server(sSetResearch,me,NewResearch,nodata^)
      end;
    if (me=1) and (RO.Turn=800) then
      begin
      count:=0;
      Server(sReload,me,0,count)
      end
    else if (RO.Turn>10) and (random(1000)=0) then
      begin
      count:=RO.Turn-10;
      Server(sReload,me,0,count)
      end
    else if Server(sTurn,me,0,nodata^)<rExecuted then
      assert(false);
    end;
  scContact:
    if WantNegotiation(integer(Data), EnemyCalled) then
      begin
      if Server(scDipStart, me, 0, nodata^)<rExecuted then
        assert(false);
      Opponent:=integer(Data);
      MyAction:=scDipStart;
      end
    else
      begin
      if Server(scReject, me, 0, nodata^)<rExecuted then
        assert(false);
      end;
  scDipStart, scDipNotice, scDipAccept, scDipCancelTreaty, scDipOffer, scDipBreak:
    begin
    OppoAction:=Command;
    if Command=scDipOffer then OppoOffer:=TOffer(Data);
    MyLastAction:=MyAction;
    MyLastOffer:=MyOffer;
    if (OppoAction=scDipCancelTreaty) or (OppoAction=scDipBreak) then
      MyAction:=scDipNotice
    else begin MyAction:=scDipOffer; MyOffer.nDeliver:=0; MyOffer.nCost:=0; end;
    DoNegotiation;
    assert((MyAction=scDipNotice) or (MyAction=scDipAccept)
      or (MyAction=scDipCancelTreaty) or (MyAction=scDipOffer)
      or (MyAction=scDipBreak));
    if MyAction=scDipOffer then Server(MyAction, me, 0, MyOffer)
    else Server(MyAction, me, 0, nodata^);
    end;
  cShowEndContact:
    Opponent:=-1;
  end;
end;

{$HINTS OFF}
procedure TCustomAI.SetDataDefaults;
begin
end;

procedure TCustomAI.SetDataRandom;
begin
end;

procedure TCustomAI.DoTurn;
begin
end;

procedure TCustomAI.DoNegotiation;
begin
end;

procedure TCustomAI.OnBeforeEnemyAttack(UnitInfo: TUnitInfo; ToLoc, EndHealth,
  EndHealthDef: integer);
begin
end;

procedure TCustomAI.OnBeforeEnemyCapture(UnitInfo: TUnitInfo; ToLoc: integer);
begin
end;

procedure TCustomAI.OnAfterEnemyAttack;
begin
end;

procedure TCustomAI.OnAfterEnemyCapture;
begin
end;

function TCustomAI.ChooseResearchAdvance: integer;
begin
result:=-1
end;

function TCustomAI.ChooseStealAdvance: integer;
begin
result:=-1
end;

function TCustomAI.ChooseGovernment: integer;
begin
result:=gDespotism
end;

function TCustomAI.WantNegotiation(Nation: integer; NegoTime: TNegoTime): boolean;
begin
result:=false;
end;

function TCustomAI.OnNegoRejected_CancelTreaty: boolean;
begin
result:=false;
end;
{$HINTS ON}

procedure TCustomAI.StealAdvance;
var
Steal, ad, count: integer;
begin
Steal:=ChooseStealAdvance;
if Steal<0 then
  begin // choose random advance
  count:=0;
  for ad:=0 to nAdv-1 do if AdvanceStealable(ad) then
    begin inc(count); if random(count)=0 then Steal:=ad end
  end;
if Steal>=0 then Server(sStealTech,me,Steal,nodata^);
RO.Happened:=RO.Happened and not phStealTech
end;

function TCustomAI.IsResearched(Advance: integer): boolean;
begin
result:= RO.Tech[Advance]>=tsApplicable
end;

function TCustomAI.ResearchCost: integer;
begin
Server(sGetTechCost,me,0,result)
end;

function TCustomAI.ChangeAttitude(Nation, Attitude: integer): integer;
begin
result:=Server(sSetAttitude+Nation shl 4,me,Attitude,nodata^)
end;

function TCustomAI.Revolution: integer;
begin
result:=Server(sRevolution,me,0,nodata^);
end;

function TCustomAI.ChangeRates(Tax,Lux: integer): integer;
begin
result:=Server(sSetRates,me,Tax div 10 and $f+Lux div 10 and $f shl 4,nodata^)
end;

function TCustomAI.PrepareNewModel(Domain: integer): integer;
begin
result:=Server(sCreateDevModel,me,Domain,nodata^);
end;

function TCustomAI.SetNewModelFeature(F, Count: integer): integer;
begin
result:=Server(sSetDevModelCap+Count shl 4,me,F,nodata^)
end;

function TCustomAI.AdvanceResearchable(Advance: integer): boolean;
begin
result:= Server(sSetResearch-sExecute,me,Advance,nodata^)>=rExecuted;
end;

function TCustomAI.AdvanceStealable(Advance: integer): boolean;
begin
result:= Server(sStealTech-sExecute,me,Advance,nodata^)>=rExecuted;
end;

function TCustomAI.DebugMessage(Level: integer; Text: string): boolean;
begin
Text:=copy('P'+char(48+me)+' '+Text,1,254);
Server(sMessage,me,Level,pchar(Text)^);

result:=true;
  // always returns true so that it can be used like
  // "assert(DebugMessage(...));" -> not compiled in release build
end;

function TCustomAI.SetDebugMap(var DebugMap): boolean;
begin
Server(sSetDebugMap, me, 0, DebugMap);

result:=true;
  // always returns true so that it can be used like
  // "assert(SetDebugMap(...));" -> not compiled in release build
end;

procedure TCustomAI.Unit_FindMyDefender(Loc: integer; var uix: integer);
begin
if Server(sGetDefender,me,Loc,uix)<rExecuted then uix:=-1
end;

procedure TCustomAI.Unit_FindEnemyDefender(Loc: integer; var euix: integer);
begin
euix:=RO.nEnemyUn-1;
while (euix>=0) and (RO.EnemyUn[euix].Loc<>Loc) do
  dec(euix);
end;

function TCustomAI.Unit_Move(uix,ToLoc: integer): integer;
var
Step: integer;
DestinationReached: boolean;
Advice: TMoveAdviceData;
begin
assert((uix>=0) and (uix<RO.nUn) and (MyUnit[uix].Loc>=0)); // is a unit
{Loc_to_ab(MyUnit[uix].Loc,ToLoc,a,b);
assert((a<>0) or (b<>0));
if (a>=-1) and (a<=1) and (b>=-1) and (b<=1) then
  begin // move to adjacent tile
  !!!problem: if move is invalid, return codes are not consistent with other branch (eNoWay)
  Advice.nStep:=1;
  Advice.dx[0]:=a-b;
  Advice.dy[0]:=a+b;
  Advice.MoreTurns:=0;
  Advice.MaxHostile_MovementLeft:=MyUnit[uix].Movement;
  result:=eOK;
  end
else}
  begin // move to non-adjacent tile, find shortest path
  Advice.ToLoc:=ToLoc;
  Advice.MoreTurns:=9999;
  Advice.MaxHostile_MovementLeft:=100;
  result:=Server(sGetMoveAdvice,me,uix,Advice);
  end;
if result=eOk then
  begin
  DestinationReached:=false;
  Step:=0;
  repeat
    if result and (rExecuted or rUnitRemoved)=rExecuted then // check if destination reached
      if (ToLoc>=0) and (Advice.MoreTurns=0) and (Step=Advice.nStep-1)
        and ((Map[ToLoc] and (fUnit or fOwned)=fUnit) // attack
          or (Map[ToLoc] and (fCity or fOwned)=fCity)
          and ((MyModel[MyUnit[uix].mix].Domain<>dGround) // bombardment
            or (MyModel[MyUnit[uix].mix].Flags and mdCivil<>0))) then // can't capture
        begin DestinationReached:=true; break end // stop next to destination
      else if Step=Advice.nStep then
        DestinationReached:=true; // normal move -- stop at destination

    if (Step=Advice.nStep) or (result<>eOK) and (result<>eLoaded) then
      break;

    result:=Server(sMoveUnit+(Advice.dx[Step] and 7) shl 4 +(Advice.dy[Step] and 7) shl 7,
      me,uix,nodata^);
    inc(Step);
    if RO.Happened and phStealTech<>0 then StealAdvance;
  until false;
  if DestinationReached then
    if Advice.nStep=25 then
      result:=Unit_Move(uix,ToLoc) // Shinkansen
    else if Advice.MoreTurns=0 then
      result:=result or rLocationReached
    else result:=result or rMoreTurns;
  end
end;

function TCustomAI.Unit_Step(uix,ToLoc: integer): integer;
var
a,b: integer;
begin
Loc_to_ab(MyUnit[uix].Loc, ToLoc, a, b);
assert(((a<>0) or (b<>0)) and (a>=-1) and (a<=1) and (b>=-1) and (b<=1));
result:=Server(sMoveUnit+((a-b) and 7) shl 4 +((a+b) and 7) shl 7, me, uix, nodata^);
if RO.Happened and phStealTech<>0 then StealAdvance;
end;

function TCustomAI.Unit_Attack(uix,ToLoc: integer): integer;
var
a,b: integer;
begin
assert((uix>=0) and (uix<RO.nUn) and (MyUnit[uix].Loc>=0) // is a unit
  and ((Map[ToLoc] and (fUnit or fOwned)=fUnit) // is an attack
  or (Map[ToLoc] and (fCity or fOwned)=fCity)
  and (MyModel[MyUnit[uix].mix].Domain<>dGround))); // is a bombardment
Loc_to_ab(MyUnit[uix].Loc,ToLoc,a,b);
assert(((a<>0) or (b<>0)) and (a>=-1) and (a<=1) and (b>=-1) and (b<=1)); // attack to adjacent tile
result:=Server(sMoveUnit+(a-b) and 7 shl 4 +(a+b) and 7 shl 7,me,uix,nodata^);
end;

function TCustomAI.Unit_DoMission(uix,MissionType,ToLoc: integer): integer;
var
a,b: integer;
begin
result:=Server(sSetSpyMission + MissionType shl 4,me,0,nodata^);
if result>=rExecuted then
  begin
  assert((uix>=0) and (uix<RO.nUn) and (MyUnit[uix].Loc>=0) // is a unit
    and (MyModel[MyUnit[uix].mix].Kind=mkDiplomat)); // is a commando
  Loc_to_ab(MyUnit[uix].Loc,ToLoc,a,b);
  assert(((a<>0) or (b<>0)) and (a>=-1) and (a<=1) and (b>=-1) and (b<=1)); // city must be adjacent
  result:=Server(sMoveUnit-sExecute+(a-b) and 7 shl 4 +(a+b) and 7 shl 7,me,uix,nodata^);
  if result=eMissionDone then
    result:=Server(sMoveUnit+(a-b) and 7 shl 4 +(a+b) and 7 shl 7,me,uix,nodata^)
  else if (result<>eNoTime_Move) and (result<>eTreaty) and (result<>eNoTurn) then
    result:=eInvalid // not a special commando mission!
  end
end;

function TCustomAI.Unit_MoveForecast(uix,ToLoc: integer;
  var RemainingMovement: integer): boolean;
var
Advice: TMoveAdviceData;
begin
assert((uix>=0) and (uix<RO.nUn) and (MyUnit[uix].Loc>=0)); // is a unit
Advice.ToLoc:=ToLoc;
Advice.MoreTurns:=0;
Advice.MaxHostile_MovementLeft:=100;
if Server(sGetMoveAdvice,me,uix,Advice)=eOk then
  begin
  RemainingMovement:=Advice.MaxHostile_MovementLeft;
  result:=true
  end
else
  begin
  RemainingMovement:=-1;
  result:=false
  end
end;

function TCustomAI.Unit_AttackForecast(uix,ToLoc,AttackMovement: integer;
  var RemainingHealth: integer): boolean;
var
BattleForecast: TBattleForecast;
begin
assert((uix>=0) and (uix<RO.nUn) and (MyUnit[uix].Loc>=0) // is a unit
  and (Map[ToLoc] and (fUnit or fOwned)=fUnit)); // is an attack
RemainingHealth:=-$100;
result:=false;
if AttackMovement>=0 then with MyUnit[uix] do
  begin
  BattleForecast.pAtt:=me;
  BattleForecast.mixAtt:=mix;
  BattleForecast.HealthAtt:=Health;
  BattleForecast.ExpAtt:=Exp;
  BattleForecast.FlagsAtt:=Flags;
  BattleForecast.Movement:=AttackMovement;
  if Server(sGetBattleForecast,me,ToLoc,BattleForecast)>=rExecuted then
    begin
    if BattleForecast.EndHealthAtt>0 then
      RemainingHealth:=BattleForecast.EndHealthAtt
    else RemainingHealth:=-BattleForecast.EndHealthDef;
    result:=true
    end
  end
end;

function TCustomAI.Unit_DefenseForecast(euix,ToLoc: integer;
  var RemainingHealth: integer): boolean;
var
BattleForecast: TBattleForecast;
begin
assert((euix>=0) and (euix<RO.nEnemyUn) and (RO.EnemyUn[euix].Loc>=0) // is an enemy unit
  and (Map[ToLoc] and (fUnit or fOwned)=(fUnit or fOwned))); // is an attack
RemainingHealth:=$100;
result:=false;
with RO.EnemyUn[euix] do
  begin
  BattleForecast.pAtt:=Owner;
  BattleForecast.mixAtt:=mix;
  BattleForecast.HealthAtt:=Health;
  BattleForecast.ExpAtt:=Exp;
  BattleForecast.FlagsAtt:=Flags;
  BattleForecast.Movement:=100;
  if Server(sGetBattleForecast,me,ToLoc,BattleForecast)>=rExecuted then
    begin
    if BattleForecast.EndHealthDef>0 then
      RemainingHealth:=BattleForecast.EndHealthDef
    else RemainingHealth:=-BattleForecast.EndHealthAtt;
    result:=true
    end
  end
end;

function TCustomAI.Unit_Disband(uix: integer): integer;
begin
result:=Server(sRemoveUnit,me,uix,nodata^)
end;

function TCustomAI.Unit_StartJob(uix,NewJob: integer): integer;
begin
result:=Server(sStartJob+NewJob shl 4,me,uix,nodata^)
end;

function TCustomAI.Unit_SetHomeHere(uix: integer): integer;
begin
result:=Server(sSetUnitHome,me,uix,nodata^)
end;

function TCustomAI.Unit_Load(uix: integer): integer;
begin
result:=Server(sLoadUnit,me,uix,nodata^)
end;

function TCustomAI.Unit_Unload(uix: integer): integer;
begin
result:=Server(sUnloadUnit,me,uix,nodata^)
end;

function TCustomAI.Unit_AddToCity(uix: integer): integer;
begin
result:=Server(sAddToCity,me,uix,nodata^)
end;


procedure TCustomAI.City_FindMyCity(Loc: integer; var cix: integer);
begin
if Map[Loc] and (fCity or fOwned)<>fCity or fOwned then
  cix:=-1
else
  begin
  cix:=RO.nCity-1;
  while (cix>=0) and (MyCity[cix].Loc<>Loc) do
    dec(cix);
  end
end;

procedure TCustomAI.City_FindEnemyCity(Loc: integer; var ecix: integer);
begin
if Map[Loc] and (fCity or fOwned)<>fCity then
  ecix:=-1
else
  begin
  ecix:=RO.nEnemyCity-1;
  while (ecix>=0) and (RO.EnemyCity[ecix].Loc<>Loc) do
    dec(ecix);
  end
end;

function TCustomAI.City_HasProject(cix: integer): boolean;
begin
result:= MyCity[cix].Project and (cpImp+cpIndex)<>cpImp+imTrGoods
end;

function TCustomAI.City_CurrentImprovementProject(cix: integer): integer;
begin
if MyCity[cix].Project and cpImp=0 then result:=-1
else
  begin
  result:=MyCity[cix].Project and cpIndex;
  if result=imTrGoods then result:=-1
  end
end;

function TCustomAI.City_CurrentUnitProject(cix: integer): integer;
begin
if MyCity[cix].Project and cpImp<>0 then result:=-1
else result:=MyCity[cix].Project and cpIndex;
end;

function TCustomAI.City_GetTileInfo(cix,TileLoc: integer; var TileInfo: TTileInfo): integer;
begin
TileInfo.ExplCity:=cix;
result:=Server(sGetHypoCityTileInfo,me,TileLoc,TileInfo)
end;

function TCustomAI.City_GetReport(cix: integer; var Report: TCityReport): integer;
begin
Report.HypoTiles:=-1;
Report.HypoTax:=-1;
Report.HypoLux:=-1;
result:=Server(sGetCityReport,me,cix,Report)
end;

function TCustomAI.City_GetHypoReport(cix, HypoTiles, HypoTax, HypoLux: integer;
  var Report: TCityReport): integer;
begin
Report.HypoTiles:=HypoTiles;
Report.HypoTax:=HypoTax;
Report.HypoLux:=HypoLux;
result:=Server(sGetCityReport,me,cix,Report)
end;

function TCustomAI.City_GetAreaInfo(cix: integer; var AreaInfo: TCityAreaInfo): integer;
begin
result:=Server(sGetCityAreaInfo,me,cix,AreaInfo)
end;

function TCustomAI.City_StartUnitProduction(cix,mix: integer): integer;
begin
result:=Server(sSetCityProject,me,cix,mix)
end;

function TCustomAI.City_StartEmigration(cix,mix: integer;
  AllowDisbandCity, AsConscripts: boolean): integer;
var
NewProject: integer;
begin
NewProject:=mix;
if AllowDisbandCity then NewProject:=NewProject or cpDisbandCity;
if AsConscripts then NewProject:=NewProject or cpConscripts;
result:=Server(sSetCityProject,me,cix,NewProject)
end;

function TCustomAI.City_StartImprovement(cix,iix: integer): integer;
var
NewProject: integer;
begin
NewProject:=iix+cpImp;
result:=Server(sSetCityProject,me,cix,NewProject)
end;

function TCustomAI.City_Improvable(cix,iix: integer): boolean;
var
NewProject: integer;
begin
NewProject:=iix+cpImp;
result:= Server(sSetCityProject-sExecute,me,cix,NewProject)>=rExecuted;
end;

function TCustomAI.City_StopProduction(cix: integer): integer;
var
NewProject: integer;
begin
NewProject:=imTrGoods+cpImp;
result:=Server(sSetCityProject,me,cix,NewProject)
end;

function TCustomAI.City_BuyProject(cix: integer): integer;
begin
result:=Server(sBuyCityProject,me,cix,nodata^)
end;

function TCustomAI.City_SellImprovement(cix,iix: integer): integer;
begin
result:=Server(sSellCityImprovement,me,cix,iix)
end;

function TCustomAI.City_RebuildImprovement(cix,iix: integer): integer;
begin
result:=Server(sRebuildCityImprovement,me,cix,iix)
end;

function TCustomAI.City_SetTiles(cix,NewTiles: integer): integer;
begin
result:=Server(sSetCityTiles,me,cix,NewTiles)
end;


// negotiation
function TCustomAI.Nego_CheckMyAction: integer;
begin
assert(Opponent>=0); // only allowed in negotiation mode
assert((MyAction=scDipNotice) or (MyAction=scDipAccept)
  or (MyAction=scDipCancelTreaty) or (MyAction=scDipOffer)
  or (MyAction=scDipBreak));
if MyAction=scDipOffer then result:=Server(MyAction-sExecute, me, 0, MyOffer)
else result:=Server(MyAction-sExecute, me, 0, nodata^);
end;


initialization
nodata:=pointer(0);
RWDataSize:=0;

end.

