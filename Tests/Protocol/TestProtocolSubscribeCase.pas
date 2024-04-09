{
    Copyright (C) 2024 VCC
    creation date: 12 Mar 2024
    initial release date: 12 Mar 2024

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


unit TestProtocolSubscribeCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TTestProtocolSubscribeCase = class(TTestCase)
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
  MQTTClient, MQTTUtils, DynArrays, MQTTSubscribeCtrl, Expectations
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


var
  DecodedSubscribePacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;
  FoundError: Word;
  ErrorOnPacketType: Byte;
  IncludeSubscriptionIdentifier: Boolean;


function HandleOnBeforeSendingMQTT_SUBSCRIBE(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                             var ASubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
                                             var ASubscribeProperties: TMQTTSubscribeProperties;
                                             ACallbackID: Word): Boolean;
var
  NewSubId: Word; //doesn't have to be DWord
begin
  Result := True;

  Result := Result and FillIn_SubscribePayload('abc/def', 73, ASubscribeFields.TopicFilters);
  Result := Result and FillIn_SubscribePayload('123/456/789', 85, ASubscribeFields.TopicFilters);

  if IncludeSubscriptionIdentifier then
  begin
    NewSubId := MQTT_CreateClientToServerSubscriptionIdentifier(ClientInstance);  /////////////// always use CreateClientToServerSubscriptionIdentifier for these identifiers !!!
    if NewSubId = $FFFF then
    begin
      Result := False;
      Exit;
    end;

    ASubscribeProperties.SubscriptionIdentifier := NewSubId;
    ASubscribeFields.EnabledProperties := CMQTTSubscribe_EnSubscriptionIdentifier;
  end;
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolSubscribeCase.SetUp;
begin
  {$IFDEF UsingDynTFT}
    MM_Init;
  {$ENDIF}

  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnBeforeSendingMQTT_SUBSCRIBE^ := @HandleOnBeforeSendingMQTT_SUBSCRIBE;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnBeforeSendingMQTT_SUBSCRIBE := @HandleOnBeforeSendingMQTT_SUBSCRIBE;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  MQTT_InitControlPacket(DecodedSubscribePacket);
  DecodedBufferLen := 0;

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
  IncludeSubscriptionIdentifier := False;
end;


procedure TTestProtocolSubscribeCase.TearDown;
begin
  MQTT_FreeControlPacket(DecodedSubscribePacket);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolSubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
  SubscribeFields: TMQTTSubscribeFields;
  SubscribeProperties: TMQTTSubscribeProperties;
  DecodedTopics: TDynArrayOfTDynArrayOfByte;
  DecodedSubscriptionOptions: TDynArrayOfByte;
begin
  Expect(MQTT_SUBSCRIBE(0, 0)).ToBe(True);  //add a SUBSCRIBE packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := MQTT_GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);
  Expect(FoundError).ToBe(CMQTT_Success);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);

  Expect(Decode_SubscribeToCtrlPacket(BufferPointer^, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedSubscribePacket.Header.Content^[0]).ToBe(CMQTT_SUBSCRIBE or 2);
  Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);

  InitDynArrayToEmpty(SubscribeFields.TopicFilters);
  MQTT_InitSubscribeProperties(SubscribeProperties);
  try
    Decode_Subscribe(DecodedSubscribePacket, SubscribeFields, SubscribeProperties);

    if IncludeSubscriptionIdentifier then
      Expect(SubscribeProperties.SubscriptionIdentifier).ToBe(CMQTT_ClientToServerSubscriptionIdentifiersInitOffset, 'Allocated SubscriptionIdentifier')
    else
      Expect(SubscribeProperties.SubscriptionIdentifier).ToBe(3, 'Default SubscriptionIdentifier');

    InitDynOfDynOfByteToEmpty(DecodedTopics);
    InitDynArrayToEmpty(DecodedSubscriptionOptions);
    try
      Expect(Decode_SubscribePayload(SubscribeFields.TopicFilters, DecodedTopics, DecodedSubscriptionOptions)).ToBe(CMQTTDecoderNoErr);
      Expect(DecodedTopics.Len).ToBe(2, 'Expected two topics');
      Expect(DecodedSubscriptionOptions.Len).ToBe(2, 'Expected two topic options');

      Expect(DynArrayOfByteToString(DecodedTopics.Content^[0]^)).ToBe('abc/def');
      Expect(DynArrayOfByteToString(DecodedTopics.Content^[1]^)).ToBe('123/456/789');
      Expect(DecodedSubscriptionOptions.Content^[0]).ToBe(73);
      Expect(DecodedSubscriptionOptions.Content^[1]).ToBe(85);
    finally
      FreeDynOfDynOfByteArray(DecodedTopics);
      FreeDynArray(DecodedSubscriptionOptions);
    end;

  finally
    MQTT_FreeSubscribeProperties(SubscribeProperties);
    FreeDynArray(SubscribeFields.TopicFilters);
  end;
end;


procedure TTestProtocolSubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback;
begin
  IncludeSubscriptionIdentifier := True;
  TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
end;


procedure TTestProtocolSubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_NoID;
begin
  IncludeSubscriptionIdentifier := False;
  TestClientToServerBufferContent_BeforeSubscribe_WithCallback_Generic;
end;


initialization

  RegisterTest(TTestProtocolSubscribeCase);

end.

