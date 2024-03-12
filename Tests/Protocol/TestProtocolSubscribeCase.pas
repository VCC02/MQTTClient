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

    procedure TestClientToServerBufferContent_BeforeSubscribe_WithCallback_GenericPacketCount(ACount: Integer);
  published
    procedure TestClientToServerBufferContent_BeforeSubscribe_WithCallback_OnePacket;
  end;


implementation


uses
  MQTTClient, MQTTUtils, DynArrays, MQTTSubscribeCtrl, Expectations;


var
  //EncodedSubscribeBuffer: TDynArrayOfByte;
  DecodedSubscribePacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;
  FoundError: Word;
  ErrorOnPacketType: Byte;


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

  NewSubId := CreateClientToServerSubscriptionIdentifier(ClientInstance);  /////////////// always use CreateClientToServerSubscriptionIdentifier for these identifiers !!!
  if NewSubId = $FFFF then
  begin
    Result := False;
    Exit;
  end;

  Result := Result and AddDWordToDynArraysOfDWord(ASubscribeProperties.SubscriptionIdentifier, NewSubId);
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolSubscribeCase.SetUp;
begin
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

  //InitDynArrayToEmpty(EncodedSubscribeBuffer);
  MQTT_InitControlPacket(DecodedSubscribePacket);
  DecodedBufferLen := 0;

  FoundError := CMQTT_Success;
  ErrorOnPacketType := CMQTT_UNDEFINED;
end;


procedure TTestProtocolSubscribeCase.TearDown;
begin
  //FreeDynArray(EncodedSubscribeBuffer);
  MQTT_FreeControlPacket(DecodedSubscribePacket);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure TTestProtocolSubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_GenericPacketCount(ACount: Integer);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  Expect(MQTT_SUBSCRIBE(0, 0)).ToBe(True);  //add a SUBSCRIBE packet to ClientToServer buffer
  //verify buffer content
  BufferPointer := GetClientToServerBuffer(0, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  Expect(Err).ToBe(CMQTT_Success);
  Expect(FoundError).ToBe(CMQTT_Success);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);

  Expect(Decode_SubscribeToCtrlPacket(BufferPointer^, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedSubscribePacket.Header.Content^[0]).ToBe(CMQTT_SUBSCRIBE);
  Expect(DecodedBufferLen).ToBe(BufferPointer^.Len);
end;


procedure TTestProtocolSubscribeCase.TestClientToServerBufferContent_BeforeSubscribe_WithCallback_OnePacket;
begin
  TestClientToServerBufferContent_BeforeSubscribe_WithCallback_GenericPacketCount(0);
end;


initialization

  RegisterTest(TTestProtocolSubscribeCase);

end.

