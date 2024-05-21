{
    Copyright (C) 2023 VCC
    creation date: 20 May 2023
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



unit MQTTCommonCodecCtrl;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ENDIF}

{$IFDEF IsDesktop}
interface
{$ENDIF}

uses
  DynArrays, MQTTUtils, MQTTCommonProperties;


function FillIn_Common(var ACommonFields: TMQTTCommonFields;
                       var ACommonProperties: TMQTTCommonProperties;
                       APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                       var ADestPacket: TMQTTControlPacket): Boolean;


function Valid_CommonPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;
//input args: ABuffer
//output args: ADestPacket, AErr
function Decode_CommonToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function Decode_Common(var AReceivedPacket: TMQTTControlPacket;
                       var ACommonFields: TMQTTCommonFields;
                       var ACommonProperties: TMQTTCommonProperties): Word;

implementation


function FillIn_CommonVarHeader(var ACommonFields: TMQTTCommonFields; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;

  if not AddWordToPropertiesWithoutIdentifier(AVarHeader, ACommonFields.PacketIdentifier) then
    Exit;

  if ACommonFields.IncludeReasonCode = 1 then //based on remaining length
    if not AddByteToDynArray(ACommonFields.ReasonCode, AVarHeader) then
      Exit;

  Result := True;
end;


//input args: all, except ADestPacket
//output args: ADestPacket
function FillIn_Common(var ACommonFields: TMQTTCommonFields;
                       var ACommonProperties: TMQTTCommonProperties;
                       APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                       var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
  PacketTypeIsSubAckOrUnsubAck: Boolean;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  ACommonFields.IncludeReasonCode := 1;  //include by default (will be reset later if that's the case)

  InitDynArrayToEmpty(TempProperties);
  if not MQTT_FillIn_CommonProperties(ACommonFields.EnabledProperties, ACommonProperties, TempProperties, PropLen) then
    Exit;

  PacketTypeIsSubAckOrUnsubAck := (APacketType = CMQTT_SUBACK) or (APacketType = CMQTT_UNSUBACK);

  if PacketTypeIsSubAckOrUnsubAck then
  begin
    ACommonFields.IncludeReasonCode := 0;
    if PropLen = 0 then
    begin
      ACommonFields.ReasonCode := 0; //this will end up as PropLen
      //ACommonFields.IncludeReasonCode := 1;
    end;
  end
  else
  begin
    if PropLen > 2 then
      ACommonFields.IncludeReasonCode := 1
    else
    begin
      if ACommonFields.ReasonCode = 0 then   //this statement is optional  (per spec)
        ACommonFields.IncludeReasonCode := 0;
    end;
  end;

  if not FillIn_CommonVarHeader(ACommonFields, ADestPacket.VarHeader) then
    Exit;

  if ((ACommonFields.IncludeReasonCode = 1) and (PropLen > 0)) or PacketTypeIsSubAckOrUnsubAck then   // the "PropLen > 0" verification is done, because IncludeReasonCode is 1 by default
  begin
    if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
      Exit;

    if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
      Exit;
  end;

  FreeDynArray(TempProperties);

  if PacketTypeIsSubAckOrUnsubAck then
    if not ConcatDynArrays(ADestPacket.Payload, ACommonFields.SrcPayload) then
      Exit;

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := APacketType;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len + ADestPacket.Payload.Len) then
    Exit;                                                                                         //there is no payload for most packet types. Only SubAck and UnsubAck have payloads.

  Result := True;
end;


//input args: ABuffer
//output args: ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen, AActualVarAndPayloadLen
//Result: Err
function Decode_CommonPacketLength(var ABuffer: TDynArrayOfByte; var ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen, AActualVarAndPayloadLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  VarIntLen, TempErr: Byte;
  ConvErr: Boolean;
begin
  Result := CMQTTDecoderNoErr;
  ADecodedBufferLen := 0;

  if ABuffer.Len = 0 then
  begin
    Result := CMQTTDecoderEmptyBuffer;
    Exit;
  end;

  if ABuffer.Len < 4 then    //without this verification, the function ends up returning an invalid ADecodedBufferLen
  begin
    Result := CMQTTDecoderIncompleteBuffer;
    Exit;
  end;

  MemMove(@TempArr4, @ABuffer.Content^[1], 4);
  AExpectedVarAndPayloadLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  if AExpectedVarAndPayloadLen = 0 then
  begin
    Result := CMQTTDecoderBadHeaderSize;
    Exit;
  end;

  AFixedHeaderLen := VarIntLen + 1;
  ADecodedBufferLen := AFixedHeaderLen + AExpectedVarAndPayloadLen;

  AActualVarAndPayloadLen := ABuffer.Len - AFixedHeaderLen;
  if AActualVarAndPayloadLen > AExpectedVarAndPayloadLen then  ////////////////////////////////// Quick fix, in case the buffer contains multiple packets.
    AActualVarAndPayloadLen := AExpectedVarAndPayloadLen;

  TempErr := MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, AActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;
    Exit;
  end;
end;


function Valid_CommonPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;
var
  DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen: DWord;
begin
  Result := Decode_CommonPacketLength(ABuffer, DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if Result = CMQTTDecoderNoErr then
    if ABuffer.Len < DecodedBufferLen then
      Result := CMQTTDecoderIncompleteBuffer;

  APacketSize := DecodedBufferLen;
end;


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_CommonToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen, ActualVarAndPayloadLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, TempErr, TempPacketType: Byte;
  ConvErr: Boolean;
begin
  TempErr := Decode_CommonPacketLength(ABuffer, ADecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;
    Exit;
  end;

  if not SetDynLength(ADestPacket.Header, FixedHeaderLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_HeaderAlloc;
    Exit;
  end;

  CurrentBufferPointer := 0;
  MemMove(ADestPacket.Header.Content, @ABuffer.Content^[CurrentBufferPointer], FixedHeaderLen);

  CurrentBufferPointer := CurrentBufferPointer + FixedHeaderLen;

  if ActualVarAndPayloadLen < 2 then
  begin
    Result := CMQTTDecoderNoErr;
    Exit; //end of packet
  end;

  TempPacketType := ADestPacket.Header.Content^[0];

  if ActualVarAndPayloadLen <= 3 then
  begin
    PropertyLen := 0;
    ConvErr := False; ////////////// is this still required ????????

    if ActualVarAndPayloadLen = 3 then
      VarHeaderLen := 3  //(Packet Identifier, then ReasonCode)
    else
      VarHeaderLen := 2; //(Packet Identifier only
  end
  else
  begin
    VarHeaderLen := 2; //(Packet Identifier, then ReasonCode)
    if not ((TempPacketType = CMQTT_SUBACK) or (TempPacketType = CMQTT_UNSUBACK)) then
      VarHeaderLen := VarHeaderLen + 1;    // there is no ReasonCode on CMQTT_SUBACK and CMQTT_UNSUBACK

    CurrentBufferPointer := CurrentBufferPointer + VarHeaderLen; //(Packet Identifier, then ReasonCode)  now, it should point to Property Length

    MemMove(@TempArr4, @ABuffer.Content^[CurrentBufferPointer], 4);
    PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);
    PropertyLen := PropertyLen + DWord(VarIntLen);

    if ConvErr then
    begin
      Result := CMQTTDecoderBadVarInt;
      FreeDynArray(ADestPacket.Header);  //free all above arrays
      Exit;
    end;

    VarHeaderLen := VarHeaderLen + PropertyLen;                   //inc by length of Properties
  end;

  if not SetDynLength(ADestPacket.VarHeader, VarHeaderLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_VarHeaderAlloc;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Exit;
  end;

  if ExpectedVarAndPayloadLen < VarHeaderLen then
  begin
    Result := CMQTTDecoderBadHeaderSize;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    FreeDynArray(ADestPacket.VarHeader);  //free all above arrays
    Exit;
  end;

  MemMove(ADestPacket.VarHeader.Content, @ABuffer.Content^[ADestPacket.Header.Len], VarHeaderLen);

  if (TempPacketType = CMQTT_SUBACK) or (TempPacketType = CMQTT_UNSUBACK) then
  begin
    if not SetDynLength(ADestPacket.Payload, ExpectedVarAndPayloadLen - VarHeaderLen) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_PayloadAlloc;
      FreeDynArray(ADestPacket.Header);  //free all above arrays
      FreeDynArray(ADestPacket.VarHeader);  //free all above arrays
      Exit;
    end;

    if ADestPacket.Payload.Len > 0 then
    begin
      CurrentBufferPointer := CurrentBufferPointer + PropertyLen;
      MemMove(ADestPacket.Payload.Content, @ABuffer.Content^[CurrentBufferPointer], ADestPacket.Payload.Len);
    end
    else
    begin
      Result := CMQTTDecoderMissingPayload;
      FreeDynArray(ADestPacket.Header);  //free all above arrays
      FreeDynArray(ADestPacket.VarHeader);  //free all above arrays
      Exit;
    end;
  end;

  Result := CMQTTDecoderNoErr;
end;


//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_CommonToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_CommonToCtrlPacket, but this time, there is no low-level validation
function Decode_Common(var AReceivedPacket: TMQTTControlPacket;
                       var ACommonFields: TMQTTCommonFields;
                       var ACommonProperties: TMQTTCommonProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen, TempPacketType, IsSubAck: Byte;
  ConvErr: Boolean;
begin
  ACommonFields.EnabledProperties := 0;
  ACommonFields.PacketIdentifier := AReceivedPacket.VarHeader.Content^[0] shl 8 + AReceivedPacket.VarHeader.Content^[1];

  ACommonFields.IncludeReasonCode := Byte(AReceivedPacket.VarHeader.Len > 2) and 1;
  if ACommonFields.IncludeReasonCode = 0 then
    ACommonFields.ReasonCode := 0
  else
    ACommonFields.ReasonCode := AReceivedPacket.VarHeader.Content^[2];

  TempPacketType := AReceivedPacket.Header.Content^[0];
  IsSubAck := 0;
  if (TempPacketType = CMQTT_SUBACK) or (TempPacketType = CMQTT_UNSUBACK) then
    IsSubAck := 1;

  if AReceivedPacket.VarHeader.Len < DWord(4 - IsSubAck) then   //This was 4, but it prevented valid SUBACK packets to be decoded. They can have a VarHeader.Len = 3.
  begin
    Result := CMQTTDecoderNoErr;
    //PropertyLen := 0;
    Exit;                //end of packet
  end;


  if IsSubAck = 1 then
    CurrentBufferPointer := 2
  else
    CurrentBufferPointer := 3;

  MemMove(@TempArr4, @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + DWord(VarIntLen);

  if PropertyLen > 0 then
    if not MQTT_Decode_CommonProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, ACommonProperties, ACommonFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if ACommonFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  if IsSubAck = 1 then
  begin
    InitDynArrayToEmpty(ACommonFields.SrcPayload);
    if not CopyFromDynArray(ACommonFields.SrcPayload, AReceivedPacket.Payload, 0, AReceivedPacket.Payload.Len) then   //the dest array is initialized by CopyFromDynArray
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_PayloadAlloc;
      Exit;
    end;
  end;

  Result := CMQTTDecoderNoErr;
end;

end.
