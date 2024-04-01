{
    Copyright (C) 2023 VCC
    creation date: 26 May 2023
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


unit TestHeaderUnsubscribeDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, DynArrays;

type

  THeaderUnsubscribeDecoderCase = class(TTestCase)
  private
    DestPacket: TMQTTControlPacket;
    UnsubscribeProperties: TMQTTUnsubscribeProperties;
    EncodedUnsubscribeBuffer: TDynArrayOfByte;
    DecodedUnsubscribePacket: TMQTTControlPacket;
    TempUnsubscribeFields: TMQTTUnsubscribeFields;

    DecodedTopicFilters: TDynArrayOfTDynArrayOfByte;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
  published
    procedure Test_FillIn_Unsubscribe_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_Unsubscribe_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_Unsubscribe_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Unsubscribe_Decoder_EmptyBuffer;
    procedure Test_FillIn_Unsubscribe_Decoder_BadVarInt;
    procedure Test_FillIn_Unsubscribe_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Unsubscribe_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Unsubscribe_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Unsubscribe_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Unsubscribe_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Unsubscribe_AllProperties;
    procedure Test_FillIn_Unsubscribe_Decoder_UnknownProperty;
    procedure Test_FillIn_Unsubscribe_Decoder_NoProperties;
  end;

implementation


uses
  Expectations,
  MQTTUnsubscribeCtrl, MQTTTestUtils;

var
  DecodedBufferLen: DWord;


procedure THeaderUnsubscribeDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedUnsubscribeBuffer);
  MQTT_InitControlPacket(DecodedUnsubscribePacket);
  InitDynArrayToEmpty(TempUnsubscribeFields.TopicFilters);

  InitDynOfDynOfByteToEmpty(DecodedTopicFilters);

  MQTT_InitUnsubscribeProperties(UnsubscribeProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderUnsubscribeDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedUnsubscribeBuffer);
  MQTT_FreeControlPacket(DecodedUnsubscribePacket);
  FreeDynArray(TempUnsubscribeFields.TopicFilters);

  FreeDynOfDynOfByteArray(DecodedTopicFilters);

  MQTT_FreeUnsubscribeProperties(UnsubscribeProperties);
end;


procedure THeaderUnsubscribeDecoderCase.HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
begin
  TempUnsubscribeFields.PacketIdentifier := $4730;
  TempUnsubscribeFields.EnabledProperties := $FF * (APropertiesPresent and 1); //all properties
  Expect(FillIn_UnsubscribePayload('some simple payload entry', TempUnsubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_UnsubscribePayload('another payload entry', TempUnsubscribeFields.TopicFilters)).ToBe(True);

  Expect(AddStringToDynOfDynArrayOfByte('Some content for user property.', UnsubscribeProperties.UserProperty)).ToBe(True);

  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedUnsubscribePacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedUnsubscribePacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedUnsubscribePacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedUnsubscribePacket.Header.Content^[0]).ToBe(CMQTT_UNSUBSCRIBE or 2);
  Expect(DecodedUnsubscribePacket.VarHeader.Content^[0]).ToBe($47);
  Expect(DecodedUnsubscribePacket.VarHeader.Content^[1]).ToBe($30);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedUnsubscribePacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedUnsubscribePacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedUnsubscribePacket.Payload.Content^, 'Payload.Content');

  Expect(Decode_UnsubscribePayload(DecodedUnsubscribePacket.Payload, DecodedTopicFilters)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedTopicFilters.Len).ToBe(2);

  Expect(@DecodedTopicFilters.Content^[0]^.Content^, 25).ToBe(@['some simple payload entry']);
  Expect(@DecodedTopicFilters.Content^[1]^.Content^, 21).ToBe(@['another payload entry']);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_HappyFlow_WithProperties;
const
  CPropertiesPresent = 1;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_HappyFlow_NoProperties;
const
  CPropertiesPresent = 0;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_HappyFlow_LongStrings;
const
  CPropertiesPresent = 1;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', UnsubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', UnsubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', UnsubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', UnsubscribeProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', UnsubscribeProperties.UserProperty)).ToBe(True);

  HappyFlowContent(CPropertiesPresent, 3);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_EmptyBuffer;
begin
  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedUnsubscribeBuffer, 5)).ToBe(True);

  EncodedUnsubscribeBuffer.Content^[0] := CMQTT_UNSUBSCRIBE or 2;
  FillChar(EncodedUnsubscribeBuffer.Content^[1], 4, $FF);

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempUnsubscribeFields.EnabledProperties := $FF; //all properties
  TempUnsubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  EncodedUnsubscribeBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_BadHeaderSizeInVarHeader;
begin
  TempUnsubscribeFields.EnabledProperties := $FF; //all properties
  TempUnsubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  EncodedUnsubscribeBuffer.Content^[4] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_IncompleteBuffer;
