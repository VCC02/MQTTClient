{
    Copyright (C) 2023 VCC
    creation date: 28 Apr 2023
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



unit TestHeaderConnectEncoderCase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils;

type

  THeaderConnectEncoderCase = class(TTestCase)
  private
    procedure PrepareBasicContent(var TempConnectFields: TMQTTConnectFields; var DestPacket: TMQTTControlPacket;
      var TempUserName, TempPassword, TempClientID: string);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_FillIn_Connect_BasicContent;
    procedure Test_FillIn_Connect_Decoder_HappyFlow;
    procedure Test_FillIn_Connect_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Connect_Decoder_EmptyBuffer;
    procedure Test_FillIn_Connect_Decoder_BadVarInt;
    procedure Test_FillIn_Connect_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Connect_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Connect_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Connect_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Connect_Decoder_BufferWithExtraPackets;

    procedure Test_FillIn_Connect_Decoder_AllProperties;
    procedure Test_FillIn_Connect_Decoder_UnknownProperty;
    procedure Test_FillIn_Connect_Decoder_NoProperties;
  end;

implementation


uses
  DynArrays, Expectations,
  MQTTConnectCtrl, MQTTTestUtils;

var
  DestPacket: TMQTTControlPacket;
  ConnectProperties: TMQTTConnectProperties;
  EncodedConnectBuffer: TDynArrayOfByte;
  DecodedConnectPacket: TMQTTControlPacket;

  //PayloadContent: TMQTTConnectPayloadContent;
  TempWillProperties: TMQTTWillProperties;
  TempConnectFields: TMQTTConnectFields;
  DecodedBufferLen: DWord;


procedure THeaderConnectEncoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedConnectBuffer);
  MQTT_InitControlPacket(DecodedConnectPacket);

  MQTT_InitConnectProperties(ConnectProperties);
  MQTT_InitConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_InitWillProperties(TempWillProperties);
  DecodedBufferLen := 0;
end;


procedure THeaderConnectEncoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedConnectBuffer);
  MQTT_FreeControlPacket(DecodedConnectPacket);

  MQTT_FreeConnectProperties(ConnectProperties);
  MQTT_FreeConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_FreeWillProperties(TempWillProperties);
end;


procedure THeaderConnectEncoderCase.PrepareBasicContent(var TempConnectFields: TMQTTConnectFields; var DestPacket: TMQTTControlPacket;
  var TempUserName, TempPassword, TempClientID: string);
begin
  TempConnectFields.ConnectFlags := CMQTT_UsernameInConnectFlagsBitMask or
                                    CMQTT_PasswordInConnectFlagsBitMask or
                                    CMQTT_CleanStartInConnectFlagsBitMask;

  TempConnectFields.KeepAlive := 0; //any positive values require pinging the server if no other packet is being sent
  TempConnectFields.EnabledProperties := CMQTTConnect_EnSessionExpiryInterval;

  ConnectProperties.SessionExpiryInterval := 3600;  //just a random value
  ConnectProperties.ReceiveMaximum := 3000;   // just a random value
  ConnectProperties.MaximumPacketSize := 128;  // just a random value
  ConnectProperties.TopicAliasMaximum := 7000; // just a random value
  ConnectProperties.RequestResponseInformation := 1; // just a random value
  ConnectProperties.RequestProblemInformation := 1; // just a random value

  TempWillProperties.PayloadFormatIndicator := 0; // nothing for now

  FillIn_PayloadWillProperties(TempWillProperties, TempConnectFields.PayloadContent.WillProperties);

  TempUserName := 'abc';
  StringToDynArrayOfByte(TempUserName, TempConnectFields.PayloadContent.UserName);

  TempPassword := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ01';
  StringToDynArrayOfByte(TempPassword, TempConnectFields.PayloadContent.Password);

  TempClientID := 'VVV';
  StringToDynArrayOfByte(TempClientID, TempConnectFields.PayloadContent.ClientID);
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_BasicContent;
var
  DestPacket: TMQTTControlPacket;
  TempUserName, TempPassword, TempClientID: string;
