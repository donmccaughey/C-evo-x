{$INCLUDE switches}

unit Enhance;

interface

uses
  ScreenTools,BaseWin,Protocol,ClientTools,Term,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ButtonBase, ButtonB, ButtonC, Menus;

type
  TEnhanceDlg = class(TFramedDlg)
    ToggleBtn: TButtonB;
    CloseBtn: TButtonB;
    job1: TButtonC;
    job2: TButtonC;
    job4: TButtonC;
    job5: TButtonC;
    job7: TButtonC;
    job3: TButtonC;
    job6: TButtonC;
    job9: TButtonC;
    Popup: TPopupMenu;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure ToggleBtnClick(Sender: TObject);
    procedure TerrClick(Sender: TObject);
    procedure JobClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  public
    procedure ShowNewContent(NewMode: integer; TerrType: integer = -1);
  protected
    Page: integer;
    procedure OffscreenPaint; override;
  end;

var
  EnhanceDlg: TEnhanceDlg;

implementation

uses Help;

{$R *.DFM}

procedure TEnhanceDlg.FormCreate(Sender: TObject);
var
TerrType: integer;
m: TMenuItem;
begin
inherited;
CaptionRight:=CloseBtn.Left;
CaptionLeft:=ToggleBtn.Left+ToggleBtn.Width;
InitButtons();
HelpContext:='MACRO';
Caption:=Phrases.Lookup('TITLE_ENHANCE');
ToggleBtn.Hint:=Phrases.Lookup('BTN_SELECT');

for TerrType:=fGrass to fMountains do if TerrType<>fJungle then
  begin
  m:=TMenuItem.Create(Popup);
  m.RadioItem:=true;
  if TerrType=fGrass then
    m.Caption:=Format(Phrases.Lookup('TWOTERRAINS'),
      [Phrases.Lookup('TERRAIN',fGrass), Phrases.Lookup('TERRAIN',fGrass+12)])
  else if TerrType=fForest then
    m.Caption:=Format(Phrases.Lookup('TWOTERRAINS'),
      [Phrases.Lookup('TERRAIN',fForest), Phrases.Lookup('TERRAIN',fJungle)])
  else m.Caption:=Phrases.Lookup('TERRAIN',TerrType);
  m.Tag:=TerrType;
  m.OnClick:=TerrClick;
  Popup.Items.Add(m);
  end;
end;

procedure TEnhanceDlg.FormPaint(Sender: TObject);
var
i: integer;
begin
inherited;
BtnFrame(Canvas,Rect(job1.Left,job1.Top,job7.Left+job7.Width,job1.Top+job1.Height),MainTexture);
BtnFrame(Canvas,Rect(job3.Left,job3.Top,job9.Left+job9.Width,job3.Top+job3.Height),MainTexture);
for i:=0 to ControlCount-1 do if Controls[i] is TButtonC then
  BitBlt(Canvas.Handle,Controls[i].Left+2,Controls[i].Top-11,8,8,
    GrExt[HGrSystem].Data.Canvas.Handle,121+Controls[i].Tag mod 7 *9,
    1+Controls[i].Tag div 7 *9,SRCCOPY);
end;

procedure TEnhanceDlg.FormShow(Sender: TObject);
begin
OffscreenPaint;
end;

procedure TEnhanceDlg.ShowNewContent(NewMode,TerrType: integer);
begin
if (TerrType<fGrass) or (TerrType>fMountains) then Page:=fGrass
else Page:=TerrType;
inherited ShowNewContent(NewMode);
end;

procedure TEnhanceDlg.OffscreenPaint;
var
i,stage,TerrType,TileImp,x,EndStage,Cost,LastJob: integer;
s: string;
Done: Set of jNone..jTrans;
TypeChanged: boolean;
begin
OffscreenUser:=self;
offscreen.Canvas.Font.Assign(UniFont[ftSmall]);
FillOffscreen(0,0,InnerWidth,InnerHeight);

EndStage:=0;
while (EndStage<5) and (MyData.EnhancementJobs[Page,EndStage]<>jNone) do
  inc(EndStage);
x:=InnerWidth div 2-xxt-(xxt+3)*EndStage;

