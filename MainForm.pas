unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Ping, Misc, ShellAPI,  Vcl.Imaging.jpeg, Vcl.Imaging.PngImage,
  Dialogs, ComCtrls, StdCtrls, ExtCtrls, WThreads, DateTimeTools, StrClasses, Math, IniFiles, Vcl.Menus, PingClasses;

type


  TPingForm = class(TForm)
    tmrUpdate: TTimer;
    chxDrawStat: TCheckBox;
    pmContext: TPopupMenu;
    miLookupHost: TMenuItem;
    miShowLog: TMenuItem;
    miSaveSS: TMenuItem;
    svdlg: TSaveDialog;
    sbInfo: TStatusBar;
    PageCtrl: TPageControl;
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrUpdateTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure imgResultsDblClick(Sender: TObject);
    procedure imgResultsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure miShowLogClick(Sender: TObject);
    procedure miLookupHostClick(Sender: TObject);
    procedure miSaveSSClick(Sender: TObject);
  protected
    procedure DrawHostStat;
    procedure WMEraseBackground (var msg: TMessage); // message WM_ERASEBKGND;
  private
    dest_list: TStrMap;



    procedure PaintResults;
    function  AddDest(const dstl: String): TPingThread;
    function  MouseOnHost: TICMPHost;
    function  ActiveRequests: Integer;
    { Private declarations }
  public
    { Public declarations }
    last_results: TStrMap;
    sel_host_updated: Boolean;

    mouse_pt: TPoint;
    sel_host: TICMPHost;
    ctx_host: TICMPHost;

    procedure LoadConfig;
  end;




var
       PingForm: TPingForm;



implementation
uses StatChart;

{$R *.dfm}

{ TPingForm }
procedure TPingForm.WMEraseBackground;
begin
end;

procedure TPingForm.LoadConfig;
var
   fini: TIniFile;
   n: Integer;
   s, k, ns: String;
   pth: TPingThread;

begin
 fini := TIniFile.Create ( FindConfigFile ('xping.conf') );
 try
  g_ping_timeout := fini.ReadInteger ('config', 'PingTimeout', 2500);
  for n := 0 to 9 do
   begin
    k := 'destination' + IntToStr(n);
    if fini.SectionExists(k) then
      begin
       s := fini.ReadString(k, 'netaddr', '');
       if s = '' then continue;
       pth := AddDest(s);
       pth.SaveTraffic := fini.ReadBool(k, 'SaveTraffic', Pos('192.168.', s) + Pos('10.10.', s) = 0);
       s := fini.ReadString(k, 'caption', s);
       pth.PingDest.Caption := s;
       s := fini.ReadString(k, 'nameserver', '');
       pth.PingDest.NameServer := s;

       s := fini.ReadString(k, 'render', 'wide');
       pth.PingDest.InitRender(s);
       with pth.PingDest.Render do
        begin
         FontName := fini.ReadString (k, 'FontName', FontName);
         FontSize := fini.ReadInteger(k, 'FontSize', FontSize);
        end;
      end
    else
      begin // obsolete config type
       s := fini.ReadString ('config', k, '');
       if s = '' then continue;
       k := 'nameserver' + IntToStr(n);
       ns := fini.ReadString ('config', k, '');
       pth := AddDest (s);
       pth.SaveTraffic := (Pos('192.168.', pth.PingDest.Name) + Pos('10.10.', pth.PingDest.Name) = 0);
       pth.PingDest.Caption := s;
       pth.PingDest.NameServer := ns;
       pth.PingDest.InitRender('wide');
       Assert (Assigned(pth.PingDest.Render));
      end;
   end;
 finally
  fini.Free;
 end;
end;

procedure TPingForm.miLookupHostClick(Sender: TObject);
var
   s, dir, ftmp: String;
   einf: _SHELLEXECUTEINFO;
   buff: AnsiString;
   hFile: THandle;
   fsize: Integer;
      rb: DWORD;

begin
 if ctx_host = nil then exit;


 dir := GetEnvironmentVariable ('TEMP');
 if dir = '' then
    dir := ExtractFilePath (gLogFileName);

 ftmp := CorrectFilePath (dir + '\nslookup.log');


 FillChar (einf, sizeof(einf), 0);

 s := 'nslookup.exe ' + ctx_host.Name + ' ' + ctx_host.NameServer;

 einf.cbSize := sizeof (einf);
 einf.Wnd := Handle;
 einf.lpFile := 'cmd.exe';
 einf.lpParameters := PChar ( ' /C ' + s  + ' > ' + ftmp);
 einf.nShow := SW_HIDE;
 einf.fMask := 0;

 ShellExecuteExW ( @einf );

 if FileExists (ftmp) then
  begin

   ShowMessage('Please wait for complete operation ~= 15 sec');
   rb := 0;
   repeat
    Inc (rb);
    Sleep (500);
    hFile := CreateFile (PChar(ftmp), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_ALWAYS, 0, 0);
   until (hFile <> INVALID_HANDLE_VALUE) or (rb > 50);

   if (hFile = INVALID_HANDLE_VALUE) then exit;

   fsize := GetFileSize (hFile, nil);

   SetLength (buff, fsize);

   ReadFile (hFile, buff[1], fsize, rb, nil);


   s := s + #13#10 + String ( PAnsiChar(buff) );

   ShowMessage (s);

   SetLength (buff, 0);

   CloseHandle (hFile);

   DeleteFile (ftmp);
  end;
