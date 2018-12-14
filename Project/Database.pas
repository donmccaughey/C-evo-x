{$INCLUDE switches}
//{$DEFINE TEXTLOG}
//{$DEFINE LOADPERF}
unit Database;

interface

uses
Protocol,CmdList;

const
// additional test flags
FastContact=false; {extra small world with railroad everywhere}

neumax=4096;
necmax=1024;
nemmax=1024;

lNoObserve=0; lObserveUnhidden=1; lObserveAll=2; lObserveSuper=3; //observe levels

TerrType_Canalable=[fGrass,fDesert,fPrairie,fTundra,fSwamp,fForest,fHills];

nStartUn=1;
StartUn: array[0..nStartUn-1] of integer=(0); //mix of start units

CityOwnTile=13;

var
GAlive, {players alive; bitset of 1 shl p}
GWatching,
GInitialized,
GAI,
RND, {world map randseed}
lx,ly,
MapSize, // = lx*ly
LandMass,
{$IFOPT O-}InvalidTreatyMap,{$ENDIF}
SaveMapCenterLoc,
PeaceEnded,
GTurn, {current turn}
GTestFlags: integer;
Mode: (moLoading_Fast, moLoading, moMovie, moPlaying);
GWonder: array[0..27] of TWonderInfo;
ServerVersion: array[0..nPl-1] of integer;
ProcessClientData: array[0..nPl-1] of boolean;
CL: TCmdList;
{$IFDEF TEXTLOG}CmdInfo: string; TextLog: TextFile;{$ENDIF}
{$IFDEF LOADPERF}time_total,time_total0,time_x0,time_x1,time_a,time_b,time_c: int64;{$ENDIF}

// map data
RealMap: array[0..lxmax*lymax-1] of Cardinal;
Continent:array[0..lxmax*lymax-1] of integer; {continent id for each tile}
Occupant:array[0..lxmax*lymax-1] of ShortInt; {occupying player for each tile}
ZoCMap:array[0..lxmax*lymax-1] of ShortInt;
ObserveLevel:array[0..lxmax*lymax-1] of Cardinal;
  {Observe Level of player p in bits 2*p and 2*p+1}
UsedByCity:array[0..lxmax*lymax-1] of integer; {location of exploiting city for
  each tile, =-1 if not exploited}

// player data
RW: array[0..nPl-1] of TPlayerContext;{player data}
Difficulty: array[0..nPl-1] of integer;
GShip: array[0..nPl-1] of TShipInfo;
ResourceMask: array[0..nPl-1] of Cardinal;
Founded: array[0..nPl-1] of integer; {number of cities founded}
TerritoryCount: array[0..nPl] of integer;
LastValidStat,
Researched,
Discovered, // number of tiles discovered
GrWallContinent: array[0..nPl-1] of integer;
RWemix: array[0..nPl-1, 0..nPl-1, 0..nmmax-1] of SmallInt;
  // [p1,p2,mix] -> index of p2's model mix in p1's enemy model list
Destroyed: array[0..nPl-1, 0..nPl-1, 0..nmmax-1] of SmallInt;
  // [p1,p2,mix] -> number of p2's units with model mix that p1 has destroyed
nTech: array[0..nPl-1] of integer; {number of known techs}
//NewContact: array[0..nPl-1,0..nPl-1] of boolean;

type
TVicinity8Loc=array[0..7] of integer;
TVicinity21Loc=array[0..27] of integer;

procedure MaskD(var x; Count, Mask: Cardinal);
procedure IntServer(Command,Player,Subject:integer;var Data);
procedure CompactLists(p: integer);
procedure ClearTestFlags(ClearFlags: integer);
procedure SetTestFlags(p,SetFlags: integer);

// Tech Related Functions
function TechBaseCost(nTech,diff: integer): integer;
function TechCost(p: integer): integer;
procedure CalculateModel(var m: TModel);
procedure CheckSpecialModels(p,pre: integer);
procedure EnableDevModel(p: integer);
procedure SeeTech(p,ad: integer);
procedure DiscoverTech(p,ad: integer);
procedure CheckExpiration(Wonder: integer);

// Location Navigation
function dLoc(Loc,dx,dy: integer): integer;
procedure dxdy(Loc0,Loc1: integer; var dx,dy: integer);
function Distance(Loc0,Loc1: integer): integer;
procedure V8_to_Loc(Loc0: integer; var VicinityLoc: TVicinity8Loc);
procedure V21_to_Loc(Loc0: integer; var VicinityLoc: TVicinity21Loc);

// Game Initialization
procedure InitRandomGame;
procedure InitMapGame(Human: integer);
procedure ReleaseGame;

// Map Editor
function MapGeneratorAvailable: boolean;
procedure CreateElevation;
procedure CreateMap(preview: boolean);
procedure InitMapEditor;
procedure ReleaseMapEditor;
procedure EditTile(Loc, NewTile: integer);

// Map Revealing
function GetTileInfo(p, cix, Loc: integer; var Info: TTileInfo): integer;
procedure Strongest(Loc:integer;var uix,Strength,Bonus,Cnt:integer);
function UnitSpeed(p, mix, Health: integer): integer;
procedure GetUnitReport(p,uix: integer; var UnitReport: TUnitReport);
procedure SearchCity(Loc: integer; var p,cix: integer);
procedure TellAboutModel(p,taOwner,tamix: integer);
function emixSafe(p,taOwner,tamix: integer): integer;
function Discover9(Loc,p,Level: integer; TellAllied, EnableContact: boolean): boolean;
function Discover21(Loc,p,AdjacentLevel: integer; TellAllied, EnableContact: boolean): boolean;
procedure DiscoverAll(p, Level: integer);
procedure DiscoverViewAreas(p: integer);
function GetUnitStack(p,Loc: integer): integer;
procedure UpdateUnitMap(Loc: integer; CityChange: boolean = false);
procedure RecalcV8ZoC(p,Loc: integer);
procedure RecalcMapZoC(p: integer);
procedure RecalcPeaceMap(p: integer);

// Territory Calculation
procedure CheckBorders(OriginLoc: integer; PlayerLosingCity: integer = -1);
procedure LogCheckBorders(p,cix: integer; PlayerLosingCity: integer = -1);

// Map Processing
procedure CreateUnit(p,mix: integer);
procedure FreeUnit(p,uix: integer);
procedure PlaceUnit(p,uix: integer);
procedure RemoveUnit(p,uix: integer; Enemy: integer = -1);
procedure RemoveUnit_UpdateMap(p,uix: integer);
procedure RemoveAllUnits(p,Loc: integer; Enemy: integer = -1);
procedure RemoveDomainUnits(d,p,Loc: integer);
procedure FoundCity(p,FoundLoc: integer);
procedure DestroyCity(p,cix: integer; SaveUnits: boolean);
procedure ChangeCityOwner(pOld,cixOld,pNew: integer);
procedure CompleteJob(p,Loc,Job: integer);

// Diplomacy
procedure IntroduceEnemy(p1,p2: integer);
procedure GiveCivilReport(p, pAbout: integer);
procedure GiveMilReport(p, pAbout: integer);
procedure ShowPrice(pSender, pTarget, Price: integer);
function PayPrice(pSender, pTarget, Price: integer; execute: boolean): boolean;
procedure CancelTreaty(p, pWith: integer; DecreaseCredibility: boolean = true);
function DoSpyMission(p,pCity,cix,Mission: integer): Cardinal;


implementation

uses
{$IFDEF LOADPERF}SysUtils, Windows,{$ENDIF}
{$IFDEF TEXTLOG}SysUtils,{$ENDIF}
IPQ;

var
UnBuilt: array[0..nPl-1] of integer; {number of units built}


procedure MaskD(var x; Count, Mask: Cardinal); Register;
asm
sub eax,4
@r: and [eax+edx*4],ecx
    dec edx
    jnz @r
end;

procedure CompactLists(p: integer);
var
uix,uix1,cix: integer;
{$IFOPT O-}V21: integer; Radius: TVicinity21Loc;{$ENDIF}
begin
with RW[p] do
  begin
  // compact unit list
  uix:=0;
  while uix<nUn do
    if Un[uix].Loc<0 then
      begin
      dec(nUn);
      Un[uix]:=Un[nUn]; {replace removed unit by last}
      if (Un[uix].TroopLoad>0) or (Un[uix].AirLoad>0) then
        for uix1:=0 to nUn-1 do
          if Un[uix1].Master=nUn then Un[uix1].Master:=uix;
            // index of last unit changes
      end
    else inc(uix);

  // compact city list
  cix:=0;
  while cix<nCity do
    if City[cix].Loc<0 then
      begin
      dec(nCity);
      City[cix]:=City[nCity]; {replace city by last}
      for uix1:=0 to nUn-1 do
        if Un[uix1].Home=nCity then Un[uix1].Home:=cix;
          {index of last city changes}
      end
    else inc(cix);

  // compact enemy city list
  cix:=0;
  while cix<nEnemyCity do
    if EnemyCity[cix].Loc<0 then
      begin
      dec(nEnemyCity);
      EnemyCity[cix]:=EnemyCity[nEnemyCity]; {replace city by last}
      end
    else inc(cix);

{$IFOPT O-}
  for cix:=0 to nCity-1 do with City[cix] do
    begin
    V21_to_Loc(Loc,Radius);
    for V21:=1 to 26 do if Tiles and (1 shl V21)<>0 then
      assert(UsedByCity[Radius[V21]]=Loc);
    end
{$ENDIF}
  end;
end; // CompactLists

{
                         Tech Related Functions
 ____________________________________________________________________
}
function TechBaseCost(nTech,diff: integer): integer;
var
c0: single;
begin
c0:=TechFormula_M[diff]*(nTech+4)*exp((nTech+4)/TechFormula_D[diff]);
if c0>=$10000000 then result:=$10000000
else result:=trunc(c0)
end;

function TechCost(p: integer): integer;
begin
with RW[p] do
  begin
  result:=TechBaseCost(nTech[p],Difficulty[p]);
  if ResearchTech>=0 then
    if (ResearchTech=adMilitary) or (Tech[ResearchTech]=tsSeen) then
      result:=result shr 1
    else if ResearchTech in FutureTech then
      if Government=gFuture then
        result:=result*2
      else result:=result*4;
  end
end;

procedure SetModelFlags(var m: TModel);
begin
m.Flags:=0;
if (m.Domain=dGround) and (m.Kind<>mkDiplomat) then
  m.Flags:=m.Flags or mdZOC;
if (m.Kind=mkDiplomat) or (m.Attack+m.Cap[mcBombs]=0) then
  m.Flags:=m.Flags or mdCivil;
if (m.Cap[mcOver]>0) or (m.Domain=dSea) and (m.Weight>=6) then
  m.Flags:=m.Flags or mdDoubleSupport;
end;

procedure CalculateModel(var m: TModel);
{calculate attack, defense, cost... of a model by features}
var
i: integer;
begin
with m do
  begin
  Attack:=(Cap[mcOffense]+Cap[mcOver])*MStrength;
  Defense:=(Cap[mcDefense]+Cap[mcOver])*MStrength;
  case Domain of
    dGround: Speed:=150+Cap[mcMob]*50;
    dSea:
      begin
      Speed:=350+200*Cap[mcNP]+200*Cap[mcTurbines];
      if Cap[mcNP]=0 then
        inc(Speed,100*Cap[mcSE]);
      end;
    dAir: Speed:=850+400*Cap[mcJet];
    end;
  Cost:=0;
  for i:=0 to nFeature-1 do
    if 1 shl Domain and Feature[i].Domains<>0 then
      inc(Cost,Cap[i]*Feature[i].Cost);
  Cost:=Cost*MCost;
  Weight:=0;
  for i:=0 to nFeature-1 do
    if 1 shl Domain and Feature[i].Domains<>0 then
      if (Domain=dGround) and (i=mcDefense) then inc(Weight,Cap[i]*2)
      else inc(Weight,Cap[i]*Feature[i].Weight);
  end;
SetModelFlags(m);
end;

procedure CheckSpecialModels(p,pre: integer);
var
i,mix1: integer;
HasAlready: boolean;
begin
for i:=0 to nSpecialModel-1 do {check whether new special model available}
  if (SpecialModelPreq[i]=pre) and (RW[p].nModel<nmmax) then
    begin
    HasAlready:=false;
    for mix1:=0 to RW[p].nModel-1 do
      if (RW[p].Model[mix1].Kind=SpecialModel[i].Kind)
        and (RW[p].Model[mix1].Attack=SpecialModel[i].Attack)
        and (RW[p].Model[mix1].Speed=SpecialModel[i].Speed) then
        HasAlready:=true;
    if not HasAlready then
      begin
      RW[p].Model[RW[p].nModel]:=SpecialModel[i];
      SetModelFlags(RW[p].Model[RW[p].nModel]);
      with RW[p].Model[RW[p].nModel] do
        begin
        Status:=0;
        SavedStatus:=0;
        IntroTurn:=GTurn;
        Built:=0;
        Lost:=0;
        ID:=p shl 12+RW[p].nModel;
        if (Kind=mkSpecial_Boat) and (ServerVersion[p]<$000EF0) then
          Speed:=350; // old longboat
        end;
      inc(RW[p].nModel);
      end
    end;
end;

procedure EnableDevModel(p: integer);
begin
with RW[p] do if nModel<nmmax then
  begin
  Model[nModel]:=DevModel;
  with Model[nModel] do
    begin
    Status:=0;
    SavedStatus:=0;
    IntroTurn:=GTurn;
    Built:=0;
    Lost:=0;
    ID:=p shl 12+nModel
    end;
  inc(nModel);
  inc(Researched[p])
  end
end;

procedure SeeTech(p,ad: integer);
begin
{$IFDEF TEXTLOG}CmdInfo:=CmdInfo+Format(' P%d:A%d', [p,ad]);{$ENDIF}
RW[p].Tech[ad]:=tsSeen;
//inc(nTech[p]);
inc(Researched[p])
end;

procedure FreeSlaves;
var
p1,uix: integer;
begin
for p1:=0 to nPl-1 do if (GAlive and (1 shl p1)<>0) then
  for uix:=0 to RW[p1].nUn-1 do
    if RW[p1].Model[RW[p1].Un[uix].mix].Kind=mkSlaves then
      RW[p1].Un[uix].Job:=jNone
end;

procedure DiscoverTech(p,ad: integer);

  procedure TellAboutKeyTech(p,Source: integer);
  var
  i,p1: integer;
  begin
  for i:=1 to 3 do if ad=AgePreq[i] then
    for p1:=0 to nPl-1 do if (p1<>p) and ((GAlive or GWatching) and (1 shl p1)<>0) then
      RW[p1].EnemyReport[p].Tech[ad]:=Source;
  end;

var
i: integer;
begin
if ad in FutureTech then
  begin
  if RW[p].Tech[ad]<tsApplicable then RW[p].Tech[ad]:=1
  else inc(RW[p].Tech[ad]);
  if ad<>futResearchTechnology then inc(nTech[p],2);
  inc(Researched[p],8);
  exit;
  end;

if RW[p].Tech[ad]=tsSeen then
  begin inc(nTech[p]); inc(Researched[p]); end
else begin inc(nTech[p],2); inc(Researched[p],2); end;
RW[p].Tech[ad]:=tsResearched;
TellAboutKeyTech(p,tsResearched);
CheckSpecialModels(p,ad);
if ad=adScience then
  ResourceMask[p]:=ResourceMask[p] or fSpecial2;
if ad=adMassProduction then
  ResourceMask[p]:=ResourceMask[p] or fModern;

for i:=0 to 27 do {check whether wonders expired}
  if (GWonder[i].EffectiveOwner<>GWonder[woEiffel].EffectiveOwner)
    and (Imp[i].Expiration=ad) then
    begin
    GWonder[i].EffectiveOwner:=-1;
    if i=woPyramids then FreeSlaves;
    end;
end;

procedure CheckExpiration(Wonder: integer);
// GWonder[Wonder].EffectiveOwner must be set before!
var
p: integer;
begin
if (Imp[Wonder].Expiration>=0)
  and (GWonder[woEiffel].EffectiveOwner<>GWonder[Wonder].EffectiveOwner) then
  for p:=0 to nPl-1 do // check if already expired
    if (1 shl p and GAlive<>0) and (RW[p].Tech[Imp[Wonder].Expiration]>=tsApplicable) then
      begin
      GWonder[Wonder].EffectiveOwner:=-1;
      if Wonder=woPyramids then FreeSlaves
      end
end;

{
                          Location Navigation
 ____________________________________________________________________
}
function dLoc(Loc,dx,dy: integer): integer;
{relative location, dx in hor and dy in ver direction from Loc}
var
y0: integer;
begin
assert((Loc>=0) and (Loc<MapSize) and (dx+lx>=0));
y0:=Loc div lx;
result:=(Loc+(dx+y0 and 1+lx+lx) shr 1) mod lx +lx*(y0+dy);
if (result<0) or (result>=MapSize) then result:=-1;
end;

procedure dxdy(Loc0,Loc1: integer; var dx,dy: integer);
begin
dx:=((Loc1 mod lx *2 +Loc1 div lx and 1)
  -(Loc0 mod lx *2 +Loc0 div lx and 1)+3*lx) mod (2*lx) -lx;
dy:=Loc1 div lx-Loc0 div lx;
end;

function Distance(Loc0,Loc1: integer): integer;
var
dx,dy: integer;
begin
dxdy(Loc0,Loc1,dx,dy);
dx:=abs(dx);
dy:=abs(dy);
result:=dx+dy+abs(dx-dy) shr 1;
end;

