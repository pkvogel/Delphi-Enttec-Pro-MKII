unit UDMXUSBProThread;

interface

uses
  Classes, Windows, SysUtils;

type
  TDMXUSBProThread = class(TThread)
  private
  protected
    procedure Execute; override;
    procedure Receive ();
  public
    _info: String;
    _Comport: String;
    constructor Create(ThreadPriority: TThreadPriority; _Comport: String );
  end;

implementation

uses
  UComPort, UDMXUSBPRO;

procedure TDMXUSBProThread.Receive ();
var
  _data: TByteArray;
  _test: Boolean;
  _s: string;
  counter, count: Integer;
begin
  while ( not Terminated ) do begin
    _test := false;
    _s := '';

    // send datapackages
    if ( DMXUSBPro_Param_1 = 1 ) and ( Send_DMX1 ) then
      Send_DMXUSBPRO ( 1, DMXUSBPRO_Level1 );
    if ( DMXUSBPro_Param_2 = 1 ) and ( Send_DMX2 ) then
      Send_DMXUSBPRO ( 2, DMXUSBPRO_Level2 );

    // send receive DMX requests
    if Receive_DMX1 then
      Receive_DMX_Request ( 1 );
    if Receive_DMX2 then
      Receive_DMX_Request ( 2 );

    // ** analyze received data **
    _data := ReadText2 ();
//{debug}    _info := ReadText ();

    if _data <> nil then begin
      if _data [ 0 ] = START_BYTE then begin
        case _data [ 1 ] of

          WIDGET_SERIAL_NUMBER: begin
            _info := 'SN: ' + inttohex ( _data [ 7 ], 2 ) + inttohex ( _data [ 6 ], 2 ) + inttohex ( _data [ 5 ], 2 ) + inttohex ( _data [ 4 ], 2 );
          end;

          PORT_WIDGET_PARAM_1: begin
            _info := '----Port 1----';
            sleep ( 50 );
            _info := 'V' + inttostr ( _data [ 5 ] ) + '.' + inttostr ( _data [ 4 ] );
            sleep ( 50 );
            _info := 'breaktime: ' + inttostr ( trunc ( _data [ 6 ] * 10.67 ) ) + ' 탎';
            sleep ( 50 );
            _info := 'MaBtime: ' + inttostr ( trunc ( _data [ 7 ] * 10.67 ) ) + ' 탎';
            sleep ( 50 );
            _info := 'refreshrate: ' + inttostr ( _data [ 8 ] ) + ' pkg/s';
          end;

          PORT_WIDGET_PARAM_2: begin
            _info := '----Port 2----';
            sleep ( 50 );
            _info := 'V' + inttostr ( _data [ 5 ] ) + '.' + inttostr ( _data [ 4 ] );
            sleep ( 50 );
            _info := 'breaktime: ' + inttostr ( trunc ( _data [ 6 ] * 10.67 ) ) + ' 탎';
            sleep ( 50 );
            _info := 'MaBtime: ' + inttostr ( trunc ( _data [ 7 ] * 10.67 ) ) + ' 탎';
            sleep ( 50 );
            _info := 'refreshrate: ' + inttostr ( _data [ 8 ] ) + ' pkg/s';
          end;

          RECEIVED_DMX_PACKET_1: begin
            // is valid?
            case _data [ 4 ] of
              0: begin
                // $00: datapackage is valid
                _test := true;
              end;
              1: begin
                // $01: overrun
                _info := 'DMX-IN[1] error: overrun';
              end;
              16: begin
                // $10: queue overflow
                _info := 'DMX-IN[1] error: queue overflow';
              end;
              17: begin
                // $11: both errors
                _info := 'DMX-IN[1] error: overrun and queue overflow';
              end;
            end;

            // copy the data: first Byte is a start code
            if _test then begin
              for counter := 0 to 511 do
                DMXUSBPro_Level1_In [ counter ] := _data [ counter + 6 ];

              for counter := 0 to 10 do
                _s := _s + formatfloat ( '000', _data [ counter + 6 ] );
              _info := _s;
            end;
          end; // RECEIVED_DMX_PACKET_1

          RECEIVED_DMX_PACKET_2: begin
            // is valid?
            case _data [ 4 ] of
              0: begin
                // $00: datapackage is valid
                _test := true;
              end;
              1: begin
                // $01: overrun
                _info := 'DMX-IN[2] error: overrun';
              end;
              16: begin
                // $10: queue overflow
                _info := 'DMX-IN[2] error: queue overflow';
              end;
              17: begin
                // $11: both errors
                _info := 'DMX-IN[2] error: overrun and queue overflow';
              end;
            end;

            // copy the data: first Byte is a start code
            if _test then begin
              for counter := 0 to 511 do
                DMXUSBPro_Level2_In [ counter ] := _data [ counter + 6 ];

              for counter := 0 to 10 do
                _s := _s + formatfloat ( '000', _data [ counter + 6 ] );
              _info := _s;
            end;
          end; // RECEIVED_DMX_PACKET_2

          QUERY_HARDWARE_VERSION: begin
            _info := 'hardware-version: ' + inttostr ( _data [ 4 ] );
          end; // QUERY_HARDWARE_VERSION

          GET_PORT_ASSIGNMENT: begin
            _info := 'port assignment: param1: ' + inttostr ( _data [ 4 ] ) + ' param2:' + inttostr ( _data [ 5 ] );
            DMXUSBPro_Param_1 := _data [ 4 ];
            DMXUSBPro_Param_2 := _data [ 5 ];
          end; // GET_PORT_ASSIGNMENT

          RECEIVED_MIDI: begin
            count := _data [ 2 ] * 256 + _data [ 3 ];
            Setlength ( MIDIIN, count );
            for counter := 0 to count - 1 do
              MIDIIN [ counter ] := _data [ counter + 4 ];

            MIDIIN_data := true;

            for counter := 0 to count - 1 do
              _s := _s + formatfloat ( '000', _data [ counter + 4 ] );
            _info := _s;
          end; // RECEIVED_MIDI

        end; // case
      end; // if
    end;

    _data := nil;

    sleep ( 20 );
  end;

  _data := nil;
end;

procedure TDMXUSBProThread.Execute;
begin
  try
    Receive;

    // close the comport
//    Destroy_DMXUSBPRO ();

    sleep ( 1 );
  except
  end;
end;

constructor TDMXUSBProThread.Create(ThreadPriority: TThreadPriority; _Comport: String );
begin
  inherited Create ( true );

  Priority := ThreadPriority;

  _Comport := _Comport;

  Create_DMXUSBPRO ( 1, _Comport );

  FreeOnTerminate := true;

  Resume;
end;

end.
