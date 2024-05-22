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


unit MQTTConnAckCtrl;

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


function FillIn_ConnAckProperties(AEnabledProperties: DWord; var AConnAckProperties: TMQTTConnAckProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_ConnAck(var AConnAckFields: TMQTTConnAckFields;
                        var AConnAckProperties: TMQTTConnAckProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;

function Decode_ConnAckProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AConnAckProperties: TMQTTConnAckProperties; var AEnabledProperties: DWord): Boolean;
function Valid_ConnAckPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;
function Decode_ConnAckToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function Decode_ConnAck(var AReceivedPacket: TMQTTControlPacket;
                        var AConnAckFields: TMQTTConnAckFields;  //bits 7-1 are reserved. Bit 0 is the Session Present flag
                        var AConnAckProperties: TMQTTConnAckProperties): Word;


{$IFDEF IsDesktop}
  type
    TMQTTConnAckPropertiesArr = array of TMQTTConnAckProperties;
{$ENDIF}


implementation


function FillIn_ConnAckProperties(AEnabledProperties: DWord; var AConnAckProperties: TMQTTConnAckProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTConnAck_EnSessionExpiryInterval = CMQTTConnAck_EnSessionExpiryInterval then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, AConnAckProperties.SessionExpiryInterval, CMQTT_SessionExpiryInterval_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnReceiveMaximum = CMQTTConnAck_EnReceiveMaximum then
  begin
    Result := AddWordToProperties(AVarHeader, AConnAckProperties.ReceiveMaximum, CMQTT_ReceiveMaximum_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnMaximumQoS = CMQTTConnAck_EnMaximumQoS then
  begin
    AConnAckProperties.MaximumQoS := AConnAckProperties.MaximumQoS and 1; //spec requirement

    Result := AddByteToProperties(AVarHeader, AConnAckProperties.MaximumQoS, CMQTT_MaximumQoS_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnRetainAvailable = CMQTTConnAck_EnRetainAvailable then
  begin
    Result := AddByteToProperties(AVarHeader, AConnAckProperties.RetainAvailable, CMQTT_RetainAvailable_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnMaximumPacketSize = CMQTTConnAck_EnMaximumPacketSize then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, AConnAckProperties.MaximumPacketSize, CMQTT_MaximumPacketSize_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnAssignedClientIdentifier = CMQTTConnAck_EnAssignedClientIdentifier then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.AssignedClientIdentifier, CMQTT_AssignedClientIdentifier_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnTopicAliasMaximum = CMQTTConnAck_EnTopicAliasMaximum then
  begin
    Result := AddWordToProperties(AVarHeader, AConnAckProperties.TopicAliasMaximum, CMQTT_TopicAliasMaximum_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnReasonString = CMQTTConnAck_EnReasonString then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.ReasonString, CMQTT_ReasonString_PropID);
    if not Result then
      Exit;
  end;

  {$IFDEF EnUserProperty}
    if AEnabledProperties and CMQTTConnAck_EnUserProperty = CMQTTConnAck_EnUserProperty then
    begin
      Result := MQTT_AddUserPropertyToPacket(AConnAckProperties.UserProperty, AVarHeader);
      if not Result then
        Exit;
    end;
  {$ENDIF}

  if AEnabledProperties and CMQTTConnAck_EnWildcardSubscriptionAvailable = CMQTTConnAck_EnWildcardSubscriptionAvailable then
  begin
    Result := AddByteToProperties(AVarHeader, AConnAckProperties.WildcardSubscriptionAvailable, CMQTT_WildcardSubscriptionAvailable_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnSubscriptionIdentifierAvailable = CMQTTConnAck_EnSubscriptionIdentifierAvailable then
  begin
    Result := AddByteToProperties(AVarHeader, AConnAckProperties.SubscriptionIdentifierAvailable, CMQTT_SubscriptionIdentifierAvailable_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnSharedSubscriptionAvailable = CMQTTConnAck_EnSharedSubscriptionAvailable then
  begin
    Result := AddByteToProperties(AVarHeader, AConnAckProperties.SharedSubscriptionAvailable, CMQTT_SharedSubscriptionAvailable_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnServerKeepAlive = CMQTTConnAck_EnServerKeepAlive then
  begin
    Result := AddWordToProperties(AVarHeader, AConnAckProperties.ServerKeepAlive, CMQTT_ServerKeepAlive_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnResponseInformation = CMQTTConnAck_EnResponseInformation then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.ResponseInformation, CMQTT_ResponseInformation_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnServerReference = CMQTTConnAck_EnServerReference then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.ServerReference, CMQTT_ServerReference_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnAuthenticationMethod = CMQTTConnAck_EnAuthenticationMethod then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.AuthenticationMethod, CMQTT_AuthenticationMethod_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnAck_EnAuthenticationData = CMQTTConnAck_EnAuthenticationData then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnAckProperties.AuthenticationData, CMQTT_AuthenticationData_PropID);
    if not Result then
      Exit;
  end;

  {$IFDEF FPC}
    if AEnabledProperties and CMQTTUnknownPropertyDoubleWord = CMQTTUnknownPropertyDoubleWord then
    begin
      Result := AddByteToProperties(AVarHeader, 30, CMQTT_UnknownProperty_PropID);
      if not Result then
        Exit;
    end;
  {$ENDIF}

  APropLen := AVarHeader.Len - APropLen;
  Result := True;
end;


function FillIn_ConnAckVarHeader(SessionPresentFlag, ConnectReasonCode: Byte; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;
  //VarHeader: Connect Acknowledge Flags, Connect Reason Code

  if not SetDynLength(AVarHeader, 2) then
    Exit;

  AVarHeader.Content^[0] := SessionPresentFlag and 1;
  AVarHeader.Content^[1] := ConnectReasonCode;

  Result := True;
end;


//input args: all, except ADestPacket
//output args: ADestPacket
function FillIn_ConnAck(var AConnAckFields: TMQTTConnAckFields;
                        var AConnAckProperties: TMQTTConnAckProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  if not FillIn_ConnAckVarHeader(AConnAckFields.SessionPresentFlag, AConnAckFields.ConnectReasonCode, ADestPacket.VarHeader) then
    Exit;

  if AConnAckFields.ConnectReasonCode < 128 then
  begin
    InitDynArrayToEmpty(TempProperties);
    if not FillIn_ConnAckProperties(AConnAckFields.EnabledProperties, AConnAckProperties, TempProperties, PropLen) then
      Exit;

    if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
      Exit;

    if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
      Exit;

    FreeDynArray(TempProperties);
  end;

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_CONNACK;
                                                                                                     //no payload
  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len {+ ADestPacket.Payload.Len}) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: AConnAckProperties, AEnabledProperties
function Decode_ConnAckProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AConnAckProperties: TMQTTConnAckProperties; var AEnabledProperties: DWord): Boolean;
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
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnSessionExpiryInterval;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, AConnAckProperties.SessionExpiryInterval);
      end;

      CMQTT_ReceiveMaximum_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnReceiveMaximum;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, AConnAckProperties.ReceiveMaximum);
      end;

      CMQTT_MaximumQoS_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnMaximumQoS;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnAckProperties.MaximumQoS);
      end;

      CMQTT_RetainAvailable_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnRetainAvailable;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnAckProperties.RetainAvailable);
      end;

      CMQTT_MaximumPacketSize_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnMaximumPacketSize;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, AConnAckProperties.MaximumPacketSize);
      end;

      CMQTT_AssignedClientIdentifier_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnAssignedClientIdentifier;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.AssignedClientIdentifier);
      end;

      CMQTT_TopicAliasMaximum_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnTopicAliasMaximum;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, AConnAckProperties.TopicAliasMaximum);
      end;

      CMQTT_ReasonString_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnReasonString;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.ReasonString);
      end;

      {$IFDEF EnUserProperty}
        CMQTT_UserProperty_PropID: //
        begin
          AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnUserProperty;
          MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
          if not AddDynArrayOfByteToDynOfDynOfByte(AConnAckProperties.UserProperty, TempBinData) then
            Exit;

          FreeDynArray(TempBinData);
        end;
      {$ENDIF}

      CMQTT_WildcardSubscriptionAvailable_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnWildcardSubscriptionAvailable;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnAckProperties.WildcardSubscriptionAvailable);
      end;

      CMQTT_SubscriptionIdentifierAvailable_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnSubscriptionIdentifierAvailable;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnAckProperties.SubscriptionIdentifierAvailable);
      end;

      CMQTT_SharedSubscriptionAvailable_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnSharedSubscriptionAvailable;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnAckProperties.SharedSubscriptionAvailable);
      end;

      CMQTT_ServerKeepAlive_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnServerKeepAlive;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, AConnAckProperties.ServerKeepAlive);
      end;

      CMQTT_ResponseInformation_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnResponseInformation;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.ResponseInformation);
      end;

      CMQTT_ServerReference_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnServerReference;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.ServerReference);
      end;

      CMQTT_AuthenticationMethod_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnAuthenticationMethod;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.AuthenticationMethod);
      end;

      CMQTT_AuthenticationData_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnAck_EnAuthenticationData;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnAckProperties.AuthenticationData);
      end

      else
      begin
        AEnabledProperties := CMQTTUnknownPropertyDoubleWord or PropType;
        Break;
      end;
    end;  //case
  until CurrentBufferPointer >= MaxBufferPointer;

  Result := True;
