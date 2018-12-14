{$INCLUDE switches}

unit CmdList;

interface

uses
Classes;

const
MaxDataSize=1024;

type
TLogData=array[0..999999999] of Byte;

TCmdListState=record
  nLog, {used size of LogData in bytes}
  LoadPos, {position in LogData when loading a game}
  LastMovingUnit: integer;
  MoveCode, LoadMoveCode: Cardinal;
  end;

TCmdList=class
  constructor Create;
  destructor Destroy; override;
  procedure Get(var Command, Player, Subject: integer; var Data: pointer);
  procedure GetDataChanges(Data: pointer; DataSize: integer);
  procedure Put(Command, Player, Subject: integer; Data: pointer);
  procedure PutDataChanges(Command, Player: integer; OldData, NewData: pointer; DataSize: integer);
  procedure LoadFromFile(const f: TFileStream);
  procedure SaveToFile(const f: TFileStream);
  procedure AppendToFile(const f: TFileStream; const OldState: TCmdListState);
  procedure Cut;
  function Progress: integer;
private
  LogAlloc: integer; {allocated size of LogData in bytes}
  LogData: ^TLogData;
  FState: TCmdListState;
  procedure PutData(Data: pointer; Length: integer);
  procedure CompleteMoveCode;
public
  property State: TCmdListState read FState write FState;
  end;

implementation

uses
Protocol;

const
LogGrow=1 shl 18;

type
TData=array[0..MaxDataSize-1] of Cardinal;
PData=^TData;

constructor TCmdList.Create;
begin
inherited Create;
FState.nLog:=0;
LogAlloc:=0;
LogData:=nil;
FState.LastMovingUnit:=-1;
FState.MoveCode:=0;
FState.LoadMoveCode:=0;
end;

destructor TCmdList.Destroy;
begin
ReallocMem(LogData, 0);
inherited Destroy;
end;

procedure TCmdList.Get(var Command, Player, Subject: integer; var Data: pointer);
var
DirCode, code: Cardinal;
begin
if FState.LoadMoveCode>0 then
  begin
  Player:=-1;
  if FState.LoadMoveCode and 1=1 then
    begin // FM
    DirCode:=FState.LoadMoveCode shr 1 and 7;
    Subject:=FState.LastMovingUnit;
    FState.LoadMoveCode:=FState.LoadMoveCode shr 4;
    end
  else
    begin // M
    DirCode:=FState.LoadMoveCode shr 3 and 7;
    Subject:=FState.LoadMoveCode shr 6 and $FFF;
    FState.LoadMoveCode:=FState.LoadMoveCode shr 18;
    FState.LastMovingUnit:=Subject
    end;
  case DirCode of
    0: Command:=sMoveUnit+$090;
    1: Command:=sMoveUnit+$0F0;
    2: Command:=sMoveUnit+$390;
    3: Command:=sMoveUnit+$3F0;
    4: Command:=sMoveUnit+$020;
    5: Command:=sMoveUnit+$060;
    6: Command:=sMoveUnit+$100;
    7: Command:=sMoveUnit+$300;
    end;
  Data:=nil;
  end
else
  begin
  code:=Cardinal((@LogData[FState.LoadPos])^);
  if code and 3=0 then
    begin // non-clientex command
    Command:=code shr 2 and $3FFF +sExecute;
    Player:=code shr 16 and $f;
    Subject:=code shr 20 and $FFF;
    inc(FState.LoadPos,4);
    end
  else if code and 7=2 then
    begin // clientex command
    Command:=code shr 3 and $FFFF;
    Player:=code shr 19 and $f;
    Subject:=0;
    inc(FState.LoadPos,3);
    end
  else
    begin // move command shortcut
    if (code and 1=1) and (code and (7 shl 4)<>6 shl 4) then
      begin FState.LoadMoveCode:=code and $FF; inc(FState.LoadPos) end
    else begin FState.LoadMoveCode:=code and $FFFFFF; inc(FState.LoadPos,3); end;
    Get(Command, Player, Subject, Data);
    exit;
    end;

  if Command and $f=0 then Data:=nil
  else
    begin
    Data:=@LogData[FState.LoadPos];
    inc(FState.LoadPos,Command and $f *4);
    end
  end
