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


unit MQTTAuthCtrl;

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


function FillIn_AuthProperties(AEnabledProperties: Word; var AAuthProperties: TMQTTAuthProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_Auth(var AAuthFields: TMQTTAuthFields;
                     var AAuthProperties: TMQTTAuthProperties;
                     var ADestPacket: TMQTTControlPacket): Boolean;

function Decode_AuthProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AAuthProperties: TMQTTAuthProperties; var AEnabledProperties: Word): Boolean;
function Valid_AuthPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;

//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_AuthToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;

//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_AuthToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_AuthToCtrlPacket, but this time, there is no low-level validation
function Decode_Auth(var AReceivedPacket: TMQTTControlPacket;
                     var AAuthFields: TMQTTAuthFields;
                     var AAuthProperties: TMQTTAuthProperties): Word;


implementation


function FillIn_AuthProperties(AEnabledProperties: Word; var AAuthProperties: TMQTTAuthProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTAuth_EnAuthenticationMethod = CMQTTAuth_EnAuthenticationMethod then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AAuthProperties.AuthenticationMethod, CMQTT_AuthenticationMethod_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTAuth_EnAuthenticationData = CMQTTAuth_EnAuthenticationData then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AAuthProperties.AuthenticationData, CMQTT_AuthenticationData_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTAuth_EnReasonString = CMQTTAuth_EnReasonString then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AAuthProperties.ReasonString, CMQTT_ReasonString_PropID);
    if not Result then
      Exit;
  end;

  {$IFDEF EnUserProperty}
    if AEnabledProperties and CMQTTAuth_EnUserProperty = CMQTTAuth_EnUserProperty then
    begin
      Result := MQTT_AddUserPropertyToPacket(AAuthProperties.UserProperty, AVarHeader);
      if not Result then
        Exit;
    end;
  {$ENDIF}

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


function FillIn_AuthVarHeader(var AAuthFields: TMQTTAuthFields; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;

  if not AddByteToDynArray(AAuthFields.AuthReasonCode, AVarHeader) then
    Exit;

  Result := True;
end;


function FillIn_Auth(var AAuthFields: TMQTTAuthFields;
                     var AAuthProperties: TMQTTAuthProperties;
                     var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_AuthProperties(AAuthFields.EnabledProperties, AAuthProperties, TempProperties, PropLen) then
    Exit;

  if PropLen > 0 then
  begin
    if not FillIn_AuthVarHeader(AAuthFields, ADestPacket.VarHeader) then
      Exit;

    if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
      Exit;
  end
  else
    if AAuthFields.AuthReasonCode > 0 then
      if not FillIn_AuthVarHeader(AAuthFields, ADestPacket.VarHeader) then
        Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  //no payload

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_AUTH;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len {+ ADestPacket.Payload.Len}) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: AAuthProperties, AEnabledProperties
function Decode_AuthProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AAuthProperties: TMQTTAuthProperties; var AEnabledProperties: Word): Boolean;
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
      CMQTT_AuthenticationMethod_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTAuth_EnAuthenticationMethod;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AAuthProperties.AuthenticationMethod);
      end;

      CMQTT_AuthenticationData_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTAuth_EnAuthenticationData;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AAuthProperties.AuthenticationData);
      end;

      CMQTT_ReasonString_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTAuth_EnReasonString;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AAuthProperties.ReasonString);
      end
      
      {$IFDEF EnUserProperty}
        ;
        CMQTT_UserProperty_PropID: //
        begin
          AEnabledProperties := AEnabledProperties or CMQTTAuth_EnUserProperty;
          MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
          if not AddDynArrayOfByteToDynOfDynOfByte(AAuthProperties.UserProperty, TempBinData) then
            Exit;

          FreeDynArray(TempBinData);
        end
      {$ENDIF}

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
function Decode_AuthPacketLength(var ABuffer: TDynArrayOfByte; var ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen, AActualVarAndPayloadLen: DWord): Word;
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

  //if ABuffer.Len < 2 then    //without this verification, the function ends up returning an invalid ADecodedBufferLen
  //begin                      //no longer needed, see how TempArr4 is initialized below:
  //  Result := CMQTTDecoderIncompleteBuffer;
  //  Exit;
  //end;

  if ABuffer.Content^[0] and $0F > 0 then
  begin
    Result := CMQTTDecoderBadCtrlPacket;
    Exit;
  end;

  InitVarIntDecoderArr(ABuffer, TempArr4);
  AExpectedVarAndPayloadLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  //if (VarIntLen > 1) and (ABuffer.Len < VarIntLen + 1) then    //without this verification, the function ends up returning an invalid ADecodedBufferLen
  //begin                                                        //no longer needed, see how TempArr4 is initialized above:
  //  Result := CMQTTDecoderIncompleteBuffer;
  //  Exit;
  //end;

  //if AExpectedVarAndPayloadLen = 0 then     //auth packets can have a 0-len VarHeader, when there is no reason code and no properties
  //begin
  //  //Result := CMQTTDecoderBadHeaderSize;
  //  Exit;
  //end;

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


function Valid_AuthPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;
var
  DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen: DWord;
begin
  Result := Decode_AuthPacketLength(ABuffer, DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if Result = CMQTTDecoderNoErr then
    if ABuffer.Len < DecodedBufferLen then
      Result := CMQTTDecoderIncompleteBuffer;

  APacketSize := DecodedBufferLen;
end;


//input args: ABuffer
//output args: ADestPacket, ADecodedBufferLen
//Result: Err
function Decode_AuthToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen, ActualVarAndPayloadLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, TempErr: Byte;
  ConvErr: Boolean;
begin
  TempErr := Decode_AuthPacketLength(ABuffer, ADecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
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

  ConvErr := False;
  VarHeaderLen := 1;  //Auth Reason Code, one byte

  if ActualVarAndPayloadLen = 1 then    //there is a reason code, but there is no property
    PropertyLen := 0
  else
  begin
    CurrentBufferPointer := CurrentBufferPointer + VarHeaderLen;    ////////////////////////////// if = 0 then set a different index

    MemMove(@TempArr4, @ABuffer.Content^[CurrentBufferPointer], 4);
    PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);
    PropertyLen := PropertyLen + DWord(VarIntLen);
  end;

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
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
//this function assumes that AReceivedPacket is returned by Decode_AuthToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_AuthToCtrlPacket, but this time, there is no low-level validation
function Decode_Auth(var AReceivedPacket: TMQTTControlPacket;
                     var AAuthFields: TMQTTAuthFields;
                     var AAuthProperties: TMQTTAuthProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  AAuthFields.EnabledProperties := 0;

  if AReceivedPacket.Header.Content^[0] and $0F > 0 then
  begin
    Result := CMQTTDecoderBadCtrlPacket;
    Exit;
  end;

  if AReceivedPacket.VarHeader.Len > 0 then
    AAuthFields.AuthReasonCode := AReceivedPacket.VarHeader.Content^[0]
  else
  begin
    Result := CMQTTDecoderNoErr;
    //PropertyLen := 0;
    AAuthFields.AuthReasonCode := 0;
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
    if not Decode_AuthProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, AAuthProperties, AAuthFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if AAuthFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;

end.
