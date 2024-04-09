{
    Copyright (C) 2024 VCC
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

  TTestPacketBuffer = array[0..0] of Byte;
  PTestPacketBuffer = ^TTestPacketBuffer;


  TTestProtocolReceivePublishCase = class(TTestCase)
  private
    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_Generic(APacketIdentifier,
                                                                                   AModifiedPacketIdentifier,
                                                                                   AExpectedIdentifiersCount,
                                                                                   ANewReasonCode,
                                                                                   AExpectedFoundError,
                                                                                   AExpectedErrorOnPacketType: Word);

    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(APacketIdentifier,
                                                                                    AModifiedPacketIdentifier,
                                                                                    ASecondPacketIdentifier,
                                                                                    ASecondModifiedPacketIdentifier,
                                                                                    AExpectedIdentifiersCount,
                                                                                    ANewReasonCode,
                                                                                    AExpectedFoundError,
                                                                                    AExpectedErrorOnPacketType: Word);

    procedure TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(const ASrcBuf: PTestPacketBuffer; ALen: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_0;
    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_1;

    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_HappyFlow;
    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_BadReasonCode;
    procedure TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_BadPacketIdentifier;

    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_0;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_1;

    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_0_IRLPackets;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_1_IRLPackets;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_IRLPackets;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_IRLPackets_WithPUBREL;

    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_BadReasonCode;
    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_BadPacketIdentifier;

    procedure TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow_DUP;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl, MQTTPubRelCtrl,
  Expectations, ExpectationsDynArrays
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


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

  ReceivedMessages: TStringArray;

  FoundError: Word;
  ErrorOnPacketType: Byte;

  ReceivedCount: Byte;  //Counts how many times a PUBLISH handler is called. For QoS=0 and QoS=1, it should be on every receive. For QoS=2, it should be 1.
  RecCount: Byte;
  CompCount: Byte;
  ReceivedPacketIdentifiers: array of Word;

                                             //The lower word identifies the client instance
procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var APublishFields: TMQTTPublishFields; var APublishProperties: TMQTTPublishProperties);
var
  n: Integer;
  QoS: Byte;
begin
  Inc(ReceivedCount);
  DecodedPublishFields := APublishFields;

  SetLength(ReceivedMessages, Length(ReceivedMessages) + 1);
  ReceivedMessages[Length(ReceivedMessages) - 1] := DynArrayOfByteToString(APublishFields.ApplicationMessage);

  //Expect(AErr).ToBe(CMQTT_Success);  //////////////////////////////////////////////////////// verify for incomplete packets???????????

  n := Length(DecodedPublishPropertiesArr);
  SetLength(DecodedPublishPropertiesArr, n + 1);
  MQTT_InitPublishProperties(DecodedPublishPropertiesArr[n]);
  MQTT_CopyPublishProperties(APublishProperties, DecodedPublishPropertiesArr[n]);

  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;

  SetLength(ReceivedPacketIdentifiers, Length(ReceivedPacketIdentifiers) + 1);
  ReceivedPacketIdentifiers[Length(ReceivedPacketIdentifiers) - 1] := APublishFields.PacketIdentifier;
end;


procedure HandleOnBeforeSending_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties);
begin
  //Nothing here.
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
begin
  Inc(RecCount);  //publish received count
end;


procedure HandleOnAfterReceiving_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
begin
  //
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  Inc(CompCount);  //publish complete count
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
  //Expect(ErrorOnPacketType).ToBe(0, 'Packet type error');
end;


procedure HandleOnSend_MQTT_Packet(ClientInstance: DWord; APacketType: Byte);
begin

end;


