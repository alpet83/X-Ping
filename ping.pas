unit Ping;

interface
uses
  Windows, SysUtils, Classes, Misc;

const
  ICMP_LIB = 'iphlpapi.dll'; // icmp.dll
  GET_IP_ERROR = 'GET_IP_ERROR';




type
  PIO_APC_ROUTINE = procedure (ApcContext, IoStatusBlock: Pointer; Reserved: DWORD); stdcall;



  TSunB = packed record
    s_b1, s_b2, s_b3, s_b4: byte;
  end;

  TSunW = packed record
    s_w1, s_w2: word;
  end;

  PIPAddr = ^TIPAddr;
  TIPAddr = record
    case integer of
      0: (S_un_b: TSunB);
      1: (S_un_w: TSunW);
      2: (S_addr: longword);
  end;

 IPAddr = TIPAddr;

 USHORT = Word;

 IP_OPTION_INFORMATION = Pointer;

 TICMPEchoReply = packed record
  Address: IPAddr;
  Status: ULONG;
  RoundTripTime: ULONG;
  DataSize: USHORT;
  Reserved: USHORT;
  Data: Pointer;
  Options: IP_OPTION_INFORMATION;
 end;

 ICMP_ECHO_REPLY = TICMPEchoReply;


function IcmpCreateFile : THandle; stdcall; external ICMP_LIB;
function IcmpCloseHandle (icmpHandle : THandle) : boolean;
            stdcall; external ICMP_LIB;

function IcmpSendEcho
   (IcmpHandle : THandle; DestinationAddress : IPAddr;
    RequestData : Pointer; RequestSize : Smallint;
    RequestOptions : pointer;
    ReplyBuffer : Pointer;
    ReplySize : DWORD;
    Timeout : DWORD) : DWORD; stdcall; external ICMP_LIB;

function IcmpSendEcho2
   (IcmpHandle : THandle;
    hEvent: THandle;
    ApcRoutine: PIO_APC_ROUTINE;
    ApcContext: Pointer;

    DestinationAddress: IPAddr;

    RequestData: Pointer;
    RequestSize: Smallint;
    RequestOptions: Pointer;

    ReplyBuffer : Pointer;
    ReplySize : DWORD;
    Timeout : DWORD) : DWORD; stdcall; external ICMP_LIB;

function IcmpParseReplies ( pbuff: Pointer; replySize: DWORD ): DWORD; stdcall; external ICMP_LIB;

function TranslateStringToTInAddr(AHost: string; var AInAddr): Boolean;
function  PerformPing(InetAddress : string) : boolean;

implementation

uses
  WinSock, ModuleMgr;

function Fetch(var AInput: string;
                      const ADelim: string = ' ';
                      const ADelete: Boolean = true): string;
var
  iPos: Integer;
begin
  if ADelim = #0 then begin
    // AnsiPos does not work with #0
    iPos := Pos(ADelim, AInput);
  end else begin
    iPos := Pos(ADelim, AInput);
  end;
  if iPos = 0 then begin
    Result := AInput;
    if ADelete then begin
      AInput := '';
    end;
  end else begin
    result := Copy(AInput, 1, iPos - 1);
    if ADelete then begin
      Delete(AInput, 1, iPos + Length(ADelim) - 1);
    end;
  end;
end;

function TranslateStringToTInAddr(AHost: string; var AInAddr): Boolean;
var
  phe: PHostEnt;
  pac: PAnsiChar;

begin
  result := FALSE;

  FillChar(AInAddr, SizeOf(AInAddr), #0);

  try
    phe := GetHostByName(PAnsiChar( AnsiString(AHost) ));
    if Assigned(phe) then
    begin
      pac := phe^.h_addr_list^;
      if Assigned(pac) then
      begin
        with TIPAddr(AInAddr).S_un_b do begin
          s_b1 := Byte( pac[0] );
          s_b2 := Byte( pac[1] );
          s_b3 := Byte( pac[2] );
          s_b4 := Byte( pac[3] );
          result := TRUE;
        end;
      end
      else
      begin
       ODS ('[~T].~C0C #WARN: Error getting IP from HostName ~C0F' + AHost + '~C07');
      end;
    end
    else
    begin
      ODS ('[~T].~C0C #WARN: Error getting HostName ~C0F' + AHost + '~C07');
    end;

  except
   on E: Exception do
     OnExceptLog ('GetHostByName', E);
  end;

end;


var
   h_icmp: THandle;
   GInitData: TWSAData;

function PerformPing(InetAddress : string) : Boolean;
var
 InAddr : IPAddr;
 DW : DWORD;
 rep : array[1..128] of byte;
begin
  result := false;
  if h_icmp = INVALID_HANDLE_VALUE then Exit;
  TranslateStringToTInAddr(InetAddress, InAddr);
  DW := IcmpSendEcho (h_icmp, InAddr, nil, 0, nil, @rep, 128, 2500);
  Result := (DW <> 0);
end;

{ TMiscModuleDesc }
function OnModuleRqs (md: TModuleDescriptor; rqs, flags: DWORD): Boolean;
var
   i: Integer;
begin
 result := FALSE;
 case rqs of
      MRQ_INITIALIZE:  // ==================================================================================================== //
          begin
           result := (MST_INITIALIZED <> md.Status);
           if not result then exit;
           ODS('[~T]. #DBG(ping.pas): trying WSAStartup...');
           WSAStartup($101, GInitData);
           exit;
          end;
      MRQ_FINALIZE: // ==================================================================================================== //
          begin
           result := (MST_FINALIZED <> md.Status);
           if not result then exit;
           try
            WSACleanup;
           except
            on E: Exception do
               OnExceptLog('WSACleanup', E);
           end;
          end;
 end; // case
end; // OnModuleRqs

var
  lMDesc: TModuleDescriptor = nil;

initialization
 lMDesc := RegModule ('Ping', 'Misc', OnModuleRqs);
 InitializeModule ('Ping');
finalization
 FinalizeModule('Ping');
 lMDesc := nil;
end.
