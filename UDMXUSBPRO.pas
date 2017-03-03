unit UDMXUSBPRO;

interface

uses
  sysutils, UComPort;

type
  TDMXLevel = array [ 0..511 ] of byte;
  TMIDI = array of Byte;

const
  // API2-Key: XXXXXXXXXX
  API2_KEY_1 = 0; //
  API2_KEY_2 = 0; //
  API2_KEY_3 = 0; //
  API2_KEY_4 = 0; //

  START_BYTE = 126; // $7E
  END_BYTE = 231;   // $E7

  PORT_WIDGET_PARAM_1 = 3;
  PORT_WIDGET_PARAM_2 = 192;
  SET_PORT_WIDGET_PARAM_1 = 4;
  SET_PORT_WIDGET_PARAM_2 = 133;
  RECEIVED_DMX_PACKET_1 = 5;
  RECEIVED_DMX_PACKET_2 = 135;
  SEND_DMX_PACKET_1 = 6;
  SEND_DMX_PACKET_2 = 137;
  SEND_RDM_PACKET_1 = 7;
  SEND_RDM_PACKET_2 = 163;
  RECEIVE_DMX_ON_CHANGE_1 = 8;
  RECEIVE_DMX_ON_CHANGE_2 = 177;
  RECEIVE_DMX_CHANGE_OF_STATE_PACKET_1 = 9;
  RECEIVE_DMX_CHANGE_OF_STATE_PACKET_2 = 228;
  WIDGET_SERIAL_NUMBER = 10;
  SEND_RDM_DISCOVERY_REQUEST_1 = 11;
  SEND_RDM_DISCOVERY_REQUEST_2 = 134;
  RDM_CONTROLLER_RECEIVE_TIMEOUT_1 = 12;
  RDM_CONTROLLER_RECEIVE_TIMEOUT_2 = 229;
  SET_API_KEY_REQUEST = 13;
  QUERY_HARDWARE_VERSION = 14;
  GET_PORT_ASSIGNMENT = 193;
  SET_PORT_ASSIGNMENT = 236;
  RECEIVED_MIDI = 230;
  SEND_MIDI = 195;
  SHOW_QUERY = 142;
  SHOW_ERASE = 225;
  SHOW_WRITE = 225;
  SHOW_READ = 197;
  START_SHOW = 225;
  STOP_SHOW = 225;

var
  DMXUSBPRO_Ready: Boolean = false;
  DMXUSBPRO_Tag: Integer = -1;
  DMXUSBPRO_Level1: TDMXLEVEL;
  DMXUSBPro_Level1_In: TDMXLEVEL;
  DMXUSBPRO_Level2: TDMXLEVEL;
  DMXUSBPro_Level2_In: TDMXLEVEL;

  MIDIIN: TMidi;
  MIDIIN_data: Boolean = false;

  DMXUSBPro_Param_1: Integer = 1;
  DMXUSBPro_Param_2: Integer = 1;

  DMXUSB_message: String = '';

  Send_DMX1: Boolean = false;
  Send_DMX2: Boolean = false;
  Receive_DMX1: Boolean = false;
  Receive_DMX2: Boolean = false;

  // --
  function Create_DMXUSBPRO ( _tag: Integer = -1; PortNumber: String = '' ): Boolean;
  function Destroy_DMXUSBPRO: Boolean;
  function Send_DMXUSBPRO ( _port: Integer; var _DMX: TDMXLevel ): Boolean;

  procedure SendMsg ( Msg: string );

  procedure Send_Serial_Request_Packet;
  procedure Send_Hardware_Request;
  procedure Send_Config_Request_Packet ( _port: Integer );
  procedure Set_DMXUSBPro_Port_Assignment ( _param1, _param2: Integer );
  procedure Get_DMXUSBPro_Port_Assignment;
  procedure Receive_DMX_Request ( _port: Integer );
  procedure Send_MidiData ( _mididata: TMIDI );

  function ReceiveData_DMXUSBPRO (): Boolean;

