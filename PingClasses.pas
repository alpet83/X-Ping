unit PingClasses;

interface

uses
    Windows, Misc, WThreads, DateTimeTools, StrClasses, Math, SysUtils, Classes, Graphics,
    Vcl.Controls, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Ping;


type

  TPingStat = class
  private
     FLost: Integer;
   FEchoes: Integer;
    function GetDelay(index: Integer): Double;
    function GetTime(index: Integer): TDateTime;
  protected
   FDelays: array [0..255] of Double;
    FTimes: array [0..255] of TDateTime;
    FCount: Integer;


  public
   { vars }

   evts_reached: Integer;
   first_reached: TDateTime;
   last_reached: TDateTime;

   { props }
   property     Count: Integer read FCount;
   property     Echoes: Integer read FEchoes;
   property     Delays[index: Integer]: Double read GetDelay;
   property     Times[index: Integer]: TDateTime read GetTime;

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
  TPingRender = class;

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
      FRender: TPingRender;
    FCaption: String;

   function     GetHostObjs(index: Integer): TICMPHost;
   procedure    EnumSubnet(addr: String);
  public
   { props }
   property     Caption: String read FCaption write FCaption;
   property     HostObjs[index: Integer]: TICMPHost read GetHostObjs;
   property     HitRect: TRect read FHitRect;
   property     NameServer: String read FNameServer write FNameServer;
   property     Render: TPingRender read FRender;

   { C & D }
   constructor  Create (AOwner: TObject);
   { methods }
   function     AddHost (const addr: String): TICMPHost;
   procedure    PingAll ();
   function     InProgress: Integer;
   procedure    InitRender(const scheme: String);
  end; // TPingDestination

  TPingThread = class(TWorkerThread)
  private
    FPingDest: TPingDestination;
    FSaveTraffic: Boolean;
  protected
   //
   function             ProcessRequest (const rqs: String; rqobj: TObject): Integer; override;


  public

   property             SaveTraffic: Boolean read FSaveTraffic write FSaveTraffic default true;
   property             PingDest: TPingDestination read FPingDest;
   { methods }
   procedure            WorkProc; override;
  end; // TPingThread

  TPingRender = class(TImage)
  private

    FDest: TPingDestination;
    FRect: TRect;
    FClientRect: TRect;
    FFontName: String;
    FFontSize: Integer;
  protected
      wc: TCanvas;
  public


   property Dest: TPingDestination read FDest;

   property Rect: TRect read FRect;  // postrendered area
   property FontName: String read FFontName write FFontName;
   property FontSize: Integer read FFontSize write FFontSize;


   constructor  Create(AOwner: TComponent); override;


   procedure    DrawAll; virtual;



  end;

  TWideRender = class(TPingRender)
  private
   max_col: Integer;
     n_col: Integer;
     n_row: Integer;

     frame: TRect;

  public

  const
      ROW_HEIGHT  = 15;
     SPACE_HEIGHT = 20;
        COL_WIDTH = 130;


   procedure    DrawAll; override;
   procedure    DrawHost(var x, y: Integer; hst: TICMPHost);
  end;


var
       act_hosts: TStrMap;
  g_ping_timeout: Integer = 1500;
       g_exiting: Integer = 0;


implementation
uses MainForm;

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


function TPingStat.GetDelay(index: Integer): Double;
begin
 result := FDelays[index and 255];
end;

function TPingStat.GetTime(index: Integer): TDateTime;
begin
 result := FTimes [index and 255];
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
     if (d < 0) or (d >= 1000.0) then continue;
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
 try
  pt.Free;
  PingStat.Free;
  IcmpCloseHandle(h_icmp);
 except
  on E: Exception do
     OnExceptLog('TICMPHost.Destroy', E);
 end;
 inherited;
end;

procedure PingApcRoutine(ApcContext, IoStatusBlock: Pointer; Reserved: DWORD); stdcall;
var
   hst: TICMPHost;
   cnt: Integer;
