{$INCLUDE switches.pas}
library AIProject;

uses
Protocol in '..\Protocol\Protocol.pas',
CustomAI,
AI;


var
AIList: array[0..nPl-1] of TCustomAI;
Defender: integer;


procedure Client(Command,Player:integer;var Data); stdcall;
var
p,y0,ToLoc: integer;
UnitInfo: TUnitInfo;
begin
case Command of
  cInitModule:
    begin
    Server:=TInitModuleData(Data).Server;
    TInitModuleData(Data).DataSize:=RWDataSize;
    end;
  cNewGame,cLoadGame:
    begin
{$IFNDEF DEBUG}Randomize;{$ENDIF}
    CustomAI.Init(TNewGameData(Data));
    for p:=nPl-1 downto 0 do
      if G.RO[p]<>nil then
        begin
        AIList[p]:=TAI.Create(p);
        AIList[p].SetDataDefaults;
        end
      else AIList[p]:=nil;
    Defender:=-1;
    end;
  cGetReady:
    for p:=nPl-1 downto 0 do
      if AIList[p]<>nil then AIList[p].SetDataRandom;
  cBreakGame:
    for p:=0 to nPl-1 do
      if AIList[p]<>nil then AIList[p].Free;

  cTurn, cContinue, scContact..scDipBreak, cShowEndContact:
    AIList[Player].Process(Command, Data);

  cShowAttacking, cShowCapturing:
    with TShowMove(Data) do
      begin
      y0:=FromLoc div G.lx;
      ToLoc:=(FromLoc+(dx+y0 and 1+G.lx+G.lx) shr 1) mod G.lx +G.lx*(y0+dy);
      if G.RO[Player].Map[ToLoc] and fOwned<>0 then
        begin
        UnitInfo.Loc:=FromLoc;
        UnitInfo.mix:=mix;
        UnitInfo.emix:=emix;
        UnitInfo.Owner:=Owner;
        UnitInfo.Health:=Health;
        UnitInfo.Fuel:=Fuel;
        UnitInfo.Job:=jNone;
        UnitInfo.Exp:=Exp;
        UnitInfo.Load:=Load;
        UnitInfo.Flags:=Flags;
        if Command=cShowAttacking then
          AIList[Player].OnBeforeEnemyAttack(UnitInfo, ToLoc, EndHealth,
            EndHealthDef)
        else AIList[Player].OnBeforeEnemyCapture(UnitInfo, ToLoc);
        Defender:=Player
        end
      end;
  cShowAfterAttack:
    if Player=Defender then
      begin
      AIList[Player].OnAfterEnemyAttack;
      Defender:=-1;
      end;
  cShowAfterMove:
    if Player=Defender then
      begin
      AIList[Player].OnAfterEnemyCapture;
      Defender:=-1;
      end;

  else {ignore other commands}
  end
end;

exports
Client Name 'client';

end.

