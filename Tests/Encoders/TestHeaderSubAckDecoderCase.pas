{
    Copyright (C) 2023 VCC
    creation date: 24 May 2023
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


unit TestHeaderSubAckDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, TestHeaderCommonDecoderCase;

type

  THeaderSubAckDecoderCase = class(THeaderCommonDecoderCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_FillIn_SubAck_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_SubAck_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_SubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode;
    procedure Test_FillIn_SubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode_IRLPacket;
    procedure Test_FillIn_SubAck_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_SubAck_Decoder_EmptyBuffer;
    procedure Test_FillIn_SubAck_Decoder_BadVarInt;
    procedure Test_FillIn_SubAck_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_SubAck_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_SubAck_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_SubAck_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_SubAck_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_SubAck_AllProperties;
    procedure Test_FillIn_SubAck_Decoder_UnknownProperty;
    procedure Test_FillIn_SubAck_Decoder_NoProperties;

    property PacketType;
  end;

implementation


uses
  Expectations, MQTTSubAckCtrl, DynArrays;


procedure THeaderSubAckDecoderCase.SetUp;
begin
  inherited SetUp;
  PacketType := CMQTT_SUBACK;
end;


procedure THeaderSubAckDecoderCase.TearDown;
begin
  inherited TearDown;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_HappyFlow_WithProperties;
begin
  inherited Test_FillIn_Common_Decoder_HappyFlow_WithProperties;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_HappyFlow_NoProperties;
begin
  Test_FillIn_Common_Decoder_HappyFlow_NoProperties;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode;
begin
  Test_FillIn_Common_Decoder_HappyFlow_NoPropertiesNoReasonCode;
end;


//This is a packet, captured from Mosquitto server, as a SUBACK. It does not contain properties, but is has a 4-byte long payload.
procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode_IRLPacket;
var
  EncodedCommonBuffer: TDynArrayOfByte;
  DecodedCommonPacket: TMQTTControlPacket;
  DecodedBufferLen: DWord;
  SubAckFields: TMQTTSubAckFields;
  SubAckProperties: TMQTTSubAckProperties;
begin
  InitDynArrayToEmpty(EncodedCommonBuffer);
  MQTT_InitControlPacket(DecodedCommonPacket);
  try
    SetDynLength(EncodedCommonBuffer, 9);
    // $90, $07, $00, $01, $00, $02, $02, $01, $00
    EncodedCommonBuffer.Content^[0] := $90; //SUBACK
    EncodedCommonBuffer.Content^[1] := $07; //NumberOfNextBytes
    EncodedCommonBuffer.Content^[2] := $00; //Hi(PacketIdentifier)
    EncodedCommonBuffer.Content^[3] := $01; //Lo(PacketIdentifier)
    EncodedCommonBuffer.Content^[4] := $00; //SUBACK Properties Len (No Reason String, No user prop)
    EncodedCommonBuffer.Content^[5] := $02; //QoS[0]=2
    EncodedCommonBuffer.Content^[6] := $02; //QoS[0]=2
    EncodedCommonBuffer.Content^[7] := $01; //QoS[0]=1
    EncodedCommonBuffer.Content^[8] := $00; //QoS[0]=0

    Expect(Decode_SubAckToCtrlPacket(EncodedCommonBuffer, DecodedCommonPacket, DecodedBufferLen)).ToBe(CMQTTDecoderNoErr);
    Expect(DecodedCommonPacket.Header.Content^[0]).ToBe(CMQTT_SUBACK);
    Expect(DecodedBufferLen).ToBe(EncodedCommonBuffer.Len);

    Expect(DecodedCommonPacket.Header.Len).ToBe(2, 'Header len mismatch');
    Expect(DecodedCommonPacket.VarHeader.Len).ToBe(3, 'VarHeader len mismatch');
    Expect(DecodedCommonPacket.Payload.Len).ToBe(4, 'Payload len mismatch');

    Expect(DecodedCommonPacket.VarHeader.Content^[0]).ToBe($00); //Hi(PacketIdentifier)
    Expect(DecodedCommonPacket.VarHeader.Content^[1]).ToBe($01); //Lo(PacketIdentifier)

    Expect(DecodedCommonPacket.VarHeader.Len).ToBe(2 + 1);  //one more byte for payload

    MQTT_InitCommonProperties(SubAckProperties);
    InitDynArrayToEmpty(SubAckFields.SrcPayload);
    try
      Expect(Decode_SubAck(DecodedCommonPacket, SubAckFields, SubAckProperties)).ToBe(CMQTTDecoderNoErr);

      Expect(SubAckFields.EnabledProperties).ToBe(0, 'No expected properties.');
      //Expect(SubAckFields.IncludeReasonCode).ToBe(0, 'TBD');  //the IncludeReasonCode field may not be used in SUBACK
      Expect(SubAckFields.PacketIdentifier).ToBe(1, 'PacketIdentifier');
      Expect(SubAckFields.SrcPayload.Len).ToBe(4, 'Expected 4 reason codes');
    finally
      FreeDynArray(SubAckFields.SrcPayload);
      MQTT_FreeCommonProperties(SubAckProperties);
    end;
  finally
    FreeDynArray(EncodedCommonBuffer);
    MQTT_FreeControlPacket(DecodedCommonPacket);
  end;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_HappyFlow_LongStrings;
begin
  Test_FillIn_Common_Decoder_HappyFlow_LongStrings;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_EmptyBuffer;
begin
  Test_FillIn_Common_Decoder_EmptyBuffer;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_BadVarInt;
begin
  Test_FillIn_Common_Decoder_BadVarInt;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_BadHeaderSizeInFixedHeader;
begin
  Test_FillIn_Common_Decoder_BadHeaderSizeInFixedHeader;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_BadHeaderSizeInVarHeader;
begin
  Test_FillIn_Common_Decoder_BadHeaderSizeInVarHeader;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_IncompleteBuffer;
begin
  Test_FillIn_Common_Decoder_IncompleteBuffer;
end;


//procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  Test_FillIn_Common_Decoder_OverfilledBuffer;
//end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_BufferWithExtraPackets;
begin
  Test_FillIn_Common_Decoder_BufferWithExtraPackets;
end;


procedure THeaderSubAckDecoderCase.Test_Decode_SubAck_AllProperties;
begin
  Test_Decode_Common_AllProperties;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_UnknownProperty;
begin
  Test_FillIn_Common_Decoder_UnknownProperty;
end;


procedure THeaderSubAckDecoderCase.Test_FillIn_SubAck_Decoder_NoProperties;
begin
  Test_FillIn_Common_Decoder_NoProperties;
end;


initialization

  RegisterTest(THeaderSubAckDecoderCase);
end.


