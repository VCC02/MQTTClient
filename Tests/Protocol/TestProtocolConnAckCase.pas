{
    Copyright (C) 2023 VCC
    creation date: 06 Aug 2023
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


unit TestProtocolConnAckCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolConnAckCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    procedure TestClientToServerBufferContent_AfterConnAck_OnePacket;
    procedure TestClientToServerBufferContent_AfterConnAck_TwoPackets;
    procedure TestClientToServerBufferContent_AfterConnAck_TwoPackets_FirstWithUndefinedPacketError;
    procedure TestClientToServerBufferContent_AfterConnAck_TwoPackets_SecondWithUndefinedPacketError;
    procedure TestClientToServerBufferContent_AfterConnAck_TwoPackets_FirstWithContentError;
    procedure TestClientToServerBufferContent_AfterConnAck_TwoPackets_SecondWithContentError;
    procedure TestClientToServerBufferContent_AfterConnAck_PartialPacket;
    procedure TestClientToServerBufferContent_AfterConnAck_PartialPacketThenRemaining;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTConnAckCtrl,
  Expectations, ExpectationsDynArrays;


type
  TMQTTConnAckPropertiesArr = array of TMQTTConnAckProperties;

var
  FieldsToSend: TMQTTConnAckFields;
  PropertiesToSend: TMQTTConnAckProperties;
  DestPacket: TMQTTControlPacket;

  DecodedConnAckFields: TMQTTConnAckFields;
  DecodedConnAckPropertiesArr: TMQTTConnAckPropertiesArr;

  FoundError: Word;
  ErrorOnPacketType: Byte;


procedure HandleOnAfterMQTT_CONNACK(ClientInstance: DWord; var AConnAckFields: TMQTTConnAckFields; var AConnAckProperties: TMQTTConnAckProperties);
var
  n: Integer;
begin
  DecodedConnAckFields := AConnAckFields;

  n := Length(DecodedConnAckPropertiesArr);
  SetLength(DecodedConnAckPropertiesArr, n + 1);
  MQTT_InitConnAckProperties(DecodedConnAckPropertiesArr[n]);
  MQTT_CopyConnAckProperties(AConnAckProperties, DecodedConnAckPropertiesArr[n]);
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolConnAckCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnAfterMQTT_CONNACK^ := @HandleOnAfterMQTT_CONNACK;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnAfterMQTT_CONNACK := @HandleOnAfterMQTT_CONNACK;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  FieldsToSend.EnabledProperties := 0;
  FieldsToSend.SessionPresentFlag := 0;
  FieldsToSend.ConnectReasonCode := 0;

  MQTT_InitConnAckProperties(PropertiesToSend);
  MQTT_InitControlPacket(DestPacket);

  FoundError := CMQTT_Success;
end;


procedure TTestProtocolConnAckCase.TearDown;
var
  i: Integer;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreeConnAckProperties(PropertiesToSend);

  for i := 0 to Length(DecodedConnAckPropertiesArr) - 1 do
    MQTT_FreeConnAckProperties(DecodedConnAckPropertiesArr[i]);

  SetLength(DecodedConnAckPropertiesArr, 0);

  MQTT_DestroyClient(0);
  MQTT_Done;
end;


procedure FillInTestProperties;
begin
  PropertiesToSend.SessionExpiryInterval := 100;
  PropertiesToSend.ReceiveMaximum := 50;
  PropertiesToSend.MaximumQoS := 0;
  PropertiesToSend.RetainAvailable := 1;
  PropertiesToSend.MaximumPacketSize := 300;
  StringToDynArrayOfByte('Some_identifier', PropertiesToSend.AssignedClientIdentifier);
  PropertiesToSend.TopicAliasMaximum := 80;
  StringToDynArrayOfByte('Some_ReasonString', PropertiesToSend.ReasonString);
  AddStringToDynOfDynArrayOfByte('Some_userprop', PropertiesToSend.UserProperty);
  PropertiesToSend.WildcardSubscriptionAvailable := 31;
  PropertiesToSend.SubscriptionIdentifierAvailable := 45;
  PropertiesToSend.SharedSubscriptionAvailable := 65;
  PropertiesToSend.ServerKeepAlive := 3600;
  StringToDynArrayOfByte('info', PropertiesToSend.ResponseInformation);
  StringToDynArrayOfByte('ref', PropertiesToSend.ServerReference);
  StringToDynArrayOfByte('method', PropertiesToSend.AuthenticationMethod);
  StringToDynArrayOfByte('data', PropertiesToSend.AuthenticationData);
end;


procedure VerifyProperties(APacketIndex: Integer);
begin
  Expect(DecodedConnAckPropertiesArr[APacketIndex].SessionExpiryInterval).ToBe(PropertiesToSend.SessionExpiryInterval);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].ReceiveMaximum).ToBe(PropertiesToSend.ReceiveMaximum);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].MaximumQoS).ToBe(PropertiesToSend.MaximumQoS);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].RetainAvailable).ToBe(PropertiesToSend.RetainAvailable);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].MaximumPacketSize).ToBe(PropertiesToSend.MaximumPacketSize);

  Expect(DecodedConnAckPropertiesArr[APacketIndex].AssignedClientIdentifier).ToMatchContentOf(PropertiesToSend.AssignedClientIdentifier);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].TopicAliasMaximum).ToBe(PropertiesToSend.TopicAliasMaximum);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].ReasonString).ToMatchContentOf(PropertiesToSend.ReasonString);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].UserProperty).ToMatchContentOf(PropertiesToSend.UserProperty);

  Expect(DecodedConnAckPropertiesArr[APacketIndex].WildcardSubscriptionAvailable).ToBe(PropertiesToSend.WildcardSubscriptionAvailable);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].SubscriptionIdentifierAvailable).ToBe(PropertiesToSend.SubscriptionIdentifierAvailable);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].SharedSubscriptionAvailable).ToBe(PropertiesToSend.SharedSubscriptionAvailable);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].ServerKeepAlive).ToBe(PropertiesToSend.ServerKeepAlive);

  Expect(DecodedConnAckPropertiesArr[APacketIndex].ResponseInformation).ToMatchContentOf(PropertiesToSend.ResponseInformation);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].ServerReference).ToMatchContentOf(PropertiesToSend.ServerReference);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].AuthenticationMethod).ToMatchContentOf(PropertiesToSend.AuthenticationMethod);
  Expect(DecodedConnAckPropertiesArr[APacketIndex].AuthenticationData).ToMatchContentOf(PropertiesToSend.AuthenticationData);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_OnePacket;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');

  Expect(DecodedConnAckFields.EnabledProperties).ToBe($1FFFF);
  Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
  Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);

  VerifyProperties(0);
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_TwoPackets;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Successful processing');

  Expect(DecodedConnAckFields.EnabledProperties).ToBe($1FFFF);
  Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
  Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);

  VerifyProperties(0);
  VerifyProperties(1);
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_TwoPackets_FirstWithUndefinedPacketError;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);

  StringToDynArrayOfByte(Chr(CMQTT_UNDEFINED) + 'abc', TempBuffer); //some string which the MQTT library will mark as bad packet
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  FreeDynArray(TempBuffer);

  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_UnhandledPacketType, 'Bad processing');

  Expect(FoundError).ToBe(CMQTT_UnhandledPacketType);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);
  Expect(Length(DecodedConnAckPropertiesArr)).ToBe(0);

  //the processing stops in case of an error
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_TwoPackets_SecondWithUndefinedPacketError;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);

  StringToDynArrayOfByte(Chr(CMQTT_UNDEFINED) + 'abc', TempBuffer); //some string which the MQTT library will mark as bad packet
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  FreeDynArray(TempBuffer);

  Expect(MQTT_Process(0)).ToBe(CMQTT_UnhandledPacketType, 'Bad processing');

  Expect(DecodedConnAckFields.EnabledProperties).ToBe($1FFFF); //these should be valid from the first packet
  Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
  Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);

  Expect(FoundError).ToBe(CMQTT_UnhandledPacketType);
  Expect(ErrorOnPacketType).ToBe(CMQTT_UNDEFINED);
  Expect(Length(DecodedConnAckPropertiesArr)).ToBe(1);
  VerifyProperties(0);

  //the processing stops in case of an error
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_TwoPackets_FirstWithContentError;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);

  StringToDynArrayOfByte(Chr(CMQTT_CONNACK) + 'abc', TempBuffer); //some string which the MQTT library will mark as bad packet
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  FreeDynArray(TempBuffer);

  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTTDecoderUnknownProperty, 'Bad processing');

  Expect(FoundError).ToBe(CMQTTDecoderUnknownProperty, 'Expected found error');
  Expect(ErrorOnPacketType).ToBe(CMQTT_CONNACK);
  Expect(Length(DecodedConnAckPropertiesArr)).ToBe(0);

  //the processing stops in case of an error
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_TwoPackets_SecondWithContentError;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);

  StringToDynArrayOfByte(Chr(CMQTT_CONNACK) + 'abc', TempBuffer); //some string which the MQTT library will mark as bad packet
  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  FreeDynArray(TempBuffer);

  Expect(MQTT_Process(0)).ToBe(CMQTTDecoderIncompleteBuffer, 'Bad processing');

  Expect(DecodedConnAckFields.EnabledProperties).ToBe($1FFFF); //these should be valid from the first packet
  Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
  Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);

  Expect(FoundError).ToBe(CMQTTDecoderIncompleteBuffer, 'Expected found error');
  Expect(ErrorOnPacketType).ToBe(CMQTT_CONNACK);
  Expect(Length(DecodedConnAckPropertiesArr)).ToBe(1);
  VerifyProperties(0);

  //the processing stops in case of an error
  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_PartialPacket;
