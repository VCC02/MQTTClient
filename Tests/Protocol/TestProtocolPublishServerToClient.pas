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
  private
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_Generic(APacketIdentifier,
                                                                                   AModifiedPacketIdentifier,
                                                                                   AExpectedIdentifiersCount,
                                                                                   ANewReasonCode,
                                                                                   AExpectedFoundError,
                                                                                   AExpectedErrorOnPacketType: Word);

    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(APacketIdentifier,
                                                                                    AModifiedPacketIdentifier,
                                                                                    AExpectedIdentifiersCount,
                                                                                    ANewReasonCode,
                                                                                    AExpectedFoundError,
                                                                                    AExpectedErrorOnPacketType: Word);
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1;

    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_HappyFlow;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_BadReasonCode;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_BadPacketIdentifier;

    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_0;
    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_1;

    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow;
    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_BadReasonCode;
    procedure TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_BadPacketIdentifier;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl, MQTTPubRelCtrl,
  Expectations, ExpectationsDynArrays;


type
  TMQTTPublishPropertiesArr = array of TMQTTPublishProperties;

var
  ReceivedPublishFields: TMQTTPublishFields;
  ReceivedPublishProperties: TMQTTPublishProperties;
  ReceivedPubRelFields: TMQTTPubRelFields;
  ReceivedPubRelProperties: TMQTTPubRelProperties;
  DestPacket: TMQTTControlPacket;

  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishPropertiesArr: TMQTTPublishPropertiesArr;

  FoundError: Word;
  ErrorOnPacketType: Byte;

  ReceivedCount: Byte;  //Counts how many times a PUBLISH handler is called. For QoS=0 and QoS=1, it should be on every receive. For QoS=2, it should be 1.
  RecCount: Byte;
  CompCount: Byte;

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

  case QoS of
    0:
      Expect(APublishFields.PacketIdentifier).ToBe(0);
    1:
      Expect(APublishFields.PacketIdentifier).ToBe(456);
    2:
    begin
      case ReceivedCount of
        1:
          Expect(APublishFields.PacketIdentifier).ToBe(20);
        2:
          Expect(APublishFields.PacketIdentifier).ToBe(60);
        else
          Expect(APublishFields.PacketIdentifier).ToBe(-2, 'Unhandled case for PacketIdentifier value');
      end;
    end;
  end;
end;


procedure HandleOnBeforeSending_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties);
begin
  //Nothing here.
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
begin
  Inc(RecCount);  //publish received count
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  Inc(CompCount);  //publish complete count
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
    OnBeforeSendingMQTT_PUBREC^ := @HandleOnBeforeSending_MQTT_PUBREC;
    OnBeforeSendingMQTT_PUBCOMP^ := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSending_MQTT_PUBACK;
    OnBeforeSendingMQTT_PUBREC := @HandleOnBeforeSending_MQTT_PUBREC;
    OnBeforeSendingMQTT_PUBCOMP := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  ReceivedCount := 0;
  RecCount := 0;
  CompCount := 0;

  ReceivedPublishFields.PacketIdentifier := 456;
  InitDynArrayToEmpty(ReceivedPublishFields.ApplicationMessage);
  StringToDynArrayOfByte('SomeAppMsg', ReceivedPublishFields.ApplicationMessage);
  ReceivedPublishFields.EnabledProperties := 0;
  ReceivedPublishFields.PublishCtrlFlags := 0;
  InitDynArrayToEmpty(ReceivedPublishFields.TopicName);
  StringToDynArrayOfByte('SomeTopic', ReceivedPublishFields.TopicName);

  ReceivedPubRelFields.EnabledProperties := 0;
  ReceivedPubRelFields.ReasonCode := 0;
  InitDynArrayToEmpty(ReceivedPubRelFields.SrcPayload);
  InitDynArrayToEmpty(ReceivedPubRelProperties.ReasonString);
  InitDynOfDynOfByteToEmpty(ReceivedPubRelProperties.UserProperty);

  MQTT_InitPublishProperties(ReceivedPublishProperties);
  MQTT_InitControlPacket(DestPacket);

  SetLength(DecodedPublishPropertiesArr, 0);

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
end;