begin
  PrepareBasicContent(TempConnectFields, DestPacket, TempUserName, TempPassword, TempClientID);

  try
    Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
    Expect(DestPacket.Header.Len).ToBe(2);
    Expect(DestPacket.VarHeader.Len).ToBe(16);
    Expect(DestPacket.Payload.Len).ToBe(40);

    Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@[16, 56]);
    Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@[0, 4, 77, 81, 84, 84, 5, 194, 0, 0, 5, 17, 0, 0, 14, 16]);
    Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@[0, 3, 86, 86, 86, 0, 3, 97, 98, 99, 0, 28, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 48, 49]);
  finally
    SetDynLength(DestPacket.Header, 0);
    SetDynLength(DestPacket.VarHeader, 0);
    SetDynLength(DestPacket.Payload, 0);
  end;
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_HappyFlow;
const
  CConnectFlags = 255;
begin
  TempConnectFields.ConnectFlags := CConnectFlags;
  TempConnectFields.KeepAlive := 1234;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(2);
  Expect(DecodedConnectPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedConnectPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedConnectPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(@DecodedConnectPacket.VarHeader.Content^[2], 4).ToBe(@['MQTT']);
  Expect(DecodedConnectPacket.VarHeader.Content^[6]).ToBe(5);  //version
  //
  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedConnectPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedConnectPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedConnectPacket.Payload.Content^, 'VarHeader.Payload');
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_HappyFlow_LongStrings;
const
  CConnectFlags = 255;
begin
  Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', ConnectProperties.UserProperty)).ToBe(True);

  TempWillProperties.WillDelayInterval := 123;
  TempWillProperties.PayloadFormatIndicator := 158;
  TempWillProperties.MessageExpiryInterval := 3600;
  Expect(StringToDynArrayOfByte('some sort of text', TempWillProperties.ContentType)).ToBe(True);
  Expect(StringToDynArrayOfByte('/my/very/long/name', TempWillProperties.ResponseTopic)).ToBe(True);
  Expect(StringToDynArrayOfByte('some unique identifier', TempWillProperties.CorrelationData)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('some string', TempWillProperties.UserProperty)).ToBe(True);
  Expect(FillIn_PayloadWillProperties(TempWillProperties, TempConnectFields.PayloadContent.WillProperties)).ToBe(True);

  Expect(StringToDynArrayOfByte('This is the longest ClientID ever. It can contain anything.', TempConnectFields.PayloadContent.ClientID)).ToBe(True);
  Expect(StringToDynArrayOfByte('A_very_long_username,_only_a_computer_could_remember.', TempConnectFields.PayloadContent.UserName)).ToBe(True);
  Expect(StringToDynArrayOfByte('Now, a real challenge, to have a password, longer than the above username.', TempConnectFields.PayloadContent.Password)).ToBe(True);
  Expect(StringToDynArrayOfByte('Nothing special here, just a useless will message.', TempConnectFields.PayloadContent.WillPayload)).ToBe(True);
  //Expect(StringToDynArrayOfByte('', PayloadContent.WillProperties)).ToBe(True);  //this is set by FillIn_PayloadWillProperties function  - concatenation of TMQTTWillProperties.
  Expect(StringToDynArrayOfByte('/Some/remaining/string/for/the/WillTopic.', TempConnectFields.PayloadContent.WillTopic)).ToBe(True);

  TempConnectFields.ConnectFlags := CConnectFlags;
  TempConnectFields.KeepAlive := 1234;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);

  Expect(DestPacket.Header.Len).ToBe(3);
  Expect(DecodedConnectPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedConnectPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedConnectPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(DecodedConnectPacket.Header.Content^[0]).ToBe(CMQTT_Connect);
  Expect(@DecodedConnectPacket.VarHeader.Content^[2], 4).ToBe(@['MQTT']);
  Expect(DecodedConnectPacket.VarHeader.Content^[6]).ToBe(5);  //version
  //
  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedConnectPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedConnectPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedConnectPacket.Payload.Content^, 'VarHeader.Payload');
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_EmptyBuffer;
begin
  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedConnectBuffer, 5)).ToBe(True);

  EncodedConnectBuffer.Content^[0] := CMQTT_Connect;
  FillChar(EncodedConnectBuffer.Content^[1], 4, $FF);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempConnectFields.ConnectFlags := 255;
  TempConnectFields.KeepAlive := 2400;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  EncodedConnectBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_BadHeaderSizeInVarHeader;