end;


//input args: ABuffer
//output args: ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen
//Result: Err
function Decode_ConnAckPacketLength(var ABuffer: TDynArrayOfByte; var ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  ActualVarAndPayloadLen: DWord;
  VarIntLen: Byte;
  TempErr: Word;
  ConvErr: Boolean;
begin
  Result := CMQTTDecoderNoErr;
  ADecodedBufferLen := 0;

  if ABuffer.Len = 0 then
  begin
    Result := CMQTTDecoderEmptyBuffer;
    Exit;
  end;

  //if ABuffer.Len < 4 then    //without this verification, the function ends up returning an invalid ADecodedBufferLen
  //begin                      //no longer needed, see how TempArr4 is initialized below:
  //  Result := CMQTTDecoderIncompleteBuffer;
  //  Exit;
  //end;

  InitVarIntDecoderArr(ABuffer, TempArr4);
  AExpectedVarAndPayloadLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);    //this is more of the VarHeader length, because there is no payload

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

  AFixedHeaderLen := VarIntLen + 1;    //the fixed header should be 2 bytes long
  ADecodedBufferLen := AFixedHeaderLen + AExpectedVarAndPayloadLen;

  //the returned error code could be verified here, but the fixed header is empty at this point, so the function would not return useful info

  ActualVarAndPayloadLen := ABuffer.Len - AFixedHeaderLen;

  TempErr := MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;
    Exit;
  end;
