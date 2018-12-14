{$INCLUDE switches}
//{$DEFINE TEXTLOG}
//{$DEFINE LOADPERF}
unit GameServer;

interface

uses
Protocol, Database;

const
Version=$010200;
FirstAICompatibleVersion=$000D00;
FirstBookCompatibleVersion=$010103;

// notifications
ntCreateWorld=0; ntInitModule=$100; ntInitLocalHuman=$1FF;
ntDLLError=$200; ntAIError=$2FF;
ntClientError=$300;
ntInitPlayers=$400; ntDeactivationMissing=$410;
ntSetAIName=$420;
ntException=$500;
ntLoadBegin=$600; ntLoadState=$601;
ntEndInfo=$6FC; ntBackOn=$6FD; ntBackOff=$6FE; ntLoadError=$6FF;
ntStartDone=$700; ntStartGo=$701; ntStartGoRefresh=$702;
ntStartGoRefreshMaps=$703;
ntChangeClient=$800; ntNextPlayer=$810;
ntDeinitModule=$900;

// module flags
fMultiple=$10000000; fDotNet=$20000000; fUsed=$40000000;

// save map tile flags
smOwned=$20; smUnit=$40; smCity=$80;

maxBrain=255;
bixNoTerm=0; bixSuper_Virtual=1; bixTerm=2; bixRandom=3; bixFirstAI=4;

type
TNotifyFunction = procedure(ID: integer);

TBrainInfo= record
  FileName, DLLName, Name, Credits: string; {filename and full name}
  hm, {module handle}
  Flags,
  ServerVersion,
  DataVersion, DataSize: integer;
  Client: TClientCall; {client function address}
  Initialized: boolean;
  end;

var
// PARAMETERS
bixView: array[0..nPl-1]of integer; {brain index of the players}
Difficulty: array[0..nPl-1]of integer absolute Database.Difficulty; {difficulty}

// READ ONLY
DotNetClient: TClientCall;
bixBeginner, // AI to use for beginner level
nBrain: integer; {number of brains available}
Brain: array[-1..maxBrain-1] of TBrainInfo; {available brains}
NotifyMessage: string;

procedure Init(NotifyFunction: TNotifyFunction);
procedure Done;

procedure StartNewGame(const Path, FileName, Map: string; Newlx, Newly,
  NewLandMass, NewMaxTurn: integer);
function LoadGame(const Path, FileName: string; Turn: integer; MovieMode: boolean): boolean;
procedure EditMap(const Map: string; Newlx, Newly, NewLandMass: integer);
procedure DirectHelp(Command: integer);

procedure ChangeClient;
procedure NextPlayer;
function PreviewMap(lm: integer): pointer;


implementation

uses
Directories, CityProcessing, UnitProcessing, CmdList,

Windows,Classes,SysUtils;


