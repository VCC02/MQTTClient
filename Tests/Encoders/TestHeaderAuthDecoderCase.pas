{
    Copyright (C) 2023 VCC
    creation date: 29 May 2023
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


unit TestHeaderAuthDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, DynArrays;

type

  THeaderAuthDecoderCase = class(TTestCase)
  private
    DestPacket: TMQTTControlPacket;
    AuthProperties: TMQTTAuthProperties;
    EncodedAuthBuffer: TDynArrayOfByte;
    DecodedAuthPacket: TMQTTControlPacket;
    TempAuthFields: TMQTTAuthFields;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
  published
    procedure Test_FillIn_Auth_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_Auth_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_Auth_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Auth_Decoder_EmptyBuffer;
    procedure Test_FillIn_Auth_Decoder_BadVarInt;
    //procedure Test_FillIn_Auth_Decoder_BadHeaderSizeInFixedHeader;    //auth allows 0-len VarHeader
    procedure Test_FillIn_Auth_Decoder_BadHeaderContentInFixedHeader;
    procedure Test_FillIn_Auth_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Auth_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Auth_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Auth_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Auth_AllProperties;
    procedure Test_FillIn_Auth_Decoder_UnknownProperty;
    procedure Test_FillIn_Auth_Decoder_NoProperties_NoReasonCode;
  end;

implementation


uses
  Expectations,
  MQTTAuthCtrl, MQTTTestUtils;

var
  DecodedBufferLen: DWord;


procedure THeaderAuthDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedAuthBuffer);
  MQTT_InitControlPacket(DecodedAuthPacket);

  MQTT_InitAuthProperties(AuthProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderAuthDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedAuthBuffer);
  MQTT_FreeControlPacket(DecodedAuthPacket);

  MQTT_FreeAuthProperties(AuthProperties);
end;


procedure THeaderAuthDecoderCase.HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
begin
  TempAuthFields.AuthReasonCode := $47;
  TempAuthFields.EnabledProperties := $FF * (APropertiesPresent and 1); //all properties

  StringToDynArrayOfByte('abc', AuthProperties.ReasonString);
  StringToDynArrayOfByte('auth data', AuthProperties.AuthenticationData);
  StringToDynArrayOfByte('auth method', AuthProperties.AuthenticationMethod);
  Expect(AddStringToDynOfDynArrayOfByte('Some content for user property.', AuthProperties.UserProperty)).ToBe(True);

  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedAuthPacket.Header.Content^[0]).ToBe(CMQTT_Auth);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedAuthPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedAuthPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedAuthPacket.Payload.Len).ToBe(0, 'no Payload');

  Expect(DecodedAuthPacket.Header.Content^[0]).ToBe(CMQTT_Auth);
  Expect(DecodedAuthPacket.VarHeader.Content^[0]).ToBe($47);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedAuthPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedAuthPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(Pointer(DestPacket.Payload.Content)).ToBe(Pointer(nil), 'no Payload.Content');
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_HappyFlow_WithProperties;
const
  CPropertiesPresent = 1;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_HappyFlow_NoProperties;
const
  CPropertiesPresent = 0;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_HappyFlow_LongStrings;
const
  CPropertiesPresent = 1;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', AuthProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', AuthProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', AuthProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', AuthProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', AuthProperties.UserProperty)).ToBe(True);

  HappyFlowContent(CPropertiesPresent, 3);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_EmptyBuffer;
begin
  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedAuthBuffer, 5)).ToBe(True);

  EncodedAuthBuffer.Content^[0] := CMQTT_Auth;
  FillChar(EncodedAuthBuffer.Content^[1], 4, $FF);

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_BadHeaderContentInFixedHeader;
begin
  TempAuthFields.EnabledProperties := $FF; //all properties
  TempAuthFields.AuthReasonCode := 37;

  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  EncodedAuthBuffer.Content^[0] := CMQTT_AUTH or 5; //corrupting the first byte should result in an specific Auth error

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadCtrlPacket);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_BadHeaderSizeInVarHeader;
begin
  TempAuthFields.EnabledProperties := $FF; //all properties
  TempAuthFields.AuthReasonCode := 37;

  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  EncodedAuthBuffer.Content^[3] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_IncompleteBuffer;
