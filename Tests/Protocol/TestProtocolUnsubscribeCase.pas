{
    Copyright (C) 2024 VCC
    creation date: 22 Mar 2024
    initial release date: 23 Mar 2024

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


unit TestProtocolUnsubscribeCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TTestProtocolUnsubscribeCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
  published
    procedure TestClientToServerBufferContent_BeforeSubscribe_WithCallback;
    procedure TestClientToServerBufferContent_BeforeSubscribe_WithCallback_NoID;
  end;


implementation


uses
  MQTTClient, MQTTUtils, DynArrays, MQTTUnsubscribeCtrl, Expectations
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


var
  DecodedUnsubscribePacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;
  FoundError: Word;
  ErrorOnPacketType: Byte;
  IncludeSubscriptionIdentifier: Boolean;
  AllocatedSubscriptionIdentifier: Word;


function HandleOnBeforeSendingMQTT_UNSUBSCRIBE(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                               var AUnsubscribeFields: TMQTTUnsubscribeFields;                    //user code has to fill-in this parameter
                                               var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                                               ACallbackID: Word): Boolean;
begin
  Result := True;

  Result := Result and FillIn_UnsubscribePayload('abc/def', AUnsubscribeFields.TopicFilters);
  Result := Result and FillIn_UnsubscribePayload('123/456/789', AUnsubscribeFields.TopicFilters);

  if IncludeSubscriptionIdentifier then
  begin
    Expect(MQTT_RemoveClientToServerSubscriptionIdentifier(ClientInstance, AllocatedSubscriptionIdentifier)).ToBe(0);
    AUnsubscribeFields.EnabledProperties := 0;
  end;
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolUnsubscribeCase.SetUp;
begin
  {$IFDEF UsingDynTFT}
    MM_Init;
  {$ENDIF}

  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnBeforeSendingMQTT_UNSUBSCRIBE^ := @HandleOnBeforeSendingMQTT_UNSUBSCRIBE;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnBeforeSendingMQTT_UNSUBSCRIBE := @HandleOnBeforeSendingMQTT_UNSUBSCRIBE;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  MQTT_InitControlPacket(DecodedUnsubscribePacket);
  DecodedBufferLen := 0;

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
  IncludeSubscriptionIdentifier := False;
  AllocatedSubscriptionIdentifier := 370; //something different than 0 and different than SubscriptionIdentifier allocation offset
end;


procedure TTestProtocolUnsubscribeCase.TearDown;
begin
  MQTT_FreeControlPacket(DecodedUnsubscribePacket);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolUnsubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
  UnsubscribeFields: TMQTTUnsubscribeFields;
  UnsubscribeProperties: TMQTTUnsubscribeProperties;
  DecodedTopics: TDynArrayOfTDynArrayOfByte;
begin
  Expect(MQTT_UNSUBSCRIBE(0, 0)).ToBe(True);  //add an UNSUBSCRIBE packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := MQTT_GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);
  Expect(FoundError).ToBe(CMQTT_Success);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);

  Expect(Decode_UnsubscribeToCtrlPacket(BufferPointer^, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedUnsubscribePacket.Header.Content^[0]).ToBe(CMQTT_UNSUBSCRIBE or 2);
  Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);

  InitDynArrayToEmpty(UnsubscribeFields.TopicFilters);
  MQTT_InitUnsubscribeProperties(UnsubscribeProperties);
  try
    Decode_Unsubscribe(DecodedUnsubscribePacket, UnsubscribeFields, UnsubscribeProperties);

    InitDynOfDynOfByteToEmpty(DecodedTopics);
    try
      Expect(Decode_UnsubscribePayload(UnsubscribeFields.TopicFilters, DecodedTopics)).ToBe(CMQTTDecoderNoErr);
      Expect(DecodedTopics.Len).ToBe(2, 'Expected two topics');

      Expect(DynArrayOfByteToString(DecodedTopics.Content^[0]^)).ToBe('abc/def');
      Expect(DynArrayOfByteToString(DecodedTopics.Content^[1]^)).ToBe('123/456/789');
    finally
      FreeDynOfDynOfByteArray(DecodedTopics);
    end;

  finally
    MQTT_FreeUnsubscribeProperties(UnsubscribeProperties);
    FreeDynArray(UnsubscribeFields.TopicFilters);
  end;
end;


procedure TTestProtocolUnsubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback;
begin
  IncludeSubscriptionIdentifier := True;

  AllocatedSubscriptionIdentifier := MQTT_CreateClientToServerSubscriptionIdentifier(0); //used in handler
  Expect(AllocatedSubscriptionIdentifier).NotToBe($FFFF);
  TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
end;


procedure TTestProtocolUnsubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_NoID;
begin
  IncludeSubscriptionIdentifier := False;
  TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
end;


initialization

  RegisterTest(TTestProtocolUnsubscribeCase);

end.

