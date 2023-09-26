{
    Copyright (C) 2023 VCC
    creation date: 22 May 2023
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


unit TestHeaderCommonDecoderCase;

//used for PubAck, PubRec, PubRel and PubComp

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, DynArrays;

type

  THeaderCommonDecoderCase = class(TTestCase)
  private
    FPacketType: Byte;

    DestPacket: TMQTTControlPacket;
    CommonProperties: TMQTTCommonProperties;
    EncodedCommonBuffer: TDynArrayOfByte;
    DecodedCommonPacket: TMQTTControlPacket;
    TempCommonFields: TMQTTCommonFields;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    procedure AddAPayload;
    procedure HappyFlowContent(APropertiesPresent, AExpectedHeaderLen, AExpectedReasonCode: Byte);
  public
    constructor Create; override;

    procedure Test_FillIn_Common_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_Common_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_Common_Decoder_HappyFlow_NoPropertiesNoReasonCode;
    procedure Test_FillIn_Common_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Common_Decoder_EmptyBuffer;
    procedure Test_FillIn_Common_Decoder_BadVarInt;
    procedure Test_FillIn_Common_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Common_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Common_Decoder_IncompleteBuffer;
    procedure Test_FillIn_Common_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Common_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Common_AllProperties;
    procedure Test_FillIn_Common_Decoder_UnknownProperty;
    procedure Test_FillIn_Common_Decoder_NoProperties;

    property PacketType: Byte write FPacketType;
  end;

implementation


uses
  Expectations,
  MQTTCommonCodecCtrl, MQTTTestUtils;

var
  DecodedBufferLen: DWord;


constructor THeaderCommonDecoderCase.Create;
begin
  FPacketType := 0;
end;


procedure THeaderCommonDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedCommonBuffer);
  MQTT_InitControlPacket(DecodedCommonPacket);
  InitDynArrayToEmpty(TempCommonFields.SrcPayload);

  MQTT_InitCommonProperties(CommonProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderCommonDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedCommonBuffer);
  MQTT_FreeControlPacket(DecodedCommonPacket);
  FreeDynArray(TempCommonFields.SrcPayload);

  MQTT_FreeCommonProperties(CommonProperties);
end;


procedure THeaderCommonDecoderCase.AddAPayload;
var
  TempStr: string;
begin
  case FPacketType of
    CMQTT_SUBACK, CMQTT_UNSUBACK:
    begin
      Expect(AddByteToDynArray(243, TempCommonFields.SrcPayload)).ToBe(True);
      Expect(AddByteToDynArray(244, TempCommonFields.SrcPayload)).ToBe(True);
      Expect(AddByteToDynArray(245, TempCommonFields.SrcPayload)).ToBe(True);
      Expect(AddByteToDynArray(246, TempCommonFields.SrcPayload)).ToBe(True);
    end;

    else
    begin
      TempStr := 'some simple payload entry';
      Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempCommonFields.SrcPayload, TempStr)).ToBe(True);  //instead of FillIn_UnsubscribePayload

      TempStr := 'another payload entry';
      Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempCommonFields.SrcPayload, TempStr)).ToBe(True);  //instead of FillIn_UnsubscribePayload

      TempStr := 'one more payload entry';
      Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempCommonFields.SrcPayload, TempStr)).ToBe(True);  //instead of FillIn_UnsubscribePayload

      TempStr := 'the last payload entry';
      Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempCommonFields.SrcPayload, TempStr)).ToBe(True);  //instead of FillIn_UnsubscribePayload
    end;
  end;
end;


procedure THeaderCommonDecoderCase.HappyFlowContent(APropertiesPresent, AExpectedHeaderLen, AExpectedReasonCode: Byte);
begin
  TempCommonFields.PacketIdentifier := $4730; //dec: 71 48
  TempCommonFields.ReasonCode := AExpectedReasonCode;
  TempCommonFields.EnabledProperties := $FF * (APropertiesPresent and 1); //all properties

  AddAPayload;

  Expect(StringToDynArrayOfByte('five/seven/zero', CommonProperties.ReasonString)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Some content for user property.', CommonProperties.UserProperty)).ToBe(True);

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedCommonPacket.Header.Content^[0]).ToBe(FPacketType);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(AExpectedHeaderLen);
  Expect(DecodedCommonPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedCommonPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedCommonPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedCommonPacket.Header.Content^[0]).ToBe(FPacketType);
  Expect(DecodedCommonPacket.VarHeader.Content^[0]).ToBe($47);
  Expect(DecodedCommonPacket.VarHeader.Content^[1]).ToBe($30);

  if not (FPacketType in [CMQTT_SUBACK, CMQTT_UNSUBACK]) then
    if AExpectedReasonCode > 0 then
      Expect(DecodedCommonPacket.VarHeader.Content^[2]).ToBe(AExpectedReasonCode);

  if APropertiesPresent and 1 = 1 then
  begin
    if AExpectedReasonCode > 0 then
      Expect(DecodedCommonPacket.VarHeader.Content^[3]).ToBeGreaterThan(0)
  end
  else
  begin
    if AExpectedReasonCode = 0 then
    begin
      if FPacketType in [CMQTT_SUBACK, CMQTT_UNSUBACK] then
        Expect(DecodedCommonPacket.VarHeader.Len).ToBe(2 + 1)  //one more byte for payload
      else
        Expect(DecodedCommonPacket.VarHeader.Len).ToBe(2)  //no reason code should be included if it is 0  (success)
    end
    else
      Expect(DecodedCommonPacket.VarHeader.Len).ToBe(3);
  end;

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedCommonPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedCommonPacket.VarHeader.Content^, 'VarHeader.Content');

  if FPacketType in [CMQTT_SUBACK, CMQTT_UNSUBACK] then
    Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedCommonPacket.Payload.Content^, 'Payload.Content')
  else
    Expect(Pointer(DestPacket.Payload.Content)).ToBePointer(nil, 'no Payload.Content');
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_HappyFlow_WithProperties;
const
  CPropertiesPresent = 1;
  CReasonCode = 24;
