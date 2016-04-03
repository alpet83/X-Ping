unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Ping, Misc, ShellAPI,  Vcl.Imaging.jpeg, Vcl.Imaging.PngImage,
  Dialogs, ComCtrls, StdCtrls, ExtCtrls, WThreads, DateTimeTools, StrClasses, Math, IniFiles, Vcl.Menus;

type

  TPingStat = class
  private
   FEchoes: Integer;
  protected
   FDelays: array [0..255] of Double;
   FTimes: array [0..255] of TDateTime;
   FCount: Integer;
  public
   { vars }

   evts_reached: Integer;
   last_reached: TDateTime;

   { props }
   property     Count: Integer read FCount;
   property     Echoes: Integer read FEchoes;

   { C & D }
   constructor  Create;

   { methods }
   procedure    Add (d, dt: Double);
   function     Last: Double;
   function     Median: Double;
   function     Reached: Integer;
   function     Skipped: Integer;
  end;

  TPingDestination = class;

  TICMPHost = class
  private
        FName: String;
      FInAddr: TIPAddr;
    FPingStat: TPingStat;
       h_icmp: THandle;
     reqvs: array [0..63] of AnsiChar;
     reply: record
             hdr: ICMP_ECHO_REPLY;
             data: array [0..127] of AnsiChar;
            end;
     ping_now: Boolean;
     ping_cnt: Integer;
     ping_sent: TDateTime;
     ping_timeout: DWORD;
        FStatus: String;
    FNameServer: String;


  protected
     pt: TProfileTimer;
     FOwner: TPingDestination;
     sub_addr: String;
  public

   rHit: TRect; // hitRect



   { props }
   property     Name: String read FName;
   property     NameServer: String read FNameServer write FNameServer;
   property     PingStat: TPingStat read FPingStat;
   property     Owner: TPingDestination read FOwner;
   property     Status: String read FStatus;

   { C & D }
   constructor  Create(const AName: String);
   destructor   Destroy; override;

   { methods }
   function     DoPing: Boolean;
   procedure    OnICMPReply (IoStatusBlock: Pointer);
   procedure    Resolve;

  end; // TICMPHost

  TPingDestination = class (TStrMap)
  private
     FHitRect: TRect;
  FNameServer: String;

   function     GetHostObjs(index: Integer): TICMPHost;
   procedure    EnumSubnet(addr: String);
  public
   { props }
   property     HostObjs[index: Integer]: TICMPHost read GetHostObjs;
   property     HitRect: TRect read FHitRect;
   property     NameServer: String read FNameServer write FNameServer;
   { C & D }
   constructor  Create (AOwner: TObject);
   { methods }
   function     AddHost (const addr: String): TICMPHost;
   procedure    PingAll ();
  end; // TPingDestination

  TPingThread = class(TWorkerThread)
  private
    FPingDest: TPingDestination;
  protected
   //
   function                   ProcessRequest (const rqs: String; rqobj: TObject): Integer; override;


  public

   property             PingDest: TPingDestination read FPingDest;
   { methods }
   procedure            WorkProc; override;
  end; // TPingThread


  TPingForm = class(TForm)
    tmrUpdate: TTimer;
    imgResults: TImage;
    chxDrawStat: TCheckBox;
    pmContext: TPopupMenu;
    miLookupHost: TMenuItem;
    miShowLog: TMenuItem;
    miSaveSS: TMenuItem;
    svdlg: TSaveDialog;
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
    procedure WMEraseBackground (var msg: TMessage); message WM_ERASEBKGND;
  private
    dest_list: TStrMap;
    mouse_pt: TPoint;
    sel_host: TICMPHost;
    ctx_host: TICMPHost;


    procedure PaintResults;
    procedure AddDest(const dstl, ns: String);
    function MouseOnHost: TICMPHost;
    { Private declarations }
  public
    { Public declarations }
    last_results: TStrMap;
    sel_host_updated: Boolean;


    procedure LoadConfig;
  end;

var
  PingForm: TPingForm;
  g_ping_timeout: Integer = 1500;


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

