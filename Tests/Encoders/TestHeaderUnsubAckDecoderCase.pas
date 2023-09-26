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


unit TestHeaderUnsubAckDecoderCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  MQTTUtils, TestHeaderCommonDecoderCase;

type

  THeaderUnsubAckDecoderCase = class(THeaderCommonDecoderCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_FillIn_UnsubAck_Decoder_HappyFlow_WithProperties;
    procedure Test_FillIn_UnsubAck_Decoder_HappyFlow_NoProperties;
    procedure Test_FillIn_UnsubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode;
    procedure Test_FillIn_UnsubAck_Decoder_HappyFlow_LongStrings;

    procedure Test_FillIn_UnsubAck_Decoder_EmptyBuffer;
    procedure Test_FillIn_UnsubAck_Decoder_BadVarInt;
    procedure Test_FillIn_UnsubAck_Decoder_BadHeaderSizeInFixedHeader;
    procedure Test_FillIn_UnsubAck_Decoder_BadHeaderSizeInVarHeader;
    procedure Test_FillIn_UnsubAck_Decoder_IncompleteBuffer;
    //procedure Test_FillIn_UnsubAck_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
    procedure Test_FillIn_UnsubAck_Decoder_BufferWithExtraPackets;

    procedure Test_Decode_UnsubAck_AllProperties;
    procedure Test_FillIn_UnsubAck_Decoder_UnknownProperty;
    procedure Test_FillIn_UnsubAck_Decoder_NoProperties;

    property PacketType;
  end;

implementation


procedure THeaderUnsubAckDecoderCase.SetUp;
begin
  inherited SetUp;
  PacketType := CMQTT_UNSUBACK;
end;


procedure THeaderUnsubAckDecoderCase.TearDown;
begin
  inherited TearDown;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_HappyFlow_WithProperties;
begin
  inherited Test_FillIn_Common_Decoder_HappyFlow_WithProperties;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_HappyFlow_NoProperties;
begin
  Test_FillIn_Common_Decoder_HappyFlow_NoProperties;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_HappyFlow_NoPropertiesNoReasonCode;
begin
  Test_FillIn_Common_Decoder_HappyFlow_NoPropertiesNoReasonCode;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_HappyFlow_LongStrings;
begin
  Test_FillIn_Common_Decoder_HappyFlow_LongStrings;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_EmptyBuffer;
begin
  Test_FillIn_Common_Decoder_EmptyBuffer;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_BadVarInt;
begin
  Test_FillIn_Common_Decoder_BadVarInt;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_BadHeaderSizeInFixedHeader;
begin
  Test_FillIn_Common_Decoder_BadHeaderSizeInFixedHeader;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_BadHeaderSizeInVarHeader;
begin
  Test_FillIn_Common_Decoder_BadHeaderSizeInVarHeader;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_IncompleteBuffer;
begin
  Test_FillIn_Common_Decoder_IncompleteBuffer;
end;


//procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_OverfilledBuffer;  //feature is disabled, to allow having multiple packets in a single buffer
//begin
//  Test_FillIn_Common_Decoder_OverfilledBuffer;
//end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_BufferWithExtraPackets;
begin
  Test_FillIn_Common_Decoder_BufferWithExtraPackets;
end;


procedure THeaderUnsubAckDecoderCase.Test_Decode_UnsubAck_AllProperties;
begin
  Test_Decode_Common_AllProperties;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_UnknownProperty;
begin
  Test_FillIn_Common_Decoder_UnknownProperty;
end;


procedure THeaderUnsubAckDecoderCase.Test_FillIn_UnsubAck_Decoder_NoProperties;
begin
  Test_FillIn_Common_Decoder_NoProperties;
end;


initialization

  RegisterTest(THeaderUnsubAckDecoderCase);
end.