end;

procedure TPingForm.miSaveSSClick(Sender: TObject);
var
   pimg: TPNGImage;
    rnd: TPingRender;
     ts: TTabSheet;
      n: Integer;
begin
 ts := PageCtrl.ActivePage;
 if ts = nil then exit;
 rnd := nil;
 if Sender is TPingRender then
   rnd := TPingRender(Sender);

 if (ts.ControlCount > 0) and Assigned(ts.Controls[0]) and (ts.Controls[0] is TPingRender) then
   rnd := TPingRender(ts.Controls[0]);

 if nil = rnd then exit;

 svdlg.FileName := 'xping_' + FormatDateTime('yy-mm-dd hh-nn', Now) + '.png';
 if not svdlg.Execute() then exit;

 pimg := TPNGImage.Create;
 try
  pimg.Assign(rnd.Picture.Bitmap); // TODO: imgResults.Picture.Bitmap
  pimg.CompressionLevel := 7;
  pimg.SaveToFile( svdlg.FileName );
 finally
  pimg.Free;
 end;

end;

procedure TPingForm.miShowLogClick(Sender: TObject);
begin
 if miShowLog.Checked then
    ShowConsole (SW_SHOW)
 else
    HideConsole ();
end;

function TPingForm.ActiveRequests: Integer;
var
    i: Integer;
  pth: TPingThread;
begin
 result := 0;
 for i := 0 to dest_list.Count - 1 do
  begin
   pth := TPingThread ( dest_list.Objects [i] );
   Inc (result, pth.PingDest.InProgress);
  end;
end;

procedure TPingForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
   n: Integer;
 cnt: Integer;
 pth: TPingThread;
begin
 chxDrawStat.checked := FALSE;
 tmrUpdate.Enabled := FALSE;

 try
   ChartForm.Hide;
   Hide;
   g_exiting := 1;
   Sleep (g_ping_timeout);

   for n := 1 to 10 do
     begin
      Inc (g_exiting);
      cnt := ActiveRequests;
      if (cnt > 0) then
       begin
        wprintf ('[~T]. #DBG: stopping %d threads, stage %d, active_rqs %d ', [dest_list.Count, n, cnt]);
        Sleep (g_ping_timeout div 2);
        Application.ProcessMessages;
      end;
     end;

   for n := dest_list.Count - 1 downto 0 do
    begin
     pth := TPingThread ( dest_list.Objects [n] );
     pth.WaitStop(10500);
    end;
   ODS('[~T]. #DBG: all threads stopped');
   ChartForm.Close;
 except
  on E: Exception do
     PrintError(' Exception catched ' + E.Message);
 end;
 CanClose := TRUE;
end;

procedure TPingForm.FormCreate(Sender: TObject);
begin
 dest_list := TStrMap.Create (self);
 act_hosts := TStrMap.Create(self);
 g_timer := TVirtualTimer.Create;

 Constraints.MaxHeight := Screen.Height;

 PaintResults;
 LoadConfig;
 if dest_list.Count = 0 then
  with AddDest('localhost') do
   begin
    PingDest.Caption := 'default';
    PingDest.InitRender('wide');
    ODS('[~T]. #WARN: From configuration file not loaded any host!');
   end;

 FormResize (nil);
 Caption := 'Xping v. ' + GetFileVersionStr('');
end;

procedure TPingForm.FormDestroy(Sender: TObject);
var
     n: Integer;
   pth: TPingThread;
begin
 tmrUpdate.Enabled := FALSE;

 ODS('[~T]. #DBG: releasing threads');
 for n := dest_list.Count - 1 downto 0 do
  try
   pth := TPingThread ( dest_list.Objects [n] );
   if not pth.Terminated then pth.StopThread;
   // pth.FreeOnTerminate := TRUE;
   pth.WaitStop;
   pth.Free;

   dest_list.Delete (n);
  except
   on E: Exception do
     OnExceptLog('FormDestroy', E);
  end;

 FreeAndNil (dest_list);
 FreeAndNil (act_hosts);
 ODS('[~T]. #DBG: FormDestroy exit');