begin
 fini := TIniFile.Create ( FindConfigFile ('xping.conf') );
 try
  g_ping_timeout := fini.ReadInteger ('config', 'PingTimeout', 1500);
  for n := 0 to 9 do
   begin
    k := 'destination' + IntToStr(n);
    s := fini.ReadString ('config', k, '');
    if s = '' then continue;
    k := 'nameserver' + IntToStr(n);
    ns := fini.ReadString ('config', k, '');
    AddDest (s, ns);
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
begin
 svdlg.FileName := 'xping_' + FormatDateTime('yy-mm-dd hh-nn', Now) + '.png';
 if not svdlg.Execute() then exit;


 pimg := TPNGImage.Create;
 try
  pimg.Assign(imgResults.Picture.Bitmap);
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

procedure TPingForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
   n: Integer;
 pth: TPingThread;
begin
 ODS('[~T]. #DBG: FormCloseQuery processing...');
 try
   Hide;
   for n := dest_list.Count - 1 downto 0 do
    begin
     pth := TPingThread ( dest_list.Objects [n] );
     pth.StopThread;
    end;
   for n := dest_list.Count - 1 downto 0 do
    begin
     pth := TPingThread ( dest_list.Objects [n] );
     pth.WaitStop();
    end;
 except
  on E: Exception do
     PrintError(' Exception catched ' + E.Message);
 end;
 CanClose := TRUE;
end;

procedure TPingForm.FormCreate(Sender: TObject);
begin
 dest_list := TStrMap.Create (self);
 g_timer := TVirtualTimer.Create;

 PaintResults;
 LoadConfig;
 if dest_list.Count = 0 then AddDest('localhost', '');
 imgResults.Left := 0;
 imgResults.Top := 0;
 FormResize (nil);
 Caption := 'Xping v. ' + GetFileVersionStr('');
end;

procedure TPingForm.FormDestroy(Sender: TObject);
var
     n: Integer;
   pth: TPingThread;
begin
 for n := dest_list.Count - 1 downto 0 do
  try
   pth := TPingThread ( dest_list.Objects [n] );
   if not pth.Terminated then
      pth.StopThread;
   pth.WaitStop;
   pth.Free;
   dest_list.Delete (n);
  except
  end;
 dest_list.Free;
end;

procedure TPingForm.FormResize(Sender: TObject);
var
   w, h: Integer;
begin
 w := self.ClientWidth - 1;
 h := self.ClientHeight - 1;
 imgResults.Width := w;
 imgResults.Height := h;
 imgResults.Picture.Bitmap.SetSize ( w, h );
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
       pingTimes.Add ( Abs (pst.FDelays [n]), FormatDateTime ( 'ss.zzz', pst.FTimes [n] )  );

   Show;
  end;

end;


procedure TPingForm.imgResultsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 mouse_pt.X := x;
 mouse_pt.Y := y;
 ctx_host := MouseOnHost;
end;

procedure TPingForm.AddDest(const dstl, ns: String);
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

 pth.AddRequest ('ADD_DEST', tmpl);
end;


procedure TPingForm.PaintResults;


var
   wc: TCanvas;
   w, h: Integer;
   cx, x, y: Integer;

   frame: TRect;
   cell_w, max_col: Integer;
   n_dest: Integer;
   n_host: Integer;
   n_col, n_row: Integer;

   stability, speed: Double;

   pth: TPingThread;
   dst: TPingDestination;
   hst: TICMPHost;
   pst: TPingStat;
