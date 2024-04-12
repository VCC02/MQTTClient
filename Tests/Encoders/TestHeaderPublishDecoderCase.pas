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


unit TestHeaderPublishDecoderCase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils;

type

  THeaderPublishDecoderCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_FillIn_Publish_Decoder_HappyFlow_QoS0;
    procedure Test_FillIn_Publish_Decoder_HappyFlow_QoS1;
    procedure Test_FillIn_Publish_Decoder_HappyFlow_QoS2;
    procedure Test_FillIn_Publish_Decoder_HappyFlow_QoS3;
    procedure Test_FillIn_Publish_Decoder_HappyFlow_NoAppMsg;
    procedure Test_FillIn_Publish_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_Publish_Decoder_EmptyBuffer;
    procedure Test_FillIn_Publish_Decoder_BadVarInt;
    procedure Test_FillIn_Publish_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_Publish_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_Publish_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_Publish_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_Publish_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_Publish_AllProperties_QoS1;
    procedure Test_FillIn_Publish_Decoder_UnknownProperty;
    procedure Test_FillIn_Publish_Decoder_NoProperties;
  end;


implementation


uses
  DynArrays, Expectations,
  MQTTTestUtils, MQTTPublishCtrl;

var
  DestPacket: TMQTTControlPacket;
  PublishProperties: TMQTTPublishProperties;
  EncodedPubBuffer: TDynArrayOfByte;
  DecodedPubPacket: TMQTTControlPacket;
  TempPublishFields: TMQTTPublishFields;
  DecodedBufferLen: DWord;


procedure THeaderPublishDecoderCase.SetUp;
begin
  MQTT_InitControlPacket(DestPacket);
  InitDynArrayToEmpty(EncodedPubBuffer);
  MQTT_InitControlPacket(DecodedPubPacket);

  MQTT_InitPublishProperties(PublishProperties);
  InitDynArrayToEmpty(TempPublishFields.TopicName);
  InitDynArrayToEmpty(TempPublishFields.ApplicationMessage);
  DecodedBufferLen := 0;
end;


procedure THeaderPublishDecoderCase.TearDown;
begin
  MQTT_FreeControlPacket(DestPacket);
  FreeDynArray(EncodedPubBuffer);
  MQTT_FreeControlPacket(DecodedPubPacket);

  MQTT_FreePublishProperties(PublishProperties);
  FreeDynArray(TempPublishFields.TopicName);
  FreeDynArray(TempPublishFields.ApplicationMessage);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_QoS0;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPubPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH or TempPublishFields.PublishCtrlFlags);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  Expect(DecodedPubPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedPubPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedPubPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedPubPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedPubPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedPubPacket.Payload.Content^, 'Payload.Content');
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_QoS1;
begin
  TempPublishFields.PublishCtrlFlags := 1 shl 1;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := $1234;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPubPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH or TempPublishFields.PublishCtrlFlags);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);
  Expect(DecodedPubPacket.VarHeader.Content^[17]).ToBe($12);
  Expect(DecodedPubPacket.VarHeader.Content^[18]).ToBe($34);

  Expect(DecodedPubPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedPubPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedPubPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedPubPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedPubPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedPubPacket.Payload.Content^, 'Payload.Content');
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_QoS2;
begin
  TempPublishFields.PublishCtrlFlags := 2 shl 1;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := $1234;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPubPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH or TempPublishFields.PublishCtrlFlags);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);
  Expect(DecodedPubPacket.VarHeader.Content^[17]).ToBe($12);
  Expect(DecodedPubPacket.VarHeader.Content^[18]).ToBe($34);

  Expect(DecodedPubPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedPubPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedPubPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedPubPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedPubPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedPubPacket.Payload.Content^, 'Payload.Content');
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_QoS3;
begin
  TempPublishFields.PublishCtrlFlags := 3 shl 1;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := $1234;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTT_Reason_MalformedPacket shl 8 or CMQTTDecoderServerErr);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_NoAppMsg;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  Expect(DestPacket.Payload.Len).ToBe(0);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPubPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH or TempPublishFields.PublishCtrlFlags);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  Expect(DecodedPubPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedPubPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedPubPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedPubPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedPubPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(DestPacket.Payload.Content).ToBe(nil, 'Payload.Content');
end;

                                     //the test of LongStrings implies having VarInts of two or more bytes in size
procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_HappyFlow_LongStrings;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/five/seven/zero/', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.this is the content.', TempPublishFields.ApplicationMessage)).ToBe(True);

  {$IFDEF EnUserProperty}
    Expect(AddStringToDynOfDynArrayOfByte('First_user_property with a very long content. This is intended to cause total string length to be greater than 255.', PublishProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Second_user_property with a very long content. This is intended to cause total string length to be greater than 255.', PublishProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Third_user_property with a very long content. This is intended to cause total string length to be greater than 255.', PublishProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('Fourth_user_property with a very long content. This is intended to cause total string length to be greater than 255.', PublishProperties.UserProperty)).ToBe(True);
    Expect(AddStringToDynOfDynArrayOfByte('One more string, to cause the buffer to go past 512 bytes.', PublishProperties.UserProperty)).ToBe(True);
  {$ENDIF}

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedPubPacket.Header.Content^[0]).ToBe(CMQTT_PUBLISH or TempPublishFields.PublishCtrlFlags);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  Expect(DecodedPubPacket.Header.Len).ToBe(DestPacket.Header.Len, 'Header len mismatch');
  Expect(DecodedPubPacket.VarHeader.Len).ToBe(DestPacket.VarHeader.Len, 'VarHeader len mismatch');
  Expect(DecodedPubPacket.Payload.Len).ToBe(DestPacket.Payload.Len, 'Payload len mismatch');

  Expect(@DestPacket.Header.Content^, DestPacket.Header.Len).ToBe(@DecodedPubPacket.Header.Content^, 'Header.Content');
  Expect(@DestPacket.VarHeader.Content^, DestPacket.VarHeader.Len).ToBe(@DecodedPubPacket.VarHeader.Content^, 'VarHeader.Content');
  Expect(@DestPacket.Payload.Content^, DestPacket.Payload.Len).ToBe(@DecodedPubPacket.Payload.Content^, 'Payload.Content');
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_EmptyBuffer;
begin
  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderEmptyBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_BadVarInt;