end;

procedure TPingForm.FormResize(Sender: TObject);
var
   w, h: Integer;
begin
 w := self.ClientWidth - 1;
 h := self.ClientHeight - 1;
 // imgResults.Width := w - 20;
 // imgResults.Picture.Bitmap.SetSize ( w, h );
 PaintResults;
end;

function  TPingForm.MouseOnHost: TICMPHost;
var
   hst: TICMPHost;
   pth: TPingThread;
   pst: TPingStat;
   dst: TPingDestination;
   found: Boolean;
   n_dest: Integer;
   n_host: Integer;

begin
 found := FALSE;
 hst := nil;
 pst := nil;
 result := nil;

 for n_dest := 0 to dest_list.Count - 1 do
  begin
   pth := TPingThread ( dest_list.Objects [n_dest] );

   dst := pth.PingDest;
   if dst = nil then continue;
   if dst.Render.TabSheet <> PageCtrl.ActivePage then continue;
   // dy := dst.Render.ScrollBox.VertScrollBar.Position;

   for n_host := 0 to dst.Count - 1 do
     begin
      hst := dst.HostObjs [n_host];
      if (hst = nil) then continue;


      with hst.rHit, mouse_pt do
      if ( x >= left ) and ( y >= top ) and
         ( x <= right ) and ( y <= bottom ) then
        begin
         found := (hst.PingStat <> nil);
         break;
        end;

     end;
   if found then break;
  end; // for n_dest

 result := hst;
end;

procedure TPingForm.imgResultsDblClick(Sender: TObject);
begin
 if ctx_host = nil then exit;
 sel_host := ctx_host;
 DrawHostStat;
end;

procedure TPingForm.DrawHostStat;
var n: Integer;
   pst: TPingStat;
begin
 pst := sel_host.PingStat;
 if pst = nil then exit;

 ChartForm.Caption := 'Ping stat for ' + sel_host.Name;

 with ChartForm do
  begin
   pingTimes.clear;

   for n := 0 to pst.Count - 1 do
       pingTimes.Add ( Abs (pst.Delays [n]), FormatDateTime ( 'ss.zzz', pst.Times [n] )  );

   Show;
  end;

end;


procedure TPingForm.imgResultsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
   dt: TDateTime;
   ps: TPingStat;
    s: String;
begin
 mouse_pt.X := x;
 mouse_pt.Y := y;
 ctx_host := MouseOnHost;
 if Assigned(ctx_host) then
  begin
    ps := ctx_host.PingStat;

    dt := ps.last_reached;
    if dt > 0.1 then
      s := Format(' last seen: %s, average ping %.1f ms',
                                        [FormatDateTime('mmm dd hh:nn:ss', dt), ps.Median])
    else
      s := ' last seen: never';
    sbInfo.Panels[1].Text := ctx_host.Name + s;
  end;
end;

function TPingForm.AddDest;
var
   tmpl: TStrMap;
   sfx: String;
   pth: TPingThread;
   i: Integer;
begin
 tmpl := TStrMap.Create;
 tmpl.Split (';', dstl);

 for i := tmpl.Count - 1 downto 0 do
      if Trim ( tmpl [i] ) = '' then tmpl.Delete(i);


 i := dest_list.IndexOf (dstl);
 if i < 0 then
  begin
   sfx := IntToStr(dest_list.Count);
   pth := TPingThread.Create (FALSE, 'ping_th#0' + sfx);
   dest_list.AddObject (dstl, pth);
  end
 else
  pth := TPingThread (dest_list.Objects [i]);

 pth.WaitStart();
 pth.AddRequest ('ADD_DEST', tmpl);
 pth.WaitRequests();
 Assert(Assigned(pth));
 result := pth;
end;


procedure TPingForm.PaintResults; // Render here
var
      dst: TPingDestination;
      pth: TPingThread;
   n_dest: Integer;
begin
  for n_dest := 0 to dest_list.Count - 1 do
   begin
     pth := TPingThread ( dest_list.Objects [n_dest] );
     Assert ( Assigned (pth), 'Thread object not assiged for ' + dest_list[n_dest] );
     dst := pth.PingDest;
     if dst = nil then continue;
     Assert ( Assigned(dst.Render), 'Render was not created for ' + dest_list[n_dest] );
     dst.Render.DrawAll;
   end;
end;


procedure TPingForm.tmrUpdateTimer(Sender: TObject);
begin
 PaintResults;

 if sel_host_updated then
   begin
    sel_host_updated := FALSE;
    if chxDrawStat.checked then DrawHostStat;
   end;
end;



end.