end;

procedure TCmdList.GetDataChanges(Data: pointer; DataSize: integer);
var
b0, b1: integer;
Map0, Map1: Cardinal;
begin
Map0:=Cardinal((@LogData[FState.LoadPos])^);
inc(FState.LoadPos,4);
b0:=0;
while Map0>0 do
  begin
  if Map0 and 1<>0 then
    begin
    Map1:=Cardinal((@LogData[FState.LoadPos])^);
    inc(FState.LoadPos,4);
    for b1:=0 to 31 do if 1 shl b1 and Map1<>0 then
      begin
      if b0*32+b1<DataSize then
        PData(Data)[b0*32+b1]:=Cardinal((@LogData[FState.LoadPos])^);
      inc(FState.LoadPos,4);
      end;
    end;
  inc(b0);
  Map0:=Map0 shr 1;
  end
end;

procedure TCmdList.Put(Command, Player, Subject: integer; Data: pointer);
var
DirCode, code: Cardinal;
begin
if Command and $FC00=sMoveUnit then
  begin // move command shortcut
  case Command of
    sMoveUnit+$090: DirCode:=0;
    sMoveUnit+$0F0: DirCode:=1;
    sMoveUnit+$390: DirCode:=2;
    sMoveUnit+$3F0: DirCode:=3;
    sMoveUnit+$020: DirCode:=4;
    sMoveUnit+$060: DirCode:=5;
    sMoveUnit+$100: DirCode:=6;
    sMoveUnit+$300: DirCode:=7;
    end;
  if Subject=FState.LastMovingUnit then code:=1+DirCode shl 1
  else code:=6+DirCode shl 3+Cardinal(Subject) shl 6;
  if FState.MoveCode=0 then FState.MoveCode:=code
  else if FState.MoveCode and 1=1 then
    begin // FM + this
    FState.MoveCode:=FState.MoveCode+code shl 4;
    if code and 1=1 then PutData(@FState.MoveCode, 1) // FM + FM
    else PutData(@FState.MoveCode, 3); // FM + M
    FState.MoveCode:=0;
    end
  else if code and 1=1 then
    begin // M + FM
    FState.MoveCode:=FState.MoveCode+code shl 18;
    PutData(@FState.MoveCode, 3);
    FState.MoveCode:=0;
    end
  else // M + M
    begin
    PutData(@FState.MoveCode, 3);
    FState.MoveCode:=code
    end;
  FState.LastMovingUnit:=Subject;
  end
else
  begin
  CompleteMoveCode;
  if Command>=cClientEx then
    begin
    code:=2+Command shl 3+Player shl 19;
    PutData(@code, 3);
    end
  else
    begin
    code:=Cardinal(Command-sExecute) shl 2+Cardinal(Player) shl 16
      +Cardinal(Subject) shl 20;
    PutData(@code, 4);
    end;
  end;
if Command and $f<>0 then PutData(Data, Command and $f *4);
end;

procedure TCmdList.PutDataChanges(Command, Player: integer; OldData,
  NewData: pointer; DataSize: integer);
var
MapPos, LogPos, b0, b1, RowEnd: integer;
Map0, Map1, code: Cardinal;
begin
if DataSize<=0 then exit;
if DataSize>MaxDataSize then DataSize:=MaxDataSize;
CompleteMoveCode;
MapPos:=FState.nLog+8;
LogPos:=MapPos+4;
Map0:=0;
for b0:=0 to (DataSize-1) div 32 do
  begin
  if LogPos+4*32>LogAlloc then
    begin
    inc(LogAlloc, LogGrow);
    ReallocMem(LogData, LogAlloc);
    end;
  Map0:=Map0 shr 1;
  Map1:=0;
  RowEnd:=DataSize-1;
  if RowEnd>b0*32+31 then RowEnd:=b0*32+31;
  for b1:=b0*32 to RowEnd do
    begin
    Map1:=Map1 shr 1;
    if PData(NewData)[b1]<>PData(OldData)[b1] then
      begin
      Cardinal((@LogData[LogPos])^):=PData(NewData)[b1];
      inc(LogPos,4);
      inc(Map1,$80000000);
      end;
    end;
  if Map1>0 then
    begin
    Map1:=Map1 shr (b0*32+31-RowEnd);
    Cardinal((@LogData[MapPos])^):=Map1;
    MapPos:=LogPos;
    inc(LogPos,4);
    inc(Map0,$80000000);
    end;
  end;
