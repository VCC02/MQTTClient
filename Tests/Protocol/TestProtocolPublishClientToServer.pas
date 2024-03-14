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



unit TestProtocolPublishClientToServer;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolSendPublishCase = class(TTestCase)
  private
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(AQoS: Byte);
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_SendQuota(AQoS: Byte);

  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_Content;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_SendQuota;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1_SendQuota;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_SendQuota;

    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To0_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To1_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To2_ModifiedPacketIdentifier;

    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To0_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To1_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To2_ModifiedPacketIdentifier;

    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To0_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To1_ModifiedPacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To2_ModifiedPacketIdentifier;
  end;


implementation


uses
  MQTTClient, MQTTUtils, DynArrays, MQTTPublishCtrl, Expectations;


var
  //EncodedPublishBuffer: TDynArrayOfByte;
  DecodedPublishPacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;
  FoundError: Word;
  ErrorOnPacketType: Byte;
  AllocatedPacketIdentifier: Word;
  FAppMsg, FTopicName: string;
  NewQoS: Byte;


function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
begin
  Result := True;
  //MQTT_InitWillProperties(TempWillProperties);
end;


function HandleOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                           var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                           var APublishProperties: TMQTTPublishProperties;            //user code has to fill-in this parameter
                                           ACallbackID: Word): Boolean;
begin
  Result := False;

  Expect(StringToDynArrayOfByte(FAppMsg, APublishFields.ApplicationMessage)).ToBe(True);
  Expect(StringToDynArrayOfByte(FTopicName, APublishFields.TopicName)).ToBe(True);
  AllocatedPacketIdentifier := APublishFields.PacketIdentifier;                    //if users override QoS in this handler, then a a different PacketIdentifier might be allocated (depending on what is available)

  APublishFields.PublishCtrlFlags := APublishFields.PublishCtrlFlags and $9; //clear QoS //bits 3-0:  Dup(3), QoS(2-1), Retain(0)   - should be overridden if a different QoS is required
  APublishFields.PublishCtrlFlags := APublishFields.PublishCtrlFlags or (NewQoS shl 1);

  Result := True;
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolSendPublishCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnBeforeSendingMQTT_PUBLISH^ := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnBeforeMQTT_CONNECT^ := @HandleOnBeforeMQTT_CONNECT;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnBeforeSendingMQTT_PUBLISH := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnBeforeMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ENDIF}

  //InitDynArrayToEmpty(EncodedPublishBuffer);
  MQTT_InitControlPacket(DecodedPublishPacket);
  DecodedBufferLen := 0;

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
  AllocatedPacketIdentifier := 65534;
  FAppMsg := 'NoApp';
  FTopicName := 'NoName';
  NewQoS := 0; //some valid default value
end;


procedure TTestProtocolSendPublishCase.TearDown;
begin
  //FreeDynArray(EncodedPublishBuffer);
  MQTT_FreeControlPacket(DecodedPublishPacket);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_PUBLISH(0, 0, 0)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);
  Expect(FoundError).ToBe(CMQTT_Success);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);

  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPublishPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH);
  Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_Content;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishProperties: TMQTTPublishProperties;
begin
  FAppMsg := 'MyAppMsg';
  FTopicName := 'SomeTopic';
  Expect(MQTT_PUBLISH(0, 0, 0)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);

  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);
  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  Decode_Publish(DecodedPublishPacket, DecodedPublishFields, DecodedPublishProperties);

  Expect(DynArrayOfByteToString(DecodedPublishFields.ApplicationMessage)).ToBe(FAppMsg);
  Expect(DynArrayOfByteToString(DecodedPublishFields.TopicName)).ToBe(FTopicName);
  FreeDynArray(DecodedPublishFields.ApplicationMessage);
  FreeDynArray(DecodedPublishFields.TopicName);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_SendQuota(AQoS: Byte); //SendQuota should not be used on QoS=0
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_CONNECT(0, 0)).ToBe(True);
  Expect(MQTT_PUBLISH(0, 0, AQoS)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);

  Expect(GetSendQuota(0)).ToBe(CMQTT_DefaultReceiveMaximum - Ord(AQoS > 0), 'Send quota is less than initial of QoS > 0.');
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_SendQuota;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_SendQuota(0);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1_SendQuota;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_SendQuota(1);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_SendQuota;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_SendQuota(2);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(AQoS: Byte);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishProperties: TMQTTPublishProperties;
begin
  Expect(MQTT_PUBLISH(0, 0, AQoS)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);

  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);
  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  Decode_Publish(DecodedPublishPacket, DecodedPublishFields, DecodedPublishProperties);
  FreeDynArray(DecodedPublishFields.ApplicationMessage);
  FreeDynArray(DecodedPublishFields.TopicName);

  Expect(GetClientToServerPacketIdentifiersCount(0)).ToBe(Ord(NewQoS > 0) + 1); //+1 because of preallocated PacketIdentifiers

  if NewQoS > 0 then
  begin
    Expect(AllocatedPacketIdentifier).ToBe(1, 'AllocatedPacketIdentifier');
    Expect(ClientToServerPacketIdentifierIsUsed(0, DecodedPublishFields.PacketIdentifier)).ToBe(True, 'PacketIdentifier is used on QoS>0 only.');  // for QoS > 0 only!!!
  end;
end;

///////////////////

procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To0_ModifiedPacketIdentifier;
begin
  NewQoS := 0;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(0);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To1_ModifiedPacketIdentifier;
begin
  NewQoS := 1;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(0);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0To2_ModifiedPacketIdentifier;
begin
  NewQoS := 2;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(0);
end;

///////////////////

procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To0_ModifiedPacketIdentifier;
begin
  NewQoS := 0;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(1);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To1_ModifiedPacketIdentifier;
begin
  NewQoS := 1;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(1);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1To2_ModifiedPacketIdentifier;
begin
  NewQoS := 2;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(1);
end;

///////////////////

procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To0_ModifiedPacketIdentifier;
begin
  NewQoS := 0;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(2);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To1_ModifiedPacketIdentifier;
begin
  NewQoS := 1;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(2);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2To2_ModifiedPacketIdentifier;
begin
  NewQoS := 2;
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(2);
end;


initialization

  RegisterTest(TTestProtocolSendPublishCase);

end.

