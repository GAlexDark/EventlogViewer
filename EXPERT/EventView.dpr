program EventView;

{$R 'EventViewmanifest.res' 'EventViewmanifest.rc'}

uses
  //ExceptionLog,
  Forms,
  Windows,
  EventViewUnit in 'EventViewUnit.pas' {Form1},
  StrRepl in '..\CORE_MODULES\StrRepl.pas',
  EventLog in '..\CORE_MODULES\EventLog.pas',
  networkAPI in '..\CORE_MODULES\networkAPI.pas',
  RTCache in '..\CORE_MODULES\RTCache.pas',
  ActiveDs_TLB in '..\CORE_MODULES\activeX\ActiveDs_TLB.pas',
  DLLLoader in '..\CORE_MODULES\DLLLoader.pas',
  Headers in '..\CORE_MODULES\Headers.pas',
  DsUtils in '..\CORE_MODULES\DsUtils.pas',
  DLLWrapUnit in '..\CORE_MODULES\DLLWrapUnit.pas';

{$IFNDEF DEBUG}
  {$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}
  {$SETPEFLAGS IMAGE_FILE_DEBUG_STRIPPED}
  {$SETPEFLAGS IMAGE_FILE_LINE_NUMS_STRIPPED}
  {$SETPEFLAGS IMAGE_FILE_LOCAL_SYMS_STRIPPED}
{$ENDIF}

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'EventView';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
