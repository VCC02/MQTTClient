{
    Copyright (C) 2023 VCC
    creation date: 27 May 2023
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


unit TestHeaderDisconnectDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, DynArrays;

type

  THeaderDisconnectDecoderCase = class(TTestCase)
  private
    DestPacket: TMQTTControlPacket;
    DisconnectProperties: TMQTTDisconnectProperties;
    EncodedDisconnectBuffer: TDynArrayOfByte;
    DecodedDisconnectPacket: TMQTTControlPacket;
    TempDisconnectFields: TMQTTDisconnectFields;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
  published
    procedure Test_FillIn_Disconnect_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_Disconnect_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_Disconnect_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Disconnect_Decoder_EmptyBuffer;
    procedure Test_FillIn_Disconnect_Decoder_BadVarInt;
    procedure Test_FillIn_Disconnect_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Disconnect_Decoder_BadHeaderContentInFixedHeader;
    procedure Test_FillIn_Disconnect_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Disconnect_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Disconnect_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Disconnect_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Disconnect_AllProperties;
    procedure Test_FillIn_Disconnect_Decoder_UnknownProperty;
    procedure Test_FillIn_Disconnect_Decoder_NoProperties;
  end;

implementation


uses
  Expectations,
  MQTTDisconnectCtrl, MQTTTestUtils;

var
  DecodedBufferLen: DWord;


procedure THeaderDisconnectDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedDisconnectBuffer);
  MQTT_InitControlPacket(DecodedDisconnectPacket);

  MQTT_InitDisconnectProperties(DisconnectProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderDisconnectDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedDisconnectBuffer);
  MQTT_FreeControlPacket(DecodedDisconnectPacket);

  MQTT_FreeDisconnectProperties(DisconnectProperties);
end;


procedure THeaderDisconnectDecoderCase.HappyFlowContent(APropertiesPresent, AExpectedHeaderLen: Byte);
begin
  TempDisconnectFields.DisconnectReasonCode := $47;
  TempDisconnectFields.EnabledProperties := $FF * (APropertiesPresent and 1); //all properties

  StringToDynArrayOfByte('abc', DisconnectProperties.ReasonString);
  StringToDynArrayOfByte('new server address', DisconnectProperties.ServerReference);
  DisconnectProperties.SessionExpiryInterval := $1234567;
  {$IFDEF EnUserProperty}
    Expect(AddStringToDynOfDynArrayOfByte('Some content for user property.', DisconnectProperties.UserProperty)).ToBe(True);
  {$ENDIF}

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedDisconnectPacket.Header.Content^[0]).ToBe(CMQTT_Disconnect);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedDisconnectPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedDisconnectPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedDisconnectPacket.Payload.Len).ToBe(0, 'no Payload');

  Expect(DecodedDisconnectPacket.Header.Content^[0]).ToBe(CMQTT_Disconnect);
  Expect(DecodedDisconnectPacket.VarHeader.Content^[0]).ToBe($47);

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedDisconnectPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedDisconnectPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(Pointer(DestPacket.Payload.Content)).ToBe(Pointer(nil), 'no Payload.Content');
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_HappyFlow_WithProperties;
const
  CPropertiesPresent = 1;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_HappyFlow_NoProperties;
const
  CPropertiesPresent = 0;
begin
  HappyFlowContent(CPropertiesPresent, 2);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_HappyFlow_LongStrings;
const
  CPropertiesPresent = 1;
begin
  {$IFDEF EnUserProperty}
    Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', DisconnectProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', DisconnectProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', DisconnectProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', DisconnectProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', DisconnectProperties.UserProperty)).ToBe(True);
  {$ENDIF}

  HappyFlowContent(CPropertiesPresent, 3 {$IFnDEF EnUserProperty} -1 {$ENDIF});
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_EmptyBuffer;
begin
  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedDisconnectBuffer, 5)).ToBe(True);

  EncodedDisconnectBuffer.Content^[0] := CMQTT_Disconnect;
  FillChar(EncodedDisconnectBuffer.Content^[1], 4, $FF);

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempDisconnectFields.EnabledProperties := $FF; //all properties
  TempDisconnectFields.DisconnectReasonCode := 37;

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  EncodedDisconnectBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_BadHeaderContentInFixedHeader;
begin
  TempDisconnectFields.EnabledProperties := $FF; //all properties
  TempDisconnectFields.DisconnectReasonCode := 37;

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  EncodedDisconnectBuffer.Content^[0] := CMQTT_DISCONNECT or 5; //corrupting the first byte should result in an specific Disconnect error

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadCtrlPacketOnDisconnect);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_BadHeaderSizeInVarHeader;
begin
  TempDisconnectFields.EnabledProperties := $FF; //all properties
  TempDisconnectFields.DisconnectReasonCode := 37;

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  EncodedDisconnectBuffer.Content^[3] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_IncompleteBuffer;
begin
  TempDisconnectFields.EnabledProperties := $FF; //all properties
  TempDisconnectFields.DisconnectReasonCode := 37;

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len + 1);
end;


//procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempDisconnectFields.EnabledProperties := $FF; //all properties
//  TempDisconnectFields.DisconnectReasonCode := 37;
//
//  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);
//
//  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len + 1);
//end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_BufferWithExtraPackets;
begin
  TempDisconnectFields.EnabledProperties := $FF; //all properties
  TempDisconnectFields.DisconnectReasonCode := 37;

  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);
  SetDynLength(EncodedDisconnectBuffer, EncodedDisconnectBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedDisconnectBuffer.Len - 50));
end;


procedure THeaderDisconnectDecoderCase.Test_Decode_Disconnect_AllProperties;
var
  DecodedDisconnectProperties: TMQTTDisconnectProperties;
  DecodedDisconnectFields: TMQTTDisconnectFields;
begin
  TempDisconnectFields.EnabledProperties := $F {$IFnDEF EnUserProperty} xor CMQTTDisconnect_EnUserProperty {$ENDIF}; //all properties
  TempDisconnectFields.DisconnectReasonCode := 47;

  Expect(FillIn_DisconnectPropertiesForTest(TempDisconnectFields.EnabledProperties, DisconnectProperties)).ToBe(True);
  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);
  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);

  MQTT_InitDisconnectProperties(DecodedDisconnectProperties);
  try
    Expect(Decode_Disconnect({DestPacket} DecodedDisconnectPacket, DecodedDisconnectFields, DecodedDisconnectProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedDisconnectFields.DisconnectReasonCode).ToBe(47);
    Expect(DecodedDisconnectFields.EnabledProperties).ToBe(TempDisconnectFields.EnabledProperties);

    Expect(DecodedDisconnectProperties.ReasonString.Len).ToBe(13);
    {$IFDEF EnUserProperty}
      Expect(DecodedDisconnectProperties.UserProperty.Len).ToBe(3);
    {$ENDIF}
    Expect(DecodedDisconnectProperties.ServerReference.Len).ToBe(10);
    //
    Expect(DecodedDisconnectProperties.SessionExpiryInterval).ToBe(DWord($08ABCDEF));
    Expect(@DecodedDisconnectProperties.ReasonString.Content^[0], 13).ToBe(@['for no reason']);
    {$IFDEF EnUserProperty}
      Expect(@DecodedDisconnectProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
      Expect(@DecodedDisconnectProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
      Expect(@DecodedDisconnectProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
    {$ENDIF}
    Expect(@DecodedDisconnectProperties.ServerReference.Content^[0], 10).ToBe(@['new server']);
  finally
    MQTT_FreeDisconnectProperties(DecodedDisconnectProperties);
  end;
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_UnknownProperty;
var
  DecodedDisconnectProperties: TMQTTDisconnectProperties;
  DecodedDisconnectFields: TMQTTDisconnectFields;
begin
  TempDisconnectFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);

  MQTT_InitDisconnectProperties(DecodedDisconnectProperties);
  try
    Expect(Decode_Disconnect({DestPacket} DecodedDisconnectPacket, DecodedDisconnectFields, DecodedDisconnectProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedDisconnectFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeDisconnectProperties(DecodedDisconnectProperties);
  end;
end;


procedure THeaderDisconnectDecoderCase.Test_FillIn_Disconnect_Decoder_NoProperties;
var
  DecodedDisconnectProperties: TMQTTDisconnectProperties;
  DecodedDisconnectFields: TMQTTDisconnectFields;
begin
  TempDisconnectFields.EnabledProperties := 0;
  Expect(FillIn_Disconnect(TempDisconnectFields, DisconnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedDisconnectBuffer);

  Expect(Decode_DisconnectToCtrlPacket(EncodedDisconnectBuffer, DecodedDisconnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedDisconnectBuffer.Len);

  MQTT_InitDisconnectProperties(DecodedDisconnectProperties);
  try
    Expect(Decode_Disconnect({DestPacket} DecodedDisconnectPacket, DecodedDisconnectFields, DecodedDisconnectProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedDisconnectFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeDisconnectProperties(DecodedDisconnectProperties);
  end;
end;


initialization

  RegisterTest(THeaderDisconnectDecoderCase);
end.