procedure V8_to_Loc(Loc0: integer; var VicinityLoc: TVicinity8Loc);
var
x0,y0,lx0: integer;
begin
lx0:=lx; // put in register!
y0:=Loc0 div lx0;
x0:=Loc0-y0*lx0; // Loc0 mod lx;
y0:=y0 and 1;
VicinityLoc[1]:=Loc0+lx0*2;
VicinityLoc[3]:=Loc0-1;
VicinityLoc[5]:=Loc0-lx0*2;
VicinityLoc[7]:=Loc0+1;
inc(Loc0,y0);
VicinityLoc[0]:=Loc0+lx0;
VicinityLoc[2]:=Loc0+lx0-1;
VicinityLoc[4]:=Loc0-lx0-1;
VicinityLoc[6]:=Loc0-lx0;

// world is round!
if x0<lx0-1 then
  begin
  if x0=0 then
    begin
    inc(VicinityLoc[3],lx0);
    if y0=0 then
      begin
      inc(VicinityLoc[2],lx0);
      inc(VicinityLoc[4],lx0);
      end
    end
  end
else
  begin
  dec(VicinityLoc[7],lx0);
  if y0=1 then
    begin
    dec(VicinityLoc[0],lx0);
    dec(VicinityLoc[6],lx0);
    end
  end;
end;

procedure V21_to_Loc(Loc0: integer; var VicinityLoc: TVicinity21Loc);
var
dx,dy,bit,y0,xComp,yComp,xComp0,xCompSwitch: integer;
dst: ^integer;
begin
y0:=Loc0 div lx;
xComp0:=Loc0-y0*lx-1; // Loc0 mod lx -1
xCompSwitch:=xComp0-1+y0 and 1;
if xComp0<0 then inc(xComp0,lx);
if xCompSwitch<0 then inc(xCompSwitch,lx);
xCompSwitch:=xCompSwitch xor xComp0;
yComp:=lx*(y0-3);
dst:=@VicinityLoc;
bit:=1;
for dy:=0 to 6 do
  begin
  xComp0:=xComp0 xor xCompSwitch;
  xComp:=xComp0;
  for dx:=0 to 3 do
    begin
    if bit and $67F7F76<>0 then dst^:=xComp+yComp
    else dst^:=-1;
    inc(xComp);
    if xComp>=lx then dec(xComp, lx);
    inc(dst);
    bit:=bit shl 1;
    end;
  inc(yComp,lx);
  end;
end;


{
                             Map Creation
 ____________________________________________________________________
}
var
primitive: integer;
StartLoc, StartLoc2: array[0..nPl-1] of integer; {starting coordinates}
Elevation: array[0..lxmax*lymax-1] of Byte; {map elevation}
ElCount: array[Byte] of integer; {count of elevation occurance}

procedure CalculatePrimitive;
var
i,j: integer;
begin
primitive:=1;
i:=2;
while i*i<=MapSize+1 do // test whether prime
  begin if (MapSize+1) mod i=0 then primitive:=0; inc(i) end;

if primitive>0 then
  repeat
    inc(primitive);
    i:=1;
    j:=0;
    repeat inc(j); i:=i*primitive mod (MapSize+1) until (i=1) or (j=MapSize+1);
  until j=MapSize;
end;

function MapGeneratorAvailable: boolean;
begin
result:=(primitive>0) and (lx>=20) and (ly>=40)
end;

procedure CreateElevation;
const
d=64;
Smooth=0.049;{causes low amplitude of short waves}
Detail=0.095;{causes short period of short waves}
Merge=5;{elevation merging range at the connection line of the
  round world,in relation to lx}

var
sa,ca,f1,f2:array[1..d] of single;
imerge,x,y:integer;
v,maxv:single;

  function Value(x,y:integer):single;{elevation formula}
  var
  i:integer;
  begin
  result:=0;
  for i:=1 to d do result:=result+sin(f1[i]*((x*2+y and 1)*sa[i]+y*1.5*ca[i]))
    *f2[i];
   {x values effectively multiplied with 2 to get 2 horizantal periods
   of the prime waves}
  end;

begin
for x:=1 to d do {prepare formula parameters}
  begin
  {$IFNDEF SCR}if x=1 then v:=pi/2 {first wave goes horizontal}
  else{$ENDIF} v:=Random*2*pi;
  sa[x]:=sin(v)/lx;
  ca[x]:=cos(v)/ly;
  f1[x]:=2*pi*Exp(Detail*(x-1));
  f2[x]:=Exp(-x*Smooth)
  end;

imerge:=2*lx div Merge;
FillChar(ElCount,SizeOf(ElCount),0);
maxv:=0;
for x:=0 to lx-1 do for y:=0 to ly-1 do
  begin
  v:=Value(x,y);
  if x*2<imerge then v:=(x*2*v+(imerge-x*2)*Value(x+lx,y))/imerge;
  v:=v-sqr(sqr(2*y/ly-1));{soft cut at poles}
  if v>maxv then maxv:=v;

  if v<-4 then Elevation[x+lx*y]:=0
  else if v>8.75 then Elevation[x+lx*y]:=255
  else Elevation[x+lx*y]:=Round((v+4)*20);
  inc(ElCount[Elevation[x+lx*y]])
  end;
end;

procedure FindContinents;

  procedure ReplaceCont(a,b,Stop:integer);
  {replace continent name a by b}
  // make sure always continent[loc]<=loc
  var
  i: integer;
  begin
  if a<b then begin i:=a; a:=b; b:=i end;
  if a>b then
    for i:=a to Stop do if Continent[i]=a then Continent[i]:=b
  end;

var
x,y,Loc,Wrong:integer;
begin
for y:=1 to ly-2 do for x:=0 to lx-1 do
  begin
  Loc:=x+lx*y;
  Continent[Loc]:=-1;
  if RealMap[Loc] and fTerrain>=fGrass then
    begin
    if (y-2>=1) and (RealMap[Loc-2*lx] and fTerrain>=fGrass) then
      Continent[Loc]:=Continent[Loc-2*lx];
    if (x-1+y and 1>=0) and (y-1>=1)
      and (RealMap[Loc-1+y and 1-lx] and fTerrain>=fGrass) then
      Continent[Loc]:=Continent[Loc-1+y and 1-lx];
    if (x+y and 1<lx) and (y-1>=1)
      and (RealMap[Loc+y and 1-lx] and fTerrain>=fGrass) then
      Continent[Loc]:=Continent[Loc+y and 1-lx];
    if (x-1>=0) and (RealMap[Loc-1] and fTerrain>=fGrass) then
      if Continent[Loc]=-1 then Continent[Loc]:=Continent[Loc-1]
      else ReplaceCont(Continent[Loc-1],Continent[Loc],Loc);
    if Continent[Loc]=-1 then Continent[Loc]:=Loc
    end
  end;

{connect continents due to round earth}
for y:=1 to ly-2 do if RealMap[lx*y] and fTerrain>=fGrass then
  begin
  Wrong:=-1;
  if RealMap[lx-1+lx*y] and fTerrain>=fGrass then Wrong:=Continent[lx-1+lx*y];
  if (y and 1=0) and (y-1>=1) and (RealMap[lx-1+lx*(y-1)] and fTerrain>=fGrass) then
    Wrong:=Continent[lx-1+lx*(y-1)];
  if (y and 1=0) and (y+1<ly-1)
    and (RealMap[lx-1+lx*(y+1)] and fTerrain>=fGrass) then
    Wrong:=Continent[lx-1+lx*(y+1)];
  if Wrong>=0 then ReplaceCont(Wrong,Continent[lx*y],MapSize-1)
  end;
end;

procedure RarePositions;
// distribute rare resources
// must be done after FindContinents
var
i,j,Cnt,x,y,dx,dy,Loc0,Loc1,xworst,yworst,totalrare,RareMaxWater,RareType,
  iBest,jbest,MinDist,xBlock,yBlock,V8: integer;
AreaCount, RareByArea, RareAdjacent: array[0..7,0..4] of integer;
RareLoc: array[0..11] of integer;
Dist: array[0..11,0..11] of integer;
Adjacent: TVicinity8Loc;
begin
RareMaxWater:=0;
repeat
  FillChar(AreaCount, SizeOf(AreaCount), 0);
  for y:=1 to ly-2 do
    begin
    yBlock:=y*5 div ly;
    if yBlock=(y+1)*5 div ly then for x:=0 to lx-1 do
      begin
      xBlock:=x*8 div lx;
      if xBlock=(x+1)*8 div lx then
        begin
        Loc0:=x+lx*y;
        if RealMap[Loc0] and fTerrain>=fGrass then
          begin
          Cnt:=0;
          V8_to_Loc(Loc0,Adjacent);
          for V8:=0 to 7 do
            begin
            Loc1:=Adjacent[V8];
            if (Loc1>=0) and (Loc1<MapSize)
              and (RealMap[Loc1] and fTerrain<fGrass) then
              inc(Cnt); // count adjacent water
            end;
          if Cnt<=RareMaxWater then // inner land
            begin
            inc(AreaCount[xBlock,yBlock]);
            if Random(AreaCount[xBlock,yBlock])=0 then
              RareByArea[xBlock,yBlock]:=Loc0
            end
          end;
        end;
      end
    end;
  totalrare:=0;
  for x:=0 to 7 do for y:=0 to 4 do if AreaCount[x,y]>0 then
    inc(totalrare);
  inc(RareMaxWater);
until totalrare>=12;

while totalrare>12 do
  begin // remove rarebyarea resources too close to each other
  FillChar(RareAdjacent,SizeOf(RareAdjacent),0);
  for x:=0 to 7 do for y:=0 to 4 do if AreaCount[x,y]>0 then
    begin
    if (AreaCount[(x+1) mod 8,y]>0)
      and (Continent[RareByArea[x,y]]=Continent[RareByArea[(x+1) mod 8,y]]) then
      begin
      inc(RareAdjacent[x,y]);
      inc(RareAdjacent[(x+1) mod 8,y]);
      end;
    if y<4 then
      begin
      if (AreaCount[x,y+1]>0)
        and (Continent[RareByArea[x,y]]=Continent[RareByArea[x,y+1]]) then
        begin
        inc(RareAdjacent[x,y]);
        inc(RareAdjacent[x,y+1]);
        end;
      if (AreaCount[(x+1) mod 8,y+1]>0)
        and (Continent[RareByArea[x,y]]=Continent[RareByArea[(x+1) mod 8,y+1]]) then
        begin
        inc(RareAdjacent[x,y]);
        inc(RareAdjacent[(x+1) mod 8,y+1]);
        end;
      if (AreaCount[(x+7) mod 8,y+1]>0)
        and (Continent[RareByArea[x,y]]=Continent[RareByArea[(x+7) mod 8,y+1]]) then
        begin
        inc(RareAdjacent[x,y]);
        inc(RareAdjacent[(x+7) mod 8,y+1]);
        end;
      end
    end;
  xworst:=0; yworst:=0;
  Cnt:=0;
  for x:=0 to 7 do for y:=0 to 4 do if AreaCount[x,y]>0 then
    begin
    if (Cnt=0) or (RareAdjacent[x,y]>RareAdjacent[xworst,yworst]) then
      begin xworst:=x; yworst:=y; Cnt:=1 end
    else if (RareAdjacent[x,y]=RareAdjacent[xworst,yworst]) then
      begin
      inc(Cnt);
      if Random(Cnt)=0 then begin xworst:=x; yworst:=y; end
      end;
    end;
  AreaCount[xworst,yworst]:=0;
  dec(totalrare)
  end;

Cnt:=0;
for x:=0 to 7 do for y:=0 to 4 do if AreaCount[x,y]>0 then
  begin RareLoc[Cnt]:=RareByArea[x,y]; inc(Cnt) end;
for i:=0 to 11 do
  begin
  RealMap[RareLoc[i]]:=RealMap[RareLoc[i]]
    and not (fTerrain or fSpecial) or (fDesert or fDeadLands);
  for dy:=-1 to 1 do for dx:=-1 to 1 do if (dx+dy) and 1=0 then
    begin
    Loc1:=dLoc(RareLoc[i],dx,dy);
    if (Loc1>=0) and (RealMap[Loc1] and fTerrain=fMountains) then
      RealMap[Loc1]:=RealMap[Loc1] and not fTerrain or fHills;
    end
  end;
for i:=0 to 11 do for j:=0 to 11 do
  Dist[i,j]:=Distance(RareLoc[i],RareLoc[j]);

MinDist:=Distance(0,MapSize-lx shr 1) shr 1;
for RareType:=1 to 3 do
  begin
  Cnt:=0;
  for i:=0 to 11 do if RareLoc[i]>=0 then
    for j:=0 to 11 do if RareLoc[j]>=0 then
      if (Cnt>0) and (Dist[iBest,jbest]>=MinDist) then
        begin
        if Dist[i,j]>=MinDist then
          begin
          inc(Cnt);
          if Random(Cnt)=0 then
            begin iBest:=i; jbest:=j end
          end
        end
      else if (Cnt=0) or (Dist[i,j]>Dist[iBest,jbest]) then
        begin iBest:=i; jbest:=j; Cnt:=1; end;
  RealMap[RareLoc[iBest]]:=RealMap[RareLoc[iBest]] or Cardinal(RareType) shl 25;
  RealMap[RareLoc[jbest]]:=RealMap[RareLoc[jbest]] or Cardinal(RareType) shl 25;
  RareLoc[iBest]:=-1;
  RareLoc[jbest]:=-1;
  end;
end; // RarePositions

function CheckShore(Loc: integer): boolean;
var
Loc1,OldTile,V21: integer;
Radius: TVicinity21Loc;
begin
result:=false;
OldTile:=RealMap[Loc];
if OldTile and fTerrain<fGrass then
  begin
  RealMap[Loc]:=RealMap[Loc] and not fTerrain or fOcean;
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize)
      and (RealMap[Loc1] and fTerrain>=fGrass)
      and (RealMap[Loc1] and fTerrain<>fArctic) then
      RealMap[Loc]:=RealMap[Loc] and not fTerrain or fShore;
    end;
  if (RealMap[Loc] xor Cardinal(OldTile)) and fTerrain<>0 then
    result:=true
  end;
end;

function ActualSpecialTile(Loc: integer): Cardinal;
begin
result:=SpecialTile(Loc, RealMap[Loc] and fTerrain, lx);
end;

procedure CreateMap(preview: boolean);
const
ShHiHills=6; {of land}
ShMountains=6; {of land}
ShRandHills=12; {of land}
ShTestRiver=40;
ShSwamp=25; {of grassland}
MinRivLen=3;
unification=70;
hotunification=50; // min. 25

Zone:array[0..3,2..9] of single= {terrain distribution}
 ((0.25,0,   0,   0.4 ,0,0,0,0.35),
  (0.55,0,   0.1 ,0,   0,0,0,0.35),
  (0.4, 0,   0.35,0,   0,0,0,0.25),
  (0,   0.7, 0,   0,   0,0,0,0.3));
  {Grs  Dst  Pra  Tun  - - - For}

  function RndLow(y:integer):Cardinal;
  {random lowland appropriate to climate}
  var
  z0,i:integer;
  p,p0,ZPlus:single;
  begin
  if ly-1-y>y then begin z0:=6*y div ly;ZPlus:=6*y/ly -z0 end
  else begin z0:=6*(ly-1-y) div ly;ZPlus:=6*(ly-1-y)/ly -z0 end;
  p0:=1;
  for i:=2 to 9 do
    begin
    p:=Zone[z0,i]*(1-ZPlus)+Zone[z0+1,i]*ZPlus;
    {weight between zones z0 and z0+1}
    if Random*p0<p then begin RndLow:=i;Break end;
    p0:=p0-p
    end;
  end;

  function RunRiver(Loc0: integer): integer;
  {runs river from start point Loc0; return value: length}
  var
  Dir,T,Loc,Loc1,Cost: integer;
  Q: TIPQ;
  From: array[0..lxmax*lymax-1] of integer;
  Time: array[0..lxmax*lymax-1] of integer;
  OneTileLake: boolean;
  begin
  FillChar(Time,SizeOf(Time),255); {-1}
  Q:=TIPQ.Create(MapSize);
  Q.Put(Loc0,0);
  while Q.Get(Loc,T) and (RealMap[Loc] and fRiver=0) do
    begin
    if (RealMap[Loc] and fTerrain<fGrass) then
      begin
      OneTileLake:=true;
      for Dir:=0 to 3 do
        begin
        Loc1:=dLoc(Loc,Dir and 1 *2 -1,Dir shr 1 *2 -1);
        if (Loc1>=0) and (RealMap[Loc1] and fTerrain<fGrass) then
          OneTileLake:=false;
        end;
      if not OneTileLake then Break;
      end;
    Time[Loc]:=T;
    for Dir:=0 to 3 do
      begin
      Loc1:=dLoc(Loc,Dir and 1 *2 -1,Dir shr 1 *2 -1);
      if (Loc1>=lx) and (Loc1<lx*(ly-1)) and (Time[Loc1]<0) then
        begin
        if RealMap[Loc1] and fRiver=0 then
          begin
          Cost:=Elevation[Loc1]-Elevation[Loc];
          if Cost<0 then Cost:=0;
          end
        else Cost:=0;
        if Q.Put(Loc1,T+Cost shl 8+1) then From[Loc1]:=Loc
        end
      end
    end;
  Loc1:=Loc;
  result:=0;
  while Loc<>Loc0 do begin Loc:=From[Loc]; inc(result); end;
  if (result>1) and ((result>=MinRivLen) or (RealMap[Loc1] and fTerrain>=fGrass)) then
    begin
    Loc:=Loc1;
    while Loc<>Loc0 do
      begin
      Loc:=From[Loc];
      if RealMap[Loc] and fTerrain in [fHills,fMountains] then
        RealMap[Loc]:=fGrass or fRiver
      else if RealMap[Loc] and fTerrain>=fGrass then
        RealMap[Loc]:=RealMap[Loc] or fRiver;
      end
    end
  else result:=0;
  Q.Free
  end;