begin
  Expect(SetDynLength(EncodedPubBuffer, 5)).ToBe(True);

  EncodedPubBuffer.Content^[0] := CMQTT_PUBLISH;
  FillChar(EncodedPubBuffer.Content^[1], 4, $FF);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadVarInt);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_BadHeaderSizeInFixedHeader;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  EncodedPubBuffer.Content^[1] := 0; //corrupting a size (e.g. VarHeader+Payload) should result in an error

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(0);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_BadHeaderSizeInVarHeader;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  EncodedPubBuffer.Content^[19] := 120; //corrupting a size (e.g. PropertyLen) should result in an error

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderBadHeaderSize);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_IncompleteBuffer;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);

  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len - 1); //decreasing the length should result in an error
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderIncompleteBuffer);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len + 1);
end;


//procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
//  TempPublishFields.EnabledProperties := 255; //all properties
//  TempPublishFields.PacketIdentifier := 47;
//  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
//  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);
//
//  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
//
//  SetDynLength(DestPacket.VarHeader, DestPacket.VarHeader.Len + 1); //increasing the length should result in an error
//  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);
//
//  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderOverfilledBuffer);
//  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len - 1);
//end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_BufferWithExtraPackets;
begin
  TempPublishFields.PublishCtrlFlags := 0;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);

  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);
  SetDynLength(EncodedPubBuffer, EncodedPubBuffer.Len + 50); //increasing the length of the buffer should result in no error

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(DWord(EncodedPubBuffer.Len - 50));
end;


procedure THeaderPublishDecoderCase.Test_Decode_Publish_AllProperties_QoS1;
var
  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishProperties: TMQTTPublishProperties;
  DecodedTopicNameStr: string;
