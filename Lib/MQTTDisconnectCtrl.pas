{
    Copyright (C) 2023 VCC
    creation date: 01 May 2023
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


unit MQTTDisconnectCtrl;

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
  DynArrays, MQTTUtils;


function FillIn_DisconnectProperties(AEnabledProperties: Word; var ADisconnectProperties: TMQTTDisconnectProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_Disconnect(var ADisconnectFields: TMQTTDisconnectFields;
                           var ADisconnectProperties: TMQTTDisconnectProperties;
                           var ADestPacket: TMQTTControlPacket): Boolean;


function Decode_DisconnectProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ADisconnectProperties: TMQTTDisconnectProperties; var AEnabledProperties: Word): Boolean;
function Valid_DisconnectPacketLength(var ABuffer: TDynArrayOfByte): Word;

//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_DisconnectToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;

//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_DisconnectToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_DisconnectToCtrlPacket, but this time, there is no low-level validation
function Decode_Disconnect(var AReceivedPacket: TMQTTControlPacket;
                           var ADisconnectFields: TMQTTDisconnectFields;
                           var ADisconnectProperties: TMQTTDisconnectProperties): Word;


implementation


function FillIn_DisconnectProperties(AEnabledProperties: Word; var ADisconnectProperties: TMQTTDisconnectProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTConnAck_EnSessionExpiryInterval = CMQTTConnAck_EnSessionExpiryInterval then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, ADisconnectProperties.SessionExpiryInterval, CMQTT_SessionExpiryInterval_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTDisconnect_EnReasonString = CMQTTDisconnect_EnReasonString then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, ADisconnectProperties.ReasonString, CMQTT_ReasonString_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTDisconnect_EnUserProperty = CMQTTDisconnect_EnUserProperty then
  begin
    Result := MQTT_AddUserPropertyToPacket(ADisconnectProperties.UserProperty, AVarHeader);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTDisconnect_EnServerReference = CMQTTDisconnect_EnServerReference then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, ADisconnectProperties.ServerReference, CMQTT_ServerReference_PropID);
    if not Result then
      Exit;
  end;

  {$IFDEF FPC}
    if AEnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
    begin
      Result := AddByteToProperties(AVarHeader, 30, CMQTT_UnknownProperty_PropID);
      if not Result then
        Exit;
    end;
  {$ENDIF}

  APropLen := AVarHeader.Len - APropLen;
  Result := True;
end;


function FillIn_DisconnectVarHeader(var ADisconnectFields: TMQTTDisconnectFields; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;

  if not AddByteToDynArray(ADisconnectFields.DisconnectReasonCode, AVarHeader) then
    Exit;

  Result := True;
end;


function FillIn_Disconnect(var ADisconnectFields: TMQTTDisconnectFields;
                           var ADisconnectProperties: TMQTTDisconnectProperties;
                           var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_DisconnectProperties(ADisconnectFields.EnabledProperties, ADisconnectProperties, TempProperties, PropLen) then
    Exit;

  if not FillIn_DisconnectVarHeader(ADisconnectFields, ADestPacket.VarHeader) then
    Exit;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
    Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  //if not ConcatDynArrays(ADestPacket.Payload, ADisconnectFields.<payload>) then  //no payload
  //  Exit;

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_DISCONNECT;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len {+ ADestPacket.Payload.Len}) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: ADisconnectProperties, AEnabledProperties
function Decode_DisconnectProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ADisconnectProperties: TMQTTDisconnectProperties; var AEnabledProperties: Word): Boolean;
var
  CurrentBufferPointer, MaxBufferPointer: DWord;
  TempBinData: TDynArrayOfByte;
  PropType: Byte;
begin
  Result := False;
  AEnabledProperties := 0;

  MaxBufferPointer := APropertiesOffset + APropertyLen;
  CurrentBufferPointer := APropertiesOffset;
  repeat
    PropType := AVarHeader.Content^[CurrentBufferPointer];
    CurrentBufferPointer := CurrentBufferPointer + 1; // SizeOf(PropType)

    case PropType of
      CMQTT_SessionExpiryInterval_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTDisconnect_EnSessionExpiryInterval;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, ADisconnectProperties.SessionExpiryInterval);
      end;

      CMQTT_ReasonString_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTDisconnect_EnReasonString;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, ADisconnectProperties.ReasonString);
      end;

      CMQTT_UserProperty_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTDisconnect_EnUserProperty;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
        if not AddDynArrayOfByteToDynOfDynOfByte(ADisconnectProperties.UserProperty, TempBinData) then
          Exit;

        FreeDynArray(TempBinData);
      end;

      CMQTT_ServerReference_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTDisconnect_EnServerReference;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, ADisconnectProperties.ServerReference);
      end

      else
      begin
        AEnabledProperties := CMQTTUnknownPropertyWord or PropType;
        Break;
      end;
    end;  //case
  until CurrentBufferPointer >= MaxBufferPointer;

  Result := True;