TerrType:=Page;
TileImp:=0;
Done:=[];
Cost:=0;
for stage:=0 to EndStage do
  begin
  if stage>0 then
    begin
    Sprite(offscreen,HGrSystem,x-10,66,14,14,80,1);
    case MyData.EnhancementJobs[Page,stage-1] of
      jRoad:
        begin
        inc(Cost,Terrain[TerrType].MoveCost*RoadWork);
        TileImp:=TileImp or fRoad;
        end;
      jRR:
        begin
        inc(Cost,Terrain[TerrType].MoveCost*RRWork);
        TileImp:=TileImp or fRR;
        end;
      jIrr:
        begin
        inc(Cost,Terrain[TerrType].IrrClearWork);
        TileImp:=TileImp and not fTerImp or tiIrrigation;
        end;
      jFarm:
        begin
        inc(Cost,Terrain[TerrType].IrrClearWork*FarmWork);
        TileImp:=TileImp and not fTerImp or tiFarm;
        end;
      jMine:
        begin
        inc(Cost,Terrain[TerrType].MineAfforestWork);
        TileImp:=TileImp and not fTerImp or tiMine;
        end;
      jClear:
        begin
        inc(Cost,Terrain[TerrType].IrrClearWork);
        TerrType:=Terrain[TerrType].ClearTerrain;
        end;
      jAfforest:
        begin
        inc(Cost,Terrain[TerrType].MineAfforestWork);
        TerrType:=Terrain[TerrType].AfforestTerrain;
        end;
      jTrans:
        begin
        inc(Cost,Terrain[TerrType].TransWork);
        TerrType:=Terrain[TerrType].TransTerrain;
        end;
      end;
    include(Done,MyData.EnhancementJobs[Page,stage-1]);
    end;

  if TerrType<fForest then
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+TerrType*(xxt*2+1),1+yyt)
  else
    begin
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+2*(xxt*2+1),1+yyt+2*(yyt*3+1));
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+7*(xxt*2+1),1+yyt+2*(2+TerrType-fForest)*(yyt*3+1));
    end;
  if TileImp and fTerImp=tiFarm then
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+(xxt*2+1),1+yyt+12*(yyt*3+1))
  else if TileImp and fTerImp=tiIrrigation then
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1,1+yyt+12*(yyt*3+1));
  if TileImp and fRR<>0 then
    begin
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+6*(xxt*2+1),1+yyt+10*(yyt*3+1));
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+2*(xxt*2+1),1+yyt+10*(yyt*3+1));
    end
  else if TileImp and fRoad<>0 then
    begin
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+6*(xxt*2+1),1+yyt+9*(yyt*3+1));
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+2*(xxt*2+1),1+yyt+9*(yyt*3+1));
    end;
  if TileImp and fTerImp=tiMine then
    Sprite(offscreen,HGrTerrain,x,64-yyt,xxt*2,yyt*2,1+2*(xxt*2+1),1+yyt+12*(yyt*3+1));
  inc(x,xxt*2+6)
  end;

for i:=0 to Popup.Items.Count-1 do
  if Popup.Items[i].Tag=Page then
    s:=Popup.Items[i].Caption;
if Cost>0 then s:=Format(Phrases.Lookup('ENHANCE'),[s,MovementToString(Cost)]);
LoweredTextOut(offscreen.Canvas,-1,MainTexture,
  (InnerWidth-BiColorTextWidth(Offscreen.Canvas,s)) div 2,12,s);

if EndStage>0 then LastJob:=MyData.EnhancementJobs[Page,EndStage-1]
else LastJob:=jNone;
if jRoad in Done then job1.ButtonIndex:=3 else job1.ButtonIndex:=2;
if jRR in Done then job2.ButtonIndex:=3 else job2.ButtonIndex:=2;
if jIrr in Done then job4.ButtonIndex:=3 else job4.ButtonIndex:=2;
if jFarm in Done then job5.ButtonIndex:=3 else job5.ButtonIndex:=2;
if jMine in Done then job7.ButtonIndex:=3 else job7.ButtonIndex:=2;
if LastJob=jClear then job3.ButtonIndex:=3 else job3.ButtonIndex:=2;
if LastJob=jAfforest then job6.ButtonIndex:=3 else job6.ButtonIndex:=2;
if LastJob=jTrans then job9.ButtonIndex:=3 else job9.ButtonIndex:=2;