begin
  TempUnsubscribeFields.EnabledProperties := $FF; //all properties
  TempUnsubscribeFields.PacketIdentifier := 1234;

  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len + 1);
end;


//procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempUnsubscribeFields.EnabledProperties := $FF; //all properties
//  TempUnsubscribeFields.PacketIdentifier := 1234;
//
//  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);
//
//  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len + 1);
//end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_BufferWithExtraPackets;
begin
  TempUnsubscribeFields.EnabledProperties := $FF; //all properties
  TempUnsubscribeFields.PacketIdentifier := 1234;
  Expect(FillIn_UnsubscribePayload('some payload..', TempUnsubscribeFields.TopicFilters)).ToBe(True);

  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);
  SetDynLength(EncodedUnsubscribeBuffer, EncodedUnsubscribeBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedUnsubscribeBuffer.Len - 50));
end;


procedure THeaderUnsubscribeDecoderCase.Test_Decode_Unsubscribe_AllProperties;
var
  DecodedUnsubscribeProperties: TMQTTUnsubscribeProperties;
  DecodedUnsubscribeFields: TMQTTUnsubscribeFields;
begin
  TempUnsubscribeFields.EnabledProperties := $1; //all properties
  TempUnsubscribeFields.PacketIdentifier := 1234;
  Expect(FillIn_UnsubscribePayload('some payload..', TempUnsubscribeFields.TopicFilters)).ToBe(True);

  Expect(FillIn_UnsubscribePropertiesForTest(TempUnsubscribeFields.EnabledProperties, UnsubscribeProperties)).ToBe(True);
  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);
  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);

  MQTT_InitUnsubscribeProperties(DecodedUnsubscribeProperties);
  try
    InitDynArrayToEmpty(DecodedUnsubscribeFields.TopicFilters);
    try
      Expect(Decode_Unsubscribe({DestPacket} DecodedUnsubscribePacket, DecodedUnsubscribeFields, DecodedUnsubscribeProperties)).ToBe(CMQTTDecoderNoErr);

      Expect(DecodedUnsubscribeFields.PacketIdentifier).ToBe(1234);
      Expect(DecodedUnsubscribeFields.EnabledProperties).ToBe(TempUnsubscribeFields.EnabledProperties);
    finally
      FreeDynArray(DecodedUnsubscribeFields.TopicFilters);
    end;

    Expect(DecodedUnsubscribeProperties.UserProperty.Len).ToBe(3);
    //
    Expect(@DecodedUnsubscribeProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedUnsubscribeProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedUnsubscribeProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
  finally
    MQTT_FreeUnsubscribeProperties(DecodedUnsubscribeProperties);
  end;
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_UnknownProperty;
var
  DecodedUnsubscribeProperties: TMQTTUnsubscribeProperties;
  DecodedUnsubscribeFields: TMQTTUnsubscribeFields;
begin
  TempUnsubscribeFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_UnsubscribePayload('some payload..', TempUnsubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);

  MQTT_InitUnsubscribeProperties(DecodedUnsubscribeProperties);
  try
    Expect(Decode_Unsubscribe({DestPacket} DecodedUnsubscribePacket, DecodedUnsubscribeFields, DecodedUnsubscribeProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedUnsubscribeFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeUnsubscribeProperties(DecodedUnsubscribeProperties);
  end;
end;


procedure THeaderUnsubscribeDecoderCase.Test_FillIn_Unsubscribe_Decoder_NoProperties;
var
  DecodedUnsubscribeProperties: TMQTTUnsubscribeProperties;
  DecodedUnsubscribeFields: TMQTTUnsubscribeFields;
begin
  TempUnsubscribeFields.EnabledProperties := 0;
  Expect(FillIn_UnsubscribePayload('some payload..', TempUnsubscribeFields.TopicFilters)).ToBe(True);
  Expect(FillIn_Unsubscribe(TempUnsubscribeFields, UnsubscribeProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedUnsubscribeBuffer);

  Expect(Decode_UnsubscribeToCtrlPacket(EncodedUnsubscribeBuffer, DecodedUnsubscribePacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedUnsubscribeBuffer.Len);

  MQTT_InitUnsubscribeProperties(DecodedUnsubscribeProperties);
  InitDynArrayToEmpty(DecodedUnsubscribeFields.TopicFilters);
  try
    Expect(Decode_Unsubscribe({DestPacket} DecodedUnsubscribePacket, DecodedUnsubscribeFields, DecodedUnsubscribeProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedUnsubscribeFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeUnsubscribeProperties(DecodedUnsubscribeProperties);
    FreeDynArray(DecodedUnsubscribeFields.TopicFilters);
  end;
end;


initialization

  RegisterTest(THeaderUnsubscribeDecoderCase);
end.

