program EventViewThread;

uses
  Forms,
  EventViewUnit in 'EventViewUnit.pas' {Form1},
  ELRThreadUnit in 'ELRThreadUnit.pas',
  DUALLIST in 'DUALLIST.pas' {DualListDlg},
  StrRepl in '..\CORE_MODULES\StrRepl.pas',
  EventLog in '..\CORE_MODULES\EventLog.pas',
  networkAPI in '..\CORE_MODULES\networkAPI.pas',
  RTCache in '..\CORE_MODULES\RTCache.pas',
  ActiveDs_TLB in '..\CORE_MODULES\activeX\ActiveDs_TLB.pas',
  Headers in '..\CORE_MODULES\Headers.pas',
  DLLLoader in '..\CORE_MODULES\DLLLoader.pas',
  DsUtils in '..\CORE_MODULES\DsUtils.pas',
  DLLWrapUnit in '..\CORE_MODULES\DLLWrapUnit.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'EventView';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDualListDlg, DualListDlg);
  Application.Run;
end.