var
  TempBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  SetDynLength(TempBuffer, TempBuffer.Len - 10); // remove some bytes at the end, to make the decoder report an incomplete buffer

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTTDecoderIncompleteBuffer, 'Expecting an incomplete buffer.');

  FreeDynArray(TempBuffer);
end;


procedure TTestProtocolConnAckCase.TestClientToServerBufferContent_AfterConnAck_PartialPacketThenRemaining;
var
  TempBuffer, RemainingBuffer: TDynArrayOfByte;
begin
  FieldsToSend.EnabledProperties := $1FFFF;
  FieldsToSend.SessionPresentFlag := 1;
  FieldsToSend.ConnectReasonCode := 0;

  InitDynArrayToEmpty(TempBuffer);
  InitDynArrayToEmpty(RemainingBuffer);
  FillInTestProperties;

  FillIn_ConnAck(FieldsToSend, PropertiesToSend, DestPacket);
  EncodeControlPacketToBuffer(DestPacket, TempBuffer);

  Expect(CopyFromDynArray(RemainingBuffer, TempBuffer, TempBuffer.Len - 10, 10)).ToBe(True);
  SetDynLength(TempBuffer, TempBuffer.Len - 10); // remove some bytes at the end, to make the decoder report an incomplete buffer

  MQTT_PutReceivedBufferToMQTTLib(0, TempBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTTDecoderIncompleteBuffer, 'Expecting an incomplete buffer.');

  MQTT_PutReceivedBufferToMQTTLib(0, RemainingBuffer);
  Expect(MQTT_Process(0)).ToBe(CMQTT_Success, 'Expecting a full buffer.');

  Expect(DecodedConnAckFields.EnabledProperties).ToBe($1FFFF);
  Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
  Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);

  VerifyProperties(0);
  FreeDynArray(TempBuffer);
  FreeDynArray(RemainingBuffer);
end;


initialization

  RegisterTest(TTestProtocolConnAckCase);

end.