begin
  TempAuthFields.EnabledProperties := $FF; //all properties
  TempAuthFields.AuthReasonCode := 37;

  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len + 1);
end;


//procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempAuthFields.EnabledProperties := $FF; //all properties
//  TempAuthFields.AuthReasonCode := 37;
//
//  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);
//
//  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len + 1);
//end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_BufferWithExtraPackets;
begin
  TempAuthFields.EnabledProperties := $FF; //all properties
  TempAuthFields.AuthReasonCode := 37;

  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);
  SetDynLength(EncodedAuthBuffer, EncodedAuthBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedAuthBuffer.Len - 50));
end;


procedure THeaderAuthDecoderCase.Test_Decode_Auth_AllProperties;
var
  DecodedAuthProperties: TMQTTAuthProperties;
  DecodedAuthFields: TMQTTAuthFields;
begin
  TempAuthFields.EnabledProperties := $F; //all properties
  TempAuthFields.AuthReasonCode := 47;

  Expect(FillIn_AuthPropertiesForTest(TempAuthFields.EnabledProperties, AuthProperties)).ToBe(True);
  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);
  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);

  MQTT_InitAuthProperties(DecodedAuthProperties);
  try
    Expect(Decode_Auth({DestPacket} DecodedAuthPacket, DecodedAuthFields, DecodedAuthProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedAuthFields.AuthReasonCode).ToBe(47);
    Expect(DecodedAuthFields.EnabledProperties).ToBe(TempAuthFields.EnabledProperties);

    Expect(DecodedAuthProperties.ReasonString.Len).ToBe(13);
    Expect(DecodedAuthProperties.UserProperty.Len).ToBe(3);
    Expect(DecodedAuthProperties.AuthenticationMethod.Len).ToBe(11);
    Expect(DecodedAuthProperties.AuthenticationData.Len).ToBe(10);
    //
    Expect(@DecodedAuthProperties.ReasonString.Content^[0], 13).ToBe(@['for no reason']);
    Expect(@DecodedAuthProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedAuthProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedAuthProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
    Expect(@DecodedAuthProperties.AuthenticationMethod.Content^[0], 11).ToBe(@['some method']);
    Expect(@DecodedAuthProperties.AuthenticationData.Content^[0], 10).ToBe(@['some data.']);
  finally
    MQTT_FreeAuthProperties(DecodedAuthProperties);
  end;
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_UnknownProperty;
var
  DecodedAuthProperties: TMQTTAuthProperties;
  DecodedAuthFields: TMQTTAuthFields;
begin
  TempAuthFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  TempAuthFields.AuthReasonCode := 7;
  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);

  MQTT_InitAuthProperties(DecodedAuthProperties);
  try
    Expect(Decode_Auth({DestPacket} DecodedAuthPacket, DecodedAuthFields, DecodedAuthProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedAuthFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeAuthProperties(DecodedAuthProperties);
  end;
end;


procedure THeaderAuthDecoderCase.Test_FillIn_Auth_Decoder_NoProperties_NoReasonCode;
var
  DecodedAuthProperties: TMQTTAuthProperties;
  DecodedAuthFields: TMQTTAuthFields;
begin
  TempAuthFields.EnabledProperties := 0;
  TempAuthFields.AuthReasonCode := 0;
  Expect(FillIn_Auth(TempAuthFields, AuthProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedAuthBuffer);

  Expect(Decode_AuthToCtrlPacket(EncodedAuthBuffer, DecodedAuthPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedAuthBuffer.Len);

  MQTT_InitAuthProperties(DecodedAuthProperties);
  try
    Expect(Decode_Auth({DestPacket} DecodedAuthPacket, DecodedAuthFields, DecodedAuthProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedAuthFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeAuthProperties(DecodedAuthProperties);
  end;
end;


initialization

  RegisterTest(THeaderAuthDecoderCase);
end.



