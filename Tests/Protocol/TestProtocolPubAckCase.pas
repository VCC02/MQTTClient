{
    Copyright (C) 2024 VCC
    creation date: 23 Feb 2024
    initial release date: 25 Feb 2024

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


unit TestProtocolPubAckCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolPubAckCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestServerToClientBufferContent_BeforePubAck_OnePacket_QoS_0;
    procedure TestServerToClientBufferContent_BeforePubAck_OnePacket_QoS_1;
    procedure TestServerToClientBufferContent_BeforePubAck_TwoPackets_QoS_0;
    procedure TestServerToClientBufferContent_BeforePubAck_TwoPackets_QoS_1;

    procedure TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_0;
    procedure TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_1;
    procedure TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_1_ReceiveMaximumReset;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl, MQTTPubAckCtrl,
  Expectations, ExpectationsDynArrays;


var
  ReceivedPublishFields: TMQTTPublishFields;
  ReceivedPublishProperties: TMQTTPublishProperties;
  ReceivedPubAckFields: TMQTTPubAckFields;
  ReceivedPubAckProperties: TMQTTPubAckProperties;
  DestPacket: TMQTTControlPacket;

  FieldsToSend_ReasonCode: array of Integer;
  FieldsToSend_PacketIdentifier: array of Integer;

  ReceivedCount: Byte;  //Counts how many times a PUBLISH handler is called. For QoS=0 and QoS=1, it should be on every receive. For QoS=2, it should be 1.
  ResponseCount: Byte;  //Counts how many times a PUBACK handler is called.

  FoundError: Word;
  ErrorOnPacketType: Byte;
  FakePacketIDs: array of Word;

function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
begin
  Result := True;
  //MQTT_InitWillProperties(TempWillProperties);
end;


function HandleOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord; var ATempPublishFields: TMQTTPublishFields; var ATempPublishProperties: TMQTTPublishProperties; ACallbackID: Word): Boolean;
begin
  Inc(ReceivedCount);
  Result := True;
end;


procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var ATempPublishFields: TMQTTPublishFields; var ATempPublishProperties: TMQTTPublishProperties);
begin
  Inc(ReceivedCount);
end;


procedure HandleOnBeforeSending_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties);
begin
  Inc(ResponseCount);

  SetLength(FieldsToSend_ReasonCode, Length(FieldsToSend_ReasonCode) + 1);
  FieldsToSend_ReasonCode[Length(FieldsToSend_ReasonCode) - 1] := ATempPubAckFields.ReasonCode;

  SetLength(FieldsToSend_PacketIdentifier, Length(FieldsToSend_PacketIdentifier) + 1);
  FieldsToSend_PacketIdentifier[Length(FieldsToSend_PacketIdentifier) - 1] := ATempPubAckFields.PacketIdentifier;

  //This handler can be used to override what is being sent to server as a reply to PUBLISH
end;


procedure HandleOnAfterReceiving_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties);
begin
  Inc(ReceivedCount);

  //ReceivedPubAckFields
  if Length(FakePacketIDs) > 0 then
    ATempPubAckFields.PacketIdentifier := FakePacketIDs[Length(FakePacketIDs) - 1];
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure HandleOnSend_MQTT_Packet(ClientInstance: DWord; APacketType: Byte);
begin

end;


procedure TTestProtocolPubAckCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnBeforeMQTT_CONNECT^ := @HandleOnBeforeMQTT_CONNECT;
    OnBeforeSendingMQTT_PUBLISH^ := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK^ := @HandleOnBeforeSending_MQTT_PUBACK;
    OnAfterReceivingMQTT_PUBACK^ := @HandleOnAfterReceiving_MQTT_PUBACK;
    OnMQTTError^ := @HandleOnMQTTError;
    OnSendMQTT_Packet^ := @HandleOnSend_MQTT_Packet;
  {$ELSE}
    OnBeforeMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
    OnAfterReceivingMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
    OnBeforeSendingMQTT_PUBLISH := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSending_MQTT_PUBACK;
    OnAfterReceivingMQTT_PUBACK := @HandleOnAfterReceiving_MQTT_PUBACK;
    OnMQTTError := @HandleOnMQTTError;
    OnSendMQTT_Packet := @HandleOnSend_MQTT_Packet;
  {$ENDIF}

  ReceivedCount := 0;
  ResponseCount := 0;

  ReceivedPublishFields.PacketIdentifier := 456;
  InitDynArrayToEmpty(ReceivedPublishFields.ApplicationMessage);
  StringToDynArrayOfByte('SomeAppMsg', ReceivedPublishFields.ApplicationMessage);
  ReceivedPublishFields.EnabledProperties := 0;
  ReceivedPublishFields.PublishCtrlFlags := 0;
  InitDynArrayToEmpty(ReceivedPublishFields.TopicName);
  StringToDynArrayOfByte('SomeTopic', ReceivedPublishFields.TopicName);

  ReceivedPubAckFields.EnabledProperties := 0;
  InitDynArrayToEmpty(ReceivedPubAckFields.SrcPayload);
  MQTT_InitCommonProperties(ReceivedPubAckProperties);

  SetLength(FieldsToSend_ReasonCode, 0);
  SetLength(FieldsToSend_PacketIdentifier, 0);

  MQTT_InitPublishProperties(ReceivedPublishProperties);
  MQTT_InitControlPacket(DestPacket);

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
  SetLength(FakePacketIDs, 0);
end;


