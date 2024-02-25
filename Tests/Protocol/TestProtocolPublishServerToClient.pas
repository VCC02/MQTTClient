{
    Copyright (C) 2023 VCC
    creation date: 25 Sep 2023
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


unit TestProtocolPublishServerToClient;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolReceivePublishCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1;
    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_0;
    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_1;

  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl,
  Expectations, ExpectationsDynArrays;


type
  TMQTTPublishPropertiesArr = array of TMQTTPublishProperties;

var
  ReceivedPublishFields: TMQTTPublishFields;
  ReceivedPublishProperties: TMQTTPublishProperties;
  DestPacket: TMQTTControlPacket;

  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishPropertiesArr: TMQTTPublishPropertiesArr;

  FoundError: Word;
  ErrorOnPacketType: Byte;

  ReceivedCount: Byte;  //Counts how many times a PUBLISH handler is called. For QoS=0 and QoS=1, it should be on every receive. For QoS=2, it should be 1.

                                             //The lower word identifies the client instance
procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var APublishFields: TMQTTPublishFields; var APublishProperties: TMQTTPublishProperties);
var
  n: Integer;
  QoS: Byte;
begin
  Inc(ReceivedCount);
  DecodedPublishFields := APublishFields;

  //Expect(AErr).ToBe(CMQTT_Success);  //////////////////////////////////////////////////////// verify for incomplete packets???????????

  n := Length(DecodedPublishPropertiesArr);
  SetLength(DecodedPublishPropertiesArr, n + 1);
  MQTT_InitPublishProperties(DecodedPublishPropertiesArr[n]);
  MQTT_CopyPublishProperties(APublishProperties, DecodedPublishPropertiesArr[n]);

  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;

  if QoS = 0 then
    Expect(APublishFields.PacketIdentifier).ToBe(0)
  else
    Expect(APublishFields.PacketIdentifier).ToBe(456);
end;


procedure HandleOnBeforeSending_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties);
begin
  //Nothing here.
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolReceivePublishCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK^ := @HandleOnBeforeSending_MQTT_PUBACK;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSending_MQTT_PUBACK;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  ReceivedCount := 0;

  ReceivedPublishFields.PacketIdentifier := 456;
  InitDynArrayToEmpty(ReceivedPublishFields.ApplicationMessage);
  StringToDynArrayOfByte('SomeAppMsg', ReceivedPublishFields.ApplicationMessage);
  ReceivedPublishFields.EnabledProperties := 0;
  ReceivedPublishFields.PublishCtrlFlags := 0;
  InitDynArrayToEmpty(ReceivedPublishFields.TopicName);
  StringToDynArrayOfByte('SomeTopic', ReceivedPublishFields.TopicName);

  MQTT_InitPublishProperties(ReceivedPublishProperties);
  MQTT_InitControlPacket(DestPacket);

  SetLength(DecodedPublishPropertiesArr, 0);

  FoundError := CMQTT_Success;
end;


procedure TTestProtocolReceivePublishCase.TearDown;
var
  i: Integer;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreePublishProperties(ReceivedPublishProperties);

  FreeDynArray(ReceivedPublishFields.ApplicationMessage);
  FreeDynArray(ReceivedPublishFields.TopicName);

  for i := 0 to Length(DecodedPublishPropertiesArr) - 1 do
    MQTT_FreePublishProperties(DecodedPublishPropertiesArr[i]);

  SetLength(DecodedPublishPropertiesArr, 0);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0;
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

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1;
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

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_0;
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

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 1 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);

  FreeDynArray(TempBuffer);
end;

initialization

  RegisterTest(TTestProtocolReceivePublishCase);

end.

