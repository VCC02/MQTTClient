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


unit MQTTConnectCtrl;

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


function FillIn_ConnectProperties(AEnabledProperties: Word; var AConnectProperties: TMQTTConnectProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_PayloadWillProperties(var AProperties: TMQTTWillProperties; var ADestWillProperties: TDynArrayOfByte): Boolean;
function FillIn_ConnectPayload(AConnectFlags: Byte; var APayloadContent: TMQTTConnectPayloadContent; var AVarHeader: TDynArrayOfByte): Boolean;
function FillIn_Connect(var AConnectFields: TMQTTConnectFields;
                        var AConnectProperties: TMQTTConnectProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;

function Decode_ConnectProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AConnectProperties: TMQTTConnectProperties; var AEnabledProperties: Word): Boolean;
function Decode_ConnectToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function Decode_Connect(var AReceivedPacket: TMQTTControlPacket;
                        var AConnectFields: TMQTTConnectFields;
                        var AConnectProperties: TMQTTConnectProperties): Word;


implementation

{$IFDEF FPC}
  uses
    SysUtils;
{$ENDIF}

function FillIn_ConnectProperties(AEnabledProperties: Word; var AConnectProperties: TMQTTConnectProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTConnect_EnSessionExpiryInterval = CMQTTConnect_EnSessionExpiryInterval then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, AConnectProperties.SessionExpiryInterval, CMQTT_SessionExpiryInterval_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnect_EnReceiveMaximum = CMQTTConnect_EnReceiveMaximum then
  begin
    Result := AddWordToProperties(AVarHeader, AConnectProperties.ReceiveMaximum, CMQTT_ReceiveMaximum_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnect_EnMaximumPacketSize = CMQTTConnect_EnMaximumPacketSize then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, AConnectProperties.MaximumPacketSize, CMQTT_MaximumPacketSize_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnect_EnTopicAliasMaximum = CMQTTConnect_EnTopicAliasMaximum then
  begin
    Result := AddWordToProperties(AVarHeader, AConnectProperties.TopicAliasMaximum, CMQTT_TopicAliasMaximum_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnect_EnRequestResponseInformation = CMQTTConnect_EnRequestResponseInformation then
  begin
    Result := AddByteToProperties(AVarHeader, AConnectProperties.RequestResponseInformation, CMQTT_RequestResponseInformation_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTConnect_EnRequestProblemInformation = CMQTTConnect_EnRequestProblemInformation then
  begin
    Result := AddByteToProperties(AVarHeader, AConnectProperties.RequestProblemInformation, CMQTT_RequestProblemInformation_PropID);
    if not Result then
      Exit;
  end;

  {$IFDEF EnUserProperty}
    if AEnabledProperties and CMQTTConnect_EnUserProperty = CMQTTConnect_EnUserProperty then
    begin
      Result := MQTT_AddUserPropertyToPacket(AConnectProperties.UserProperty, AVarHeader);
      if not Result then
        Exit;
    end;
  {$ENDIF}

  if AEnabledProperties and CMQTTConnect_EnAuthenticationMethod = CMQTTConnect_EnAuthenticationMethod then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, AConnectProperties.AuthenticationMethod, CMQTT_AuthenticationMethod_PropID);
    if not Result then
      Exit;

    if AEnabledProperties and CMQTTConnect_EnAuthenticationData = CMQTTConnect_EnAuthenticationData then
    begin
      Result := AddBinaryDataToProperties(AVarHeader, AConnectProperties.AuthenticationData, CMQTT_AuthenticationData_PropID);
      if not Result then
        Exit;
    end;
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


function FillIn_ConnectVarHeader(AConnectFlags: Byte; AKeepAlive: Word; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;
  //VarHeader: Protocol Name, Protocol Level (Version), Connect Flags, Keep Alive, and Properties
  if not SetDynLength(AVarHeader, 10) then
    Exit;

  AVarHeader.Content^[0] := 0;
  AVarHeader.Content^[1] := 4; //Length('MQTT')
  AVarHeader.Content^[2] := Ord('M');               //Protocol Name
  AVarHeader.Content^[3] := Ord('Q');
  AVarHeader.Content^[4] := Ord('T');
  AVarHeader.Content^[5] := Ord('T');
  AVarHeader.Content^[6] := 5;  //version
  AVarHeader.Content^[7] := AConnectFlags; //bits 7-0: User Name, Password, Will Retain, Will QoS, Will, Clean Start, Reserved=0

  AVarHeader.Content^[9] := AKeepAlive and $FF;  //LSByte
  AKeepAlive := AKeepAlive shr 8;
  AVarHeader.Content^[8] := AKeepAlive and $FF;  //MSByte

  Result := True;
end;

                                                                              //ADestWillProperties is APayloadContent.WillProperties
function FillIn_PayloadWillProperties(var AProperties: TMQTTWillProperties; var ADestWillProperties: TDynArrayOfByte): Boolean;
begin
  Result := AddDoubleWordToProperties(ADestWillProperties, AProperties.WillDelayInterval, CMQTT_WillDelayInterval_PropID);
  if not Result then
    Exit;

  Result := AddByteToProperties(ADestWillProperties, AProperties.PayloadFormatIndicator, CMQTT_PayloadFormatIndicator_PropID);
  if not Result then
    Exit;

  Result := AddDoubleWordToProperties(ADestWillProperties, AProperties.MessageExpiryInterval, CMQTT_MessageExpiryInterval_PropID);
  if not Result then
    Exit;

  Result := AddBinaryDataToProperties(ADestWillProperties, AProperties.ContentType, CMQTT_ContentType_PropID);
  if not Result then
    Exit;

  Result := AddBinaryDataToProperties(ADestWillProperties, AProperties.ResponseTopic, CMQTT_ResponseTopic_PropID);
  if not Result then
    Exit;

  Result := AddBinaryDataToProperties(ADestWillProperties, AProperties.CorrelationData, CMQTT_CorrelationData_PropID);
  if not Result then
    Exit;

  {$IFDEF EnUserProperty}
    Result := MQTT_AddUserPropertyToPacket(AProperties.UserProperty, ADestWillProperties);
    if not Result then
      Exit;
  {$ENDIF}

  Result := True;
end;


function FillIn_ConnectPayload(AConnectFlags: Byte; var APayloadContent: TMQTTConnectPayloadContent; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.ClientID);
  if not Result then
    Exit;

  if AConnectFlags and CMQTT_WillFlagInConnectFlagsBitMask = CMQTT_WillFlagInConnectFlagsBitMask then
  begin
    //The Will Properties consists of a Property Length and the Properties.
    Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.WillProperties);
    if not Result then
      Exit;

    Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.WillTopic);
    if not Result then
      Exit;

    Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.WillPayload);
    if not Result then
      Exit;
  end;

  if AConnectFlags and CMQTT_UsernameInConnectFlagsBitMask = CMQTT_UsernameInConnectFlagsBitMask then
  begin
    Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.UserName);
    if not Result then
      Exit;
  end;

  if AConnectFlags and CMQTT_PasswordInConnectFlagsBitMask = CMQTT_PasswordInConnectFlagsBitMask then
  begin
    Result := AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, APayloadContent.Password);
    if not Result then
      Exit;
  end;