begin
  TempPublishFields.PublishCtrlFlags := 1 shl 1;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  TempPublishFields.EnabledProperties := 255 {$IFnDEF EnUserProperty} xor CMQTTPublish_EnUserProperty {$ENDIF}; //all properties
  TempPublishFields.PacketIdentifier := 47;
  Expect(StringToDynArrayOfByte('five/seven/zero', TempPublishFields.TopicName)).ToBe(True);
  Expect(StringToDynArrayOfByte('this is the content', TempPublishFields.ApplicationMessage)).ToBe(True);

  Expect(FillIn_PublishPropertiesForTest(TempPublishFields.EnabledProperties, PublishProperties)).ToBe(True);
  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);

  //the following expectation is still required
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);
  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);

  MQTT_InitPublishProperties(DecodedPublishProperties);
  try
    Expect(Decode_Publish({DestPacket} DecodedPubPacket, DecodedPublishFields, DecodedPublishProperties)).ToBe(CMQTTDecoderNoErr);

    Expect(DecodedPublishFields.PublishCtrlFlags).ToBe(TempPublishFields.PublishCtrlFlags);

    DynArrayOfByteToString(DecodedPublishFields.TopicName, DecodedTopicNameStr);
    Expect(DecodedTopicNameStr).ToBe(DynArrayOfByteToString(TempPublishFields.TopicName));
    Expect(DecodedPublishFields.PacketIdentifier).ToBe(TempPublishFields.PacketIdentifier);
    Expect(DecodedPublishFields.EnabledProperties).ToBe(TempPublishFields.EnabledProperties);

    Expect(DecodedPublishProperties.ResponseTopic.Len).ToBe(Length('some/name'));
    Expect(DecodedPublishProperties.CorrelationData.Len).ToBe(3);
    {$IFDEF EnUserProperty}
      Expect(DecodedPublishProperties.UserProperty.Len).ToBe(3);
    {$ENDIF}
    Expect(DecodedPublishProperties.SubscriptionIdentifier.Len).ToBe(3);
    Expect(DecodedPublishProperties.ContentType.Len).ToBe(3);

    Expect(@DecodedPublishProperties.ResponseTopic.Content^, 9).ToBe(@['some/name']);
    Expect(@DecodedPublishProperties.CorrelationData.Content^, 3).ToBe(@[40, 50, 60]);
    {$IFDEF EnUserProperty}
      Expect(@DecodedPublishProperties.UserProperty.Content^[0]^.Content^, 19).ToBe(@['first_user_property']);
      Expect(@DecodedPublishProperties.UserProperty.Content^[1]^.Content^, 20).ToBe(@['second_user_property']);
      Expect(@DecodedPublishProperties.UserProperty.Content^[2]^.Content^, 19).ToBe(@['third_user_property']);
    {$ENDIF}
    Expect(@DecodedPublishProperties.SubscriptionIdentifier.Content^, 3 shl 2).ToBe(@[$A0, $0F, 0, 0,  $88, $13, 0, 0,  $40, $1F, 0, 0]);   //DWords: 4000, 5000, 8000
    Expect(@DecodedPublishProperties.ContentType.Content^, 3).ToBe(@[70, 80, 90]);

    Expect(@DecodedPublishFields.ApplicationMessage.Content^, TempPublishFields.ApplicationMessage.Len).ToBe(@TempPublishFields.ApplicationMessage.Content^[0], 'payload mismatch');
  finally
    FreeDynArray(DecodedPublishFields.TopicName);
    FreeDynArray(DecodedPublishFields.ApplicationMessage);

    MQTT_FreePublishProperties(DecodedPublishProperties);
  end;
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_UnknownProperty;
var
  DecodedPublishProperties: TMQTTPublishProperties;
  DecodedPublishFields: TMQTTPublishFields;
begin
  TempPublishFields.EnabledProperties := CMQTTUnknownPropertyWord or 1;  //"or 1" is used to add a valid property
  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  MQTT_InitPublishProperties(DecodedPublishProperties);
  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);
  try
    Expect(Decode_Publish({DestPacket} DecodedPubPacket, DecodedPublishFields, DecodedPublishProperties)).ToBe(CMQTTDecoderUnknownProperty);
    Expect(DecodedPublishFields.EnabledProperties and $FF).ToBe(CMQTT_UnknownProperty_PropID);
  finally
    FreeDynArray(DecodedPublishFields.TopicName);
    FreeDynArray(DecodedPublishFields.ApplicationMessage);
    MQTT_FreePublishProperties(DecodedPublishProperties);
  end;
end;


procedure THeaderPublishDecoderCase.Test_FillIn_Publish_Decoder_NoProperties;
var
  DecodedPublishProperties: TMQTTPublishProperties;
  DecodedPublishFields: TMQTTPublishFields;
begin
  TempPublishFields.EnabledProperties := 0;
  Expect(FillIn_Publish(TempPublishFields, PublishProperties, DestPacket)).ToBe(True);
  EncodeControlPacketToBuffer(DestPacket, EncodedPubBuffer);

  Expect(Decode_PublishToCtrlPacket(EncodedPubBuffer, DecodedPubPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
  Expect(DecodedBufferLen).ToBe(EncodedPubBuffer.Len);

  MQTT_InitPublishProperties(DecodedPublishProperties);
  InitDynArrayToEmpty(DecodedPublishFields.TopicName);
  InitDynArrayToEmpty(DecodedPublishFields.ApplicationMessage);
  try
    Expect(Decode_Publish({DestPacket} DecodedPubPacket, DecodedPublishFields, DecodedPublishProperties)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedPublishFields.EnabledProperties).ToBe(0);
  finally
    FreeDynArray(DecodedPublishFields.TopicName);
    FreeDynArray(DecodedPublishFields.ApplicationMessage);
    MQTT_FreePublishProperties(DecodedPublishProperties);
  end;
end;


initialization

  RegisterTest(THeaderPublishDecoderCase);
end.

