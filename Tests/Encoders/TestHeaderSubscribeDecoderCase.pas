{
    Copyright (C) 2023 VCC
    creation date: 23 May 2023
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


unit TestHeaderSubscribeDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, DynArrays;

type

  THeaderSubscribeDecoderCase = class(TTestCase)
  private
    DestPacket: TMQTTControlPacket;
    SubscribeProperties: TMQTTSubscribeProperties;
    EncodedSubscribeBuffer: TDynArrayOfByte;
    DecodedSubscribePacket: TMQTTControlPacket;
    TempSubscribeFields: TMQTTSubscribeFields;

    DecodedTopicFilters: TDynArrayOfTDynArrayOfByte;
    DecodedSubscriptionOptions: TDynArrayOfByte;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
  published
    procedure Test_FillIn_Subscribe_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_Subscribe_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_Subscribe_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Subscribe_Decoder_EmptyBuffer;
    procedure Test_FillIn_Subscribe_Decoder_BadVarInt;
    procedure Test_FillIn_Subscribe_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Subscribe_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Subscribe_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Subscribe_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Subscribe_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Subscribe_AllProperties;
    procedure Test_FillIn_Subscribe_Decoder_UnknownProperty;
    procedure Test_FillIn_Subscribe_Decoder_NoProperties;
  end;

implementation


uses
  Expectations,
  MQTTSubscribeCtrl, MQTTTestUtils;

var
  DecodedBufferLen: DWord;


procedure THeaderSubscribeDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedSubscribeBuffer);
  MQTT_InitControlPacket(DecodedSubscribePacket);
  InitDynArrayToEmpty(TempSubscribeFields.TopicFilters);

  InitDynOfDynOfByteToEmpty(DecodedTopicFilters);
  InitDynArrayToEmpty(DecodedSubscriptionOptions);

  MQTT_InitSubscribeProperties(SubscribeProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderSubscribeDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedSubscribeBuffer);
  MQTT_FreeControlPacket(DecodedSubscribePacket);
  FreeDynArray(TempSubscribeFields.TopicFilters);

  FreeDynOfDynOfByteArray(DecodedTopicFilters);
  FreeDynArray(DecodedSubscriptionOptions);

  MQTT_FreeSubscribeProperties(SubscribeProperties);
end;


procedure THeaderSubscribeDecoderCase.HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
begin
  TempSubscribeFields.PacketIdentifier := $4730;
  TempSubscribeFields.EnabledProperties := $FF * (APropertiesPresent and 1); //all properties
  Expect(FillIn_SubscribePayload('some simple payload entry', 73, TempSubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_SubscribePayload('another payload entry', 85, TempSubscribeFields.TopicFilters)).ToBe(True);

  Expect(AddDWordToDynArraysOfDWord(SubscribeProperties.SubscriptionIdentifier, 1234)).ToBe(True);
  Expect(AddDWordToDynArraysOfDWord(SubscribeProperties.SubscriptionIdentifier, 5678)).ToBe(True);
  Expect(AddDWordToDynArraysOfDWord(SubscribeProperties.SubscriptionIdentifier, 9876)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Some content for user property.', SubscribeProperties.UserProperty)).ToBe(True);

  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedSubscribePacket.Header.Content^[0]).ToBe(CMQTT_SUBSCRIBE);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedSubscribePacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedSubscribePacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedSubscribePacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedSubscribePacket.Header.Content^[0]).ToBe(CMQTT_SUBSCRIBE);
  Expect(DecodedSubscribePacket.VarHeader.Content^[0]).ToBe($47);
  Expect(DecodedSubscribePacket.VarHeader.Content^[1]).ToBe($30);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedSubscribePacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedSubscribePacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedSubscribePacket.Payload.Content^, 'Payload.Content');

  Expect(Decode_SubscribePayload(DecodedSubscribePacket.Payload, DecodedTopicFilters, DecodedSubscriptionOptions)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedTopicFilters.Len).ToBe(2);
  Expect(DecodedSubscriptionOptions.Len).ToBe(2);

  Expect(@DecodedTopicFilters.Content^[0]^.Content^, 25).ToBe(@['some simple payload entry']);
  Expect(@DecodedTopicFilters.Content^[1]^.Content^, 21).ToBe(@['another payload entry']);
  Expect(DecodedSubscriptionOptions.Content^[0]).ToBe(73);
  Expect(DecodedSubscriptionOptions.Content^[1]).ToBe(85);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_HappyFlow_WithProperties;
const
  CPropertiesPresent = 1;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_HappyFlow_NoProperties;
const
  CPropertiesPresent = 0;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_HappyFlow_LongStrings;