procedure TTestProtocolPubAckCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreePublishProperties(ReceivedPublishProperties);
  FreeDynArray(ReceivedPublishFields.ApplicationMessage);
  FreeDynArray(ReceivedPublishFields.TopicName);

  FreeDynArray(ReceivedPubAckFields.SrcPayload);
  MQTT_FreeCommonProperties(ReceivedPubAckProperties);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolPubAckCase.TestServerToClientBufferContent_BeforePubAck_OnePacket_QoS_0;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 0; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(1);
  Expect(ResponseCount).ToBe(0);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestServerToClientBufferContent_BeforePubAck_OnePacket_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 1 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(1);
  Expect(ResponseCount).ToBe(1);
  Expect(FieldsToSend_ReasonCode[0]).ToBe(CMQTT_Reason_Success);
  Expect(FieldsToSend_PacketIdentifier[0]).ToBe(456);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestServerToClientBufferContent_BeforePubAck_TwoPackets_QoS_0;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 0; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);
  Expect(ResponseCount).ToBe(0);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestServerToClientBufferContent_BeforePubAck_TwoPackets_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 1 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)

  ReceivedPublishFields.PacketIdentifier := 789;
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  PutReceivedBufferToMQTTLib(0, TempBuffer);

  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);

  ReceivedPublishFields.PacketIdentifier := 987;
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  PutReceivedBufferToMQTTLib(0, TempBuffer);

  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);
  Expect(ResponseCount).ToBe(2);
  Expect(FieldsToSend_ReasonCode[0]).ToBe(CMQTT_Reason_Success);
  Expect(FieldsToSend_PacketIdentifier[0]).ToBe(789);
  Expect(FieldsToSend_ReasonCode[1]).ToBe(CMQTT_Reason_Success);
  Expect(FieldsToSend_PacketIdentifier[1]).ToBe(987);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_0;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  Expect(MQTT_CONNECT(0, 0)).ToBe(True);
  Expect(MQTT_PUBLISH(0, 0, 0)).ToBe(True);  //this calls DecrementSendQuota

  SetLength(FakePacketIDs, Length(FakePacketIDs) + 1);
  FakePacketIDs[Length(FakePacketIDs) - 1] := CreateClientToServerPacketIdentifier(0);
  ReceivedPubAckFields.PacketIdentifier := FakePacketIDs[Length(FakePacketIDs) - 1];
  FillIn_PubAck(ReceivedPubAckFields, ReceivedPubAckProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  ReceivedCount := 0; //reset because of PUBLISH
  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_ReceiveMaximumReset, 'Received too many unexpected packets');
  Expect(ReceivedCount).ToBe(0, 'No PUBACK is expected on QoS 0.');
  Expect(ResponseCount).ToBe(0);

  Expect(FoundError).ToBe(CMQTT_ReceiveMaximumReset, 'The server should not respond to Publish at QoS 0.');  //Not the best error in this case, but it's an error after all.
  Expect(ErrorOnPacketType).ToBe(CMQTT_PUBACK);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  Expect(MQTT_CONNECT(0, 0)).ToBe(True);
  Expect(MQTT_PUBLISH(0, 0, 1)).ToBe(True);  //this calls DecrementSendQuota

  SetLength(FakePacketIDs, Length(FakePacketIDs) + 1);
  FakePacketIDs[Length(FakePacketIDs) - 1] := CreateClientToServerPacketIdentifier(0);
  ReceivedPubAckFields.PacketIdentifier := FakePacketIDs[Length(FakePacketIDs) - 1];
  FillIn_PubAck(ReceivedPubAckFields, ReceivedPubAckProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  ReceivedCount := 0; //reset because of PUBLISH
  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(1, 'Received PUBACK');
  Expect(ResponseCount).ToBe(0);

  Expect(FoundError).ToBe(CMQTT_Success);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_AfterPubAck_OnePacket_QoS_1_ReceiveMaximumReset;
var
  TempBuffer: TDynArrayOfByte;
  i: Integer;
begin
  InitDynArrayToEmpty(TempBuffer);

  Expect(MQTT_CONNECT(0, 0)).ToBe(True);
  Expect(MQTT_PUBLISH(0, 0, 1)).ToBe(True);  //this calls DecrementSendQuota

  ReceivedCount := 0; //reset because of PUBLISH
  for i := 1 to CMQTT_DefaultReceiveMaximum + 1 do
  begin
    SetLength(FakePacketIDs, Length(FakePacketIDs) + 1);
    FakePacketIDs[Length(FakePacketIDs) - 1] := CreateClientToServerPacketIdentifier(0);
    ReceivedPubAckFields.PacketIdentifier := FakePacketIDs[Length(FakePacketIDs) - 1];

    FillIn_PubAck(ReceivedPubAckFields, ReceivedPubAckProperties, DestPacket);
    EncodeControlPacketToBuffer(DestPacket, TempBuffer);

    PutReceivedBufferToMQTTLib(0, TempBuffer);
    FreeDynArray(TempBuffer);
    MQTT_FreeControlPacket(DestPacket);
  end;

  Expect(MQTT_Process(0)).ToBe(CMQTT_ReceiveMaximumReset, 'Received too many unexpected packets');
  Expect(ReceivedCount).ToBe(1, 'Received PUBACK');
  Expect(ResponseCount).ToBe(0);

  Expect(FoundError).ToBe(CMQTT_ReceiveMaximumReset);
  Expect(ErrorOnPacketType).ToBe(CMQTT_PUBACK);

  FreeDynArray(TempBuffer);
end;


initialization

  RegisterTest(TTestProtocolPubAckCase);

end.