if Map0=0 then exit; // no changes

Map0:=Map0 shr (31-(DataSize-1) div 32);
Cardinal((@LogData[FState.nLog+4])^):=Map0;
code:=Cardinal(Command-sExecute) shl 2+Cardinal(Player) shl 16;
Cardinal((@LogData[FState.nLog])^):=code;
FState.nLog:=MapPos
end;

procedure TCmdList.PutData(Data: pointer; Length: integer);
begin
if FState.nLog+Length>LogAlloc then
  begin
  inc(LogAlloc, LogGrow);
  ReallocMem(LogData, LogAlloc);
  end;
move(Data^, LogData[FState.nLog], Length);
inc(FState.nLog, Length);
end;

procedure TCmdList.CompleteMoveCode;
begin
if FState.MoveCode>0 then
  begin
  if FState.MoveCode and 1=1 then PutData(@FState.MoveCode, 1) // Single FM
  else PutData(@FState.MoveCode, 3); // Single M
  FState.MoveCode:=0;
  end
end;

procedure TCmdList.LoadFromFile(const f: TFileStream);
begin
f.read(FState.nLog, 4);
LogData:=nil;
LogAlloc:=((FState.nLog+2) div LogGrow +1)*LogGrow;
ReallocMem(LogData, LogAlloc);
f.read(LogData^, FState.nLog);
FState.LoadPos:=0;
end;

procedure TCmdList.SaveToFile(const f: TFileStream);
begin
CompleteMoveCode;
f.write(FState.nLog, 4);
f.write(LogData^, FState.nLog)
end;

procedure TCmdList.AppendToFile(const f: TFileStream; const OldState: TCmdListState);
begin
CompleteMoveCode;
f.write(FState.nLog, 4);
f.Position:=f.Position+OldState.nLog;
f.write(LogData[OldState.nLog], FState.nLog-OldState.nLog)
end;

procedure TCmdList.Cut;
begin
FState.nLog:=FState.LoadPos;
end;

function TCmdList.Progress: integer;
begin
if (FState.LoadPos=FState.nLog) and (FState.LoadMoveCode=0) then
  result:=1000 // loading complete
else if FState.nLog>1 shl 20 then
  result:=(FState.LoadPos shr 8)*999 div (FState.nLog shr 8)
else result:=FState.LoadPos*999 div FState.nLog
end;

{Format Specification:

Non-ClientEx-Command:
  Byte3    Byte2    Byte1    Byte0
  ssssssss sssspppp cccccccc cccccc00
  (c = Command-sExecute, p = Player, s = Subject)

ClientEx-Command:
  Byte2    Byte1    Byte0
  0ppppccc cccccccc ccccc010
  (c = Command, p = Player)

Single Move:
  Byte2    Byte1    Byte0
  000000ss ssssssss ssaaa110
  (a = Direction, s = Subject)

Move + Follow Move:
  Byte2    Byte1    Byte0
  00bbb1ss ssssssss ssaaa110
  (a = Direction 1, s = Subject 1, b = Direction 2)

Follow Move + Move:
  Byte2    Byte1    Byte0
  00ssssss ssssssbb b110aaa1
  (a = Direction 1, b = Direction 2, s = Subject 2)

Single Follow Move:
  Byte0
  0000aaa1
  (a = Direction)

Double Follow Move:
  Byte0
  bbb1aaa1
  (a = Direction 1, b = Direction 2)
}

end.

