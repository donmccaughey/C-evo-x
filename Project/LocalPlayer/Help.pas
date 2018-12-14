{$INCLUDE switches}

unit Help;

interface

uses
  Protocol,ScreenTools,BaseWin,StringTables,

  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  ExtCtrls, ButtonB, PVSB, ButtonBase;

const
MaxHist=16;

{link categories}
hkNoLink=0;hkAdv=1;hkImp=2;hkTer=3;hkFeature=4;hkInternet=5;hkModel=6;hkMisc=7;
hkCrossLink=$40;
hkText=$80;

liInvalid=$3FFF; // link index indicates invalid link

{link indices for category hkMisc}
miscMain=0; miscCredits=1; miscGovList=2; miscJobList=3; miscSearchResult=7;

fJungle=8; // pseudo terrain


type
  THyperText=class(TStringList)
    procedure AddLine(s: String =''; Format: integer =0; Picpix: integer =0;
      LinkCategory: integer =0; LinkIndex: integer =0);
    procedure LF;
    end;

  THelpDlg = class(TFramedDlg)
    CloseBtn: TButtonB;
    BackBtn: TButtonB;
    TopBtn: TButtonB;
    SearchBtn: TButtonB;
    procedure FormCreate(Sender:TObject);
    procedure FormDestroy(Sender:TObject);
    procedure FormPaint(Sender:TObject);
    procedure CloseBtnClick(Sender:TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; x,
      y: integer);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; x, y: integer);
    procedure BackBtnClick(Sender: TObject);
    procedure TopBtnClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure SearchBtnClick(Sender: TObject);
  public
    Difficulty: integer;
    procedure ShowNewContent(NewMode,Category,Index: integer);
    procedure ClearHistory;
    function TextIndex(Item: string): integer;
  protected
    procedure OffscreenPaint; override;
  private
    Kind,no,Sel,nHist,CaptionColor: integer;
    hADVHELP, hIMPHELP, hFEATUREHELP, hGOVHELP, hSPECIALMODEL, hJOBHELP: integer;
    SearchContent, NewSearchContent: string;
    CaptionFont: TFont;
    MainText, SearchResult: THyperText;
    HelpText: TStringTable;
    ExtPic,TerrIcon: TBitmap;
    sb:TPVScrollbar;
    x0: array[-2..18] of integer;
    HistKind: array[0..MaxHist-1] of integer;
    HistNo: array[0..MaxHist-1] of integer;
    HistPos: array[0..MaxHist-1] of integer;
    HistSearchContent: array[0..MaxHist-1] of shortstring;
    procedure line(ca: TCanvas; i: integer; lit: boolean);
    procedure Prepare(sbPos: integer = 0);
    procedure WaterSign(x0,y0,iix: integer);
    procedure Search(SearchString: string);
    procedure OnScroll(var m:TMessage); message WM_VSCROLL;
    procedure OnMouseWheel(var m:TMessage); message WM_MOUSEWHEEL;
    procedure OnMouseLeave(var Msg:TMessage); message CM_MOUSELEAVE;
  end;

var
  HelpDlg: THelpDlg;

implementation

uses
Directories,ClientTools,Term,Tribes,ShellAPI, Inp,Messg;

{$R *.DFM}

type
THelpLineInfo=packed record
  Format, Picpix: Byte;
  Link: Word;
  end;

procedure THyperText.AddLine(s: String; Format: integer; Picpix: integer;
  LinkCategory: integer; LinkIndex: integer);
var
HelpLineInfo: THelpLineInfo;
begin
if LinkIndex<0 then LinkIndex:=liInvalid;
HelpLineInfo.Format:=Format;
HelpLineInfo.Picpix:=Picpix;
HelpLineInfo.Link:=LinkCategory shl 8+LinkIndex;
AddObject(s,TObject(HelpLineInfo));
end;

procedure THyperText.LF;
begin
AddLine;
end;


const
{text formats}
pkNormal=0;pkCaption=1;pkSmallIcon=2;pkBigIcon=3;pkAdvIcon=4;pkTer=5;
pkBigTer=6;pkFeature=7;pkDot=8;pkNormal_Dot=9;pkDomain=10;pkSection=11;
pkBigFeature=12;pkExp=13;pkAITStat=14;pkExternal=15;pkModel=16;pkNormal_64=17;
pkIllu=18;pkLogo=19;pkTerImp=20;pkRightIcon=21;pkAdvIcon_AsPreq=22;
pkSmallIcon_AsPreq=23;pkSpecialIcon=24;pkGov=25;

nSeeAlso=14;
SeeAlso: array[0..nSeeAlso-1] of record Kind,no,SeeKind,SeeNo: integer end=
((Kind:hkImp;no:imWalls;SeeKind:hkFeature;SeeNo:mcArtillery),
(Kind:hkImp;no:imHydro;SeeKind:hkImp;SeeNo:woHoover),
(Kind:hkImp;no:imWalls;SeeKind:hkImp;SeeNo:imGrWall),
(Kind:hkImp;no:imHighways;SeeKind:hkAdv;SeeNo:adWheel),
(Kind:hkImp;no:imCathedral;SeeKind:hkImp;SeeNo:woBach),
(Kind:hkImp;no:imBank;SeeKind:hkImp;SeeNo:imStockEx),
(Kind:hkImp;no:imShipComp;SeeKind:hkImp;SeeNo:imSpacePort),
(Kind:hkImp;no:imShipPow;SeeKind:hkImp;SeeNo:imSpacePort),
(Kind:hkImp;no:imShipHab;SeeKind:hkImp;SeeNo:imSpacePort),
(Kind:hkFeature;no:mcSub;SeeKind:hkFeature;SeeNo:mcRadar),
(Kind:hkFeature;no:mcDefense;SeeKind:hkAdv;SeeNo:adSteel),
(Kind:hkFeature;no:mcSE;SeeKind:hkFeature;SeeNo:mcNP),
(Kind:hkAdv;no:adWheel;SeeKind:hkImp;SeeNo:imHighways),
(Kind:hkAdv;no:adSteel;SeeKind:hkFeature;SeeNo:mcDefense));

nTerrainHelp=14;
TerrainHelp: array[0..nTerrainHelp-1] of integer=
(fGrass,fGrass+12,fPrairie,fForest,fJungle,fHills,fMountains,fSwamp,fTundra,fArctic,
fDesert,3*12{DeadLands},fShore,fOcean);

nJobHelp=8;
JobHelp: array[0..nJobHelp-1] of integer=
  (jRoad,jRR,jCanal,jIrr,jFarm,jMine,jFort,jBase);


procedure THelpDlg.FormCreate(Sender:TObject);
begin
inherited;
CaptionLeft:=BackBtn.Left+BackBtn.Width;
CaptionRight:=SearchBtn.Left;
inc(ModalFrameIndent,29);
MainText:=THyperText.Create;
SearchResult:=THyperText.Create;
CreatePVSB(sb,Handle,36,551,36+432);

HelpText:=TStringTable.Create;
HelpText.LoadFromFile(LocalizedFilePath('Help\help.txt'));
hADVHELP:=HelpText.Gethandle('ADVHELP');
hIMPHELP:=HelpText.Gethandle('IMPHELP');
hFEATUREHELP:=HelpText.Gethandle('FEATUREHELP');
hGOVHELP:=HelpText.Gethandle('GOVHELP');
hSPECIALMODEL:=HelpText.Gethandle('SPECIALMODEL');
hJOBHELP:=HelpText.Gethandle('JOBHELP');

CaptionFont:=Font.Create;
CaptionFont.Assign(UniFont[ftNormal]);
CaptionFont.Style:=CaptionFont.Style+[fsItalic,fsBold];
InitButtons();

TopBtn.Hint:=Phrases.Lookup('BTN_CONTENTS');
BackBtn.Hint:=Phrases.Lookup('BTN_BACK');
SearchBtn.Hint:=Phrases.Lookup('BTN_SEARCH');

ExtPic:=TBitmap.Create;
TerrIcon:=TBitmap.Create;
TerrIcon.PixelFormat:=pf24bit;
TerrIcon.Width:=xSizeBig; TerrIcon.Height:=ySizeBig;
SearchContent:='';
nHist:=-1;
end;

procedure THelpDlg.ClearHistory;
begin
nHist:=-1;
end;

procedure THelpDlg.FormDestroy(Sender:TObject);
begin
MainText.Free;
SearchResult.Free;
ExtPic.Free;
TerrIcon.Free;
HelpText.Free;
//CaptionFont.Free;
end;

procedure THelpDlg.CloseBtnClick(Sender:TObject);
begin
Close
end;

procedure THelpDlg.OnScroll(var m:TMessage);
begin
if ProcessPVSB(sb,m) then
  begin Sel:=-1; SmartUpdateContent(true) end
end;

procedure THelpDlg.OnMouseWheel(var m:TMessage);
begin
if ProcessMouseWheel(sb,m) then
  begin
  Sel:=-1;
  SmartUpdateContent(true);
  PaintBox1MouseMove(nil, [], m.lParam and $FFFF-Left, m.lParam shr 16-Top);
  end
end;

procedure THelpDlg.OnMouseLeave(var Msg:TMessage);
begin
if Sel<>-1 then
  begin
  line(Canvas,Sel,false);
  Sel:=-1
  end
end;

procedure THelpDlg.FormPaint(Sender:TObject);
begin
inherited;
Canvas.Font.Assign(UniFont[ftNormal]);
end;

procedure THelpDlg.line(ca: TCanvas; i: integer; lit: boolean);
var
TextColor,x,y: integer;
TextSize: TSize;
s: string;
begin
s:=MainText[sb.si.npos+i];
if s='' then exit;
x:=x0[i]; y:=2+i*24;
if ca=Canvas then
  begin x:=x+SideFrame; y:=y+WideFrame end;