begin
 // dst := ApcContext;
 // if (dst = nil) then exit;

 hst := ApcContext;
 if hst = nil then exit;
 if g_exiting >= 5 then
    wprintf('[~T]. #DBG: last ICMP-reply received for host [%s] ', [hst.Name]);

 if IoStatusBlock = nil then exit;


 hst.OnICMPReply (IoStatusBlock);
end;


function TICMPHost.DoPing(): Boolean;
var
   res, err: DWORD;
   fail: Boolean;
   elps: Double;
   live: Boolean;
     et: DWORD;
      s: String;

begin
 result := FALSE;
 elps := pt.Elapsed (1);

 live := ( Now -  PingStat.last_reached ) < ( 5 * DT_ONE_MINUTE ); // этот хост был активен в течении 5 минут

 et := ping_timeout * 2; // время обнаружения

 if live then
    et := ping_timeout + 500;

 if ping_now and ( elps >= et ) then
  begin
   ping_now := FALSE;
   PingStat.Add ( - elps, g_timer.GetTime );
   if live then
      ODS('~C0C[~T]. #WARN: reply timeout for peer~C0F ' + Name + ' = ~C0D' + ftow(elps, '%.1f~C0F ms') + '~C07');
  end;

 Inc (ping_cnt);

 if FStatus = GET_IP_ERROR then Resolve;
 if FStatus = GET_IP_ERROR then exit;

 // try every 8 attempt if host was never accessible
 if ( ping_cnt < 5 ) or ( ping_cnt and 7 = 1 ) or ( live ) then else exit;
 if ( elps < 750 ) then exit; // interval

 if ( h_icmp = INVALID_HANDLE_VALUE ) or ( ping_now ) then Exit;

  if (g_exiting > 0) then exit;

 // ODS('[~T]. #DBG: ping host ~C0A' + Name + '~C07');
 s := Format('Ping from host %X', [FInAddr.S_addr]);

 StrPCopy ( reqvs, AnsiString (s) );

 FillChar ( reply, sizeof(reply), 0 );
 ping_sent := g_timer.GetTime;
 err := 0;
 fail := FALSE;
 pt.StartOne (2);  // next ping
 SetLastError (0);



 res := IcmpSendEcho2 (h_icmp, 0, PingApcRoutine, self, FInAddr,
                               @reqvs, Length (s),
                               nil, @reply, sizeof(reply), ping_timeout);

 if res = 0 then
    err := GetLastError ();

 if ( err <> 0 ) and ( err <> 997 ) then fail := TRUE;
 ping_now := not fail;
 if ping_now then
    pt.StartOne (1);

 SleepEx (10, TRUE);
 if fail then
    ODS('~C0C[~T]. #WARN: IcmpSendEcho2 returns with error: ~C0F' + err2str (err) + '~C07');

end;

procedure TICMPHost.OnICMPReply (IoStatusBlock: Pointer);
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

 if (res <> 0) and (elps < ping_timeout) and
    ( reply.hdr.Address.S_addr  = FInAddr.S_addr ) and ( Pos('Ping from host', sr) = 1 )  then
  begin
   if reply.hdr.RoundTripTime > 0 then
      elps := Min (elps, 1.0 * reply.hdr.RoundTripTime + 0.5 );
   PingStat.Add ( +elps, ping_sent );
   PingStat.last_reached := g_timer.GetTime;
   Inc (PingStat.FEchoes);

   Pingstat.FLost := 0;
   if PingStat.first_reached = 0 then
      PingStat.first_reached := PingStat.last_reached;

   if ( self = PingForm.sel_host ) then
       PingForm.sel_host_updated := TRUE;
  end
 else
  begin
   PingStat.Add ( -elps, ping_sent );
   Inc (Pingstat.FLost);
   if (Pingstat.FLost >= 10) then
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
   // PingDest.FNameServer := Values['ns'];
   for n := 0 to Count - 1 do
      begin
       s := Strings [n];
       if Pos('=', s) = 0 then PingDest.AddHost (s);
       SaveTraffic := ( Pos('192.168.', s) = 0 ); // for non-local host default
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
 SleepEx(100, TRUE);
 if Terminated then exit;
 if g_exiting >= 10 then StopThread;

 if SaveTraffic and (not PingForm.Active) then exit;

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

 wprintf('[~T]. #DBG: subnet [%s] size [%d]', [addr, cnt]);

 for n := 0 to cnt - 1 do
 with ipf.S_un_b do
  begin
   if (s_b4 > 0) and ( s_b4 < 255 ) then
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