procedure TTestProtocolReceivePublishCase.TearDown;
var
  i: Integer;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreePublishProperties(ReceivedPublishProperties);

  FreeDynArray(ReceivedPublishFields.ApplicationMessage);
  FreeDynArray(ReceivedPublishFields.TopicName);

  FreeDynArray(ReceivedPubRelFields.SrcPayload);
  FreeDynArray(ReceivedPubRelProperties.ReasonString);
  FreeDynOfDynOfByteArray(ReceivedPubRelProperties.UserProperty);

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


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_Generic(APacketIdentifier,
                                                                                                               AModifiedPacketIdentifier,
                                                                                                               AExpectedIdentifiersCount,
                                                                                                               ANewReasonCode,
                                                                                                               AExpectedFoundError,
                                                                                                               AExpectedErrorOnPacketType: Word);
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 2 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  ReceivedPublishFields.PacketIdentifier := APacketIdentifier; //some value
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 1');
  Expect(ReceivedCount).ToBe(1);
  Expect(RecCount).ToBe(1);
  Expect(GetPacketIdentifiersCount(0)).ToBe(1, 'PacketIdentifier created.');
  Expect(GetPacketIdentifierByIndex(0, 0)).ToBe(20);

  //send second part of the ping-pong
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := AModifiedPacketIdentifier; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2');
  Expect(CompCount).ToBe(1);
  Expect(GetPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount, 'PacketIdentifier removed.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(APacketIdentifier,
                                                                                                                AModifiedPacketIdentifier,
                                                                                                                AExpectedIdentifiersCount,
                                                                                                                ANewReasonCode,
                                                                                                                AExpectedFoundError,
                                                                                                                AExpectedErrorOnPacketType: Word);
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 2 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  ReceivedPublishFields.PacketIdentifier := APacketIdentifier; //some value
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);

  //a second packet:
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  MQTT_FreePublishProperties(ReceivedPublishProperties);
  ReceivedPublishFields.PacketIdentifier := APacketIdentifier + 40; //some value
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 1');
  Expect(ReceivedCount).ToBe(2, 'Second ReceivedCount');
  Expect(RecCount).ToBe(2, 'Second RecCount');
  Expect(GetPacketIdentifiersCount(0)).ToBe(2, 'PacketIdentifier created.');
  Expect(GetPacketIdentifierByIndex(0, 0)).ToBe(APacketIdentifier);
  Expect(GetPacketIdentifierByIndex(0, 1)).ToBe(APacketIdentifier + 40);

  //send second part of the ping-pong
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := AModifiedPacketIdentifier; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2.1');
  Expect(CompCount).ToBe(1, 'CompCount');   //only one CompCount after first call to MQTT_Process
  Expect(GetPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount + 1, 'PacketIdentifier removed 1.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  //send second part of the ping-pong  - second packet
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := AModifiedPacketIdentifier + 40; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2.2');
  Expect(CompCount).ToBe(2, 'CompCount');
  Expect(GetPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount + Ord(APacketIdentifier <> AModifiedPacketIdentifier), 'PacketIdentifier removed 2.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_HappyFlow;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 20, 0,
                                                                       0,
                                                                       CMQTT_Success,
                                                                       CMQTT_UNDEFINED);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_BadReasonCode;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 20, 0,
                                                                       CMQTT_Reason_PacketIdentifierNotFound, //new reason code
                                                                       CMQTT_ProtocolError or CMQTT_Reason_PacketIdentifierNotFound shl 8,
                                                                       CMQTT_PUBREL);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_BadPacketIdentifier;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 30, 1,
                                                                       0,
                                                                       CMQTT_PacketIdentifierNotFound_ClientToServer,
                                                                       CMQTT_PUBREL);
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


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow;
begin
  TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 20, 0,
                                                                        0,
                                                                        CMQTT_Success,
                                                                        CMQTT_UNDEFINED);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_BadReasonCode;
begin
  TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 20, 0,
                                                                        CMQTT_Reason_PacketIdentifierNotFound, //new reason code
                                                                        CMQTT_ProtocolError or CMQTT_Reason_PacketIdentifierNotFound shl 8,
                                                                        CMQTT_PUBREL);
end;


procedure TTestProtocolReceivePublishCase.TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_BadPacketIdentifier;
begin
  TestClientToServerBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 30, 1,
                                                                        0,
                                                                        CMQTT_PacketIdentifierNotFound_ClientToServer,
                                                                        CMQTT_PUBREL);
end;


initialization

  RegisterTest(TTestProtocolReceivePublishCase);

end.