var
x,y,n,Dir,plus,Count,Loc0,Loc1,bLand,bHills,bMountains,V8: integer;
CopyFrom: array[0..lxmax*lymax-1] of integer;
Adjacent: TVicinity8Loc;

begin
FillChar(RealMap,MapSize*4,0);
plus:=0;
bMountains:=256;
while plus<MapSize*LandMass*ShMountains div 10000 do
  begin dec(bMountains);inc(plus,ElCount[bMountains]) end;
Count:=plus;
plus:=0;
bHills:=bMountains;
while plus<MapSize*LandMass*ShHiHills div 10000 do
  begin dec(bHills);inc(plus,ElCount[bHills]) end;
inc(Count,plus);
bLand:=bHills;
while Count<MapSize*LandMass div 100 do
  begin dec(bLand);inc(Count,ElCount[bLand]) end;

for Loc0:=lx to lx*(ly-1)-1 do
  if Elevation[Loc0]>=bMountains then RealMap[Loc0]:=fMountains
  else if Elevation[Loc0]>=bHills then RealMap[Loc0]:=fHills
  else if Elevation[Loc0]>=bLand then RealMap[Loc0]:=fGrass;

// remove one-tile islands
for Loc0:=0 to MapSize-1 do
  if RealMap[Loc0]>=fGrass then
    begin
    Count:=0;
    V8_to_Loc(Loc0,Adjacent);
    for V8:=0 to 7 do
      begin
      Loc1:=Adjacent[V8];
      if (Loc1<0) or (Loc1>=MapSize)
        or (RealMap[Loc1] and fTerrain<fGrass)
        or (RealMap[Loc1] and fTerrain=fArctic) then
        inc(Count); // count adjacent water
      end;
    if Count=8 then RealMap[Loc0]:=fOcean
    end;

if not preview then
  begin
  plus:=36*56*20*ShTestRiver div (LandMass*100);
  if plus>MapSize then plus:=MapSize;
  Loc0:=Random(MapSize);
  for n:=0 to plus-1 do
    begin
    if (RealMap[Loc0] and fTerrain>=fGrass) and (Loc0>=lx) and (Loc0<MapSize-lx) then
      RunRiver(Loc0);
    Loc0:=(Loc0+1)*primitive mod (MapSize+1) -1;
    end;
  end;

for Loc0:=0 to MapSize-1 do
  if (RealMap[Loc0]=fGrass) and (Random(100)<ShRandHills) then
    RealMap[Loc0]:=RealMap[Loc0] or fHills;

// make terrain types coherent
for Loc0:=0 to MapSize-1 do CopyFrom[Loc0]:=Loc0;

for n:=0 to unification*MapSize div 100 do
  begin
  y:=Random(ly);
  if abs(y-(ly shr 1))>ly div 4+Random(ly*hotunification div 100) then
    if y<ly shr 1 then y:=ly shr 1-y
    else y:=3*ly shr 1-y;
  Loc0:=lx*y+Random(lx);
  if RealMap[Loc0] and fTerrain=fGrass then
    begin
    Dir:=Random(4);
    Loc1:=dLoc(Loc0,Dir and 1 *2 -1,Dir shr 1 *2 -1);
    if (Loc1>=0) and (RealMap[Loc1] and fTerrain=fGrass) then
      begin
      while CopyFrom[Loc0]<>Loc0 do Loc0:=CopyFrom[Loc0];
      while CopyFrom[Loc1]<>Loc1 do Loc1:=CopyFrom[Loc1];
      if Loc1<Loc0 then CopyFrom[Loc0]:=Loc1
      else CopyFrom[Loc1]:=Loc0;
      end;
    end;
  end;

for Loc0:=0 to MapSize-1 do
  if (RealMap[Loc0] and fTerrain=fGrass) and (CopyFrom[Loc0]=Loc0) then
    RealMap[Loc0]:=RealMap[Loc0] and not fTerrain or RndLow(Loc0 div lx);

for Loc0:=0 to MapSize-1 do
  if RealMap[Loc0] and fTerrain=fGrass then
    begin
    Loc1:=Loc0;
    while CopyFrom[Loc1]<>Loc1 do Loc1:=CopyFrom[Loc1];
    RealMap[Loc0]:=RealMap[Loc0] and not fTerrain or RealMap[Loc1] and fTerrain
    end;

for Loc0:=0 to MapSize-1 do
  if RealMap[Loc0] and fTerrain=fGrass then
    begin // change grassland to swamp
    if Random(100)<ShSwamp then
      RealMap[Loc0]:=RealMap[Loc0] and not fTerrain or fSwamp;
    end;

for Loc0:=0 to MapSize-1 do // change desert to prairie 1
  if RealMap[Loc0] and fTerrain=fDesert then
    begin
    if RealMap[Loc0] and fRiver<>0 then Count:=5
    else
      begin
      Count:=0;
      for Dir:=0 to 3 do
        begin
        Loc1:=dLoc(Loc0,Dir and 1 *2 -1,Dir shr 1 *2 -1);
        if Loc1>=0 then
          if RealMap[Loc1] and fTerrain<fGrass then inc(Count,2)
        end;
      end;
    if Count>=4 then RealMap[Loc0]:=RealMap[Loc0] and not fTerrain or fPrairie
    end;

for Loc0:=0 to MapSize-1 do // change desert to prairie 2
  if RealMap[Loc0] and fTerrain=fDesert then
    begin
    Count:=0;
    for Dir:=0 to 3 do
      begin
      Loc1:=dLoc(Loc0,Dir and 1 *2 -1,Dir shr 1 *2 -1);
      if Loc1>=0 then
        if RealMap[Loc1] and fTerrain<>fDesert then inc(Count)
      end;
    if Count>=4 then RealMap[Loc0]:=RealMap[Loc0] and not fTerrain or fPrairie
    end;

for Loc0:=0 to MapSize-1 do CheckShore(Loc0); // change ocean to shore
for x:=0 to lx-1 do
  begin
  RealMap[x+lx*0]:=fArctic;
  if RealMap[x+lx*1]>=fGrass then
    RealMap[x+lx*1]:=RealMap[x+lx*1] and not fTerrain or fTundra;
  if RealMap[x+lx*(ly-2)]>=fGrass then
    RealMap[x+lx*(ly-2)]:=RealMap[x+lx*(ly-2)] and not fTerrain or fTundra;
  RealMap[x+lx*(ly-1)]:=fArctic
  end;

for Loc0:=0 to MapSize-1 do //define special terrain tiles
  RealMap[Loc0]:=RealMap[Loc0] or ActualSpecialTile(Loc0) shl 5 or ($F shl 27);

if not preview then
  begin FindContinents; RarePositions; end;
end;

procedure StartPositions;
// define nation start positions
// must be done after FindContinents

var
CountGood:(cgBest,cgFlat,cgLand);

  function IsGoodTile(Loc: integer): boolean;
  var
  xLoc,yLoc: integer;
  begin
  xLoc:=Loc mod lx; yLoc:=Loc div lx;
  if RealMap[Loc] and fDeadLands<>0 then result:=false
  else
    case CountGood of
      cgBest:
        result:=(RealMap[Loc] and fTerrain in [fGrass,fPrairie,fTundra,fSwamp,fForest])
          and Odd((lymax+xLoc-yLoc shr 1) shr 1+xLoc+(yLoc+1) shr 1);
      cgFlat:
        result:=(RealMap[Loc] and fTerrain in [fGrass,fPrairie,fTundra,fSwamp,fForest]);
      cgLand:
        result:= RealMap[Loc] and fTerrain>=fGrass;
      end;
  end;

const
MaxCityLoc=64;

var
p1,p2,nAlive,c,Loc,Loc1,CntGood,CntGoodGrass,MinDist,Tries,i,j,n,nsc,TestLoc,
  V21,V8,BestDist,TestDist,MinGood,nIrrLoc,xLoc,yLoc,qx,qy,FineDistSQR,
  nRest:integer;
ccount:array[0..lxmax*lymax-1] of word;
sc,StartLoc0,sccount: array[1..nPl] of integer;
TestStartLoc: array[0..nPl-1] of integer;
CityLoc: array[1..nPl,0..MaxCityLoc-1] of integer;
nCityLoc: array[1..nPl] of integer;
RestLoc: array[0..MaxCityLoc-1] of integer;
IrrLoc: array[0..20] of integer;
Radius: TVicinity21Loc;
Adjacent: TVicinity8Loc;
ok: boolean;

begin
nAlive:=0;
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then inc(nAlive);
if nAlive=0 then exit;

{count good tiles}
FillChar(ccount,MapSize*2,0);
for Loc:=0 to MapSize-1 do
  if RealMap[Loc] and fTerrain=fGrass then
    if ActualSpecialTile(Loc)=1 then inc(ccount[Continent[Loc]],3)
    else inc(ccount[Continent[Loc]],2)
  else if RealMap[Loc] and fTerrain in [fPrairie,fSwamp,fForest,fHills] then
    inc(ccount[Continent[Loc]]);

Loc:=0;while ccount[Loc]>0 do inc(Loc);
for i:=1 to nAlive do begin sc[i]:=Loc; sccount[i]:=1 end;
  {init with zero size start continents, then search bigger ones}
for Loc:=0 to MapSize-1 do if ccount[Loc]>0 then
  begin // search biggest continents
  p1:=nAlive+1;
  while (p1>1) and (ccount[Loc]>ccount[sc[p1-1]]) do
    begin if p1<nAlive+1 then sc[p1]:=sc[p1-1]; dec(p1) end;
  if p1<nAlive+1 then sc[p1]:=Loc;
  end;
nsc:=nAlive;
repeat
  c:=1; // search least crowded continent after smallest
  for i:=2 to nsc-1 do
    if ccount[sc[i]]*(2*sccount[c]+1)>ccount[sc[c]]*(2*sccount[i]+1) then
      c:=i;
  if ccount[sc[nsc]]*(2*sccount[c]+1)>ccount[sc[c]] then
    Break; // even least crowded continent is more crowded than smallest
  inc(sccount[c]);
  dec(nsc)
until sccount[nsc]>1;

MinGood:=7;
CountGood:=cgBest;
repeat
  dec(MinGood);
  if (MinGood=3) and (CountGood<cgLand) then // too demanding!
    begin inc(CountGood); MinGood:=6 end;
  FillChar(nCityLoc,SizeOf(nCityLoc),0);
  Loc:=Random(MapSize);
  for i:=0 to MapSize-1 do
    begin
    if ((Loc>=4*lx) and (Loc<MapSize-4*lx) or (CountGood>=cgLand))
      and IsGoodTile(Loc) then
      begin
      c:=nsc;
      while (c>0) and (Continent[Loc]<>sc[c]) do dec(c);
      if (c>0) and (nCityLoc[c]<MaxCityLoc) then
        begin
        CntGood:=1;
        V21_to_Loc(Loc,Radius);
        for V21:=1 to 26 do if V21<>CityOwnTile then
          begin
          Loc1:=Radius[V21];
          if (Loc1>=0) and (Loc1<MapSize) and IsGoodTile(Loc1) then
            inc(CntGood)
          end;
        if CntGood>=MinGood then
          begin
          CityLoc[c,nCityLoc[c]]:=Loc;
          inc(nCityLoc[c])
          end
        end
      end;
    Loc:=(Loc+1)*primitive mod (MapSize+1) -1;
    end;

  ok:=true;
  for c:=1 to nsc do
    if nCityLoc[c]<sccount[c]*(8-MinGood) div (7-MinGood) then ok:=false;
until ok;

FineDistSQR:=MapSize*LandMass*9 div (nAlive*100);
p1:=1;
for c:=1 to nsc do
  begin // for all start continents
  if sccount[c]=1 then StartLoc0[p1]:=CityLoc[c,Random(nCityLoc[c])]
  else
    begin
    BestDist:=0;
    n:=1 shl sccount[c] *32; // number of tries to find good distribution
    if n>1 shl 12 then n:=1 shl 12;
    while (n>0) and (BestDist*BestDist<FineDistSQR) do
      begin
      MinDist:=MaxInt;
      nRest:=nCityLoc[c];
      for i:=0 to nRest-1 do RestLoc[i]:=CityLoc[c,i];
      for i:=0 to sccount[c]-1 do
        begin
        if nRest=0 then break;
        j:=Random(nRest);
        TestStartLoc[i]:=RestLoc[j];
        RestLoc[j]:=RestLoc[nRest-1];
        dec(nRest);
        for j:=0 to i-1 do
          begin
          TestDist:=Distance(TestStartLoc[i],TestStartLoc[j]);
          if TestDist<MinDist then MinDist:=TestDist
          end;
        if i=sccount[c]-1 then
          begin
          assert(MinDist>BestDist);
          BestDist:=MinDist;
          for j:=0 to sccount[c]-1 do StartLoc0[p1+j]:=TestStartLoc[j];
          end
        else if BestDist>0 then
          begin
          j:=0;
          while j<nRest do
            begin // remove all locs from rest which have too little distance to this one
            TestDist:=Distance(TestStartLoc[i],RestLoc[j]);
            if TestDist<=BestDist then
              begin RestLoc[j]:=RestLoc[nRest-1]; dec(nRest); end
            else inc(j);
            end;
          end;
        end;
      dec(n)
      end;
    end;
  p1:=p1+sccount[c]
  end;

// make start locs fertile
for p1:=1 to nAlive do
  begin
  RealMap[StartLoc0[p1]]:=RealMap[StartLoc0[p1]] and not (fTerrain or fSpecial)
    or fGrass or fSpecial1;
  CntGood:=1;
  CntGoodGrass:=1;
  V21_to_Loc(StartLoc0[p1],Radius);
  for V21:=1 to 26 do if V21<>CityOwnTile then
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize) and IsGoodTile(Loc1) then
      if RealMap[Loc1] and fTerrain=fGrass then inc(CntGoodGrass)
      else inc(CntGood);
    end;
  for V21:=1 to 26 do if V21<>CityOwnTile then
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize) and (RealMap[Loc1] and fDeadLands=0) then
      if IsGoodTile(Loc1) and (random(CntGood)<MinGood-CntGoodGrass+1) then
        begin
        RealMap[Loc1]:=RealMap[Loc1] and not (fTerrain or fSpecial) or fGrass;
        RealMap[Loc1]:=RealMap[Loc1] or ActualSpecialTile(Loc1) shl 5;
        end
      else if RealMap[Loc1] and fTerrain=fDesert then
        RealMap[Loc1]:=RealMap[Loc1] and not fTerrain or fPrairie
      else if (RealMap[Loc1] and fTerrain in [fPrairie,fTundra,fSwamp])
        and (random(2)=0) then
        RealMap[Loc1]:=RealMap[Loc1] and not fTerrain or fForest;
    end;

  // first irrigation
  nIrrLoc:=0;
  for V21:=1 to 26 do if V21<>CityOwnTile then
    begin
    Loc1:=Radius[V21];
    if (Loc1>=0) and (Loc1<MapSize)
      and (RealMap[Loc1] and (fTerrain or fSpecial)=fGrass or fSpecial1) then
      begin
      IrrLoc[nIrrLoc]:=Loc1;
      inc(nIrrLoc);
      end;
    end;
  i:=2;
  if i>nIrrLoc then i:=nIrrLoc;
  while i>0 do
    begin
    j:=random(nIrrLoc);
    RealMap[IrrLoc[j]]:=RealMap[IrrLoc[j]] or tiIrrigation;
    IrrLoc[j]:=IrrLoc[nIrrLoc-1];
    dec(nIrrLoc);
    dec(i)
    end;
  end;

StartLoc[0]:=0;
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
  begin
  repeat i:=Random(nAlive)+1 until StartLoc0[i]>=0;
  StartLoc[p1]:=StartLoc0[i];
  StartLoc0[i]:=-1
  end;
SaveMapCenterLoc:=StartLoc[0];

// second unit starting position
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
  begin
  StartLoc2[p1]:=StartLoc[p1];
  V8_to_Loc(StartLoc[p1],Adjacent);
  for V8:=0 to 7 do
    begin
    Loc1:=Adjacent[V8];
    for p2:=0 to nPl-1 do
      if (1 shl p2 and GAlive<>0) and (StartLoc[p2]=Loc1) then Loc1:=-1;
    for p2:=0 to p1-1 do
      if (1 shl p2 and GAlive<>0) and (StartLoc2[p2]=Loc1) then Loc1:=-1;
    if (Loc1<0) or (Loc1>=MapSize)
      or (RealMap[Loc1] and fTerrain in [fOcean, fShore, fDesert, fArctic, fMountains])
      or (RealMap[Loc1] and fDeadLands<>0) then
      TestDist:=-1
    else if RealMap[Loc1] and fTerrain=fGrass then TestDist:=2
    else if Terrain[RealMap[Loc1] and fTerrain].IrrEff>0 then TestDist:=1
    else TestDist:=0;
    if (StartLoc2[p1]=StartLoc[p1]) or (TestDist>BestDist) then
      begin StartLoc2[p1]:=Loc1; BestDist:=TestDist; n:=1; end
    else if TestDist=BestDist then
      begin inc(n); if random(n)=0 then StartLoc2[p1]:=Loc1; end;
    end
  end;
end; {StartPositions}

procedure PredefinedStartPositions(Human: integer);
// use predefined nation start positions
var
i,p1,Loc1,nAlive,nStartLoc0,nPrefStartLoc0,imax: integer;
StartLoc0: array[0..lxmax*lymax-1] of integer;
ishuman: boolean;
begin
nAlive:=0;
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then inc(nAlive);
if nAlive=0 then exit;

