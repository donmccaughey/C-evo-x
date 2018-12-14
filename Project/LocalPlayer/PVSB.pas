{$INCLUDE switches}

unit PVSB;

interface

uses
  Windows,Messages,SysUtils;

type
TPVScrollbar=record h:integer;si:TScrollInfo end;

procedure CreatePVSB(var sb:TPVScrollbar;Handle,y0,x1,y1:integer);
procedure InitPVSB(var sb:TPVScrollbar;max,Page:integer);
function ProcessPVSB(var sb:TPVScrollbar;const m:TMessage):boolean;
function ProcessMouseWheel(var sb:TPVScrollbar;const m:TMessage):boolean;
procedure ShowPVSB(var sb:TPVScrollbar; Visible: boolean);
procedure EndPVSB(var sb:TPVScrollbar);

implementation

const
Count:integer= 0;

procedure CreatePVSB;
begin
inc(Count);
sb.h:=CreateWindowEx(0,'SCROLLBAR',pchar('PVSB'+IntToStr(Count)),
  SBS_VERT or WS_CHILD or SBS_RIGHTALIGN,x1-100,y0,100,y1-y0,Handle,0,0,nil);
sb.si.cbSize:=28;
end;

procedure InitPVSB;
begin
with sb.si do
  begin
  nMin:=0;nMax:=max;npos:=0;nPage:=Page;
  FMask:=SIF_PAGE or SIF_POS or SIF_RANGE;
  end;
SetScrollInfo(sb.h,SB_CTL,sb.si,true);
if max<Page then ShowWindow(sb.h,SW_HIDE) else ShowWindow(sb.h,SW_SHOW)
end;

function ProcessPVSB;
var
NewPos:integer;
begin
with sb.si do
  if nMax<integer(nPage) then result:=false
  else
    begin
    if m.wParamLo in[SB_THUMBPOSITION,SB_THUMBTRACK] then
      begin result:=m.wParamHi<>npos;npos:=m.wParamHi;end
    else
      begin
      case m.wParamLo of
        SB_LINEUP:NewPos:=npos-1;SB_LINEDOWN:NewPos:=npos+1;
        SB_PAGEUP:NewPos:=npos-integer(nPage);SB_PAGEDOWN:NewPos:=npos+integer(nPage);
        else NewPos:=npos
        end;
      if NewPos<0 then NewPos:=0;
      if NewPos>nMax-integer(nPage)+1 then NewPos:=nMax-integer(nPage)+1;
      result:=NewPos<>npos;
      if (NewPos<>npos) or (m.wParamLo=SB_ENDSCROLL) then
        begin
        npos:=NewPos;FMask:=SIF_POS;
        SetScrollInfo(sb.h,SB_CTL,sb.si,true);
        end;
      end
    end
end;

function ProcessMouseWheel;
var
NewPos:integer;
begin
with sb.si do
  if nMax<integer(nPage) then result:=false
  else
    begin
    NewPos:=npos-m.wParam div (1 shl 16*40);
    if NewPos<0 then NewPos:=0;
    if NewPos>nMax-integer(nPage)+1 then NewPos:=nMax-integer(nPage)+1;
    result:=NewPos<>npos;
    if NewPos<>npos then
      begin
      npos:=NewPos;FMask:=SIF_POS;
      SetScrollInfo(sb.h,SB_CTL,sb.si,true);
      end
    end
end;

procedure ShowPVSB(var sb:TPVScrollbar; Visible: boolean);
begin
if not Visible or (sb.si.nMax<integer(sb.si.nPage)) then
  ShowWindow(sb.h,SW_HIDE)
else ShowWindow(sb.h,SW_SHOW)
end;

procedure EndPVSB(var sb:TPVScrollbar);
begin
with sb.si do
  begin
  if nMax<integer(nPage) then npos:=0 // hidden
  else
    begin
    sb.si.npos:=nMax-integer(nPage)+1;
    sb.si.FMask:=SIF_POS;
    SetScrollInfo(sb.h,SB_CTL,sb.si,true);
    end
  end
end;

end.