if THelpLineInfo(MainText.Objects[sb.si.npos+i]).Format
  in [pkCaption,pkBigTer,pkRightIcon,pkBigFeature] then
  begin
  ca.Font.Assign(CaptionFont);
{  ca.brush.color:=CaptionColor;
  ca.FillRect(rect(x,i*24,x+24,i*24+24));
  ca.brush.color:=$FFFFFF;
  ca.FrameRect(rect(x+1,i*24+1,x+24-1,i*24+24-1));
  ca.Brush.Style:=bsClear;}
  BitBlt(ca.handle,x,y-4,24,24,GrExt[HGrSystem].Data.Canvas.Handle,1,146,SRCCOPY);
  BiColorTextOut(ca,$FFFFFF,$7F007F,x+10-ca.Textwidth(s[1]) div 2,y-3,s[1]);
  BiColorTextOut(ca,CaptionColor,$7F007F,x+24,y-3,copy(s,2,255));
  ca.Font.Assign(UniFont[ftNormal]);
  end
else if THelpLineInfo(MainText.Objects[sb.si.npos+i]).Format=pkSection then
  begin
  ca.Font.Assign(CaptionFont);
  BiColorTextOut(ca,CaptionColor,$7F007F,x,y-3,s);
  ca.Font.Assign(UniFont[ftNormal]);
  end
else
  begin
  if (Kind=hkMisc) and (no=miscMain) then
    ca.Font.Assign(CaptionFont);
  TextColor:=Colors.Canvas.Pixels[clkMisc,cliPaperText];
  if ca=Canvas then
    begin
    TextSize.cx:=BiColorTextWidth(ca,s);
    TextSize.cy:=ca.TextHeight(s);
    if y+TextSize.cy>=WideFrame+InnerHeight then
      TextSize.cy:=WideFrame+InnerHeight-y;
    FillSeamless(ca,x,y,TextSize.cx,TextSize.cy,-SideFrame,sb.si.npos*24-WideFrame,
      Paper);
    end;
  BiColorTextOut(ca,TextColor,$7F007F,x,y,s);
  if lit then with ca do
    begin
    assert(ca=Canvas);
    pen.color:=TextColor;
    moveto(x+1,y+TextSize.cy-2);
    lineto(x+TextSize.cx,y+TextSize.cy-2);
    end;
  if (Kind=hkMisc) and (no=miscMain) then
    ca.Font.Assign(UniFont[ftNormal]);
  end
end;

procedure THelpDlg.WaterSign(x0,y0,iix: integer);
const
nHeaven=28;
maxsum=9*9*255 *75 div 100;
type
TLine=array[0..649,0..2] of Byte;
var
x,y,dx,dy,xSrc,ySrc,sum,xx: integer;
Heaven: array[0..nHeaven] of integer;
PaintLine,CoalLine: ^TLine;
ImpLine: array[-1..1] of ^TLine;
begin
// assume eiffel tower has free common heaven
for dy:=0 to nHeaven-1 do
  Heaven[dy]:=BigImp.Canvas.Pixels[woEiffel mod 7 *xSizeBig,
    (SystemIconLines+woEiffel div 7)*ySizeBig+dy];

xSrc:=iix mod 7 *xSizeBig;
ySrc:=(iix div 7+1) *ySizeBig;
for y:=0 to ySizeBig*2-1 do if (y0+y>=0) and (y0+y<InnerHeight) then
  begin
  PaintLine:=OffScreen.ScanLine[y0+y];
  CoalLine:=Templates.ScanLine[yCoal+y];
  for dy:=-1 to 1 do
    if ((y+dy) shr 1>=0) and ((y+dy) shr 1<ySizeBig) then
      ImpLine[dy]:=BigImp.ScanLine[ySrc+(y+dy) shr 1];
  for x:=0 to xSizeBig*2-1 do
    begin
    sum:=0;
    for dx:=-1 to 1 do
      begin
      xx:=xSrc+(x+dx) shr 1;
      for dy:=-1 to 1 do
        if ((y+dy) shr 1<0) or ((y+dy) shr 1>=ySizeBig)
          or ((x+dx) shr 1<0) or ((x+dx) shr 1>=xSizeBig)
          or ((y+dy) shr 1<nHeaven)
          and (ImpLine[dy,xx,0] shl 16+ImpLine[dy,xx,1] shl 8+ImpLine[dy,xx,2]=Heaven[(y+dy) shr 1]) then
          sum:=sum+9*255
        else sum:=sum+ImpLine[dy,xx,0]+5*ImpLine[dy,xx,1]+3*ImpLine[dy,xx,2];
      end;
    if sum<maxsum then
      begin // no saturation
      sum:=1 shl 22 - (maxsum-sum)*(256-CoalLine[xCoal+x,0]*2);
      PaintLine[x0+x,0]:=PaintLine[x0+x,0]*sum shr 22;
      PaintLine[x0+x,1]:=PaintLine[x0+x,1]*sum shr 22;
      PaintLine[x0+x,2]:=PaintLine[x0+x,2]*sum shr 22;
      end
    end
  end;
end;

procedure THelpDlg.OffscreenPaint;

  procedure PaintTerrIcon(x,y,xSrc,ySrc: integer);
  begin
  Frame(offscreen.canvas,x-1,y-1,x+xSizeBig,y+ySizeBig,$000000,$000000);
  if 2*yyt<40 then
    begin
    Sprite(Offscreen, HGrTerrain, x, y, 56, 2*yyt, xSrc, ySrc);
    Sprite(Offscreen, HGrTerrain, x, y+2*yyt, 56, 40-2*yyt, xSrc, ySrc);
    end
  else Sprite(Offscreen, HGrTerrain, x, y, 56, 40, xSrc, ySrc);
  Sprite(Offscreen, HGrTerrain, x, y, xxt, yyt, xSrc+xxt, ySrc+yyt);
  Sprite(Offscreen, HGrTerrain, x, y+yyt, xxt, 40-yyt, xSrc+xxt, ySrc);
  Sprite(Offscreen, HGrTerrain, x+xxt, y, 56-xxt, yyt, xSrc, ySrc+yyt);
  Sprite(Offscreen, HGrTerrain, x+xxt, y+yyt, 56-xxt, 40-yyt, xSrc, ySrc);
  end;

var
i,j,yl,srcno,ofs,cnt,y: integer;
s: string;
HelpLineInfo: THelpLineInfo;
begin
inherited;
CaptionColor:=Colors.Canvas.Pixels[clkMisc,cliPaperCaption];
FillSeamless(offscreen.Canvas,0,0,InnerWidth,InnerHeight,0,sb.si.npos*24,
  Paper);