implementation

//******************************************************************************
//** DESC: init the MKII -> DMX2-out, MIDI, etc
//******************************************************************************
procedure Set_DMXUSBPro_Port_Assignment ( _param1, _param2: Integer );
var
  msg: String;
begin
  // key: 6A722A4F
  // 79;//$4F;
  // 42;//$2A;
  // 114;//$72;
  // 106;//$6A;
  // send the widged-key
  msg := ansichar ( SET_API_KEY_REQUEST ) + ansichar ( 4 ) + ansichar ( 0 ) + ansichar ( 79 ) + ansichar ( 42 ) + ansichar ( 114 ) + ansichar ( 106 );
  SendMsg ( msg );
  sleep ( 100 );
  msg := ansichar ( SET_PORT_ASSIGNMENT ) + ansichar ( 2 ) + ansichar ( 0 ) + ansichar ( _param1 ) + ansichar ( _param2 );
  SendMsg ( msg );

  DMXUSBPro_Param_1 := _param1;
  DMXUSBPro_Param_2 := _param2;
end; // <- Set_Port_Assignment

//******************************************************************************
//** DESC: create the DMXUSBPRO
//******************************************************************************
function Create_DMXUSBPRO ( _tag: Integer = -1; PortNumber: String = '' ): Boolean;
begin
  try
    if OpenComPort ( PortNumber ) then begin
      SetupComport ();

      DMXUSBPRO_Ready := true;
      DMXUSBPRO_Tag := _tag;

      DMXUSB_message := 'DMXUSBPRO - Comport initialzed [' + PortNumber + ']';
    end else begin
      result := false;
      DMXUSB_message := 'error: cannot initialize Comport';
      exit;
    end;

    result := true;
  except
    result := false;
    DMXUSB_message := 'fatal error: cannot init DMXUSBPRO';
    exit;
  end;
end; // <- Init_DMXUSBPRO

//******************************************************************************
//** DESC: destroy the DMXUSBPRO
//******************************************************************************
function Destroy_DMXUSBPRO (): Boolean;
begin
  try
    CloseComPort ();

    DMXUSBPRO_Ready := false;
    DMXUSBPRO_Tag := -1;

    result := true;
    DMXUSB_message := 'DMXUSBPRO - Comport closed';
  except
    result := false;
    DMXUSB_message := 'error: cannot close USBDMXPRO Comport';
    exit;
  end;
end; // <- Destroy_DMXUSBPRO

//******************************************************************************
//**
//******************************************************************************
function hexStr ( binStr: string ): string;
// returns string of hex digits for each character in binStr
var
	i: Integer;
begin
  for i := 1 to Length ( binStr ) do
    result := result + InttoHex ( ord ( binStr [ i ] ), 2 ) + ' ';
  hexStr := result;
end;

//******************************************************************************
//** create a stream with start and stop byte
//******************************************************************************
procedure SendMsg ( Msg: string );
begin
  if DMXUSBPRO_ready then begin
    msg := ansichar ( 126 ) + msg + ansichar ( 231 );
    try
      SendText ( msg );
//      input_console ( hexStr ( msg ) );
    except
      DMXUSB_message := 'error: sendmsg(' + Msg + ')';
      exit;
    end;
  end;
end; // <- SendMsg

//******************************************************************************
//** send DMX data to Enttec USB DMX Pro widget
//******************************************************************************
procedure Send_MidiData ( _mididata: TMIDI );
var
	_data, msg: String;
  counter, count: Integer;
begin
  count := Length ( _mididata );
  if count > 64 then
    count := 64;

  _data := '';
  for counter := 0 to count - 1 do
    _data := ansichar ( _mididata [ counter ] );

  msg := ansichar ( SEND_MIDI ) + ansichar ( 0 ) + ansichar ( count ) + _data;
  SendMsg ( msg );