begin
 wc := imgResults.Canvas;
 wc.Brush.Color := clSilver;
 wc.Brush.Style := bsSolid;
 wc.Pen.Color := clBlack;
 wc.Pen.Style := psSolid;

 w := imgResults.Width;
 h := imgResults.Height;

 wc.Rectangle (0, 0, w + 1, h + 1);

 cell_w := 130; // IP + lamps

 SetRect (frame, 10, 10, w - 10, 100 );

 cx := frame.Right - frame.Left;

 max_col := Trunc ( cx / (5 * cell_w) ) * 5;

 for n_dest := 0 to dest_list.Count - 1 do
  begin
   pth := TPingThread ( dest_list.Objects [n_dest] );

   dst := pth.PingDest;
   if dst = nil then continue;

   x := frame.Left;
   y := frame.Top + 5;

   n_row := 0;
   n_col := 0;


   if dst.Name <> '' then
    begin
     wc.Font.Size := 10;
     wc.TextOut (x + 3, y, dst.Name);
     y := frame.Top + 20;
    end;

   wc.Font.Size := 7;




   if dst.TryLock ('Dump') then
   try
    for n_host := 0 to dst.Count - 1 do
     begin
      hst := dst.HostObjs [n_host];
      if (hst = nil) then continue;
      pst := hst.PingStat;

      if (pst = nil) then continue;



      if pst.Count = 0 then
         stability := 0
      else
         stability := 100.0 * pst.Reached / pst.Count;


      SetRect (hst.rhit, x, y - 1, x + cell_w, y + 11);

      wc.Brush.Style := bsClear;
      if hst.sub_addr <> '' then
         wc.TextOut (x + 3, y, hst.sub_addr + ' ---------->')
      else
         wc.TextOut (x + 3, y, hst.Name);

      if pst.Echoes < 100 then
        begin
         wc.Brush.Style := bsSolid;

         if pst.Echoes > 0 then
            wc.Brush.Color    := clRed;
         if pst.Echoes > 10 then
            wc.Brush.Color := clYellow;
         if pst.Echoes > 20 then
            wc.Brush.Color := clLime;

         wc.TextOut(x + cell_w - 70, y, IntToStr(pst.Echoes));
        end
      else
         wc.TextOut(x + cell_w - 70, y, '100+');

      wc.Brush.Style := bsSolid;

      // paint lamp of stability
      if (pst.last_reached = 0) then
        begin
         if hst.Status = GET_IP_ERROR then
           wc.Brush.Color := clPurple
         else
           wc.Brush.Color := clGray
        end
         else
      if stability = 100 then
         wc.Brush.Color := clLime else
      if stability >= 90 then
         wc.Brush.Color := clGreen else
      if stability >= 50 then
         wc.Brush.Color := clYellow else
         wc.Brush.Color := clRed;

      wc.Ellipse (x + cell_w - 30, y, x + cell_w - 20, y + 10);
      // paint lamp of speed

      if stability > 0 then
         speed := pst.Median
      else
         speed := 1000;

      if (pst.last_reached = 0) then
         wc.Brush.Color := clGray else
      if speed <= 1 then
         wc.Brush.Color := clLime else
      if speed <= 10 then
         wc.Brush.Color := clGreen else
      if speed < 50 then
         wc.Brush.Color := clYellow else
      if speed < 100 then
         wc.Brush.Color := RGB(160, 160, 0) else
         wc.Brush.Color := clRed;

      wc.Rectangle ( x + cell_w - 15, y, x + cell_w - 05, y + 10 );

      x := x + cell_w;

      wc.MoveTo (x, y);
      wc.LineTo (x, y + 12);

      Inc (n_col);
      if (n_col >= max_col) then
       begin
        n_col := 0;
        Inc (y, 12);
        x := frame.Left;
       end;
     end; // for n_host

    frame.Bottom := y + 20;

    wc.Brush.Style := bsClear;
    wc.Rectangle (frame);
    frame.Top := y + 30;
   finally
    dst.Unlock;
   end;


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

{ TPingStat }

procedure TPingStat.Add(d, dt: Double);
begin
 if Count <= High (FDelays) then
    Inc (FCount)
 else
    // dest [0] = source [1]
   begin
    Move (FDelays[1], FDelays[0], sizeof(FDelays[0]) * ( FCount - 1 ) ); // смещение всего массива на элемент влево
    Move (FTimes[1],  FTimes[0],  sizeof(FTimes[0]) * ( FCount - 1 ) ); // смещение всего массива на элемент влево
   end;

 FDelays [Count - 1] := d;
 FTimes [Count - 1] := dt;


 if d > 0 then Inc (evts_reached);
end;

constructor TPingStat.Create;
begin
 // nothing?
end;

function TPingStat.Last: Double;
begin
 result := 0;
 if FCount > 0 then result := FDelays [Count - 1];
end;

