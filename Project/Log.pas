{$INCLUDE switches}

unit log;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, Menus;

type
  TLogDlg = class(TForm)
    LogPopup: TPopupMenu;
    mLog0: TMenuItem;
    mLog1: TMenuItem;
    mLog2: TMenuItem;
    mLog3: TMenuItem;
    N1: TMenuItem;
    mClear: TMenuItem;
    mSlot: TMenuItem;
    N2: TMenuItem;
    mInvalid: TMenuItem;
    mTime: TMenuItem;
    List: TMemo;
    mNegotiation: TMenuItem;
    procedure mLogClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure mClearClick(Sender: TObject);
    procedure mSlotClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word;
      Shift: TShiftState);
    procedure Toggle(Sender: TObject);
    procedure ListMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  public
    Host: TForm;
    procedure Add(Level, Turn: integer; Text: pchar);
  private
    MaxLevel: integer;
  end;

var
  LogDlg: TLogDlg;

implementation

uses
ClientTools,Tribes;

{$R *.DFM}

const
MaxLines=1000;

procedure TLogDlg.FormCreate(Sender: TObject);
begin
MaxLevel:=0;
end;

procedure TLogDlg.mLogClick(Sender: TObject);
begin
MaxLevel:=TMenuItem(Sender).Tag;
TMenuItem(Sender).Checked:=true;
end;

procedure TLogDlg.Add(Level, Turn: integer; Text: pchar);
begin
if (MaxLevel>0) and (Level<=MaxLevel)
  or (Level=1 shl 16+1) and mInvalid.Checked
  or (Level=1 shl 16+2) and mTime.Checked
  or (Level=1 shl 16+3) and mNegotiation.Checked then
  begin
  if List.Lines.Count=MaxLines then List.Lines.Delete(0);
  List.Lines.Add(char(48+Turn div 100 mod 10)
    +char(48+Turn div 10 mod 10)+char(48+Turn mod 10)+' '+Text);
  PostMessage(List.Handle,WM_VSCROLL,SB_BOTTOM,0);
  Update;
  end;
end;

procedure TLogDlg.mClearClick(Sender: TObject);
begin
List.Clear;
end;

procedure TLogDlg.mSlotClick(Sender: TObject);
const
SlotNo: array[0..2,0..2] of integer=((8,1,2),(7,0,3),(6,5,4));
var
x,y: integer;
s: string;
begin
for y:=0 to 2 do
  begin
  s:='| ';
  for x:=0 to 2 do
    if G.Difficulty[SlotNo[y,x]]=0 then s:=s+'SUP |'
    else if G.Difficulty[SlotNo[y,x]]<0 then s:=s+'--- |'
    else
      begin
      if SlotNo[y,x] in [6..8] then
        begin // check multi control
        if G.Difficulty[SlotNo[y,x]+3]>=0 then
          s:=s+Tribe[SlotNo[y,x]+3].TPhrase('SHORTNAME')+'+';
        if G.Difficulty[SlotNo[y,x]+6]>=0 then
          s:=s+Tribe[SlotNo[y,x]+6].TPhrase('SHORTNAME')+'+';
        end;
      s:=s+Tribe[SlotNo[y,x]].TPhrase('SHORTNAME')+' | ';
      end;
  List.Lines.Add(s)
  end;
PostMessage(List.Handle,WM_VSCROLL,SB_BOTTOM,0);
end;

procedure TLogDlg.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);
begin
if Host<>nil then
  Host.OnKeyDown(Sender, Key, Shift);
end;

procedure TLogDlg.Toggle(Sender: TObject);
begin
TMenuItem(Sender).Checked:=not TMenuItem(Sender).Checked;
end;

procedure TLogDlg.ListMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
if Button=mbRight then LogPopup.Popup(Left+x,Top+y);
end;

procedure TLogDlg.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
if Host<>nil then
  Host.OnKeyUp(Sender, Key, Shift);
end;

end.

