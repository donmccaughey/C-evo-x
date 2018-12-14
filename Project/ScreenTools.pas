{$INCLUDE switches}

unit ScreenTools;

interface

uses
  StringTables,


  Windows,Messages,SysUtils,Classes,Graphics,Controls,Forms,Menus;

type
TTexture=record
  Image: TBitmap;
  clBevelLight,clBevelShade,clTextLight,clTextShade,clLitText,clMark,clPage,clCover: TColor
  end;

function ChangeResolution(x,y,bpp,freq: integer): boolean;
procedure RestoreResolution;
function Play(Item: string; Index: integer =-1): boolean;
procedure PreparePlay(Item: string; Index: integer =-1);
procedure EmptyMenu(MenuItems: TMenuItem; Keep: integer = 0);
function turntoyear(Turn: integer): integer;
function TurnToString(Turn: integer): string;
function MovementToString(Movement: integer): string;
procedure BtnFrame(ca:TCanvas;p:TRect;const T: TTexture);
procedure EditFrame(ca:TCanvas;p:TRect;const T: TTexture);
function HexStringToColor(s: string): integer;
function LoadGraphicFile(bmp: TBitmap; Path: string; Options: integer= 0): boolean;
function LoadLocalizedGraphicFile(bmp: TBitmap; Path: string; Options: integer= 0): boolean;
function LoadGraphicSet(Name: string): integer;
procedure Dump(dst:TBitmap; HGr,xDst,yDst,Width,Height,xGr,yGr:integer);
procedure Sprite(Canvas: TCanvas; HGr,xDst,yDst,Width,Height,xGr,yGr: integer); overload;
procedure Sprite(dst:TBitmap; HGr,xDst,yDst,Width,Height,xGr,yGr:integer); overload;
procedure MakeBlue(Dst: TBitmap; x,y,w,h: integer);
procedure ImageOp_B(Dst,Src: TBitmap; xDst,yDst,xSrc,ySrc,w,h: integer);
procedure ImageOp_BCC(Dst,Src: TBitmap; xDst,yDst,xSrc,ySrc,w,h,Color1,Color2: integer);
procedure ImageOp_CCC(Bmp: TBitmap; x,y,w,h,Color0,Color1,Color2: integer);
procedure SLine(ca: TCanvas; x0,x1,y: integer; cl: TColor);
procedure DLine(ca: TCanvas; x0,x1,y: integer; cl0,cl1: TColor);
procedure Frame(ca: TCanvas;x0,y0,x1,y1:integer;cl0,cl1:TColor);
procedure RFrame(ca: TCanvas;x0,y0,x1,y1:integer;cl0,cl1:TColor);
procedure CFrame(ca: TCanvas; x0,y0,x1,y1,Corner: integer; cl: TColor);
procedure FrameImage(ca: TCanvas; src:TBitmap; x,y,width,height,xSrc,ySrc: integer; IsControl: boolean = false);
procedure GlowFrame(dst: TBitmap; x0,y0,width,height: integer; cl: TColor);
procedure InitOrnament;
procedure InitCityMark(const T: TTexture);
procedure Fill(ca: TCanvas;Left,Top,Width,Height,xOffset,yOffset: integer);
procedure FillLarge(ca: TCanvas; x0,y0,x1,y1,xm: integer);
procedure FillSeamless(ca: TCanvas;Left,Top,Width,Height,xOffset,yOffset: integer;const Texture: TBitmap);
procedure FillRectSeamless(ca: TCanvas;x0,y0,x1,y1,xOffset,yOffset: integer;
  const Texture: TBitmap);
procedure PaintBackground(Form: TForm; Left,Top,Width,Height: integer);
procedure Corner(ca: TCanvas; x,y,Kind:integer; const T: TTexture);
procedure BiColorTextOut(ca: TCanvas; clMain, clBack: TColor;
  x,y:integer; s:string);
procedure LoweredTextOut(ca: TCanvas; cl: TColor; const T: TTexture;
  x,y:integer; s:string);
function BiColorTextWidth(ca: TCanvas; s: string): integer;
procedure RisedTextOut(ca: TCanvas; x,y:integer; s:string);
procedure LightGradient(ca: TCanvas; x,y,width,Color:integer);
procedure DarkGradient(ca: TCanvas; x,y,width,Kind:integer);
procedure VLightGradient(ca: TCanvas; x,y,height,Color:integer);
procedure VDarkGradient(ca: TCanvas; x,y,height,Kind:integer);
procedure NumberBar(dst:TBitmap; x,y:integer; Cap:string; val: integer;
  const T: TTexture);
procedure CountBar(dst:TBitmap; x,y,w:integer; Kind:integer; Cap:string;
  val: integer; const T: TTexture);
procedure PaintProgressBar(ca: TCanvas; Kind,x,y,pos,Growth,max: integer;
  const T: TTexture);
procedure PaintRelativeProgressBar(ca: TCanvas; Kind,x,y,size,pos,Growth,
  max: integer; IndicateComplete: boolean; const T: TTexture);
procedure PaintLogo(ca: TCanvas; x,y,clLight,clShade: integer);
function SetMainTextureByAge(Age: integer): boolean;

const
nGrExtmax=64;
wMainTexture=640; hMainTexture=480;

// template positions in Template.bmp
xLogo=1; yLogo=1; wLogo=122; hLogo=23; // logo
xBBook=1; yBBook=74; wBBook=143; hBBook=73; // big book
xSBook=72; ySBook=37; wSBook=72; hSBook=36; // small book
xNation=1; yNation=25;
xCoal=1; yCoal=148;

// Icons.bmp structure
xSizeBig=56; ySizeBig=40;

GlowRange=8;

EmptySpaceColor=$101010;

// template positions in System2.bmp
xOrna=156; yOrna=1; wOrna=27; hOrna=26; // ornament

// sound modes
smOff=0; smOn=1; smOnAlt=2;

// color matrix
clkAge0=1; cliTexture=0; cliBevelLight=cliTexture+1; cliBevelShade=cliTexture+2;
cliTextLight=cliTexture+3; cliTextShade=cliTexture+4; cliLitText=cliTexture+5;
cliMark=cliTexture+6; cliDimmedText=cliTexture+7;
cliRoad=8; cliHouse=cliRoad+1; cliImp=cliRoad+2; cliImpProject=cliRoad+3;
cliPage=13; cliCover=cliPage+1;
clkMisc=5; cliPaper=0; cliPaperText=1; cliPaperCaption=2;
clkCity=6; cliPlains=0; cliPrairie=1; cliHills=2; cliTundra=3; cliWater=4;

// LoadGraphicFile options
gfNoError=$01; gfNoGamma=$02; gfJPG=$04;

