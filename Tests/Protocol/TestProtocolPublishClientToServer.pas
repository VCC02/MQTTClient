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
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_Content;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_SendQuota;

    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_PacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1_PacketIdentifier;
    procedure TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_PacketIdentifier;
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



function HandleOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                           var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                           var APublishProperties: TMQTTPublishProperties): Boolean;  //user code has to fill-in this parameter
begin
  Result := False;

  Expect(StringToDynArrayOfByte(FAppMsg, APublishFields.ApplicationMessage)).ToBe(True);
  Expect(StringToDynArrayOfByte(FTopicName, APublishFields.TopicName)).ToBe(True);
  AllocatedPacketIdentifier := APublishFields.PacketIdentifier;

  //APublishFields.PublishCtrlFlags := 0; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)   - should be overridden if a different QoS is required

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
  {$ELSE}
    OnBeforeSendingMQTT_PUBLISH := @HandleOnBeforeSendingMQTT_PUBLISH;
  {$ENDIF}

  //InitDynArrayToEmpty(EncodedPublishBuffer);
  MQTT_InitControlPacket(DecodedPublishPacket);
  DecodedBufferLen := 0;

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
  AllocatedPacketIdentifier := 65534;
  FAppMsg := 'NoApp';
  FTopicName := 'NoName';
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
  Expect(MQTT_PUBLISH(0, 0)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer
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
  Expect(MQTT_PUBLISH(0, 0)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

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


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_SendQuota; //SendQuota should not be used on QoS=0
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_PUBLISH(0, 0)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);

  Expect(True).ToBe(False, 'Send quota is not implemented.');  //ToDo:  implement Send quota, then make sure it is used on QoS > 0 only.
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(AQoS: Byte);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishProperties: TMQTTPublishProperties;
begin
  Expect(MQTT_PUBLISH(0, AQoS)).ToBe(True);  //add a PUBLISH packet to ClientToServer buffer

  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Decode_PublishToCtrlPacket(BufferPointer^, DecodedPublishPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);

  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);
  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  Decode_Publish(DecodedPublishPacket, DecodedPublishFields, DecodedPublishProperties);
  FreeDynArray(DecodedPublishFields.ApplicationMessage);
  FreeDynArray(DecodedPublishFields.TopicName);

  Expect(PacketIdentifierIsUsed(0, DecodedPublishFields.PacketIdentifier)).ToBe(AQoS = 2, 'PacketIdentifier is used on QoS=2 only.');  // for QoS = 2 only!!!

  if AQoS = 2 then
    Expect(AllocatedPacketIdentifier).ToBe(0);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_0_PacketIdentifier;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(0);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_1_PacketIdentifier;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(1);
end;


procedure TTestProtocolSendPublishCase.TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_2_PacketIdentifier;
begin
  TestClientToServerBufferContent_AfterPublish_OnePacket_QoS_Generic_PacketIdentifier(2);
end;


initialization

  RegisterTest(TTestProtocolSendPublishCase);

end.