begin
  HappyFlowContent(CPropertiesPresent, 2, CReasonCode);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_HappyFlow_NoProperties;
const
  CPropertiesPresent = 0;
  CReasonCode = 24;
begin
  HappyFlowContent(CPropertiesPresent, 2, CReasonCode);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_HappyFlow_NoPropertiesNoReasonCode;
const
  CPropertiesPresent = 0;
  CReasonCode = 0;
begin
  HappyFlowContent(CPropertiesPresent, 2, CReasonCode);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_HappyFlow_LongStrings;
const
  CPropertiesPresent = 1;
  CReasonCode = 24;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', CommonProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', CommonProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', CommonProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', CommonProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', CommonProperties.UserProperty)).ToBe(True);

  HappyFlowContent(CPropertiesPresent, 3, CReasonCode);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_EmptyBuffer;
begin
  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedCommonBuffer, 5)).ToBe(True);

  EncodedCommonBuffer.Content^[0] := FPacketType;
  FillChar(EncodedCommonBuffer.Content^[1], 4, $FF);

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempCommonFields.EnabledProperties := $FF; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  EncodedCommonBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_BadHeaderSizeInVarHeader;
begin
  TempCommonFields.EnabledProperties := $FF; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  if FPacketType in [CMQTT_SUBACK, CMQTT_UNSUBACK] then
    EncodedCommonBuffer.Content^[4] := 120
  else
    EncodedCommonBuffer.Content^[5] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_IncompleteBuffer;
begin
  TempCommonFields.EnabledProperties := $FF; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedCommonBuffer.Len + 1));
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_OverfilledBuffer;   //feature is disabled, to allow having multiple packets in a single buffer
begin
  TempCommonFields.EnabledProperties := $FF; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);
                                                                                                   //CMQTTDecoderOverfilledBuffer is not expected anymore, because the buffer should accept multiple packets as a stream
  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len + 1);
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_BufferWithExtraPackets;
begin
  TempCommonFields.EnabledProperties := $FF; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;
  AddAPayload;

  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);
  SetDynLength(EncodedCommonBuffer, EncodedCommonBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedCommonBuffer.Len - 50));
end;


procedure THeaderCommonDecoderCase.Test_Decode_Common_AllProperties;
var
  DecodedCommonProperties: TMQTTCommonProperties;
  DecodedCommonFields: TMQTTCommonFields;
begin
  TempCommonFields.EnabledProperties := $3; //all properties
  TempCommonFields.ReasonCode := 97;
  TempCommonFields.PacketIdentifier := 1234;

  AddAPayload;

  Expect(FillIn_CommonPropertiesForTest(TempCommonFields.EnabledProperties, CommonProperties)).ToBe(True);
  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);
  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);

  MQTT_InitCommonProperties(DecodedCommonProperties);
  try
    Expect(Decode_Common({DestPacket} DecodedCommonPacket, DecodedCommonFields, DecodedCommonProperties)).ToBe(CMQTTDecoderNoErr);

    if not (FPacketType in [CMQTT_SUBACK, CMQTT_UNSUBACK]) then
      Expect(DecodedCommonFields.ReasonCode).ToBe(97);

    Expect(DecodedCommonFields.PacketIdentifier).ToBe(1234);
    Expect(DecodedCommonFields.EnabledProperties).ToBe(TempCommonFields.EnabledProperties);

    Expect(DecodedCommonProperties.ReasonString.Len).ToBe(13);
    Expect(DecodedCommonProperties.UserProperty.Len).ToBe(3);
    //
    Expect(@DecodedCommonProperties.ReasonString.Content^, 13).ToBe(@['for no reason']);
    Expect(@DecodedCommonProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedCommonProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedCommonProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
  finally
    MQTT_FreeCommonProperties(DecodedCommonProperties);
  end;
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_UnknownProperty;
var
  DecodedCommonProperties: TMQTTCommonProperties;
  DecodedCommonFields: TMQTTCommonFields;
begin
  TempCommonFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  AddAPayload;
  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);

  MQTT_InitCommonProperties(DecodedCommonProperties);
  try
    Expect(Decode_Common({DestPacket} DecodedCommonPacket, DecodedCommonFields, DecodedCommonProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedCommonFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    MQTT_FreeCommonProperties(DecodedCommonProperties);
  end;
end;


procedure THeaderCommonDecoderCase.Test_FillIn_Common_Decoder_NoProperties;
var
  DecodedCommonProperties: TMQTTCommonProperties;
  DecodedCommonFields: TMQTTCommonFields;
begin
  TempCommonFields.EnabledProperties := 0;
  AddAPayload;
  Expect(FillIn_Common(TempCommonFields, CommonProperties, FPacketType, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedCommonBuffer);

  Expect(Decode_CommonToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);

  MQTT_InitCommonProperties(DecodedCommonProperties);
  try
    Expect(Decode_Common({DestPacket} DecodedCommonPacket, DecodedCommonFields, DecodedCommonProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedCommonFields.EnabledProperties).ToBe(0, 'no property should be decoded');
  finally
    MQTT_FreeCommonProperties(DecodedCommonProperties);
  end;
end;


end.

