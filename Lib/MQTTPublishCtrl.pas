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


unit MQTTPublishCtrl;

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


function FillIn_PublishProperties(AEnabledProperties: Word; var APublishProperties: TMQTTPublishProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_Publish(var APublishFields: TMQTTPublishFields;
                        var APublishProperties: TMQTTPublishProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;

function Valid_PublishPacketLength(var ABuffer: TDynArrayOfByte): Word;
function Decode_PublishToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function Decode_Publish(var AReceivedPacket: TMQTTControlPacket;
                        var APublishFields: TMQTTPublishFields;
                        var APublishProperties: TMQTTPublishProperties): Word;


implementation


function FillIn_PublishProperties(AEnabledProperties: Word; var APublishProperties: TMQTTPublishProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTPublish_EnPayloadFormatIndicator = CMQTTPublish_EnPayloadFormatIndicator then
  begin
    APublishProperties.PayloadFormatIndicator := APublishProperties.PayloadFormatIndicator and 1; //spec requirement
    Result := AddByteToProperties(AVarHeader, APublishProperties.PayloadFormatIndicator, CMQTT_PayloadFormatIndicator_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnMessageExpiryInterval = CMQTTPublish_EnMessageExpiryInterval then
  begin
    Result := AddDoubleWordToProperties(AVarHeader, APublishProperties.MessageExpiryInterval, CMQTT_MessageExpiryInterval_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnTopicAlias = CMQTTPublish_EnTopicAlias then
  begin
    if APublishProperties.TopicAlias = 0 then
      APublishProperties.TopicAlias := 1;  //spec requirement

    Result := AddWordToProperties(AVarHeader, APublishProperties.TopicAlias, CMQTT_TopicAlias_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnResponseTopic = CMQTTPublish_EnResponseTopic then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, APublishProperties.ResponseTopic, CMQTT_ResponseTopic_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnCorrelationData = CMQTTPublish_EnCorrelationData then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, APublishProperties.CorrelationData, CMQTT_CorrelationData_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnUserProperty = CMQTTPublish_EnUserProperty then
  begin
    Result := MQTT_AddUserPropertyToPacket(APublishProperties.UserProperty, AVarHeader);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnSubscriptionIdentifier = CMQTTPublish_EnSubscriptionIdentifier then
  begin
    Result := MQTT_AddSubscriptionIdentifierToPacket(APublishProperties.SubscriptionIdentifier, AVarHeader);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTPublish_EnContentType = CMQTTPublish_EnContentType then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, APublishProperties.ContentType, CMQTT_ContentType_PropID);
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


function FillIn_PublishVarHeader(AQoS: Byte; var ATopicName: TDynArrayOfByte; APacketIdentifier: Word; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;
  //VarHeader: Topic Name, Packet Identifier, and Properties

  if not AddBinaryDataToPropertiesWithoutIdentifier(AVarHeader, ATopicName) then
    Exit;

  if AQoS > 0 then   //this information is encoding in fixed header         //PacketIdentifier is not used on QoS = 0.
    AddWordToPropertiesWithoutIdentifier(AVarHeader, APacketIdentifier);

  Result := True;
end;


//input args: all, except ADestPacket
//output args: ADestPacket
function FillIn_Publish(var APublishFields: TMQTTPublishFields;
                        var APublishProperties: TMQTTPublishProperties;
                        var ADestPacket: TMQTTControlPacket): Boolean;
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
  QoS: Byte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  if not FillIn_PublishVarHeader(QoS, APublishFields.TopicName, APublishFields.PacketIdentifier, ADestPacket.VarHeader) then
    Exit;

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_PublishProperties(APublishFields.EnabledProperties, APublishProperties, TempProperties, PropLen) then
    Exit;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
    Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  if not ConcatDynArrays(ADestPacket.Payload, APublishFields.ApplicationMessage) then    //at this point, there are two arrays in memory, with the same content
    Exit;                                                                  //this simplifies the code, somehow, because later, ADestPacket.Payload is used, instead of AApplicationMessage

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_PUBLISH or (APublishFields.PublishCtrlFlags and $F);

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len + ADestPacket.Payload.Len) then
    Exit;

  Result := True;
end;


//input args: ABuffer
//output args: ADestPacket, AErr
function Decode_PublishPacketLength(var ABuffer: TDynArrayOfByte; var ADecodedBufferLen, AFixedHeaderLen, AExpectedVarAndPayloadLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  ActualVarAndPayloadLen: DWord;
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

  ActualVarAndPayloadLen := ABuffer.Len - AFixedHeaderLen;

  TempErr := MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, ActualVarAndPayloadLen);
  if TempErr <> CMQTTDecoderNoErr then
  begin
    Result := TempErr;
    Exit;
  end;
end;


function Valid_PublishPacketLength(var ABuffer: TDynArrayOfByte): Word;
var
  FixedHeaderLen, ExpectedVarAndPayloadLen, AExpectedVarAndPayloadLen: DWord;
begin
  Result := Decode_PublishPacketLength(ABuffer, FixedHeaderLen, ExpectedVarAndPayloadLen, AExpectedVarAndPayloadLen);
end;


//input args: ABuffer
//output args: ADestPacket, AErr
function Decode_PublishToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, QoS, TempErr: Byte;
  ConvErr: Boolean;
  TopicNameLen: Word;
begin
  TempErr := Decode_PublishPacketLength(ABuffer, ADecodedBufferLen, FixedHeaderLen, ExpectedVarAndPayloadLen);
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

  TopicNameLen := ABuffer.Content^[CurrentBufferPointer] shl 8 + ABuffer.Content^[CurrentBufferPointer + 1];
  TopicNameLen := TopicNameLen + 2;  //+2, because of (UTF-8) string length
  CurrentBufferPointer := CurrentBufferPointer + TopicNameLen;

  QoS := (ADestPacket.Header.Content^[0] shr 1) and 3;
  if QoS > 0 then
  begin
    if QoS = 3 then
    begin
      Result := CMQTT_Reason_MalformedPacket shl 8 or CMQTTDecoderServerErr;
      FreeDynArray(ADestPacket.Header);  //free all above arrays
      Exit;
    end;

    VarHeaderLen := TopicNameLen + 2;
    CurrentBufferPointer := CurrentBufferPointer + 2; //2 bytes for packet identifier
  end
  else
    VarHeaderLen := TopicNameLen;

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
  end;

  Result := CMQTTDecoderNoErr;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: APublishProperties, AEnabledProperties
function Decode_PublishProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var APublishProperties: TMQTTPublishProperties; var AEnabledProperties: Word): Boolean;
var
  CurrentBufferPointer, MaxBufferPointer: DWord;
  TempDWord: DWord;
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
      CMQTT_PayloadFormatIndicator_PropID: // = 1;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnPayloadFormatIndicator;
        MQTT_DecodeByte(AVarHeader, CurrentBufferPointer, APublishProperties.PayloadFormatIndicator);
      end;

      CMQTT_MessageExpiryInterval_PropID: // = 2;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnMessageExpiryInterval;
        MQTT_DecodeDoubleWord(AVarHeader, CurrentBufferPointer, APublishProperties.MessageExpiryInterval);
      end;

      CMQTT_ContentType_PropID: // = 3;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnContentType;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, APublishProperties.ContentType);
      end;

      CMQTT_ResponseTopic_PropID: // = 8;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnResponseTopic;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, APublishProperties.ResponseTopic);
      end;

      CMQTT_CorrelationData_PropID: // = 9;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnCorrelationData;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, APublishProperties.CorrelationData);
      end;

      CMQTT_SubscriptionIdentifier_PropID: // = 11;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnSubscriptionIdentifier;   // array of VarInt as DWord
        MQTT_DecodeVarInt(AVarHeader, CurrentBufferPointer, TempDWord);
        if not AddDWordToDynArraysOfDWord(APublishProperties.SubscriptionIdentifier, TempDWord) then
          Exit;
      end;

      CMQTT_TopicAlias_PropID: // = 35;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnTopicAlias;
        MQTT_DecodeWord(AVarHeader, CurrentBufferPointer, APublishProperties.TopicAlias);
      end;

      CMQTT_UserProperty_PropID: // = 38;
      begin
        AEnabledProperties := AEnabledProperties or CMQTTPublish_EnUserProperty;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
        if not AddDynArrayOfByteToDynOfDynOfByte(APublishProperties.UserProperty, TempBinData) then
          Exit;

        FreeDynArray(TempBinData);
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


//input args: AReceivedPacket
//output args: all the others
//this function assumes that AReceivedPacket is returned by Decode_PublishToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_PublishToCtrlPacket, but this time, there is no low-level validation
function Decode_Publish(var AReceivedPacket: TMQTTControlPacket;
                        var APublishFields: TMQTTPublishFields;
                        var APublishProperties: TMQTTPublishProperties): Word;
var
  QoS: Byte;
  CurrentBufferPointer, TopicNameLen, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  APublishFields.EnabledProperties := 0;

  APublishFields.PublishCtrlFlags := AReceivedPacket.Header.Content^[0] and $F;
  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;

  CurrentBufferPointer := 0;
  TopicNameLen := AReceivedPacket.VarHeader.Content^[0] shl 8 + AReceivedPacket.VarHeader.Content^[1];

  if not SetDynLength(APublishFields.TopicName, TopicNameLen) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_TopicNameAlloc;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + 2; //+2, because of (UTF-8) string length
  MemMove(APublishFields.TopicName.Content, @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], APublishFields.TopicName.Len);

  CurrentBufferPointer := CurrentBufferPointer + TopicNameLen;

  if QoS > 0 then
  begin
    APublishFields.PacketIdentifier := AReceivedPacket.VarHeader.Content^[CurrentBufferPointer] shl 8 + AReceivedPacket.VarHeader.Content^[CurrentBufferPointer + 1];
    CurrentBufferPointer := CurrentBufferPointer + 2;
  end
  else
    APublishFields.PacketIdentifier := 0;

  MemMove(@TempArr4, @AReceivedPacket.VarHeader.Content^[CurrentBufferPointer], 4);
  PropertyLen := VarIntToDWord(TempArr4, VarIntLen, ConvErr);

  if ConvErr then
  begin
    Result := CMQTTDecoderBadVarInt;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + DWord(VarIntLen);

  if PropertyLen > 0 then
    if not Decode_PublishProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, APublishProperties, APublishFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if APublishFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  CurrentBufferPointer := CurrentBufferPointer + PropertyLen;

  if not SetDynLength(APublishFields.ApplicationMessage, AReceivedPacket.Payload.Len) then
  begin
    Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_ApplicationMessageAlloc;
    Exit;
  end;

  MemMove(APublishFields.ApplicationMessage.Content, AReceivedPacket.Payload.Content, AReceivedPacket.Payload.Len);    //a bit of memory waste, but it allows discarding the entire AReceivedPacket after the call to Decode_Publish
  Result := CMQTTDecoderNoErr;
end;

end.
