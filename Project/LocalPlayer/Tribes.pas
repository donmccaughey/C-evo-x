{$INCLUDE switches}

unit Tribes;

interface

uses
  Protocol,ScreenTools,

  Classes,Graphics,SysUtils;

type
TCityPicture=record
  xShield,yShield:integer;
  end;
TModelPicture=record
  HGr,pix,xShield,yShield:integer;
  end;
TModelPictureInfo=record
  trix,mix,pix,Hash: integer;
  GrName: ShortString
  end;

TTribe=class
  symHGr, sympix, faceHGr, facepix, cHGr, cpix, //symbol and city graphics
  cAge, mixSlaves: integer;
  Color: TColor;
  NumberName: integer;
  CityPicture: array[0..3] of TCityPicture;
  ModelPicture: array[-1..256] of TModelPicture; // -1 is building site
  ModelName: array[-1..256] of string;
  constructor Create(FileName: string);
  destructor Destroy; override;
  function GetCityName(i: integer): string;
  {$IFNDEF SCR}procedure SetCityName(i: integer; NewName: string);{$ENDIF}
  {$IFNDEF SCR}function TString(Template: string): string;
  function TPhrase(Item: string): string;{$ENDIF}
  procedure SetModelPicture(const Info: TModelPictureInfo; IsNew: boolean);
  function ChooseModelPicture(var Picture: TModelPictureInfo;
    code,Turn: integer; ForceNew: boolean): boolean;
  procedure InitAge(Age: integer);
protected
  CityLine0,nCityLines: integer;
  Name: array['a'..'z'] of string;
  Script: tstringlist;
  end;

var
Tribe: array[0..nPl-1] of TTribe;
HGrStdUnits: integer;

procedure Init;
procedure Done;
function CityName(Founder: integer): string;
function ModelCode(const ModelInfo: TModelInfo): integer;
procedure FindStdModelPicture(code: integer; var pix: integer;
  var Name: string);
function GetTribeInfo(FileName: string; var Name: string; var Color: TColor): boolean;
procedure FindPosition(HGr,x,y,xmax,ymax: integer; Mark: TColor; var xp,yp: integer);


implementation

uses
Directories;


type
TChosenModelPictureInfo=record
  Hash,HGr,pix: integer;
  ModelName: ShortString
  end;

TPictureList=array[0..99999] of TChosenModelPictureInfo;

var
StdUnitScript: tstringlist;
PictureList: ^TPictureList;
nPictureList: integer;


procedure Init;
begin
StdUnitScript:=tstringlist.Create;
StdUnitScript.LoadFromFile(LocalizedFilePath('Tribes\StdUnits.txt'));
nPictureList:=0;
PictureList:=nil;
end;

procedure Done;
begin
ReallocMem(PictureList,0);
StdUnitScript.Free;
end;

function CityName(Founder: integer): string;
begin
if not GenerateNames then
  result:=Format('%d.%d',[Founder shr 12, Founder and $FFF])
else result:=Tribe[Founder shr 12].GetCityName(Founder and $FFF);
end;

function ModelCode(const ModelInfo: TModelInfo): integer;
begin
with ModelInfo do
  begin
  case Kind of
    mkSelfDeveloped, mkEnemyDeveloped:
      case Domain of {age determination}
        dGround:
          if (Attack>=Defense*4)
            or (Attack>0) and (MaxUpgrade<10)
              and (Cap and (1 shl (mcArtillery-mcFirstNonCap))<>0) then
            begin
            result:=170;
            if MaxUpgrade>=12 then inc(result,3)
            else if (MaxUpgrade>=10) or (Weight>7) then inc(result,2)
            else if MaxUpgrade>=4 then inc(result,1)
            end
          else
            begin
            result:=100;
            if MaxUpgrade>=12 then inc(result,6)
            else if (MaxUpgrade>=10) or (Weight>7) then inc(result,5)
            else if MaxUpgrade>=6 then inc(result,4)
            else if MaxUpgrade>=4 then inc(result,3)
            else if MaxUpgrade>=2 then inc(result,2)
            else if MaxUpgrade>=1 then inc(result,1);
            if Speed>=250 then
              if (result>=105) and (Attack<=Defense) then result:=110
              else inc(result,30)
            end;
        dSea:
          begin
          result:=200;
          if MaxUpgrade>=8 then inc(result,3)
          else if MaxUpgrade>=6 then inc(result,2)
          else if MaxUpgrade>=3 then inc(result,1);
          if Cap and (1 shl (mcSub-mcFirstNonCap))<>0 then result:=240
          else if ATrans_Fuel>0 then result:=220
          else if (result>=202) and (Attack=0) and (TTrans>0) then result:=210;
          end;
        dAir:
          begin
          result:=300;
          if (Bombs>0) or (TTrans>0) then inc(result,10);
          if Speed>850 then inc(result,1)
          end;
        end;
    mkSpecial_TownGuard: result:=41;
    mkSpecial_Boat: result:=64;
    mkSpecial_SubCabin: result:=71;
    mkSpecial_Glider: result:=73;
    mkSlaves: result:=74;
    mkSettler: if Speed>150 then result:=11 else result:=10;
    mkDiplomat: result:=21;
    mkCaravan: result:=30;
    end;
  end;
