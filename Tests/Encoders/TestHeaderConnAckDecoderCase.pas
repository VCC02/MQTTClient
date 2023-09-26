{
    Copyright (C) 2023 VCC
    creation date: 03 May 2023
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


unit TestHeaderConnAckDecoderCase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils;

type

  THeaderConnAckDecoderCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure HappyFlowContent(ASessionPresent, AExpectedHeaderLen: Byte);
  published
    procedure Test_FillIn_ConnAck_Decoder_HappyFlow_WithSession;
    procedure Test_FillIn_ConnAck_Decoder_HappyFlow_NoSession;
    procedure Test_FillIn_ConnAck_Decoder_HappyFlow_LongStrings;
    procedure Test_FillIn_ConnAck_Decoder_ErrResponse;

    procedure Test_FillIn_ConnAck_Decoder_EmptyBuffer;
    procedure Test_FillIn_ConnAck_Decoder_BadVarInt;
    procedure Test_FillIn_ConnAck_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_ConnAck_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_ConnAck_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_ConnAck_Decoder_OverfilledBuffer;    //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_ConnAck_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_ConnAck_AllProperties;
    procedure Test_FillIn_ConnAck_Decoder_UnknownProperty;
    procedure Test_FillIn_ConnAck_Decoder_NoProperties;
  end;


implementation


uses
  DynArrays, Expectations,
  MQTTConnAckCtrl, MQTTTestUtils;

var
  DestPacket: TMQTTControlPacket;
  ConnAckProperties: TMQTTConnAckProperties;
  EncodedConnAckBuffer: TDynArrayOfByte;
  DecodedConnAckPacket: TMQTTControlPacket;
  TempConnAckFields: TMQTTConnAckFields;
  DecodedBufferLen: DWord;


procedure THeaderConnAckDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedConnAckBuffer);
  MQTT_InitControlPacket(DecodedConnAckPacket);

  MQTT_InitConnAckProperties(ConnAckProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderConnAckDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedConnAckBuffer);
  MQTT_FreeControlPacket(DecodedConnAckPacket);

  MQTT_FreeConnAckProperties(ConnAckProperties);
end;


procedure THeaderConnAckDecoderCase.HappyFlowContent(ASessionPresent, AExpectedHeaderLen: Byte);
const
  CReasonCode = 0; //0 = no err
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := ASessionPresent;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedConnAckPacket.Header.Content^[0]).ToBe(CMQTT_CONNACK);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedConnAckPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedConnAckPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedConnAckPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedConnAckPacket.Header.Content^[0]).ToBe(CMQTT_CONNACK);
  Expect(DecodedConnAckPacket.VarHeader.Content^[0]).ToBe(ASessionPresent);
  Expect(DecodedConnAckPacket.VarHeader.Content^[1]).ToBe(CReasonCode);
  Expect(DecodedConnAckPacket.VarHeader.Len).ToBeGreaterThan(2);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedConnAckPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedConnAckPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(DestPacket.Payload.Content).ToBe(nil, 'No Payload.Content');
  Expect(DecodedConnAckPacket.Payload.Content).ToBe(nil, 'No Payload.Content');
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_HappyFlow_WithSession;
const
  CSessionPresent = 1;
begin
  HappyFlowContent(CSessionPresent, 2);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_HappyFlow_NoSession;
const
  CSessionPresent = 0;
begin
  HappyFlowContent(CSessionPresent, 2);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_HappyFlow_LongStrings;
const
  CSessionPresent = 0;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnAckProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnAckProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnAckProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnAckProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', ConnAckProperties.UserProperty)).ToBe(True);

  HappyFlowContent(CSessionPresent, 3);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_ErrResponse;
const
  CSessionPresent = 1;
  CReasonCode = 128; //128 = Unspecified error  - can be anything >= 128
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := CReasonCode;
  TempConnAckFields.SessionPresentFlag := CSessionPresent;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CReasonCode shl 8 + CMQTTDecoderServerErr);
  Expect(DecodedConnAckPacket.Header.Content^[0]).ToBe(CMQTT_CONNACK);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(2);
  Expect(DecodedConnAckPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedConnAckPacket.VarHeader.Len).ToBe(2, 'VarHeader len mismatch');    //the VarHeader has only the two main bytes in case of server error
  Expect(DecodedConnAckPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedConnAckPacket.Header.Content^[0]).ToBe(CMQTT_CONNACK);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedConnAckPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, 2).ToBe(@DecodedConnAckPacket.VarHeader.Content^, 'Reduced VarHeader.Content');  //the VarHeader has only the two main bytes in case of server error
  Expect(DestPacket.Payload.Content).ToBe(nil, 'No Payload.Content');
  Expect(DecodedConnAckPacket.Payload.Content).ToBe(nil, 'No Payload.Content');
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_EmptyBuffer;
begin
  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedConnAckBuffer, 5)).ToBe(True);

  EncodedConnAckBuffer.Content^[0] := CMQTT_CONNACK;
  FillChar(EncodedConnAckBuffer.Content^[1], 4, $FF);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := 1;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  EncodedConnAckBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_BadHeaderSizeInVarHeader;
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := 1;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  EncodedConnAckBuffer.Content^[4] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_IncompleteBuffer;
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := 1;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len + 1);
end;


//procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_OverfilledBuffer; //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
//  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
//  TempConnAckFields.SessionPresentFlag := 1;
//
//  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);
//
//  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(DWord(EncodedConnAckBuffer.Len - 1));
//end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_BufferWithExtraPackets;
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := 1;

  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);
  SetDynLength(EncodedConnAckBuffer, EncodedConnAckBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedConnAckBuffer.Len - 50));
end;


procedure THeaderConnAckDecoderCase.Test_Decode_ConnAck_AllProperties;
var
  DecodedConnAckProperties: TMQTTConnAckProperties;
  DecodedConnAckFields: TMQTTConnAckFields;
begin
  TempConnAckFields.EnabledProperties := $1FFFF; //all properties
  TempConnAckFields.ConnectReasonCode := 0; //0 = no err
  TempConnAckFields.SessionPresentFlag := 1;

  Expect(FillIn_ConnAckPropertiesForTest(TempConnAckFields.EnabledProperties, ConnAckProperties)).ToBe(True);
  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);
  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);

  MQTT_InitConnAckProperties(DecodedConnAckProperties);
  try
    Expect(Decode_ConnAck({DestPacket} DecodedConnAckPacket, DecodedConnAckFields, DecodedConnAckProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedConnAckFields.SessionPresentFlag).ToBe(1);
    Expect(DecodedConnAckFields.ConnectReasonCode).ToBe(0);
    Expect(DecodedConnAckFields.EnabledProperties).ToBe(TempConnAckFields.EnabledProperties);

    Expect(DecodedConnAckProperties.AssignedClientIdentifier.Len).ToBe(32);
    Expect(DecodedConnAckProperties.ReasonString.Len).ToBe(13);
    Expect(DecodedConnAckProperties.UserProperty.Len).ToBe(3);
    Expect(DecodedConnAckProperties.ResponseInformation.Len).ToBe(11);
    Expect(DecodedConnAckProperties.ServerReference.Len).ToBe(24);
    Expect(DecodedConnAckProperties.AuthenticationMethod.Len).ToBe(26);
    Expect(DecodedConnAckProperties.AuthenticationData.Len).ToBe(3);
    //
    Expect(@DecodedConnAckProperties.AssignedClientIdentifier.Content^, 32).ToBe(@['Client name, assigned by server.']);
    Expect(@DecodedConnAckProperties.ReasonString.Content^, 13).ToBe(@['for no reason']);
    Expect(@DecodedConnAckProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedConnAckProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedConnAckProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
    Expect(@DecodedConnAckProperties.ResponseInformation.Content^, 11).ToBe(@['no new info']);
    Expect(@DecodedConnAckProperties.ServerReference.Content^, 24).ToBe(@['address_of_backup_server']);
    Expect(@DecodedConnAckProperties.AuthenticationMethod.Content^, 26).ToBe(@['some authentication method']);
    Expect(@DecodedConnAckProperties.AuthenticationData.Content^, 3).ToBe(@[70, 80, 90]);
  finally
    MQTT_FreeConnAckProperties(DecodedConnAckProperties);
  end;
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_UnknownProperty;
var
  DecodedConnAckProperties: TMQTTConnAckProperties;
  DecodedConnAckFields: TMQTTConnAckFields;
begin
  TempConnAckFields.EnabledProperties := CMQTTUnknownPropertyDoubleWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);

  MQTT_InitConnAckProperties(DecodedConnAckProperties);
  try
    Expect(Decode_ConnAck({DestPacket} DecodedConnAckPacket, DecodedConnAckFields, DecodedConnAckProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedConnAckFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeConnAckProperties(DecodedConnAckProperties);
  end;
end;


procedure THeaderConnAckDecoderCase.Test_FillIn_ConnAck_Decoder_NoProperties;
var
  DecodedConnAckProperties: TMQTTConnAckProperties;
  DecodedConnAckFields: TMQTTConnAckFields;
begin
  TempConnAckFields.EnabledProperties := 0;
  Expect(FillIn_ConnAck(TempConnAckFields, ConnAckProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnAckBuffer);

  Expect(Decode_ConnAckToCtrlPacket(EncodedConnAckBuffer, DecodedConnAckPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnAckBuffer.Len);

  MQTT_InitConnAckProperties(DecodedConnAckProperties);
  try
    Expect(Decode_ConnAck({DestPacket} DecodedConnAckPacket, DecodedConnAckFields, DecodedConnAckProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedConnAckFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeConnAckProperties(DecodedConnAckProperties);
  end;
end;


initialization

  RegisterTest(THeaderConnAckDecoderCase);
end.