// calculate starting positions
nStartLoc0:=0;
nPrefStartLoc0:=0;
for Loc1:=0 to MapSize-1 do
  if RealMap[Loc1] and fPrefStartPos<>0 then
    begin
    StartLoc0[nStartLoc0]:=StartLoc0[nPrefStartLoc0];
    StartLoc0[nPrefStartLoc0]:=Loc1;
    inc(nPrefStartLoc0);
    inc(nStartLoc0);
    RealMap[Loc1]:=RealMap[Loc1] and not fPrefStartPos;
    end
  else if RealMap[Loc1] and fStartPos<>0 then
    begin
    StartLoc0[nStartLoc0]:=Loc1;
    inc(nStartLoc0);
    RealMap[Loc1]:=RealMap[Loc1] and not fStartPos;
    end;
assert(nStartLoc0>=nAlive);

StartLoc[0]:=0;
for ishuman:=true downto false do for p1:=0 to nPl-1 do
  if (1 shl p1 and GAlive<>0) and ((1 shl p1 and Human<>0)=ishuman) then
    begin
    dec(nStartLoc0);
    imax:=nStartLoc0;
    if nPrefStartLoc0>0 then
      begin
      dec(nPrefStartLoc0);
      imax:=nPrefStartLoc0;
      end;
    i:=Random(imax+1);
    StartLoc[p1]:=StartLoc0[i];
    StartLoc2[p1]:=StartLoc0[i];
    StartLoc0[i]:=StartLoc0[imax];
    StartLoc0[imax]:=StartLoc0[nStartLoc0];
    end;
SaveMapCenterLoc:=StartLoc[0];
end; {PredefinedStartPositions}

procedure InitGame;
var
i, p, p1, uix, Loc1: integer;
begin
if FastContact then {Railroad everywhere}
  for Loc1:=0 to MapSize-1 do
    if RealMap[Loc1] and fTerrain>=fGrass then RealMap[Loc1]:=RealMap[Loc1] or fRR;