procedure TPingDestination.InitRender(const scheme: String);

var
    ts: TTabSheet;

begin
 ts := TTabSheet.Create(PingForm.PageCtrl);
 ts.PageControl := PingForm.PageCtrl;
 ts.Hint := Name;
 ts.ShowHint := True;
 if Length(Caption) <= 20 then
   ts.Caption := Caption
 else
   ts.Caption := Copy(Caption, 1, 17) + '...';
 if scheme = 'wide' then
   FRender := TWideRender.Create(ts);

 Assert(Assigned(Render), 'Not created Render object for scheme ' + scheme);
 Render.Name := 'imgResults_' + IntToHex(DWORD(Render));
 Render.Left := 0;
 Render.Top := 0;
 Render.Width := ts.ClientWidth;
 Render.Height := ts.ClientHeight;
 Render.Parent := ts;
 Render.FDest := self;
 Render.Show;
end;

function TPingDestination.InProgress: Integer;
var
    i: Integer;
begin
 result := 0;
 for i := 0 to Count - 1 do
  if HostObjs [i].ping_now then
     Inc (result);
end;

procedure TPingDestination.PingAll;
var
   n: Integer;
begin
 if (Count > 0) and (g_exiting <= 9) then
 try
  for n := 0 to Count - 1 do
     begin
      if TWorkerThread (Owner).Terminated then exit;
      HostObjs [n].DoPing ();
     end;

  SleepEx (g_ping_timeout + 100, TRUE); // sleep for APC routing call
 finally
  //
 end;
end;

{ TPingRender }

constructor TPingRender.Create;
begin
 inherited Create(AOwner);
 Assert(Assigned(Owner), 'Render created without Owner');
 Align := alClient;
 OnMouseDown := PingForm.imgResultsMouseDown;
 OnDblClick := PingForm.imgResultsDblClick;
 PopupMenu := PingForm.pmContext;
 FontName := 'Lucida Console';
 FontSize := 8;
end;



procedure TPingRender.DrawAll;
begin
 wc := Canvas;
 Picture.Bitmap.SetSize(ClientWidth, ClientHeight);
end;

{ TWideRender }

procedure TWideRender.DrawAll;

var

   w, h: Integer;
   i, cx, x, y: Integer;


   max_h: Integer;

   n_dest: Integer;
   n_host: Integer;
   cnt_rows: Integer;


   hst: TICMPHost;


begin
 inherited DrawAll;

 wc.Brush.Color := clSilver;
 wc.Brush.Style := bsSolid;
 wc.Pen.Color := clBlack;
 wc.Pen.Style := psSolid;

 w := ClientRect.Width;
 cx := w - 20;
 max_col := Trunc ( cx / (5 * COL_WIDTH) ) * 5; // rounded to 5 for decimal accuracy
 max_col := max (max_col, 1);

 SetRect (frame, 10, 10, w - 10, 0 );

 Assert(Assigned(Dest), 'DrawAll: PingDest unassigned');

 cnt_rows := 0;
 // trying predict height
 n_row := Dest.Count div max_col;      // count of full-filled rows
 if max_col * n_row < Dest.Count then
      Inc(n_row);
 Inc(cnt_rows, n_row);


 with PingForm do
 if PageCtrl.ActivePage = TTabSheet(self.Owner) then
   begin
    sbInfo.Panels[0].Text := 'Dest: ' + Dest.Name;
    // sbInfo.Panels[1].Text := Format('W:%d, H:%d ', [Width, Height]);
   end;
   // if dst.Count > i then     Inc(cnt_rows);

 h := cnt_rows * ROW_HEIGHT;


 max_h := Height;


 wc.Rectangle (0, 0, w, ClientHeight);
 x := frame.Left;
 y := frame.Top + 5;

 n_row := 0;
 n_col := 0;
 wc.Font.Name := FontName;
 wc.Font.Size := FontSize;

 if Dest.TryLock ('Dump') then
 try
  for n_host := 0 to Dest.Count - 1 do
   begin
    if y + ROW_HEIGHT > Height then break;

    hst := Dest.HostObjs [n_host];
    if (hst = nil) then continue;
    DrawHost(x, y, hst);
   end; // for n_host

  frame.Bottom := y + SPACE_HEIGHT;

  wc.Brush.Style := bsClear;
  wc.Rectangle (frame);
  //  wc.TextOut (30, frame.Top - 5, Format('FT:%d,FB:%d', [Frame.Top, Frame.Bottom]));
  // self.Paint;
 finally
  Dest.Unlock;
 end;