end;


function Valid_ConnAckPacketLength(var ABuffer: TDynArrayOfByte; var APacketSize: DWord): Word;
var
  DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen: DWord;
begin
  Result := Decode_ConnAckPacketLength(ABuffer, DecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen);
  if Result = CMQTTDecoderNoErr then
    if ABuffer.Len < DecodedBufferLen then
      Result := CMQTTDecoderIncompleteBuffer;

  APacketSize := DecodedBufferLen;
end;


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_ConnAckToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen: DWord;
  CurrentBufferPointer, PropertyLen: DWord;
  VarIntLen, ConnectReasonCode: Byte;
  TempErr: Word;
  ConvErr: Boolean;
begin
  TempErr := Decode_ConnAckPacketLength(ABuffer, ADecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen);
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

  MemMove(ADestPacket.Header.Content, ABuffer.Content, FixedHeaderLen);

  ConnectReasonCode := ABuffer.Content^[FixedHeaderLen + 1];    //verifying error code after setting FixedHeader content
  TempErr := ConnectReasonCode shl 8;

  if ConnectReasonCode >= 128 then
  begin
    TempErr := TempErr + CMQTTDecoderServerErr;

    if not SetDynLength(ADestPacket.VarHeader, 2) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_VarHeaderAlloc;
      Exit;   //the Result is False here
    end;

    MemMove(ADestPacket.VarHeader.Content, @ABuffer.Content^[ADestPacket.Header.Len], 2); //copy the two main bytes of the var header (there should be no properties in this case)

    Result := TempErr;
    Exit;
  end;

  CurrentBufferPointer := FixedHeaderLen + 2;  // + 2, because of the two fixed bytes from VarHeader, before properties
  MemMove(@TempArr4, @ABuffer.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  VarHeaderLen := PropertyLen + DWord(VarIntLen) + 2;                   //inc by length of Properties

  if not SetDynLength(ADestPacket.VarHeader, VarHeaderLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_VarHeaderAlloc;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Exit;
  end;
                                               //feature is disabled, to allow having multiple packets in a single buffer
  if (ExpectedVarAndPayloadLen < VarHeaderLen) {or (VarHeaderLen <> ActualVarAndPayloadLen)} then
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
//Resukt: Err
//this function assumes that AReceivedPacket is returned by Decode_ConnAckToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_ConnAckToCtrlPacket, but this time, there is no low-level validation
function Decode_ConnAck(var AReceivedPacket: TMQTTControlPacket;
                        var AConnAckFields: TMQTTConnAckFields;
                        var AConnAckProperties: TMQTTConnAckProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  AConnAckFields.EnabledProperties := 0;

  AConnAckFields.SessionPresentFlag := AReceivedPacket.VarHeader.Content^[0] and 1;
  AConnAckFields.ConnectReasonCode := AReceivedPacket.VarHeader.Content^[1];   //success or error codes
  Result := AConnAckFields.ConnectReasonCode shl 8; //because this result contains a reason code, the lower byte should be checked for error

  if AConnAckFields.ConnectReasonCode >= 128 then   //any value for ConnectReasonCode, less than 128, means success
  begin
    Result := Result + CMQTTDecoderServerErr;
    Exit;
  end;

  CurrentBufferPointer := 2;

  MemMove(@TempArr4, @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + DWord(VarIntLen);

  if PropertyLen > 0 then
    if not Decode_ConnAckProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, AConnAckProperties, AConnAckFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if AConnAckFields.EnabledProperties and CMQTTUnknownPropertyDoubleWord = CMQTTUnknownPropertyDoubleWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  //do not set Result here to 0, because it is already set to ConnectReasonCode
end;


end.