procedure TTestProtocolReceivePublishCase.SetUp;
begin
  {$IFDEF UsingDynTFT}
    MM_Init;
  {$ENDIF}

  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK^ := @HandleOnBeforeSending_MQTT_PUBACK;
    OnBeforeSendingMQTT_PUBREC^ := @HandleOnBeforeSending_MQTT_PUBREC;
    OnAfterReceivingMQTT_PUBREL^ := @HandleOnAfterReceiving_MQTT_PUBREL;
    OnBeforeSendingMQTT_PUBCOMP^ := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnMQTTError^ := @HandleOnMQTTError;
    OnSendMQTT_Packet^ := @HandleOnSend_MQTT_Packet;
  {$ELSE}
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSending_MQTT_PUBACK;
    OnBeforeSendingMQTT_PUBREC := @HandleOnBeforeSending_MQTT_PUBREC;
    OnAfterReceivingMQTT_PUBREL := @HandleOnAfterReceiving_MQTT_PUBREL;
    OnBeforeSendingMQTT_PUBCOMP := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnMQTTError := @HandleOnMQTTError;
    OnSendMQTT_Packet := @HandleOnSend_MQTT_Packet;
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
  SetLength(ReceivedPacketIdentifiers, 0);

  SetLength(ReceivedMessages, 0);
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
  SetLength(ReceivedMessages, 0);
  SetLength(ReceivedPacketIdentifiers, 0);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_0;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 0; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(1);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 1 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(1);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(456);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_Generic(APacketIdentifier,
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

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 1');
  Expect(ReceivedCount).ToBe(1);
  Expect(RecCount).ToBe(1);
  Expect(MQTT_GetServerToClientPacketIdentifiersCount(0)).ToBe(1, 'PacketIdentifier created.');
  Expect(MQTT_GetServerToClientPacketIdentifierByIndex(0, 0)).ToBe(20);

  //send second part of the ping-pong
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := AModifiedPacketIdentifier; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2');
  Expect(CompCount).ToBe(1);
  Expect(MQTT_GetServerToClientPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount, 'PacketIdentifier removed.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(APacketIdentifier,
                                                                                                                AModifiedPacketIdentifier,
                                                                                                                ASecondPacketIdentifier,
                                                                                                                ASecondModifiedPacketIdentifier,
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

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);

  //a second packet:
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  MQTT_FreePublishProperties(ReceivedPublishProperties);
  ReceivedPublishFields.PacketIdentifier := ASecondPacketIdentifier; //some value
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 1');
  Expect(ReceivedCount).ToBe(2, 'Second ReceivedCount');
  Expect(RecCount).ToBe(1 + Ord(APacketIdentifier <> ASecondPacketIdentifier), 'Second RecCount');  ////////////////// also possible that the Modified args will have to be part of the formula
  Expect(MQTT_GetServerToClientPacketIdentifiersCount(0)).ToBe(2, 'PacketIdentifier created.');
  Expect(MQTT_GetServerToClientPacketIdentifierByIndex(0, 0)).ToBe(APacketIdentifier);
  Expect(MQTT_GetServerToClientPacketIdentifierByIndex(0, 1)).ToBe(ASecondPacketIdentifier);

  //send second part of the ping-pong
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := AModifiedPacketIdentifier; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2.1');
  Expect(CompCount).ToBe(1, 'CompCount');   //only one CompCount after first call to MQTT_Process
  Expect(MQTT_GetServerToClientPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount + 1, 'PacketIdentifier removed 1.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  //send second part of the ping-pong  - second packet
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(TempBuffer);
  ReceivedPubRelFields.PacketIdentifier := ASecondModifiedPacketIdentifier; //If different than above, it should cause an error event.
  ReceivedPubRelFields.ReasonCode := ANewReasonCode;
  FillIn_PubRel(ReceivedPubRelFields, ReceivedPubRelProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing 2.2');
  Expect(CompCount).ToBe(2, 'CompCount');
  Expect(MQTT_GetServerToClientPacketIdentifiersCount(0)).ToBe(AExpectedIdentifiersCount + Ord(APacketIdentifier <> AModifiedPacketIdentifier), 'PacketIdentifier removed 2.');

  Expect(FoundError).ToBe(AExpectedFoundError);
  Expect(ErrorOnPacketType).ToBe(AExpectedErrorOnPacketType);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_HappyFlow;
begin
  TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 20, 0,
                                                                       0,
                                                                       CMQTT_Success,
                                                                       CMQTT_UNDEFINED);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_BadReasonCode;
begin
  TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 20, 0,
                                                                       CMQTT_Reason_PacketIdentifierNotFound, //new reason code
                                                                       CMQTT_ProtocolError or CMQTT_Reason_PacketIdentifierNotFound shl 8,
                                                                       CMQTT_PUBREL);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_BadPacketIdentifier;
begin
  TestServerToClientBufferContent_AfterPublish_OnePacket_QoS_2_Generic(20, 30, 1,
                                                                       0,
                                                                       CMQTT_PacketIdentifierNotFound_ServerToClient,
                                                                       CMQTT_PUBREL);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_0;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 0; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_1;
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);

  ReceivedPublishFields.PublishCtrlFlags := 1 shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  FillIn_Publish(ReceivedPublishFields, ReceivedPublishProperties, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(456);
  Expect(ReceivedPacketIdentifiers[1]).ToBe(456);

  FreeDynArray(TempBuffer);
end;


procedure TestBufferToDynArrayOfByte(const ASrcBuf: PTestPacketBuffer; ALen: Integer; var DestBuffer: TDynArrayOfByte);
var
  s: string;
begin
  SetLength(s, ALen);
  Move(ASrcBuf^[0], s[1], ALen);
  StringToDynArrayOfByte(s, DestBuffer);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(const ASrcBuf: PTestPacketBuffer; ALen: Integer);
const
  CMsg1 = 'First content';
  CMsg2 = 'Second content_and_more';
var
  TempBuffer: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempBuffer);
  TestBufferToDynArrayOfByte(ASrcBuf, ALen, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer); //single call
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');
  Expect(ReceivedCount).ToBe(2);

  FreeDynArray(TempBuffer);

  Expect(ReceivedMessages[0]).ToBe(CMsg1);
  Expect(ReceivedMessages[1]).ToBe(CMsg2);
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_0_IRLPackets;
const
  CRecPackets: array[0..23+34] of Byte = (
    48, 22, 0, 3, 97, 98, 99, 3, 11, 188, 5, 70, 105, 114, 115, 116, 32, 99, 111, 110, 116, 101, 110, 116
    //                                        F    i    r    s    t       c    o    n    t    e    n    t
    ,
    48, 32, 0, 3, 97, 98, 99, 3, 11, 188, 5, 83, 101, 99, 111, 110, 100, 32, 99, 111, 110, 116, 101, 110, 116, 95, 97, 110, 100, 95, 109, 111, 114, 101
    //                                        S    e   c    o    n    d       c    o    n    t    e    n    t   _   a    n    d   _    m    o    r    e
    );
