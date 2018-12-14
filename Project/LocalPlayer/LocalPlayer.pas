{$INCLUDE switches}

unit LocalPlayer;

interface

procedure Client(Command,Player:integer;var Data); stdcall;

procedure SetAIName(p: integer; Name: string);


implementation

uses
Term,CityScreen,Draft,MessgEx,Select,CityType,Help,UnitStat,Diagram,
NatStat,Wonders,Nego,Enhance,BaseWin,Battle,Rates,TechTree,

Forms;

var
FormsCreated: boolean;

procedure Client;
begin
if not FormsCreated then
  begin
  FormsCreated:=true;
  BaseWin.CreateOffscreen;
  Application.CreateForm(TMainScreen, MainScreen);
  Application.CreateForm(TCityDlg, CityDlg);
  Application.CreateForm(TModalSelectDlg, ModalSelectDlg);
  Application.CreateForm(TListDlg, ListDlg);
  Application.CreateForm(TMessgExDlg, MessgExDlg);
  Application.CreateForm(TDraftDlg, DraftDlg);
  Application.CreateForm(TCityTypeDlg, CityTypeDlg);
  Application.CreateForm(THelpDlg, HelpDlg);
  Application.CreateForm(TUnitStatDlg, UnitStatDlg);
  Application.CreateForm(TDiaDlg, DiaDlg);
  Application.CreateForm(TNatStatDlg, NatStatDlg);
  Application.CreateForm(TWondersDlg, WondersDlg);
  Application.CreateForm(TNegoDlg, NegoDlg);
  Application.CreateForm(TEnhanceDlg, EnhanceDlg);
  Application.CreateForm(TBattleDlg, BattleDlg);
  //Application.CreateForm(TAdvisorDlg, AdvisorDlg);
  Application.CreateForm(TRatesDlg, RatesDlg);
  Application.CreateForm(TTechTreeDlg, TechTreeDlg);
  end;
MainScreen.Client(Command,Player,Data);
end;

procedure SetAIName(p: integer; Name: string);
begin
MainScreen.SetAIName(p, Name);
end;

initialization
FormsCreated:=false;

end.