with offscreen.Canvas do
  begin
  Font.Assign(UniFont[ftNormal]);
  for i:=-sb.si.npos to InnerHeight div 24 do
    if sb.si.npos+i<MainText.Count then
      begin
      HelpLineInfo:=THelpLineInfo(MainText.Objects[sb.si.npos+i]);
      if HelpLineInfo.Format=pkExternal then
        begin
        yl:=ExtPic.Height;
        if 4+i*24+yl>InnerHeight then yl:=InnerHeight-(4+i*24);
        BitBlt(Handle,8,4+i*24,ExtPic.Width,yl,
          ExtPic.Canvas.Handle,0,0,SRCCOPY);
        end
      end;
  for i:=-2 to InnerHeight div 24 do
    if (sb.si.npos+i>=0) and (sb.si.npos+i<MainText.Count) then
      begin
      HelpLineInfo:=THelpLineInfo(MainText.Objects[sb.si.npos+i]);
      if HelpLineInfo.Link<>0 then
        begin
        if (Kind=hkMisc) and (no=miscSearchResult) then
          Sprite(offscreen,HGrSystem,18,9+i*24,8,8,90,16)
        else if HelpLineInfo.Format in [pkSmallIcon_AsPreq,pkAdvIcon_AsPreq] then
          Sprite(offscreen,HGrSystem,12,i*24+5,14,14,65,20)
        else if HelpLineInfo.Link and (hkCrossLink shl 8)<>0 then
          Sprite(offscreen,HGrSystem,12,i*24+5,14,14,80,1)
        else if not ((Kind=hkMisc) and (no=miscMain)) then
          Sprite(offscreen,HGrSystem,10,i*24+6,14,14,65,1);
        x0[i]:=24;
        end
      else x0[i]:=0;
      case HelpLineInfo.Format of
        pkLogo:
          begin
          Server(sGetVersion,0,0,j);
          s:=Format('%d.%d.%d',[j shr 16 and $FF, j shr 8 and $FF, j and $FF]);
          PaintLogo(offscreen.canvas,(InnerWidth-122) div 2,i*24+1,
            GrExt[HGrSystem].Data.Canvas.Pixels[95,1],$000000);
          Font.Assign(UniFont[ftSmall]);
          BiColorTextout(offscreen.Canvas,$000000,$7F007F,
            (InnerWidth-TextWidth(s)) div 2,i*24+26,s);
          Font.Assign(UniFont[ftNormal]);
          end;
        pkSmallIcon,pkSmallIcon_AsPreq:
          begin
          Frame(offscreen.Canvas,8-1+x0[i],2-1+i*24,8+xSizeSmall+x0[i],2+20+i*24,
            $000000,$000000);
          if HelpLineInfo.Picpix=imPalace then
            BitBlt(offscreen.Canvas.Handle,8+x0[i],2+i*24,xSizeSmall,ySizeSmall,SmallImp.Canvas.Handle,
              0*xSizeSmall,1*ySizeSmall,SRCCOPY)
          else BitBlt(offscreen.Canvas.Handle,8+x0[i],2+i*24,xSizeSmall,ySizeSmall,SmallImp.Canvas.Handle,
            HelpLineInfo.Picpix mod 7*xSizeSmall,(HelpLineInfo.Picpix+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY);
          x0[i]:=x0[i]+(8+8+36);
          end;
        pkBigIcon:
          begin
          FrameImage(offscreen.canvas,BigImp,x0[i]+12,i*24-7,56,40,
            HelpLineInfo.Picpix mod 7*xSizeBig,
            HelpLineInfo.Picpix div 7*ySizeBig);
          x0[i]:=64+8+8+x0[i];
          end;
        pkSpecialIcon:
          begin
          case HelpLineInfo.Picpix of
            0:
              FrameImage(Offscreen.Canvas, GrExt[HGrSystem2].Data, 12+x0[i],-7+i*24, 56, 40, 137, 127);
            1:
              begin
              PaintTerrIcon(12+x0[i],-7+i*24, 1+3*(xxt*2+1), 1+yyt);
              if 2*yyt<40 then
                Sprite(Offscreen, HGrTerrain, 12+x0[i],-7+4+i*24, 56, 2*yyt, 1+3*(xxt*2+1)+xxt-28, 1+yyt+1*(yyt*3+1))
              else Sprite(Offscreen, HGrTerrain, 12+x0[i],-7+4+i*24-4, 56, 40, 1+3*(xxt*2+1)+xxt-28, 1+yyt+1*(yyt*3+1)+yyt-20);
              end;
            2:
              begin
              PaintTerrIcon(12+x0[i],-7+i*24, 1+7*(xxt*2+1), 1+yyt+4*(yyt*3+1));
              if 2*yyt<40 then
                Sprite(Offscreen, HGrTerrain, 12+x0[i],-7+4+i*24, 56, 32, 1+4*(xxt*2+1)+xxt-28, 1+yyt+12*(yyt*3+1)+yyt-16)
              else Sprite(Offscreen, HGrTerrain, 12+x0[i],-7+4+i*24, 56, 32, 1+4*(xxt*2+1)+xxt-28, 1+yyt+12*(yyt*3+1)+yyt-16)
              end;
            end;
          x0[i]:=64+8+8+x0[i];
          end;
        pkDomain:
          begin
          Frame(offscreen.Canvas,8-1+x0[i],2-1+i*24,8+36+x0[i],2+20+i*24,
            $000000,$000000);
          Dump(offscreen,HGrSystem,8+x0[i],2+i*24,36,20,
            75+HelpLineInfo.Picpix*37,295);
          x0[i]:=x0[i]+(8+8+36);
          end;
        pkAdvIcon,pkAdvIcon_AsPreq:
          begin
          Frame(offscreen.Canvas,8-1+x0[i],2-1+i*24,8+xSizeSmall+x0[i],2+ySizeSmall+i*24,
            $000000,$000000);
          if AdvIcon[HelpLineInfo.Picpix]<84 then
            BitBlt(offscreen.Canvas.Handle,8+x0[i],2+i*24,xSizeSmall,ySizeSmall,
              SmallImp.Canvas.Handle, (AdvIcon[HelpLineInfo.Picpix]+SystemIconLines*7) mod 7*xSizeSmall,
              (AdvIcon[HelpLineInfo.Picpix]+SystemIconLines*7) div 7*ySizeSmall,SRCCOPY)
          else
            Dump(offscreen,HGrSystem,8+x0[i],2+i*24,36,20,
              1+(AdvIcon[HelpLineInfo.Picpix]-84) mod 8*37,
              295+(AdvIcon[HelpLineInfo.Picpix]-84) div 8*21);
          j:=AdvValue[HelpLineInfo.Picpix] div 1000;
          BitBlt(Handle,x0[i]+4,4+i*24,14,14,
            GrExt[HGrSystem].Mask.Canvas.Handle,127+j*15,85,SRCAND);
          Sprite(offscreen,HGrSystem,x0[i]+3,3+i*24,14,14,127+j*15,85);
          x0[i]:=x0[i]+(8+8+36);
          end;
        pkRightIcon:
          begin
          if Imp[HelpLineInfo.Picpix].Kind<>ikWonder then
            ImpImage(Offscreen.Canvas,InnerWidth-(40+xSizeBig),i*24,
              HelpLineInfo.Picpix, gDespotism)
          else WaterSign(InnerWidth-(40+2*xSizeBig),i*24-8,HelpLineInfo.Picpix+7);
          x0[i]:=x0[i]+8;
          end;
        pkIllu:
          WaterSign(8,i*24-8,HelpLineInfo.Picpix);
        pkBigFeature:
          begin
          cnt:=0;
          for j:=nDomains-1 downto 0 do
            if 1 shl j and Feature[HelpLineInfo.Picpix].Domains<>0 then
              begin
              inc(cnt);
              Dump(offscreen,HGrSystem,InnerWidth-38-38*cnt,i*24+1,36,20,75+j*37,295);
              Frame(offscreen.canvas,InnerWidth-39-38*cnt,i*24,
                InnerWidth-2-38*cnt,i*24+21,
                $000000,$000000);
              end;
          DarkGradient(offscreen.Canvas,InnerWidth-38-38*cnt,i*24+23,cnt*38-2,1);
          ofs:=InnerWidth-(39+7)-19*cnt;
          with offscreen.Canvas do
            begin
            Brush.Color:=$C0C0C0;
            FrameRect(Rect(ofs,1+23+i*24,ofs+14,15+23+i*24));
            Brush.Style:=bsClear;
            Sprite(offscreen,HGrSystem,ofs+2,3+23+i*24,10,10,
              66+HelpLineInfo.Picpix mod 11 *11,
              137+HelpLineInfo.Picpix div 11 *11);
            end;
          x0[i]:=x0[i]+8;
          end;
        pkTer,pkBigTer:
          begin
          if HelpLineInfo.Format=pkBigTer then
            y:=i*24-3+yyt
          else y:=i*24+13;
          if HelpLineInfo.Picpix>=3*12 then srcno:=2*9+6
          else if HelpLineInfo.Picpix mod 12=fJungle then srcno:=18*9
          else if HelpLineInfo.Picpix mod 12<fJungle then
            srcno:=HelpLineInfo.Picpix mod 12
          else srcno:=27+(HelpLineInfo.Picpix mod 12-9)*18;
          if HelpLineInfo.Format=pkTer then
            begin ofs:=x0[i]+8; x0[i]:=2*xxt+8+ofs; end
          else begin ofs:=InnerWidth-(2*xxt+38); x0[i]:=x0[i]+8; end;
          if srcno>=fJungle then
            begin
            Sprite(offscreen,HGrTerrain,ofs+4,y-yyt+2,xxt*2-8,yyt*2-4,
              5+2*(xxt*2+1),3+yyt+2*(yyt*3+1));
            Sprite(offscreen,HGrTerrain,ofs,y-2*yyt,xxt*2,yyt*3-2,
              1+srcno mod 9 *(xxt*2+1),1+srcno div 9 *(yyt*3+1));
            end
          else Sprite(offscreen,HGrTerrain,ofs+4,y-yyt+2,xxt*2-8,yyt*2-4,
            5+srcno mod 9 *(xxt*2+1),3+yyt+srcno div 9 *(yyt*3+1));
          if HelpLineInfo.Picpix>=3*12 then {rare resource}
            Sprite(offscreen,HGrTerrain,ofs,y-2*yyt,xxt*2,yyt*3,
              1+8*(xxt*2+1), 1+(HelpLineInfo.Picpix-2*12)*(yyt*3+1))
          else if HelpLineInfo.Picpix>=12 then {special tile}
            begin
            if HelpLineInfo.Picpix mod 12=fJungle then srcno:=17*9+8
            else if HelpLineInfo.Picpix mod 12<fJungle then
              srcno:=HelpLineInfo.Picpix mod 12
            else srcno:=18+8+(HelpLineInfo.Picpix mod 12-9)*18;
            srcno:=srcno+HelpLineInfo.Picpix div 12*9;
            Sprite(offscreen,HGrTerrain,ofs,y-2*yyt,xxt*2,yyt*3,
              1+srcno mod 9 *(xxt*2+1),1+srcno div 9 *(yyt*3+1));
            end;
          end;
        pkTerImp:
          begin
          ofs:=8;
          if HelpLineInfo.Picpix=5 then
            begin // display mine on hills
            Sprite(offscreen,HGrTerrain,ofs+4,i*24+13-yyt,xxt*2-8,yyt*2-4,
              5+2*(xxt*2+1),3+yyt+2*(yyt*3+1));
            srcno:=45
            end
          else srcno:=fPrairie; // display on prairie
          Sprite(offscreen,HGrTerrain,ofs+4,i*24+13-yyt,xxt*2-8,yyt*2-4,
            5+srcno mod 9 *(xxt*2+1),3+yyt+srcno div 9 *(yyt*3+1));
          if HelpLineInfo.Picpix=12 then {river}
            Sprite(offscreen,HGrTerrain,ofs,i*24+11-yyt,xxt*2,yyt*2,1+5*(xxt*2+1),
              1+yyt+13*(yyt*3+1))
          else if HelpLineInfo.Picpix>=3 then {improvement 2}
            begin
            if HelpLineInfo.Picpix=6 then
              Sprite(offscreen,HGrTerrain,ofs,i*24+11-2*yyt,xxt*2,yyt*3,
                1+7 *(xxt*2+1),1+12 *(yyt*3+1));
            Sprite(offscreen,HGrTerrain,ofs,i*24+11-2*yyt,xxt*2,yyt*3,
              1+(HelpLineInfo.Picpix-3)*(xxt*2+1), 1+12*(yyt*3+1))
            end
          else {improvement 1}
            begin
            Sprite(offscreen,HGrTerrain,ofs,i*24+11-2*yyt,xxt*2,yyt*3,
              1+2*(xxt*2+1),1+(9+HelpLineInfo.Picpix)*(yyt*3+1));
            Sprite(offscreen,HGrTerrain,ofs,i*24+11-2*yyt,xxt*2,yyt*3,
              1+5*(xxt*2+1),1+(9+HelpLineInfo.Picpix)*(yyt*3+1))
            end;
          x0[i]:=x0[i]+8;
          end;
        pkModel:
          begin
          FrameImage(offscreen.canvas,BigImp,x0[i]+12,i*24-7,56,40,0,0);
          Sprite(offscreen,HGrStdUnits,x0[i]+8,i*24-11,64,44,
            1+HelpLineInfo.Picpix mod 10 *65,1+HelpLineInfo.Picpix div 10 *49);
          x0[i]:=64+8+8+x0[i];
          end;
        pkFeature:
          begin
          DarkGradient(offscreen.Canvas,x0[i]+8-1,7+i*24-3,16,1);
          Frame(offscreen.canvas,x0[i]+8,7+i*24-2,x0[i]+8+13,7+i*24-2+13,
            $C0C0C0,$C0C0C0);
          Sprite(offscreen,HGrSystem,x0[i]+8+2,7+i*24,10,10,
            66+HelpLineInfo.Picpix mod 11*11,137+HelpLineInfo.Picpix div 11*11);
          x0[i]:=x0[i]+8+8+2+13;
          end;
        pkExp:
          begin
          Frame(offscreen.Canvas,20-1,8-4+i*24,20+12,8+11+i*24,$000000,$000000);
          Dump(offscreen,HGrSystem,20,8-3+i*24,12,14,121+HelpLineInfo.Picpix*13,28);
          x0[i]:=20+8+11;
          end;
        pkAITStat:
          begin
          Sprite(offscreen,HGrSystem,20,6+i*24,14,14,1+HelpLineInfo.Picpix*15,316);
          x0[i]:=20+8+11;
          end;
        pkGov:
          begin
          Frame(offscreen.Canvas,8-1+x0[i],2-1+i*24,8+xSizeSmall+x0[i],2+20+i*24,
            $000000,$000000);
          BitBlt(offscreen.Canvas.Handle,8+x0[i],2+i*24,xSizeSmall,ySizeSmall,SmallImp.Canvas.Handle,
            (HelpLineInfo.Picpix-1)*xSizeSmall,ySizeSmall,SRCCOPY);
          x0[i]:=x0[i]+(8+8+36);
          end;
        pkDot:
          begin
          Sprite(offscreen,HGrSystem,x0[i]+18,9+i*24,8,8,81,16);
          x0[i]:=20+8+4;
          end;
        pkNormal_Dot:
          x0[i]:=20+8+4;
        pkNormal_64:
          x0[i]:=64+8+8;
        else x0[i]:=x0[i]+8
        end;
      line(offscreen.Canvas,i,false)
      end
  end;
MarkUsedOffscreen(InnerWidth,InnerHeight+13+48);
end; {OffscreenPaint}

procedure THelpDlg.Prepare(sbPos: integer = 0);
var
i,j,special,Domain,Headline,TerrType,TerrSubType: integer;
s: string;
ps: pchar;
List: THyperText;
CheckSeeAlso: boolean;

  procedure AddAdv(i: integer);
  begin
  MainText.AddLine(Phrases.Lookup('ADVANCES',i),pkAdvIcon,i,hkAdv+hkCrossLink,i);
  end;

  procedure AddPreqAdv(i: integer);
  begin
  MainText.AddLine(Phrases.Lookup('ADVANCES',i),pkAdvIcon_AsPreq,i,hkAdv+hkCrossLink,i);
  end;

  procedure AddImp(i: integer);
  begin
  MainText.AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon,i,hkImp+hkCrossLink,i);
  end;

  procedure AddPreqImp(i: integer);
  begin
  MainText.AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon_AsPreq,i,hkImp+hkCrossLink,i);
  end;

  procedure AddTer(i: integer);
  begin
  if MainText.Count>1 then begin MainText.LF; end;
  MainText.AddLine(Phrases.Lookup('TERRAIN',i),pkTer,i,hkTer,i);
  end;

  procedure AddFeature(i: integer);
  begin
  MainText.AddLine(Phrases.Lookup('FEATURES',i),pkFeature,i,hkFeature+hkCrossLink,i);
  end;

  procedure AddModel(i: integer);
  var
  pix: integer;
  Name: string;
  begin
  if MainText.Count>1 then MainText.LF;
  FindStdModelPicture(SpecialModelPictureCode[i],pix,Name);
  MainText.AddLine(Name,pkModel,pix,hkModel+hkCrossLink,i)
  end;

  procedure AddStandardBlock(Item: string);
  var
  i: integer;
  begin
  with MainText do
    begin
    if Item='LOGO' then
      begin AddLine('',pkLogo); LF; end
    else if Item='TECHFORMULA' then
      begin
      i:=Difficulty;
      if i=0 then i:=2;
      AddLine(Format(HelpText.Lookup('TECHFORMULA'),[TechFormula_M[i],TechFormula_D[i]]))
      end
    else if Item='EXPERIENCE' then
      for i:=0 to nExp-1 do AddLine(Phrases.Lookup('EXPERIENCE',i),pkExp,i)
    else if Item='MODERN' then
      for i:=1 to 3 do
        begin
        LF;
        AddLine(Phrases.Lookup('TERRAIN',3*12+i),pkTer,3*12+i);
        end
    else if Item='SAVED' then
      AddLine(DataDir+'Saved',pkNormal)
    else if Item='AITSTAT' then
      for i:=0 to 3 do AddLine(Phrases2.Lookup('AITSTAT',i),pkAITStat,i)
    end
  end;

  procedure DecodeItem(s: string; var Category, Index: integer);
  var
  i: integer;
  begin
  if (length(s)>0) and (s[1]=':') then
    begin
    Category:=hkMisc;
    Index:=0;
    for i:=3 to Length(s) do Index:=Index*10+ord(s[i])-48;
    case s[2] of
      'A': Category:=hkAdv;
      'B': Category:=hkImp;
      'T': Category:=hkTer;
      'F': Category:=hkFeature;
      'E': Category:=hkInternet;
      'S': Category:=hkModel;
      'C': Index:=miscCredits;
      'J': Index:=miscJobList;
      'G': Index:=miscGovList;
      end;
    if (Category<>hkMisc) and (Index=0) then
      Index:=200;
    end
  else
    begin
    Category:=hkText;
    Index:=HelpText.GetHandle(copy(s,1,255));
    end;
  end;

  procedure AddText(s: string);
  var
  i,p,l,ofs,CurrentFormat,FollowFormat,Picpix,LinkCategory,LinkIndex,RightMargin: integer;
  Name: string;
  begin
  RightMargin:=InnerWidth-16-GetSystemMetrics(SM_CXVSCROLL);
  FollowFormat:=pkNormal;
  while s<>'' do
    begin
    Picpix:=0;
    LinkCategory:=0;
    LinkIndex:=0;
    if s[1]='$' then
      begin // window caption
      p:=1;
      repeat inc(p) until (p>Length(s)) or (s[p]='\');
      Caption:=Copy(s,2,p-2);
      Delete(s,1,p);
      end
    else if s[1]='&' then
      begin // standard block
      p:=1;
      repeat inc(p) until (p>Length(s)) or (s[p]='\');
      AddStandardBlock(Copy(s,2,p-2));
      Delete(s,1,p);
      end
    else if s[1]='@' then
      begin // image
      if (Length(s)>=2) and (s[2]='@') then
        begin // generate from icon
        Picpix:=0;
        p:=3;
        while (p<=Length(s)) and (s[p]<>'\') do
          begin Picpix:=Picpix*10+ord(s[p])-48; inc(p) end;
        if (Picpix<0) or (Picpix>=nImp) then Picpix:=0;
        MainText.AddLine('',pkIllu,Picpix);
        MainText.LF;
        MainText.LF;
        end
      else
        begin // external image
        p:=1;
        repeat inc(p) until (p>Length(s)) or (s[p]='\');
        if LoadLocalizedGraphicFile(ExtPic, 'Help\'+Copy(s,2,p-2)) then
          begin
          MainText.AddLine('',pkExternal);
          for i:=0 to (ExtPic.Height-12) div 24 do MainText.LF;
          end;
        end;
      Delete(s,1,p);
      end
    else
      begin
      case s[1] of
        ':',';':
          begin // link
          p:=1;
          repeat inc(p) until (p>Length(s)) or (s[p]='\') or (s[p]=' ');
          DecodeItem(copy(s,2,p-2), LinkCategory, LinkIndex);
          CurrentFormat:=0;
          if (LinkCategory<>hkText) and (LinkIndex<200) then // show icon
            case LinkCategory of
              hkAdv:
                begin CurrentFormat:=pkAdvIcon; Picpix:=LinkIndex end;
              hkImp:
                begin CurrentFormat:=pkSmallIcon; Picpix:=LinkIndex end;
              hkTer:
                begin CurrentFormat:=pkTer; Picpix:=LinkIndex end;
              hkFeature:
                begin CurrentFormat:=pkFeature; Picpix:=LinkIndex end;
              hkModel:
                begin
                CurrentFormat:=pkModel;
                FindStdModelPicture(SpecialModelPictureCode[LinkIndex],Picpix,Name);
                end;
              end;
          if s[1]=':' then LinkCategory:=LinkCategory+hkCrossLink;
          if (p>Length(s)) or (s[p]=' ') then Delete(s,1,p)
          else Delete(s,1,p-1)
          end;
        '!': // highlited
          if (length(s)>=2) and (s[2]='!') then
            begin
            if MainText.Count>1 then MainText.LF;
            FollowFormat:=pkCaption;
            CurrentFormat:=pkCaption;
            Delete(s,1,2);
            end
          else
            begin
            FollowFormat:=pkSection;
            CurrentFormat:=pkSection;
            Delete(s,1,1);
            end;
        '-':
          begin // list
          FollowFormat:=pkNormal_Dot;
          CurrentFormat:=pkDot;
          Delete(s,1,1);
          end;
        else CurrentFormat:=FollowFormat;
        end;
      if FollowFormat=pkNormal_Dot then ofs:=20+4+8
      else ofs:=8;
      p:=0;
      repeat
        repeat inc(p) until (p>Length(s)) or (s[p]=' ') or (s[p]='\');
        if (BiColorTextWidth(Offscreen.Canvas,Copy(s,1,p-1))<=RightMargin-ofs) then
          l:=p-1
        else Break;
      until (p>=Length(s)) or (s[l+1]='\');
      MainText.AddLine(Copy(s,1,l),CurrentFormat,Picpix,LinkCategory,LinkIndex);
      if (l<Length(s)) and (s[l+1]='\') then FollowFormat:=pkNormal;
      Delete(s,1,l+1);
      end
    end
  end;

  procedure AddItem(Item: string);
  begin
  AddText(HelpText.Lookup(Item));
  end;

  procedure AddModelText(i: integer);
  var
  pix: integer;
  s: string;
  begin
  with MainText do
    begin
    if Count>1 then begin LF; LF; end;
    FindStdModelPicture(SpecialModelPictureCode[i],pix,s);
    AddLine(s,pkSection);
    AddLine(Format(HelpText.Lookup('STRENGTH'),
      [SpecialModel[i].Attack,SpecialModel[i].Defense]),pkNormal_64);
    AddLine(Format(HelpText.Lookup('SPEED'),
      [MovementToString(SpecialModel[i].Speed)]),pkModel,pix);
    if Difficulty=0 then
      AddLine(Format(HelpText.Lookup('BUILDCOST'),
        [SpecialModel[i].Cost]),pkNormal_64)
    else AddLine(Format(HelpText.Lookup('BUILDCOST'),
      [SpecialModel[i].Cost*BuildCostMod[Difficulty] div 12]),pkNormal_64);
    s:=HelpText.LookupByHandle(hSPECIALMODEL,i);
    if (s<>'') and (s<>'*') then AddText(s);
    if SpecialModelPreq[i]>=0 then AddPreqAdv(SpecialModelPreq[i])
    else if SpecialModelPreq[i]=preLighthouse then AddPreqImp(woLighthouse)
    else if SpecialModelPreq[i]=preBuilder then AddPreqImp(woPyramids)
    else if SpecialModelPreq[i]=preLeo then AddPreqImp(woLeo);
    if SpecialModelPreq[i]<>preNone then
      MainText[Count-1]:=Format(HelpText.Lookup('REQUIRED'),[MainText[Count-1]]);
    end
  end;

  procedure AddJobList;
  var
  i,JobCost: integer;
  begin
  with MainText do
    begin
    for i:=0 to nJobHelp-1 do
      begin
      if i>0 then begin LF; LF end;
      AddLine(Phrases.Lookup('JOBRESULT',JobHelp[i]),pkSection);
      AddLine;
      AddLine('',pkTerImp,i);
      AddLine;
      AddText(HelpText.LookupByHandle(hJOBHELP,i));
      JobCost:=-1;
      case JobHelp[i] of
        jCanal: JobCost:=CanalWork;
        jFort: JobCost:=FortWork;
        jBase: JobCost:=BaseWork;
        end;
      if JobCost>=0 then
        AddText(Format(HelpText.Lookup('JOBCOST'),[MovementToString(JobCost)]))
      else AddText(HelpText.Lookup('JOBCOSTVAR'));
      if JobPreq[JobHelp[i]]<>preNone then
        begin
        AddPreqAdv(JobPreq[JobHelp[i]]);
        MainText[Count-1]:=Format(HelpText.Lookup('REQUIRED'),[MainText[Count-1]]);
        end
      end;
    end
  end;

  procedure AddGraphicCredits;
  var
  i: integer;
  s: string;
  sr: TSearchRec;
  List, plus: tstringlist;
  begin
  List:=tstringlist.Create;
  plus:=tstringlist.Create;
  if FindFirst(HomeDir+'Graphics\*.credits.txt',$27,sr)=0 then
    repeat
      plus.LoadFromFile(HomeDir+'Graphics\'+sr.Name);
      List.AddStrings(plus);
    until FindNext(sr)<>0;
  FindClose(sr);
  plus.Free;

  List.Sort;
  i:=1;
  while i<List.Count do
    if List[i]=List[i-1] then List.Delete(i)
    else inc(i);

  for i:=0 to List.Count-1 do
    begin
    s:=List[i];
    while BiColorTextWidth(Offscreen.Canvas,s)>InnerWidth-16
      -GetSystemMetrics(SM_CXVSCROLL) do
      Delete(s,Length(s),1);
    MainText.AddLine(s);
    end;
  List.Free;
  end;

  procedure AddSoundCredits;
  var
  i: integer;
  s: string;
  List: tstringlist;
  begin
  List:=tstringlist.Create;
  List.LoadFromFile(HomeDir+'Sounds\sound.credits.txt');
  for i:=0 to List.Count-1 do
    begin
    s:=List[i];
    while BiColorTextWidth(Offscreen.Canvas,s)>InnerWidth-16
      -GetSystemMetrics(SM_CXVSCROLL) do
      Delete(s,Length(s),1);
    MainText.AddLine(s);
    end;
  List.Free;
  end;

  procedure NextSection(Item: string);
  begin
  if MainText.Count>1 then
    if MainText.Count=Headline+1 then MainText.Delete(Headline)
    else MainText.LF;
  MainText.AddLine(HelpText.Lookup(Item),pkSection);
  Headline:=MainText.Count-1;
  end;

begin {Prepare}
with MainText do
  begin
  offscreen.Canvas.Font.Assign(UniFont[ftNormal]);
  CheckSeeAlso:=false;
  Clear;
  Headline:=-1;
  if (no>=200) or not (Kind in [hkAdv,hkImp,hkTer,hkFeature]) then
    LF;
  case Kind of
    hkText: AddText(HelpText.LookupByHandle(no));
    hkMisc:
      begin
      case no of
        miscMain:
          begin
          Caption:=HelpText.Lookup('HELPTITLE_MAIN');
          AddLine(HelpText.Lookup('HELPTITLE_QUICKSTART'),pkSpecialIcon,0,{pkBigIcon,22,}hkText,HelpText.GetHandle('QUICK')); LF;
          AddLine(HelpText.Lookup('HELPTITLE_CONCEPTS'),pkBigIcon,6,hkText,HelpText.GetHandle('CONCEPTS')); LF;
          AddLine(HelpText.Lookup('HELPTITLE_TERLIST'),pkSpecialIcon,1,hkTer,200); LF;
          AddLine(HelpText.Lookup('HELPTITLE_JOBLIST'),pkSpecialIcon,2,hkMisc,miscJobList); LF;
          AddLine(HelpText.Lookup('HELPTITLE_TECHLIST'),pkBigIcon,39,hkAdv,200); LF;
          FindStdModelPicture(SpecialModelPictureCode[6],i,s);
          AddLine(HelpText.Lookup('HELPTITLE_MODELLIST'),pkModel,i,hkModel,0); LF;
          AddLine(HelpText.Lookup('HELPTITLE_FEATURELIST'),pkBigIcon,28,hkFeature,200); LF;
          AddLine(HelpText.Lookup('HELPTITLE_IMPLIST'),pkBigIcon,7*SystemIconLines+imCourt,hkImp,200); LF;
          AddLine(HelpText.Lookup('HELPTITLE_UNIQUELIST'),pkBigIcon,7*SystemIconLines+imStockEx,hkImp,201); LF;
          AddLine(HelpText.Lookup('HELPTITLE_WONDERLIST'),pkBigIcon,7*SystemIconLines,hkImp,202); LF;
          AddLine(HelpText.Lookup('HELPTITLE_GOVLIST'),pkBigIcon,gDemocracy+6,hkMisc,miscGovList); LF;
          AddLine(HelpText.Lookup('HELPTITLE_KEYS'),pkBigIcon,2,hkText,HelpText.GetHandle('HOTKEYS')); LF;
          AddLine(HelpText.Lookup('HELPTITLE_ABOUT'),pkBigIcon,1,hkText,HelpText.GetHandle('ABOUT')); LF;
          AddLine(HelpText.Lookup('HELPTITLE_CREDITS'),pkBigIcon,22,hkMisc,miscCredits);
          end;
        miscCredits:
          begin
          AddItem('CREDITS');
          LF;
          AddGraphicCredits;
          NextSection('CRED_CAPSOUND');
          AddSoundCredits;
          NextSection('CRED_CAPAI');
          Server(sGetAICredits,0,0,ps);
          AddText(ps);
          NextSection('CRED_CAPLANG');
          AddItem('AUTHOR');
          end;
        miscJobList:
          begin
          Caption:=HelpText.Lookup('HELPTITLE_JOBLIST');
          AddJobList;
          LF;
          AddItem('TERIMPEXCLUDE');
          LF;
          AddItem('TERIMPCITY');
          end;
        miscGovList:
          begin
          Caption:=HelpText.Lookup('HELPTITLE_GOVLIST');
          for i:=1 to nGov do
            begin
            AddLine(Phrases.Lookup('GOVERNMENT',i mod nGov),pkSection);
            LF;
            if i=nGov then
              AddLine('',pkBigIcon,7*SystemIconLines+imPalace)
            else AddLine('',pkBigIcon,i+6);
            LF;
            AddText(HelpText.LookupByHandle(hGOVHELP,i mod nGov));
            if i mod nGov>=2 then
              begin
              AddPreqAdv(GovPreq[i mod nGov]);
              MainText[Count-1]:=Format(HelpText.Lookup('REQUIRED'),[MainText[Count-1]]);
              end;
            if i<nGov then begin LF; LF; end
            end
          end;
        miscSearchResult:
          begin
          Caption:=HelpText.Lookup('HELPTITLE_SEARCHRESULTS');
          AddText(Format(HelpText.Lookup('MATCHES'), [SearchContent]));
          MainText.AddStrings(SearchResult);
          end
        end; // case no
      end;

    hkAdv:
      if no=200 then
        begin // complete advance list
        Caption:=HelpText.Lookup('HELPTITLE_TECHLIST');
        List:=THyperText.Create;
        for j:=0 to 3 do
          begin
          if j>0 then begin LF; LF; end;
          AddLine(HelpText.Lookup('TECHAGE',j),pkSection);
          if j=1 then
            AddLine(Phrases.Lookup('ADVANCES',adScience)+' '
              +HelpText.Lookup('BASETECH'),
              pkAdvIcon,adScience,hkAdv,adScience);
          if j=2 then
            AddLine(Phrases.Lookup('ADVANCES',adMassProduction)+' '
              +HelpText.Lookup('BASETECH'),
              pkAdvIcon,adMassProduction,hkAdv,adMassProduction);
          List.Clear;
          for i:=0 to nAdv-1 do
            if (i<>adScience) and (i<>adMassProduction) and (AdvValue[i] div 1000=j) then
              List.AddLine(Phrases.Lookup('ADVANCES',i),pkAdvIcon,i,hkAdv,i);
          List.Sort;
          AddStrings(List);
          end;
        List.Free
        end
      else // single advance
        begin
        Caption:=Phrases.Lookup('ADVANCES',no);
        LF;
        AddLine(Phrases.Lookup('ADVANCES',no),pkCaption);
        if no in FutureTech then
          begin
          AddLine(HelpText.Lookup('HELPSPEC_FUTURE'));
          LF;
          if no=futResearchTechnology then
            AddItem('FUTURETECHHELP100')
          else AddItem('FUTURETECHHELP25');
          end
        else AddLine(HelpText.Lookup('HELPSPEC_ADV'));
        if AdvPreq[no,2]<>preNone then NextSection('PREREQALT')
        else NextSection('PREREQ');
        for i:=0 to 2 do
          if AdvPreq[no,i]<>preNone then AddPreqAdv(AdvPreq[no,i]);
        NextSection('GOVALLOW');
        for i:=2 to nGov-1 do
          if GovPreq[i]=no then
            AddLine(Phrases.Lookup('GOVERNMENT',i),pkGov,i,
              hkMisc+hkCrossLink,miscGovList);
        NextSection('BUILDALLOW');
        for i:=0 to 27 do
          if Imp[i].Preq=no then AddImp(i);
        for i:=28 to nImp-1 do
          if (Imp[i].Preq=no) and (Imp[i].Kind<>ikCommon) then AddImp(i);
        for i:=28 to nImp-1 do
          if (Imp[i].Preq=no) and (Imp[i].Kind=ikCommon) then AddImp(i);
        NextSection('MODELALLOW');
        for i:=0 to nSpecialModel-1 do
          if SpecialModelPreq[i]=no then AddModel(i);
        NextSection('FEATALLOW');
        for i:=0 to nFeature-1 do if Feature[i].Preq=no then AddFeature(i);
        NextSection('FOLLOWADV');
        for i:=0 to nAdv-1 do
          if (AdvPreq[i,0]=no) or (AdvPreq[i,1]=no) or (AdvPreq[i,2]=no) then
            AddAdv(i);
        NextSection('UPGRADEALLOW');
        for Domain:=0 to nDomains-1 do for i:=1 to nUpgrade-1 do
          if upgrade[Domain,i].Preq=no then
            begin
            if upgrade[Domain,i].Strength>0 then
              AddLine(Format(HelpText.Lookup('STRENGTHUP'),
                [Phrases.Lookup('DOMAIN',Domain),upgrade[Domain,i].Strength]),
                pkDomain,Domain);
            if upgrade[Domain,i].Trans>0 then
              AddLine(Format(HelpText.Lookup('TRANSUP'),
                [Phrases.Lookup('DOMAIN',Domain),upgrade[Domain,i].Trans]),
                pkDomain,Domain);
            if no in FutureTech then
              AddLine(Format(HelpText.Lookup('COSTUP'),
                [upgrade[Domain,i].Cost]),pkNormal_Dot)
            else
              AddLine(Format(HelpText.Lookup('COSTMIN'),
                [upgrade[Domain,i].Cost]),pkNormal_Dot)
            end;
        NextSection('EXPIRATION');
        for i:=0 to 27 do
          if (Imp[i].Preq<>preNA) and (Imp[i].Expiration=no) then AddImp(i);
        NextSection('ADVEFFECT');
        s:=HelpText.LookupByHandle(hADVHELP,no);
        if s<>'*' then AddText(s);
        NextSection('SEEALSO');
        CheckSeeAlso:=true
        end;

    hkImp:
      if no=200 then
        begin // complete city improvement list
        Caption:=HelpText.Lookup('HELPTITLE_IMPLIST');
//        AddLine(HelpText.Lookup('HELPTITLE_IMPLIST'),pkSection);
        List:=THyperText.Create;
        for i:=28 to nImp-1 do
          if (i<>imTrGoods) and (Imp[i].Preq<>preNA) and (Imp[i].Kind=ikCommon) then
            List.AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon,i,hkImp,i);
        List.Sort;
        AddStrings(List);
        List.Free
        end
      else if no=201 then
        begin // complete nat. project list
        Caption:=HelpText.Lookup('HELPTITLE_UNIQUELIST');
//        AddLine(HelpText.Lookup('HELPTITLE_UNIQUELIST'),pkSection);
        for i:=28 to nImp-1 do
          if (Imp[i].Preq<>preNA)
            and ((Imp[i].Kind=ikNatLocal) or (Imp[i].Kind=ikNatGlobal)) then
            AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon,i,hkImp,i);
{        LF;
        LF;
        AddLine(HelpText.Lookup('HELPTITLE_SHIPPARTLIST'),pkSection);
        for i:=28 to nImp-1 do
          if (Imp[i].Preq<>preNA) and (Imp[i].Kind=ikShipPart) then
            AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon,i,hkImp,i);}
        end
      else if no=202 then
        begin // complete wonder list
        Caption:=HelpText.Lookup('HELPTITLE_WONDERLIST');
//        AddLine(HelpText.Lookup('HELPTITLE_WONDERLIST'),pkSection);
        for i:=0 to 27 do if Imp[i].Preq<>preNA then
          AddLine(Phrases.Lookup('IMPROVEMENTS',i),pkSmallIcon,i,hkImp,i);
        end
      else
        begin // single building
        Caption:=Phrases.Lookup('IMPROVEMENTS',no);
        LF;
        AddLine(Phrases.Lookup('IMPROVEMENTS',no),pkRightIcon,no);
        case Imp[no].Kind of
          ikWonder: AddLine(HelpText.Lookup('HELPSPEC_WONDER'));
          ikCommon: AddLine(HelpText.Lookup('HELPSPEC_IMP'));
          ikShipPart: AddLine(HelpText.Lookup('HELPSPEC_SHIPPART'));
          else AddLine(HelpText.Lookup('HELPSPEC_NAT'))
          end;
        if Imp[no].Kind<>ikShipPart then
          begin
          NextSection('EFFECT');
          AddText(HelpText.LookupByHandle(hIMPHELP,no));
          end;
        if no=woSun then
          begin
          AddFeature(mcFirst);
          AddFeature(mcWill);
          AddFeature(mcAcademy);
          end;
        if (no<28) and not Phrases2FallenBackToEnglish then
          begin
          LF;
          if Imp[no].Expiration>=0 then
            AddText(Phrases2.Lookup('HELP_WONDERMORALE1'))
          else AddText(Phrases2.Lookup('HELP_WONDERMORALE2'));
          end;
        if Imp[no].Preq<>preNone then
          begin
          NextSection('PREREQ');
          AddPreqAdv(Imp[no].Preq);
          end;
        NextSection('COSTS');
        if Difficulty=0 then
          s:=Format(HelpText.Lookup('BUILDCOST'),[Imp[no].Cost])
        else s:=Format(HelpText.Lookup('BUILDCOST'),
          [Imp[no].Cost*BuildCostMod[Difficulty] div 12]);
        AddLine(s);
        if Imp[no].Maint>0 then
          AddLine(Format(HelpText.Lookup('MAINTCOST'),[Imp[no].Maint]));
        j:=0;
        for i:=0 to nImpReplacement-1 do if ImpReplacement[i].NewImp=no then
          begin
          if j=0 then
            begin NextSection('REPLACE'); AddItem('REPLACETEXT'); j:=1 end;
          AddImp(ImpReplacement[i].OldImp);
          end;
        if Imp[no].Kind=ikShipPart then
          begin
          LF;
          if no=imShipComp then i:=1
          else if no=imShipPow then i:=2
          else {if no=imShipHab then} i:=3;
          AddLine(Format(HelpText.Lookup('RAREREQUIRED'),
            [Phrases.Lookup('TERRAIN',3*12+i)]),pkTer,3*12+i);
          end;
        if (no<28) and (Imp[no].Expiration>=0) then
          begin
          NextSection('EXPIRATION');
          s:=Format(HelpText.Lookup('EXPWITH'),[Phrases.Lookup('ADVANCES',Imp[no].Expiration)]);
          if no=woPyramids then s:=s+' '+HelpText.Lookup('EXPSLAVE');
          AddText(s);
          end;
        NextSection('SEEALSO');
        if (no<28) and (Imp[no].Expiration>=0) then AddImp(woEiffel);
        for i:=0 to nImpReplacement-1 do if ImpReplacement[i].OldImp=no then
          AddImp(ImpReplacement[i].NewImp);
        if no=imSupermarket then
          AddLine(HelpText.Lookup('HELPTITLE_JOBLIST'),pkNormal,0,hkMisc+hkCrossLink,miscJobList);
        CheckSeeAlso:=true
        end;

    hkTer:
      if no=200 then
        begin // complete terrain type list
        Caption:=HelpText.Lookup('HELPTITLE_TERLIST');
//        AddLine(HelpText.Lookup('HELPTITLE_TERLIST'),pkSection);
        for i:=0 to nTerrainHelp-1 do AddTer(TerrainHelp[i]);
        end
      else
        begin // sigle terrain type
        TerrType:=no mod 12;
        if TerrType=fJungle then TerrType:=fForest;
        TerrSubType:=no div 12;
        if no=3*12 then
          begin TerrType:=fDesert; TerrSubType:=0 end;
        with Terrain[TerrType] do
          begin
          Caption:=Phrases.Lookup('TERRAIN',no);
          LF;
          AddLine(Phrases.Lookup('TERRAIN',no), pkBigTer, no);
          AddLine(HelpText.Lookup('HELPSPEC_TER'));
          LF;
          if (ProdRes[TerrSubType]>0) or (MineEff>0) then
            AddLine(Format(HelpText.Lookup('RESPROD'),[ProdRes[TerrSubType]]));
          if (no<3*12) and (MineEff>0) then
            MainText[Count-1]:=MainText[Count-1]+' '
              +Format(HelpText.Lookup('MOREMINE'),[MineEff]);
          if (FoodRes[TerrSubType]>0) or (IrrEff>0) then
            AddLine(Format(HelpText.Lookup('RESFOOD'),[FoodRes[TerrSubType]]));
          if (no<3*12) and (IrrEff>0) then
            MainText[Count-1]:=MainText[Count-1]+' '
              +Format(HelpText.Lookup('MOREIRR'),[IrrEff]);
          if TradeRes[TerrSubType]>0 then
            AddLine(Format(HelpText.Lookup('RESTRADE'),[TradeRes[TerrSubType]]));
          if Defense>4 then
            AddLine(Format(HelpText.Lookup('DEFBONUS'),[(Defense-4)*25]));
          if (TerrType>=fGrass) and (TerrType<>fMountains) then
            if MoveCost=2 then
              AddLine(HelpText.Lookup('MOVEHEAVY'))
            else AddLine(HelpText.Lookup('MOVEPLAIN'));
          if no=3*12 then
            begin
            LF;
            AddText(HelpText.Lookup('DEADLANDS'));
            end;
          if (TerrType=fDesert) and (no<>fDesert+12) then
            begin
            LF;
            AddText(Format(HelpText.Lookup('HOSTILE'),[DesertThurst]));
            end;
          if TerrType=fArctic then
            begin
            LF;
            AddText(Format(HelpText.Lookup('HOSTILE'),[ArcticThurst]));
            end;
          if (no<3*12) and (TransTerrain>=0) then
            begin
            LF;
            i:=TransTerrain;
            if (TerrType<>fGrass) and (i<>fGrass) then
              i:=i+TerrSubType*12; // trafo to same special resource group
            AddLine(Format(HelpText.Lookup('TRAFO'),
              [Phrases.Lookup('TERRAIN',i)]),pkTer,i,hkTer+hkCrossLink,i);
            if no=fSwamp+12 then
              begin
              LF;
              AddLine(Format(HelpText.Lookup('TRAFO'),
                [Phrases.Lookup('TERRAIN',TransTerrain+24)]),pkTer,TransTerrain+24,
                hkTer+hkCrossLink,TransTerrain+24);
              end
            else if i=fGrass then
              begin
              LF;
              AddLine(Format(HelpText.Lookup('TRAFO'),
                [Phrases.Lookup('TERRAIN',fGrass+12)]),pkTer,fGrass+12,
                hkTer+hkCrossLink,fGrass+12);
              end
            end;
          NextSection('SPECIAL');
          if no=3*12 then
            begin
            LF;
            for special:=1 to 3 do
              begin
              if special>1 then LF;
              AddLine(Phrases.Lookup('TERRAIN',3*12+special),pkTer,3*12+special);
              end
            end
          else if (no<12) and (no<>fGrass) and (no<>fOcean) then
            begin
            LF;
            for special:=1 to 2 do
              if (no<>fArctic) and (no<>fSwamp) or (special<2) then
                begin
                if special>1 then LF;
                AddLine(Phrases.Lookup('TERRAIN',no+special*12),pkTer,no+special*12);
                i:=FoodRes[special]-FoodRes[0];
                if i<>0 then
                  MainText[Count-1]:=MainText[Count-1]+Format(HelpText.Lookup('SPECIALFOOD'),[i]);
                i:=ProdRes[special]-ProdRes[0];
                if i<>0 then
                  MainText[Count-1]:=MainText[Count-1]+Format(HelpText.Lookup('SPECIALPROD'),[i]);
                i:=TradeRes[special]-TradeRes[0];
                if i<>0 then
                  MainText[Count-1]:=MainText[Count-1]+Format(HelpText.Lookup('SPECIALTRADE'),[i]);
                end;
            end;
          if no=3*12 then
            begin
            LF;
            AddText(HelpText.Lookup('RARE'));
            end;
          if (no<3*12) and (TerrType in [fDesert,fArctic]) then
            begin
            NextSection('SEEALSO');
            AddImp(woGardens);
            CheckSeeAlso:=true
            end
          end
        end;

    hkFeature:
      if no=200 then
        begin // complete feature list
        Caption:=HelpText.Lookup('HELPTITLE_FEATURELIST');
        List:=THyperText.Create;
        for special:=0 to 2 do
          begin
          if special>0 then begin LF; LF end;
          case special of
            0: AddLine(HelpText.Lookup('HELPTITLE_FEATURE1LIST'),pkSection);
            1: AddLine(HelpText.Lookup('HELPTITLE_FEATURE2LIST'),pkSection);
            2: AddLine(HelpText.Lookup('HELPTITLE_FEATURE3LIST'),pkSection);
            end;
          List.Clear;
          for i:=0 to nFeature-1 do if Feature[i].Preq<>preNA then
            begin
            if i<mcFirstNonCap then j:=0
            else if i in AutoFeature then j:=2
            else j:=1;
            if j=special then
              List.AddLine(Phrases.Lookup('FEATURES',i),pkFeature,i,hkFeature,i);
            end;
          List.Sort;
          AddStrings(List);
          end;
        List.Free
        end
      else
        begin // single feature
        Caption:=Phrases.Lookup('FEATURES',no);
        LF;
        AddLine(Phrases.Lookup('FEATURES',no),pkBigFeature,no);
        if no<mcFirstNonCap then
          AddLine(HelpText.Lookup('HELPSPEC_CAP'))
        else if no in AutoFeature then
          AddLine(HelpText.Lookup('HELPSPEC_STANDARD'))
        else AddLine(HelpText.Lookup('HELPSPEC_FEATURE'));
        NextSection('EFFECT');
        AddText(HelpText.LookupByHandle(hFEATUREHELP,no));
        if (Feature[no].Weight<>0) or (Feature[no].Cost<>0) then
          begin
          NextSection('COSTS');
          s:=IntToStr(Feature[no].Cost);
          if Feature[no].Cost>=0 then s:='+'+s;
          AddLine(Format(HelpText.Lookup('COSTBASE'),[s]));
          if Feature[no].Weight>0 then
            begin
            AddLine(Format(HelpText.Lookup('WEIGHT'),
              ['+'+IntToStr(Feature[no].Weight)]));
            if no=mcDefense then
              AddLine(Format(HelpText.Lookup('WEIGHT'),['+2']),pkDomain,dGround);
            end
          end;
        if Feature[no].Preq<>preNone then
          begin
          LF;
          if Feature[no].Preq=preSun then AddPreqImp(woSun) // sun tsu feature
          else AddPreqAdv(Feature[no].Preq);
          MainText[Count-1]:=Format(HelpText.Lookup('REQUIRED'),[MainText[Count-1]]);
          end;
        NextSection('SEEALSO');
        CheckSeeAlso:=true
        end;

    hkModel:
        begin
        Caption:=HelpText.Lookup('HELPTITLE_MODELLIST');
        for i:=0 to nSpecialModel-1 do if i<>2 then AddModelText(i);
        LF;
        AddItem('MODELNOTE');
        end;

    end;
  if CheckSeeAlso then
    for i:=0 to nSeeAlso-1 do
      if (SeeAlso[i].Kind=Kind) and (SeeAlso[i].no=no) then
        case SeeAlso[i].SeeKind of
          hkImp: AddImp(SeeAlso[i].SeeNo);
          hkAdv: AddAdv(SeeAlso[i].SeeNo);
          hkFeature: AddFeature(SeeAlso[i].SeeNo);
          end;
  if (Headline>=0) and (Count=Headline+1) then Delete(Headline)
  else LF;

  InitPVSB(sb,Count-1,InnerHeight div 24);
  if sbPos<>0 then
    begin
    sb.si.npos:=sbPos;
    sb.si.FMask:=SIF_POS;
    SetScrollInfo(sb.h,SB_CTL,sb.si,true);
    end;
  BackBtn.Visible:= nHist>0;
  TopBtn.Visible:= (nHist>0) or (Kind<>hkMisc) or (no<>miscMain);
  Sel:=-1;
  end; // with MainText
end; {Prepare}

procedure THelpDlg.ShowNewContent(NewMode, Category, Index: integer);
begin
if (Category<>Kind) or (Index<>no)
  or (Category=hkMisc) and (Index=miscSearchResult) then
  begin
  if nHist=MaxHist then
    begin
    move(HistKind[2],HistKind[1],4*(nHist-2));
    move(HistNo[2],HistNo[1],4*(nHist-2));
    move(HistPos[2],HistPos[1],4*(nHist-2));
    move(HistSearchContent[2],HistSearchContent[1],sizeof(shortstring)*(nHist-2));
    end
  else inc(nHist);
  if nHist>0 then
    begin
    HistKind[nHist-1]:=Kind;
    HistNo[nHist-1]:=no;
    HistPos[nHist-1]:=sb.si.npos;
    HistSearchContent[nHist-1]:=SearchContent
    end
  end;
Kind:=Category;
no:=Index;
SearchContent:=NewSearchContent;
Prepare;
OffscreenPaint;
inherited ShowNewContent(NewMode);
end;

procedure THelpDlg.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState;
  x, y: integer);
var
i0,Sel0:integer;
begin
y:=y-WideFrame;
i0:=sb.si.npos;
Sel0:=Sel;
if (x>=SideFrame) and (x<SideFrame+InnerWidth) and (y>=0) and (y<InnerHeight)
  and (y mod 24>=8) then
  Sel:=y div 24
else Sel:=-1;
if (Sel+i0>=MainText.Count) or (Sel>=0)
  and (THelpLineInfo(MainText.Objects[Sel+i0]).Link=0) then Sel:=-1;
if Sel<>Sel0 then
  begin
  if Sel0<>-1 then line(Canvas,Sel0,false);
  if Sel<>-1 then line(Canvas,Sel,true)
  end
end;

procedure THelpDlg.PaintBox1MouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; x, y: integer);
begin
if Sel>=0 then with THelpLineInfo(MainText.Objects[Sel+sb.si.npos]) do
  if Link shr 8 and $3F=hkInternet then
    case Link and $FF of
      1: ShellExecute(Handle,'open',pchar(HomeDir+'AI Template\AI development manual.html'),'','',
        SW_SHOWNORMAL);
      2: ShellExecute(Handle,'open','http://c-evo.org','','',
        SW_SHOWNORMAL);
      3: ShellExecute(Handle,'open','http://c-evo.org/_sg/contact','','',
        SW_SHOWNORMAL);
      end
  else
    begin
    if (Link>=$8000) and (Link and $3FFF=liInvalid) then
      exit; // invalid link;
    if Link>=$8000 then
      ShowNewContent(FWindowMode, hkText, Link and $3FFF)
    else ShowNewContent(FWindowMode, Link shr 8 and $3F, Link and $FF);
    end
end;

procedure THelpDlg.BackBtnClick(Sender: TObject);
begin
if nHist>0 then
  begin
  dec(nHist);
  if (HistKind[nHist]=hkMisc) and (HistNo[nHist]=miscSearchResult)
    and (HistSearchContent[nHist]<>SearchContent) then
    begin
    SearchContent:=HistSearchContent[nHist];
    Search(SearchContent);
    end;
  Kind:=HistKind[nHist];
  no:=HistNo[nHist];
  Prepare(HistPos[nHist]);
  OffscreenPaint;
  Invalidate;
  end
end;

procedure THelpDlg.TopBtnClick(Sender: TObject);
begin
nHist:=0;
Kind:=hkMisc;
no:=miscMain;
Prepare;
OffscreenPaint;
Invalidate;
end;

procedure THelpDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
ExtPic.Height:=0;
inherited;
end;

function THelpDlg.TextIndex(Item: string): integer;
begin
result:=HelpText.GetHandle(Item)
end;

procedure THelpDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if Key=VK_F1 then // my key
else inherited
end;

procedure THelpDlg.SearchBtnClick(Sender: TObject);
begin
InputDlg.Caption:=Phrases.Lookup('SEARCH');
InputDlg.EInput.Text:=SearchContent;
InputDlg.CenterToRect(BoundsRect);
InputDlg.ShowModal;
if (InputDlg.ModalResult=mrOK) and (length(InputDlg.EInput.Text)>=2) then
  begin
  Search(InputDlg.EInput.Text);
  case SearchResult.Count of
    0: SimpleMessage(Format(HelpText.Lookup('NOMATCHES'), [InputDlg.EInput.Text]));
    1:
      with THelpLineInfo(SearchResult.Objects[0]) do
        if Link>=$8000 then
          ShowNewContent(FWindowMode, hkText, Link and $3FFF)
        else ShowNewContent(FWindowMode, Link shr 8 and $3F, Link and $FF);
    else
      begin
      NewSearchContent:=InputDlg.EInput.Text;
      ShowNewContent(FWindowMode, hkMisc, miscSearchResult);
      end
    end
  end
end;

procedure THelpDlg.Search(SearchString: string);
var
h, i, PrevHandle, PrevIndex, p, RightMargin: integer;
s: string;
mADVHELP, mIMPHELP, mFEATUREHELP: set of 0..255;
bGOVHELP, bSPECIALMODEL, bJOBHELP: boolean;
begin
SearchResult.Clear;
mADVHELP:=[];
mIMPHELP:=[];
mFEATUREHELP:=[];
bGOVHELP:=false;
bSPECIALMODEL:=false;
bJOBHELP:=false;

// search in generic reference
SearchString:=UpperCase(SearchString);
for i:=0 to 35+4 do
  begin
  s:=Phrases.Lookup('TERRAIN',i);
  if pos(SearchString,UpperCase(s))>0 then
    if i<36 then
      SearchResult.AddLine(s+' '+HelpText.Lookup('HELPSPEC_TER'),pkNormal,0,
        hkTer+hkCrossLink,i)
    else
      begin
      SearchResult.AddLine(Phrases.Lookup('TERRAIN',36)+' '
        +HelpText.Lookup('HELPSPEC_TER'),pkNormal,0,hkTer+hkCrossLink,36);
      if i>36 then
        SearchResult.AddLine(Phrases.Lookup('IMPROVEMENTS',imShipComp+i-37)
          +' '+HelpText.Lookup('HELPSPEC_SHIPPART'),
          pkNormal,0,hkImp+hkCrossLink,imShipComp+i-37);
      break
      end
  end;
for i:=0 to nJobHelp-1 do
  if pos(SearchString,UpperCase(Phrases.Lookup('JOBRESULT',JobHelp[i])))>0 then
    begin
    SearchResult.AddLine(HelpText.Lookup('HELPTITLE_JOBLIST'),pkNormal,0,
      hkMisc+hkCrossLink,miscJobList);
    bJOBHELP:=true;
    break
    end;
for i:=0 to nAdv-1 do
  begin
  s:=Phrases.Lookup('ADVANCES',i);
  if pos(SearchString,UpperCase(s))>0 then
    begin
    if i in FutureTech then s:=s+' '+HelpText.Lookup('HELPSPEC_FUTURE')
    else s:=s+' '+HelpText.Lookup('HELPSPEC_ADV');
    SearchResult.AddLine(s,pkNormal,0,hkAdv+hkCrossLink,i);
    include(mADVHELP,i);
    end
  end;
for i:=0 to nSpecialModel-1 do
  begin
  FindStdModelPicture(SpecialModelPictureCode[i],h,s);
  if pos(SearchString,UpperCase(s))>0 then
    begin
    SearchResult.AddLine(HelpText.Lookup('HELPTITLE_MODELLIST'),pkNormal,0,
      hkModel+hkCrossLink,0);
    bSPECIALMODEL:=true;
    break
    end;
  end;
for i:=0 to nFeature-1 do
  begin
  s:=Phrases.Lookup('FEATURES',i);
  if pos(SearchString,UpperCase(s))>0 then
    begin
    if i<mcFirstNonCap then s:=s+' '+HelpText.Lookup('HELPSPEC_CAP')
    else if i in AutoFeature then s:=s+' '+HelpText.Lookup('HELPSPEC_STANDARD')
    else s:=s+' '+HelpText.Lookup('HELPSPEC_FEATURE');
    SearchResult.AddLine(s,pkNormal,0,hkFeature+hkCrossLink,i);
    include(mFEATUREHELP,i);
    end
  end;
for i:=0 to nImp-1 do
  begin
  s:=Phrases.Lookup('IMPROVEMENTS',i);
  if pos(SearchString,UpperCase(s))>0 then
    begin
    case Imp[i].Kind of
      ikWonder: s:=s+' '+HelpText.Lookup('HELPSPEC_WONDER');
      ikCommon: s:=s+' '+HelpText.Lookup('HELPSPEC_IMP');
      ikShipPart: s:=s+' '+HelpText.Lookup('HELPSPEC_SHIPPART');
      else s:=s+' '+HelpText.Lookup('HELPSPEC_NAT')
      end;
    SearchResult.AddLine(s,pkNormal,0,hkImp+hkCrossLink,i);
    include(mIMPHELP,i);
    end
  end;
for i:=0 to nGov-1 do
  if pos(SearchString,UpperCase(Phrases.Lookup('GOVERNMENT',i)))>0 then
    begin
    SearchResult.AddLine(HelpText.Lookup('HELPTITLE_GOVLIST'),pkNormal,0,
      hkMisc+hkCrossLink,miscGovList);
    bGOVHELP:=true;
    break
    end;

// full text search
h:=-1;
repeat
  PrevHandle:=h;
  PrevIndex:=i;
  if not HelpText.Search(SearchString, h, i) then
    break;
  if h=hADVHELP then
    begin
    if (i>=0) and ((i<>PrevIndex) or (h<>PrevHandle)) and not (i in mADVHELP) then
      begin
      s:=Phrases.Lookup('ADVANCES',i);
      if i in FutureTech then s:=s+' '+HelpText.Lookup('HELPSPEC_FUTURE')
      else s:=s+' '+HelpText.Lookup('HELPSPEC_ADV');
      SearchResult.AddLine(s,pkNormal,0,hkAdv+hkCrossLink,i)
      end
    end
  else if h=hIMPHELP then
    begin
    if (i>=0) and ((i<>PrevIndex) or (h<>PrevHandle)) and not (i in mIMPHELP) then
      begin
      s:=Phrases.Lookup('IMPROVEMENTS',i);
      case Imp[i].Kind of
        ikWonder: s:=s+' '+HelpText.Lookup('HELPSPEC_WONDER');
        ikCommon: s:=s+' '+HelpText.Lookup('HELPSPEC_IMP');
        ikShipPart: s:=s+' '+HelpText.Lookup('HELPSPEC_SHIPPART');
        else s:=s+' '+HelpText.Lookup('HELPSPEC_NAT')
        end;
      SearchResult.AddLine(s,pkNormal,0,hkImp+hkCrossLink,i)
      end
    end
  else if h=hFEATUREHELP then
    begin
    if (i>=0) and ((i<>PrevIndex) or (h<>PrevHandle)) and not (i in mFEATUREHELP) then
      begin
      s:=Phrases.Lookup('FEATURES',i);
      if i<mcFirstNonCap then s:=s+' '+HelpText.Lookup('HELPSPEC_CAP')
      else if i in AutoFeature then s:=s+' '+HelpText.Lookup('HELPSPEC_STANDARD')
      else s:=s+' '+HelpText.Lookup('HELPSPEC_FEATURE');
      SearchResult.AddLine(s,pkNormal,0,hkFeature+hkCrossLink,i);
      end
    end
  else if h=hGOVHELP then
    begin
    if (i>=0) and (h<>PrevHandle) and not bGOVHELP then
      SearchResult.AddLine(HelpText.Lookup('HELPTITLE_GOVLIST'),pkNormal,0,
        hkMisc+hkCrossLink,miscGovList)
    end
  else if h=hSPECIALMODEL then
    begin
    if (i>=0) and (h<>PrevHandle) and not bSPECIALMODEL then
      SearchResult.AddLine(HelpText.Lookup('HELPTITLE_MODELLIST'),pkNormal,0,
        hkModel+hkCrossLink,0)
    end
  else if h=hJOBHELP then
    begin
    if (i>=0) and (h<>PrevHandle) and not bJOBHELP then
      SearchResult.AddLine(HelpText.Lookup('HELPTITLE_JOBLIST'),pkNormal,0,
        hkMisc+hkCrossLink,miscJobList)
    end
  else if {(h<>hMAIN) and} (h<>PrevHandle) then
    begin
    s:=HelpText.LookupByHandle(h);
    p:=pos('$',s);
    if p>0 then
      begin
      s:=copy(s,p+1,maxint);
      p:=pos('\',s);
      if p>0 then
        s:=copy(s,1,p-1);
      SearchResult.AddLine(s, pkNormal, 0, hkText+hkCrossLink, h);
      end
    end
until false;

// cut lines to fit to window
RightMargin:=InnerWidth-16-GetSystemMetrics(SM_CXVSCROLL);
Offscreen.Canvas.Font.Assign(UniFont[ftNormal]);
for i:=0 to SearchResult.Count-1 do
  begin
  while BiColorTextWidth(Offscreen.Canvas, SearchResult[i])>RightMargin-32 do
    SearchResult[i]:=copy(SearchResult[i], 1, length(SearchResult[i])-1)
  end;
end;

end.