begin
  TempConnectFields.ConnectFlags := 255;
  TempConnectFields.KeepAlive := 2400;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  EncodedConnectBuffer.Content^[12] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_IncompleteBuffer;
begin
  TempConnectFields.ConnectFlags := 255;
  TempConnectFields.KeepAlive := 2400;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len + 1);
end;


//procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_OverfilledBuffer; //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempConnectFields.ConnectFlags := 255;
//  TempConnectFields.KeepAlive := 2400;
//  TempConnectFields.EnabledProperties := $1FF; //all properties
//  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);
//
//  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len - 1);
//end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_BufferWithExtraPackets;
begin
  TempConnectFields.ConnectFlags := 255;
  TempConnectFields.KeepAlive := 2400;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);
  SetDynLength(EncodedConnectBuffer, EncodedConnectBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedConnectBuffer.Len - 50));
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_AllProperties;
const
  CConnectFlags = 255;
  CKeepAlive = 1234;
var
  //DecodedEnabledProperties: Word;
  DecodedConnectProperties: TMQTTConnectProperties;
  //DecodedProtocolVersion: Byte;
  //DecodedKeepAlive: Word;
  //DecodedCtrlFlags: Byte;
  DecodedConnectFields: TMQTTConnectFields;
begin
  ConnectProperties.SessionExpiryInterval := 4567;
  ConnectProperties.ReceiveMaximum := 30;
  ConnectProperties.MaximumPacketSize := 12345;
  ConnectProperties.TopicAliasMaximum := 345;
  ConnectProperties.RequestResponseInformation := 1;
  ConnectProperties.RequestProblemInformation := 1;
  Expect(AddStringToDynOfDynArrayOfByte('first_user_property.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('second_user_property.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('third_user_property.', ConnectProperties.UserProperty)).ToBe(True);
  Expect(StringToDynArrayOfByte('some auth method', ConnectProperties.AuthenticationMethod)).ToBe(True);
  Expect(StringToDynArrayOfByte('some auth data', ConnectProperties.AuthenticationData)).ToBe(True);

  TempWillProperties.WillDelayInterval := 234;
  TempWillProperties.PayloadFormatIndicator := 159;
  TempWillProperties.MessageExpiryInterval := 3700;
  Expect(StringToDynArrayOfByte('some sort of text', TempWillProperties.ContentType)).ToBe(True);
  Expect(StringToDynArrayOfByte('/my/very/long/name', TempWillProperties.ResponseTopic)).ToBe(True);
  Expect(StringToDynArrayOfByte('some unique identifier', TempWillProperties.CorrelationData)).ToBe(True);
  Expect(AddStringToDynOfDynArrayOfByte('some string', TempWillProperties.UserProperty)).ToBe(True);
  Expect(FillIn_PayloadWillProperties(TempWillProperties, TempConnectFields.PayloadContent.WillProperties)).ToBe(True);

  Expect(StringToDynArrayOfByte('ClientID.', TempConnectFields.PayloadContent.ClientID)).ToBe(True);
  Expect(StringToDynArrayOfByte('long_username', TempConnectFields.PayloadContent.UserName)).ToBe(True);
  Expect(StringToDynArrayOfByte('a password', TempConnectFields.PayloadContent.Password)).ToBe(True);
  Expect(StringToDynArrayOfByte('will message', TempConnectFields.PayloadContent.WillPayload)).ToBe(True);
  //Expect(StringToDynArrayOfByte('', TempConnectFields.PayloadContent.WillProperties)).ToBe(True);  //this is set by FillIn_PayloadWillProperties function  - concatenation of TMQTTWillProperties.
  Expect(StringToDynArrayOfByte('/Some/Will', TempConnectFields.PayloadContent.WillTopic)).ToBe(True);

  TempConnectFields.ConnectFlags := CConnectFlags;
  TempConnectFields.KeepAlive := CKeepAlive;
  TempConnectFields.EnabledProperties := $1FF; //all properties
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);

  DecodedConnectFields.ProtocolVersion := 1;
  DecodedConnectFields.KeepAlive := 3;
  MQTT_InitConnectProperties(DecodedConnectProperties);
  try
    Expect(Decode_Connect({DestPacket} DecodedConnectPacket, DecodedConnectFields, DecodedConnectProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedConnectFields.ConnectFlags).ToBe(CConnectFlags);
    Expect(DecodedConnectFields.EnabledProperties).ToBe(TempConnectFields.EnabledProperties);
    Expect(DecodedConnectFields.ProtocolVersion).ToBe(5);
    Expect(DecodedConnectFields.KeepAlive).ToBe(CKeepAlive);

    Expect(DecodedConnectProperties.SessionExpiryInterval).ToBe(4567);
    Expect(DecodedConnectProperties.ReceiveMaximum).ToBe(30);
    Expect(DecodedConnectProperties.MaximumPacketSize).ToBe(12345);
    Expect(DecodedConnectProperties.TopicAliasMaximum).ToBe(345);
    Expect(DecodedConnectProperties.RequestResponseInformation).ToBe(1);
    Expect(DecodedConnectProperties.RequestProblemInformation).ToBe(1);
    Expect(DecodedConnectProperties.UserProperty.Len).ToBe(3);
    Expect(DecodedConnectProperties.AuthenticationMethod.Len).ToBe(16);
    Expect(DecodedConnectProperties.AuthenticationData.Len).ToBe(14);
    //
    Expect(@DecodedConnectProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
    Expect(@DecodedConnectProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
    Expect(@DecodedConnectProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
    Expect(@DecodedConnectProperties.AuthenticationMethod.Content^, 16).ToBe(@['some auth method']);
    Expect(@DecodedConnectProperties.AuthenticationData.Content^, 14).ToBe(@['some auth data']);

    //ToDo:  veryify ConnectPayload and PayloadWillProperties
  finally
    MQTT_FreeConnectProperties(DecodedConnectProperties);
  end;
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_UnknownProperty;
var
  DecodedConnectProperties: TMQTTConnectProperties;
  DecodedConnectFields: TMQTTConnectFields;
begin
  TempConnectFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);

  MQTT_InitConnectProperties(DecodedConnectProperties);
  try
    Expect(Decode_Connect({DestPacket} DecodedConnectPacket, DecodedConnectFields, DecodedConnectProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedConnectFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);

    //ToDo:  veryify ConnectPayload and PayloadWillProperties
  finally
    MQTT_FreeConnectProperties(DecodedConnectProperties);
  end;
end;


procedure THeaderConnectEncoderCase.Test_FillIn_Connect_Decoder_NoProperties;
var
  DecodedConnectProperties: TMQTTConnectProperties;
  DecodedConnectFields: TMQTTConnectFields;
begin
  TempConnectFields.EnabledProperties := 0;
  Expect(FillIn_Connect(TempConnectFields, ConnectProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedConnectBuffer);

  Expect(Decode_ConnectToCtrlPacket(EncodedConnectBuffer, DecodedConnectPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedConnectBuffer.Len);

  MQTT_InitConnectProperties(DecodedConnectProperties);
  try
    Expect(Decode_Connect({DestPacket} DecodedConnectPacket, DecodedConnectFields, DecodedConnectProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedConnectFields.EnabledProperties).ToBe(0);   //if this returns 8 (CMQTT_UnknownProperty_PropID), then the decoder can't parse empty array of properties

    //ToDo:  veryify ConnectPayload and PayloadWillProperties
  finally
    MQTT_FreeConnectProperties(DecodedConnectProperties);
  end;
end;


initialization

  RegisterTest(THeaderConnectEncoderCase);
end.

