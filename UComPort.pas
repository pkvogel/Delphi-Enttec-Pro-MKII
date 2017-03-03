unit UComPort;

interface

uses
  Winapi.Windows, System.SysUtils;

type
  TByteArray = array of Byte;

var
  ComFile: THandle;
  ComPort_Connected: Boolean = false;

// ** export **
  function OpenCOMPort ( _comport: String ): Boolean;
  function SetupCOMPort: Boolean;
  function SendText ( s: ansistring ): DWORD;
  function ReadText: string;
  function ReadText2: TByteArray;
  procedure CloseCOMPort;

implementation

// *****************************************************************************
// desc.: open a connection to a com-port
// *****************************************************************************
function OpenCOMPort ( _comport: String ): Boolean;
var
  DeviceName: array [ 0..80 ] of Char;
begin
   { First step is to open the communications device for read/write.
     This is achieved using the Win32 'CreateFile' function.
     If it fails, the function returns false.

     Wir versuchen, COM1 zu öffnen.
     Sollte dies fehlschlagen, gibt die Funktion false zurück.
   }
  StrPCopy ( DeviceName, _comport );

  ComFile := CreateFile ( DeviceName,
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0 );

  if ComFile = INVALID_HANDLE_VALUE then
    Result := False
  else
    Result := True;

  Comport_Connected := Result;
end; // <- OpenComPort

// *****************************************************************************
// desc.: setup the comport
// *****************************************************************************
function SetupCOMPort: Boolean;
const
  RxBufferSize = 1024;
  TxBufferSize = 1024;
var
  DCB: TDCB;
  Config: string;
  CommTimeouts: TCommTimeouts;
begin
   { We assume that the setup to configure the setup works fine.
     Otherwise the function returns false.

     wir gehen davon aus das das Einstellen des COM Ports funktioniert.
     sollte dies fehlschlagen wird der Rückgabewert auf "FALSE" gesetzt.
   }

  Result := True;

  if not SetupComm ( ComFile, RxBufferSize, TxBufferSize ) then
    Result := False;

  if not GetCommState ( ComFile, DCB ) then
    Result := False;

  // define the baudrate, parity,...
  // hier die Baudrate, Parität usw. konfigurieren

  Config := 'baud=115200 parity=n data=8 stop=1';

  if not BuildCommDCB ( @Config [ 1 ], DCB ) then
    Result := False;

  if not SetCommState ( ComFile, DCB ) then
    Result := False;

  with CommTimeouts do begin
    ReadIntervalTimeout         := 0;
    ReadTotalTimeoutMultiplier  := 0;
    ReadTotalTimeoutConstant    := 10;
    WriteTotalTimeoutMultiplier := 0;
    WriteTotalTimeoutConstant   := 10;
  end;

  if not SetCommTimeouts ( ComFile, CommTimeouts ) then
    Result := False;

  Comport_Connected := result;
end; // <- SetupComPort

// *****************************************************************************
// desc.: send a string to comport
// *****************************************************************************
function SendText ( s: ansistring ): DWORD;
var
  BytesWritten: DWORD;
begin
   {
     Add a word-wrap (#13 + #10) to the string

     An den übergebenen String einen Zeilenumbruch (#13 + #10) hängen
   }
  s := s {+ #13 + #10};
  WriteFile ( ComFile, s [ 1 ], {Byte}Length ( s ), BytesWritten, nil );

  result := BytesWritten;
end; // <- SendText

// *****************************************************************************
// desc.: read a incomming text from comport
// *****************************************************************************
function ReadText: string;
var
  d: array [ 1..519 ] of Byte;
//  d: array [ 1..40960 ] of AnsiChar;
  s: string;
  BytesRead: Cardinal;
  i: Integer;
begin
  Result := '';
  if not ReadFile ( ComFile, d, SizeOf ( d ), BytesRead, nil ) then begin
    // Raise an exception
  end;
  s := '';
  for i := 1 to BytesRead do
    s := s + ' ' + inttostr ( d [ i ] );
  Result := s;
end; // <- ReadText

function ReadText2: TByteArray;
var
  d: array [ 1..519 ] of Byte;
//  d: array [ 1..40960 ] of AnsiChar;
  BytesRead: Cardinal;
  i: Integer;
begin
  BytesRead := 0;
  if not ReadFile ( ComFile, d, SizeOf ( d ), BytesRead, nil ) then begin
    // Raise an exception
  end;
  setlength ( result, BytesRead );
  for i := 1 to BytesRead do
    result [ i - 1 ] := d [ i ];
end; // <- ReadText2

// *****************************************************************************
// desc.: close the connection to the comport
// *****************************************************************************
procedure CloseCOMPort;
begin
  // finally close the COM Port!
  // nicht vergessen den COM Port wieder zu schliessen!
  CloseHandle ( ComFile );

  comport_connected := false;
end; // <- CloseComport

end.