TypeChanged:= LastJob in [jClear, jAfforest, jTrans];
job1.Visible:=(jRoad in Done) or not TypeChanged;
job2.Visible:=(jRR in Done) or not TypeChanged;
job4.Visible:=(jIrr in Done) or not TypeChanged and (Terrain[TerrType].IrrEff>0);
job5.Visible:=(jFarm in Done) or not TypeChanged and (Terrain[TerrType].IrrEff>0);
job7.Visible:=(jMine in Done) or not TypeChanged and (Terrain[TerrType].MineEff>0);
job3.Visible:=not TypeChanged and (Terrain[TerrType].ClearTerrain>=0)
  and ((TerrType<>fDesert) or (MyRO.Wonder[woGardens].EffectiveOwner=me))
  or (LastJob=jClear);
job6.Visible:=not TypeChanged and (Terrain[TerrType].AfforestTerrain>=0)
  or (LastJob=jAfforest);
job9.Visible:=not TypeChanged and (Terrain[TerrType].TransTerrain>=0)
  or (LastJob=jTrans);

MarkUsedOffscreen(InnerWidth,InnerHeight);
end; {OffscreenPaint}

procedure TEnhanceDlg.CloseBtnClick(Sender: TObject);
begin
Close
end;

procedure TEnhanceDlg.ToggleBtnClick(Sender: TObject);
var
i: integer;
begin
for i:=0 to Popup.Items.Count-1 do
  Popup.Items[i].Checked:= Popup.Items[i].Tag=Page;
Popup.Popup(Left+ToggleBtn.Left, Top+ToggleBtn.Top+ToggleBtn.Height);
end;

procedure TEnhanceDlg.TerrClick(Sender: TObject);
begin
Page:=TComponent(Sender).Tag;
SmartUpdateContent
end;

procedure TEnhanceDlg.JobClick(Sender: TObject);
var
stage, NewJob: integer;
Done: Set of jNone..jTrans;

  procedure RemoveJob(j: integer);
  begin // remove job
  stage:=0;
  while (stage<5) and (MyData.EnhancementJobs[Page,stage]<>jNone) do
    begin
    if (MyData.EnhancementJobs[Page,stage]=j) or (j=jRoad)
      and (MyData.EnhancementJobs[Page,stage]=jRR)
      or (j=jIrr) and (MyData.EnhancementJobs[Page,stage]=jFarm) then
      begin
      if stage<4 then
        move(MyData.EnhancementJobs[Page,stage+1],
          MyData.EnhancementJobs[Page,stage],4-stage);
      MyData.EnhancementJobs[Page,4]:=jNone
      end
    else inc(stage);
    end;
  end;

begin
NewJob:=TButtonC(Sender).Tag;
Done:=[];
stage:=0;
while (stage<5) and (MyData.EnhancementJobs[Page,stage]<>jNone) do
  begin
  include(Done, MyData.EnhancementJobs[Page,stage]);
  inc(stage);
  end;
if NewJob in Done then RemoveJob(NewJob)
else
  begin // add job
  if NewJob in [jMine,jAfforest] then RemoveJob(jIrr);
  if NewJob in [jIrr,jFarm,jTrans] then RemoveJob(jMine);
  if (NewJob=jRR) and not (jRoad in Done) then
    begin MyData.EnhancementJobs[Page,stage]:=jRoad; inc(stage) end;
  if (NewJob=jFarm) and not (jIrr in Done) then
    begin MyData.EnhancementJobs[Page,stage]:=jIrr; inc(stage) end;
  MyData.EnhancementJobs[Page,stage]:=NewJob
  end;
SmartUpdateContent
end;

procedure TEnhanceDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if Key=VK_ESCAPE then Close
else if Key=VK_F1 then
  HelpDlg.ShowNewContent(FWindowMode or wmPersistent, hkText, HelpDlg.TextIndex('MACRO'))
end;

end.