end;

var
Input: string;

function Get: string;
var
p:integer;
begin
while (Input<>'') and ((Input[1]=' ') or (Input[1]=#9)) do Delete(Input,1,1);
p:=pos(',',Input);if p=0 then p:=Length(Input)+1;
result:=Copy(Input,1,p-1);
Delete(Input,1,p)
end;

function GetNum: integer;
var
i:integer;
begin
val(Get,result,i);
if i<>0 then result:=0
end;

procedure FindStdModelPicture(code: integer; var pix: integer;
  var Name: string);
var
i: integer;
begin
for i:=0 to StdUnitScript.Count-1 do
  begin // look through StdUnits
  Input:=StdUnitScript[i];
  pix:=GetNum;
  if code=GetNum then begin Name:=Get; exit; end
  end;
pix:=-1
end;

function GetTribeInfo(FileName: string; var Name: string; var Color: TColor): boolean;
var
found: integer;
TribeScript: TextFile;
begin
Name:='';
Color:=$FFFFFF;
found:=0;
AssignFile(TribeScript,LocalizedFilePath('Tribes\'+FileName+'.tribe.txt'));
Reset(TribeScript);
while not EOF(TribeScript) do
  begin
  ReadLn(TribeScript,Input);
  if Copy(Input,1,7)='#CHOOSE' then
    begin
    Name:=Copy(Input,9,255);
    found:=found or 1;
    if found=3 then break
    end
  else if Copy(Input,1,6)='#COLOR' then
    begin
    Color:=HexStringToColor(Copy(Input,7,255));
    found:=found or 2;
    if found=3 then break
    end
  end;
CloseFile(TribeScript);
result:= found=3;
end;

constructor TTribe.Create(FileName: string);
var
line:integer;
variant: char;
Item:string;
begin
inherited Create;
for variant:='a' to 'z' do Name[variant]:='';
Script:=tstringlist.Create;
Script.LoadFromFile(LocalizedFilePath('Tribes\'+FileName+'.tribe.txt'));
CityLine0:=0;
nCityLines:=0;
for line:=0 to Script.Count-1 do
  begin
  Input:=Script[line];
  if (CityLine0>0) and (nCityLines=0) and ((Input='') or (Input[1]='#')) then
    nCityLines:=line-CityLine0;
  if (Length(Input)>=3) and (Input[1]='#') and (Input[2] in ['a'..'z'])
    and (Input[3]=' ') then
    Name[Input[2]]:=Copy(Input,4,255)
  else if Copy(Input,1,6)='#COLOR' then
    Color:=HexStringToColor(Copy(Input,7,255))
  else if Copy(Input,1,7)='#CITIES' then CityLine0:=line+1
  else if Copy(Input,1,8)='#SYMBOLS' then
    begin
    Delete(Input,1,9);
    Item:=Get;
    sympix:=GetNum;
    symHGr:=LoadGraphicSet(Item);
    end
  end;
FillChar(ModelPicture,SizeOf(ModelPicture),0);
NumberName:=-1;
cAge:=-1;
mixSlaves:=-1;
end;

destructor TTribe.Destroy;
begin
Script.Free;
inherited Destroy;
end;

procedure FindPosition(HGr,x,y,xmax,ymax: integer; Mark: TColor;
  var xp,yp: integer);
begin
xp:=0;
while (xp<xmax) and (GrExt[HGr].Data.Canvas.Pixels[x+1+xp,y]<>Mark) do
  inc(xp);
yp:=0;
while (yp<ymax) and (GrExt[HGr].Data.Canvas.Pixels[x,y+1+yp]<>Mark) do
  inc(yp);
end;

function TTribe.GetCityName(i: integer): string;
begin
result:='';
if nCityLines>i then
  begin
  result:=Script[CityLine0+i];
  while (result<>'') and ((result[1]=' ') or (result[1]=#9)) do
    Delete(result,1,1);
  end
{$IFNDEF SCR}else result:=Format(TPhrase('GENCITY'),[i+1]){$ENDIF}
end;

{$IFNDEF SCR}
procedure TTribe.SetCityName(i: integer; NewName: string);
begin
while nCityLines<=i do
  begin
  Script.Insert(CityLine0+nCityLines, Format(TPhrase('GENCITY'),
    [nCityLines+1]));
  inc(nCityLines);
  end;
Script[CityLine0+i]:=NewName;
end;

function TTribe.TString(Template: string): string;
var
p: integer;
variant: char;
CaseUp: boolean;
begin
repeat
  p:=pos('#',Template);
  if (p=0) or (p=Length(Template)) then Break;
  variant:=Template[p+1];
  CaseUp:= variant in ['A'..'Z'];
  if CaseUp then inc(variant,32);
  Delete(Template,p,2);
  if variant in ['a'..'z'] then
    begin
    if NumberName<0 then Insert(Name[variant],Template,p)
    else Insert(Format('P%d',[NumberName]),Template,p);
    if CaseUp and (Length(Template)>=p) and (Template[p] in ['a'..'z',#$E0..#$FF]) then
      dec(Template[p],32);
    end
until false;
result:=Template;
end;

function TTribe.TPhrase(Item: string): string;
begin
result:=TString(Phrases.Lookup(Item));
end;
{$ENDIF}

procedure TTribe.InitAge(Age: integer);
type
TLine=array[0..649,0..2] of Byte;
var
i,x,gray: integer;
Item: string;
begin
if Age=cAge then exit;
cAge:=Age;
with Script do
  begin
  i:=0;
  while (i<Count) and (Copy(Strings[i],1,6)<>'#AGE'+char(48+Age)+' ') do
    inc(i);
  if i<Count then
    begin
    Input:=Strings[i];
    system.Delete(Input,1,6);
    Item:=Get;
    cpix:=GetNum;
    // init city graphics
    if age<2 then
      begin
      if CompareText(Item,'stdcities')=0 then
        case cpix of
          3: cpix:=0;
          6: begin cpix:=0; Item:='Nation2'; end
          end;
      cHGr:=LoadGraphicSet(Item);
      for x:=0 to 3 do with CityPicture[x] do
        begin
        FindPosition(cHGr,x*65,cpix*49,63,47,$00FFFF,xShield,yShield);
        //FindPosition(cHGr,x*65,cpix*49,$FFFFFF,xf,yf);
        end
      end
    else cHGr:=-1;

    {$IFNDEF SCR}
    Get;
    GetNum;
    Item:=Get;
    if Item='' then faceHGr:=-1
    else
      begin
      faceHGr:=LoadGraphicSet(Item);
      facepix:=GetNum;
      if GrExt[faceHGr].Data.Canvas.Pixels[facepix mod 10*65,facepix div 10*49+48]=$00FFFF then
        begin // generate shield picture
        GrExt[faceHGr].Data.Canvas.Pixels[facepix mod 10*65,facepix div 10*49+48]:=$000000;
        gray:=$B8B8B8;
        ImageOp_BCC(GrExt[faceHGr].Data,Templates,facepix mod 10*65+1,
          facepix div 10*49+1,1,25,64,48,gray,Color);
        end
      end;
    {$ENDIF}  
    end
  end
end;

procedure TTribe.SetModelPicture(const Info: TModelPictureInfo; IsNew: boolean);
var
i: integer;
ok: boolean;
begin
with Info do
  begin
  if not IsNew then
    begin
    i:=nPictureList-1;
    while (i>=0) and (PictureList[i].Hash<>Info.Hash) do dec(i);
    assert(i>=0);
    assert(PictureList[i].HGr = LoadGraphicSet(GrName));
    assert(PictureList[i].pix = pix);
    ModelPicture[mix].HGr:=PictureList[i].HGr;
    ModelPicture[mix].pix:=PictureList[i].pix;
    ModelName[mix]:=PictureList[i].ModelName;
    end
  else
    begin
    with ModelPicture[mix] do
      begin
      HGr:=LoadGraphicSet(GrName);
      pix:=Info.pix;
      inc(GrExt[HGr].pixUsed[pix]);
      end;
    ModelName[mix]:='';

    // read model name from tribe script
    ok:=false;
    for i:=0 to Script.Count-1 do
      begin
      Input:=Script[i];
      if Input='#UNITS '+GrName then ok:=true
      else if (Input<>'') and (Input[1]='#') then ok:=false
      else if ok and (GetNum=pix) then
        begin Get; ModelName[mix]:=Get end
      end;

    if ModelName[mix]='' then
      begin // read model name from StdUnits.txt
      for i:=0 to StdUnitScript.Count-1 do
        begin
        Input:=StdUnitScript[i];
        if GetNum=pix then
          begin Get; ModelName[mix]:=Get end
        end
      end;

    if Hash<>0 then
      begin
      if nPictureList=0 then
        ReallocMem(PictureList, 64*sizeof(TChosenModelPictureInfo))
      else if (nPictureList>=64) and (nPictureList and (nPictureList-1)=0) then
        ReallocMem(PictureList, nPictureList*(2*sizeof(TChosenModelPictureInfo)));
      PictureList[nPictureList].Hash:=Info.Hash;
      PictureList[nPictureList].HGr:=ModelPicture[mix].HGr;
      PictureList[nPictureList].pix:=Info.pix;
      PictureList[nPictureList].ModelName:=ModelName[mix];
      inc(nPictureList);
      end
    end;

  with ModelPicture[mix] do
    FindPosition(HGr,pix mod 10 *65,pix div 10 *49,63,47,$FFFFFF,xShield,yShield);
  end;
end;

function TTribe.ChooseModelPicture(var Picture: TModelPictureInfo;
  code,Turn: integer; ForceNew: boolean): boolean;
var
i,Cnt,HGr,used,LeastUsed: integer;
TestPic: TModelPictureInfo;
ok: boolean;

  procedure check;
  begin
  TestPic.pix:=GetNum;
  if code=GetNum then
    begin
    if ForceNew or (HGr<0) then used:=0
    else
      begin
      used:=4*GrExt[HGr].pixUsed[TestPic.pix];
      if HGr=HGrStdUnits then inc(used,2); // prefer units not from StdUnits
      end;
    if used<LeastUsed then begin Cnt:=0; LeastUsed:=used end;
    if used=LeastUsed then
      begin
      inc(Cnt);
      if Turn mod Cnt=0 then Picture:=TestPic
      end;
    end
  end;

begin
// look for identical model to assign same picture again
if not ForceNew and (Picture.Hash>0) then
  begin
  for i:=0 to nPictureList-1 do
    if PictureList[i].Hash=Picture.Hash then
      begin
      Picture.GrName:=GrExt[PictureList[i].HGr].Name;
      Picture.pix:=PictureList[i].pix;
      result:=false;
      exit;
      end
  end;

Picture.pix:=0;
TestPic:=Picture;
LeastUsed:=MaxInt;

TestPic.GrName:='StdUnits';
HGr:=HGrStdUnits;
for i:=0 to StdUnitScript.Count-1 do
  begin // look through StdUnits
  Input:=StdUnitScript[i];
  check;
  end;

ok:=false;
for i:=0 to Script.Count-1 do
  begin // look through units defined in tribe script
  Input:=Script[i];
  if Copy(Input,1,6)='#UNITS' then
    begin
    ok:=true;
    TestPic.GrName:=Copy(Input,8,255);
    HGr:=nGrExt-1;
    while (HGr>=0) and (GrExt[HGr].Name<>TestPic.GrName) do dec(HGr);
    end
  else if (Input<>'') and (Input[1]='#') then ok:=false
  else if ok then check;
  end;
result:=true;
end;

end.