function TPingStat.Median: Double;
var
   n, cnt: Integer;
   d: Double;
begin
 result := 0;
 cnt := 0;

 for n := 0 to Count - 1 do
    begin
     d := FDelays [n];
     if d < 0 then continue;
     result := result + d;
     Inc (cnt);
    end;


 if cnt > 0 then result := result / cnt;
end;

function TPingStat.Reached: Integer;
var n: Integer;
begin
 result := 0;
 for n := 0 to Count - 1 do
     if FDelays [n] >= 0 then Inc (result);
end;

function TPingStat.Skipped: Integer;
var n: Integer;
begin
 result := 0;
 for n := 0 to Count - 1 do
     if FDelays [n] < 0 then Inc (result);
end;

{ TICMPHost }

constructor TICMPHost.Create(const AName: String);
begin
 FName := AName;
 Resolve;

 FPingStat := TPingStat.Create;
 pt := TProfileTimer.Create;
 h_icmp := IcmpCreateFile;;
 ping_timeout := g_ping_timeout;
end;

destructor TICMPHost.Destroy;
begin
 pt.Free;
 PingStat.Free;
 IcmpCloseHandle(h_icmp);
 inherited;
end;

procedure PingApcRoutine(ApcContext, IoStatusBlock: Pointer; Reserved: DWORD); stdcall;
var
   hst: TICMPHost;
begin
 // dst := ApcContext;
 // if (dst = nil) then exit;
 hst := ApcContext;
 if hst = nil then exit;

 if IoStatusBlock = nil then exit;


 hst.OnICMPReply (IoStatusBlock);
end;


function TICMPHost.DoPing(): Boolean;
var
   res, err: DWORD;
   fail: Boolean;
   elps: Double;
   s: String;

begin
 result := FALSE;
 elps := pt.Elapsed (1);
 if ping_now and ( elps > 3 * ping_timeout ) then
  begin
   ping_now := FALSE;
   PingStat.Add ( - elps, g_timer.GetTime );
   ODS('~C0C[~T]. #WARN: Hard timeout for peer~C0F ' + Name + ' =~C0D' + ftow(elps, '%.1f~C0F ms') + '~C07');
  end;


 Inc (ping_cnt);

 if FStatus = GET_IP_ERROR then Resolve;
 if FStatus = GET_IP_ERROR then exit;


 if ( ping_cnt and 15 = 1 ) or ( PingStat.last_reached > 0 ) then else exit;

 if ( h_icmp = INVALID_HANDLE_VALUE ) or ( ping_now ) then Exit;


 // ODS('[~T]. #DBG: ping host ~C0A' + Name + '~C07');


 s := Format('Ping from host %X', [FInAddr.S_addr]);

 StrPCopy ( reqvs, AnsiString (s) );

 FillChar (reply, sizeof(reply), 0);


 ping_sent := g_timer.GetTime;


 err := 0;
 fail := FALSE;
 pt.StartOne (2);
 SetLastError (0);
 res := IcmpSendEcho2 (h_icmp, 0, PingApcRoutine, self, FInAddr,
                               @reqvs, Length (s),
                               nil, @reply, sizeof(reply), ping_timeout);
 if res = 0 then
    err := GetLastError ();
 pt.StartOne (1);
 if ( err <> 0 ) and ( err <> 997 ) then fail := TRUE;
 ping_now := not fail;
 SleepEx (10, TRUE);

 if fail then
    ODS('~C0C[~T]. #WARN: IcmpSendEcho2 returns with error: ~C0F' + err2str (err) + '~C07');


end;

procedure TICMPHost.OnICMPReply(IoStatusBlock: Pointer);
var
   elps: Double;
   res: DWORD;
   sr: String;