begin
  TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(@CRecPackets, Length(CRecPackets));
  Expect(ReceivedPacketIdentifiers[0]).ToBe(0, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(0, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_1_IRLPackets;
const
  CRecPackets: array[0..25+36] of Byte = (
    50, 24, 0, 3, 97, 98, 99, 0, 1, 3, 11, 188, 5, 70, 105, 114, 115, 116, 32, 99, 111, 110, 116, 101, 110, 116
    //                                              F    i    r    s    t       c    o    n    t    e    n    t
    ,
    50, 34, 0, 3, 97, 98, 99, 0, 2, 3, 11, 188, 5, 83, 101, 99, 111, 110, 100, 32, 99, 111, 110, 116, 101, 110, 116, 95, 97, 110, 100, 95, 109, 111, 114, 101
    //                                              S    e   c    o    n    d       c    o    n    t    e    n    t   _   a    n    d   _    m    o    r    e
    );
begin
  TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(@CRecPackets, Length(CRecPackets));
  Expect(ReceivedPacketIdentifiers[0]).ToBe(1, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(2, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_IRLPackets;
const
  CRecPackets: array[0..25+36] of Byte = (
    52, 24, 0, 3, 97, 98, 99, 0, 1, 3, 11, 188, 5, 70, 105, 114, 115, 116, 32, 99, 111, 110, 116, 101, 110, 116
    //                                              F    i    r    s    t       c    o    n    t    e    n    t
    ,
    52, 34, 0, 3, 97, 98, 99, 0, 2, 3, 11, 188, 5, 83, 101, 99, 111, 110, 100, 32, 99, 111, 110, 116, 101, 110, 116, 95, 97, 110, 100, 95, 109, 111, 114, 101
    //                                              S    e   c    o    n    d       c    o    n    t    e    n    t   _   a    n    d   _    m    o    r    e
    );
begin
  TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(@CRecPackets, Length(CRecPackets));
  Expect(ReceivedPacketIdentifiers[0]).ToBe(1, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(2, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_IRLPackets_WithPUBREL;
const
  CRecPackets: array[0..25+4+36] of Byte = (
    52, 24, 0, 3, 97, 98, 99, 0, 1, 3, 11, 188, 5, 70, 105, 114, 115, 116, 32, 99, 111, 110, 116, 101, 110, 116
    //                                              F    i    r    s    t       c    o    n    t    e    n    t
    , 98, 2, 0, 1, //PUBREL
    52, 34, 0, 3, 97, 98, 99, 0, 2, 3, 11, 188, 5, 83, 101, 99, 111, 110, 100, 32, 99, 111, 110, 116, 101, 110, 116, 95, 97, 110, 100, 95, 109, 111, 114, 101
    //                                              S    e   c    o    n    d       c    o    n    t    e    n    t   _   a    n    d   _    m    o    r    e
    );
begin
  TestServerToClientBufferContent_AfterPublish_TwoIRLPackets(@CRecPackets, Length(CRecPackets));
  Expect(ReceivedPacketIdentifiers[0]).ToBe(1, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(2, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow;
begin
  TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 20, 40 + 20, 40 + 20, 0,
                                                                        0,
                                                                        CMQTT_Success,
                                                                        CMQTT_UNDEFINED);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(60, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_BadReasonCode;
begin
  TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 20, 40 + 20, 40 + 20,  0,
                                                                        CMQTT_Reason_PacketIdentifierNotFound, //new reason code
                                                                        CMQTT_ProtocolError or CMQTT_Reason_PacketIdentifierNotFound shl 8,
                                                                        CMQTT_PUBREL);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(60, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_BadPacketIdentifier;
begin
  TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 30, 40 + 20, 40 + 30, 1,
                                                                        0,
                                                                        CMQTT_PacketIdentifierNotFound_ServerToClient,
                                                                        CMQTT_PUBREL);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(60, '[1]');
end;


procedure TTestProtocolReceivePublishCase.TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_HappyFlow_DUP;
begin
  TestServerToClientBufferContent_AfterPublish_TwoPackets_QoS_2_Generic(20, 20, 0 + 20, 0 + 20, 0,
                                                                        0,
                                                                        CMQTT_Success,
                                                                        CMQTT_UNDEFINED);
  Expect(ReceivedPacketIdentifiers[0]).ToBe(20, '[0]');
  Expect(ReceivedPacketIdentifiers[1]).ToBe(20, '[1]');
end;

initialization

  RegisterTest(TTestProtocolReceivePublishCase);

end.