end;


//input args: all, except ADestPacket
//output args: ADestPacket
function FillIn_Connect(var AConnectFields: TMQTTConnectFields;
                        var AConnectProperties: TMQTTConnectProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  if not FillIn_ConnectVarHeader(AConnectFields.ConnectFlags, AConnectFields.KeepAlive, ADestPacket.VarHeader) then
    Exit;

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_ConnectProperties(AConnectFields.EnabledProperties, AConnectProperties, TempProperties, PropLen) then
    Exit;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
    Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  if not FillIn_ConnectPayload(AConnectFields.ConnectFlags, AConnectFields.PayloadContent, ADestPacket.Payload) then
    Exit;

  ////////////////////////////////  experiment here if the arrays from APayloadContent can be freed, before exiting FillIn_Connect

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_CONNECT; //no flags (bits 3-0) for CMQTT_CONNECT

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len + ADestPacket.Payload.Len) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: AConnectProperties, AEnabledProperties
function Decode_ConnectProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AConnectProperties: TMQTTConnectProperties; var AEnabledProperties: Word): Boolean;
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
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnSessionExpiryInterval;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, AConnectProperties.SessionExpiryInterval);
      end;

      CMQTT_ReceiveMaximum_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnReceiveMaximum;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, AConnectProperties.ReceiveMaximum);
      end;

      CMQTT_MaximumPacketSize_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnMaximumPacketSize;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, AConnectProperties.MaximumPacketSize);
      end;

      CMQTT_TopicAliasMaximum_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnTopicAliasMaximum;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, AConnectProperties.TopicAliasMaximum);
      end;

      CMQTT_RequestResponseInformation_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnRequestResponseInformation;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnectProperties.RequestResponseInformation);
      end;

      CMQTT_RequestProblemInformation_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnRequestProblemInformation;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, AConnectProperties.RequestProblemInformation);
      end;

      {$IFDEF EnUserProperty}
        CMQTT_UserProperty_PropID: //
        begin
          AEnabledProperties := AEnabledProperties or CMQTTConnect_EnUserProperty;
          MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
          if not AddDynArrayOfByteToDynOfDynOfByte(AConnectProperties.UserProperty, TempBinData) then
            Exit;

          FreeDynArray(TempBinData);
        end;
      {$ENDIF}

      CMQTT_AuthenticationMethod_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnAuthenticationMethod;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnectProperties.AuthenticationMethod);
      end;

      CMQTT_AuthenticationData_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTConnect_EnAuthenticationData;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, AConnectProperties.AuthenticationData);
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
//output args: ADestPacket,
//Resul: Err
function Decode_ConnectToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
const
  CMQTTString = 'MQTT';
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen, ActualVarAndPayloadLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, TempErr: Byte;
  ConvErr: Boolean;
  MQTTNameLen: Word;
  MQTTString: string[4];
