{
    Copyright (C) 2024 VCC
    creation date: 01 Aug 2023
    initial release date: 26 Sep 2023

    author: VCC
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}



unit TestProtocolConnectCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolConnectCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_GenericPacketCount(ACount: Integer);
  published
    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_OnePacket;

    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets1;
    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets2;
    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets3;

    procedure TestClientToServerBufferContent_AfterConnect_WithCallback_DelOnePacket;
  end;

implementation


uses
  MQTTClient, MQTTUtils, DynArrays, MQTTConnectCtrl, Expectations
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


var
  //EncodedConnectBuffer: TDynArrayOfByte;
  DecodedConnectPacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;


function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
var
  TempWillProperties: TMQTTWillProperties;
  ClientId, UserName, Password: string[20];
  Id: Char;
begin
  Result := True;

  Id := Chr((ClientInstance and $FF) + 48);
  ClientId := 'MyClient' + Id;
  UserName := 'MyUserName' + Id;
  Password := 'MyPassword' + Id;

  StringToDynArrayOfByte(ClientId, AConnectFields.PayloadContent.ClientID);
  StringToDynArrayOfByte(UserName, AConnectFields.PayloadContent.UserName);
  StringToDynArrayOfByte(Password, AConnectFields.PayloadContent.Password);

  MQTT_InitWillProperties(TempWillProperties);
  TempWillProperties.WillDelayInterval := 30; //some value
  TempWillProperties.PayloadFormatIndicator := 1;  //0 = do not send.  1 = UTF-8 string
  TempWillProperties.MessageExpiryInterval := 3600;
  StringToDynArrayOfByte('SomeType', TempWillProperties.ContentType);
  StringToDynArrayOfByte('SomeTopicName', TempWillProperties.ResponseTopic);
  StringToDynArrayOfByte('MyCorrelationData', TempWillProperties.CorrelationData);
  AddStringToDynOfDynArrayOfByte('Key=Value', TempWillProperties.UserProperty);
  AddStringToDynOfDynArrayOfByte('NewKey=NewValue', TempWillProperties.UserProperty);

  FillIn_PayloadWillProperties(TempWillProperties, AConnectFields.PayloadContent.WillProperties);
  MQTT_FreeWillProperties(TempWillProperties);
  StringToDynArrayOfByte('WillTopic', AConnectFields.PayloadContent.WillTopic);

  //Please set the Will Flag in ConnectFlags below, then uncomment above code, if "Will" properties are required.
  AConnectFields.ConnectFlags := $FE;  //bits 7-0:  User Name, Password, Will Retain, Will QoS, Will Flag, Clean Start, Reserved

  AConnectProperties.SessionExpiryInterval := 3600; //[s]
  AConnectProperties.ReceiveMaximum := 1;
  AConnectProperties.MaximumPacketSize := 1000;
  AConnectProperties.TopicAliasMaximum := 100;
  AConnectProperties.RequestResponseInformation := 1;
  AConnectProperties.RequestProblemInformation := 1;
  AddStringToDynOfDynArrayOfByte('UserProp=Value', AConnectProperties.UserProperty);
  StringToDynArrayOfByte('MyAuthMethod', AConnectProperties.AuthenticationMethod);
  StringToDynArrayOfByte('MyAuthData', AConnectProperties.AuthenticationData);
end;


procedure TTestProtocolConnectCase.SetUp;
begin
  {$IFDEF UsingDynTFT}
    MM_Init;
  {$ENDIF}

  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnBeforeMQTT_CONNECT^ := @HandleOnBeforeMQTT_CONNECT;
  {$ELSE}
    OnBeforeMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
  {$ENDIF}

  //InitDynArrayToEmpty(EncodedConnectBuffer);
  MQTT_InitControlPacket(DecodedConnectPacket);
  DecodedBufferLen := 0;
end;


procedure TTestProtocolConnectCase.TearDown;
begin
  //FreeDynArray(EncodedConnectBuffer);
  MQTT_FreeControlPacket(DecodedConnectPacket);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_OnePacket;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_CONNECT(0, 0)).ToBe(True);  //add a CONNECT packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := MQTT_GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);

  Expect(Decode_ConnectToCtrlPacket(BufferPointer^, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets1;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_CONNECT(0, 0)).ToBe(True);    //add a CONNECT packet to ClientToServer buffer
  Expect(MQTT_CONNECT(0, 1)).ToBe(True);    //add a CONNECT packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := MQTT_GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);

  Expect(Decode_ConnectToCtrlPacket(BufferPointer^, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(DecodedBufferLen).{$IFDEF SingleOutputBuffer}ToBeLessThan{$ELSE}ToBe{$ENDIF}(BufferPointer^.Len);
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_GenericPacketCount(ACount: Integer);
var
  BufferPointer: PMQTTBuffer;
  Err, i: Word;
begin
  Expect(MQTT_GetClientToServerBuffer(0, Err)^.Len).ToBe(ACount);

  {$IFnDEF SingleOutputBuffer}
    for i := 0 to ACount - 1 do
    begin
      BufferPointer := MQTT_GetClientToServerBuffer(0, Err)^.Content^[i];
      Expect(Err).ToBe(CMQTT_Success);

      Expect(Decode_ConnectToCtrlPacket(BufferPointer^, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
      Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
      Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);

      MQTT_FreeControlPacket(DecodedConnectPacket);
      FreeDynArray(BufferPointer^);
    end;
  {$ENDIF}
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets2;
const
  CPacketCount = 2;
var
  i: Word;
begin
  for i := 0 to CPacketCount - 1 do
    Expect(MQTT_CONNECT(0, i)).ToBe(True);    //add a CONNECT packet to ClientToServer buffer

  TestClientToServerBufferContent_AfterConnect_WithCallback_GenericPacketCount(CPacketCount);
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_TwoPackets3;
const
  CPacketCount = 3;
var
  i: Word;
begin
  for i := 0 to CPacketCount - 1 do
    Expect(MQTT_CONNECT(0, i)).ToBe(True);    //add a CONNECT packet to ClientToServer buffer

  TestClientToServerBufferContent_AfterConnect_WithCallback_GenericPacketCount(CPacketCount);
end;


procedure TTestProtocolConnectCase.TestClientToServerBufferContent_AfterConnect_WithCallback_DelOnePacket;
const
  CPacketCount = 3;
var
  i: Word;
begin
  for i := 0 to CPacketCount - 1 do
    Expect(MQTT_CONNECT(0, i)).ToBe(True);    //add a CONNECT packet to ClientToServer buffer

  {$IFnDEF SingleOutputBuffer}
    Expect(MQTT_RemovePacketFromClientToServerBuffer(0)).ToBe(True);
    TestClientToServerBufferContent_AfterConnect_WithCallback_GenericPacketCount(CPacketCount - 1);
  {$ENDIF}
end;


initialization

  RegisterTest(TTestProtocolConnectCase);
end.