type
TGrExtDescr=record {don't use dynamic strings here!}
  Name:string[31];
  Data,Mask:TBitmap;
  pixUsed: array[Byte] of Byte;
  end;
TGrExtDescrSize=record {for size calculation only - must be the same as
  TGrExtDescr, but without pixUsed}
  Name:string[31];
  Data,Mask:TBitmap;
  end;

TFontType=(ftNormal, ftSmall, ftTiny, ftCaption, ftButton);

var
Phrases, Phrases2, Sounds: TStringTable;
nGrExt: integer;
GrExt:array[0..nGrExtmax-1] of ^TGrExtDescr;
HGrSystem, HGrSystem2, ClickFrameColor,SoundMode, MainTextureAge: integer;
MainTexture: TTexture;
Templates,Colors,Paper,BigImp,LogoBuffer: TBitmap;
FullScreen,GenerateNames,InitOrnamentDone,Phrases2FallenBackToEnglish: boolean;

UniFont: array[TFontType] of TFont;

implementation

uses
  Directories, Sound, ButtonBase, ButtonA, ButtonB,

  Registry,JPEG;

var
StartResolution: TDeviceMode;
ResolutionChanged: boolean;

Gamma: integer; // global gamma correction (cent)
GammaLUT: array[0..255] of byte;


function ChangeResolution(x,y,bpp,freq: integer): boolean;
var
DevMode: TDeviceMode;
begin
EnumDisplaySettings(nil, 0, DevMode);
DevMode.dmFields := DM_PELSWIDTH or DM_PELSHEIGHT or DM_BITSPERPEL
  or DM_DISPLAYFREQUENCY;
DevMode.dmPelsWidth:=x;
DevMode.dmPelsHeight:=y;
DevMode.dmBitsPerPel:=bpp;
DevMode.dmDisplayFrequency:=freq;
result:= ChangeDisplaySettings(DevMode,0)=DISP_CHANGE_SUCCESSFUL;
if result then
  ResolutionChanged:=true;
end;

procedure RestoreResolution;
begin
if ResolutionChanged then
  ChangeDisplaySettings(StartResolution,0);
ResolutionChanged:=false;
end;

function Play(Item: string; Index: integer =-1): boolean;
{$IFNDEF DEBUG}
var
WAVFileName: string;
{$ENDIF}
begin
{$IFNDEF DEBUG}
if (Sounds=nil) or (SoundMode=smOff) or (Item='') then
  begin result:=true; exit; end;
WAVFileName:=Sounds.Lookup(Item, Index);
assert(WAVFileName[1]<>'[');
result:=(WAVFileName<>'') and (WAVFileName[1]<>'[') and (WAVFileName<>'*');
if result then
//  SndPlaySound(pchar(HomeDir+'Sounds\'+WAVFileName+'.wav'),SND_ASYNC)
  PlaySound(HomeDir+'Sounds\'+WAVFileName)
{$ENDIF}
end;

procedure PreparePlay(Item: string; Index: integer =-1);
{$IFNDEF DEBUG}
var
WAVFileName: string;
{$ENDIF}
begin
{$IFNDEF DEBUG}
if (Sounds=nil) or (SoundMode=smOff) or (Item='') then exit;
WAVFileName:=Sounds.Lookup(Item, Index);
assert(WAVFileName[1]<>'[');
if (WAVFileName<>'') and (WAVFileName[1]<>'[') and (WAVFileName<>'*') then
  PrepareSound(HomeDir+'Sounds\'+WAVFileName)
{$ENDIF}
end;

procedure EmptyMenu(MenuItems: TMenuItem; Keep: integer = 0);
var
m: TMenuItem;
begin
while MenuItems.Count>Keep do
  begin
  m:=MenuItems[MenuItems.Count-1];
  MenuItems.Delete(MenuItems.Count-1);
  m.Free;
  end;
end;

function turntoyear(Turn: integer): integer;
var
i: integer;
begin
result:=-4000;
for i:=1 to Turn do
  if result<-1000 then inc(result,50)       // 0..60
  else if result<0 then inc(result,25)      // 60..100
  else if result<1500 then inc(result,20)   // 100..175
  else if result<1750 then inc(result,10)   // 175..200
  else if result<1850 then inc(result,2)    // 200..250
  else inc(result);
end;

function TurnToString(Turn: integer): string;
var
year: integer;
begin
if GenerateNames then
  begin
  year:=turntoyear(Turn);
  if year<0 then result:=Format(Phrases.Lookup('BC'),[-year])
  else result:=Format(Phrases.Lookup('AD'),[year]);
  end
else result:=IntToStr(Turn)
end;

function MovementToString(Movement: integer): string;
begin
if Movement>=1000 then
  begin
  result:=char(48+Movement div 1000);
  Movement:=Movement mod 1000;
  end
else result:='';
result:=result+char(48+Movement div 100);
Movement:=Movement mod 100;
if Movement>0 then
  begin
  result:=result+'.'+char(48+Movement div 10);
  Movement:=Movement mod 10;
  if Movement>0 then
    result:=result+char(48+Movement);
  end
end;

procedure BtnFrame(ca:TCanvas;p:TRect;const T: TTexture);
begin
RFrame(ca,p.Left-1,p.Top-1,p.Right,p.Bottom,T.clBevelShade,T.clBevelLight)
end;

procedure EditFrame(ca:TCanvas;p:TRect;const T: TTexture);
begin
Frame(ca,p.Left-1,p.Top-1,p.Right,p.Bottom,$000000,$000000);
Frame(ca,p.Left-2,p.Top-2,p.Right+1,p.Bottom+1,$000000,$000000);
Frame(ca,p.Left-3,p.Top-3,p.Right+2,p.Bottom+1,$000000,$000000);
RFrame(ca,p.Left-4,p.Top-4,p.Right+3,p.Bottom+2,T.clBevelShade,T.clBevelLight)
end;

function HexStringToColor(s: string): integer;

  function HexCharToInt(x: char): integer;
  begin
  case x of
    '0'..'9': result:=ord(x)-48;
    'A'..'F': result:=ord(x)-65+10;
    'a'..'f': result:=ord(x)-97+10;
    else result:=0
    end
  end;

begin
while (Length(s)>0) and (s[1]=' ') do Delete(s,1,1);
s:=s+'000000';
if Gamma=100 then
  result:=$10*HexCharToInt(s[1])+$1*HexCharToInt(s[2])
    +$1000*HexCharToInt(s[3])+$100*HexCharToInt(s[4])
    +$100000*HexCharToInt(s[5])+$10000*HexCharToInt(s[6])
else result:=GammaLUT[$10*HexCharToInt(s[1])+HexCharToInt(s[2])]
  +$100*GammaLUT[$10*HexCharToInt(s[3])+HexCharToInt(s[4])]
  +$10000*GammaLUT[$10*HexCharToInt(s[5])+HexCharToInt(s[6])];
end;

procedure ApplyGamma(Start, Stop: pbyte);
begin
while integer(Start)<integer(Stop) do
  begin Start^:=GammaLUT[Start^]; inc(Start); end;
end;

function LoadGraphicFile(bmp: TBitmap; Path: string; Options: integer): boolean;
type
TLine=array[0..9999,0..2] of Byte;
var
FirstLine, LastLine: ^TLine;
jtex: tjpegimage;
begin
result:=true;
if Options and gfJPG<>0 then
  begin
  jtex:=tjpegimage.create;
  try
    jtex.loadfromfile(Path+'.jpg');
  except
    result:=false;
    end;
  if result then
    begin
    if Options and gfNoGamma=0 then
      bmp.PixelFormat:=pf24bit;
    bmp.width:=jtex.width; bmp.height:=jtex.height;
    bmp.canvas.draw(0,0,jtex);
    end;
  jtex.free;
  end
else
  begin
  try
    bmp.LoadFromFile(Path+'.bmp');
  except
    result:=false;
    end;
  if result then
    begin
    if Options and gfNoGamma=0 then
      bmp.PixelFormat:=pf24bit;
    end
  end;
if not result then
  begin
  if Options and gfNoError=0 then
    Application.MessageBox(PChar(Format(Phrases.Lookup('FILENOTFOUND'),[Path])), 'C-evo', 0);
  exit;
  end;
if (Options and gfNoGamma=0) and (Gamma<>100) then
  begin
  FirstLine:=bmp.ScanLine[0];
  LastLine:=bmp.ScanLine[bmp.Height-1];
  if integer(FirstLine)<integer(LastLine) then
    ApplyGamma(pointer(FirstLine), @LastLine[bmp.Width])
  else ApplyGamma(pointer(LastLine), @FirstLine[bmp.Width])
  end
end;

function LoadLocalizedGraphicFile(bmp: TBitmap; Path: string; Options: integer): boolean;
type
TLine=array[0..9999,0..2] of Byte;
var
FirstLine, LastLine: ^TLine;
jtex: tjpegimage;
begin
result:=true;
if Options and gfJPG<>0 then
  begin
  jtex:=tjpegimage.create;
  try
    jtex.loadfromfile(LocalizedFilePath(Path+'.jpg'));
  except
    result:=false;
    end;
  if result then
    begin
    if Options and gfNoGamma=0 then
      bmp.PixelFormat:=pf24bit;
    bmp.width:=jtex.width; bmp.height:=jtex.height;
    bmp.canvas.draw(0,0,jtex);
    end;
  jtex.free;
  end
else
  begin
  try
    bmp.LoadFromFile(LocalizedFilePath(Path+'.bmp'));
  except
    result:=false;
    end;
  if result then
    begin
    if Options and gfNoGamma=0 then
      bmp.PixelFormat:=pf24bit;
    end
  end;
if not result then
  begin
  if Options and gfNoError=0 then
    Application.MessageBox(PChar(Format(Phrases.Lookup('FILENOTFOUND'),[Path])), 'C-evo', 0);
  exit;
  end;
if (Options and gfNoGamma=0) and (Gamma<>100) then
  begin
  FirstLine:=bmp.ScanLine[0];
  LastLine:=bmp.ScanLine[bmp.Height-1];
  if integer(FirstLine)<integer(LastLine) then
    ApplyGamma(pointer(FirstLine), @LastLine[bmp.Width])
  else ApplyGamma(pointer(LastLine), @FirstLine[bmp.Width])
  end
end;

function LoadGraphicSet(Name: string): integer;
type
TLine=array[0..999,0..2] of Byte;
var
i,x,y,xmax,OriginalColor: integer;
FileName: string;
Source: TBitmap;
DataLine, MaskLine: ^TLine;
begin
i:=0;
while (i<nGrExt) and (GrExt[i].Name<>Name) do inc(i);
result:=i;
if i=nGrExt then
  begin
  FileName:=HomeDir+'Graphics\'+Name;
  Source:=TBitmap.Create;
  try
    Source.LoadFromFile(FileName+'.bmp')
  except
    result:=-1;
    Application.MessageBox(PChar(Format(Phrases.Lookup('FILENOTFOUND'),['Graphics\'+Name])), 'C-evo', 0);
    exit;
    end;

  GetMem(GrExt[nGrExt],SizeOf(TGrExtDescrSize)+Source.Height div 49 *10);
  GrExt[nGrExt].Name:=Name;

  xmax:=Source.Width-1; // allows 4-byte access even for last pixel
  if xmax>970 then xmax:=970;

  GrExt[nGrExt].Data:=Source;
  GrExt[nGrExt].Data.PixelFormat:=pf24bit;
  GrExt[nGrExt].Mask:=TBitmap.Create;
  GrExt[nGrExt].Mask.PixelFormat:=pf24bit;
  GrExt[nGrExt].Mask.Width:=Source.Width;
  GrExt[nGrExt].Mask.Height:=Source.Height;

  for y:=0 to Source.Height-1 do
    begin
    DataLine:=GrExt[nGrExt].Data.ScanLine[y];
    MaskLine:=GrExt[nGrExt].Mask.ScanLine[y];
    for x:=0 to xmax-1 do
      begin
      OriginalColor:=Cardinal((@DataLine[x])^) and $FFFFFF;
      if (OriginalColor=$FF00FF) or (OriginalColor=$7F007F) then
        begin // transparent
        Cardinal((@MaskLine[x])^):=$FFFFFF;
        Cardinal((@DataLine[x])^):=Cardinal((@DataLine[x])^) and $FF000000
        end
      else
        begin
        Cardinal((@MaskLine[x])^):=$000000; // non-transparent
        if Gamma<>100 then
          begin
          DataLine[x,0]:=GammaLUT[DataLine[x,0]];
          DataLine[x,1]:=GammaLUT[DataLine[x,1]];
          DataLine[x,2]:=GammaLUT[DataLine[x,2]];
          end
        end
      end
    end;

  FillChar(GrExt[nGrExt].pixUsed,GrExt[nGrExt].Data.Height div 49 *10,0);
  inc(nGrExt)
  end
end;

procedure Dump(dst:TBitmap; HGr,xDst,yDst,Width,Height,xGr,yGr: integer);
begin
BitBlt(dst.Canvas.Handle,xDst,yDst,Width,Height,
  GrExt[HGr].Data.Canvas.Handle,xGr,yGr,SRCCOPY);
end;

procedure MakeBlue(Dst: TBitmap; x,y,w,h: integer);
type
TLine=array[0..99999,0..2] of Byte;
PLine=^TLine;

  procedure BlueLine(line: PLine; length: integer);
  var
  i: integer;
  begin
  for i:=0 to length-1 do
    begin
    line[i,0]:=line[i,0] div 2;
    line[i,1]:=line[i,1] div 2;
    line[i,2]:=line[i,2] div 2;
    end
  end;

var
i: integer;
begin
for i:=0 to h-1 do
  BlueLine(@(PLine(Dst.ScanLine[y+i])[x]),w)
end;

procedure ImageOp_B(Dst,Src: TBitmap; xDst,yDst,xSrc,ySrc,w,h: integer);
// Src is template
// X channel = background amp (old Dst content), 128=original brightness
type
TPixel=array[0..2] of Byte;
var
i,Brightness,test: integer;
PixelSrc: ^byte;
PixelDst: ^TPixel;
begin
assert(Src.PixelFormat=pf8bit);
assert(Dst.PixelFormat=pf24bit);
if xDst<0 then
  begin w:=w+xDst; xSrc:=xSrc-xDst; xDst:=0; end;
if yDst<0 then
  begin h:=h+yDst; ySrc:=ySrc-yDst; yDst:=0; end;
if xDst+w>Dst.Width then
  w:=Dst.Width-xDst;
if yDst+h>Dst.Height then
  h:=Dst.Height-yDst;
if (w<0) or (h<0) then
  exit;

h:=yDst+h;
while yDst<h do
  begin
  PixelDst:=pointer(integer(Dst.ScanLine[yDst])+3*xDst);
  PixelSrc:=pointer(integer(Src.ScanLine[ySrc])+xSrc);
  for i:=0 to w-1 do
    begin
    Brightness:=PixelSrc^;
    test:=(PixelDst[2]*Brightness) shr 7;
    if test>=256 then PixelDst[2]:=255
    else PixelDst[2]:=test; // Red
    test:=(PixelDst[1]*Brightness) shr 7;
    if test>=256 then PixelDst[1]:=255
    else PixelDst[1]:=test; // Green
    test:=(PixelDst[0]*Brightness) shr 7;
    if test>=256 then PixelDst[2]:=255
    else PixelDst[0]:=test; // Blue
    PixelDst:=pointer(integer(PixelDst)+3);
    PixelSrc:=pointer(integer(PixelSrc)+1);
    end;
  inc(yDst);
  inc(ySrc);
  end
end;

procedure ImageOp_BCC(Dst,Src: TBitmap; xDst,yDst,xSrc,ySrc,w,h,Color1,Color2: integer);
// Src is template
// B channel = background amp (old Dst content), 128=original brightness
// G channel = Color1 amp, 128=original brightness
// R channel = Color2 amp, 128=original brightness
type
TLine=array[0..9999,0..2] of Byte;
var
ix,iy,amp1,amp2,trans,Value: integer;
SrcLine,DstLine: ^TLine;
begin
if xDst<0 then
  begin w:=w+xDst; xSrc:=xSrc-xDst; xDst:=0; end;
if yDst<0 then
  begin h:=h+yDst; ySrc:=ySrc-yDst; yDst:=0; end;
if xDst+w>Dst.Width then
  w:=Dst.Width-xDst;
if yDst+h>Dst.Height then
  h:=Dst.Height-yDst;
if (w<0) or (h<0) then
  exit;

for iy:=0 to h-1 do
  begin
  SrcLine:=Src.ScanLine[ySrc+iy];
  DstLine:=Dst.ScanLine[yDst+iy];
  for ix:=0 to w-1 do
    begin
    trans:=SrcLine[xSrc+ix,0]*2; // green channel = transparency
    amp1:=SrcLine[xSrc+ix,1]*2;
    amp2:=SrcLine[xSrc+ix,2]*2;
    if trans<>$FF then
      begin
      Value:=(DstLine[xDst+ix][0]*trans+(Color2 shr 16 and $FF)*amp2+(Color1 shr 16 and $FF)*amp1) div $FF;
      if Value<256 then
        DstLine[xDst+ix][0]:=Value
      else DstLine[xDst+ix][0]:=255;
      Value:=(DstLine[xDst+ix][1]*trans+(Color2 shr 8 and $FF)*amp2+(Color1 shr 8 and $FF)*amp1) div $FF;
      if Value<256 then
        DstLine[xDst+ix][1]:=Value
      else DstLine[xDst+ix][1]:=255;
      Value:=(DstLine[xDst+ix][2]*trans+(Color2 and $FF)*amp2+(Color1 and $FF)*amp1) div $FF;
      if Value<256 then
        DstLine[xDst+ix][2]:=Value
      else DstLine[xDst+ix][2]:=255;
      end
    end
  end;
end;

procedure ImageOp_CCC(Bmp: TBitmap; x,y,w,h,Color0,Color1,Color2: integer);
// Bmp is template
// B channel = Color0 amp, 128=original brightness
// G channel = Color1 amp, 128=original brightness
// R channel = Color2 amp, 128=original brightness
type
TPixel=array[0..2] of Byte;
var
i,Red,Green: integer;
Pixel: ^TPixel;
begin
assert(Bmp.PixelFormat=pf24bit);
h:=y+h;
while y<h do
  begin
  Pixel:=pointer(integer(Bmp.ScanLine[y])+3*x);
  for i:=0 to w-1 do
    begin
    Red:=       (Pixel[0]*(Color0        and $0000FF)
                +Pixel[1]*(Color1        and $0000FF)
                +Pixel[2]*(Color2        and $0000FF)) shr 8;
    Green:=     (Pixel[0]*(Color0 shr  8 and $0000FF)
                +Pixel[1]*(Color1 shr  8 and $0000FF)
                +Pixel[2]*(Color2 shr  8 and $0000FF)) shr 8;
    Pixel[0]:=  (Pixel[0]*(Color0 shr 16 and $0000FF)
                +Pixel[1]*(Color1 shr 16 and $0000FF)
                +Pixel[2]*(Color2 shr 16 and $0000FF)) shr 8; // Blue
    Pixel[1]:=Green;
    Pixel[2]:=Red;
    Pixel:=pointer(integer(pixel)+3);
    end;
  inc(y);
  end
end;

procedure Sprite(Canvas: TCanvas; HGr,xDst,yDst,Width,Height,xGr,yGr: integer);
begin
BitBlt(Canvas.Handle,xDst,yDst,Width,Height,
  GrExt[HGr].Mask.Canvas.Handle,xGr,yGr,SRCAND);
BitBlt(Canvas.Handle,xDst,yDst,Width,Height,
  GrExt[HGr].Data.Canvas.Handle,xGr,yGr,SRCPAINT);
end;

procedure Sprite(dst:TBitmap; HGr,xDst,yDst,Width,Height,xGr,yGr: integer);
begin
BitBlt(dst.Canvas.Handle,xDst,yDst,Width,Height,
  GrExt[HGr].Mask.Canvas.Handle,xGr,yGr,SRCAND);
BitBlt(dst.Canvas.Handle,xDst,yDst,Width,Height,
  GrExt[HGr].Data.Canvas.Handle,xGr,yGr,SRCPAINT);
end;

procedure SLine(ca: TCanvas; x0,x1,y: integer; cl: TColor);
begin
with ca do
  begin
  Pen.Color:=cl; MoveTo(x0,y); LineTo(x1+1,y);
  end
end;

procedure DLine(ca: TCanvas; x0,x1,y: integer; cl0,cl1: TColor);
begin
with ca do
  begin
  Pen.Color:=cl0; MoveTo(x0,y); LineTo(x1,y);
  Pen.Color:=cl1; MoveTo(x0+1,y+1); LineTo(x1+1,y+1);
  Pixels[x0,y+1]:=cl0; Pixels[x1,y]:=cl1;
  end
end;

procedure Frame(ca: TCanvas;x0,y0,x1,y1:integer;cl0,cl1:TColor);
begin
with ca do
  begin
  MoveTo(x0,y1);
  Pen.Color:=cl0;LineTo(x0,y0);LineTo(x1,y0);
  Pen.Color:=cl1;LineTo(x1,y1);LineTo(x0,y1);
  end
end;

procedure RFrame(ca: TCanvas;x0,y0,x1,y1:integer;cl0,cl1:TColor);
begin
with ca do
  begin
  Pen.Color:=cl0;
  MoveTo(x0,y0+1);LineTo(x0,y1);
  MoveTo(x0+1,y0);LineTo(x1,y0);
  Pen.Color:=cl1;
  MoveTo(x1,y0+1);LineTo(x1,y1);
  MoveTo(x0+1,y1);LineTo(x1,y1);
  end
end;

procedure CFrame(ca: TCanvas; x0,y0,x1,y1,Corner: integer; cl: TColor);
begin
with ca do
  begin
  Pen.Color:=cl;
  MoveTo(x0,y0+Corner-1);LineTo(x0,y0);LineTo(x0+Corner,y0);
  MoveTo(x1,y0+Corner-1);LineTo(x1,y0);LineTo(x1-Corner,y0);
  MoveTo(x1,y1-Corner+1);LineTo(x1,y1);LineTo(x1-Corner,y1);
  MoveTo(x0,y1-Corner+1);LineTo(x0,y1);LineTo(x0+Corner,y1);
  end
end;

procedure FrameImage(ca: TCanvas; src:TBitmap; x,y,width,height,xSrc,ySrc: integer;
  IsControl: boolean = false);
begin
if IsControl then
  begin
  Frame(ca,x-1,y-1,x+width,y+height,$B0B0B0,$FFFFFF);
  RFrame(ca,x-2,y-2,x+width+1,y+height+1,$FFFFFF,$B0B0B0);
  end
else Frame(ca,x-1,y-1,x+width,y+height,$000000,$000000);
BitBlt(ca.Handle,x,y,width,height,src.Canvas.Handle,xSrc,ySrc,SRCCOPY);
end;

procedure GlowFrame(dst: TBitmap; x0,y0,width,height: integer; cl: TColor);
type
TLine=array[0..649,0..2] of Byte;
var
x,y,ch,r: integer;
DstLine: ^TLine;
begin
for y:=-GlowRange+1 to height-1+GlowRange-1 do
  begin
  DstLine:=dst.ScanLine[y0+y];
  for x:=-GlowRange+1 to width-1+GlowRange-1 do
    begin
    if x<0 then
      if y<0 then r:=round(sqrt(sqr(x)+sqr(y)))
      else if y>=height then r:=round(sqrt(sqr(x)+sqr(y-(height-1))))
      else r:=-x
    else if x>=width then
      if y<0 then r:=round(sqrt(sqr(x-(width-1))+sqr(y)))
      else if y>=height then r:=round(sqrt(sqr(x-(width-1))+sqr(y-(height-1))))
      else r:=x-(width-1)
    else if y<0 then r:=-y
    else if y>=height then r:=y-(height-1)
    else continue;
    if r=0 then r:=1;
    if r<GlowRange then
      for ch:=0 to 2 do
        DstLine[x0+x][2-ch]:=(DstLine[x0+x][2-ch]*(r-1)
          +(cl shr (8*ch) and $FF)*(GlowRange-r)) div (GlowRange-1);
    end;
  end
end;

procedure InitOrnament;
var
x,y,p,light,shade: integer;
begin
if InitOrnamentDone then exit;
light:=MainTexture.clBevelLight; // and $FCFCFC shr 2*3+MainTexture.clBevelShade and $FCFCFC shr 2;
shade:=MainTexture.clBevelShade and $FCFCFC shr 2*3+MainTexture.clBevelLight and $FCFCFC shr 2;
for x:=0 to wOrna-1 do for y:=0 to hOrna-1 do
  begin
  p:=GrExt[HGrSystem2].Data.Canvas.Pixels[xOrna+x,yOrna+y];
  if p=$0000FF then
    GrExt[HGrSystem2].Data.Canvas.Pixels[xOrna+x,yOrna+y]:=light
  else if p=$FF0000 then
    GrExt[HGrSystem2].Data.Canvas.Pixels[xOrna+x,yOrna+y]:=shade
  end;
InitOrnamentDone:=true
end;

procedure InitCityMark(const T: TTexture);
var
x,y,intensity: integer;
begin
for x:=0 to 9 do for y:=0 to 9 do
  if GrExt[HGrSystem].Mask.Canvas.Pixels[66+x,47+y]=0 then
    begin
    intensity:=GrExt[HGrSystem].Data.Canvas.Pixels[66+x,47+y] and $FF;
    GrExt[HGrSystem].Data.Canvas.Pixels[77+x,47+y]:=
      T.clMark and $FF *intensity div $FF
      +T.clMark shr 8 and $FF *intensity div $FF shl 8
      +T.clMark shr 16 and $FF *intensity div $FF shl 16
    end;
bitblt(GrExt[HGrSystem].Mask.Canvas.Handle,77,47,10,10,
  GrExt[HGrSystem].Mask.Canvas.Handle,66,47,SRCCOPY);
end;

procedure Fill(ca: TCanvas;Left,Top,Width,Height,xOffset,yOffset: integer);
begin
assert((left+xOffset>=0) and (left+xOffset+width<=wMainTexture)
  and (top+yOffset>=0) and (top+yOffset+height<=hMainTexture));
bitblt(ca.handle,left,top,width,height,MainTexture.Image.Canvas.Handle,left+xOffset,top+yOffset,SRCCOPY);
end;

procedure FillLarge(ca: TCanvas; x0,y0,x1,y1,xm: integer);

  function band(i: integer): integer;
  var
  n: integer;
  begin
  n:=((hMainTexture div 2) div (y1-y0))*2;
  while hMainTexture div 2+(i+1)*(y1-y0)>hMainTexture do
    dec(i,n);
  while hMainTexture div 2+i*(y1-y0)<0 do
    inc(i,n);
  result:=i;
  end;

var
i: integer;
begin
for i:=0 to (x1-xm) div wMainTexture-1 do
  bitblt(ca.handle,xm+i*wMainTexture,y0,wMainTexture,y1-y0,
    MainTexture.Image.canvas.handle,0,hMainTexture div 2+band(i)*(y1-y0),SRCCOPY);
bitblt(ca.handle,xm+((x1-xm) div wMainTexture)*wMainTexture,y0,
  x1-(xm+((x1-xm) div wMainTexture)*wMainTexture),y1-y0,
  MainTexture.Image.canvas.handle,0,
  hMainTexture div 2+band((x1-xm) div wMainTexture)*(y1-y0),SRCCOPY);
for i:=0 to (xm-x0) div wMainTexture-1 do
  bitblt(ca.handle,xm-(i+1)*wMainTexture,y0,wMainTexture,y1-y0,
  MainTexture.Image.canvas.handle,0,hMainTexture div 2+band(-i-1)*(y1-y0),SRCCOPY);
bitblt(ca.handle,x0,y0,xm-((xm-x0) div wMainTexture)*wMainTexture-x0,y1-y0,
  MainTexture.Image.canvas.handle,((xm-x0) div wMainTexture+1)*wMainTexture-(xm-x0),
  hMainTexture div 2+band(-(xm-x0) div wMainTexture-1)*(y1-y0),SRCCOPY);
end;

procedure FillSeamless(ca: TCanvas;Left,Top,Width,Height,xOffset,yOffset: integer;
  const Texture: TBitmap);
var
x,y,x0cut,y0cut,x1cut,y1cut: integer;
begin
while xOffset<0 do inc(xOffset,Texture.Width);
while yOffset<0 do inc(yOffset,Texture.Height);
for y:=(Top+yOffset) div Texture.Height to (Top+yOffset+Height-1) div Texture.Height do
  begin
  y0cut:=Top+yOffset-y*Texture.Height;
  if y0cut<0 then y0cut:=0;
  y1cut:=(y+1)*Texture.Height-(Top+yOffset+Height);
  if y1cut<0 then y1cut:=0;
  for x:=(Left+xOffset) div Texture.Width to (Left+xOffset+Width-1) div Texture.Width do
    begin
    x0cut:=Left+xOffset-x*Texture.Width;
    if x0cut<0 then x0cut:=0;
    x1cut:=(x+1)*Texture.Width-(Left+xOffset+Width);
    if x1cut<0 then x1cut:=0;
    BitBlt(ca.Handle,x*Texture.Width+x0cut-xOffset,y*Texture.Height+y0cut-yOffset,
      Texture.Width-x0cut-x1cut,Texture.Height-y0cut-y1cut,
      Texture.Canvas.Handle,x0cut,y0cut,SRCCOPY);
    end
  end;
end;

procedure FillRectSeamless(ca: TCanvas;x0,y0,x1,y1,xOffset,yOffset: integer;
  const Texture: TBitmap);
begin
FillSeamless(ca,x0,y0,x1-x0,y1-y0,xOffset,yOffset,Texture);
end;

procedure PaintBackground(Form: TForm; Left,Top,Width,Height: integer);
begin
Fill(Form.Canvas,Left,Top,Width,Height,(wMaintexture-Form.ClientWidth) div 2,
  (hMaintexture-Form.ClientHeight) div 2);
end;

procedure Corner(ca: TCanvas; x,y,Kind:integer; const T: TTexture);
begin
{BitBlt(ca.Handle,x,y,8,8,GrExt[T.HGr].Mask.Canvas.Handle,
  T.xGr+29+Kind*9,T.yGr+89,SRCAND);
BitBlt(ca.Handle,x,y,8,8,GrExt[T.HGr].Data.Canvas.Handle,
  T.xGr+29+Kind*9,T.yGr+89,SRCPAINT);}
end;

procedure BiColorTextOut(ca: TCanvas; clMain, clBack: TColor;
  x,y:integer; s:string);

  procedure PaintIcon(x,y,Kind: integer);
  begin
  BitBlt(ca.Handle,x,y+6,10,10,GrExt[HGrSystem].Mask.Canvas.Handle,
    66+Kind mod 11 *11,115+Kind div 11 *11,SRCAND);
  BitBlt(ca.Handle,x,y+6,10,10,GrExt[HGrSystem].Data.Canvas.Handle,
    66+Kind mod 11 *11,115+Kind div 11 *11,SRCPAINT);
  end;

var
p,xp: integer;
sp: string;
shadow: boolean;
begin
inc(x); inc(y);
for shadow:=true downto false do with ca do
  if not shadow or (clBack<>$7F007F) then
    begin
    if shadow then Font.Color:=clBack
    else Font.Color:=clMain;
    sp:=s;
    xp:=x;
    repeat
      p:=pos('%',sp);
      if (p=0) or (p+1>length(sp))
        or not (sp[p+1] in ['c','f','l','m','n','o','p','r','t','w']) then
        begin ca.Textout(xp,y,sp); break end
      else
        begin
        Textout(xp,y,copy(sp,1,p-1));
        inc(xp,ca.TextWidth(copy(sp,1,p-1)));
        if not shadow then
          case sp[p+1] of
            'c': PaintIcon(xp+1,y,6);
            'f': PaintIcon(xp+1,y,0);
            'l': PaintIcon(xp+1,y,8);
            'm': PaintIcon(xp+1,y,17);
            'n': PaintIcon(xp+1,y,7);
            'o': PaintIcon(xp+1,y,16);
            'p': PaintIcon(xp+1,y,2);
            'r': PaintIcon(xp+1,y,12);
            't': PaintIcon(xp+1,y,4);
            'w': PaintIcon(xp+1,y,13);
            end;
        inc(xp,10);
        delete(sp,1,p+1);
        end
    until false;
    dec(x); dec(y);
    end
end;

function BiColorTextWidth(ca: TCanvas; s: string): integer;
var
p: integer;
begin
result:=1;
repeat
  p:=pos('%',s);
  if (p=0) or (p=Length(s)) then
    begin inc(result,ca.TextWidth(s)); break end
  else
    begin
    if not (s[p+1] in ['c','f','l','m','n','o','p','r','t','w']) then
      inc(result,ca.TextWidth(copy(s,1,p+1)))
    else inc(result,ca.TextWidth(copy(s,1,p-1))+10);
    delete(s,1,p+1);
    end
until false;
end;

procedure LoweredTextOut(ca: TCanvas; cl: TColor; const T: TTexture;
  x,y:integer; s:string);
begin
if cl=-2 then
  BiColorTextOut(ca, (T.clBevelShade and $FEFEFE) shr 1, T.clBevelLight, x, y, s)
else if cl<0 then
  BiColorTextOut(ca, T.clTextShade, T.clTextLight, x, y, s)
else BiColorTextOut(ca, cl, T.clTextLight, x, y, s)
end;

procedure RisedTextOut(ca: TCanvas; x,y:integer; s:string);
begin
BiColorTextOut(ca, $FFFFFF, $000000, x, y, s)
end;

procedure Gradient(ca: TCanvas; x,y,dx,dy,width,height,Color:integer; Brightness: array of integer);
var
i,r,g,b: integer;
begin
with ca do
  begin
  for i:=0 to 15 do
    begin // gradient
    r:=Color and $FF+Brightness[i];
    if r<0 then r:=0
    else if r>=256 then r:=255;
    g:=Color shr 8 and $FF+Brightness[i];
    if g<0 then g:=0
    else if g>=256 then g:=255;
    b:=Color shr 16 and $FF+Brightness[i];
    if b<0 then b:=0
    else if b>=256 then b:=255;
    pen.color:=r+g shl 8+b shl 16;
    MoveTo(x+dx*i,y+dy*i);
    LineTo(x+dx*i+width,y+dy*i+height);
    end;
  pen.color:=$000000;
  MoveTo(x+1,y+16*dy+height);
  LineTo(x+16*dx+width,y+16*dy+height);
  LineTo(x+16*dx+width,y);
  end
end;

procedure LightGradient(ca: TCanvas; x,y,width,Color:integer);
const
Brightness: array[0..15] of integer=
(16,12,8,4,0,-4,-8,-12,-16,-20,-24,-28,-32,-36,-40,-44);
begin
Gradient(ca,x,y,0,1,width,0,Color,Brightness)
end;

procedure DarkGradient(ca: TCanvas; x,y,width,Kind:integer);
const
Brightness: array[0..15] of integer=
(16,12,8,4,0,-4,-8,-12-24,-16+16,-20,-24,-28,-32,-36,-40,-44);
begin
Gradient(ca,x,y,0,1,width,0,
  GrExt[HGrSystem].Data.Canvas.Pixels[187,137+Kind],Brightness)
end;

procedure VLightGradient(ca: TCanvas; x,y,height,Color:integer);
const
Brightness: array[0..15] of integer=
(16,12,8,4,0,-4,-8,-12,-16,-20,-24,-28,-32,-36,-40,-44);
begin
Gradient(ca,x,y,1,0,0,height,Color,Brightness)
end;

procedure VDarkGradient(ca: TCanvas; x,y,height,Kind:integer);
const
Brightness: array[0..15] of integer=
(16,12,8,4,0,-4,-8,-12-24,-16+16,-20,-24,-28,-32,-36,-40,-44);
begin
Gradient(ca,x,y,1,0,0,height,
  GrExt[HGrSystem].Data.Canvas.Pixels[187,137+Kind],Brightness)
end;

procedure NumberBar(dst:TBitmap; x,y:integer;
  Cap:string; val: integer; const T: TTexture);
var
s:string;
begin
if val>0 then
  begin
  DLine(dst.Canvas,x-2,x+170,y+16,T.clBevelShade,T.clBevelLight);
  LoweredTextOut(dst.Canvas,-1,T,x-2,y,Cap);
  s:=IntToStr(val);
  RisedTextout(dst.canvas,x+170-BiColorTextWidth(dst.Canvas,s),y,s);
  end
end;

procedure CountBar(dst:TBitmap; x,y,w:integer; Kind:integer;
  Cap:string; val: integer; const T: TTexture);
var
i,sd,ld,cl,xIcon,yIcon: integer;
s:string;
begin
//val:=random(40); //!!!
if val=0 then exit;
assert(Kind>=0);
with dst.Canvas do
  begin
//  xIcon:=x+100;
//  yIcon:=y;
//  DLine(dst.Canvas,x-2,x+170+32,y+16,T.clBevelShade,T.clBevelLight);

  xIcon:=x-5;
  yIcon:=y+15;
  DLine(dst.Canvas,x-2,xIcon+w+2,yIcon+16,T.clBevelShade,T.clBevelLight);

  s:=IntToStr(val);
  if val<0 then cl:=$0000FF
  else cl:=-1;
  LoweredTextOut(dst.Canvas,cl,T,x-2,y,Cap);
  LoweredTextout(dst.canvas,cl,T,xIcon+w+2-BiColorTextWidth(dst.Canvas,s),yIcon,s);

  if (Kind=12) and (val>=100) then
    begin // science with symbol for 100
    val:=val div 10;
    sd:=14*(val div 10+val mod 10-1);
    if sd=0 then sd:=1;
    if sd<w-44 then ld:=sd else ld:=w-44;
    for i:=0 to val mod 10-1 do
      begin
      BitBlt(Handle,xIcon+4+i*(14*ld div sd),yIcon+2+1,14,14,
        GrExt[HGrSystem].Mask.Canvas.Handle,
        67+Kind mod 8 *15,70+Kind div 8 *15,SRCAND);
      Sprite(dst,HGrSystem,xIcon+3+i*(14*ld div sd),yIcon+2,14,14,
        67+Kind mod 8 *15,70+Kind div 8 *15);
      end;
    for i:=0 to val div 10-1 do
      begin
      BitBlt(dst.Canvas.Handle,xIcon+4+(val mod 10)*(14*ld div sd)
        +i*(14*ld div sd),yIcon+3,14,14,
        GrExt[HGrSystem].Mask.Canvas.Handle,67+7 mod 8 *15,70+7 div 8 *15,
        SRCAND);
      Sprite(dst,HGrSystem,xIcon+3+(val mod 10)*(14*ld div sd)
        +i*(14*ld div sd),yIcon+2,14,14,67+7 mod 8 *15,70+7 div 8 *15);
      end;
    end
  else
    begin
    val:=abs(val);
    if val mod 10=0 then sd:=14*(val div 10-1)
    else sd:=10*(val mod 10-1)+14*(val div 10);
    if sd=0 then sd:=1;
    if sd<w-44 then ld:=sd else ld:=w-44;
    for i:=0 to val div 10-1 do
      begin
      BitBlt(Handle,xIcon+4+i*(14*ld div sd),yIcon+3,14,14,
        GrExt[HGrSystem].Mask.Canvas.Handle,67+Kind mod 8 *15,70+Kind div 8 *15,SRCAND);
      Sprite(dst,HGrSystem,xIcon+3+i*(14*ld div sd),yIcon+2,14,14,67+Kind mod 8 *15,
        70+Kind div 8 *15);
      end;
    for i:=0 to val mod 10-1 do
      begin
      BitBlt(dst.Canvas.Handle,xIcon+4+(val div 10)*(14*ld div sd)
        +i*(10*ld div sd),yIcon+7,10,10,GrExt[HGrSystem].Mask.Canvas.Handle,
        66+Kind mod 11 *11,115+Kind div 11 *11,SRCAND);
      Sprite(dst,HGrSystem,xIcon+3+(val div 10)*(14*ld div sd)
        +i*(10*ld div sd),yIcon+6,10,10,66+Kind mod 11 *11,115+Kind div 11 *11)
      end;
    end
  end
end; //CountBar

procedure PaintProgressBar(ca: TCanvas; Kind,x,y,pos,Growth,max: integer;
  const T: TTexture);
var
i: integer;
begin
if pos>max then pos:=max;
if Growth<0 then
  begin
  pos:=pos+Growth;
  if pos<0 then begin Growth:=Growth-pos; pos:=0 end
  end
else if pos+Growth>max then Growth:=max-pos;
Frame(ca,x-1,y-1,x+max,y+7,$000000,$000000);
RFrame(ca,x-2,y-2,x+max+1,y+8,T.clBevelShade,T.clBevelLight);
with ca do
  begin
  for i:=0 to pos div 8-1 do
    BitBlt(Handle,x+i*8,y,8,7,GrExt[HGrSystem].Data.Canvas.Handle,104,
      9+8*Kind,SRCCOPY);
  BitBlt(Handle,x+8*(pos div 8),y,
    pos-8*(pos div 8),7,GrExt[HGrSystem].Data.Canvas.Handle,104,9+8*Kind,SRCCOPY);
  if Growth>0 then
    begin
    for i:=0 to Growth div 8-1 do
      BitBlt(Handle,x+pos+i*8,y,8,7,GrExt[HGrSystem].Data.Canvas.Handle,112,
        9+8*Kind,SRCCOPY);
    BitBlt(Handle,x+pos+8*(Growth div 8),y,
      Growth-8*(Growth div 8),7,GrExt[HGrSystem].Data.Canvas.Handle,112,
      9+8*Kind,SRCCOPY);
    end
  else if Growth<0 then
    begin
    for i:=0 to -Growth div 8-1 do
      BitBlt(Handle,x+pos+i*8,y,8,7,GrExt[HGrSystem].Data.Canvas.Handle,104,1,
        SRCCOPY);
    BitBlt(Handle,x+pos+8*(-Growth div 8),y,
      -Growth-8*(-Growth div 8),7,GrExt[HGrSystem].Data.Canvas.Handle,104,1,
      SRCCOPY);
    end;
  Brush.Color:=$000000;
  FillRect(Rect(x+pos+abs(Growth),y,x+max,y+7));
  Brush.Style:=bsClear;
  end
end;

// pos and growth are relative to max, set size independent
procedure PaintRelativeProgressBar(ca: TCanvas; Kind,x,y,size,pos,Growth,
  max: integer; IndicateComplete: boolean; const T: TTexture);
begin
if Growth>0 then
  PaintProgressBar(ca,Kind,x,y,pos*size div max,
    (Growth*size+max div 2) div max,size,T)
else PaintProgressBar(ca,Kind,x,y,pos*size div max,
  (Growth*size-max div 2) div max,size,T);
if IndicateComplete and (pos+Growth>=max) then
  Sprite(ca, HGrSystem, x+size-10, y-7, 23, 16, 1, 129);
end;

procedure PaintLogo(ca: TCanvas; x,y,clLight,clShade: integer);
begin
BitBlt(LogoBuffer.Canvas.Handle,0,0,wLogo,hLogo,ca.handle,x,y,SRCCOPY);
ImageOp_BCC(LogoBuffer,Templates,0,0,1,1,wLogo,hLogo,clLight,clShade);
BitBlt(ca.handle,x,y,wLogo,hLogo,LogoBuffer.Canvas.Handle,0,0,SRCCOPY);
end;

function SetMainTextureByAge(Age: integer): boolean;
begin
if Age<>MainTextureAge then with MainTexture do
  begin
  MainTextureAge:=Age;
  LoadGraphicFile(Image,HomeDir+'Graphics\Texture'+inttostr(Age+1), gfJPG);
  clBevelLight:=Colors.Canvas.Pixels[clkAge0+Age,cliBevelLight];
  clBevelShade:=Colors.Canvas.Pixels[clkAge0+Age,cliBevelShade];
  clTextLight:=Colors.Canvas.Pixels[clkAge0+Age,cliTextLight];
  clTextShade:=Colors.Canvas.Pixels[clkAge0+Age,cliTextShade];
  clLitText:=Colors.Canvas.Pixels[clkAge0+Age,cliLitText];
  clMark:=Colors.Canvas.Pixels[clkAge0+Age,cliMark];
  clPage:=Colors.Canvas.Pixels[clkAge0+Age,cliPage];
  clCover:=Colors.Canvas.Pixels[clkAge0+Age,cliCover];
  result:=true
  end
else result:=false
end;


var
i,p,size: integer;
s: string;
fontscript: TextFile;
section: TFontType;
Reg: TRegistry;

initialization
Reg:=TRegistry.Create;
Reg.OpenKey('SOFTWARE\cevo\RegVer9',true);
try
  Gamma:=Reg.ReadInteger('Gamma');
except
  Gamma:=100;
  Reg.WriteInteger('Gamma',Gamma);
  end;
Reg.closekey;
Reg.Free;

if Gamma<>100 then
  begin
  GammaLUT[0]:=0;
  for i:=1 to 255 do
    begin
    p:=round(255.0*exp(ln(i/255.0)*100.0/Gamma));
    assert((p>=0) and (p<256));
    GammaLUT[i]:=p;
    end;
  end;

EnumDisplaySettings(nil, $FFFFFFFF, StartResolution);
ResolutionChanged:=false;

Phrases:=TStringTable.Create;
Phrases2:=TStringTable.Create;
Phrases2FallenBackToEnglish:=false;
if FileExists(DataDir+'Localization\Language.txt') then
  begin
  Phrases.LoadFromFile(DataDir+'Localization\Language.txt');
  if FileExists(DataDir+'Localization\Language2.txt') then
    Phrases2.LoadFromFile(DataDir+'Localization\Language2.txt')
  else
    begin
    Phrases2.LoadFromFile(HomeDir+'Language2.txt');
    Phrases2FallenBackToEnglish:=true;
    end
  end
else
  begin
  Phrases.LoadFromFile(HomeDir+'Language.txt');
  Phrases2.LoadFromFile(HomeDir+'Language2.txt');
  end;
Sounds:=TStringTable.Create;
if not Sounds.LoadFromFile(HomeDir+'Sounds\sound.txt') then
  begin Sounds.Free; Sounds:=nil end;

for section:=Low(TFontType) to High(TFontType) do
  UniFont[section]:=TFont.Create;

LogoBuffer:=TBitmap.Create;
LogoBuffer.PixelFormat:=pf24bit;
LogoBuffer.Width:=wBBook;
LogoBuffer.Height:=hBBook;

section:=ftNormal;
AssignFile(fontscript,LocalizedFilePath('Fonts.txt'));
try
  Reset(fontscript);
  while not eof(fontscript) do
    begin
    ReadLn(fontscript,s);
    if s<>'' then
      if s[1]='#' then
        begin
        s:=TrimRight(s);
        if s='#SMALL' then section:=ftSmall
        else if s='#TINY' then section:=ftTiny
        else if s='#CAPTION' then section:=ftCaption
        else if s='#BUTTON' then section:=ftButton
        else section:=ftNormal;
        end
      else
        begin
        p:=pos(',',s);
        if p>0 then
          begin
          UniFont[section].Name:=Trim(copy(s,1,p-1));
          size:=0;
          for i:=p+1 to length(s) do
            case s[i] of
              '0'..'9': size:=size*10+byte(s[i])-48;
              'B','b': UniFont[section].Style:=UniFont[section].Style+[fsBold];
              'I','i': UniFont[section].Style:=UniFont[section].Style+[fsItalic];
              end;
          UniFont[section].Size:=Round(size * 72/UniFont[section].PixelsPerInch);
          end
        end
    end;
  CloseFile(fontscript);
except
  end;

nGrExt:=0;
HGrSystem:=LoadGraphicSet('System');
HGrSystem2:=LoadGraphicSet('System2');
Templates:=TBitmap.Create;
LoadGraphicFile(Templates, HomeDir+'Graphics\Templates', gfNoGamma);
Templates.PixelFormat:=pf24bit;
Colors:=TBitmap.Create;
LoadGraphicFile(Colors,HomeDir+'Graphics\Colors');
Paper:=TBitmap.Create;
LoadGraphicFile(Paper,HomeDir+'Graphics\Paper',gfJPG);
BigImp:=TBitmap.Create;
LoadGraphicFile(BigImp, HomeDir+'Graphics\Icons');
MainTexture.Image:=TBitmap.Create;
MainTextureAge:=-2;
ClickFrameColor:=GrExt[HGrSystem].Data.Canvas.Pixels[187,175];
InitOrnamentDone:=false;
GenerateNames:=true;

finalization
RestoreResolution;
for i:=0 to nGrExt-1 do
  begin
  GrExt[i].Data.Free; GrExt[i].Mask.Free;
  FreeMem(GrExt[i]);
  end;
for section:=Low(TFontType) to High(TFontType) do
  UniFont[section].Free;
Phrases.Free;
if Sounds<>nil then Sounds.Free;
LogoBuffer.Free;
BigImp.Free;
Paper.Free;
Templates.Free;
Colors.Free;
MainTexture.Image.Free;

end.