begin
  Result := CMQTTDecoderNoErr;
  ADecodedBufferLen := 0;

  if ABuffer.Len = 0 then
  begin
    Result := CMQTTDecoderEmptyBuffer;
    Exit;
  end;

  {$IFnDEF IsDesktop}
    MemMove(@TempArr4[0], @ABuffer.Content^[1], 4);
  {$ELSE}
    Move(ABuffer.Content^[1], TempArr4[0], 4);
  {$ENDIF}
  ExpectedVarAndPayloadLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  if ExpectedVarAndPayloadLen = 0 then
  begin
    Result := CMQTTDecoderBadHeaderSize;
    Exit;
  end;

  FixedHeaderLen := VarIntLen + 1;
  ADecodedBufferLen := FixedHeaderLen + ExpectedVarAndPayloadLen;

  ActualVarAndPayloadLen := ABuffer.Len - FixedHeaderLen;

  TempErr := MQTT_VerifyExpectedAndActual_VarAndPayloadLen(ExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;  //set to True, to indicate that there is no memory error, it's just the protocol
    Exit;
  end;

  if not SetDynLength(ADestPacket.Header, FixedHeaderLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_HeaderAlloc;
    Exit;
  end;

  CurrentBufferPointer := 0;
  {$IFnDEF IsDesktop}
    MemMove(@ADestPacket.Header.Content^[0], @ABuffer.Content^[CurrentBufferPointer], FixedHeaderLen);
  {$ELSE}
    Move(ABuffer.Content^[CurrentBufferPointer], ADestPacket.Header.Content^[0], FixedHeaderLen);
  {$ENDIF}

  CurrentBufferPointer := CurrentBufferPointer + FixedHeaderLen;

  MQTTNameLen := ABuffer.Content^[CurrentBufferPointer] shl 8 + ABuffer.Content^[CurrentBufferPointer + 1];

  if MQTTNameLen <> 4 then
  begin
    Result := CMQTTDecoderBadHeaderSize;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + 2;

  MQTTString := CMQTTString;
  if not CompareMem(@ABuffer.Content^[CurrentBufferPointer], @MQTTString[1], 4) then
  begin
    Result := CMQTTDecoderBadCtrlPacket;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + MQTTNameLen + 4;  //+4 means: ProtocolVersion, ConnectFlags, KeepAlive

  VarHeaderLen := MQTTNameLen + 2 + 4; //+2 means string length (for 'MQTT')   +4 means: ProtocolVersion, ConnectFlags, KeepAlive

  {$IFnDEF IsDesktop}
    MemMove(@TempArr4[0], @ABuffer.Content^[CurrentBufferPointer], 4);
  {$ELSE}
    Move(ABuffer.Content^[CurrentBufferPointer], TempArr4[0], 4);
  {$ENDIF}

  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);
  CurrentBufferPointer := CurrentBufferPointer + VarIntLen;

  if ConvErr then
  begin
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  VarHeaderLen := VarHeaderLen + VarIntLen;
  VarHeaderLen := VarHeaderLen + PropertyLen;                   //inc by length of Properties

  if not SetDynLength(ADestPacket.VarHeader, VarHeaderLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_VarHeaderAlloc;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    Exit;
  end;

  if ExpectedVarAndPayloadLen < VarHeaderLen then
  begin
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    FreeDynArray(ADestPacket.VarHeader);  //free all above arrays

    Result := CMQTTDecoderBadHeaderSize;
    Exit;
  end;

  {$IFnDEF IsDesktop}
    MemMove(ADestPacket.VarHeader.Content^[0], ABuffer.Content^[ADestPacket.Header.Len], VarHeaderLen);
  {$ELSE}
    Move(ABuffer.Content^[ADestPacket.Header.Len], ADestPacket.VarHeader.Content^[0], VarHeaderLen);
  {$ENDIF}

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

    {$IFnDEF IsDesktop}
      MemMove(@ADestPacket.Payload.Content^[0], @ABuffer.Content^[CurrentBufferPointer], ADestPacket.Payload.Len);
    {$ELSE}
      Move(ABuffer.Content^[CurrentBufferPointer], ADestPacket.Payload.Content^[0], ADestPacket.Payload.Len);
    {$ENDIF}
  end;

  Result := CMQTTDecoderNoErr;
end;


//input args: AReceivedPacket
//output args: all the others
//result: Err
//this function assumes that AReceivedPacket is returned by Decode_ConnectToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_ConnectToCtrlPacket, but this time, there is no low-level validation
function Decode_Connect(var AReceivedPacket: TMQTTControlPacket;
                        var AConnectFields: TMQTTConnectFields;
                        var AConnectProperties: TMQTTConnectProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  Result := CMQTTDecoderNoErr;
  AConnectFields.EnabledProperties := 0;

  if AReceivedPacket.VarHeader.Len < 10 then
  begin
    Result := CMQTTDecoderBadCtrlPacket;
    Exit;
  end;

  AConnectFields.ProtocolVersion := AReceivedPacket.VarHeader.Content^[6];
  AConnectFields.ConnectFlags := AReceivedPacket.VarHeader.Content^[7];
  AConnectFields.KeepAlive := AReceivedPacket.VarHeader.Content^[8] shl 8 + AReceivedPacket.VarHeader.Content^[9];

  CurrentBufferPointer := 10;

  {$IFnDEF IsDesktop}
    MemMove(@TempArr4[0], @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], 4);
  {$ELSE}
    Move(AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], TempArr4[0], 4);
  {$ENDIF}

  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + DWord(VarIntLen);

  if PropertyLen > 0 then
    if not Decode_ConnectProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, AConnectProperties, AConnectFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if AConnectFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;


end.
