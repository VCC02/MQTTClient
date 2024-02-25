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
    procedure TestClientToServerBufferContent_BeforePubAck_OnePacket_QoS_0;
    procedure TestClientToServerBufferContent_BeforePubAck_OnePacket_QoS_1;
    procedure TestClientToServerBufferContent_BeforePubAck_TwoPackets_QoS_0;
    procedure TestClientToServerBufferContent_BeforePubAck_TwoPackets_QoS_1;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl, //MQTTPubAckCtrl,
  Expectations, ExpectationsDynArrays;


var
  ReceivedPublishFields: TMQTTPublishFields;
  ReceivedPublishProperties: TMQTTPublishProperties;
  DestPacket: TMQTTControlPacket;

  FieldsToSend_ReasonCode: array of Integer;
  FieldsToSend_PacketIdentifier: array of Integer;

  ReceivedCount: Byte;  //Counts how many times a PUBLISH handler is called. For QoS=0 and QoS=1, it should be on every receive. For QoS=2, it should be 1.
  ResponseCount: Byte;  //Counts how many times a PUBACK handler is called.


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


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  // nothing here
end;


procedure TTestProtocolPubAckCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK^ := @HandleOnBeforeSending_MQTT_PUBACK;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSending_MQTT_PUBACK;
    OnMQTTError := @HandleOnMQTTError;
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

  SetLength(FieldsToSend_ReasonCode, 0);
  SetLength(FieldsToSend_PacketIdentifier, 0);

  MQTT_InitPublishProperties(ReceivedPublishProperties);
  MQTT_InitControlPacket(DestPacket);
end;


procedure TTestProtocolPubAckCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreePublishProperties(ReceivedPublishProperties);
  FreeDynArray(ReceivedPublishFields.ApplicationMessage);
  FreeDynArray(ReceivedPublishFields.TopicName);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_BeforePubAck_OnePacket_QoS_0;
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


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_BeforePubAck_OnePacket_QoS_1;
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


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_BeforePubAck_TwoPackets_QoS_0;
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


procedure TTestProtocolPubAckCase.TestClientToServerBufferContent_BeforePubAck_TwoPackets_QoS_1;
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


initialization

  RegisterTest(TTestProtocolPubAckCase);

end.