end;


procedure TWideRender.DrawHost(var x, y: Integer; hst: TICMPHost);
var
  pst: TPingStat;
   tf: TTextFormat;
   ts: String;
    s: String;
    r: TRect;
    i: Integer;
   stability, speed: Double;

begin
  pst := hst.PingStat;
  if (pst = nil) then exit;

  tf := [tfBottom, tfRight];
  s := hst.Name;
  if pst.Count = 0 then
     stability := 0
  else
     stability := 100.0 * pst.Reached / pst.Count;

  if (stability = 100) and (act_hosts.IndexOfName(s) < 0) then
     begin
      act_hosts.Add(s + '=' + FormatDateTime('dd.mm-hh:nn:ss', Now));
      ts := FormatDateTime('dd.mm-hh:nn:ss', pst.first_reached);
      wprintf('[~T].~C0B #PING:~C07 host registered [%35s], first ping [%s] ', [s, ts]);
     end;

  i := act_hosts.IndexOfName(s);

  if (stability < 90) and (i >= 0) then
     begin
      act_hosts.Delete(i);
      wprintf('[~T].~C0C #PING:~C07 host lost       [%35s]', [s]);
     end;

  SetRect (hst.rhit, x, y - 1, x + COL_WIDTH, y + 11);

  r.Height := ROW_HEIGHT;
  wc.Brush.Style := bsClear;

  if hst.sub_addr <> '' then
    begin
     wc.TextOut (x + 3, y, hst.sub_addr);
     s := '----->';
     r.SetLocation(x + 25, y);
     r.Width := 35;
     wc.TextRect(r, s, tf);
    end
  else
     wc.TextOut (x + 3, y, hst.Name);
  if pst.Echoes < 1000 then
    begin
     wc.Brush.Style := bsSolid;
     if pst.Echoes > 0 then
        wc.Brush.Color    := clRed;
     if pst.Echoes > 10 then
        wc.Brush.Color := clYellow;
     if pst.Echoes > 20 then
        wc.Brush.Color := clLime;

     s := IntToStr(pst.Echoes);
    end
  else
   begin
    wc.Brush.Color := $50FF50;
    if pst.Echoes >= 10000 then
      s := ftow(pst.Echoes / 1000.0, '%.0f') + 'K+'
    else
      s := ftow(pst.Echoes / 1000.0, '%.1f') + 'K+';
   end;

  r.SetLocation(X + COL_WIDTH - 75, y);
  r.Width := 40;


  wc.TextRect(r, s, tf);
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

  wc.Ellipse (x + COL_WIDTH - 30, y, x + COL_WIDTH - 20, y + 10);
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

  wc.Rectangle ( x + COL_WIDTH - 15, y, x + COL_WIDTH - 05, y + 10 );

  x := x + COL_WIDTH;

  wc.MoveTo (x, y);
  wc.LineTo (x, y + 12);

  Inc (n_col);
  if (n_col >= max_col) then
   begin
    n_col := 0;
    Inc (y, ROW_HEIGHT);
    x := frame.Left;
   end;

end;

end.