const
  CPropertiesPresent = 1;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', SubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', SubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', SubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', SubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', SubscribeProperties.UserProperty)).ToBe(True);

  HappyFlowContent(CPropertiesPresent, 3);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_EmptyBuffer;
begin
  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedSubscribeBuffer, 5)).ToBe(True);

  EncodedSubscribeBuffer.Content^[0] := CMQTT_SUBSCRIBE;
  FillChar(EncodedSubscribeBuffer.Content^[1], 4, $FF);

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempSubscribeFields.EnabledProperties := $FF; //all properties
  TempSubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  EncodedSubscribeBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_BadHeaderSizeInVarHeader;
begin
  TempSubscribeFields.EnabledProperties := $FF; //all properties
  TempSubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  EncodedSubscribeBuffer.Content^[4] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_IncompleteBuffer;
begin
  TempSubscribeFields.EnabledProperties := $FF; //all properties
  TempSubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len + 1);
end;


//procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempSubscribeFields.EnabledProperties := $FF; //all properties
//  TempSubscribeFields.PacketIdentifier := 1234;
//
//  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);
//
//  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len + 1);
//end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_BufferWithExtraPackets;
begin
  TempSubscribeFields.EnabledProperties := $FF; //all properties
  TempSubscribeFields.PacketIdentifier := 1234;
  Expect(FillIn_SubscribePayload('some payload..', 90, TempSubscribeFields.TopicFilters)).ToBe(True);

  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);
  SetDynLength(EncodedSubscribeBuffer, EncodedSubscribeBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedSubscribeBuffer.Len - 50));
end;


procedure THeaderSubscribeDecoderCase.Test_Decode_Subscribe_AllProperties;
var
  DecodedSubscribeProperties: TMQTTSubscribeProperties;
  DecodedSubscribeFields: TMQTTSubscribeFields;
begin
  TempSubscribeFields.EnabledProperties := $3; //all properties
  TempSubscribeFields.PacketIdentifier := 1234;
  Expect(FillIn_SubscribePayload('some payload..', 90, TempSubscribeFields.TopicFilters)).ToBe(True);

  Expect(FillIn_SubscribePropertiesForTest(TempSubscribeFields.EnabledProperties, SubscribeProperties)).ToBe(True);
  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);
  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);

  MQTT_InitSubscribeProperties(DecodedSubscribeProperties);
  try
    Expect(Decode_Subscribe({DestPacket} DecodedSubscribePacket, DecodedSubscribeFields, DecodedSubscribeProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedSubscribeFields.PacketIdentifier).ToBe(1234);
    Expect(DecodedSubscribeFields.EnabledProperties).ToBe(TempSubscribeFields.EnabledProperties);

    Expect(DecodedSubscribeProperties.SubscriptionIdentifier.Len).ToBe(1);
    Expect(DecodedSubscribeProperties.UserProperty.Len).ToBe(3);
    //
    Expect(DecodedSubscribeProperties.SubscriptionIdentifier.Content^[0]).ToBe(DWord($08ABCDEF));
    Expect(@DecodedSubscribeProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedSubscribeProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedSubscribeProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
  finally
    MQTT_FreeSubscribeProperties(DecodedSubscribeProperties);
  end;
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_UnknownProperty;
var
  DecodedSubscribeProperties: TMQTTSubscribeProperties;
  DecodedSubscribeFields: TMQTTSubscribeFields;
begin
  TempSubscribeFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_SubscribePayload('some payload..', 90, TempSubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);

  MQTT_InitSubscribeProperties(DecodedSubscribeProperties);
  try
    Expect(Decode_Subscribe({DestPacket} DecodedSubscribePacket, DecodedSubscribeFields, DecodedSubscribeProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedSubscribeFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeSubscribeProperties(DecodedSubscribeProperties);
  end;
end;


procedure THeaderSubscribeDecoderCase.Test_FillIn_Subscribe_Decoder_NoProperties;
var
  DecodedSubscribeProperties: TMQTTSubscribeProperties;
  DecodedSubscribeFields: TMQTTSubscribeFields;
begin
  TempSubscribeFields.EnabledProperties := 0;
  Expect(FillIn_SubscribePayload('some payload..', 90, TempSubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_Subscribe(TempSubscribeFields, SubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedSubscribeBuffer);

  Expect(Decode_SubscribeToCtrlPacket(EncodedSubscribeBuffer, DecodedSubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedSubscribeBuffer.Len);

  MQTT_InitSubscribeProperties(DecodedSubscribeProperties);
  try
    Expect(Decode_Subscribe({DestPacket} DecodedSubscribePacket, DecodedSubscribeFields, DecodedSubscribeProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedSubscribeFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeSubscribeProperties(DecodedSubscribeProperties);
  end;
end;


initialization

  RegisterTest(THeaderSubscribeDecoderCase);
end.