end;


//input args: ABuffer
//output args: ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen, AActualVarAndPayloadLen
//Result: Err
function Decode_DisconnectPacketLength(var ABuffer: TDynArrayOfByte; var ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen, AActualVarAndPayloadLen: DWord): Word;
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

  if ABuffer.Content^[0] and $0F > 0 then
  begin
    Result := CMQTTDecoderBadCtrlPacketOnDisconnect;
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

  TempErr := MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, AActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;
    Exit;
  end;
end;


function Valid_DisconnectPacketLength(var ABuffer: TDynArrayOfByte): Word;
var
  DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen: DWord;
begin
  Result := Decode_DisconnectPacketLength(ABuffer, DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if Result = CMQTTDecoderNoErr then
    if ABuffer.Len < DecodedBufferLen then
      Result := CMQTTDecoderIncompleteBuffer;
end;


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_DisconnectToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen, ActualVarAndPayloadLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, TempErr: Byte;
  ConvErr: Boolean;
begin
  TempErr := Decode_DisconnectPacketLength(ABuffer, ADecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
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

  if ActualVarAndPayloadLen < 1 then
  begin
    Result := CMQTTDecoderNoErr;
    Exit; //end of packet
  end;

  VarHeaderLen := 1;  //Disconnect Reason Code, one byte
  CurrentBufferPointer := CurrentBufferPointer + VarHeaderLen;

  MemMove(@TempArr4, @ABuffer.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);
  PropertyLen := PropertyLen + DWord(VarIntLen);

  if ConvErr then
  begin
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  VarHeaderLen := VarHeaderLen + PropertyLen;                   //inc by length of Properties

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
  Result := CMQTTDecoderNoErr;
end;


//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_DisconnectToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_DisconnectToCtrlPacket, but this time, there is no low-level validation
function Decode_Disconnect(var AReceivedPacket: TMQTTControlPacket;
                           var ADisconnectFields: TMQTTDisconnectFields;
                           var ADisconnectProperties: TMQTTDisconnectProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  ADisconnectFields.EnabledProperties := 0;

  if AReceivedPacket.Header.Content^[0] and $0F > 0 then
  begin
    Result := CMQTTDecoderBadCtrlPacketOnDisconnect;
    Exit;
  end;

  if AReceivedPacket.VarHeader.Len > 0 then
    ADisconnectFields.DisconnectReasonCode := AReceivedPacket.VarHeader.Content^[0]
  else
  begin
    Result := CMQTTDecoderNoErr;
    //PropertyLen := 0;
    ADisconnectFields.DisconnectReasonCode := 0;
    Exit;                //end of packet
  end;

  CurrentBufferPointer := 1;

  MemMove(@TempArr4, @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + DWord(VarIntLen);

  if PropertyLen > 0 then
    if not Decode_DisconnectProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, ADisconnectProperties, ADisconnectFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if ADisconnectFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;

end.