{!!!for Loc1:=0 to MapSize-1 do
  if RealMap[Loc1] and fterrain>=fGrass then
    if random(3)=0 then RealMap[Loc1]:=RealMap[Loc1] or fRoad
    else if random(3)=0 then RealMap[Loc1]:=RealMap[Loc1] or fRR;
    {random Road and Railroad}
{!!!for Loc1:=0 to MapSize-1 do
  if (RealMap[Loc1] and fterrain>=fGrass) and (random(20)=0) then
    RealMap[Loc1]:=RealMap[Loc1] or fPoll;}

FillChar(Occupant,MapSize,-1);
FillChar(ZoCMap,MapSize,0);
FillChar(ObserveLevel,MapSize*4,0);
FillChar(UsedByCity,MapSize*4,-1);
GTestFlags:=0;
GInitialized:=GAlive or GWatching;
for p:=0 to nPl-1 do if 1 shl p and GInitialized<>0 then with RW[p] do
  begin
  Researched[p]:=0;
  Discovered[p]:=0;
  TerritoryCount[p]:=0;
  nTech[p]:=0;
  if Difficulty[p]=0 then ResourceMask[p]:=$FFFFFFFF
  else ResourceMask[p]:=$FFFFFFFF and not (fSpecial2 or fModern);
  GrWallContinent[p]:=-1;

  GetMem(Map,4*MapSize);
  GetMem(MapObservedLast,2*MapSize);
  FillChar(MapObservedLast^,2*MapSize,-1);
  GetMem(Territory,MapSize);
  FillChar(Territory^,MapSize,$FF);
  GetMem(Un,numax*SizeOf(TUn));
  GetMem(Model,(nmmax+1)*SizeOf(TModel)); // draft needs one model behind last
  GetMem(City,ncmax*SizeOf(TCity));
  GetMem(EnemyUn,neumax*SizeOf(TUnitInfo));
  GetMem(EnemyCity,necmax*SizeOf(TCityInfo));
  GetMem(EnemyModel,nemmax*SizeOf(TModelInfo));
  for p1:=0 to nPl-1 do
    begin
    if 1 shl p1 and GInitialized<>0 then
      begin
      FillChar(RWemix[p,p1],SizeOf(RWemix[p,p1]),255); {-1}
      FillChar(Destroyed[p,p1],SizeOf(Destroyed[p,p1]),0);
      end;
    Attitude[p1]:=atNeutral;
    Treaty[p1]:=trNoContact;
    LastCancelTreaty[p1]:=-CancelTreatyTurns-1;
    EvaStart[p1]:=-PeaceEvaTurns-1;
    Tribute[p1]:=0;
    TributePaid[p1]:=0;
    if (p1<>p) and (1 shl p1 and GAlive<>0) then
      begin // initialize enemy report
      GetMem(EnemyReport[p1],SizeOf(TEnemyReport)-2*(INFIN+1-nmmax));
      FillChar(EnemyReport[p1].Tech,nAdv,tsNA);
      EnemyReport[p1].TurnOfContact:=-1;
      EnemyReport[p1].TurnOfCivilReport:=-1;
      EnemyReport[p1].TurnOfMilReport:=-1;
      EnemyReport[p1].Attitude:=atNeutral;
      EnemyReport[p1].Government:=gDespotism;
      if 1 shl p and GAlive=0 then Treaty[p1]:=trNone // supervisor
      end
    else EnemyReport[p1]:=nil;
    end;
  TestFlags:=GTestFlags;
  Credibility:=InitialCredibility;
  MaxCredibility:=100;
  nUn:=0;
  nModel:=0;
  nCity:=0;
  nEnemyUn:=0;
  nEnemyCity:=0;
  nEnemyModel:=0;
  for Loc1:=0 to MapSize-1 do Map[Loc1]:=fUNKNOWN;
  FillChar(Tech,nAdv,tsNA);
  FillChar(NatBuilt,SizeOf(NatBuilt),0);
  end;

// create initial models and units
for p:=0 to nPl-1 do if (1 shl p and GAlive<>0) then with RW[p] do
  begin
  nModel:=0;
  for i:=0 to nSpecialModel-1 do if SpecialModelPreq[i]=preNone then
    begin
    Model[nModel]:=SpecialModel[i];
    Model[nModel].Status:=0;
    Model[nModel].IntroTurn:=0;
    Model[nModel].Built:=0;
    Model[nModel].Lost:=0;
    Model[nModel].ID:=p shl 12+nModel;
    SetModelFlags(Model[nModel]);
    inc(nModel)
    end;
  nUn:=0;
  UnBuilt[p]:=0;
  for uix:=0 to nStartUn-1 do
    begin
    CreateUnit(p, StartUn[uix]);
    dec(Model[StartUn[uix]].Built);
    Un[uix].Loc:=StartLoc2[p];
    PlaceUnit(p,uix);
    end;
  FoundCity(p,StartLoc[p]); // capital
  Founded[p]:=1;
  with City[0] do
    begin
    ID:=p shl 12;
    Flags:=chFounded;
    end;
  end;

TerritoryCount[nPl]:=MapSize;
//fillchar(NewContact, sizeof(NewContact), false);
end; // InitGame

procedure InitRandomGame;
begin
RandSeed:=RND;
CalculatePrimitive;
CreateElevation;
CreateMap(false);
StartPositions;
InitGame;
end; {InitRandomGame}

procedure InitMapGame(Human: integer);
begin
RandSeed:=RND;
FindContinents;
PredefinedStartPositions(Human);
InitGame;
end; {InitMapGame}

procedure ReleaseGame;
var
p1,p2: integer;
begin
for p1:=0 to nPl-1 do if 1 shl p1 and GInitialized<>0 then
  begin
  for p2:=0 to nPl-1 do
    if RW[p1].EnemyReport[p2]<>nil then
      FreeMem(RW[p1].EnemyReport[p2]);
  FreeMem(RW[p1].EnemyUn);
  FreeMem(RW[p1].EnemyCity);
  FreeMem(RW[p1].EnemyModel);
  FreeMem(RW[p1].Un);
  FreeMem(RW[p1].City);
  FreeMem(RW[p1].Model);
  FreeMem(RW[p1].Territory);
  FreeMem(RW[p1].MapObservedLast);
  FreeMem(RW[p1].Map);
  end
end;

procedure InitMapEditor;
var
p1: integer;
begin
CalculatePrimitive;
FillChar(Occupant,MapSize,-1);
FillChar(ObserveLevel,MapSize*4,0);
with RW[0] do
  begin
  ResourceMask[0]:=$FFFFFFFF;
  GetMem(Map,4*MapSize);
  GetMem(MapObservedLast,2*MapSize);
  FillChar(MapObservedLast^,2*MapSize,-1);
  GetMem(Territory,MapSize);
  FillChar(Territory^,MapSize,$FF);
  Un:=nil;
  Model:=nil;
  City:=nil;
  EnemyUn:=nil;
  EnemyCity:=nil;
  EnemyModel:=nil;
  for p1:=0 to nPl-1 do EnemyReport[p1]:=nil;
  nUn:=0;
  nModel:=0;
  nCity:=0;
  nEnemyUn:=0;
  nEnemyCity:=0;
  nEnemyModel:=0;
  end;
end;

procedure ReleaseMapEditor;
begin
FreeMem(RW[0].Territory);
FreeMem(RW[0].MapObservedLast);
FreeMem(RW[0].Map);
end;

procedure EditTile(Loc, NewTile: integer);
var
Loc1,V21: integer;
Radius: TVicinity21Loc;
begin
if NewTile and fDeadLands<>0 then
  NewTile:=NewTile and (fDeadLands or fModern or fRiver) or fDesert;
case NewTile and fTerrain of
  fOcean, fShore: NewTile:=NewTile and (fTerrain or fSpecial);
  fMountains,fArctic: NewTile:=NewTile and not fRiver;
  end;
with Terrain[NewTile and fTerrain] do
  if (ClearTerrain>=0) or (AfforestTerrain>=0) or (TransTerrain>=0) then
    NewTile:=NewTile or fSpecial; // only automatic special resources for transformable tiles
if NewTile and fRR<>0 then NewTile:=NewTile and not fRoad;
if not ((NewTile and fTerrain) in TerrType_Canalable) then
  NewTile:=NewTile and not fCanal;
if Terrain[NewTile and fTerrain].IrrEff=0 then
  begin
  NewTile:=NewTile and not (fPrefStartPos or fStartPos);
  if (NewTile and fTerImp=tiIrrigation) or (NewTile and fTerImp=tiFarm) then
    NewTile:=NewTile and not fTerImp
  end;
if (Terrain[NewTile and fTerrain].MineEff=0)
  and (NewTile and fTerImp=tiMine) then
  NewTile:=NewTile and not fTerImp;

RealMap[Loc]:=NewTile;
if NewTile and fSpecial=fSpecial then // standard special resource distribution
  RealMap[Loc]:=RealMap[Loc] and not fSpecial or ActualSpecialTile(Loc) shl 5;

// automatic shore tiles
V21_to_Loc(Loc,Radius);
for V21:=1 to 26 do
  begin
  Loc1:=Radius[V21];
  if (Loc1>=0) and (Loc1<MapSize) then
    begin
    if CheckShore(Loc1) then
      RealMap[Loc1]:=RealMap[Loc1] and not fSpecial or ActualSpecialTile(Loc1) shl 5;
    RealMap[Loc1]:=RealMap[Loc1] or ($F shl 27);
    RW[0].Map[Loc1]:=RealMap[Loc1] and $07FFFFFF or fObserved;
    end
  end;
//RealMap[Loc]:=RealMap[Loc] and not fSpecial;
//RW[0].Map[Loc]:=RealMap[Loc] or fObserved;
end;

{
                            Map Revealing
 ____________________________________________________________________
}
function GetTileInfo(p, cix, Loc: integer; var Info: TTileInfo): integer;
// cix>=0 - known city index of player p -- only core internal!
// cix=-1 - search city, player unknown, only if permission for p
// cix=-2 - don't search city, don't calculate city benefits, just government of player p
var
p0,Tile,special: integer;
begin
with Info do
  begin
  p0:=p;
  if cix>=0 then Tile:=RealMap[Loc]
  else
    begin
    Tile:=RW[p].Map[Loc];
    if Tile and fTerrain=fUNKNOWN then begin result:=eNoPreq; exit end;
    end;

  if (cix=-1) and (UsedByCity[Loc]>=0) then
    begin // search exploiting player and city
    SearchCity(UsedByCity[Loc],p,cix);
    if not ((p=p0) or (ObserveLevel[UsedByCity[Loc]] shr (2*p0) and 3=lObserveSuper)) then
      cix:=-1
    end;
  if cix=-1 then begin result:=eInvalid; exit end; // no city found here

  special:=Tile and fSpecial and ResourceMask[p] shr 5;
  with Terrain[Tile and fTerrain] do
    begin
    Food:=FoodRes[special];
    Prod:=ProdRes[special];
    Trade:=TradeRes[special];
    if (special>0) and (Tile and fTerrain<>fGrass)
      and (RW[p].NatBuilt[imSpacePort]>0) then
      begin // GeoSat effect
      Food:=2*Food-FoodRes[0];
      Prod:=2*Prod-ProdRes[0];
      Trade:=2*Trade-TradeRes[0];
      end;

    if (Tile and fTerImp=tiIrrigation) or (Tile and fTerImp=tiFarm)
      or (Tile and fCity<>0) then
      inc(Food,IrrEff); {irrigation effect}
    if Tile and fTerImp=tiMine then inc(Prod,MineEff); {mining effect}
    if (Tile and fRiver<>0) and (RW[p].Tech[adMapMaking]>=tsApplicable) then
      inc(Trade); {river effect}
    if (Tile and (fRoad or fRR)<>0) and (MoveCost=1)
      and (RW[p].Tech[adWheel]>=tsApplicable) then
      inc(Trade); {road effect}
    if (Tile and (fRR or fCity)<>0) and (RW[p].Tech[adRailroad]>=tsApplicable) then
      inc(Prod,Prod shr 1); {railroad effect}

    ExplCity:=-1;
    if (cix>=0) and (p=p0) then ExplCity:=cix;
    if cix>=0 then
      if Tile and fTerrain>=fGrass then
        begin
        if ((Tile and fTerImp=tiFarm) or (Tile and fCity<>0))
          and (RW[p].City[cix].Built[imSupermarket]>0) then
          inc(Food,Food shr 1); {farmland effect}
        if (Tile and (fRoad or fRR)<>0) and (MoveCost=1)
          and (RW[p].City[cix].Built[imHighways]>0) then
          inc(Trade,1); {superhighway effect}
        end
      else
        begin
        if RW[p].City[cix].Built[imHarbor]>0 then inc(Food); {harbour effect}
        if RW[p].City[cix].Built[imPlatform]>0 then inc(Prod); {oil platform effect}
        if GWonder[woLighthouse].EffectiveOwner=p then inc(Prod);
        end;
    end;

  {good government influence}
  if (RW[p].Government in [gRepublic,gDemocracy,gFuture]) and (Trade>0) then
    inc(Trade);
  if (RW[p].Government=gCommunism) and (Prod>1) then
    inc(Prod);

  if RW[p].Government in [gAnarchy,gDespotism] then
    begin {bad government influence}
    if Food>3 then Food:=3;
    if Prod>2 then Prod:=2;
    if Trade>2 then Trade:=2;
    end;

  if Tile and (fTerrain or fPoll)>fPoll then
    begin {pollution - decrease ressources}
    dec(Food,Food shr 1);
    dec(Prod,Prod shr 1);
    dec(Trade,Trade shr 1);
    end;

  if Tile and fCity<>0 then Trade:=0
  else if (cix>=0)
    and (RW[p].City[cix].Built[imCourt]+RW[p].City[cix].Built[imPalace]=0) then
    if RW[p].City[cix].Built[imTownHall]=0 then Trade:=0
    else if Trade>3 then Trade:=3;
  end;
result:=eOK;
end; {GetTileInfo}

procedure Strongest(Loc:integer;var uix,Strength,Bonus,Cnt:integer);
{find strongest defender at Loc}
var
Defender,uix1,Det,Cost,TestStrength,TestBonus,TestDet,TestCost,Domain: integer;
PUn: ^TUn;
PModel: ^TModel;
begin
Defender:=Occupant[Loc];
Cnt:=0;
Det:=-1;
for uix1:=0 to RW[Defender].nUn-1 do
  begin
  PUn:=@RW[Defender].Un[uix1];
  PModel:=@RW[Defender].Model[PUn.mix];
  if PModel.Kind=mkSpecial_Glider then Domain:=dGround
  else Domain:=PModel.Domain;
  if PUn.Loc=Loc then
    begin
    inc(Cnt);
    if PUn.Master<0 then
      begin
      if Domain<dSea then
        begin
        TestBonus:=Terrain[RealMap[Loc] and fTerrain].Defense;
        if RealMap[Loc] and fTerImp=tiFort then inc(TestBonus,4);
        if PUn.Flags and unFortified<>0 then inc(TestBonus,2);
        if (PModel.Kind=mkSpecial_TownGuard) and (RealMap[Loc] and fCity<>0) then
          inc(TestBonus,4);
        end
      else TestBonus:=4;
      inc(TestBonus,PUn.Exp div ExpCost);
      TestStrength:=PModel.Defense*TestBonus*PUn.Health;
      if (Domain=dAir) and ((RealMap[Loc] and fCity<>0)
        or (RealMap[Loc] and fTerImp=tiBase)) then
        TestStrength:=0;
      if (Domain=dSea) and (RealMap[Loc] and fTerrain>=fGrass) then
        TestStrength:=TestStrength shr 1;
      TestDet:=TestStrength;
      if PModel.Cap[mcStealth]>0 then
      else if PModel.Cap[mcSub]>0 then inc(TestDet,1 shl 28)
      else if (Domain=dGround) and (PModel.Cap[mcFanatic]>0)
        and not (RW[Defender].Government in [gRepublic,gDemocracy,gFuture]) then
        inc(TestDet,4 shl 28) // fanatic ground units always defend
      else if PModel.Flags and mdZOC<>0 then
        inc(TestDet,3 shl 28)
      else inc(TestDet,2 shl 28);
      TestCost:=RW[Defender].Model[PUn.mix].Cost;
      if (TestDet>Det) or (TestDet=Det) and (TestCost<Cost) then
        begin
        uix:=uix1;
        Strength:=TestStrength;
        Bonus:=TestBonus;
        Det:=TestDet;
        Cost:=TestCost;
        end
      end
    end
  end;
end;

function UnitSpeed(p, mix, Health: integer): integer;
begin
with RW[p].Model[mix] do
  begin
  result:=Speed;
  if Domain=dSea then
    begin
    if GWonder[woMagellan].EffectiveOwner=p then inc(result,200);
    if Health<100 then
      result:=((result-250)*Health div 5000)*50+250;
    end
  end
end;

procedure GetUnitReport(p,uix: integer; var UnitReport: TUnitReport);
var
TerrOwner: integer;
PModel: ^TModel;
begin
UnitReport.FoodSupport:=0;
UnitReport.ProdSupport:=0;
UnitReport.ReportFlags:=0;
if RW[p].Government<>gAnarchy then with RW[p].Un[uix] do
  begin
  PModel:=@RW[p].Model[mix];
  if (PModel.Kind=mkSettler) {and (GWonder[woFreeSettlers].EffectiveOwner<>p)} then
    UnitReport.FoodSupport:=SettlerFood[RW[p].Government]
  else if Flags and unConscripts<>0 then UnitReport.FoodSupport:=1;

  if RW[p].Government<>gFundamentalism then
    begin
    if GTestFlags and tfImmImprove=0 then
      begin
      if PModel.Flags and mdDoubleSupport<>0 then
        UnitReport.ProdSupport:=2
      else UnitReport.ProdSupport:=1;
      if PModel.Kind=mkSpecial_TownGuard then
        UnitReport.ReportFlags:=UnitReport.ReportFlags or urfAlwaysSupport;
      end;
    if PModel.Flags and mdCivil=0 then
      begin
      TerrOwner:=RealMap[Loc] shr 27;
      case RW[p].Government of
        gRepublic, gFuture:
          if (TerrOwner<>p) and (TerrOwner<nPl)
            and (RW[p].Treaty[TerrOwner]<trAlliance) then
            UnitReport.ReportFlags:=UnitReport.ReportFlags or urfDeployed;
        gDemocracy:
          if (TerrOwner>=nPl) or (TerrOwner<>p)
            and (RW[p].Treaty[TerrOwner]<trAlliance) then
            UnitReport.ReportFlags:=UnitReport.ReportFlags or urfDeployed;
        end;
      end
    end;
  end;
end;

procedure SearchCity(Loc: integer; var p,cix: integer);
// set p to supposed owner before call
var
i: integer;
begin
if RealMap[Loc]<nPl shl 27 then p:=RealMap[Loc] shr 27; 
for i:=0 to nPl-1 do
  begin
  if 1 shl p and GAlive<>0 then with RW[p] do
    begin
    cix:=nCity-1;
    while (cix>=0) and (City[cix].Loc<>Loc) do dec(cix);
    if cix>=0 then exit;
    end;
  assert(i<nPl-1);
  p:=(p+1) mod nPl;
  end;
end;

procedure MakeCityInfo(p, cix: integer; var ci: TCityInfo);
begin
assert((p>=0) and (p<nPl));
assert((cix>=0) and (cix<RW[p].nCity));
with RW[p].City[cix] do
  begin
  ci.Loc:=Loc;
  ci.ID:=ID;
  ci.Owner:=p;
  ci.Size:=Size;
  ci.Flags:=0;
  if Built[imPalace]>0 then inc(ci.Flags,ciCapital);
  if (Built[imWalls]>0) or (Continent[Loc]=GrWallContinent[p]) then
    inc(ci.Flags,ciWalled);
  if Built[imCoastalFort]>0 then inc(ci.Flags,ciCoastalFort);
  if Built[imMissileBat]>0 then inc(ci.Flags,ciMissileBat);
  if Built[imBunker]>0 then inc(ci.Flags,ciBunker);
  if Built[imSpacePort]>0 then inc(ci.Flags,ciSpacePort);
  end;
end;

procedure TellAboutModel(p,taOwner,tamix: integer);
var
i: integer;
begin
if (p=taOwner) or (Mode<moPlaying) then exit;
i:=0;
while (i<RW[p].nEnemyModel)
  and ((RW[p].EnemyModel[i].Owner<>taOwner)
  or (RW[p].EnemyModel[i].mix<>tamix)) do inc(i);
if i=RW[p].nEnemyModel then
  IntServer(sIntTellAboutModel+p shl 4,taOwner,tamix,nil^);
end;

function emixSafe(p,taOwner,tamix: integer): integer;
begin
result:=RWemix[p,taOwner,tamix];
if result<0 then
  begin // sIntTellAboutModel comes too late
  assert(Mode=moMovie);
  result:=$FFFF;
  end;
end;

procedure IntroduceEnemy(p1,p2: integer);
begin
RW[p1].Treaty[p2]:=trNone;
RW[p2].Treaty[p1]:=trNone;
end;

function DiscoverTile(Loc, p, pTell, Level: integer;
  EnableContact: boolean; euix: integer = -2): boolean;
// euix = -2: full discover
// euix = -1: unit and city only, append units in EnemyUn
// euix >= 0: unit and city only, replace EnemyUn[euix]

  procedure SetContact(p1,p2: integer);
  begin
  if (Mode<moPlaying) or (p1=p2) or (RW[p1].Treaty[p2]>trNoContact) then exit;
  IntServer(sIntTellAboutNation,p1,p2,nil^);
//  NewContact[p1,p2]:=true
  end;

var
i,uix,cix,TerrOwner,TerrOwnerTreaty,Strength,Bonus,Cnt,pFoundCity,
  cixFoundCity,MinLevel,Loc1,V8: integer;
Tile,AddFlags: Cardinal;
Adjacent: TVicinity8Loc;
unx: ^TUn;
mox: ^TModel;
begin
result:=false;
with RW[pTell] do
  begin
  Tile:=RealMap[Loc] and ResourceMask[pTell];
  if Mode=moLoading_Fast then AddFlags:=0 // don't discover units
  else
    begin
    AddFlags:=Map[Loc] and fInEnemyZoC // always preserve this flag!
      or fObserved;
    if Level=lObserveSuper then
      AddFlags:=AddFlags or fSpiedOut;
    if (GrWallContinent[pTell]>=0) and (Continent[Loc]=GrWallContinent[pTell]) then
      AddFlags:=AddFlags or fGrWall;
    if (Mode=moPlaying) and ((Tile and (nPl shl 27)<>nPl shl 27) and (pTell=p)) then
      begin // set fPeace flag?
      TerrOwner:=Tile shr 27;
      if TerrOwner<>pTell then
        begin
        TerrOwnerTreaty:=RW[pTell].Treaty[TerrOwner];
        if 1 shl TerrOwnerTreaty
          and (1 shl trPeace or 1 shl TrFriendlyContact)<>0 then
          AddFlags:=AddFlags or fPeace;
        end
      end;

    if Occupant[Loc]>=0 then
      if Occupant[Loc]=pTell then
        begin
        AddFlags:=AddFlags or (fOwned or fUnit);
        if ZoCMap[Loc]>0 then AddFlags:=AddFlags or fOwnZoCUnit;
//        Level:=lObserveSuper // always see own units
        end
      else if Map[Loc] and fUnit<>0 then
        AddFlags:=AddFlags or fUnit
      else
        begin
        Strongest(Loc,uix,Strength,Bonus,Cnt);
        unx:=@RW[Occupant[Loc]].Un[uix];
        mox:=@RW[Occupant[Loc]].Model[unx.mix];
        assert((ZoCMap[Loc]<>0)=(mox.Flags and mdZOC<>0));
        if (mox.Cap[mcStealth]>0) and (Tile and fCity=0)
          and (Tile and fTerImp<>tiBase) then
          MinLevel:=lObserveSuper
        else if (mox.Cap[mcSub]>0) and (Tile and fTerrain<fGrass) then
          MinLevel:=lObserveAll
        else MinLevel:=lObserveUnhidden;
        if Level>=MinLevel then
          begin
          AddFlags:=AddFlags or fUnit;
          if euix>=0 then uix:=euix
          else
            begin
            uix:=nEnemyUn;
            inc(nEnemyUn);
            assert(nEnemyUn<neumax);
            end;
          MakeUnitInfo(Occupant[Loc],unx^,EnemyUn[uix]);
          if Cnt>1 then
            EnemyUn[uix].Flags:=EnemyUn[uix].Flags or unMulti;
          if (mox.Flags and mdZOC<>0) and (pTell=p)
            and (Treaty[Occupant[Loc]]<trAlliance) then
            begin // set fInEnemyZoC flags of surrounding tiles
            V8_to_Loc(Loc,Adjacent);
            for V8:=0 to 7 do
              begin
              Loc1:=Adjacent[V8];
              if (Loc1>=0) and (Loc1<MapSize) then
                Map[Loc1]:=Map[Loc1] or fInEnemyZoC
              end
            end;
          if EnableContact and (mox.Domain=dGround) then
            SetContact(pTell,Occupant[Loc]);
          if Mode>=moMovie then
            begin
            TellAboutModel(pTell,Occupant[Loc],unx.mix);
            EnemyUn[uix].emix:=emixSafe(pTell,Occupant[Loc],unx.mix);
            end;
//          Level:=lObserveSuper; // don't discover unit twice
          if (pTell=p)
            and ((Tile and fCity=0) or (1 shl pTell and GAI<>0)) then
            result:=true;
          end
        else AddFlags:=AddFlags or Map[Loc] and (fStealthUnit or fHiddenUnit)
        end
    end; // if Mode>moLoading_Fast

  if Tile and fCity<>0 then
    if ObserveLevel[Loc] shr (2*pTell) and 3>0 then
      AddFlags:=AddFlags or Map[Loc] and fOwned
    else
      begin
      pFoundCity:=Tile shr 27;
      if pFoundCity=pTell then AddFlags:=AddFlags or fOwned
      else
        begin
        if EnableContact then SetContact(pTell,pFoundCity);
        cixFoundCity:=RW[pFoundCity].nCity-1;
        while (cixFoundCity>=0)
          and (RW[pFoundCity].City[cixFoundCity].Loc<>Loc) do
          dec(cixFoundCity);
        assert(cixFoundCity>=0);
        i:=0;
        while (i<nEnemyCity) and (EnemyCity[i].Loc<>Loc) do
          inc(i);
        if i=nEnemyCity then
          begin
          inc(nEnemyCity);
          assert(nEnemyCity<necmax);
          EnemyCity[i].Status:=0;
          EnemyCity[i].SavedStatus:=0;
          if pTell=p then result:=true;
          end;
        MakeCityInfo(pFoundCity,cixFoundCity,EnemyCity[i]);
        end;
      end
  else if Map[Loc] and fCity<>0 then // remove enemycity
    for cix:=0 to nEnemyCity-1 do
      if EnemyCity[cix].Loc=Loc then
        EnemyCity[cix].Loc:=-1;

  if Map[Loc] and fTerrain=fUNKNOWN then inc(Discovered[pTell]);
  if euix>=-1 then
    Map[Loc]:=Map[Loc] and not (fUnit or fCity or fOwned or fOwnZoCUnit)
      or (Tile and $07FFFFFF or AddFlags) and (fUnit or fCity or fOwned or fOwnZoCUnit)
  else
    begin
    Map[Loc]:=Tile and $07FFFFFF or AddFlags;
    if Tile and $78000000=$78000000 then Territory[Loc]:=-1
    else Territory[Loc]:=Tile shr 27;
    MapObservedLast[Loc]:=GTurn
    end;
  ObserveLevel[Loc]:=ObserveLevel[Loc] and not (3 shl (2*pTell))
    or Cardinal(Level) shl (2*pTell);
  end
end; // DiscoverTile

function Discover9(Loc,p,Level: integer; TellAllied, EnableContact: boolean): boolean;
var
V9,Loc1,pTell,OldLevel: integer;
Radius: TVicinity8Loc;
begin
assert((Mode>moLoading_Fast) or (RW[p].nEnemyUn=0));
result:=false;
V8_to_Loc(Loc,Radius);
for V9:=0 to 8 do
  begin
  if V9=8 then Loc1:=Loc
  else Loc1:=Radius[V9];
  if (Loc1>=0) and (Loc1<MapSize) then
    if TellAllied then
      begin
      for pTell:=0 to nPl-1 do
        if (pTell=p) or (1 shl pTell and GAlive<>0)
          and (RW[p].Treaty[pTell]=trAlliance) then
          begin
          OldLevel:=ObserveLevel[Loc1] shr (2*pTell) and 3;
          if Level>OldLevel then
            result:=DiscoverTile(Loc1,p,pTell,Level,EnableContact) or result;
          end
      end
    else
      begin
      OldLevel:=ObserveLevel[Loc1] shr (2*p) and 3;
      if Level>OldLevel then
        result:=DiscoverTile(Loc1,p,p,Level,EnableContact) or result;
      end
  end;
end;

function Discover21(Loc,p,AdjacentLevel: integer; TellAllied, EnableContact: boolean): boolean;
var
V21,Loc1,pTell,Level,OldLevel,AdjacentFlags: integer;
Radius: TVicinity21Loc;
begin
assert((Mode>moLoading_Fast) or (RW[p].nEnemyUn=0));
result:=false;
AdjacentFlags:=$00267620 shr 1;
V21_to_Loc(Loc,Radius);
for V21:=1 to 26 do
  begin
  Loc1:=Radius[V21];
  if (Loc1>=0) and (Loc1<MapSize) then
    begin
    if AdjacentFlags and 1<>0 then Level:=AdjacentLevel
    else Level:=lObserveUnhidden;
    if TellAllied then
      begin
      for pTell:=0 to nPl-1 do
        if (pTell=p) or (1 shl pTell and GAlive<>0)
          and (RW[p].Treaty[pTell]=trAlliance) then
          begin
          OldLevel:=ObserveLevel[Loc1] shr (2*pTell) and 3;
          if Level>OldLevel then
            result:=DiscoverTile(Loc1,p,pTell,Level,EnableContact) or result;
          end
      end
    else
      begin
      OldLevel:=ObserveLevel[Loc1] shr (2*p) and 3;
      if Level>OldLevel then
        result:=DiscoverTile(Loc1,p,p,Level,EnableContact) or result;
      end
    end;
  AdjacentFlags:=AdjacentFlags shr 1;
  end;
end;

procedure DiscoverAll(p, Level: integer);
{player p discovers complete playground (for supervisor)}
var
Loc, OldLevel: integer;
begin
assert((Mode>moLoading_Fast) or (RW[p].nEnemyUn=0));
for Loc:=0 to MapSize-1 do
  begin
  OldLevel:=ObserveLevel[Loc] shr (2*p) and 3;
  if Level>OldLevel then
    DiscoverTile(Loc,p,p,Level,false);
  end;
end;

procedure DiscoverViewAreas(p: integer);
var
pTell, uix, cix, ecix, Loc, RealOwner: integer;
PModel: ^TModel;
begin // discover unit and city view areas
for pTell:=0 to nPl-1 do
  if (pTell=p) or (RW[p].Treaty[pTell]=trAlliance) then
    begin
    for uix:=0 to RW[pTell].nUn-1 do with RW[pTell].Un[uix] do
      if (Loc>=0) and (master<0) and (RealMap[Loc] and fCity=0) then
        begin
        PModel:=@RW[pTell].Model[mix];
        if (PModel.Kind=mkDiplomat) or (PModel.Cap[mcSpy]>0) then
          Discover21(Loc,p,lObserveSuper,false,true)
        else if (PModel.Cap[mcRadar]+PModel.Cap[mcCarrier]>0)
          or (PModel.Domain=dAir) then
          Discover21(Loc,p,lObserveAll,false,false)
        else if (RealMap[Loc] and fTerrain=fMountains)
          or (RealMap[Loc] and fTerImp=tiFort)
          or (RealMap[Loc] and fTerImp=tiBase)
          or (PModel.Cap[mcAcademy]>0) then
          Discover21(Loc,p,lObserveUnhidden,false,PModel.Domain=dGround)
        else Discover9(Loc,p,lObserveUnhidden,false,PModel.Domain=dGround);
        end;
    for cix:=0 to RW[pTell].nCity-1 do if RW[pTell].City[cix].Loc>=0 then
      Discover21(RW[pTell].City[cix].Loc,p,lObserveUnhidden,false,true);
    for ecix:=0 to RW[pTell].nEnemyCity-1 do
      begin // players know territory, so no use in hiding city owner
      Loc:=RW[pTell].EnemyCity[ecix].Loc;
      if Loc>=0 then
        begin
        RealOwner:=(RealMap[Loc] shr 27) and $F;
        if RealOwner<nPl then
          RW[pTell].EnemyCity[ecix].owner:=RealOwner
        else
          begin
          RW[pTell].EnemyCity[ecix].Loc:=-1;
          RW[pTell].Map[Loc]:=RW[pTell].Map[Loc] and not fCity
          end
        end
      end
    end;
end;

function GetUnitStack(p,Loc: integer): integer;
var
uix: integer;
unx: ^TUn;
begin
result:=0;
if Occupant[Loc]<0 then exit;
for uix:=0 to RW[Occupant[Loc]].nUn-1 do
  begin
  unx:=@RW[Occupant[Loc]].Un[uix];
  if unx.Loc=Loc then
    begin
    MakeUnitInfo(Occupant[Loc],unx^,RW[p].EnemyUn[RW[p].nEnemyUn+result]);
    TellAboutModel(p,Occupant[Loc],unx.mix);
    RW[p].EnemyUn[RW[p].nEnemyUn+result].emix:=RWemix[p,Occupant[Loc],unx.mix];
    inc(result);
    end
  end
end;

procedure UpdateUnitMap(Loc: integer; CityChange: boolean = false);
// update maps and enemy units of all players after unit change
var
p, euix, OldLevel: integer;
AddFlags, ClearFlags: Cardinal;
begin
if (Mode=moLoading_Fast) and not CityChange then exit;
for p:=0 to nPl-1 do if 1 shl p and (GAlive or GWatching)<>0 then
  begin
  OldLevel:=ObserveLevel[Loc] shr (2*p) and 3;
  if OldLevel>lNoObserve then
    begin
    if RW[p].Map[Loc] and (fUnit or fOwned)=fUnit then
      begin
      // replace unit located here in EnemyUn
      // do not just set loc:=-1 because total number would be unlimited
      euix:=RW[p].nEnemyUn-1;
      while euix>=0 do
        begin
        if RW[p].EnemyUn[euix].Loc=Loc then
          begin RW[p].EnemyUn[euix].Loc:=-1; Break; end;
        dec(euix);
        end;
      RW[p].Map[Loc]:=RW[p].Map[Loc] and not fUnit
      end
    else
      begin // look for empty slot in EnemyUn
      euix:=RW[p].nEnemyUn-1;
      while (euix>=0) and (RW[p].EnemyUn[euix].Loc>=0) do dec(euix);
      end;
    if (Occupant[Loc]<0) and not CityChange then
      begin // calling DiscoverTile not necessary, only clear map flags
      ClearFlags:=fUnit or fHiddenUnit or fStealthUnit or fOwnZoCUnit;
      if RealMap[Loc] and fCity=0 then
        ClearFlags:=ClearFlags or fOwned;
      RW[p].Map[Loc]:=RW[p].Map[Loc] and not ClearFlags;
      end
    else if (Occupant[Loc]<>p) or CityChange then
      begin // city or enemy unit update necessary, call DiscoverTile
      ObserveLevel[Loc]:=ObserveLevel[Loc] and not (3 shl (2*p));
      DiscoverTile(Loc, p, p, OldLevel, false, euix);
      end
    else {if (Occupant[Loc]=p) and not CityChange then}
      begin // calling DiscoverTile not necessary, only set map flags
      ClearFlags:=0;
      AddFlags:=fUnit or fOwned;
      if ZoCMap[Loc]>0 then AddFlags:=AddFlags or fOwnZoCUnit
      else ClearFlags:=ClearFlags or fOwnZoCUnit;
      RW[p].Map[Loc]:=RW[p].Map[Loc] and not ClearFlags or AddFlags;
      end
    end
  end
end;

procedure RecalcV8ZoC(p,Loc: integer);
// recalculate fInEnemyZoC flags around single tile
var
v8,V8V8,Loc1,Loc2,p1,ObserveMask: integer;
Tile1: ^Cardinal;
Adjacent,AdjacentAdjacent: TVicinity8Loc;
begin
if Mode=moLoading_Fast then exit;
ObserveMask:=3 shl (2*p);
V8_to_Loc(Loc,Adjacent);
for V8:=0 to 7 do
  begin
  Loc1:=Adjacent[V8];
  if (Loc1>=0) and (Loc1<MapSize) then
    begin
    Tile1:=@RW[p].Map[Loc1];
    Tile1^:=Tile1^ and not fInEnemyZoC;
    V8_to_Loc(Loc1,AdjacentAdjacent);
    for V8V8:=0 to 7 do
      begin
      Loc2:=AdjacentAdjacent[V8V8];
      if (Loc2>=0) and (Loc2<MapSize) and (ZoCMap[Loc2]>0)
        and (ObserveLevel[Loc2] and ObserveMask<>0) then
        begin
        p1:=Occupant[Loc2];
        assert(p1<>nPl);
        if (p1<>p) and (RW[p].Treaty[p1]<trAlliance) then
          begin Tile1^:=Tile1^ or fInEnemyZoC; break end
        end
      end;
    end
  end
end;

procedure RecalcMapZoC(p: integer);
// recalculate fInEnemyZoC flags for the whole map
var
Loc,Loc1,V8,p1,ObserveMask: integer;
Adjacent: TVicinity8Loc;
begin
if Mode=moLoading_Fast then exit;
MaskD(RW[p].Map^,MapSize,not Cardinal(fInEnemyZoC));
ObserveMask:=3 shl (2*p);
for Loc:=0 to MapSize-1 do
  if (ZoCMap[Loc]>0) and (ObserveLevel[Loc] and ObserveMask<>0) then
    begin
    p1:=Occupant[Loc];
    assert(p1<>nPl);
    if (p1<>p) and (RW[p].Treaty[p1]<trAlliance) then
      begin // this non-allied enemy ZoC unit is known to this player -- set flags!
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        if (Loc1>=0) and (Loc1<MapSize) then
          RW[p].Map[Loc1]:=RW[p].Map[Loc1] or fInEnemyZoC
        end
      end
    end
end;

procedure RecalcPeaceMap(p: integer);
// recalculate fPeace flags for the whole map
var
Loc,p1: integer;
PeacePlayer: array[-1..nPl-1] of boolean;
begin
if Mode<>moPlaying then exit;
MaskD(RW[p].Map^,MapSize,not Cardinal(fPeace));
for p1:=-1 to nPl-1 do
  PeacePlayer[p1]:= (p1>=0) and (p1<>p) and (1 shl p1 and GAlive<>0)
    and (RW[p].Treaty[p1] in [trPeace,trFriendlyContact]);
for Loc:=0 to MapSize-1 do
  if PeacePlayer[RW[p].Territory[Loc]] then
    RW[p].Map[Loc]:=RW[p].Map[Loc] or fPeace
end;


{
                         Territory Calculation
 ____________________________________________________________________
}
var
BorderChanges: array[0..sIntExpandTerritory and $F-1] of Cardinal;

procedure ChangeTerritory(Loc, p: integer);
var
p1: integer;
begin
assert(p>=0); // no player's territory indicated by p=nPl
dec(TerritoryCount[RealMap[Loc] shr 27]);
inc(TerritoryCount[p]);
RealMap[Loc]:=RealMap[Loc] and not ($F shl 27) or Cardinal(p) shl 27;
if p=$F then p:=-1;
for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
  if RW[p1].Map[Loc] and fTerrain<>fUNKNOWN then
    begin
    RW[p1].Territory[Loc]:=p;
    if (p<nPl) and (p<>p1) and (1 shl p and GAlive<>0)
      and (RW[p1].Treaty[p] in [trPeace,trFriendlyContact]) then
      RW[p1].Map[Loc]:=RW[p1].Map[Loc] or fPeace
    else RW[p1].Map[Loc]:=RW[p1].Map[Loc] and not fPeace;
    end
end;

procedure ExpandTerritory(OriginLoc: integer);
var
i,dx,dy,dxMax,dyMax,Loc,NewOwner: integer;
begin
i:=0;
dyMax:=0;
while (dyMax+1)+(dyMax+1) shr 1<=CountryRadius do
  inc(dyMax);
for dy:=-dyMax to dyMax do
  begin
  dxMax:=dy and 1;
  while abs(dy)+(dxMax+2)+abs(abs(dy)-(dxMax+2)) shr 1<=CountryRadius do
    inc(dxMax,2);
  for dx:=-dxMax to dxMax do if (dy+dx) and 1=0 then
    begin
    NewOwner:=BorderChanges[i div 8] shr (i mod 8 *4) and $F;
    Loc:=dLoc(OriginLoc,dx,dy);
    if (Loc>=0) and (Cardinal(NewOwner)<>RealMap[Loc] shr 27) then
      ChangeTerritory(Loc,NewOwner);
    inc(i);
    end
  end
end;

procedure CheckBorders(OriginLoc, PlayerLosingCity: integer);
// OriginLoc: only changes in CountryRadius around this location possible,
//   -1 for complete map, -2 for double-check (no more changes allowed)
// PlayerLosingCity: do nothing but remove tiles no longer in reach from this
//   player's territory, -1 for full border recalculation
var
i,r,Loc,Loc1,dx,dy,p1,p2,cix,NewDist,dxMax,dyMax,OldOwner,V8,
  NewOwner: integer;
Adjacent: TVicinity8Loc;
AtPeace: array[0..nPl,0..nPl] of boolean;
Country, FormerCountry, {to who's country a tile belongs}
Dist, FormerDist, StolenDist: array[0..lxmax*lymax-1] of ShortInt;
begin
if PlayerLosingCity>=0 then
  begin
  for Loc:=0 to MapSize-1 do StolenDist[Loc]:=CountryRadius+1;
  for cix:=0 to RW[PlayerLosingCity].nCity-1 do
    if RW[PlayerLosingCity].City[cix].Loc>=0 then
      StolenDist[RW[PlayerLosingCity].City[cix].Loc]:=0;

  for r:=1 to CountryRadius shr 1 do
    begin
    move(StolenDist,FormerDist,MapSize);
    for Loc:=0 to MapSize-1 do
      if (FormerDist[Loc]<=CountryRadius-2) // use same conditions as below!
        and ((1 shl (RealMap[Loc] and fTerrain))
        and (1 shl fShore+1 shl fMountains+1 shl fArctic)=0) then
        begin
        V8_to_Loc(Loc,Adjacent);
        for V8:=0 to 7 do
          begin
          Loc1:=Adjacent[V8];
          NewDist:=FormerDist[Loc]+2+V8 and 1;
          if (Loc1>=0) and (Loc1<MapSize) and (NewDist<StolenDist[Loc1]) then
            StolenDist[Loc1]:=NewDist;
          end
        end
    end;
  end;

FillChar(Country,MapSize,-1);
for Loc:=0 to MapSize-1 do Dist[Loc]:=CountryRadius+1;
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
  for cix:=0 to RW[p1].nCity-1 do if RW[p1].City[cix].Loc>=0 then
    begin
    Country[RW[p1].City[cix].Loc]:=p1;
    Dist[RW[p1].City[cix].Loc]:=0;
    end;

for r:=1 to CountryRadius shr 1 do
  begin
  move(Country,FormerCountry,MapSize);
  move(Dist,FormerDist,MapSize);
  for Loc:=0 to MapSize-1 do
    if (FormerDist[Loc]<=CountryRadius-2) // use same conditions as above!
      and ((1 shl (RealMap[Loc] and fTerrain))
      and (1 shl fShore+1 shl fMountains+1 shl fArctic)=0) then
      begin
      assert(FormerCountry[Loc]>=0);
      V8_to_Loc(Loc,Adjacent);
      for V8:=0 to 7 do
        begin
        Loc1:=Adjacent[V8];
        NewDist:=FormerDist[Loc]+2+V8 and 1;
        if (Loc1>=0) and (Loc1<MapSize) and (NewDist<Dist[Loc1]) then
          begin
          Country[Loc1]:=FormerCountry[Loc];
          Dist[Loc1]:=NewDist;
          end
        end
      end
  end;

FillChar(AtPeace, sizeof(AtPeace), false);
for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
  for p2:=0 to nPl-1 do
    if (p2<>p1) and (1 shl p2 and GAlive<>0) and (RW[p1].Treaty[p2]>=trPeace) then
    AtPeace[p1,p2]:=true;

if OriginLoc>=0 then
  begin // update area only
  i:=0; 
  fillchar(BorderChanges, sizeof(BorderChanges), 0);
  dyMax:=0;
  while (dyMax+1)+(dyMax+1) shr 1<=CountryRadius do
    inc(dyMax);
  for dy:=-dyMax to dyMax do
    begin
    dxMax:=dy and 1;
    while abs(dy)+(dxMax+2)+abs(abs(dy)-(dxMax+2)) shr 1<=CountryRadius do
      inc(dxMax,2);
    for dx:=-dxMax to dxMax do if (dy+dx) and 1=0 then
      begin
      Loc:=dLoc(OriginLoc,dx,dy);
      if Loc>=0 then
        begin
        OldOwner:=RealMap[Loc] shr 27;
        NewOwner:=Country[Loc] and $f;
        if NewOwner<>OldOwner then
          if AtPeace[NewOwner,OldOwner]
            and not ((OldOwner=PlayerLosingCity) and (StolenDist[Loc]>CountryRadius)) then
            NewOwner:=OldOwner // peace fixes borders
          else ChangeTerritory(Loc,NewOwner);
        inc(BorderChanges[i div 8],NewOwner shl (i mod 8 *4));
        end;
      inc(i);
      end
    end
  end
else for Loc:=0 to MapSize-1 do // update complete map
  begin
  OldOwner:=RealMap[Loc] shr 27;
  NewOwner:=Country[Loc] and $f;
  if (NewOwner<>OldOwner)
    and (not AtPeace[NewOwner,OldOwner]
      or ((OldOwner=PlayerLosingCity) and (StolenDist[Loc]>CountryRadius))) then
    begin
    assert(OriginLoc<>-2); // test if border saving works
    ChangeTerritory(Loc,NewOwner);
    end;
  end;

{$IFOPT O-}if OriginLoc<>-2 then CheckBorders(-2);{$ENDIF} //check: single pass should do!
end; //CheckBorders

procedure LogCheckBorders(p,cix,PlayerLosingCity: integer);
begin
CheckBorders(RW[p].City[cix].Loc,PlayerLosingCity);
IntServer(sIntExpandTerritory,p,cix,BorderChanges);
end;

{
                             Map Processing
 ____________________________________________________________________
}

procedure CreateUnit(p,mix: integer);
begin
with RW[p] do
  begin
  Un[nUn].mix:=mix;
  with Un[nUn] do
    begin
    ID:=UnBuilt[p];
    inc(UnBuilt[p]);
    Status:=0;
    SavedStatus:=0;
    inc(Model[mix].Built);
    Home:=-1;
    Health:=100;
    Flags:=0;
    Movement:=0;
    if Model[mix].Domain=dAir then
      begin
      Fuel:=Model[mix].Cap[mcFuel];
      Flags:=Flags or unBombsLoaded
      end;
    Job:=jNone;
    Exp:=ExpCost shr 1;
    TroopLoad:=0; AirLoad:=0; Master:=-1;
    end;
  inc(nUn);
  end
end;

procedure FreeUnit(p,uix: integer);
// loc or master should be set after call
// implementation is critical for loading performance, change carefully
var
Loc0, uix1: integer;
Occ, ZoC: boolean;
begin
with RW[p].Un[uix] do
  begin
  Job:=jNone;
  Flags:=Flags and not (unFortified or unMountainDelay);
  Loc0:=Loc
  end;
if Occupant[Loc0]>=0 then
  begin
  assert(Occupant[Loc0]=p);
  Occ:=false;
  ZoC:=false;
  for uix1:=0 to RW[p].nUn-1 do with RW[p].Un[uix1] do
    if (Loc=Loc0) and (Master<0) and (uix1<>uix) then
      begin
      Occ:=true;
      if RW[p].Model[mix].Flags and mdZOC<>0 then
        begin ZoC:=true; Break end
      end;
  if not Occ then Occupant[Loc0]:=-1;
  if not ZoC then ZoCMap[Loc0]:=0;
  end;
end;

procedure PlaceUnit(p,uix: integer);
begin
with RW[p].Un[uix] do
  begin
  Occupant[Loc]:=p;
  if RW[p].Model[mix].Flags and mdZOC<>0 then ZoCMap[Loc]:=1;
  end
end;

procedure CountLost(p, mix, Enemy: integer);
begin
inc(RW[p].Model[mix].Lost);
TellAboutModel(Enemy,p,mix);
inc(Destroyed[Enemy,p,mix]);
end;

procedure RemoveUnit(p,uix: integer; Enemy: integer = -1);
// use enemy only from inside sMoveUnit if attack
var
uix1: integer;
begin
with RW[p].Un[uix] do
  begin
  assert((Loc>=0) or (RW[p].Model[mix].Kind=mkDiplomat)); // already freed when spy mission
  if Loc>=0 then
    FreeUnit(p,uix);
  if Master>=0 then
    if RW[p].Model[mix].Domain=dAir then dec(RW[p].Un[Master].AirLoad)
    else dec(RW[p].Un[Master].TroopLoad);
  if (TroopLoad>0) or (AirLoad>0) then
    for uix1:=0 to RW[p].nUn-1 do
      if (RW[p].Un[uix1].Loc>=0) and (RW[p].Un[uix1].Master=uix) then
        {unit mastered by removed unit -- remove too}
        begin
        RW[p].Un[uix1].Loc:=-1;
        if Enemy>=0 then CountLost(p,RW[p].Un[uix1].mix,Enemy);
        end;
  Loc:=-1;
  if Enemy>=0 then CountLost(p,mix,Enemy);
  end
end;{RemoveUnit}

procedure RemoveUnit_UpdateMap(p,uix: integer);
var
Loc0: integer;
begin
Loc0:=RW[p].Un[uix].Loc;
RemoveUnit(p,uix);
if Mode>moLoading_Fast then UpdateUnitMap(Loc0);
end;

procedure RemoveAllUnits(p,Loc: integer; Enemy: integer = -1);
var
uix: integer;
begin
for uix:=0 to RW[p].nUn-1 do
  if RW[p].Un[uix].Loc=Loc then
    begin
    if Enemy>=0 then CountLost(p,RW[p].Un[uix].mix,Enemy);
    RW[p].Un[uix].Loc:=-1
    end;
Occupant[Loc]:=-1;
ZoCMap[Loc]:=0;
end;

procedure RemoveDomainUnits(d,p,Loc: integer);
var
uix: integer;
begin
for uix:=0 to RW[p].nUn-1 do
  if (RW[p].Model[RW[p].Un[uix].mix].Domain=d) and (RW[p].Un[uix].Loc=Loc) then
    RemoveUnit(p,uix);
end;

procedure FoundCity(p,FoundLoc: integer);
var
p1,cix1,V21,dx,dy: integer;
begin
if RW[p].nCity=ncmax then exit;
inc(RW[p].nCity);
with RW[p].City[RW[p].nCity-1] do
  begin
  Size:=2;
  Status:=0;
  SavedStatus:=0;
  FillChar(Built,SizeOf(Built),0);
  Food:=0;
  Project:=cpImp+imTrGoods;
  Prod:=0;
  Project0:=Project;
  Prod0:=0;
  Pollution:=0;
  N1:=0;
  Loc:=FoundLoc;
  if UsedByCity[FoundLoc]>=0 then
    begin {central tile is exploited - toggle in exploiting city}
    p1:=p;
    SearchCity(UsedByCity[FoundLoc],p1,cix1);
    dxdy(UsedByCity[FoundLoc],FoundLoc,dx,dy);
    V21:=(dy+3) shl 2+(dx+3) shr 1;
    RW[p1].City[cix1].Tiles:=RW[p1].City[cix1].Tiles and not (1 shl V21);
    end;
  Tiles:=1 shl 13; {exploit central tile}
  UsedByCity[FoundLoc]:=FoundLoc;
  RealMap[FoundLoc]:=RealMap[FoundLoc]
    and (fTerrain or fSpecial or fRiver or nPl shl 27) or fCity;
    
  ChangeTerritory(Loc,p)
  end;
end; {FoundCity}

procedure StealCity(p,cix: integer; SaveUnits: boolean);
var
i,j,uix1,cix1,nearest: integer;
begin
for i:=0 to 27 do
  if RW[p].City[cix].Built[i]=1 then
    begin
    GWonder[i].EffectiveOwner:=-1;
    if i=woPyramids then FreeSlaves;
    if i=woEiffel then // deactivate expired wonders
      for j:=0 to 27 do if GWonder[j].EffectiveOwner=p then
        CheckExpiration(j);
    end;
for i:=28 to nImp-1 do
  if (Imp[i].Kind<>ikCommon) and (RW[p].City[cix].Built[i]>0) then
    begin {destroy national projects}
    RW[p].NatBuilt[i]:=0;
    if i=imGrWall then GrWallContinent[p]:=-1;
    end;

for uix1:=0 to RW[p].nUn-1 do with RW[p].Un[uix1] do
  if (Loc>=0) and (Home=cix) then
    if SaveUnits then
      begin // support units by nearest other city
      nearest:=-1;
      for cix1:=0 to RW[p].nCity-1 do
        if (cix1<>cix) and (RW[p].City[cix1].Loc>=0)
          and ((nearest<0) or (Distance(RW[p].City[cix1].Loc,Loc)
          <Distance(RW[p].City[nearest].Loc,Loc))) then
          nearest:=cix1;
      Home:=nearest
      end
    else RemoveUnit(p,uix1); // destroy supported units
end; //StealCity

procedure DestroyCity(p,cix: integer; SaveUnits: boolean);
var
i,V21: integer;
Radius: TVicinity21Loc;
begin
StealCity(p,cix,SaveUnits);
with RW[p].City[cix] do
  begin
  for i:=0 to 27 do
    if Built[i]>0 then GWonder[i].CityID:=-2; // wonder destroyed
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do if 1 shl V21 and Tiles<>0 then
    UsedByCity[Radius[V21]]:=-1;
  RealMap[Loc]:=RealMap[Loc] and not fCity;
  Loc:=-1
  end
end; //DestroyCity

procedure ChangeCityOwner(pOld,cixOld,pNew: integer);
var
i,j,cix1,Loc1,V21: integer;
Radius: TVicinity21Loc;
begin
inc(RW[pNew].nCity);
RW[pNew].City[RW[pNew].nCity-1]:=RW[pOld].City[cixOld];
StealCity(pOld,cixOld,false);
RW[pOld].City[cixOld].Loc:=-1;
with RW[pNew].City[(RW[pNew].nCity-1)] do
  begin
  Food:=0;
  Project:=cpImp+imTrGoods;
  Prod:=0;
  Project0:=Project;
  Prod0:=0;
  Status:=0;
  SavedStatus:=0;
  N1:=0;

  // check for siege
  V21_to_Loc(Loc,Radius);
  for V21:=1 to 26 do if Tiles and (1 shl V21) and not (1 shl CityOwnTile)<>0 then
    begin
    Loc1:=Radius[V21];
    assert((Loc1>=0) and (Loc1<MapSize) and (UsedByCity[Loc1]=Loc));
    if (ZoCMap[Loc1]>0) and (Occupant[Loc1]<>pNew)
      and (RW[pNew].Treaty[Occupant[Loc1]]<trAlliance) then
      begin // tile can't remain exploited
      Tiles:=Tiles and not (1 shl V21);
      UsedByCity[Loc1]:=-1;
      end;
    // don't check for siege by peace territory here, because territory
    // might not be up to date -- done in turn beginning anyway
    end;
  Built[imTownHall]:=0;
  Built[imCourt]:=0;
  for i:=28 to nImp-1 do if Imp[i].Kind<>ikCommon then
    Built[i]:=0; {destroy national projects}
  for i:=0 to 27 do
    if Built[i]=1 then
      begin // new wonder owner!
      GWonder[i].EffectiveOwner:=pNew;
      if i=woEiffel then // reactivate expired wonders
        begin
        for j:=0 to 27 do if Imp[j].Expiration>=0 then
          for cix1:=0 to (RW[pNew].nCity-1) do
            if RW[pNew].City[cix1].Built[j]=1 then
              GWonder[j].EffectiveOwner:=pNew
        end
      else CheckExpiration(i);
      case i of
        woLighthouse: CheckSpecialModels(pNew,preLighthouse);
        woLeo: CheckSpecialModels(pNew,preLeo);
        woPyramids: CheckSpecialModels(pNew,preBuilder);
        end;
      end;

  // remove city from enemy cities
  // not done by Discover, because fCity still set!
  cix1:=RW[pNew].nEnemyCity-1;
  while (cix1>=0) and (RW[pNew].EnemyCity[cix1].Loc<>Loc) do dec(cix1);
  assert(cix1>=0);
  RW[pNew].EnemyCity[cix1].Loc:=-1;

  ChangeTerritory(Loc,pNew);
  end;
end; //ChangeCityOwner

procedure CompleteJob(p,Loc,Job: integer);
var
ChangedTerrain,p1: integer;
begin
assert(Job<>jCity);
ChangedTerrain:=-1;
case Job of
  jRoad:
    RealMap[Loc]:=RealMap[Loc] or fRoad;
  jRR:
    RealMap[Loc]:=RealMap[Loc] and not fRoad or fRR;
  jClear:
    begin
    ChangedTerrain:=Terrain[RealMap[Loc] and fTerrain].ClearTerrain;
    RealMap[Loc]:=RealMap[Loc] and not fTerrain or Cardinal(ChangedTerrain);
    RealMap[Loc]:=RealMap[Loc] and not (3 shl 5) or ActualSpecialTile(Loc) shl 5;
    end;
  jIrr:
    RealMap[Loc]:=RealMap[Loc] and not fTerImp or tiIrrigation;
  jFarm:
    RealMap[Loc]:=RealMap[Loc] and not fTerImp or tiFarm;
  jAfforest:
    begin
    ChangedTerrain:=Terrain[RealMap[Loc] and fTerrain].AfforestTerrain;
    RealMap[Loc]:=RealMap[Loc] and not fTerrain or Cardinal(ChangedTerrain);
    RealMap[Loc]:=RealMap[Loc] and not (3 shl 5) or ActualSpecialTile(Loc) shl 5;
    end;
  jMine:
    RealMap[Loc]:=RealMap[Loc] and not fTerImp or tiMine;
  jFort:
    RealMap[Loc]:=RealMap[Loc] and not fTerImp or tiFort;
  jCanal:
    RealMap[Loc]:=RealMap[Loc] or fCanal;
  jTrans:
    begin
    ChangedTerrain:=Terrain[RealMap[Loc] and fTerrain].TransTerrain;
    RealMap[Loc]:=RealMap[Loc] and not fTerrain or Cardinal(ChangedTerrain);
    RealMap[Loc]:=RealMap[Loc] and not (3 shl 5) or ActualSpecialTile(Loc) shl 5;
    if not (RealMap[Loc] and fTerrain in TerrType_Canalable) then
      begin
      RemoveDomainUnits(dSea,p,Loc);
      RealMap[Loc]:=RealMap[Loc] and not fCanal;
      end;
    end;
  jPoll:
    RealMap[Loc]:=RealMap[Loc] and not fPoll;
  jBase:
    RealMap[Loc]:=RealMap[Loc] and not fTerImp or tiBase;
  jPillage:
    if RealMap[Loc] and fTerImp<>0 then
      begin
      if RealMap[Loc] and fTerImp=tiBase then
        RemoveDomainUnits(dAir,p,Loc);
      RealMap[Loc]:=RealMap[Loc] and not fTerImp
      end
    else if RealMap[Loc] and fCanal<>0 then
      begin
      RemoveDomainUnits(dSea,p,Loc);
      RealMap[Loc]:=RealMap[Loc] and not fCanal
      end
    else if RealMap[Loc] and fRR<>0 then
      RealMap[Loc]:=RealMap[Loc] and not fRR or fRoad
    else if RealMap[Loc] and fRoad<>0 then
      RealMap[Loc]:=RealMap[Loc] and not fRoad;
  end;
if ChangedTerrain>=0 then
  begin // remove terrain improvements if not possible on new terrain
  if ((RealMap[Loc] and fTerImp=tiIrrigation)
      or (RealMap[Loc] and fTerImp=tiFarm))
    and ((Terrain[ChangedTerrain].IrrClearWork=0)
      or (Terrain[ChangedTerrain].ClearTerrain>=0)) then
    RealMap[Loc]:=RealMap[Loc] and not fTerImp;
  if (RealMap[Loc] and fTerImp=tiMine)
    and ((Terrain[ChangedTerrain].MineAfforestWork=0)
      or (Terrain[ChangedTerrain].AfforestTerrain>=0)) then
    RealMap[Loc]:=RealMap[Loc] and not fTerImp;
  end;

// update map of all observing players
if Mode>moLoading_Fast then
  for p1:=0 to nPl-1 do
    if (1 shl p1 and (GAlive or GWatching)<>0)
      and (ObserveLevel[Loc] shr (2*p1) and 3>lNoObserve) then
      RW[p1].Map[Loc]:=RW[p1].Map[Loc]
        and not (fTerrain or fSpecial or fTerImp or fRoad or fRR or fCanal or fPoll)
        or RealMap[Loc] and (fTerrain or fSpecial or fTerImp or fRoad or fRR or fCanal or fPoll);
end; //CompleteJob

{
                              Diplomacy
 ____________________________________________________________________
}
procedure GiveCivilReport(p, pAbout: integer);
begin
with RW[p].EnemyReport[pAbout]^ do
  begin
  // general info
  TurnOfCivilReport:=LastValidStat[pAbout];
  move(RW[pAbout].Treaty, Treaty, SizeOf(Treaty));
  Government:=RW[pAbout].Government;
  Money:=RW[pAbout].Money;

  // tech info
  ResearchTech:=RW[pAbout].ResearchTech;
  ResearchDone:=RW[pAbout].Research*100 div TechCost(pAbout);
  if ResearchDone>100 then
    ResearchDone:=100;
  move(RW[pAbout].Tech, Tech, nAdv);
  end;
end;

procedure GiveMilReport(p, pAbout: integer);
var
uix,mix: integer;
begin
with RW[p].EnemyReport[pAbout]^ do
  begin
  TurnOfMilReport:=LastValidStat[pAbout];
  nModelCounted:=RW[pAbout].nModel;
  for mix:=0 to RW[pAbout].nModel-1 do
    begin TellAboutModel(p,pAbout,mix); UnCount[mix]:=0 end;
  for uix:=0 to RW[pAbout].nUn-1 do
    if RW[pAbout].Un[uix].Loc>=0 then inc(UnCount[RW[pAbout].Un[uix].mix]);
  end
end;

procedure ShowPrice(pSender, pTarget, Price: integer);
begin
case Price and opMask of
  opTech: // + advance
    with RW[pTarget].EnemyReport[pSender]^ do
      if Tech[Price-opTech]<tsApplicable then
        Tech[Price-opTech]:=tsApplicable;
  opModel: // + model index
    TellAboutModel(pTarget,pSender,Price-opModel);
{  opCity: // + city ID
    begin
    end;}
  end
end;

function CopyCivilReport(pSender, pTarget, pAbout: integer): boolean;
var
i: integer;
rSender, rTarget: ^TEnemyReport;
begin // copy third nation civil report
result:=false;
if RW[pTarget].Treaty[pAbout]=trNoContact then
  IntroduceEnemy(pTarget, pAbout);
rSender:=pointer(RW[pSender].EnemyReport[pAbout]);
rTarget:=pointer(RW[pTarget].EnemyReport[pAbout]);
if rSender.TurnOfCivilReport>rTarget.TurnOfCivilReport then
  begin // only if newer than current information
  rTarget.TurnOfCivilReport:=rSender.TurnOfCivilReport;
  rTarget.Treaty:=rSender.Treaty;
  rTarget.Government:=rSender.Government;
  rTarget.Money:=rSender.Money;
  rTarget.ResearchTech:=rSender.ResearchTech;
  rTarget.ResearchDone:=rSender.ResearchDone;
  result:=true
  end;
for i:=0 to nAdv-1 do
  if rTarget.Tech[i]<rSender.Tech[i] then
    begin
    rTarget.Tech[i]:=rSender.Tech[i];
    result:=true
    end
end;

function CopyMilReport(pSender, pTarget, pAbout: integer): boolean;
var
mix: integer;
rSender, rTarget: ^TEnemyReport;
begin // copy third nation military report
result:=false;
if RW[pTarget].Treaty[pAbout]=trNoContact then
  IntroduceEnemy(pTarget, pAbout);
rSender:=pointer(RW[pSender].EnemyReport[pAbout]);
rTarget:=pointer(RW[pTarget].EnemyReport[pAbout]);
if rSender.TurnOfMilReport>rTarget.TurnOfMilReport then
  begin // only if newer than current information
  rTarget.TurnOfMilReport:=rSender.TurnOfMilReport;
  rTarget.nModelCounted:=rSender.nModelCounted;
  move(rSender.UnCount, rTarget.UnCount, 2*rSender.nModelCounted);
  for mix:=0 to rTarget.nModelCounted-1 do
    TellAboutModel(pTarget,pAbout,mix);
  result:=true
  end
end;

procedure CopyModel(pSender,pTarget,mix: integer);
var
i: integer;
miSender, miTarget: TModelInfo;
ok: boolean;
begin
// only if target doesn't already have a model like this
ok:= RW[pTarget].nModel<nmmax;
MakeModelInfo(pSender,mix,RW[pSender].Model[mix],miSender);
for i:=0 to RW[pTarget].nModel-1 do
  begin
  MakeModelInfo(pTarget,i,RW[pTarget].Model[i],miTarget);
  if IsSameModel(miSender,miTarget) then ok:=false
  end;
if ok then
  begin
  RW[pTarget].Model[RW[pTarget].nModel]:=RW[pSender].Model[mix];
  with RW[pTarget].Model[RW[pTarget].nModel] do
    begin
    IntroTurn:=GTurn;
    if Kind=mkSelfDeveloped then Kind:=mkEnemyDeveloped;
    Status:=0;
    SavedStatus:=0;
    Built:=0;
    Lost:=0;
    end;
  inc(RW[pTarget].nModel);
  inc(Researched[pTarget]);
  TellAboutModel(pSender,pTarget,RW[pTarget].nModel-1);
  end
end;

procedure CopyMap(pSender, pTarget: integer);
var
Loc,i,cix:integer;
Tile: Cardinal;
begin
for Loc:=0 to MapSize-1 do
  if (RW[pSender].MapObservedLast[Loc]>RW[pTarget].MapObservedLast[Loc]) then
    begin
    Tile:=RW[pSender].Map[Loc];
    if Tile and fCity<>0 then
      begin
      i:=0;
      while (i<RW[pTarget].nEnemyCity) and (RW[pTarget].EnemyCity[i].Loc<>Loc) do
        inc(i);
      if i=RW[pTarget].nEnemyCity then
        begin
        inc(RW[pTarget].nEnemyCity);
        assert(RW[pTarget].nEnemyCity<necmax);
        RW[pTarget].EnemyCity[i].Status:=0;
        RW[pTarget].EnemyCity[i].SavedStatus:=0;
        end;
      if Tile and fOwned<>0 then
        begin // city owned by sender -- create new info
        cix:=RW[pSender].nCity-1;
        while (cix>=0) and (RW[pSender].City[cix].Loc<>Loc) do dec(cix);
        MakeCityInfo(pSender, cix, RW[pTarget].EnemyCity[i]);
        end
      else // city not owned by sender -- copy old info
        begin
        cix:=RW[pSender].nEnemyCity-1;
        while (cix>=0) and (RW[pSender].EnemyCity[cix].Loc<>Loc) do dec(cix);
        RW[pTarget].EnemyCity[i]:=RW[pSender].EnemyCity[cix];
        end;
      end
    else if RW[pTarget].Map[Loc] and fCity<>0 then // remove enemycity
      for cix:=0 to RW[pTarget].nEnemyCity-1 do
        if RW[pTarget].EnemyCity[cix].Loc=Loc then
          RW[pTarget].EnemyCity[cix].Loc:=-1;

    Tile:=Tile and (not (fSpecial or fModern) or ResourceMask[pTarget]);
    Tile:=Tile or (RW[pTarget].Map[Loc] and fModern);
    if (Tile and fTerrain=RW[pTarget].Map[Loc] and fTerrain) then
      Tile:=Tile or (RW[pTarget].Map[Loc] and fSpecial);

    if RW[pTarget].Map[Loc] and fTerrain=fUNKNOWN then inc(Discovered[pTarget]);
    RW[pTarget].Map[Loc]:=RW[pTarget].Map[Loc] and fInEnemyZoC // always preserve this flag!
      or Tile and not (fUnit or fHiddenUnit or fStealthUnit
      or fObserved or fSpiedOut or fOwned or fInEnemyZoC or fOwnZoCUnit
      or fPeace or fGrWall);
    if RW[pSender].Territory[Loc]<>RW[pTarget].Territory[Loc] then
      begin
      RW[pTarget].Territory[Loc]:=RW[pSender].Territory[Loc];
      {if RW[pTarget].BorderHelper<>nil then
        RW[pTarget].BorderHelper[Loc]:=0;}
      end;
    RW[pTarget].Territory[Loc]:=RW[pSender].Territory[Loc];
    RW[pTarget].MapObservedLast[Loc]:=RW[pSender].MapObservedLast[Loc];
    end;
end;

function PayPrice(pSender, pTarget, Price: integer; execute: boolean): boolean;
var
pSubject,i,n,NewTreaty: integer;
begin
result:=true;
case Price and opMask of
  opCivilReport: // + turn + concerned player shl 16
    begin
    pSubject:=Price shr 16 and $f;
    if pTarget=pSubject then result:=false
    else if pSender=pSubject then
      begin
      if execute then GiveCivilReport(pTarget,pSender)
      end
    else if RW[pSender].EnemyReport[pSubject].TurnOfCivilReport<0 then
      result:=false
    else if execute then CopyCivilReport(pSender, pTarget, pSubject);
    end;
  opMilReport: // + turn + concerned player shl 16
    begin
    pSubject:=Price shr 16 and $f;
    if pTarget=pSubject then result:=false
    else if pSender=pSubject then
      begin
      if execute then GiveMilReport(pTarget,pSender)
      end
    else if RW[pSender].EnemyReport[pSubject].TurnOfMilReport<0 then
      result:=false
    else if execute then CopyMilReport(pSender, pTarget, pSubject)
    end;
  opMap:
    if execute then
      begin
      CopyMap(pSender, pTarget);
      RecalcPeaceMap(pTarget);
      end;
  opTreaty..opTreaty+trAlliance: // + nation treaty
    begin
    if Price-opTreaty=RW[pSender].Treaty[pTarget]-1 then
      begin // agreed treaty end
      if execute then CancelTreaty(pSender,pTarget,false)
      end
    else
      begin
      NewTreaty:=-1;
      if Price-opTreaty=RW[pSender].Treaty[pTarget]+1 then
        NewTreaty:=Price-opTreaty
      else if (RW[pSender].Treaty[pTarget]=trNone) and (Price-opTreaty=trPeace) then
        NewTreaty:=trPeace;
      if NewTreaty<0 then result:=false
      else if execute then
        begin
        assert(NewTreaty>RW[pSender].Treaty[pTarget]);
        RW[pSender].Treaty[pTarget]:=NewTreaty;
        RW[pTarget].Treaty[pSender]:=NewTreaty;
        if NewTreaty>=trFriendlyContact then
          begin
          GiveCivilReport(pTarget, pSender);
          GiveCivilReport(pSender, pTarget);
          end;
        if NewTreaty=trAlliance then
          begin
          GiveMilReport(pTarget, pSender);
          GiveMilReport(pSender, pTarget);
          CopyMap(pSender, pTarget);
          CopyMap(pTarget, pSender);
          RecalcMapZoC(pSender);
          RecalcMapZoC(pTarget);
          end;
        if not (NewTreaty in [trPeace,trFriendlyContact]) then
          begin
          RW[pSender].EvaStart[pTarget]:=-PeaceEvaTurns-1;
          RW[pTarget].EvaStart[pSender]:=-PeaceEvaTurns-1;
          end;
        RecalcPeaceMap(pSender);
        RecalcPeaceMap(pTarget);
        end
      end
    end;
  opShipParts: // + number + part type shl 16
    begin
    n:=Price and $FFFF; // number
    i:=Price shr 16 and $f; // type
    if (i<nShipPart) and (GShip[pSender].Parts[i]>=n) then
      begin
      if execute then
        begin
        dec(GShip[pSender].Parts[i],n);
        RW[pSender].Ship[pSender].Parts[i]:=GShip[pSender].Parts[i];
        RW[pTarget].Ship[pSender].Parts[i]:=GShip[pSender].Parts[i];
        if RW[pTarget].NatBuilt[imSpacePort]>0 then
          begin // space ship control requires space port
          inc(GShip[pTarget].Parts[i],n);
          RW[pSender].Ship[pTarget].Parts[i]:=GShip[pTarget].Parts[i];
          RW[pTarget].Ship[pTarget].Parts[i]:=GShip[pTarget].Parts[i];
          end
        end
      end
    else result:=false;
    end;
  opMoney: // + value
    if (Price-opMoney<=MaxMoneyPrice) and (RW[pSender].Money>=Price-opMoney) then
      begin
      if execute then
        begin
        dec(RW[pSender].Money,Price-opMoney);
        inc(RW[pTarget].Money,Price-opMoney);
        end
      end
    else result:=false;
  opTribute: // + value
    if execute then
      begin
      end;
  opTech: // + advance
    if RW[pSender].Tech[Price-opTech]>=tsApplicable then
      begin
      if execute and (RW[pTarget].Tech[Price-opTech]=tsNA) then
        begin
        SeeTech(pTarget,Price-opTech);
        RW[pSender].EnemyReport[pTarget].Tech[Price-opTech]:=tsSeen;
        end
      end
    else result:=false;
  opAllTech:
    if execute then for i:=0 to nAdv-1 do
      if (RW[pSender].Tech[i]>=tsApplicable) and (RW[pTarget].Tech[i]=tsNA) then
        begin
        SeeTech(pTarget,i);
        RW[pSender].EnemyReport[pTarget].Tech[i]:=tsSeen;
        RW[pTarget].EnemyReport[pSender].Tech[i]:=tsApplicable;
        end;
  opModel: // + model index
    if Price-opModel<RW[pSender].nModel then
      begin
      if execute then CopyModel(pSender,pTarget,Price-opModel)
      end
    else result:=false;
  opAllModel:
    if execute then for i:=0 to RW[pSender].nModel-1 do
      begin
      TellAboutModel(pTarget,pSender,i);
      CopyModel(pSender,pTarget,i);
      end;
{  opCity: // + city ID
    begin
    result:=false
    end;}
  end
end;

procedure CancelTreaty(p, pWith: integer; DecreaseCredibility: boolean);
// side effect: PeaceEnded := bitarray of players with which peace treaty was canceled
var
p1,OldTreaty: integer;
begin
OldTreaty:=RW[p].Treaty[pWith];
PeaceEnded:=0;
if OldTreaty>=trPeace then
  RW[p].LastCancelTreaty[pWith]:=GTurn;
if DecreaseCredibility then
  begin
  case OldTreaty of
    trPeace:
      begin
      RW[p].Credibility:=RW[p].Credibility shr 1;
      if RW[p].MaxCredibility>0 then
        dec(RW[p].MaxCredibility,10);
      if RW[p].Credibility>RW[p].MaxCredibility then
        RW[p].Credibility:=RW[p].MaxCredibility;
      end;
    trAlliance:
      RW[p].Credibility:=RW[p].Credibility*3 div 4;
    end;
  RW[pWith].EnemyReport[p].Credibility:=RW[p].Credibility;
  end;

if OldTreaty=trPeace then
  begin
  for p1:=0 to nPl-1 do
    if (p1=pWith)
      or DecreaseCredibility and (p1<>p)
      and (RW[pWith].Treaty[p1]=trAlliance)
      and (RW[p].Treaty[p1]>=trPeace) then
      begin
      RW[p].Treaty[p1]:=trNone;
      RW[p1].Treaty[p]:=trNone;
      RW[p].EvaStart[p1]:=-PeaceEvaTurns-1;
      RW[p1].EvaStart[p]:=-PeaceEvaTurns-1;
      inc(PeaceEnded,1 shl p1);
      end;
  CheckBorders(-1);
  if (Mode>moLoading_Fast) and (PeaceEnded>0) then
    RecalcMapZoC(p);
  end
else
  begin
  RW[p].Treaty[pWith]:=OldTreaty-1;
  RW[pWith].Treaty[p]:=OldTreaty-1;
  if OldTreaty=trFriendlyContact then
    begin // necessary for loading
    GiveCivilReport(p, pWith);
    GiveCivilReport(pWith, p);
    end
  else if OldTreaty=trAlliance then
    begin // necessary for loading
    GiveMilReport(p, pWith);
    GiveMilReport(pWith, p);
    end;
  if (Mode>moLoading_Fast) and (OldTreaty=trAlliance) then
    begin
    RecalcMapZoC(p);
    RecalcMapZoC(pWith);
    end
  end;
if OldTreaty in [trPeace,trAlliance] then
  begin
  RecalcPeaceMap(p);
  RecalcPeaceMap(pWith);
  end
end;

function DoSpyMission(p,pCity,cix,Mission: integer): Cardinal;
var
p1: integer;
begin
result:=0;
case Mission of
  smSabotageProd: RW[pCity].City[cix].Flags:=
    RW[pCity].City[cix].Flags or chProductionSabotaged;
  smStealMap:
    begin
    CopyMap(pCity,p);
    RecalcPeaceMap(p);
    end;
  smStealCivilReport:
    begin
    if RW[p].Treaty[pCity]=trNoContact then IntroduceEnemy(p,pCity);
    GiveCivilReport(p,pCity);
    end;
  smStealMilReport:
    begin
    if RW[p].Treaty[pCity]=trNoContact then IntroduceEnemy(p,pCity);
    GiveMilReport(p,pCity);
    end;
  smStealForeignReports:
    begin
    for p1:=0 to nPl-1 do if (p1<>p) and (p1<>pCity)
      and (RW[pCity].EnemyReport[p1]<>nil) then
      begin
      if RW[pCity].EnemyReport[p1].TurnOfCivilReport>=0 then
        if CopyCivilReport(pCity,p,p1) then
          result:=result or (1 shl (2*p1));
      if RW[pCity].EnemyReport[p1].TurnOfMilReport>=0 then
        if CopyMilReport(pCity,p,p1) then
          result:=result or (2 shl (2*p1));
      end
    end;
  end;
end;

{
                              Test Flags
 ____________________________________________________________________
}
procedure ClearTestFlags(ClearFlags: integer);
var
p1: integer;
begin
GTestFlags:=GTestFlags and (not ClearFlags or tfTested or tfAllTechs or tfAllContact);
for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
  RW[p1].TestFlags:=GTestFlags;
end;

procedure SetTestFlags(p,SetFlags: integer);
var
i,p1,p2,MoreFlags: integer;
begin
MoreFlags:=SetFlags and not GTestFlags;
GTestFlags:=GTestFlags or (SetFlags and $7FF);
for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
  RW[p1].TestFlags:=GTestFlags;

if MoreFlags and (tfUncover or tfAllContact)<>0 then
  for p1:=0 to nPl-2 do
    if 1 shl p1 and GAlive<>0 then
      for p2:=p1+1 to nPl-1 do if 1 shl p2 and GAlive<>0 then
        begin // make p1 and p2 know each other
        if RW[p1].Treaty[p2]=trNoContact then
          IntroduceEnemy(p1,p2)
        end;

if MoreFlags and tfAllTechs<>0 then
  for p1:=0 to nPl-1 do
    begin
    ResourceMask[p1]:=$FFFFFFFF;
    if 1 shl p1 and GAlive<>0 then
      begin
      for i:=0 to nAdv-1 do // give all techs to player p1
        if not (i in FutureTech) and (RW[p1].Tech[i]<tsApplicable) then
          begin
          RW[p1].Tech[i]:=tsCheat;
          CheckSpecialModels(p1,i);
          end;
      for p2:=0 to nPl-1 do if (p2<>p1) and (1 shl p2 and (GAlive or GWatching)<>0) then
        for i:=1 to 3 do
          if RW[p2].EnemyReport[p1].Tech[AgePreq[i]]<tsApplicable then
            RW[p2].EnemyReport[p1].Tech[AgePreq[i]]:=tsCheat;
      end
    end;

if MoreFlags and tfUncover<>0 then
  begin
  DiscoverAll(p,lObserveSuper);
  for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
    begin
    ResourceMask[p1]:=$FFFFFFFF;
    if p1<>p then
      begin
      GiveCivilReport(p, p1);
      GiveMilReport(p, p1);
      end
    end
  end;
end;

{
                      Internal Command Processing
 ____________________________________________________________________
}
procedure IntServer(Command,Player,Subject:integer;var Data);
var
i,p1: integer;

begin
if Mode=moPlaying then
  CL.Put(Command, Player, Subject, @Data);

case Command of

  sIntTellAboutNation:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntTellAboutNation P%d+P%d', [Player,Subject]);{$ENDIF}
    assert((Player>=0) and (Player<nPl) and (Subject>=0) and (Subject<nPl));
    IntroduceEnemy(Player,Subject);
    end;

  sIntHaveContact:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntHaveContact P%d+P%d', [Player,Subject]);{$ENDIF}
    assert(RW[Player].Treaty[Subject]>trNoContact);
    RW[Player].EnemyReport[Subject].TurnOfContact:=GTurn;
    RW[Subject].EnemyReport[Player].TurnOfContact:=GTurn;
    end;

  sIntCancelTreaty:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntCancelTreaty P%d with P%d', [Player,Subject]);{$ENDIF}
    CancelTreaty(Player,Subject);
    end;

(*  sIntChoosePeace:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntChoosePeace P%d+P%d', [Player,Subject]);{$ENDIF}
    RW[Player].Treaty[Subject]:=trPeace;
    RW[Subject].Treaty[Player]:=trPeace;
    end;*)

  sIntTellAboutModel..sIntTellAboutModel+(nPl-1) shl 4:
    begin
    p1:=(Command-sIntTellAboutModel) shr 4; // told player
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntTellAboutModel P%d about P%d Mod%d', [p1,Player,Subject]);{$ENDIF}
    assert((Player>=0) and (Player<nPl));
    assert((Subject>=0) and (Subject<RW[Player].nModel));
    MakeModelInfo(Player,Subject,RW[Player].Model[Subject],
      RW[p1].EnemyModel[RW[p1].nEnemyModel]);
    RWemix[p1,Player,Subject]:=RW[p1].nEnemyModel;
    inc(RW[p1].nEnemyModel);
    assert(RW[p1].nEnemyModel<nemmax);
    end;

  sIntDiscoverZOC:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntDiscoverZOC P%d Loc%d', [Player,integer(data)]);{$ENDIF}
    Discover9(integer(Data),Player,lObserveUnhidden,true,false);
    end;

  sIntExpandTerritory:
    if Mode<moPlaying then
      begin
      {$IFDEF TEXTLOG}CmdInfo:=Format('IntExpandTerritory P%d Loc%d', [Player,RW[Player].City[Subject].Loc]);{$ENDIF}
      move(Data,BorderChanges,sizeof(BorderChanges));
      ExpandTerritory(RW[Player].City[Subject].Loc);
      end;

  sIntBuyMaterial:
    with RW[Player].City[Subject] do
      begin
      {$IFDEF TEXTLOG}CmdInfo:=Format('IntBuyMaterial P%d Loc%d Cost%d', [Player,Loc,integer(Data)]);{$ENDIF}
      dec(RW[Player].Money,integer(Data));
      if (GWonder[woMich].EffectiveOwner=Player) and (Project and cpImp<>0) then
        inc(Prod,integer(Data) div 2)
      else inc(Prod,integer(Data) div 4);
      if Project0 and not cpAuto<>Project and not cpAuto then
        Project0:=Project;
      Prod0:=Prod;
      end;

  sIntPayPrices..sIntPayPrices+12:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntPayPrices P%d+P%d', [Player,Subject]);{$ENDIF}
    for i:=0 to TOffer(Data).nDeliver-1 do
      PayPrice(Player,Subject,TOffer(Data).Price[i],true);
    for i:=0 to TOffer(Data).nCost-1 do
      PayPrice(Subject,Player,TOffer(Data).Price[TOffer(Data).nDeliver+i],true);
    for i:=0 to TOffer(Data).nDeliver+TOffer(Data).nCost-1 do
      if TOffer(Data).Price[i]=opTreaty+trAlliance then
        begin // add view area of allied player
        DiscoverViewAreas(Player);
        DiscoverViewAreas(Subject);
        break
        end
    end;

  sIntSetDevModel:
    if Mode<moPlaying then
      move(Data, RW[Player].DevModel.Kind, sIntSetDevModel and $F *4);

  sIntSetModelStatus: if ProcessClientData[Player] then
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntSetModelStatus P%d', [Player]);{$ENDIF}
    RW[Player].Model[Subject].Status:=integer(Data);
    end;

  sIntSetUnitStatus: if ProcessClientData[Player] then
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntSetUnitStatus P%d', [Player]);{$ENDIF}
    RW[Player].Un[Subject].Status:=integer(Data);
    end;

  sIntSetCityStatus: if ProcessClientData[Player] then
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntSetCityStatus P%d', [Player]);{$ENDIF}
    RW[Player].City[Subject].Status:=integer(Data);
    end;

  sIntSetECityStatus: if ProcessClientData[Player] then
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('IntSetECityStatus P%d', [Player]);{$ENDIF}
    RW[Player].EnemyCity[Subject].Status:=integer(Data);
    end;

  end;{case command}
end;{IntServer}

end.