begin
 elps := pt.Elapsed (1);
 ping_now := FALSE;

 res := IcmpParseReplies ( @reply, 128 );
 reply.data [127] := #0;

 sr := AnsiTrim2W ( PAnsiChar (@reply.data[4]) );

 if (res <> 0) and (elps < ping_timeout) and ( reply.hdr.Address.S_addr  = FInAddr.S_addr ) and ( Pos('Ping from host', sr) = 1 )  then
  begin
   if reply.hdr.RoundTripTime > 0 then
      elps := Min (elps, 1.0 * reply.hdr.RoundTripTime + 0.5 );
   PingStat.Add ( +elps, ping_sent );
   PingStat.last_reached := g_timer.GetTime;
   Inc (PingStat.FEchoes);

   if ( self = PingForm.sel_host ) then
       PingForm.sel_host_updated := TRUE;
  end
 else
  begin
   PingStat.Add ( -elps, ping_sent );
   PingStat.FEchoes := 0;
  end;

end;

procedure TICMPHost.Resolve;
begin
 if TranslateStringToTInAddr(Name, FInAddr) then
    FStatus := 'READY'
 else
    FStatus := GET_IP_ERROR;
end;

{ TPingThread }

function TPingThread.ProcessRequest(const rqs: String; rqobj: TObject): Integer;
var
   n: Integer;
   s: String;
begin
 result := inherited ProcessRequest (rqs, rqobj);

 if rqs = 'INIT' then
  begin
   FPingDest := TPingDestination.Create(self);
   wait_time := 50;
   Priority := tpHigher;
  end;


 if (rqs = 'ADD_DEST') and ( Assigned (rqobj) ) then
  with TStrMap (rqobj) do
  begin
   PingDest.FNameServer := Values['ns'];

   for n := 0 to Count - 1 do
      begin
       s := Strings [n];
       if Pos('=', s) = 0 then PingDest.AddHost (s);
      end;
   rqobj.Free;
  end;

 if (rqs = 'STOPTHREAD') then
  begin
   FreeAndNil (FPingDest);
  end;
end;

procedure TPingThread.WorkProc;
begin
 inherited;
 if Terminated then exit;

 if Assigned (PingDest) and (PingDest.Count > 0) then
    PingDest.PingAll ();
end;

{ TPingDestination }

function TPingDestination.AddHost(const addr: String): TICMPHost;
begin
 result := nil;

 if Pos('/', addr) > 0 then
    self.EnumSubnet ( addr )
 else
  if IndexOf (addr) >= 0 then
     begin
      result := FindObject (addr) as TICMPHost;
     end
    else
     begin
      result := TICMPHost.Create (addr);
      result.FOwner := self;
      result.FNameServer := NameServer;
      AddObject ( addr, result );
     end;
end;

constructor TPingDestination.Create(AOwner: TObject);

begin
 inherited Create (AOwner);
 OwnsObjects := TRUE;
end;


procedure TPingDestination.EnumSubnet(addr: String);
var
   mask: String;
   bits: Integer;
   cnt: Integer;
   ipf: TIPAddr;
   ips: DWORD;
   hst: TICMPHost;
   n: Integer;
begin

 if Name = '' then Name := Addr;

 mask := '32';
 if Pos('/', addr) > 0 then
  begin
   mask := addr;
   addr := StrTok (mask, ['/']);
  end;

 bits := atoi (mask);
 if bits < 24 then bits := 24; // большие подсети не поддерживаются

 TranslateStringToTInAddr (addr, ipf);
 ips := ipf.S_addr;

 cnt := 1 shl (32 - bits);

 for n := 0 to cnt - 1 do
 with ipf.S_un_b do
  begin
   if (s_b4 > 0) and ( s_b4 < 250 ) then
    begin
     hst := AddHost ( Format('%d.%d.%d.%d',  [s_b1, s_b2, s_b3, s_b4] ) );
     if hst <> nil then hst.sub_addr := IntToStr ( s_b4 );
    end;
   Inc (s_b4);
  end;

end; // EnumSubnet

function TPingDestination.GetHostObjs(index: Integer): TICMPHost;
begin
 result := TICMPHost ( Objects [index] );
end;


procedure TPingDestination.PingAll;
var
   n: Integer;
begin
 if (Count > 0) then
 try
  SleepEx (100, TRUE);
  for n := 0 to Count - 1 do
     begin
      HostObjs [n].DoPing ();
      if TWorkerThread (Owner).Terminated then exit;
     end;

  SleepEx (g_ping_timeout + 100, TRUE);
 finally
  //
 end;
end;

end.
