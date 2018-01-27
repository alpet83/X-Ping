program Xping;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  FastMM4Messages in '..\lib\FastMM4Messages.pas',
  FastMM4 in '..\lib\FastMM4.pas',
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  misc in '..\lib\misc.pas',
  Windows,
  SysUtils,
  SyncObjs,
  ShellAPi,
  Forms, ModuleMgr,
  MainForm in 'MainForm.pas',
  ping,
  StatChart in 'StatChart.pas' {ChartForm};

var
   shutdown: Boolean;
   hCon: THandle;
   sc_share: TCriticalSection;   // используется для синхронизации многопоточного вывода в консоль

function CtrlHandler (ctlType: DWORD): Boolean; stdcall;
begin
 result := TRUE;
 shutdown := TRUE;
 sc_share.Enter;
 try
  SetConsoleTextAttribute (hCon, $07);
  WriteLn ('User break. ');
 finally
  sc_share.Leave;
 end;
 Sleep (500);
end;


begin
 StartLogging ('');
 ShowConsole(SW_HIDE);
 SetConsoleTitle ('Xping - log console');


 ODS('[~T]. #DBG: Xping startup - initalizing application...');
 sc_share := TCriticalSection.Create;

 SetConsoleCtrlHandler (@CtrlHandler, TRUE);
 Shutdown := FALSE;


 try
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Xping';
  Application.CreateForm(TPingForm, PingForm);
  Application.CreateForm(TChartForm, ChartForm);
  Application.Run;
  ODS('[~T]. #DBG: app finalization preparing...');
  try
   ChartForm.Close;
   FreeAndNil (ChartForm);
  except
   on E: Exception do
      OnExceptLog('main', E);
  end;
  ODS('[~T]. #DBG: app finalization start...');
 finally
  sc_share.Free;
  SetConsoleTextAttribute (hCon, $07);
 end;

 Sleep (500);
 WriteLn;
 ExitProcess(0);
end.