var
MaxTurn,
LoadTurn, {turn where to stop loading}
nLogOpened, {nLog of opened book}
{$IFOPT O-}nHandoverStack,{$ENDIF}
LastEndClientCommand,
pContacted, // player contacted for negotiation
pDipActive, // player who's to speak in a negotiation
pTurn, {player who's turn it is}
GWinner,
GColdWarStart,
GStealFrom,
SpyMission,
ZOCTile,
CCCommand,
CCPlayer: integer;
DebugMap: array[0..nPl-1] of pointer;
ExeInfo: TSearchRec;
Stat: array[0..nStat-1, 0..nPl-1] of ^TChart;
AutoSaveState: TCmdListState;
MapField: ^Cardinal; // predefined map
LastOffer: TOffer;
CCData: array[0..14] of integer;
DevModelTurn, {turn of last call to sResetModel}
bix, {brain index of the players}
OriginalDataVersion: array[0..nPl-1] of integer;
SavedTiles{, SavedResourceWeights}: array[0..ncmax-1] of cardinal;
SavedData: array[0..nPl-1] of pointer;
LogFileName, SavePath, {name of file for saving the current game}
MapFileName, // name of map to use, empty for random
AICredits: string;
AIInfo: array[0..nPl-1] of string;
Notify: TNotifyFunction;
PerfFreq, LastClientTime: int64;
{$IFOPT O-}HandoverStack: array[0..31] of Cardinal;{$ENDIF}
AutoSaveExists,
LoadOK, WinOnAlone, PreviewElevation, MovieStopped: boolean;

const
PreviewRND=41601260; {randseed for preview map}

function Server(Command,Player,Subject:integer;var Data): integer; stdcall; forward;


procedure CallPlayer(Command,p: integer; var Data);
begin
if ((Mode<>moMovie) or (p=0)) then
  begin
  {$IFOPT O-}
  HandoverStack[nHandoverStack]:=p;
  HandoverStack[nHandoverStack+1]:=Command;
  inc(nHandoverStack,2);
  Brain[bix[p]].Client(Command,p,Data);
  dec(nHandoverStack,2);
  {$ELSE}
  try
    Brain[bix[p]].Client(Command,p,Data);
  except
    Notify(ntException+bix[p]);
    end;
  {$ENDIF}
  end
end;

procedure CallClient(bix,Command: integer; var Data);
begin
if ((Mode<>moMovie) or (bix=GameServer.bix[0])) then
  begin
  {$IFOPT O-}
  HandoverStack[nHandoverStack]:=bix;
  HandoverStack[nHandoverStack+1]:=Command;
  inc(nHandoverStack,2);
  Brain[bix].Client(Command,-1,Data);
  dec(nHandoverStack,2);
  {$ELSE}
  try
    Brain[bix].Client(Command,-1,Data);
  except
    Notify(ntException+bix);
    end;
  {$ENDIF}
  end
end;

procedure Init(NotifyFunction: TNotifyFunction);
var
i: integer;
f: TSearchRec;
T: TextFile;
s: string;

begin
Notify:=NotifyFunction;
PreviewElevation:=false;

{get available brains}
Brain[bixNoTerm].FileName:=':AIT';
Brain[bixNoTerm].Flags:=0;
Brain[bixNoTerm].Initialized:=false;
Brain[bixSuper_Virtual].FileName:=':Supervisor';
Brain[bixSuper_Virtual].Flags:=0;
Brain[bixSuper_Virtual].Initialized:=false;
Brain[bixTerm].FileName:=':StdIntf';
Brain[bixTerm].Flags:=fMultiple;
Brain[bixTerm].Initialized:=false;
Brain[bixTerm].ServerVersion:=Version;
Brain[bixRandom].FileName:=':Random';
Brain[bixRandom].Flags:=fMultiple;
Brain[bixRandom].Initialized:=false;
nBrain:=bixFirstAI;
bixBeginner:=bixFirstAI;
if FindFirst(HomeDir+'*.ai.txt',$21,f)=0 then
  repeat
    with Brain[nBrain] do
      begin
      FileName:=Copy(f.Name,1,Length(f.Name)-7);
      DLLName:=HomeDir+FileName;
      Name:=Copy(f.Name,1,Length(f.Name)-7);
      Credits:='';
      Flags:=fMultiple;
      Client:=nil;
      Initialized:=false;
      ServerVersion:=0;
      AssignFile(T,HomeDir+f.Name);
      Reset(T);
      while not EOF(T) do
        begin
        ReadLn(T,s);
        s:=trim(s);
        if Copy(s,1,5)='#NAME' then Name:=Copy(s,7,255)
        else if Copy(s,1,10)='#.NET' then
          Flags:=Flags or fDotNet
        else if Copy(s,1,9)='#BEGINNER' then
          bixBeginner:=nBrain
        else if Copy(s,1,5)='#PATH' then
          DLLName:=HomeDir+trim(Copy(s,7,255))
        else if Copy(s,1,12)='#GAMEVERSION' then
          for i:=13 to Length(s) do
            case s[i] of
              '0'..'9': ServerVersion:=ServerVersion and $FFFF00
                +ServerVersion and $FF *10+ord(s[i])-48;
              '.': ServerVersion:=ServerVersion shl 8;
              end
        else if Copy(s,1,8)='#CREDITS' then
          Credits:=Copy(s,10,255)
        end;
      CloseFile(T);
      end;
    if (Brain[nBrain].ServerVersion>=FirstAICompatibleVersion)
      and (Brain[nBrain].ServerVersion<=Version)
      and ((Brain[nBrain].Flags and fDotNet=0) or (@DotNetClient<>nil)) then
      inc(nBrain);
  until FindNext(f)<>0;
end;

procedure Done;
var
i: integer;
begin
for i:=0 to nBrain-1 do if Brain[i].Initialized then
  begin
  CallClient(i, cReleaseModule, nil^);
  if (i>=bixFirstAI) and (Brain[i].Flags and fDotNet=0) then
    FreeLibrary(Brain[i].hm);
  end;
end;

function PreviewMap(lm: integer): pointer;
begin
lx:=lxmax; ly:=lymax; MapSize:=lx*ly;
LandMass:=lm;
RandSeed:=PreviewRND;
if not PreviewElevation then
  begin
  CreateElevation;
  PreviewElevation:=true;
  end;
CreateMap(true);
result:=@RealMap;
end;

procedure ChangeClientWhenDone(Command, Player: integer; var Data;
  DataSize: integer);
begin
CCCommand:=Command;
CCPlayer:=Player;
if DataSize>0 then move(Data,CCData,DataSize);
Notify(ntChangeClient);
end;

procedure PutMessage(Level: integer; Text: string);
begin
Brain[bix[0]].Client(cDebugMessage,Level,pchar(Text)^);
end;

procedure ForceClientDeactivation;
var
NullOffer: TOffer;
begin
if pDipActive<0 then Server(sTurn,pTurn,0,nil^) // no nego mode
else case LastEndClientCommand of // nego mode
  scContact: Server(scReject,pDipActive,0,nil^);
  scDipCancelTreaty, scDipBreak: Server(scDipNotice,pDipActive,0,nil^);
  else
    begin // make null offer
    NullOffer.nDeliver:=0;
    NullOffer.nCost:=0;
    Server(scDipOffer,pDipActive,0,NullOffer);
    end
  end
end;

procedure ChangeClient;
//hand over control to other client (as specified by CC...)
var
p: integer;
T: int64;
begin
QueryPerformanceCounter(T);
PutMessage(1 shl 16+2, Format('CLIENT: took %.1f ms',
  [{$IFDEF VER100}(T.LowPart-LastClientTime.LowPart)
  {$ELSE}(T-LastClientTime){$ENDIF}*1000.0/PerfFreq]));
LastClientTime:=T;
PutMessage(1 shl 16+2, Format('CLIENT: calling %d (%s)',
  [CCPlayer,Brain[bix[CCPlayer]].Name]));
if CCCommand=cTurn then
  for p:=0 to nPl-1 do if (p<>CCPlayer) and (1 shl p and GWatching<>0) then
    CallPlayer(cShowTurnChange,p,CCPlayer);

p:=CCPlayer;
CCPlayer:=-1;
CallPlayer(CCCommand,p,CCData);
if (Mode=moPlaying) and (Brain[bix[p]].Flags and aiThreaded=0) and (CCPlayer<0) then
  begin
  Notify(ntDeactivationMissing+p);
  ForceClientDeactivation;
  end
end;

procedure Inform(p: integer);
var
i,p1: integer;
begin
RW[p].Turn:=GTurn;
if (GTurn=MaxTurn) and (p=pTurn) and (p=0) then
  RW[p].Happened:=RW[p].Happened or phTimeUp;
if (GWinner>0) and (p=pTurn) and (p=0) then
  RW[p].Happened:=RW[p].Happened or phShipComplete;
RW[p].Alive:=GAlive;
move(GWonder,RW[p].Wonder,SizeOf(GWonder));
move(GShip,RW[p].Ship,SizeOf(GShip));
for p1:=0 to nPl-1 do
  if (p1<>p) and (bix[p1]>=0) and (Difficulty[p1]>0) then
    RW[p].EnemyReport[p1].Credibility:=RW[p1].Credibility;
for p1:=0 to nPl-1 do
  if (p1<>p) and (1 shl p1 and GAlive<>0) then
    begin
    if (GTestFlags and tfUncover<>0) or (Difficulty[p]=0)
      or (RW[p].Treaty[p1]>=trFriendlyContact) then
      GiveCivilReport(p, p1);
    if (GTestFlags and tfUncover<>0) or (Difficulty[p]=0)
      or (RW[p].Treaty[p1]=trAlliance) then
      GiveMilReport(p, p1)
    end;
for i:=0 to RW[p].nEnemyModel-1 do with RW[p].EnemyModel[i] do
  Lost:=Destroyed[p,Owner,mix];
end;

procedure LogChanges;
var
p,ix: integer;
begin
for p:=0 to nPl-1 do
  if (1 shl p and GWatching<>0) and ProcessClientData[p] then
    begin
    // log unit status changes
    for ix:=0 to RW[p].nUn-1 do with RW[p].Un[ix] do
      if (Loc>=0) and (SavedStatus<>Status) then
        begin
        CL.Put(sIntSetUnitStatus, p, ix, @Status);
        SavedStatus:=Status
        end;
    // log city status changes
    for ix:=0 to RW[p].nCity-1 do with RW[p].City[ix] do
      if (Loc>=0) and (SavedStatus<>Status) then
        begin
        CL.Put(sIntSetCityStatus, p, ix, @Status);
        SavedStatus:=Status
        end;
    // log model status changes
    for ix:=0 to RW[p].nModel-1 do with RW[p].Model[ix] do
      if SavedStatus<>Status then
        begin
        CL.Put(sIntSetModelStatus, p, ix, @Status);
        SavedStatus:=Status
        end;
    // log enemy city status changes
    for ix:=0 to RW[p].nEnemyCity-1 do with RW[p].EnemyCity[ix] do
      if (Loc>=0) and (SavedStatus<>Status) then
        begin
        CL.Put(sIntSetECityStatus, p, ix, @Status);
        SavedStatus:=Status
        end;
    // log data changes
    if Brain[bix[p]].DataSize>0 then
      begin
      CL.PutDataChanges(sIntDataChange, p, SavedData[p], RW[p].Data,
        Brain[bix[p]].DataSize);
      move(RW[p].Data^,SavedData[p]^,Brain[bix[p]].DataSize*4);
      end
    end;
end;

procedure NoLogChanges;
var
p,ix: integer;
begin
for p:=0 to nPl-1 do
  if (1 shl p and GWatching<>0) and ProcessClientData[p] then
    begin
    for ix:=0 to RW[p].nUn-1 do with RW[p].Un[ix] do
      SavedStatus:=Status;
    for ix:=0 to RW[p].nCity-1 do with RW[p].City[ix] do
      SavedStatus:=Status;
    for ix:=0 to RW[p].nModel-1 do with RW[p].Model[ix] do
      SavedStatus:=Status;
    for ix:=0 to RW[p].nEnemyCity-1 do with RW[p].EnemyCity[ix] do
      SavedStatus:=Status;
    if Brain[bix[p]].DataSize>0 then
      move(RW[p].Data^,SavedData[p]^,Brain[bix[p]].DataSize*4);
    end;
end;

function HasChanges(p: integer): boolean;
type
TDWordList= array[0..INFIN] of Cardinal;
PDWortList=^TDWordList;
var
ix: integer;
begin
result:=false;
for ix:=0 to RW[p].nUn-1 do with RW[p].Un[ix] do
  if (Loc>=0) and (SavedStatus<>Status) then result:=true;
for ix:=0 to RW[p].nCity-1 do with RW[p].City[ix] do
  if (Loc>=0) and (SavedStatus<>Status) then result:=true;
for ix:=0 to RW[p].nModel-1 do with RW[p].Model[ix] do
  if SavedStatus<>Status then result:=true;
for ix:=0 to RW[p].nEnemyCity-1 do with RW[p].EnemyCity[ix] do
  if (Loc>=0) and (SavedStatus<>Status) then result:=true;
if RW[p].Data<>nil then for ix:=0 to Brain[bix[p]].DataSize-1 do
  if PDWortList(SavedData[p])[ix]<>PDWortList(RW[p].Data)[ix] then result:=true
end;

procedure InitBrain(bix: integer);
var
InitModuleData: TInitModuleData;
begin
assert(bix<>bixSuper_Virtual);
with Brain[bix] do
  begin
  if Initialized then exit;
  if bix>=bixFirstAI then
    begin {get client function}
    Notify(ntInitModule+bix);
    if Flags and fDotNet>0 then
      Client:=DotNetClient
    else
      begin
      hm:=LoadLibrary(pchar(DLLName));
      if hm=0 then
        begin
        Client:=nil;
        Notify(ntDLLError+bix);
        end
      else
        begin
        Client:=GetProcAddress(hm,'client');
        if @Client=nil then Notify(ntClientError+bix);
        end
      end
    end;
  if @Client<>nil then
    begin
    Initialized:=true;
    InitModuleData.Server:=@Server;
    InitModuleData.DataVersion:=0;
    InitModuleData.DataSize:=0;
    InitModuleData.Flags:=0;
    CallClient(bix, cInitModule, InitModuleData);
    DataVersion:=InitModuleData.DataVersion;
    DataSize:=(InitModuleData.DataSize+3) div 4;
    if DataSize>MaxDataSize then DataSize:=0;
    Flags:=Flags or InitModuleData.Flags;
    end
  end
end;

procedure SaveMap(FileName: string);
var
i: integer;
MapFile: TFileStream;
s: string[255];
begin
MapFile:=TFileStream.Create(DataDir+'Maps\'+FileName, fmCreate or fmShareExclusive);
MapFile.Position:=0;
s:='cEvoMap'#0; MapFile.write(s[1],8); {file id}
i:=0; MapFile.write(i,4); {format id}
MapFile.write(MaxTurn,4);
MapFile.write(lx,4);
MapFile.write(ly,4);
MapFile.write(RealMap,MapSize*4);
MapFile.Free;
end;

function LoadMap(FileName: string): boolean;
var
i,Loc1: integer;
MapFile: TFileStream;
s: string[255];
begin
result:=false;
MapFile:=nil;
try
  MapFile:=TFileStream.Create(DataDir+'Maps\'+FileName, fmOpenRead or fmShareExclusive);
  MapFile.Position:=0;
  MapFile.read(s[1],8); {file id}
  MapFile.read(i,4); {format id}
  if i=0 then
    begin
    MapFile.read(i,4); //MaxTurn
    MapFile.read(lx,4);
    MapFile.read(ly,4);
    ly:=ly and not 1;
    if lx>lxmax then lx:=lxmax;
    if ly>lymax then ly:=lymax;
    MapSize:=lx*ly;
    MapFile.read(RealMap,MapSize*4);
    for Loc1:=0 to MapSize-1 do
      begin
      RealMap[Loc1]:=RealMap[Loc1] and ($7F01FFFF or fPrefStartPos or fStartPos)
        or ($F shl 27);
      if RealMap[Loc1] and (fTerrain or fSpecial)=fSwamp or fSpecial2 then
        RealMap[Loc1]:=RealMap[Loc1] and not (fTerrain or fSpecial) or (fSwamp or fSpecial1);
      if (RealMap[Loc1] and fDeadLands<>0) and (RealMap[Loc1] and fTerrain<>fArctic) then
        RealMap[Loc1]:=RealMap[Loc1] and not (fTerrain or fSpecial) or fDesert;
      end;
    result:=true;
    end;
  MapFile.Free;
except
  if MapFile<>nil then MapFile.Free;
  end;
end;

procedure SaveGame(FileName: string; auto: boolean);
var
x,y,i,zero,Tile,nLocal: integer;
LogFile: TFileStream;
s: string[255];
SaveMap: array[0..lxmax*lymax-1] of Byte;
begin
nLocal:=0;
for i:=0 to nPl-1 do if bix[i]=bixTerm then inc(nLocal);
if Difficulty[0]=0 then nLocal:=0;
if nLocal<=1 then for y:=0 to ly-1 do for x:=0 to lx-1 do
  begin
  Tile:=RW[0].Map[(x+SaveMapCenterLoc+lx shr 1) mod lx +lx*y];
  SaveMap[x+lx*y]:=Tile and fTerrain + Tile and (fCity or fUnit or fOwned) shr 16;
  end;

if auto and AutoSaveExists then // append to existing file
  LogFile:=TFileStream.Create(SavePath+FileName,
    fmOpenReadWrite or fmShareExclusive)
else // create new file
  LogFile:=TFileStream.Create(SavePath+FileName, fmCreate or fmShareExclusive);

zero:=0;
LogFile.Position:=0;
s:='cEvoBook'; LogFile.write(s[1],8); {file id}
i:=Version; LogFile.write(i,4); {c-evo version}
LogFile.write(ExeInfo.Time,4);
LogFile.write(lx,4);
LogFile.write(ly,4);
LogFile.write(LandMass,4);
if LandMass=0 then
  LogFile.write(MapField^,MapSize*4);

LogFile.write(MaxTurn,4);
LogFile.write(RND,4);
LogFile.write(GTurn,4);
if nLocal>1 then // multiplayer game -- no quick view
  begin i:=$80; LogFile.write(i,4); end
else LogFile.write(SaveMap,((MapSize-1) div 4+1)*4);
for i:=0 to nPl-1 do
  if bix[i]<0 then LogFile.write(zero,4)
  else
    begin
    if bixView[i]>=bixRandom then s:=Brain[bix[i]].FileName
    else s:=Brain[bixView[i]].FileName;
    move(zero,s[Length(s)+1],4);
    LogFile.write(s,(Length(s) div 4+1)*4);
    LogFile.write(OriginalDataVersion[i],4);
    s:=''; {behavior} move(zero,s[Length(s)+1],4);
    LogFile.write(s,(Length(s) div 4+1)*4);
    LogFile.write(Difficulty[i],4);
    end;

if auto and AutoSaveExists then CL.AppendToFile(LogFile, AutoSaveState)
else CL.SaveToFile(LogFile);
LogFile.Free;
if auto then
  begin AutoSaveState:=CL.State; AutoSaveExists:=true end
end;

procedure StartGame;
var
i,p,p1,Human,nAlive,bixUni: integer;
Game: TNewGameData;
//GameEx: TNewGameExData;
path: shortstring;
BrainUsed: Set of 0..254; {used brains}
begin
for p1:=0 to nPl-1 do
  begin
  if bixView[p1]=bixSuper_Virtual then bix[p1]:=bixTerm // supervisor and local human use same module
  else if bixView[p1]=bixRandom then
    if nBrain<=bixFirstAI then bix[p1]:=-1
    else bix[p1]:=bixFirstAI+random(nBrain-bixFirstAI)
  else bix[p1]:=bixView[p1];
  if bixView[p1]<0 then Difficulty[p1]:=-1;
  end;

if bix[0]<>bixNoTerm then Notify(ntInitLocalHuman);
BrainUsed:=[];
for p:=0 to nPl-1 do
  if (bix[p]>=0) and ((Mode<>moMovie) or (p=0)) then
    begin {initiate selected control module}
    AIInfo[p]:=Brain[bix[p]].Name+#0;
    InitBrain(bix[p]);
    if Mode=moPlaying then
      begin // new game, this data version is original
      OriginalDataVersion[p]:=Brain[bix[p]].DataVersion;
      ProcessClientData[p]:=true;
      end
    else // loading game, compare with data version read from file
      ProcessClientData[p]:=ProcessClientData[p]
        and (OriginalDataVersion[p]=Brain[bix[p]].DataVersion);
    if @Brain[bix[p]].Client=nil then // client function not found
      if bix[0]=bixNoTerm then
        bix[p]:=-1
      else
        begin
        bix[p]:=bixTerm;
        OriginalDataVersion[p]:=-1;
        ProcessClientData[p]:=false;
        end;
    if bix[p]>=0 then include(BrainUsed,bix[p])
    end;

Notify(ntCreateWorld);
nAlive:=0;
GAlive:=0;
if Mode=moMovie then GWatching:=1
else GWatching:=0;
GAI:=0;
for p1:=0 to nPl-1 do if bix[p1]>=0 then
  begin
  if Mode<>moMovie then inc(GWatching,1 shl p1);
  if bix[p1]>=bixFirstAI then inc(GAI,1 shl p1);
  if Difficulty[p1]>0 then
    begin inc(GAlive,1 shl p1); inc(nAlive); end;
  ServerVersion[p1]:=Brain[bix[p1]].ServerVersion;
  end;
WinOnAlone:= (bix[0]=bixNoTerm) and (nAlive>1);
GWinner:=0;
GColdWarStart:=-ColdWarTurns-1;
uixSelectedTransport:=-1;
SpyMission:=smSabotageProd;
for p1:=0 to nPl-1 do
  DebugMap[p1]:=nil;

GTurn:=0;
for i:=0 to 27 do with GWonder[i] do
  begin CityID:=-1; EffectiveOwner:=-1 end;
FillChar(GShip,SizeOf(GShip),0);

for p:=0 to nPl-1 do if 1 shl p and (GAlive or GWatching)<>0 then with RW[p] do
  begin
  Government:=gDespotism;
  Money:=StartMoney;
  TaxRate:=30;
  LuxRate:=0;
  Research:=0;
  ResearchTech:=-2;
  AnarchyStart:=-AnarchyTurns-1;
  Happened:=0;
  LastValidStat[p]:=-1;
  Worked[p]:=0;
  Founded[p]:=0;
  DevModelTurn[p]:=-1;
  OracleIncome:=0;

  if Brain[bix[p]].DataSize>0 then
    begin
    GetMem(SavedData[p], Brain[bix[p]].DataSize*4);
    GetMem(Data, Brain[bix[p]].DataSize*4);
    FillChar(SavedData[p]^,Brain[bix[p]].DataSize*4,0);
    FillChar(Data^,Brain[bix[p]].DataSize*4,0);
    end
  else begin Data:=nil; SavedData[p]:=nil end;
  nBattleHistory:=0;
  BattleHistory:=nil;
  {if bix[p]=bixTerm then
    begin
    GetMem(BorderHelper,MapSize);
    FillChar(BorderHelper^,MapSize,0);
    end
  else} BorderHelper:=nil;
  for i:=0 to nStat-1 do GetMem(Stat[i,p],4*(MaxTurn+1));
  if Brain[bix[p]].Flags and fDotNet<>0 then
    begin
    GetMem(RW[p].DefaultDebugMap, MapSize*4);
    FillChar(RW[p].DefaultDebugMap^, MapSize*4, 0);
    DebugMap[p]:=RW[p].DefaultDebugMap;
    end
  else RW[p].DefaultDebugMap:=nil;

  {!!!for i:=0 to nShipPart-1 do GShip[p].Parts[i]:=random((3-i)*2);{}
  end;

if LandMass>0 then
  begin // random map
  InitRandomGame;
  PreviewElevation:=false;
  MapField:=nil;
  end
else
  begin // predefined map
  if Mode=moPlaying then
    LoadMap(MapFileName); // new game -- load map from file
  GetMem(MapField,MapSize*4);
  move(RealMap,MapField^,MapSize*4);
  Human:=0;
  for p1:=0 to nPl-1 do if bix[p1]=bixTerm then inc(Human,1 shl p1);
  InitMapGame(Human);
  end;
CityProcessing.InitGame;
UnitProcessing.InitGame;
for p:=0 to nPl-1 do if 1 shl p and (GAlive or GWatching)<>0 then
  Inform(p);

pTurn:=-1;
if bix[0]<>bixNoTerm then
  Notify(ntInitLocalHuman);
Game.lx:=lx; Game.ly:=ly; Game.LandMass:=LandMass; Game.MaxTurn:=MaxTurn;
move(Difficulty,Game.Difficulty,SizeOf(Difficulty));
//GameEx.lx:=lx; GameEx.ly:=ly; GameEx.LandMass:=LandMass;
//GameEx.MaxTurn:=MaxTurn; GameEx.RND:=RND;
//move(Difficulty,GameEx.Difficulty,SizeOf(Difficulty));
AICredits:='';
for i:=0 to nBrain-1 do if Brain[i].Initialized then
  if i in BrainUsed then
    begin
    if i>=bixFirstAI then
      Notify(ntInitPlayers);
    for p:=0 to nPl-1 do
      begin
      if bix[p]=i then
        Game.RO[p]:=@RW[p]
      else Game.RO[p]:=nil;
      if (i=bixTerm) and (Difficulty[0]=0) and (bix[p]>=0) then
        Game.SuperVisorRO[p]:=@RW[p]
      else Game.SuperVisorRO[p]:=nil;
      end;
    if Brain[i].Flags and fDotNet>0 then
      begin
      path:=Brain[i].DLLName;
      move(path[1], Game.AssemblyPath, Length(path));
      Game.AssemblyPath[Length(path)]:=#0;
      end
    else Game.AssemblyPath[0]:=#0;
    case Mode of
      moLoading, moLoading_Fast: CallClient(i, cLoadGame, Game);
      moMovie: CallClient(i, cMovie, Game);
      moPlaying: CallClient(i, cNewGame, Game);
      end;
    if (i>=bixFirstAI) and (Brain[i].Credits<>'') then
      if AICredits='' then AICredits:=Brain[i].Credits
      else AICredits:=AICredits+'\'+Brain[i].Credits
    end
  else
    begin {module no longer used -- unload}
    CallClient(i, cReleaseModule, nil^);
    if i>=bixFirstAI then
      begin
      if Brain[i].Flags and fDotNet=0 then
        FreeLibrary(Brain[i].hm);
      Brain[i].Client:=nil;
      end;
    Brain[i].Initialized:=false;
    end;
AICredits:=AICredits+#0;

if bix[0]<>bixNoTerm then
  begin
  // uni ai?
  bixUni:=-1;
  for p1:=0 to nPl-1 do if bix[p1]>=bixFirstAI then
    if bixUni=-1 then bixUni:=bix[p1]
    else if bixUni<>bix[p1] then bixUni:=-2;
  for p1:=0 to nPl-1 do if bix[p1]>=bixFirstAI then
    begin
    if bixUni=-2 then NotifyMessage:=Brain[bix[p1]].FileName
    else NotifyMessage:='';
    Notify(ntSetAIName+p1);
    end
  end;

CheckBorders(-1);
{$IFOPT O-}InvalidTreatyMap:=0;{$ENDIF}
AutoSaveExists:=false;
pDipActive:=-1;
pTurn:=0;

if Mode>=moMovie then
  Notify(ntEndInfo);
end;{StartGame}

procedure EndGame;
var
i,p1: integer;
begin
if LandMass=0 then FreeMem(MapField);
for p1:=0 to nPl-1 do if bix[p1]>=0 then
  begin
  for i:=0 to nStat-1 do FreeMem(Stat[i,p1]);
  if RW[p1].BattleHistory<>nil then FreeMem(RW[p1].BattleHistory);
  {if RW[p1].BorderHelper<>nil then FreeMem(RW[p1].BorderHelper);}
  FreeMem(RW[p1].Data);
  FreeMem(SavedData[p1]);
  if RW[p1].DefaultDebugMap<>nil then
    FreeMem(RW[p1].DefaultDebugMap);
  end;
UnitProcessing.ReleaseGame;
CityProcessing.ReleaseGame;
Database.ReleaseGame;
CL.Free;
end;

procedure GenerateStat(p: integer);
var
cix,uix: integer;
begin
if Difficulty[p]>0 then with RW[p] do
  begin
  Stat[stPop,p,GTurn]:=0;
  for cix:=0 to nCity-1 do if City[cix].Loc>=0 then
    inc(Stat[stPop,p,GTurn],City[cix].Size);
  Stat[stScience,p,GTurn]:=Researched[p]*50;
  if (RW[p].ResearchTech>=0) and (RW[p].ResearchTech<>adMilitary) then
    inc(Stat[stScience,p,GTurn],
      Research*100 div TechBaseCost(nTech[p],Difficulty[p]));
  Stat[stMil,p,GTurn]:=0;
  for uix:=0 to nUn-1 do if Un[uix].Loc>=0 then
    with Model[Un[uix].mix] do
      begin
      if (Kind<=mkEnemyDeveloped) and (Un[uix].mix<>1) then
        inc(Stat[stMil,p,GTurn],Weight*MStrength*Un[uix].Health div 100)
      else if Domain=dGround then inc(Stat[stMil,p,GTurn],(Attack+2*Defense)*Un[uix].Health div 100)
      else inc(Stat[stMil,p,GTurn],(Attack+Defense)*Un[uix].Health div 100);
      case Kind of
        mkSlaves: inc(Stat[stPop,p,GTurn]);
        mkSettler: inc(Stat[stPop,p,GTurn],2);
        end;
      end;
  Stat[stMil,p,GTurn]:=Stat[stMil,p,GTurn] div 16;
  Stat[stExplore,p,GTurn]:=Discovered[p];
  Stat[stTerritory,p,GTurn]:=TerritoryCount[p];
  Stat[stWork,p,GTurn]:=Worked[p];
  LastValidStat[p]:=GTurn;
  end;
end;

procedure LogCityTileChanges;
var
cix: integer;
begin
for cix:=0 to RW[pTurn].nCity-1 do
  with RW[pTurn].City[cix] do if Loc>=0 then
    begin
{    if SavedResourceWeights[cix]<>ResourceWeights then
      begin // log city resource weight changes
      CL.Put(sSetCityResourceWeights, pTurn, cix, @ResourceWeights);
      SavedResourceWeights[cix]:=ResourceWeights;
      end;}
    if SavedTiles[cix]<>Tiles then
      begin // log city tile changes
      CL.Put(sSetCityTiles, pTurn, cix, @Tiles);
      SavedTiles[cix]:=Tiles;
      end;
    end;
end;

procedure NoLogCityTileChanges;
var
cix: integer;
begin
for cix:=0 to RW[pTurn].nCity-1 do
  with RW[pTurn].City[cix] do if Loc>=0 then
    begin
//    SavedResourceWeights[cix]:=ResourceWeights;
    SavedTiles[cix]:=Tiles;
    end;
end;

function HasCityTileChanges: boolean;
var
cix: integer;
begin
result:=false;
for cix:=0 to RW[pTurn].nCity-1 do
  with RW[pTurn].City[cix] do if Loc>=0 then
    begin
//    if SavedResourceWeights[cix]<>ResourceWeights then result:=true;
    if SavedTiles[cix]<>Tiles then result:=true;
    end;
end;

procedure BeforeTurn0;
var
p1,uix: integer;
begin
for uix:=0 to RW[pTurn].nUn-1 do {init movement points for first turn}
  with RW[pTurn].Un[uix] do Movement:=RW[pTurn].Model[mix].Speed;

if Difficulty[pTurn]>0 then
  DiscoverViewAreas(pTurn)
else {supervisor}
  begin
  DiscoverAll(pTurn,lObserveSuper);
  for p1:=1 to nPl-1 do
    if 1 shl p1 and GAlive<>0 then
      begin
      GiveCivilReport(pTurn, p1);
      GiveMilReport(pTurn, p1)
      end;
  end;
//CheckContact;
end;

function LoadGame(const Path, FileName: string; Turn: integer; MovieMode: boolean): boolean;
var
i,j,ix,d,p1,Command,Subject: integer;
{$IFDEF TEXTLOG}LoadPos0: integer;{$ENDIF}
Data: pointer;
LogFile: TFileStream;
FormerCLState: TCmdListState;
s: string[255];
SaveMap: array[0..lxmax*lymax-1] of Byte;
started,StatRequest: boolean;
begin
SavePath:=Path;
LogFileName:=FileName;
LoadTurn:=Turn;
LogFile:=TFileStream.Create(SavePath+LogFileName,fmOpenRead or fmShareExclusive);
LogFile.Position:=0;
LogFile.read(s[1],8); {file id}
LogFile.read(i,4); {c-evo version}
LogFile.read(j,4); {exe time}

if (i>=FirstBookCompatibleVersion) and (i<=Version) then
  begin
  result:=true;
  LogFile.read(lx,4);
  LogFile.read(ly,4);
  MapSize:=lx*ly;
  LogFile.read(LandMass,4);
  if LandMass=0 then
    LogFile.read(RealMap,MapSize*4); // use predefined map
  LogFile.read(MaxTurn,4); 
  LogFile.read(RND,4);
  LogFile.read(GTurn,4);
  LogFile.read(SaveMap,4);
  if SaveMap[0]<>$80 then
    LogFile.read(SaveMap[4],((MapSize-1) div 4+1)*4-4);
  for p1:=0 to nPl-1 do
    begin
    LogFile.read(s[0],4);
    if s[0]=#0 then bixView[p1]:=-1
    else
      begin
      LogFile.read(s[4],Byte(s[0]) div 4 *4);
      LogFile.read(OriginalDataVersion[p1],4);
      LogFile.read(d,4);{behavior}
      LogFile.read(Difficulty[p1],4);
      j:=nBrain-1;
      while (j>=0) and (AnsiCompareFileName(Brain[j].FileName,s)<>0) do
        dec(j);
      if j<0 then
        begin // ai not found -- replace by local player
        ProcessClientData[p1]:=false;
        NotifyMessage:=s;
        Notify(ntAIError);
        j:=bixTerm;
        end
      else ProcessClientData[p1]:=true;
      if j=bixNoTerm then j:=bixSuper_Virtual;
        // crashed tournament -- load as supervisor
      bixView[p1]:=j;
      end;
    end;
  end
else result:=false;

if result then
  begin
  CL:=TCmdList.Create;
  CL.LoadFromFile(LogFile);
  end;
LogFile.Free;
if not result then exit;

Notify(ntStartDone);
if LoadTurn<0 then LoadTurn:=GTurn;
if MovieMode then Mode:=moMovie
else if LoadTurn=0 then Mode:=moLoading
else Mode:=moLoading_Fast;
{$IFDEF TEXTLOG}AssignFile(TextLog,SavePath+LogFileName+'.txt');Rewrite(TextLog);{$ENDIF}
LoadOK:=true;
StartGame;
if MovieMode then
  begin
  Brain[bix[0]].Client(cShowGame,0,nil^);
  Notify(ntBackOff);
  end
else Notify(ntLoadBegin);

started:=false;
StatRequest:=false;
MovieStopped:=false;
{$IFDEF LOADPERF}QueryPerformanceCounter(time_total0); time_a:=0; time_b:=0; time_c:=0;{$ENDIF}
while not MovieStopped and (CL.Progress<1000) do
  begin
  FormerCLState:=CL.State;
  CL.Get(Command, p1, Subject, Data);
  if p1<0 then p1:=pTurn;
  if StatRequest
    and (Command and (sctMask or sExecute)<>sctInternal or sExecute) then
    begin GenerateStat(pTurn); StatRequest:=false end;
      // complete all internal commands following an sTurn before generating statistics
  if (Command=sTurn) and not started then
    begin
    {$IFDEF TEXTLOG}WriteLn(TextLog,'---Turn 0 P0---');{$ENDIF}
    for p1:=0 to nPl-1 do
      if (bix[p1]>=0) and ((Mode<>moMovie) or (p1=0)) then
        CallPlayer(cReplay,p1,nil^);
    BeforeTurn0;
    if MovieMode then
      begin
      Inform(pTurn);
      CallPlayer(cMovieTurn,0,nil^);
      end;
    StatRequest:=true;
    started:=true;
    end
  else if (Command=sTurn) and (pTurn=0) and (GTurn=LoadTurn) then
    begin
    assert(CL.State.LoadPos=FormerCLState.LoadPos+4); // size of sTurn
    CL.State:=FormerCLState;
    CL.Cut;
    Break;
    end
  else if Command=sIntDataChange then
    begin
    {$IFDEF TEXTLOG}LoadPos0:=CL.State.LoadPos;{$ENDIF}
    if ProcessClientData[p1] then
      CL.GetDataChanges(RW[p1].Data, Brain[bix[p1]].DataSize)
    else CL.GetDataChanges(nil, 0);
    {$IFDEF TEXTLOG}WriteLn(TextLog,Format('Data Changes P%d (%d Bytes)', [p1,CL.State.LoadPos-LoadPos0]));{$ENDIF}
    end
  else
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('Command %x',[Command]);{$ENDIF}
    if Command and (sctMask or sExecute)=sctInternal or sExecute then
      IntServer(Command, p1, Subject, Data^) // internal command
    else
      begin
      StatRequest:= Command=sTurn;
      Server(Command, p1, Subject, Data^);
      end;
    {$IFDEF TEXTLOG}WriteLn(TextLog,CmdInfo);{$ENDIF}
    end;
  if not MovieMode then Notify(ntLoadState+CL.Progress*128 div 1000);
  end;

if MovieMode then
  begin
  Notify(ntBackOn);
  Brain[bix[0]].Client(cBreakGame,-1,nil^);
  EndGame;
  Notify(ntStartGo);
  result:=false;
  exit;
  end;

if StatRequest then GenerateStat(pTurn);
assert(started);
{$IFDEF TEXTLOG}CloseFile(TextLog);{$ENDIF}
{$IFDEF LOADPERF}QueryPerformanceCounter(time_total);{time in s is: (time_total-time_total0)/PerfFreq}{$ENDIF}
NoLogChanges;
NoLogCityTileChanges;
if LogFileName[1]='~' then
  begin Delete(LogFileName,1,1); nLogOpened:=-1 end
else nLogOpened:=CL.State.nLog;

Mode:=moPlaying;
LastEndClientCommand:=-1;
if (GTestFlags and tfUncover<>0) or (Difficulty[pTurn]=0) then
  DiscoverAll(pTurn,lObserveSuper) {supervisor - all tiles visible}
else DiscoverViewAreas(pTurn);

for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
  begin
  RecalcPeaceMap(p1);
  for ix:=0 to RW[p1].nEnemyUn-1 do with RW[p1].EnemyUn[ix] do
    emix:=RWemix[p1,Owner,mix];
  Inform(p1);
  end;
{$IFOPT O-}CheckBorders(-2);{$ENDIF} // for testing only
Notify(ntEndInfo);
if not LoadOK then
  begin NotifyMessage:=SavePath+LogFileName; Notify(ntLoadError); end;
Brain[bix[0]].Client(cShowGame,0,nil^);
Notify(ntBackOff);
Inform(pTurn);
ChangeClientWhenDone(cResume,0,nil^,0);
end; //LoadGame

procedure InsertTerritoryUpdateCommands;
var
p1,Command,Subject: integer;
Data: pointer;
FormerCLState: TCmdListState;
begin
while CL.Progress<1000 do
  begin
  FormerCLState:=CL.State;
  CL.Get(Command, p1, Subject, Data);
  if (Command=sIntExpandTerritory) and (p1=pTurn) then
    begin
    IntServer(Command, p1, Subject, Data^);
    {$IFDEF TEXTLOG}WriteLn(TextLog,'AfterTurn - ExpandTerritory');{$ENDIF}
    end
  else
    begin
    CL.State:=FormerCLState;
    break
    end
  end;
{$IFOPT O-}InvalidTreatyMap:=0;{$ENDIF}
end;

procedure StartNewGame(const Path, FileName, Map: string; Newlx, Newly,
  NewLandMass, NewMaxTurn: integer);
var
p: integer;
begin
Notify(ntStartDone);
SavePath:=Path;
LogFileName:=FileName;
MapFileName:=Map;
if FastContact then begin lx:=24; ly:=42; end
else begin lx:=Newlx; ly:=Newly end;
MapSize:=lx*ly;
if MapFileName<>'' then LandMass:=0
else LandMass:=NewLandMass;
MaxTurn:=NewMaxTurn;
Randomize;
RND:=RandSeed;
Mode:=moPlaying;
CL:=TCmdList.Create;
StartGame;
NoLogChanges;
for p:=0 to nPl-1 do if bix[p]>=0 then
  CallPlayer(cGetReady,p,nil^);
LogChanges;
CL.Put(sTurn, 0, 0, nil);
BeforeTurn0;
NoLogCityTileChanges;
GenerateStat(pTurn);
nLogOpened:=-1;
LastEndClientCommand:=-1;
Brain[bix[0]].Client(cShowGame,0,nil^);
Notify(ntBackOff);
Inform(pTurn);
ChangeClientWhenDone(cTurn,0,nil^,0)
end;

procedure DirectHelp(Command: integer);
begin
InitBrain(bixTerm);
Brain[bixTerm].Client(Command,-1,nil^);
AICredits:=#0;
end;

procedure EditMap(const Map: string; Newlx, Newly, NewLandMass: integer);
var
p1,Loc1: integer;
Game: TNewGameData;
begin
Notify(ntStartDone);
Notify(ntInitLocalHuman);
MapFileName:=Map;
lx:=Newlx;
ly:=Newly;
MapSize:=lx*ly;
LandMass:=NewLandMass;
bix[0]:=bixTerm;
Difficulty[0]:=0;
InitBrain(bixTerm);

Randomize;
GAlive:=0;
GWatching:=1;
if not LoadMap(MapFileName) then
  for Loc1:=0 to MapSize-1 do RealMap[Loc1]:=fOcean or ($F shl 27);
CL:=nil;
InitMapEditor;
RW[0].Data:=nil;
RW[0].BorderHelper:=nil;
RW[0].Alive:=0;
Game.lx:=lx; Game.ly:=ly;
Game.RO[0]:=@RW[0];
Game.Difficulty[0]:=0;
for p1:=1 to nPl-1 do begin Game.RO[p1]:=nil; Game.Difficulty[p1]:=-1 end;
Brain[bixTerm].Client(cNewMap,-1,Game);

DiscoverAll(0,lObserveSuper);
Notify(ntEndInfo);
Brain[bix[0]].Client(cShowGame,0,nil^);
Notify(ntBackOff);
ChangeClientWhenDone(cEditMap,0,nil^,0)
end;

procedure DestroySpacePort_TellPlayers(p,pCapturer: integer);
var
cix,i,p1: integer;
ShowShipChange: TShowShipChange;
begin
// stop ship part production
for cix:=0 to RW[p].nCity-1 do with RW[p].City[cix] do
  if (Loc>=0) and (Project and cpImp<>0)
    and ((Project and cpIndex=woMIR)
      or (Imp[Project and cpIndex].Kind=ikShipPart)) then
    begin
    inc(RW[p].Money,Prod0);
    Prod:=0;
    Prod0:=0;
    Project:=cpImp+imTrGoods;
    Project0:=cpImp+imTrGoods
    end;

// destroy ship
with GShip[p] do if Parts[0]+Parts[1]+Parts[2]>0 then
  begin
  for i:=0 to nShipPart-1 do
    begin
    ShowShipChange.Ship1Change[i]:=-Parts[i];
    if pCapturer>=0 then
      begin
      ShowShipChange.Ship2Change[i]:=Parts[i];
      inc(GShip[pCapturer].Parts[i], Parts[i]);
      end;
    Parts[i]:=0;
    end;
  if Mode>=moMovie then
    begin
    if pCapturer>=0 then ShowShipChange.Reason:=scrCapture
    else ShowShipChange.Reason:=scrDestruction;
    ShowShipChange.Ship1Owner:=p;
    ShowShipChange.Ship2Owner:=pCapturer;
    for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
      begin
      move(GShip,RW[p1].Ship,SizeOf(GShip));
      if 1 shl p1 and GWatching<>0 then
        CallPlayer(cShowShipChange,p1,ShowShipChange);
      end;
    end
  end
end;

procedure DestroyCity_TellPlayers(p,cix: integer; SaveUnits: boolean);
begin
if RW[p].City[cix].built[imSpacePort]>0 then
  DestroySpacePort_TellPlayers(p,-1);
DestroyCity(p,cix,SaveUnits);
end;

procedure ChangeCityOwner_TellPlayers(pOld,cixOld,pNew: integer);
begin
if RW[pOld].City[cixOld].built[imSpacePort]>0 then
  if RW[pNew].NatBuilt[imSpacePort]>0 then
    DestroySpacePort_TellPlayers(pOld,pNew)
  else DestroySpacePort_TellPlayers(pOld,-1);
ChangeCityOwner(pOld,cixOld,pNew);
end;

procedure CheckWin(p: integer);
var
i: integer;
ShipComplete: boolean;
begin
ShipComplete:=true;
for i:=0 to nShipPart-1 do
  if GShip[p].Parts[i]<ShipNeed[i] then ShipComplete:=false;
if ShipComplete then GWinner:=GWinner or 1 shl p; // game won!
end;

procedure BeforeTurn;
var
i,p1,uix,cix,V21,Loc1,Cost,Job0,nAlive,nAppliers,ad,
  OldLoc,SiegedTiles,nUpdateLoc: integer;
UpdateLoc: array[0..numax-1] of integer;
Radius: TVicinity21Loc;
ShowShipChange: TShowShipChange;
TribeExtinct, JobDone, MirBuilt: boolean;
begin
{$IFOPT O-}assert(1 shl pTurn and InvalidTreatyMap=0);{$ENDIF}
assert(1 shl pTurn and (GAlive or GWatching)<>0);
if (1 shl pTurn and GAlive=0) and (Difficulty[pTurn]>0) then
  exit;

if (GWonder[woGrLibrary].EffectiveOwner=pTurn) and (GWinner=0) then
  begin // check great library effect
  nAlive:=0;
  for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then inc(nAlive);
  for ad:=0 to nAdv-5 do if RW[pTurn].Tech[ad]<tsSeen then
    begin
    nAppliers:=0;
    for p1:=0 to nPl-1 do
      if (p1<>pTurn) and (1 shl p1 and GAlive<>0)
        and (RW[p1].Tech[ad]>=tsApplicable) then
        inc(nAppliers);
    if nAppliers*2>nAlive then
      begin
      SeeTech(pTurn,ad);
      inc(nTech[pTurn]);
      if Mode>=moMovie then
        CallPlayer(cShowGreatLibTech,pTurn,ad);
        // do not call CallPlayer(pTurn) while map is invalid
      end;
    end;
  end;

MaskD(ObserveLevel,MapSize,not Cardinal(3 shl (2*pTurn)));
if Mode>moLoading_Fast then
  MaskD(RW[pTurn].Map^,MapSize,not Cardinal(fUnit or fHiddenUnit or fStealthUnit
    or fObserved or fSpiedOut or fOwned or fOwnZoCUnit or fInEnemyZoC));
RW[pTurn].nEnemyUn:=0;

MirBuilt:=false;
if (Difficulty[pTurn]>0) and (GWinner=0) then with RW[pTurn] do
  begin
  if nCity>0 then for p1:=0 to nPl-1 do
    if GTurn=EvaStart[p1]+PeaceEvaTurns then
      begin // peace contract -- remove all units from p1's territory
      Loc1:=City[0].Loc; // search destination for homeless units
      for cix:=1 to nCity-1 do
        if (City[cix].Loc>=0) and ((Loc1<0) or (City[cix].Built[imPalace]>0)) then
          Loc1:=City[cix].Loc;
      for uix:=0 to nUn-1 do with Un[uix] do
        if (Loc>=0) and (Model[mix].Kind<>mkDiplomat)
          and ((Home>=0) or (Loc1>=0))
          and (RealMap[Loc] shr 27=Cardinal(p1)) then
          begin
          OldLoc:=Loc;
          if Master>=0 then
            begin // transport unload
            if Model[mix].Domain=dAir then dec(Un[Master].AirLoad)
            else dec(Un[Master].TroopLoad);
            Master:=-1;
            end
          else FreeUnit(pTurn,uix);

          if Home>=0 then Loc:=City[Home].Loc
          else Loc:=Loc1;
          PlaceUnit(pTurn,uix);
          UpdateUnitMap(OldLoc);
          UpdateUnitMap(Loc);
          Flags:=Flags or unWithdrawn;
          Happened:=Happened or phPeaceEvacuation;
          end
      end;

  if Mode>=moMovie then
    fillchar(ShowShipChange,sizeof(ShowShipChange),0);
  TribeExtinct:=true;
  nUpdateLoc:=0;
  for cix:=0 to nCity-1 do with City[cix] do if Loc>=0 then
    begin {next turn for all cities - city loop 1}
//    if ServerVersion[pTurn]>=$000EF0 then
//      Flags:=Flags and (chFounded or chCaptured or chProductionSabotaged or chDisorder)
//    else Flags:=Flags and (chCaptured or chProductionSabotaged or chDisorder);
    // check for siege
    SiegedTiles:=0;
    V21_to_Loc(Loc,Radius);
    for V21:=1 to 26 do if Tiles and (1 shl V21) and not (1 shl CityOwnTile)<>0 then
      begin
      Loc1:=Radius[V21];
      assert((Loc1>=0) and (Loc1<MapSize) and (UsedByCity[Loc1]=Loc));
      p1:=RealMap[Loc1] shr 27;
      if (RealMap[Loc1] and fCity<>0)
        or (p1<nPl) and (p1<>pTurn) and (RW[pTurn].Treaty[p1]>=trPeace)
        or (ZoCMap[Loc1]>0) and (Occupant[Loc1]<>pTurn)
        and (Treaty[Occupant[Loc1]]<trPeace) then
        begin
        Tiles:=Tiles and not (1 shl V21);
        UsedByCity[Loc1]:=-1;
        Flags:=Flags or chSiege;
        inc(SiegedTiles);
        end;
      end;
    while SiegedTiles>0 do // replace sieged tiles
      begin
      if not AddBestCityTile(pTurn,cix) then break;
      dec(SiegedTiles);
      end;

    if Flags and chFounded=0 then
      begin
//      CollectCityResources(pTurn,cix); // old style

      if CityTurn(pTurn,cix) then
        TribeExtinct:=false
      else
        begin // city is erased
        RemoveDomainUnits(dSea,pTurn,Loc);
        RemoveDomainUnits(dAir,pTurn,Loc);
        Map[Loc]:=Map[Loc] and not fCity; // !!! do this in inner core
        UpdateLoc[nUpdateLoc]:=Loc;
        inc(nUpdateLoc);
        DestroyCity_TellPlayers(pTurn,cix,true);
        end;

      if (Flags and chProduction<>0) and (Project0 and cpImp<>0) then
        begin
        if Project0 and cpIndex=woMir then // MIR completed
          MirBuilt:=true
        else if Project0 and cpIndex=woManhattan then
          GColdWarStart:=GTurn
        else if Imp[Project0 and cpIndex].Kind=ikShipPart then {ship parts produced}
          inc(ShowShipChange.Ship1Change[Project0 and cpIndex-imShipComp]);
        end
      end
    end;{city loop 1}
  if nUpdateLoc>0 then
    begin
    CheckBorders(-1,pTurn);
    for i:=0 to nUpdateLoc-1 do UpdateUnitMap(UpdateLoc[i],true);
    if Mode>=moMovie then
      for p1:=0 to nPl-1 do
        if (1 shl p1 and GWatching<>0) and (p1<>pTurn) then
          for i:=0 to nUpdateLoc-1 do
            if ObserveLevel[UpdateLoc[i]] shr (2*p1) and 3>=lObserveUnhidden then
              CallPlayer(cShowCityChanged,p1,UpdateLoc[i]);
    end;

  for uix:=0 to nUn-1 do with Un[uix] do if Loc>=0 then
    begin // unit loop 2
    if Health<100 then Recover(pTurn,uix);

    if Flags and unMountainDelay<>0 then
      begin
      Movement:=0;
      Flags:=Flags and not unMountainDelay
      end
    else Movement:=UnitSpeed(pTurn,mix,Health); {refresh movement}

    assert(Loc>=0);
    if Model[mix].Kind<>mkDiplomat then
      begin // check treaty violation
      p1:=RealMap[Loc] shr 27;
      if (p1<nPl) and (p1<>pTurn) and (Treaty[p1]>=trPeace) then
        begin
        if (Job in [jCity,jPillage,jClear,jAfforest,jTrans])
          or (Job in [jIrr,jMine,jFort,jBase]) and (RealMap[Loc] and fTerImp<>0) then
          Job:=jNone;
        if (GTurn>EvaStart[p1]+PeaceEvaTurns) and (Treaty[p1]<>trAlliance) then
          begin
          EvaStart[p1]:=GTurn;
          Happened:=Happened or phPeaceViolation;
          if Mode>=moMovie then
            CallPlayer(cShowPeaceViolation,p1,pTurn);
          end;
        end;
      end;

    if ServerVersion[pTurn]>=$000EF0 then
      begin
      if (Health<=0) or TribeExtinct then RemoveUnit_UpdateMap(pTurn,uix);
      end
    end;

  if ServerVersion[pTurn]<$000EF0 then
    for uix:=0 to nUn-1 do with Un[uix] do if Loc>=0 then
      begin // unit loop 3
      Loc1:=Loc;
      Job0:=Job;
      if Job<>jNone then JobDone:=Work(pTurn,uix);
        {settlers do terrain improvement jobs}
      if (Health<=0) or TribeExtinct then RemoveUnit_UpdateMap(pTurn,uix);

      if (Job0=jCity) and JobDone then // new city
        begin
        AddBestCityTile(pTurn,RW[pTurn].nCity-1);
        UpdateUnitMap(Loc1,true);
        if Mode>=moMovie then // tell enemies
          for p1:=0 to nPl-1 do
            if (1 shl p1 and GWatching<>0) and (p1<>pTurn)
              and (ObserveLevel[Loc1] and (3 shl (2*p1))>0) then
                CallPlayer(cShowCityChanged,p1,Loc1);
        end
      end;

  {pollution - city loop 3}
  for cix:=0 to nCity-1 do with City[cix] do
    if (Loc>=0) and (Pollution>=MaxPollution) then
      Pollute(pTurn,cix);

  CompactLists(pTurn);
  if (nUn=0) and (nCity=0) then
    begin // nation made extinct
    Happened:=Happened or phExtinct;
    GAlive:=GAlive and not (1 shl pTurn);
    Stat[stPop,pTurn,GTurn]:=0;
    Stat[stMil,pTurn,GTurn]:=0;
    Stat[stScience,pTurn,GTurn]:=0;
    Stat[stExplore,pTurn,GTurn]:=0;
    Stat[stTerritory,pTurn,GTurn]:=0;
    Stat[stWork,pTurn,GTurn]:=0;
    for p1:=0 to nPl-1 do if 1 shl p1 and (GAlive or GWatching)<>0 then
      begin
      if p1<>pTurn then
        begin
        GiveCivilReport(p1, pTurn);
        if (GTestFlags and tfUncover<>0) or (Difficulty[p1]=0)
          or (RW[p1].Treaty[pTurn]=trAlliance) then
          GiveMilReport(p1, pTurn);
        end;
      with RW[p1] do
        begin
        Alive:=GAlive;
        for Loc1:=0 to MapSize-1 do
          if Territory[Loc1]=pTurn then // remove territory of extinct nation from player maps
            begin
            Territory[Loc1]:=-1;
            Map[Loc1]:=Map[Loc1] and not fPeace
            end
        end;
      end;
    exit
    end;

  // check research
  Cost:=TechCost(pTurn);
  if GTestFlags and tfImmAdvance<>0 then Research:=Cost;
  if (Happened and phTech=0) and (Research>=Cost) then
    begin
    if ResearchTech=adMilitary then EnableDevModel(pTurn) {new Unit class initiated}
    else if ResearchTech>=0 then
      DiscoverTech(pTurn,ResearchTech);

    dec(Research,Cost);
    Happened:=Happened or phTech;
    ResearchTech:=-1
    end
  else if (ResearchTech=-2) and (nCity>0) then
    begin
    Happened:=Happened or phTech;
    ResearchTech:=-1
    end;

  if Credibility<MaxCredibility then
    for p1:=0 to nPl-1 do
      if (p1<>pTurn) and (1 shl p1 and GAlive<>0)
        and (Treaty[p1]>=trPeace) then
        begin inc(Credibility); Break end;

  if GWinner=0 then CheckWin(pTurn);
  if (Mode>=moMovie) and (GWinner=0) and ((ShowShipChange.Ship1Change[0]>0)
    or (ShowShipChange.Ship1Change[1]>0) or (ShowShipChange.Ship1Change[2]>0)) then
    begin
    ShowShipChange.Reason:=scrProduction;
    ShowShipChange.Ship1Owner:=pTurn;
    ShowShipChange.Ship2Owner:=-1;
    for p1:=0 to nPl-1 do
      if (p1<>pTurn) and (1 shl p1 and (GAlive or GWatching)<>0) then
        begin
        move(GShip,RW[p1].Ship,SizeOf(GShip));
        if 1 shl p1 and GWatching<>0 then
          CallPlayer(cShowShipChange,p1,ShowShipChange);
        end
    end;
  if WinOnAlone and (GAlive and not (1 shl pTurn or 1)=0) then
    GWinner:=1 shl pTurn; // break if only one nation left

  if GTurn=AnarchyStart+AnarchyTurns then
    begin
    AnarchyStart:=-AnarchyTurns-1;
    Government:=gDespotism;
    for p1:=0 to nPl-1 do if (p1<>pTurn) and ((GAlive or GWatching) and (1 shl p1)<>0) then
      RW[p1].EnemyReport[pTurn].Government:=gDespotism;
    inc(Happened,phChangeGov)
    end;
  end; // if Difficulty[pTurn]>0

if (pTurn=0) and (GWinner>0) then
  begin // game over, give world map and all reports to player 0
  DiscoverAll(pTurn,lObserveSuper);
  for p1:=1 to nPl-1 do if 1 shl p1 and GAlive<>0 then
    begin
    if RW[pTurn].Treaty[p1]<trNone then
      begin
      RW[pTurn].Treaty[p1]:=trNone;
      RW[p1].Treaty[pTurn]:=trNone;
      end;
    GiveCivilReport(pTurn,p1);
    GiveMilReport(pTurn,p1);
    end;
  end
else
  begin
  // show observed areas
  if (GTestFlags and tfUncover<>0) or (Difficulty[pTurn]=0) then {supervisor - all tiles visible}
    begin
    if (bix[pTurn]<>bixNoTerm)
      and ((Difficulty[pTurn]>0) or (Mode>moLoading_Fast)) then
      DiscoverAll(pTurn,lObserveSuper)
    end
  else
    begin
    DiscoverViewAreas(pTurn);
    if MirBuilt then
      DiscoverAll(pTurn,lObserveUnhidden)
    end
  end;
//CheckContact;
end; {BeforeTurn}

procedure AfterTurn;
var
cix,uix,p1,Loc1,Job0: integer;
JobDone: boolean;
begin
with RW[pTurn] do
  begin
  for cix:=0 to nCity-1 do if City[cix].Loc>=0 then
    begin
//    City[cix].Flags:=City[cix].Flags and not chProductionSabotaged;
    City[cix].Flags:=City[cix].Flags and (chCaptured or chDisorder);
    CollectCityResources(pTurn,cix); // new style
    end;

  inc(Money,OracleIncome);
  OracleIncome:=0;
  if GWonder[woOracle].EffectiveOwner=pTurn then
    begin
    for p1:=0 to nPl-1 do
      if (1 shl p1 and GAlive<>0)
        and ((p1=pTurn) or (RW[pTurn].Treaty[p1]>trNoContact)) then
        for cix:=0 to RW[p1].nCity-1 do
          if (RW[p1].City[cix].Loc>=0) and (RW[p1].City[cix].Built[imTemple]>0) then
            inc(OracleIncome);
    end;

  if (GTestFlags and tfImmImprove=0) and (Government<>gAnarchy) then
    for cix:=0 to nCity-1 do
      if (City[cix].Loc>=0) and (City[cix].Flags and chCaptured=0) then
        PayCityMaintenance(pTurn,cix);

  if ServerVersion[pTurn]>=$000EF0 then
    begin // let settlers work
    for cix:=0 to nCity-1 do
      City[cix].Flags:=City[cix].Flags and not chFounded;
    for uix:=0 to nUn-1 do with Un[uix] do if Loc>=0 then
      begin
      Loc1:=Loc;
      Job0:=Job;
      if Job<>jNone then JobDone:=Work(pTurn,uix);
        {settlers do terrain improvement jobs}
      if Health<=0 then RemoveUnit_UpdateMap(pTurn,uix);

      if (Job0=jCity) and JobDone then // new city
        begin
        AddBestCityTile(pTurn,RW[pTurn].nCity-1);
        UpdateUnitMap(Loc1,true);
        if Mode>=moMovie then // tell enemies
          for p1:=0 to nPl-1 do
            if (1 shl p1 and GWatching<>0) and (p1<>pTurn)
              and (ObserveLevel[Loc1] and (3 shl (2*p1))>0) then
                CallPlayer(cShowCityChanged,p1,Loc1);
        end
      end;
    end;

  for uix:=0 to nUn-1 do with Un[uix] do if Loc>=0 then
    begin {next turn for all units}
    if Model[mix].Domain=dAir then
      if (Master>=0) or (RealMap[Loc] and fCity<>0)
        or (RealMap[Loc] and fTerImp=tiBase) then
        begin
        Fuel:=Model[mix].Cap[mcFuel];
        Flags:=Flags or unBombsLoaded
        end
      else if Model[mix].Kind=mkSpecial_Glider then {glider}
        begin
        if RealMap[Loc] and fTerrain<fGrass then
          begin
          RemoveUnit_UpdateMap(pTurn,uix); // unit lost
          Happened:=Happened or phGliderLost
          end
        end
      else
        begin
        dec(Fuel);
        if Fuel<0 then
          begin
          RemoveUnit_UpdateMap(pTurn,uix); // unit lost
          Happened:=Happened or phPlaneLost
          end
        end
    else if (Master<0) and (Movement>0) then // check HostileDamage
      begin
      Health:=Health-HostileDamage(pTurn,mix,Loc,Movement);
      if Health<0 then RemoveUnit_UpdateMap(pTurn,uix);
      end
    end; {unit loop 1}

  for uix:=0 to nUn-1 do with Un[uix] do
    begin
    Flags:=Flags and not unWithdrawn;
    if (Loc>=0) and (Model[mix].Domain=dGround) and (Master<0)
      and ((integer(Movement)=Model[mix].Speed)
      or (Model[mix].Cap[mcAcademy]>0) and (Movement*2>=Model[mix].Speed)) then
      Flags:=Flags or unFortified; // fortify unmoved units
    end;

  if (GTestFlags and tfUncover=0) and (Difficulty[pTurn]>0) then
    begin // restrict view area to current positions
    MaskD(ObserveLevel,MapSize,not Cardinal(3 shl (2*pTurn)));
    if Mode>moLoading_Fast then
      MaskD(RW[pTurn].Map^,MapSize,not Cardinal(fUnit or fHiddenUnit or fStealthUnit
        or fObserved or fSpiedOut or fOwned or fOwnZoCUnit or fInEnemyZoC));
    RW[pTurn].nEnemyUn:=0;
    DiscoverViewAreas(pTurn);
    end;

  if GWinner=0 then
    for p1:=0 to nPl-1 do if 1 shl p1 and GAlive<>0 then
      CheckWin(p1);
  end;
end; //Afterturn

procedure NextPlayer;
begin
if GTurn=0 then BeforeTurn0
else BeforeTurn;
NoLogCityTileChanges;
GenerateStat(pTurn);
Inform(pTurn);
ChangeClient;
end;

function ExecuteMove(p,uix,ToLoc: integer;
  var MoveInfo: TMoveInfo; ShowMove: TShowMove): integer;
var
i,p1,FromLoc,uix1,nUpdateLoc: integer;
MinLevel, MissionResult: Cardinal;
PModel: ^TModel;
UpdateLoc: array[0..numax-1] of integer;
SeeFrom,SeeTo,ExtDiscover: boolean;
begin
result:=0;
with RW[p],Un[uix] do
  begin
  PModel:=@Model[mix];
  FromLoc:=Loc;

  if Master<0 then
    FreeUnit(p,uix);
  if (MoveInfo.MoveType in [mtMove,mtCapture]) and MoveInfo.MountainDelay then
    begin Flags:=Flags or unMountainDelay; end;
  Loc:=-2;
  if TroopLoad+AirLoad>0 then
    for i:=0 to nUn-1 do
      if (Un[i].Loc>=0) and (Un[i].Master=uix) then
        Un[i].Loc:=-2;
  UpdateUnitMap(FromLoc);

  if Mode>=moMovie then {show move in interface modules}
    begin
    ShowMove.EndHealth:=MoveInfo.EndHealth;
    ShowMove.EndHealthDef:=-1;
    if Master>=0 then
      if Model[Un[Master].mix].Domain=dAir then
        ShowMove.Flags:=ShowMove.Flags or umPlaneUnloading
      else ShowMove.Flags:=ShowMove.Flags or umShipUnloading;
    if MoveInfo.ToMaster>=0 then
      if Model[Un[MoveInfo.ToMaster].mix].Domain=dAir then
        ShowMove.Flags:=ShowMove.Flags or umPlaneLoading
      else ShowMove.Flags:=ShowMove.Flags or umShipLoading;
    for p1:=0 to nPl-1 do
      if (1 shl p1 and GWatching<>0)
        and ((p1<>p) or (bix[p1]=bixTerm)) then
        begin
        if PModel.Cap[mcStealth]>0 then MinLevel:=lObserveSuper
        else if PModel.Cap[mcSub]>0 then MinLevel:=lObserveAll
        else MinLevel:=lObserveUnhidden;
        SeeFrom:= (p1=p) or (ObserveLevel[FromLoc] shr (2*p1) and 3>=MinLevel);
        SeeTo:= (p1=p) or (ObserveLevel[ToLoc] shr (2*p1) and 3>=MinLevel);
        if SeeFrom and SeeTo then
          begin
          TellAboutModel(p1,p,mix);
          if p1=p then ShowMove.emix:=-1
          else ShowMove.emix:=emixSafe(p1,p,mix);
          if MoveInfo.MoveType=mtCapture then CallPlayer(cShowCapturing,p1,ShowMove)
          else CallPlayer(cShowMoving,p1,ShowMove);
          end
        else if SeeFrom then
          CallPlayer(cShowUnitChanged,p1,FromLoc);
        end;
    end;

  if MoveInfo.MoveType<>mtSpyMission then
    Loc:=ToLoc;
  if TroopLoad+AirLoad>0 then
    for i:=0 to nUn-1 do
      if Un[i].Loc=-2 then Un[i].Loc:=ToLoc;

  ExtDiscover:=false;
  nUpdateLoc:=0;
  if MoveInfo.MoveType=mtCapture then
    begin
    assert(Occupant[ToLoc]<0);
    for uix1:=0 to RW[MoveInfo.Defender].nUn-1 do with RW[MoveInfo.Defender].Un[uix1] do
      if (Loc>=0) and (Home=MoveInfo.Dcix) then
        begin UpdateLoc[nUpdateLoc]:=Loc; inc(nUpdateLoc) end;
        // unit will be removed -- remember position and update for all players

    if (RW[MoveInfo.Defender].City[MoveInfo.Dcix].Size>2) and (nCity<ncmax) then
      begin // city captured
      ChangeCityOwner_TellPlayers(MoveInfo.Defender,MoveInfo.Dcix,p);
      City[nCity-1].Flags:=CaptureTurns shl 16;
      CityShrink(p,nCity-1);
      if Mode=moPlaying then with RW[p].City[nCity-1] do
        begin
//        SavedResourceWeights[nCity-1]:=ResourceWeights;
        SavedTiles[nCity-1]:=Tiles;
        end;
      ExtDiscover:=true;

      // Temple of Zeus effect
      if GWonder[woZeus].EffectiveOwner=p then
        begin
        GiveCivilReport(p,MoveInfo.Defender);
        for i:=0 to nAdv-1 do
          if not (i in FutureTech) and (RW[p].Tech[i]<tsSeen)
            and (RW[MoveInfo.Defender].Tech[i]>=tsApplicable) then
            begin
            Happened:=Happened or phStealTech;
            GStealFrom:=MoveInfo.Defender;
            Break
            end
        end;
      if Mode=moPlaying then LogCheckBorders(p,nCity-1,MoveInfo.Defender);
      {$IFOPT O-}if Mode<moPlaying then InvalidTreatyMap:=not(1 shl p);{$ENDIF}
        // territory should not be considered for the rest of the command
        // execution, because during loading a game it's incorrect before
        // subsequent sIntExpandTerritory is processed
      end
    else // city destroyed
      begin
      DestroyCity_TellPlayers(MoveInfo.Defender,MoveInfo.Dcix,false);
      CheckBorders(ToLoc,MoveInfo.Defender);
      end;
    RecalcPeaceMap(p);
    if Mode>=moMovie then
      move(GWonder,Wonder,SizeOf(GWonder));
    end; {if MoveInfo.MoveType=mtCapture}

  if MoveInfo.MoveType=mtSpyMission then
    begin
    MissionResult:=DoSpyMission(p,MoveInfo.Defender,MoveInfo.Dcix,SpyMission);
    if (Mode=moPlaying) and (SpyMission=smStealForeignReports) then
      CallPlayer(cShowMissionResult,p,MissionResult);
    end;

  Health:=MoveInfo.EndHealth;
  dec(Movement,MoveInfo.Cost);
  // transport unload
  if Master>=0 then
    begin
    if PModel.Domain=dAir then dec(Un[Master].AirLoad)
    else
      begin
      dec(Un[Master].TroopLoad);
      assert(Movement<=0);
      end;
    Master:=-1;
    end;

  if (Health<=0) or (MoveInfo.MoveType=mtSpyMission) then
    RemoveUnit(p,uix) // spy mission or victim of HostileDamage
  else
    begin // transport load
    Master:=MoveInfo.ToMaster;
    if MoveInfo.ToMaster>=0 then
      begin
      if PModel.Domain=dAir then inc(Un[MoveInfo.ToMaster].AirLoad)
      else inc(Un[MoveInfo.ToMaster].TroopLoad);
      end
    else PlaceUnit(p,uix);
    end;

  if (MoveInfo.MoveType=mtCapture) and (nUpdateLoc>0) then
    RecalcMapZoC(p);
  UpdateUnitMap(ToLoc,MoveInfo.MoveType=mtCapture);
  for i:=0 to nUpdateLoc-1 do UpdateUnitMap(UpdateLoc[i]);
    // tell about lost units of defender

  if (MoveInfo.MoveType<>mtSpyMission) and (Master<0) then
    begin
    if (PModel.Kind=mkDiplomat) or (PModel.Domain=dAir)
      or (PModel.Cap[mcRadar]+PModel.Cap[mcCarrier]+PModel.Cap[mcAcademy]>0)
      or (RealMap[ToLoc] and fTerrain=fMountains)
      or (RealMap[ToLoc] and fTerImp=tiFort)
      or (RealMap[ToLoc] and fTerImp=tiBase) then
      ExtDiscover:=true;
    if (PModel.Kind=mkDiplomat) or (PModel.Cap[mcSpy]>0) then
      i:=lObserveSuper
    else if (PModel.Domain=dAir)
      or (PModel.Cap[mcRadar]+PModel.Cap[mcCarrier]>0) then
      i:=lObserveAll
    else i:=lObserveUnhidden;
    if ExtDiscover then
      begin
      if Discover21(ToLoc,p,i,true, PModel.Domain=dGround) then
        result:=result or rEnemySpotted;
      end
    else
      begin
      if Discover9(ToLoc,p,i,true, PModel.Domain=dGround) then
        result:=result or rEnemySpotted;
      end;
    end;

  if Mode>=moMovie then {show after-move in interface modules}
    for p1:=0 to nPl-1 do
      if (1 shl p1 and GWatching<>0)
        and ((p1<>p) or (bix[p1]=bixTerm)) then
        begin
        if PModel.Cap[mcStealth]>0 then MinLevel:=lObserveSuper
        else if PModel.Cap[mcSub]>0 then MinLevel:=lObserveAll
        else MinLevel:=lObserveUnhidden;
        SeeFrom:= (p1=p) or (ObserveLevel[FromLoc] shr (2*p1) and 3>=MinLevel);
        SeeTo:= (p1=p) or (ObserveLevel[ToLoc] shr (2*p1) and 3>=MinLevel);
        if SeeTo and (MoveInfo.MoveType=mtCapture) then
          CallPlayer(cShowCityChanged,p1,ToLoc);
        if SeeFrom and SeeTo then
          CallPlayer(cShowAfterMove,p1,ToLoc)
        else if (MoveInfo.MoveType<>mtSpyMission) and SeeTo then
          CallPlayer(cShowUnitChanged,p1,ToLoc);
        for i:=0 to nUpdateLoc-1 do
          if ObserveLevel[UpdateLoc[i]] shr (2*p1) and 3>=lObserveUnhidden then
            CallPlayer(cShowUnitChanged,p1,UpdateLoc[i]);
        end;
  end;
end; // ExecuteMove

function ExecuteAttack(p,uix,ToLoc: integer;
  var MoveInfo: TMoveInfo; ShowMove: TShowMove): integer;

  procedure WriteBattleHistory(ToLoc, FromLoc, Attacker, Defender,
    mixAttacker, mixDefender: integer; AttackerLost, DefenderLost: boolean);
  var
  AttackerBattle, DefenderBattle: ^TBattle;
  begin
  with RW[Attacker] do
    begin
    if nBattleHistory=0 then
      ReallocMem(BattleHistory, 16*SizeOf(TBattle))
    else if (nBattleHistory>=16)
      and (nBattleHistory and (nBattleHistory-1)=0) then
      ReallocMem(BattleHistory, nBattleHistory*(2*SizeOf(TBattle)));
    AttackerBattle:=@BattleHistory[nBattleHistory];
    inc(nBattleHistory);
    end;
  with RW[Defender] do
    begin
    if nBattleHistory=0 then
      ReallocMem(BattleHistory, 16*SizeOf(TBattle))
    else if (nBattleHistory>=16)
      and (nBattleHistory and (nBattleHistory-1)=0) then
      ReallocMem(BattleHistory, nBattleHistory*(2*SizeOf(TBattle)));
    DefenderBattle:=@BattleHistory[nBattleHistory];
    inc(nBattleHistory);
    end;
  AttackerBattle.Enemy:=Defender;
  AttackerBattle.Flags:=0;
  AttackerBattle.Turn:=GTurn;
  AttackerBattle.mix:=mixAttacker;
  AttackerBattle.mixEnemy:=mixDefender;
  AttackerBattle.ToLoc:=ToLoc;
  AttackerBattle.FromLoc:=FromLoc;
  DefenderBattle.Enemy:=Attacker;
  DefenderBattle.Flags:=bhEnemyAttack;
  DefenderBattle.Turn:=GTurn;
  DefenderBattle.mix:=mixDefender;
  DefenderBattle.mixEnemy:=mixAttacker;
  DefenderBattle.ToLoc:=ToLoc;
  DefenderBattle.FromLoc:=FromLoc;
  if AttackerLost then
    begin
    AttackerBattle.Flags:=AttackerBattle.Flags or bhMyUnitLost;
    DefenderBattle.Flags:=DefenderBattle.Flags or bhEnemyUnitLost;
    end;
  if DefenderLost then
    begin
    AttackerBattle.Flags:=AttackerBattle.Flags or bhEnemyUnitLost;
    DefenderBattle.Flags:=DefenderBattle.Flags or bhMyUnitLost;
    end;
  end;

var
i,p1,FromLoc,uix1,nUpdateLoc,ExpGain, ExpelToLoc,cix1: integer;
PModel: ^TModel;
UpdateLoc: array[0..numax-1] of integer;
LoseCityPop,CityDestroyed,SeeFrom,SeeTo,ZoCDefenderDestroyed: boolean;
begin
result:=0;
with RW[p].Un[uix] do
  begin
  PModel:=@RW[p].Model[mix];
  FromLoc:=Loc;

  ShowMove.EndHealth:=MoveInfo.EndHealth;
  ShowMove.EndHealthDef:=MoveInfo.EndHealthDef;
  if MoveInfo.MoveType=mtAttack then
    WriteBattleHistory(ToLoc, FromLoc, p, MoveInfo.Defender, mix,
      RW[MoveInfo.Defender].Un[MoveInfo.Duix].mix,
      MoveInfo.EndHealth<=0, MoveInfo.EndHealthDef<=0);

{  if RW[p].Treaty[MoveInfo.Defender]=trCeaseFire then
    begin
    if Mode>=moMovie then
      CallPlayer(cShowCancelTreaty,MoveInfo.Defender,p);
    CancelTreaty(p,MoveInfo.Defender)
    end;}
  if Mode>=moMovie then {show attack in interface modules}
    for p1:=0 to nPl-1 do
      if (1 shl p1 and GWatching<>0)
        and ((p1<>p) or (bix[p1]=bixTerm)) then
        begin
        SeeFrom:= ObserveLevel[FromLoc] shr (2*p1) and 3>=lObserveUnhidden;
        SeeTo:= ObserveLevel[ToLoc] shr (2*p1) and 3>=lObserveUnhidden;
        if SeeFrom and SeeTo then
          begin
          TellAboutModel(p1,p,mix);
          if p1=p then ShowMove.emix:=-1
          else ShowMove.emix:=emixSafe(p1,p,mix);
          CallPlayer(cShowAttacking,p1,ShowMove);
          end;
        end;

  LoseCityPop:=false;
  if (RealMap[ToLoc] and fCity<>0) and
    ((MoveInfo.MoveType=mtAttack) and (MoveInfo.EndHealthDef<=0)
    or (MoveInfo.MoveType=mtBombard) and (BombardmentDestroysCity or (RW[MoveInfo.Defender].City[MoveInfo.Dcix].Size>2))) then
    case PModel.Domain of
      dGround: LoseCityPop:= (PModel.Cap[mcArtillery]>0)
        or (RW[MoveInfo.Defender].City[MoveInfo.Dcix].Built[imWalls]=0)
        and (Continent[ToLoc]<>GrWallContinent[MoveInfo.Defender]);
      dSea: LoseCityPop:= RW[MoveInfo.Defender].City[MoveInfo.Dcix].Built[imCoastalFort]=0;
      dAir: LoseCityPop:= RW[MoveInfo.Defender].City[MoveInfo.Dcix].Built[imMissileBat]=0;
      end;
  CityDestroyed:=LoseCityPop and (RW[MoveInfo.Defender].City[MoveInfo.Dcix].Size<=2);

  if MoveInfo.MoveType=mtBombard then
    begin
    assert(Movement>=100);
    if PModel.Attack=0 then Flags:=Flags and not unBombsLoaded;
    dec(Movement,100)
    end
  else if MoveInfo.MoveType=mtExpel then
    begin
    assert(Movement>=100);
    Job:=jNone;
    Flags:=Flags and not unFortified;
    dec(Movement,100)
    end
  else
    begin
    assert(MoveInfo.MoveType=mtAttack);
    if MoveInfo.EndHealth=0 then
      RemoveUnit(p,uix,MoveInfo.Defender) // destroy attacker
    else
      begin // update attacker
      ExpGain:=(Health-MoveInfo.EndHealth+1) shr 1;
      if Exp+ExpGain>(nExp-1)*ExpCost then Exp:=(nExp-1)*ExpCost
      else inc(Exp,ExpGain);
      Health:=MoveInfo.EndHealth;
      Job:=jNone;
      if RW[MoveInfo.Defender].Model[RW[MoveInfo.Defender].Un[MoveInfo.Duix].mix].Domain<dAir then
        Flags:=Flags and not unBombsLoaded;
      Flags:=Flags and not unFortified;
      if Movement>100 then dec(Movement,100)
      else Movement:=0;
      end;
    end;

  ZoCDefenderDestroyed:=false;
  nUpdateLoc:=0;
  if MoveInfo.MoveType=mtExpel then with RW[MoveInfo.Defender],Un[MoveInfo.Duix] do
    begin // expel friendly unit
    if Home>=0 then ExpelToLoc:=City[Home].Loc
    else
      begin
      ExpelToLoc:=City[0].Loc; // search destination for homeless units
      for cix1:=1 to nCity-1 do
        if (City[cix1].Loc>=0) and ((ExpelToLoc<0) or (City[cix1].Built[imPalace]>0)) then
          ExpelToLoc:=City[cix1].Loc;
      end;
    if ExpelToLoc>=0 then
      begin
      FreeUnit(MoveInfo.Defender,MoveInfo.Duix);
      Loc:=ExpelToLoc;
      PlaceUnit(MoveInfo.Defender,MoveInfo.Duix);
      UpdateLoc[nUpdateLoc]:=Loc;
      inc(nUpdateLoc);
      Flags:=Flags or unWithdrawn;
      end
    end
  else if (MoveInfo.MoveType=mtAttack) and (MoveInfo.EndHealthDef>0) then
    with RW[MoveInfo.Defender].Un[MoveInfo.Duix] do
      begin // update defender
      ExpGain:=(Health-MoveInfo.EndHealthDef+1) shr 1;
      if Exp+ExpGain>(nExp-1)*ExpCost then Exp:=(nExp-1)*ExpCost
      else inc(Exp,ExpGain);
      Health:=MoveInfo.EndHealthDef;
      end
  else
    begin // destroy defenders
    if MoveInfo.MoveType<>mtBombard then
      begin
      ZoCDefenderDestroyed:=RW[MoveInfo.Defender].Model[RW[MoveInfo.Defender].Un[MoveInfo.Duix].mix].Flags and mdZOC<>0;
      if ((RealMap[ToLoc] and fCity=0)
        and (RealMap[ToLoc] and fTerImp<>tiBase)
        and (RealMap[ToLoc] and fTerImp<>tiFort))
        or LoseCityPop and (RW[MoveInfo.Defender].City[MoveInfo.Dcix].Size=2) then
        RemoveAllUnits(MoveInfo.Defender,ToLoc,p) {no city, base or fortress}
      else RemoveUnit(MoveInfo.Defender,MoveInfo.Duix,p);
      end;

    if LoseCityPop then // city defender defeated -- shrink city
      if not CityDestroyed then
        CityShrink(MoveInfo.Defender,MoveInfo.Dcix)
      else
        begin
        for uix1:=0 to RW[MoveInfo.Defender].nUn-1 do with RW[MoveInfo.Defender].Un[uix1] do
          if (Loc>=0) and (Home=MoveInfo.Dcix) then
            begin UpdateLoc[nUpdateLoc]:=Loc; inc(nUpdateLoc) end;
            // unit will be removed -- remember position and update for all players
        DestroyCity_TellPlayers(MoveInfo.Defender,MoveInfo.Dcix,false);
        CheckBorders(ToLoc,MoveInfo.Defender);
        RecalcPeaceMap(p);
        end;
    end;

  if CityDestroyed and (nUpdateLoc>0) then
    RecalcMapZoC(p)
  else if ZoCDefenderDestroyed then
    RecalcV8ZoC(p,ToLoc);
  UpdateUnitMap(FromLoc);
  UpdateUnitMap(ToLoc,LoseCityPop);
  for i:=0 to nUpdateLoc-1 do UpdateUnitMap(UpdateLoc[i]);
    // tell about lost units of defender

  if Mode>=moMovie then
    begin
    for i:=0 to RW[p].nEnemyModel-1 do with RW[p].EnemyModel[i] do
      Lost:=Destroyed[p,Owner,mix];
    for p1:=0 to nPl-1 do {show after-attack in interface modules}
      if (1 shl p1 and GWatching<>0)
        and ((p1<>p) or (bix[p1]=bixTerm)) then
        begin
        SeeFrom:= ObserveLevel[FromLoc] shr (2*p1) and 3>=lObserveUnhidden;
        SeeTo:= ObserveLevel[ToLoc] shr (2*p1) and 3>=lObserveUnhidden;
        if SeeTo and CityDestroyed then
          CallPlayer(cShowCityChanged,p1,ToLoc); // city was destroyed
        if SeeFrom and SeeTo then
          begin
          CallPlayer(cShowAfterAttack,p1,ToLoc);
          CallPlayer(cShowAfterAttack,p1,FromLoc);
          end
        else
          begin
          if SeeTo then
            CallPlayer(cShowUnitChanged,p1,ToLoc);
          if SeeFrom then
            CallPlayer(cShowUnitChanged,p1,FromLoc);
          end;
        if SeeTo and (MoveInfo.MoveType=mtExpel) and (ExpelToLoc>=0) then
          CallPlayer(cShowUnitChanged,p1,ExpelToLoc);
        end;
    end
  end
end; // ExecuteAttack

function MoveUnit(p,uix,dx,dy: integer; TestOnly: boolean): integer;
var
ToLoc: integer;
MoveInfo: TMoveInfo;
ShowMove: TShowMove;
begin
{$IFOPT O-}assert(1 shl p and InvalidTreatyMap=0);{$ENDIF}
with RW[p].Un[uix] do
  begin
  ToLoc:=dLoc(Loc,dx,dy);
  if (ToLoc<0) or (ToLoc>=MapSize) then
    begin result:=eInvalid; exit end;
  result:=CalculateMove(p,uix,ToLoc,3-dy and 1,TestOnly,MoveInfo);
  if result=eZOC_EnemySpotted then
    ZOCTile:=ToLoc;
  if (result>=rExecuted) and not TestOnly then
    begin
    ShowMove.dx:=dx;
    ShowMove.dy:=dy;
    ShowMove.FromLoc:=Loc;
    ShowMove.mix:=mix;
    ShowMove.Health:=Health;
    ShowMove.Fuel:=Fuel;
    ShowMove.Exp:=Exp;
    ShowMove.Load:=TroopLoad+AirLoad;
    ShowMove.Owner:=p;
    if (TroopLoad>0) or (AirLoad>0) then
      ShowMove.Flags:=unMulti
    else ShowMove.Flags:=0;
    case MoveInfo.MoveType of
      mtCapture: ShowMove.Flags:=ShowMove.Flags or umCapturing;
      mtSpyMission: ShowMove.Flags:=ShowMove.Flags or umSpyMission;
      mtBombard: ShowMove.Flags:=ShowMove.Flags or umBombarding;
      mtExpel: ShowMove.Flags:=ShowMove.Flags or umExpelling;
      end;
    case MoveInfo.MoveType of
      mtMove,mtCapture,mtSpyMission:
        result:=ExecuteMove(p,uix,ToLoc,MoveInfo,ShowMove) or result;
      mtAttack,mtBombard,mtExpel:
        result:=ExecuteAttack(p,uix,ToLoc,MoveInfo,ShowMove) or result
      end;
    end
  end; // with
end; {MoveUnit}

function Server(Command,Player,Subject:integer;var Data): integer; stdcall;

  function CountPrice(const Offer: TOffer; PriceType: integer): integer;
  var
  i: integer;
  begin
  result:=0;
  for i:=0 to Offer.nDeliver+Offer.nCost-1 do
    if Offer.Price[i] and $FFFF0000=Cardinal(PriceType) then inc(result);
  end;

{  procedure UpdateBorderHelper;
  var
  x, y, Loc, Loc1, dx, dy, ObserveMask: integer;
  begin
  ObserveMask:=3 shl (2*pTurn);
  for x:=0 to lx-1 do for y:=0 to ly shr 1-1 do
    begin
    Loc:=lx*(y*2)+x;
    if ObserveLevel[Loc] and ObserveMask<>0 then
      begin
      for dy:=0 to 1 do for dx:=0 to 1 do
        begin
        Loc1:=(Loc+dx-1+lx) mod lx +lx*((y+dy)*2-1);
        if (Loc1>=0) and (Loc1<MapSize)
          and (ObserveLevel[Loc1] and ObserveMask<>0) then
          if RealMap[Loc1] and $78000000=RealMap[Loc] and $78000000 then
            begin
            RW[pTurn].BorderHelper[Loc]:=RW[pTurn].BorderHelper[Loc] and not (1 shl (dy*2+dx));
            RW[pTurn].BorderHelper[Loc1]:=RW[pTurn].BorderHelper[Loc1] and not (8 shr (dy*2+dx))
            end
          else
            begin
            RW[pTurn].BorderHelper[Loc]:=RW[pTurn].BorderHelper[Loc] or (1 shl (dy*2+dx));
            RW[pTurn].BorderHelper[Loc1]:=RW[pTurn].BorderHelper[Loc1] or (8 shr (dy*2+dx));
            end
        end
      end
    end
  end;}

const
ptSelect=0; ptTrGoods=1; ptUn=2; ptCaravan=3; ptImp=4; ptWonder=6;
ptShip=7; ptInvalid=8;

  function ProjectType(Project: integer): integer;
  begin
  if Project and cpCompleted<>0 then result:=ptSelect
  else if Project and (cpImp+cpIndex)=cpImp+imTrGoods then result:=ptTrGoods
  else if Project and cpImp=0 then
    if RW[Player].Model[Project and cpIndex].Kind=mkCaravan then result:=ptCaravan
    else result:=ptUn
  else if Project and cpIndex>=nImp then result:=ptInvalid
  else if Imp[Project and cpIndex].Kind=ikWonder then result:=ptWonder
  else if Imp[Project and cpIndex].Kind=ikShipPart then result:=ptShip
  else result:=ptImp
  end;

const
Dirx: array[0..7] of integer=(1,2,1,0,-1,-2,-1,0);
Diry: array[0..7] of integer=(-1,0,1,2,1,0,-1,-2);

var
d,i,j,p1,p2,pt0,pt1,uix1,cix1,Loc0,Loc1,dx,dy,NewCap,MinCap,MaxCap,
  CapWeight,Cost,NextProd,Preq,TotalFood,TotalProd,CheckSum,StopTurn,
  FutureMCost,NewProject,OldImp,mix,V8,V21,AStr,DStr,ABaseDamage,DBaseDamage: integer;
CityReport,AltCityReport:TCityReport;
FormerCLState: TCmdListState;
EndTime: int64;
Adjacent: TVicinity8Loc;
Radius: TVicinity21Loc;
ShowShipChange: TShowShipChange;
ShowNegoData: TShowNegoData;
logged,ok,HasShipChanged,AllHumansDead,OfferFullySupported:boolean;

begin {>>>server}
if Command=sTurn then
  begin
  p2:=-1;
  for p1:=0 to nPl-1 do if (p1<>Player) and (1 shl p1 and GWatching<>0) then
    CallPlayer(cShowTurnChange,p1,p2);
  end;

assert(MapSize=lx*ly);
assert(Command and (sctMask or sExecute)<>sctInternal or sExecute); // not for internal commands
if (Command<0) or (Command>=$10000) then
  begin result:=eUnknown; exit end;

if (Player<0) or (Player>=nPl)
  or ((Command and (sctMask or sExecute)<>sctInfo)
    and ((Subject<0) or (Subject>=$1000))) then
  begin result:=eInvalid; exit end;

if (1 shl Player and (GAlive or GWatching)=0) and
  not ((Command=sTurn) or (Command=sBreak) or (Command=sResign)
  or (Command=sGetAIInfo) or (Command=sGetAICredits) or (Command=sGetVersion)
  or (Command and $FF0F=sGetChart)) then
  begin
  PutMessage(1 shl 16+1, Format('NOT Alive: %d',[Player]));
  result:=eNoTurn;
  exit
  end;

result:=eOK;

// check if command allowed now
if (Mode=moPlaying)
  and not ((Command>=cClientEx) or (Command=sMessage) or (Command=sSetDebugMap)
  or (Command=sGetDebugMap)
  or (Command=sGetAIInfo) or (Command=sGetAICredits) or (Command=sGetVersion)
  or (Command=sGetTechCost) or (Command=sGetDefender)
  or (Command=sGetUnitReport)
  or (Command=sGetCityReport) or (Command=sGetCityTileInfo)
  or (Command=sGetCity) or (Command=sGetEnemyCityReport)
  or (Command=sGetEnemyCityAreaInfo) or (Command=sGetCityReportNew)
  or (Command and $FF0F=sGetChart) or (Command and $FF0F=sSetAttitude))
    // commands always allowed
  and not ((Player=pTurn) and (Command<$1000))
    // info request always allowed for pTurn
  and ((pDipActive<0) and (Player<>pTurn) // not his turn
  or (pDipActive>=0) and (Player<>pDipActive) // not active in negotiation mode
  or (pDipActive>=0) and (Command and sctMask<>sctEndClient)) then // no nego command
  begin
  PutMessage(1 shl 16+1, Format('No Turn: %d calls %x',
    [Player,Command shr 4]));
  result:=eNoTurn;
  exit
  end;

// do not use EXIT hereafter!

{$IFOPT O-}
HandoverStack[nHandoverStack]:=Player+$1000;
HandoverStack[nHandoverStack+1]:=Command;
inc(nHandoverStack,2);

InvalidTreatyMap:=0; // new command, sIntExpandTerritory of previous command was processed
{$ENDIF}

if (Mode=moPlaying) and (Command>=sExecute)
  and ((Command and sctMask<>sctEndClient) or (Command=sTurn))
  and (Command and sctMask<>sctModel) and (Command<>sCancelTreaty)
  and (Command<>sSetCityTiles) and (Command<>sBuyCityProject)
  and ((Command<cClientEx) or ProcessClientData[Player]) then
  begin {log command}
  FormerCLState:=CL.State;
  CL.Put(Command, Player, Subject, @Data);
  logged:=true;
  end
else logged:=false;

case Command of

{
                        Info Request Commands
 ____________________________________________________________________
}
  sMessage:
    Brain[bix[0]].Client(cDebugMessage,Subject,Data);

  sSetDebugMap:
    DebugMap[Player]:=@Data;

  sGetDebugMap:
    pointer(Data):=DebugMap[Subject];

  {sChangeSuperView:
    if Difficulty[Player]=0 then
      begin
      for i:=0 to nBrain-1 do if Brain[i].Initialized then
        CallClient(i, cShowSuperView, Subject)
      end
    else result:=eInvalid;}

  sRefreshDebugMap:
    Brain[bix[0]].Client(cRefreshDebugMap,-1,Player);

  sGetChart..sGetChart+(nStat-1) shl 4:
    if (Subject>=0) and (Subject<nPl) and (bix[Subject]>=0) then
      begin
      StopTurn:=0;
      if (Difficulty[Player]=0) or (GTestFlags and tfUncover<>0) // supervisor
        or (Subject=Player)  // own chart
        or (GWinner>0) // game end chart
        or (1 shl Subject and GAlive=0) then // chart of extinct nation
        if Subject>Player then StopTurn:=GTurn
        else StopTurn:=GTurn+1
      else if RW[Player].Treaty[Subject]>trNoContact then
        if Command shr 4 and $f=stMil then
          StopTurn:=RW[Player].EnemyReport[Subject].TurnOfMilReport+1
        else StopTurn:=RW[Player].EnemyReport[Subject].TurnOfCivilReport+1;
      move(Stat[Command shr 4 and $f, Subject]^, Data, StopTurn*SizeOf(integer));
      FillChar(TChart(Data)[StopTurn],(GTurn-StopTurn)*SizeOf(integer),0);
      end
    else result:=eInvalid;

  sGetTechCost:
    integer(Data):=TechCost(Player);

  sGetAIInfo:
    if AIInfo[Subject]='' then pchar(Data):=nil
    else pchar(Data):=@AIInfo[Subject][1];

  sGetAICredits:
    if AICredits='' then pchar(Data):=nil
    else pchar(Data):=@AICredits[1];

  sGetVersion:
    integer(Data):=Version;

  sGetGameChanged:
    if Player<>0 then result:=eInvalid
    else if (CL<>nil) and (CL.state.nLog=nLogOpened) and (CL.state.MoveCode=0)
      and not HasCityTileChanges and not HasChanges(Player) then
      result:=eNotChanged;

  sGetTileInfo:
    if (Subject>=0) and (Subject<MapSize) then
      result:=GetTileInfo(Player,-2,Subject,TTileInfo(Data))
    else result:=eInvalid;

  sGetCityTileInfo:
    if (Subject>=0) and (Subject<MapSize) then
      result:=GetTileInfo(Player,-1,Subject,TTileInfo(Data))
    else result:=eInvalid;

  sGetHypoCityTileInfo:
    if (Subject>=0) and (Subject<MapSize) then
      begin
      if (TTileInfo(Data).ExplCity<0) or (TTileInfo(Data).ExplCity>=RW[Player].nCity) then
        result:=eInvalid
      else if ObserveLevel[Subject] shr (Player*2) and 3=0 then
        result:=eNoPreq
      else result:=GetTileInfo(Player,TTileInfo(Data).ExplCity,Subject,TTileInfo(Data))
      end
    else result:=eInvalid;

  sGetJobProgress:
    if (Subject>=0) and (Subject<MapSize) then
      begin
      if ObserveLevel[Subject] shr (Player*2) and 3=0 then
        result:=eNoPreq
      else result:=GetJobProgress(Player,Subject,TJobProgressData(Data))
      end
    else result:=eInvalid;

  sGetModels:
    if (GTestFlags and tfUncover<>0) or (Difficulty[Player]=0) then {supervisor only command}
      begin
      for p1:=0 to nPl-1 do if (p1<>Player) and (1 shl p1 and GAlive<>0) then
        for mix:=0 to RW[p1].nModel-1 do
          TellAboutModel(Player,p1,mix);
      end
    else result:=eInvalid;

  sGetUnits:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] shr (Player*2) and 3=lObserveSuper) then
      integer(Data):=GetUnitStack(Player,Subject)
    else result:=eNoPreq;

  sGetDefender:
    if (Subject>=0) and (Subject<MapSize) and (Occupant[Subject]=Player) then
      Strongest(Subject,integer(Data),d,i,j)
    else result:=eInvalid;

  sGetBattleForecast,sGetBattleForecastEx:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] and (3 shl (Player*2))>0) then
      with TBattleForecast(Data) do
        if (1 shl pAtt and GAlive<>0)
          and (mixAtt>=0) and (mixAtt<RW[pAtt].nModel)
          and ((pAtt=Player) or (RWemix[Player,pAtt,mixAtt]>=0)) then
          begin
          result:=GetBattleForecast(Subject,TBattleForecast(Data),uix1,cix1,
            AStr,DStr,ABaseDamage,DBaseDamage);
          if Command=sGetBattleForecastEx then
            begin
            TBattleForecastEx(Data).AStr:=(AStr+200) div 400;
            TBattleForecastEx(Data).DStr:=(DStr+200) div 400;
            TBattleForecastEx(Data).ABaseDamage:=ABaseDamage;
            TBattleForecastEx(Data).DBaseDamage:=DBaseDamage;
            end;
          if result=eOk then
            result:=eInvalid // no enemy unit there!
          end
        else result:=eInvalid
    else result:=eInvalid;

  sGetUnitReport:
    if (Subject<0) or (Subject>=RW[Player].nUn)
      or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else GetUnitReport(Player, Subject, TUnitReport(Data));

  sGetMoveAdvice:
    if (Subject<0) or (Subject>=RW[Player].nUn)
      or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else result:=GetMoveAdvice(Player,Subject, TMoveAdviceData(Data));

  sGetPlaneReturn:
    if (Subject<0) or (Subject>=RW[Player].nUn)
      or (RW[Player].Un[Subject].Loc<0)
      or (RW[Player].Model[RW[Player].Un[Subject].mix].Domain<>dAir) then
      result:=eInvalid
    else
      begin
      if CanPlaneReturn(Player,Subject, TPlaneReturnData(Data)) then result:=eOK
      else result:=eNoWay
      end;

  sGetCity:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] shr (Player*2) and 3=lObserveSuper)
      and (RealMap[Subject] and fCity<>0) then
      with TGetCityData(Data) do
        begin
        Owner:=Player;
        SearchCity(Subject,Owner,cix1);
        c:=RW[Owner].City[cix1];
        if (Owner<>Player) and (c.Project and cpImp=0) then
          TellAboutModel(Player,Owner,c.Project and cpIndex);
        end
    else result:=eInvalid;

  sGetCityReport:
    if (Subject<0) or (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else result:=GetCityReport(Player,Subject,TCityReport(Data));

  sGetCityReportNew:
    if (Subject<0) or (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else GetCityReportNew(Player,Subject,TCityReportNew(Data));

  sGetCityAreaInfo:
    if (Subject<0) or (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else GetCityAreaInfo(Player, RW[Player].City[Subject].Loc,
      TCityAreaInfo(Data));

  sGetEnemyCityReport:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] shr (Player*2) and 3=lObserveSuper)
      and (RealMap[Subject] and fCity<>0) then
      begin
      p1:=Occupant[Subject];
      if p1<0 then p1:=1;
      SearchCity(Subject,p1,cix1);
      TCityReport(Data).HypoTiles:=-1;
      TCityReport(Data).HypoTax:=-1;
      TCityReport(Data).HypoLux:=-1;
      GetCityReport(p1,cix1,TCityReport(Data))
      end
    else result:=eInvalid;

  sGetEnemyCityReportNew:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] shr (Player*2) and 3=lObserveSuper)
      and (RealMap[Subject] and fCity<>0) then
      begin
      p1:=Occupant[Subject];
      if p1<0 then p1:=1;
      SearchCity(Subject,p1,cix1);
      TCityReport(Data).HypoTiles:=-1;
      TCityReport(Data).HypoTax:=-1;
      TCityReport(Data).HypoLux:=-1;
      GetCityReportNew(p1,cix1,TCityReportNew(Data));
      end
    else result:=eInvalid;

  sGetEnemyCityAreaInfo:
    if (Subject>=0) and (Subject<MapSize)
      and (ObserveLevel[Subject] shr (Player*2) and 3=lObserveSuper)
      and (RealMap[Subject] and fCity<>0) then
      begin
      p1:=Occupant[Subject];
      if p1<0 then p1:=1;
      SearchCity(Subject,p1,cix1);
      GetCityAreaInfo(p1,Subject,TCityAreaInfo(Data))
      end
    else result:=eInvalid;

  sGetCityTileAdvice:
    if (Subject<0) or (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else GetCityTileAdvice(Player, Subject, TCityTileAdviceData(Data));

{
                      Map Editor Commands
 ____________________________________________________________________
}
  sEditTile:
    if Player=0 then with TEditTileData(Data) do EditTile(Loc, NewTile)
    else result:=eInvalid;

  sRandomMap:
    if (Player=0) and MapGeneratorAvailable then
      begin
      CreateElevation;
      PreviewElevation:=false;
      CreateMap(false);
      FillChar(ObserveLevel,MapSize*4,0);
      DiscoverAll(Player,lObserveSuper);
      end
    else result:=eInvalid;

  sMapGeneratorRequest:
    if not MapGeneratorAvailable then result:=eInvalid;

{
                    Client Deactivation Commands
 ____________________________________________________________________
}
  sTurn, sTurn-sExecute:
    begin
    AllHumansDead:=true;
    for p1:=0 to nPl-1 do
      if (1 shl p1 and GAlive<>0) and (bix[p1]=bixTerm) then
        AllHumansDead:=false;
    if (pDipActive>=0) // still in negotiation mode
      or (pTurn=0) and ((GWinner>0) or (GTurn=MaxTurn)
        or (Difficulty[0]>0) and AllHumansDead) then // game end reached
      result:=eViolation
    else if Command>=sExecute then
      begin
      if Mode=moPlaying then
        begin
        CL.State:=FormerCLState;
        LogCityTileChanges;
        {$IFNDEF SCR}
        if pTurn=0 then
          begin LogChanges; SaveGame('~'+LogFileName,true); end
        {$ENDIF}  
        end
      else if (Mode=moMovie) and (pTurn=0) then
        CallPlayer(cMovieEndTurn,0,nil^);
      GWatching:=GWatching and GAlive or 1;
      RW[pTurn].Happened:=0;
      uixSelectedTransport:=-1;
      SpyMission:=smSabotageProd;
      if 1 shl pTurn and GAlive<>0 then
        begin
        // calculate checksum
        TotalFood:=0;
        TotalProd:=0;
        for i:=0 to RW[pTurn].nCity-1 do if RW[pTurn].City[i].Loc>=0 then
          begin
          inc(TotalFood,RW[pTurn].City[i].Food);
          inc(TotalProd,RW[pTurn].City[i].Prod);
          end;
        CheckSum:=TotalFood and 7 + TotalProd and 7 shl 3
          + RW[pTurn].Money and 7 shl 6
          + Worked[pTurn] div 100 and 7 shl 9;
        end
      else CheckSum:=0;

      if Mode<moPlaying then // check checksum
        begin
        if CheckSum<>Subject then
          LoadOK:=false
        end
      else // save checksum
        CL.Put(Command, Player, CheckSum, @Data);
      {$IFDEF TEXTLOG}
        CmdInfo:='';
        if CheckSum and 7<>Subject and 7 then CmdInfo:=Format('***ERROR (Food %d) ',[(CheckSum and 7-Subject and 7+12) mod 8 -4])+CmdInfo;
        if CheckSum shr 3 and 7<>Subject shr 3 and 7 then CmdInfo:='***ERROR (Prod) '+CmdInfo;
        if CheckSum shr 6 and 7<>Subject shr 6 and 7 then CmdInfo:='***ERROR (Research) '+CmdInfo;
        if CheckSum shr 9 and 7<>Subject shr 9 and 7 then CmdInfo:='***ERROR (Work) '+CmdInfo;
      {$ENDIF}

      if 1 shl pTurn and GAlive<>0 then
        begin
        AfterTurn;
        if Mode<moPlaying then
          InsertTerritoryUpdateCommands;
        //if bix[pTurn]=bixTerm then UpdateBorderHelper;
        end;

      repeat
        pTurn:=(pTurn+1) mod nPl;
        if pTurn=0 then inc(GTurn);
        if (bix[pTurn]>=0) and ((1 shl pTurn) and GAlive=0) then
          begin // already made extinct -- continue statistics
          Stat[stExplore,pTurn,GTurn]:=0;
          Stat[stPop,pTurn,GTurn]:=0;
          Stat[stTerritory,pTurn,GTurn]:=0;
          Stat[stScience,pTurn,GTurn]:=0;
          Stat[stWork,pTurn,GTurn]:=0;
          Stat[stMil,pTurn,GTurn]:=0;
          end;
      until (pTurn=0) or ((1 shl pTurn and (GAlive or GWatching)<>0) and (GWinner=0));
      if (Mode=moLoading_Fast) and ((GTurn=LoadTurn) or (GTurn=LoadTurn-1) and (pTurn>0)) then
        Mode:=moLoading;
      if Mode=moPlaying then
        begin
        CCCommand:=cTurn; CCPlayer:=pTurn;
        Notify(ntNextPlayer)
        end
      else
        begin
        if GTurn=0 then BeforeTurn0
        else BeforeTurn;
        if (Mode=moMovie) and (pTurn=0) then
          begin
          Inform(pTurn);
          CallPlayer(cMovieTurn,0,nil^);
          end;
        end;
      {$IFDEF TEXTLOG}CmdInfo:=CmdInfo+Format('---Turn %d P%d---', [GTurn,pTurn]);{$ENDIF}
      end;
    end; // sTurn

  sBreak, sResign, sNextRound, sReload:
    if Mode=moMovie then
      MovieStopped:=true
    else
      begin
      if Command=sReload then
        begin
        ok:= (Difficulty[0]=0) and (bix[0]<>bixNoTerm)
          and (integer(Data)>=0) and (integer(Data)<GTurn);
        for p1:=1 to nPl-1 do if bix[p1]=bixTerm then ok:=false;
          // allow reload in AI-only games only
        end
      else ok:= Player=0;
      if ok then
        begin
        if (Command=sBreak) or (Command=sResign) then Notify(ntBackOn);
        for i:=0 to nBrain-1 do if Brain[i].Initialized then
          begin
          if i>=bixFirstAI then
            Notify(ntDeinitModule+i);
          CallClient(i, cBreakGame, nil^);
          end;
        Notify(ntEndInfo);
        if (Command=sBreak) or (Command=sReload) then
          begin
          LogCityTileChanges;
          LogChanges;
          SaveGame(LogFileName,false);
          end;
        DeleteFile(SavePath+'~'+LogFileName);
        EndGame;
        case Command of
          sBreak: Notify(ntStartGoRefresh);
          sResign: Notify(ntStartGo);
          sNextRound: StartNewGame(SavePath, LogFileName, MapFileName, lx, ly, LandMass,
            MaxTurn);
          sReload: LoadGame(SavePath,LogFileName,integer(Data),false);
          end
        end
      else result:=eInvalid;
      end;

  sAbandonMap, sSaveMap:
    if Player=0 then
      begin
      if Command=sSaveMap then SaveMap(MapFileName);
      Notify(ntBackOn);
      Brain[bixTerm].Client(cBreakGame,-1,nil^);
      ReleaseMapEditor;
      if Command=sSaveMap then Notify(ntStartGoRefreshMaps)
      else Notify(ntStartGo)
      end
    else result:=eInvalid;

  scContact..scContact+(nPl-1) shl 4,
  scContact-sExecute..scContact-sExecute+(nPl-1) shl 4:
    if (pDipActive>=0) or (1 shl (Command shr 4 and $f) and GAlive=0) then
      result:=eInvalid
    else if GWinner>0 then result:=eViolation // game end reached
    else if RW[Player].Treaty[Command shr 4 and $f]=trNoContact then
      result:=eNoPreq
    else if GTurn<GColdWarStart+ColdWarTurns then result:=eColdWar
    else if RW[Player].Government=gAnarchy then
      result:=eAnarchy
    else if RW[Command shr 4 and $f].Government=gAnarchy then
      begin
      result:=eAnarchy;
      LastEndClientCommand:=scReject; //enable cancel treaty
      pContacted:=Command shr 4 and $f;
      end
    else if Command>=sExecute then
      begin // contact request
      pContacted:=Command shr 4 and $f;
      pDipActive:=pContacted;
      assert(Mode=moPlaying);
      Inform(pDipActive);
      ChangeClientWhenDone(scContact,pDipActive,pTurn,4);
      end;

  scReject, scReject-sExecute:
    if LastEndClientCommand and $FF0F=scContact then
      begin
      if Command>=sExecute then
        begin // contact requested and not accepted yet
        pDipActive:=-1;
        assert(Mode=moPlaying);
        ChangeClientWhenDone(cContinue,pTurn,nil^,0);
        end
      end
    else result:=eInvalid;

  scDipStart, scDipStart-sExecute:
    if LastEndClientCommand and $FF0F=scContact then
      begin
      if Command>=sExecute then
        begin // accept contact
        pContacted:=pDipActive;
        RW[pContacted].EnemyReport[pTurn].Credibility:=RW[pTurn].Credibility;
        pDipActive:=pTurn;
        assert(Mode=moPlaying);
        IntServer(sIntHaveContact,pTurn,pContacted,nil^);
        ChangeClientWhenDone(scDipStart,pDipActive,nil^,0);
        end
      end
    else result:=eInvalid;

  scDipNotice, scDipAccept, scDipCancelTreaty, scDipBreak,
  scDipNotice-sExecute, scDipAccept-sExecute, scDipCancelTreaty-sExecute,
  scDipBreak-sExecute:
    if pDipActive>=0 then
      begin
      assert(Mode=moPlaying);
      if pDipActive=pTurn then p1:=pContacted
      else p1:=pTurn;
      if (Command and not sExecute=scDipBreak and not sExecute)
        and (LastEndClientCommand<>scDipBreak) then // ok
      else if (Command and not sExecute=scDipNotice and not sExecute)
        and ((LastEndClientCommand=scDipCancelTreaty)
        or (LastEndClientCommand=scDipBreak)) then // ok
      else if (Command and not sExecute=scDipAccept and not sExecute)
        and (LastEndClientCommand=scDipOffer) then with LastOffer do
        begin
        // check if offer can be accepted
        if nDeliver+nCost=0 then result:=eOfferNotAcceptable;
        for i:=0 to nDeliver+nCost-1 do
          if Price[i]=opChoose then result:=eOfferNotAcceptable;
        for i:=0 to nCost-1 do
          if not PayPrice(pDipActive,p1,Price[nDeliver+i],false) then
            result:=eOfferNotAcceptable;
        if (Command>=sExecute) and (result>=rExecuted) then
          begin
          IntServer(sIntPayPrices+nDeliver+nCost,p1,pDipActive,LastOffer);
//          CheckContact;

          // tell other players about ship part trades
          HasShipChanged:=false;
          fillchar(ShowShipChange,sizeof(ShowShipChange),0);
          for i:=0 to nDeliver+nCost-1 do
            if Price[i] and opMask=opShipParts then
              begin
              HasShipChanged:=true;
              if i>=nDeliver then
                begin // p1 has demanded from pDipActive
                ShowShipChange.Ship1Change[Price[i] shr 16 and 3]:=+integer(Price[i] and $FFFF);
                ShowShipChange.Ship2Change[Price[i] shr 16 and 3]:=-integer(Price[i] and $FFFF);
                end
              else
                begin // p1 has delivered to pDipActive
                ShowShipChange.Ship1Change[Price[i] shr 16 and 3]:=-integer(Price[i] and $FFFF);
                ShowShipChange.Ship2Change[Price[i] shr 16 and 3]:=+integer(Price[i] and $FFFF);
                end
              end;
          if HasShipChanged then
            begin
            ShowShipChange.Reason:=scrTrade;
            ShowShipChange.Ship1Owner:=p1;
            ShowShipChange.Ship2Owner:=pDipActive;
            for p2:=0 to nPl-1 do
              if (p2<>p1) and (p2<>pDipActive) and (1 shl p2 and (GAlive or GWatching)<>0) then
                begin
                move(GShip,RW[p2].Ship,SizeOf(GShip));
                if 1 shl p2 and GWatching<>0 then
                  CallPlayer(cShowShipChange,p2,ShowShipChange);
                end
            end
          end;
        end
      else if (Command and not sExecute=scDipCancelTreaty and not sExecute)
        and (RW[pDipActive].Treaty[p1]>=trPeace) then
        begin
        if (ServerVersion[pDipActive]>=$010100)
          and (GTurn<RW[pDipActive].LastCancelTreaty[p1]+CancelTreatyTurns) then
          result:=eCancelTreatyRush
        else if Command>=sExecute then
          begin
          IntServer(sIntCancelTreaty,pDipActive,p1,nil^);
          for p2:=0 to nPl-1 do
            if (p2<>p1) and (1 shl p2 and PeaceEnded<>0) then
              begin
              i:=p1 shl 4+pDipActive;
              CallPlayer(cShowSupportAllianceAgainst,p2,i);
              end;
          for p2:=0 to nPl-1 do
            if (p2<>p1) and (1 shl p2 and PeaceEnded<>0) then
              begin
              i:=p2;
              CallPlayer(cShowCancelTreatyByAlliance,pDipActive,i);
              end;
          end
        end
      else result:=eInvalid;
      if (Command>=sExecute) and (result>=rExecuted) then
        if LastEndClientCommand=scDipBreak then
          begin // break negotiation
          pDipActive:=-1;
          CallPlayer(cShowEndContact,pContacted,nil^);
          ChangeClientWhenDone(cContinue,pTurn,nil^,0);
          end
        else
          begin
          if (GTestFlags and tfUncover<>0) or (Difficulty[0]=0) then
            with ShowNegoData do
              begin // display negotiation in log window
              pSender:=pDipActive;
              pTarget:=p1;
              Action:=Command;
              Brain[bix[0]].Client(cShowNego,1 shl 16+3,ShowNegoData);
              end;
          pDipActive:=p1;
          ChangeClientWhenDone(Command,pDipActive,nil^,0);
          end
      end
    else result:=eInvalid;

  scDipOffer, scDipOffer-sExecute:
    if (pDipActive>=0) and (LastEndClientCommand<>scDipCancelTreaty)
      and (LastEndClientCommand<>scDipBreak) then
      if (LastEndClientCommand=scDipOffer) and (LastOffer.nDeliver+LastOffer.nCost
        +TOffer(Data).nDeliver+TOffer(Data).nCost=0) then
        begin
        if Command>=sExecute then
          begin // agreed discussion end
          pDipActive:=-1;
          CallPlayer(cShowEndContact,pContacted,nil^);
          assert(Mode=moPlaying);
          ChangeClientWhenDone(cContinue,pTurn,nil^,0);
          end
        end
      else
        begin
        // check if offer can be made
        if pDipActive=pTurn then p1:=pContacted
        else p1:=pTurn;
        if RW[pDipActive].Treaty[p1]<trPeace then
          begin // no tribute allowed!
          for i:=0 to TOffer(Data).nDeliver+TOffer(Data).nCost-1 do
            if (TOffer(Data).Price[i] and opMask=opTribute) then result:=eInvalidOffer;
          for i:=0 to TOffer(Data).nDeliver+TOffer(Data).nCost-1 do
            if (TOffer(Data).Price[i]=opTreaty+trPeace) then result:=eOK;
          end;
        for i:=0 to TOffer(Data).nDeliver-1 do
          if (TOffer(Data).Price[i]<>opChoose)
            and not PayPrice(pDipActive,p1,TOffer(Data).Price[i],false) then
            result:=eInvalidOffer;
        if CountPrice(TOffer(Data),opTreaty)>1 then
          result:=eInvalidOffer;
        for i:=0 to nShipPart-1 do
          if CountPrice(TOffer(Data),opShipParts+i shl 16)>1 then
            result:=eInvalidOffer;
        if CountPrice(TOffer(Data),opMoney)>1 then
          result:=eInvalidOffer;
        if CountPrice(TOffer(Data),opTribute)>1 then
          result:=eInvalidOffer;
        case CountPrice(TOffer(Data),opChoose) of
          0:;
          1:
            if (TOffer(Data).nCost=0) or (TOffer(Data).nDeliver=0) then
              result:=eInvalidOffer;
          else result:=eInvalidOffer;
          end;

        // !!! check here if cost can be demanded

        if (Command>=sExecute) and (result>=rExecuted) then
          begin
          OfferFullySupported:= (TOffer(Data).nDeliver<=2)
            and (TOffer(Data).nCost<=2); // >2 no more allowed
          for i:=0 to TOffer(Data).nDeliver+TOffer(Data).nCost-1 do
            begin
            if TOffer(Data).Price[i] and opMask=opTribute then
              OfferFullySupported:=false; // tribute no more part of the game
            if (TOffer(Data).Price[i] and opMask=opTreaty)
              and (TOffer(Data).Price[i]-opTreaty<=RW[pDipActive].Treaty[p1]) then
              OfferFullySupported:=false; // agreed treaty end no more part of the game
            if TOffer(Data).Price[i]=opTreaty+trCeaseFire then
              OfferFullySupported:=false; // ceasefire no more part of the game
            end;
          if not OfferFullySupported then
            begin
            // some elements have been removed from the game -
            // automatically respond will null-offer
            LastOffer.nDeliver:=0;
            LastOffer.nCost:=0;
            ChangeClientWhenDone(scDipOffer,pDipActive,LastOffer,SizeOf(LastOffer));
            end
          else
            begin
            if (GTestFlags and tfUncover<>0) or (Difficulty[0]=0) then
              with ShowNegoData do
                begin // display negotiation in log window
                pSender:=pDipActive;
                pTarget:=p1;
                Action:=Command;
                Offer:=TOffer(Data);
                Brain[bix[0]].Client(cShowNego,1 shl 16+3,ShowNegoData);
                end;
            LastOffer:=TOffer(Data);
            // show offered things to receiver
            for i:=0 to LastOffer.nDeliver-1 do
              ShowPrice(pDipActive,p1,LastOffer.Price[i]);
            pDipActive:=p1;
            assert(Mode=moPlaying);
            ChangeClientWhenDone(scDipOffer,pDipActive,LastOffer,SizeOf(LastOffer));
            end
          end
        end
    else result:=eInvalid;

{
                          General Commands
 ____________________________________________________________________
}
  sClearTestFlag:
    if Player=0 then
      begin
      {$IFDEF TEXTLOG}CmdInfo:=Format('ClearTestFlag %x', [Subject]);{$ENDIF}
      ClearTestFlags(Subject);
      end
    else result:=eInvalid;

  sSetTestFlag:
    if Player=0 then
      begin
      {$IFDEF TEXTLOG}CmdInfo:=Format('SetTestFlag %x', [Subject]);{$ENDIF}
      SetTestFlags(Player,Subject);
//      CheckContact;
      end
    else result:=eInvalid;

  sSetGovernment, sSetGovernment-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetGovernment P%d: %d', [Player,Subject]);{$ENDIF}
    if RW[Player].Happened and phChangeGov=0 then result:=eViolation
    else if RW[Player].Government=Subject then result:=eNotChanged
    else if (Subject>=nGov) then result:=eInvalid
    else if (Subject>=gMonarchy)
      and (RW[Player].Tech[GovPreq[Subject]]<tsApplicable) then
      result:=eNoPreq
    else if Command>=sExecute then
      begin
      RW[Player].Government:=Subject;
      for p1:=0 to nPl-1 do if (p1<>Player) and ((GAlive or GWatching) and (1 shl p1)<>0) then
        RW[p1].EnemyReport[Player].Government:=Subject;
      end
    end;

  sSetRates, sSetRates-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetRates P%d: %d/%d', [Player,Subject and $f *10,Subject shr 4 *10]);{$ENDIF}
    if Subject and $f+Subject shr 4>10 then result:=eInvalid
    else if (RW[Player].TaxRate=Subject and $f *10)
      and (RW[Player].LuxRate=Subject shr 4 *10) then
      result:=eNotChanged
    else if Command>=sExecute then
      begin
      RW[Player].TaxRate:=Subject and $f *10;
      RW[Player].LuxRate:=Subject shr 4 *10;
      end
    end;

  sRevolution:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('Revolution P%d', [Player]);{$ENDIF}
    if RW[Player].Government=gAnarchy then result:=eInvalid
    else
      begin
      RW[Player].Government:=gAnarchy;
      for p1:=0 to nPl-1 do if (p1<>Player) and ((GAlive or GWatching) and (1 shl p1)<>0) then
        RW[p1].EnemyReport[Player].Government:=gAnarchy;
      RW[Player].AnarchyStart:=GTurn;
      end;
    end;

  sSetResearch, sSetResearch-sExecute: with RW[Player] do
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetResearch P%d: %d', [Player,Subject]);{$ENDIF}
    if (Happened and phTech<>0)
      and ((Subject<nAdv) or (Subject=adMilitary)) then
      begin
      if (Mode=moPlaying) and (Subject=adMilitary)
        and (DevModelTurn[Player]<>GTurn) then
        result:=eNoModel
      else if Subject<>adMilitary then
        begin
        if Subject=futComputingTechnology then
          begin
          if Tech[Subject]>=MaxFutureTech_Computing then result:=eInvalid
          end
        else if Subject in FutureTech then
          begin
          if Tech[Subject]>=MaxFutureTech then result:=eInvalid
          end
        else if Tech[Subject]>=tsApplicable then
          result:=eInvalid; // already discovered
        if Tech[Subject]<>tsSeen then // look if preqs met
          if AdvPreq[Subject,2]<>preNone then
            begin // 2 of 3 required
            i:=0;
            for j:=0 to 2 do
              if Tech[AdvPreq[Subject,j]]>=tsApplicable then inc(i);
            if i<2 then result:=eNoPreq
            end
          else if (AdvPreq[Subject,0]<>preNone)
            and (Tech[AdvPreq[Subject,0]]<tsApplicable)
            or (AdvPreq[Subject,1]<>preNone)
            and (Tech[AdvPreq[Subject,1]]<tsApplicable) then
            result:=eNoPreq
        end;
      if (result=eOK) and (Command>=sExecute) then
        begin
        if (Mode=moPlaying) and (Subject=adMilitary) then
          IntServer(sIntSetDevModel,Player,0,DevModel.Kind);
          // save DevModel, because sctModel commands are not logged
        ResearchTech:=Subject;
        end
      end
    else result:=eViolation;
    end;

  sStealTech, sStealTech-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('StealTech P%d: %d', [Player,Subject]);{$ENDIF}
    if RW[Player].Happened and phStealTech=0 then result:=eInvalid
    else if (Subject>=nAdv) or (Subject in FutureTech)
      or (RW[Player].Tech[Subject]>=tsSeen)
      or (RW[GStealFrom].Tech[Subject]<tsApplicable) then
      result:=eInvalid
    else if Command>=sExecute then
      begin
      SeeTech(Player,Subject);
      dec(RW[Player].Happened,phStealTech);
      end
    end;

  sSetAttitude..sSetAttitude+(nPl-1) shl 4,
  sSetAttitude-sExecute..sSetAttitude-sExecute+(nPl-1) shl 4:
    begin
    p1:=Command shr 4 and $f;
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetAttitude P%d to P%d: %d', [Player,p1,Subject]);{$ENDIF}
    if (Subject>=nAttitude) or (p1>=nPl)
      or (RW[Player].EnemyReport[p1]=nil) then
      result:=eInvalid
    else if RW[Player].Treaty[p1]=trNoContact then
      result:=eNoPreq
    else if RW[Player].Attitude[p1]=Subject then
      result:=eNotChanged
    else if Command>=sExecute then
      begin
      RW[Player].Attitude[p1]:=Subject;
      RW[p1].EnemyReport[Player].Attitude:=Subject;
      end
    end;

  sCancelTreaty, sCancelTreaty-sExecute:
    if (LastEndClientCommand<>scReject)
      or (RW[Player].Treaty[pContacted]<trPeace) then
      result:=eInvalid
    else if (ServerVersion[Player]>=$010100)
      and (GTurn<RW[Player].LastCancelTreaty[pContacted]+CancelTreatyTurns) then
      result:=eCancelTreatyRush
    else if Command>=sExecute then
      begin
      CallPlayer(cShowCancelTreaty,pContacted,Player);
      IntServer(sIntCancelTreaty,Player,pContacted,nil^);
      for p2:=0 to nPl-1 do
        if (p2<>pContacted) and (1 shl p2 and PeaceEnded<>0) then
          begin
          i:=pContacted shl 4+Player;
          CallPlayer(cShowSupportAllianceAgainst,p2,i);
          end;
      for p2:=0 to nPl-1 do
        if (p2<>pContacted) and (1 shl p2 and PeaceEnded<>0) then
          begin
          i:=p2;
          CallPlayer(cShowCancelTreatyByAlliance,Player,i);
          end;
      LastEndClientCommand:=sTurn;
      end;

{
                       Model Related Commands
 ____________________________________________________________________
}
  sCreateDevModel, sCreateDevModel-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('CreateDevModel P%d', [Player]);{$ENDIF}
    if Subject>=4 then result:=eInvalid
    else if (upgrade[Subject,0].Preq<>preNone)
      and (RW[Player].Tech[upgrade[Subject,0].Preq]<tsApplicable) then
      result:=eNoPreq
    else if Command>=sExecute then
      begin
      with RW[Player].DevModel do
        begin
        Domain:=Subject;
        MStrength:=0; MTrans:=0; MCost:=0; Upgrades:=0;
        FutureMCost:=0;
        for i:=0 to nUpgrade-1 do with upgrade[Domain,i] do
          if (Preq=preNone)
            or (Preq>=0) and ((RW[Player].Tech[Preq]>=tsApplicable)
            or (Preq in FutureTech) and (RW[Player].Tech[Preq]>=0)) then
            begin
            if Preq in FutureTech then
              begin
              j:=RW[Player].Tech[Preq];
              inc(FutureMCost,j*Cost);
              end
            else
              begin
              j:=1;
              if Cost>MCost then MCost:=Cost;
              end;
            inc(Upgrades,1 shl i);
            inc(MStrength,j*Strength);
            inc(MTrans,j*Trans);
            end;
        inc(MCost,FutureMCost);
        FillChar(Cap,SizeOf(Cap),0);
        Cap[mcOffense]:=2;
        Cap[mcDefense]:=1;
        for i:=0 to nFeature-1 do with Feature[i] do
          if (1 shl Domain and Domains<>0) and ((Preq=preNone)
            or (Preq=preSun) and (GWonder[woSun].EffectiveOwner=Player)
            or (Preq>=0) and (RW[Player].Tech[Preq]>=tsApplicable))
            and (i in AutoFeature) then Cap[i]:=1;
        MaxWeight:=5;
        if (WeightPreq7[Domain]<>preNA)
          and (RW[Player].Tech[WeightPreq7[Domain]]>=tsApplicable) then
          MaxWeight:=7;
        if (WeightPreq10[Domain]<>preNA)
          and (RW[Player].Tech[WeightPreq10[Domain]]>=tsApplicable) then
          if Domain=dSea then MaxWeight:=9
          else MaxWeight:=10;
        end;
      CalculateModel(RW[Player].DevModel);
      DevModelTurn[Player]:=GTurn;
      end
    end;

  sSetDevModelCap..sSetDevModelCap+$3F0,
  sSetDevModelCap-sExecute..sSetDevModelCap-sExecute+$3F0:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetDevModelCap P%d', [Player]);{$ENDIF}
    if Subject>=nFeature then result:=eInvalid
    else if DevModelTurn[Player]=GTurn then
      begin
      NewCap:=Command shr 4 and $3F; {new value}
      with RW[Player].DevModel do
        if 1 shl Domain and Feature[Subject].Domains=0 then
          result:=eDomainMismatch
        else if not ((Feature[Subject].Preq=preNone)
          or (Feature[Subject].Preq=preSun)
          and (GWonder[woSun].EffectiveOwner=Player)
          or (Feature[Subject].Preq>=0)
          and (RW[Player].Tech[Feature[Subject].Preq]>=tsApplicable)) then
          result:=eNoPreq
        else
          begin
          if (Subject in AutoFeature) or (Subject=mcDefense) then MinCap:=1
          else MinCap:=0; {MinCap - minimum use of feature}
          if Subject>=mcFirstNonCap then MaxCap:=1
          else if Subject=mcDefense then
            begin
            if Domain=dGround then MaxCap:=2
            else MaxCap:=3;
            if RW[Player].Tech[adSteel]>=tsApplicable then inc(MaxCap)
            end
          else MaxCap:=8; {MaxCap - maximum use of this feature}
          if (Domain=dGround) and (Subject=mcDefense) then CapWeight:=2
          else CapWeight:=Feature[Subject].Weight;
          if (NewCap<MinCap) or (NewCap>MaxCap)
            or (Weight+(NewCap-Cap[Subject])*CapWeight>MaxWeight) then
            result:=eViolation
          else if Command>=sExecute then
            begin
            Cap[Subject]:=NewCap;

            // mutual feature exclusion
            case Subject of
              mcSub:
                begin
                if ServerVersion[Player]>=$010103 then
                  Cap[mcSeaTrans]:=0;
                Cap[mcArtillery]:=0;
                Cap[mcCarrier]:=0;
                if Cap[mcDefense]>2 then Cap[mcDefense]:=2
                end;
              mcSeaTrans:
                begin
                if ServerVersion[Player]>=$010103 then
                  Cap[mcSub]:=0;
                end;
              mcCarrier: Cap[mcSub]:=0;
              mcArtillery: Cap[mcSub]:=0;
              mcAlpine:
                begin Cap[mcOver]:=0; Cap[mcMob]:=0; end;
              mcOver: Cap[mcAlpine]:=0;
              mcMob: begin Cap[mcAlpine]:=0; end;
              end;

            CalculateModel(RW[Player].DevModel);
            end
          end;
      end
    else result:=eNoModel;
    end;

{
                        Unit Related Commands
 ____________________________________________________________________
}
  sRemoveUnit,sRemoveUnit-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('RemoveUnit P%d Mod%d Loc%d', [Player,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else
      begin
      result:=eRemoved;
      Loc0:=RW[Player].Un[Subject].Loc;
      if RealMap[Loc0] and fCity<>0 then {check utilize}
        begin
        SearchCity(Loc0,Player,cix1);
        with RW[Player].City[cix1] do
          begin
          if (RW[Player].Model[RW[Player].Un[Subject].mix].Kind=mkCaravan)
            and ((Project and cpImp=0) or (Imp[Project and cpIndex].Kind<>ikShipPart))
            or (Project and cpImp=0) and (RW[Player].Model[Project
            and cpIndex].Kind<>mkCaravan) then
            result:=eUtilized;
          if Command>=sExecute then
            begin
            if result=eUtilized then
              begin
              with RW[Player].Un[Subject] do
                begin
                Cost:=integer(RW[Player].Model[mix].Cost)*Health
                  *BuildCostMod[Difficulty[Player]] div 1200;
                if RW[Player].Model[mix].Cap[mcLine]>0 then
                  Cost:=Cost div 2;
                end;
              if Project and (cpImp+cpIndex)=cpImp+imTrGoods then
                inc(RW[Player].Money,Cost)
              else
                begin
                inc(Prod,Cost*2 div 3);
                Project0:=Project0 and not cpCompleted;
                if Project0 and not cpAuto<>Project and not cpAuto then
                  Project0:=Project;
                Prod0:=Prod;
                end
              end;
            RemoveUnit_UpdateMap(Player,Subject);
            end;
          end;
        end
      else if Command>=sExecute then
        RemoveUnit_UpdateMap(Player,Subject);
      end
    end;

  sSetUnitHome,sSetUnitHome-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetUnitHome P%d Mod%d Loc%d', [Player,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else
      begin
      Loc0:=RW[Player].Un[Subject].Loc;
      if RealMap[Loc0] and fCity=0 then result:=eInvalid
      else
        begin
        SearchCity(Loc0,Player,cix1);
        if RW[Player].City[cix1].Flags and chCaptured<>0 then
          result:=eViolation
        else if Command>=sExecute then
          RW[Player].Un[Subject].Home:=cix1
        end
      end
    end;

  sSetSpyMission..sSetSpyMission+(nSpyMission-1) shl 4,
    sSetSpyMission-sExecute..sSetSpyMission-sExecute+(nSpyMission-1) shl 4:
    if Command>=sExecute then
      SpyMission:=Command shr 4 and $F;

  sLoadUnit,sLoadUnit-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('LoadUnit P%d Mod%d Loc%d', [Player,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else result:=LoadUnit(Player,Subject,Command<sExecute);
    end;

  sUnloadUnit,sUnloadUnit-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('UnloadUnit P%d Mod%d Loc%d', [Player,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else result:=UnloadUnit(Player,Subject,Command<sExecute)
    end;

  sSelectTransport,sSelectTransport-sExecute:
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else with RW[Player].Model[RW[Player].Un[Subject].mix] do
      begin
      if Cap[mcSeaTrans]+Cap[mcAirTrans]+Cap[mcCarrier]=0 then
        result:=eInvalid
      else if Command>=sExecute then
        uixSelectedTransport:=Subject;
      end;

  sCreateUnit..sCreateUnit+(nPl-1) shl 4,
  sCreateUnit-sExecute..sCreateUnit-sExecute+(nPl-1) shl 4:
    if (GTestFlags and tfUncover<>0) or (Difficulty[Player]=0) then {supervisor only command}
      begin
      p1:=Command shr 4 and $f;
      Loc1:=integer(Data);
      if (Occupant[Loc1]>=0) and (p1<>Occupant[Loc1])
        or (RealMap[Loc1] and fCity<>0) and (RealMap[Loc1] shr 27<>Cardinal(p1))
        or (RW[p1].Model[Subject].Domain<dAir)
        and ((RW[p1].Model[Subject].Domain=dSea)
        <>(RealMap[integer(Data)] and fTerrain<fGrass)) then
        result:=eViolation
      else if Command>=sExecute then
        begin
        CreateUnit(p1,Subject);
        RW[p1].Un[RW[p1].nUn-1].Loc:=integer(Data);
        PlaceUnit(p1,RW[p1].nUn-1);
        UpdateUnitMap(integer(Data));
        end
      end
    else result:=eInvalid;

  sMoveUnit+(0+6*8)*16,sMoveUnit+(1+7*8)*16,
  sMoveUnit+(2+0*8)*16,sMoveUnit+(1+1*8)*16,
  sMoveUnit+(0+2*8)*16,sMoveUnit+(7+1*8)*16,
  sMoveUnit+(6+0*8)*16,sMoveUnit+(7+7*8)*16,
  sMoveUnit-sExecute+(0+6*8)*16,sMoveUnit-sExecute+(1+7*8)*16,
  sMoveUnit-sExecute+(2+0*8)*16,sMoveUnit-sExecute+(1+1*8)*16,
  sMoveUnit-sExecute+(0+2*8)*16,sMoveUnit-sExecute+(7+1*8)*16,
  sMoveUnit-sExecute+(6+0*8)*16,sMoveUnit-sExecute+(7+7*8)*16:
    begin
    dx:=(Command shr 4 +4) and 7-4; dy:=(Command shr 7 +4) and 7-4;
    {$IFDEF TEXTLOG}CmdInfo:=Format('MoveUnit P%d I%d Mod%d Loc%d (%d,%d)', [Player,Subject,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc,dx,dy]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else result:=MoveUnit(Player,Subject,dx,dy,Command<sExecute);
    end;

{
                      Settlers Related Commands
 ____________________________________________________________________
}
  sAddToCity, sAddToCity-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('AddToCity P%d Mod%d Loc%d', [Player,RW[Player].Un[Subject].mix,RW[Player].Un[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (RW[Player].Un[Subject].Loc<0) then
      result:=eInvalid
    else if not (RW[Player].Model[RW[Player].Un[Subject].mix].Kind in [mkSettler,mkSlaves])
      and (RW[Player].Un[Subject].Flags and unConscripts=0) then
      result:=eViolation
    else
      begin
      Loc0:=RW[Player].Un[Subject].Loc;
      if RealMap[Loc0] and fCity=0 then result:=eInvalid
      else
        begin
        SearchCity(Loc0,Player,cix1);
        with RW[Player].City[cix1] do
          if not CanCityGrow(Player,cix1) then
            result:=eMaxSize
          else if Command>=sExecute then
            begin {add to city}
            if Mode=moPlaying then
              SavedTiles[cix1]:=0; // save in every case
            if CanCityGrow(Player,cix1) then
              CityGrowth(Player,cix1);
            if (RW[Player].Model[RW[Player].Un[Subject].mix].Kind=mkSettler)
              and CanCityGrow(Player,cix1) then
              CityGrowth(Player,cix1);
            RemoveUnit_UpdateMap(Player,Subject);
            end
        end
      end
    end;

  sStartJob..sStartJob+$3F0, sStartJob-sExecute..sStartJob+$3F0-sExecute:
    begin
    Loc0:=RW[Player].Un[Subject].Loc;
    i:=Command shr 4 and $3F; // new job
    {$IFDEF TEXTLOG}CmdInfo:=Format('StartJob P%d Mod%d Loc%d: %d', [Player,RW[Player].Un[Subject].mix,Loc0,i]);{$ENDIF}
    if (Subject>=RW[Player].nUn) or (Loc0<0) then
      result:=eInvalid
    else if i>=nJob then result:=eInvalid
    else
      begin
      result:=StartJob(Player,Subject,i,Command<sExecute);
      if result=eCity then
        begin // new city
        cix1:=RW[Player].nCity-1;
        AddBestCityTile(Player,cix1);
        if Mode=moPlaying then with RW[Player].City[cix1] do
          begin
//          SavedResourceWeights[cix1]:=ResourceWeights;
          SavedTiles[cix1]:=0; // save in every case
          end;
        if Mode>=moMovie then {show new city in interface modules}
          for p1:=0 to nPl-1 do
            if (1 shl p1 and GWatching<>0) and (p1<>Player)
              and (ObserveLevel[Loc0] and (3 shl (2*p1))>0) then
                CallPlayer(cShowCityChanged,p1,Loc0);
        end
      end;
    end;

{
                        City Related Commands
 ____________________________________________________________________
}
  sSetCityProject,sSetCityProject-sExecute:
    begin
    NewProject:=integer(Data) and not cpAuto;
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetCityProject P%d Loc%d: %d', [Player,RW[Player].City[Subject].Loc,NewProject]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else with RW[Player].City[Subject] do
      begin
      if NewProject=Project then result:=eNotChanged
      else
        begin
        pt0:=ProjectType(Project0);
        pt1:=ProjectType(NewProject);
        if NewProject and cpImp=0 then
          begin
          if NewProject and cpIndex>=RW[Player].nModel then
            result:=eInvalid
          else if (NewProject and cpConscripts<>0)
            and not ((RW[Player].Tech[adConscription]>=tsApplicable)
            and (RW[Player].Model[NewProject and cpIndex].Domain=dGround)
            and (RW[Player].Model[NewProject and cpIndex].Kind<mkScout)) then
            result:=eViolation
//          else if (RW[Player].Model[NewProject and cpIndex].Kind=mkSlaves)
//            and (GWonder[woPyramids].EffectiveOwner<>Player) then
//            result:=eNoPreq
          end
        else if NewProject and cpIndex>=nImp then
          result:=eInvalid
        else
          begin
          Preq:=Imp[NewProject and cpIndex].Preq;
          for i:=0 to nImpReplacement-1 do
            if (ImpReplacement[i].OldImp=NewProject and cpIndex)
              and (Built[ImpReplacement[i].NewImp]>0) then
              result:=eObsolete;
          if result=eObsolete then
          else if Preq=preNA then result:=eInvalid
          else if (Preq>=0) and (RW[Player].Tech[Preq]<tsApplicable) then
            result:=eNoPreq
          else if Built[NewProject and cpIndex]>0 then result:=eInvalid
          else if (NewProject and cpIndex<28)
            and (GWonder[NewProject and cpIndex].CityID<>-1) then
            result:=eViolation // wonder already exists
          else if (NewProject and cpIndex=imSpacePort)
            and (RW[Player].NatBuilt[imSpacePort]>0) then
            result:=eViolation // space port already exists
          else if (NewProject=cpImp+imBank) and (Built[imMarket]=0)
            or (NewProject=cpImp+imUniversity) and (Built[imLibrary]=0)
            or (NewProject=cpImp+imResLab) and (Built[imUniversity]=0)
            or (NewProject=cpImp+imMfgPlant) and (Built[imFactory]=0) then
            result:=eNoPreq;
          case NewProject-cpImp of
            woLighthouse,woMagellan,imCoastalFort,imHarbor,imPlatform:
              begin {city at ocean?}
              Preq:=0;
              V8_to_Loc(Loc,Adjacent);
              for V8:=0 to 7 do
                begin
                Loc1:=Adjacent[V8];
                if (Loc1>=0) and (Loc1<MapSize)
                  and (RealMap[Loc1] and fTerrain=fShore) then
                  inc(Preq);
                end;
              if Preq=0 then result:=eNoPreq;
              end;
            woHoover,imHydro:
              begin {city at river or mountains?}
              Preq:=0;
              V8_to_Loc(Loc,Adjacent);
              for V8:=0 to 7 do
                begin
                Loc1:=Adjacent[V8];
                if (Loc1>=0) and (Loc1<MapSize)
                  and ((RealMap[Loc1] and fTerrain=fMountains)
                  or (RealMap[Loc1] and fRiver<>0)) then inc(Preq);
                end;
              if Preq=0 then result:=eNoPreq;
              end;
            woMIR,imShipComp,imShipPow,imShipHab:
              if RW[Player].NatBuilt[imSpacePort]=0 then result:=eNoPreq;
            end;
          if (GTestFlags and tfNoRareNeed=0)
            and (Imp[NewProject and cpIndex].Kind=ikShipPart) then
            if RW[Player].Tech[adMassProduction]<tsApplicable then result:=eNoPreq
            else
              begin // check for rare resources
              if NewProject and cpIndex=imShipComp then j:=1
              else if NewProject and cpIndex=imShipPow then j:=2
              else {if NewProject and cpIndex=imShipHab then} j:=3;
                // j = rare resource required
              Preq:=0;
              V21_to_Loc(Loc,Radius);
              for V21:=1 to 26 do
                begin
                Loc1:=Radius[V21];
                if (Loc1>=0) and (Loc1<MapSize)
                  and (RealMap[Loc1] shr 25 and 3=Cardinal(j)) then
                  inc(Preq);
                end;
              if Preq=0 then result:=eNoPreq;
              end
          end;

        if (Command>=sExecute) and (result>=rExecuted) then
          begin
          if pt0<>ptSelect then
            if NewProject and (cpImp or cpIndex)=Project0 and (cpImp or cpIndex) then
              Prod:=Prod0
            else if (pt1=ptTrGoods) or (pt1=ptShip) or (pt1<>pt0) and (pt0<>ptCaravan) then
              begin
              inc(RW[Player].Money,Prod0);
              Prod:=0;
              Prod0:=0;
              Project0:=cpImp+imTrGoods
              end
            else Prod:=Prod0*2 div 3;
          Project:=NewProject
          end
        end
      end
    end;

  sBuyCityProject,sBuyCityProject-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('BuyCityProject P%d Loc%d', [Player,RW[Player].City[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else with RW[Player].City[Subject] do
      if (RW[Player].Government=gAnarchy) or (Flags and chCaptured<>0) then
        result:=eOutOfControl
      else if (Project and cpImp<>0) and ((Project and cpIndex=imTrGoods)
        or (Imp[Project and cpIndex].Kind=ikShipPart)) then
        result:=eInvalid // don't buy colony ship
      else
        begin
        CityReport.HypoTiles:=-1;
        CityReport.HypoTax:=-1;
        CityReport.HypoLux:=-1;
        GetCityReport(Player,Subject,CityReport);
        Cost:=CityReport.ProdCost;
        NextProd:=CityReport.ProdRep-CityReport.Support;
        if (CityReport.Working-CityReport.Happy>Size shr 1) or (NextProd<0) then // !!! change to new style disorder
          NextProd:=0;
        Cost:=Cost-Prod-NextProd;
        if (GWonder[woMich].EffectiveOwner=Player) and (Project and cpImp<>0) then
          Cost:=Cost*2
        else Cost:=Cost*4;
        if Cost<=0 then result:=eNotChanged
        else if Cost>RW[Player].Money then result:=eViolation
        else if Command>=sExecute then
          IntServer(sIntBuyMaterial, Player, Subject, Cost);
            // need to save material/cost because city tiles are not correct
            // when loading
        end;
    end;

  sSellCityProject,sSellCityProject-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SellCityProject P%d Loc%d', [Player,RW[Player].City[Subject].Loc]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else if Command>=sExecute then
      with RW[Player].City[Subject] do
        begin inc(RW[Player].Money,Prod0); Prod:=0; Prod0:=0; end;
    end;

  sSellCityImprovement,sSellCityImprovement-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SellCityImprovement P%d Loc%d: %d', [Player,RW[Player].City[Subject].Loc,integer(Data)]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else with RW[Player].City[Subject] do
      if Built[integer(Data)]=0 then result:=eInvalid
      else if (RW[Player].Government=gAnarchy) or (Flags and chCaptured<>0) then
        result:=eOutOfControl
      else if Flags and chImprovementSold<>0 then result:=eOnlyOnce
      else if Command>=sExecute then
        begin
        inc(RW[Player].Money,
          Imp[integer(Data)].Cost*BuildCostMod[Difficulty[Player]] div 12);
        Built[integer(Data)]:=0;
        if Imp[integer(Data)].Kind in [ikNatLocal,ikNatGlobal] then
          begin
          RW[Player].NatBuilt[integer(Data)]:=0;
          case integer(Data) of
            imGrWall: GrWallContinent[Player]:=-1;
            imSpacePort: DestroySpacePort_TellPlayers(Player,-1);
            end
          end;
        inc(Flags,chImprovementSold);
        end
    end;

  sRebuildCityImprovement,sRebuildCityImprovement-sExecute:
    begin
    OldImp:=integer(Data);
    {$IFDEF TEXTLOG}CmdInfo:=Format('RebuildCityImprovement P%d Loc%d: %d', [Player,RW[Player].City[Subject].Loc,OldImp]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else
      begin
      if (OldImp<0) or (OldImp>=nImp)
        or not (Imp[OldImp].Kind in [ikCommon,ikNatLocal,ikNatGlobal]) then
        result:=eInvalid
      else with RW[Player].City[Subject] do
        if (Built[OldImp]=0) or (Project and cpImp=0)
          or not (Imp[Project and cpIndex].Kind in [ikCommon,ikNatLocal,ikNatGlobal]) then
          result:=eInvalid
        else if (RW[Player].Government=gAnarchy) or (Flags and chCaptured<>0) then
          result:=eOutOfControl
        else if Flags and chImprovementSold<>0 then result:=eOnlyOnce
        else if Command>=sExecute then
          begin
          inc(Prod,Imp[OldImp].Cost
            *BuildCostMod[Difficulty[Player]] div 12 *2 div 3);
          Project0:=Project0 and not cpCompleted;
          if Project0 and not cpAuto<>Project and not cpAuto then
            Project0:=Project;
          Prod0:=Prod;
          Built[OldImp]:=0;
          if Imp[OldImp].Kind in [ikNatLocal,ikNatGlobal] then
            begin // nat. project lost
            RW[Player].NatBuilt[OldImp]:=0;
            case OldImp of
              imGrWall: GrWallContinent[Player]:=-1;
              imSpacePort: DestroySpacePort_TellPlayers(Player,-1);
              end
            end;
          inc(Flags,chImprovementSold);
          end
      end
    end;

  sSetCityTiles, sSetCityTiles-sExecute:
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('SetCityTiles P%d Loc%d: %x', [Player,RW[Player].City[Subject].Loc,integer(data)]);{$ENDIF}
    if (Subject>=RW[Player].nCity) or (RW[Player].City[Subject].Loc<0) then
      result:=eInvalid
    else result:=SetCityTiles(Player, Subject, integer(Data), Command<sExecute);
    end;

{
                      Client Exclusive Commands
 ____________________________________________________________________
}
  else
    if Command>=cClientEx then
      begin
      {$IFDEF TEXTLOG}CmdInfo:=Format('ClientEx%x P%d', [Command,Player]);{$ENDIF}
      if ProcessClientData[Player] or (Mode=moPlaying) then
        CallPlayer(Command,Player,Data)
      end
    else result:=eUnknown;
  end;{case command}

// do not log invalid and non-relevant commands
if result=eZOC_EnemySpotted then
  begin
  assert(Mode=moPlaying);
  CL.State:=FormerCLState;
  IntServer(sIntDiscoverZOC,Player,0,ZOCTile);
  end
else if result and rEffective=0 then
  if Mode<moPlaying then
    begin
    {$IFDEF TEXTLOG}CmdInfo:=Format('***ERROR (%x) ',[result])+CmdInfo;{$ENDIF}
    LoadOK:=false;
    end
  else
    begin
    if logged then CL.State:=FormerCLState;
    if (result<rExecuted) and (Command>=sExecute) then
      PutMessage(1 shl 16+1, Format('INVALID: %d calls %x (%d)',
        [Player,Command,Subject]));
    end;

if (Command and (cClientEx or sExecute or sctMask)=sExecute or sctEndClient)
  and (result>=rExecuted) then LastEndClientCommand:=Command;
{$IFOPT O-}dec(nHandoverStack,2);{$ENDIF}
end;{<<<server}


initialization
QueryPerformanceFrequency(PerfFreq);
FindFirst(ParamStr(0),$21,ExeInfo);

{$IFOPT O-}nHandoverStack:=0;{$ENDIF}

end.