end;

//******************************************************************************
//** get the DMX levels from the widget
//******************************************************************************
procedure Receive_DMX_Request ( _port: Integer );
var
	msg: String;
  _level: Integer;
begin
  case _port of
    1: _level := RECEIVE_DMX_ON_CHANGE_1;
    2: _level := RECEIVE_DMX_ON_CHANGE_2;
  end;
  msg := ansichar ( _level ) + ansichar ( 1 ) + ansichar ( 0 ) + ansichar ( 0 );
  SendMsg ( msg );
end;

//******************************************************************************
//** send DMX data to Enttec USB DMX Pro widget
//******************************************************************************
procedure Send_Serial_Request_Packet;
var
	msg: String;
begin
  // sending DMX msgnumber 10
  msg := ansichar ( WIDGET_SERIAL_NUMBER ) + ansichar ( 0 ) + ansichar ( 0 );
  SendMsg ( msg );
end;

//******************************************************************************
//** get the hardware version
//******************************************************************************
procedure Send_Hardware_Request;
var
	msg: String;
begin
  msg := ansichar ( QUERY_HARDWARE_VERSION ) + ansichar ( 0 ) + ansichar ( 0 );
  SendMsg ( msg );
end; // <- Send_Hardware_Request

//******************************************************************************
//** get the port assignment
//******************************************************************************
procedure Get_DMXUSBPro_Port_Assignment;
var
	msg: String;
begin
  msg := ansichar ( GET_PORT_ASSIGNMENT ) + ansichar ( 0 ) + ansichar ( 0 );
  SendMsg ( msg );
end; // <- Get_DMXUSBPro_Port_Assignment

//******************************************************************************
//** send DMX data to Enttec USB DMX Pro widget
//******************************************************************************
procedure Send_Config_Request_Packet ( _port: Integer );
var
	msg: String;
  _label: Integer;
begin
  case _port of
    1: _label := PORT_WIDGET_PARAM_1;
    2: _label := PORT_WIDGET_PARAM_2;
  end;

  // sending DMX msgnumber 3
  msg := ansichar ( _label ) + ansichar ( 0 ) + ansichar ( 0 );// + Chr ( 0 );
  SendMsg ( msg );
end;

//******************************************************************************
//** DESC: send the data to the USBDMXPRO-Interface
//******************************************************************************
function Send_DMXUSBPRO ( _port: Integer; var _DMX: TDMXLevel ): Boolean;
var
	msg, levels, startcode: string;
	_label, dataLen, dataLenLSB, dataLenMSB, i: Integer;
begin
  try
    case _port of
      1: _label := SEND_DMX_PACKET_1;
      2: _label := SEND_DMX_PACKET_2;
    end;

    startcode := ansichar ( 0 );
    levels := '';

    for i := 0 To 511 do
      levels := levels + ansichar ( _DMX [ i ] );

    dataLenMSB := 2;
    dataLenLSB := 1;

    // sending DMX msgnumber 6 and dataLen bytes of data
    msg := ansichar ( _label ) + ansichar ( dataLenLSB ) + ansichar ( dataLenMSB ) + startcode + levels;

    SendMsg ( msg );

    result := true;
  except
    result := false;
    exit;
  end;
end; // <- Send_DMXUSBPRO


function ReceiveData_DMXUSBPRO (): Boolean;
var
  counter: Integer;
  s: String;
begin
  try
    if Comport_Connected then
      s := ReadText ();

      if s <> '' then begin
//        Form1.Memo1.Clear;
//        Form1.Memo1.Lines.BeginUpdate;
//        Form1.Memo1.Lines.Add ( s );
//        Form1.Memo1.Lines.EndUpdate;
        DMXUSB_message := s;
      end;

  except
    result := false;
    DMXUSB_message := 'error: receivedata';
    exit;
  end;
end; // <- ReceiveData_DMXUSBPRO

end.
