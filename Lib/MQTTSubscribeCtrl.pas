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


unit MQTTSubscribeCtrl;

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


function FillIn_SubscribeProperties(AEnabledProperties: Word; var ASubscribeProperties: TMQTTSubscribeProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_SubscribePayload({$IFnDEF FPC} var {$ENDIF} AContent: string; ASubscriptionOptions: Byte; var ADestPayload: TDynArrayOfByte): Boolean;
function FillIn_SubscribeVarHeader(var ASubscribeFields: TMQTTSubscribeFields; var AVarHeader: TDynArrayOfByte): Boolean;
function FillIn_Subscribe(var ASubscribeFields: TMQTTSubscribeFields;
                          var ASubscribeProperties: TMQTTSubscribeProperties;
                          var ADestPacket: TMQTTControlPacket): Boolean;       //The payload should be passed to FillIn_Subscribe, through ASubscribeFields.TopicFilters.


function Decode_SubscribeProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ASubscribeProperties: TMQTTSubscribeProperties; var AEnabledProperties: Word): Boolean;
//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_SubscribeToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function DecodeTopicNames(var ASrcPayload: TDynArrayOfByte; var ACurrentBufferPointer: DWord; var ADestTopics: TDynArrayOfTDynArrayOfByte): Boolean;
function Decode_SubscribePayload(var ASrcPayload: TDynArrayOfByte; var ADestTopics: TDynArrayOfTDynArrayOfByte; var ADestSubscriptionOptions: TDynArrayOfByte): Word;  //ADestTopics and ADestSubscriptionOptions will have the same length (if there is no error) and their items are "related" by index
function Decode_Subscribe(var AReceivedPacket: TMQTTControlPacket;
                          var ASubscribeFields: TMQTTSubscribeFields;
                          var ASubscribeProperties: TMQTTSubscribeProperties): Word;


implementation


function FillIn_SubscribeProperties(AEnabledProperties: Word; var ASubscribeProperties: TMQTTSubscribeProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTSubscribe_EnSubscriptionIdentifier = CMQTTSubscribe_EnSubscriptionIdentifier then
  begin
    if ASubscribeProperties.SubscriptionIdentifier.Len > 0 then   //only one identifier is expected for Subscribe packet
    begin
      Result := AddVarIntAsDWordToProperties(AVarHeader, ASubscribeProperties.SubscriptionIdentifier.Content^[0], CMQTT_SubscriptionIdentifier_PropID);
      if not Result then
        Exit;
    end;
  end;

  if AEnabledProperties and CMQTTSubscribe_EnUserProperty = CMQTTSubscribe_EnUserProperty then
  begin
    Result := MQTT_AddUserPropertyToPacket(ASubscribeProperties.UserProperty, AVarHeader);
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


function FillIn_SubscribePayload({$IFnDEF FPC} var {$ENDIF} AContent: string; ASubscriptionOptions: Byte; var ADestPayload: TDynArrayOfByte): Boolean;
begin
  Result := AddUTF8StringToPropertiesWithoutIdentifier(ADestPayload, AContent);
  if not Result then
    Exit;

  Result := AddByteToDynArray(ASubscriptionOptions, ADestPayload);
end;


function FillIn_SubscribeVarHeader(var ASubscribeFields: TMQTTSubscribeFields; var AVarHeader: TDynArrayOfByte): Boolean;
begin
  Result := False;

  if not AddWordToPropertiesWithoutIdentifier(AVarHeader, ASubscribeFields.PacketIdentifier) then
    Exit;

  Result := True;
end;


function FillIn_Subscribe(var ASubscribeFields: TMQTTSubscribeFields;
                          var ASubscribeProperties: TMQTTSubscribeProperties;
                          var ADestPacket: TMQTTControlPacket): Boolean;        //The payload should be passed to FillIn_Subscribe, through ASubscribeFields.TopicFilters.
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_SubscribeProperties(ASubscribeFields.EnabledProperties, ASubscribeProperties, TempProperties, PropLen) then
    Exit;

  if not FillIn_SubscribeVarHeader(ASubscribeFields, ADestPacket.VarHeader) then
    Exit;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
    Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  if not ConcatDynArrays(ADestPacket.Payload, ASubscribeFields.TopicFilters) then
    Exit;

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_SUBSCRIBE;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len + ADestPacket.Payload.Len) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: ASubscribeProperties, AEnabledProperties
function Decode_SubscribeProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ASubscribeProperties: TMQTTSubscribeProperties; var AEnabledProperties: Word): Boolean;
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
      CMQTT_SubscriptionIdentifier_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTSubscribe_EnSubscriptionIdentifier;
        SetDynOfDWordLength(ASubscribeProperties.SubscriptionIdentifier, 1); //use Len + 1, to detect if multiple identifier properties are received, then count them
        MQTT_DecodeVarInt(AVarHeader, CurrentBufferPointer, ASubscribeProperties.SubscriptionIdentifier.Content^[0]);
      end;

      CMQTT_UserProperty_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTSubscribe_EnUserProperty;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
        if not AddDynArrayOfByteToDynOfDynOfByte(ASubscribeProperties.UserProperty, TempBinData) then
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


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_SubscribeToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
var
  TempArr4: T4ByteArray;
  FixedHeaderLen, ExpectedVarAndPayloadLen, VarHeaderLen, PropertyLen, ActualVarAndPayloadLen: DWord;
  CurrentBufferPointer: DWord;
  VarIntLen, TempErr: Byte;
  ConvErr: Boolean;
begin
  ADecodedBufferLen := 0;

  if ABuffer.Len = 0 then
  begin
    Result := CMQTTDecoderEmptyBuffer;
    Exit;
  end;

  MemMove(@TempArr4, @ABuffer.Content^[1], 4);
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

  VarHeaderLen := 2;  //Packet Identifier, two bytes
  CurrentBufferPointer := CurrentBufferPointer + VarHeaderLen;

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
  end
  else
  begin
    Result := CMQTTDecoderMissingPayload;
    FreeDynArray(ADestPacket.Header);  //free all above arrays
    FreeDynArray(ADestPacket.VarHeader);  //free all above arrays
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;


function DecodeTopicNames(var ASrcPayload: TDynArrayOfByte; var ACurrentBufferPointer: DWord; var ADestTopics: TDynArrayOfTDynArrayOfByte): Boolean;
var
  TopicLen: DWord;
  TempTopicFilter: TDynArrayOfByte;
begin
  Result := False;
  TopicLen := ASrcPayload.Content^[ACurrentBufferPointer] shl 8 + ASrcPayload.Content^[ACurrentBufferPointer + 1];

  ACurrentBufferPointer := ACurrentBufferPointer + 2; //the length is fixed to two bytes, because a string is expected

  InitDynArrayToEmpty(TempTopicFilter);
  if not SetDynLength(TempTopicFilter, TopicLen) then
    Exit;

  MemMove(TempTopicFilter.Content, @ASrcPayload.Content^[ACurrentBufferPointer], TopicLen);

  if not AddDynArrayOfByteToDynOfDynOfByte(ADestTopics, TempTopicFilter) then
  begin
    FreeDynArray(TempTopicFilter);
    Exit;
  end;

  FreeDynArray(TempTopicFilter);
  ACurrentBufferPointer := ACurrentBufferPointer + TopicLen;
  Result := True;
end;


function Decode_SubscribePayload(var ASrcPayload: TDynArrayOfByte; var ADestTopics: TDynArrayOfTDynArrayOfByte; var ADestSubscriptionOptions: TDynArrayOfByte): Word;
var
  CurrentBufferPointer: DWord;
begin
  if ASrcPayload.Len = 0 then
  begin
    Result := CMQTTDecoderNoErr;
    Exit;
  end;

  CurrentBufferPointer := 0;
  repeat
    if not DecodeTopicNames(ASrcPayload, CurrentBufferPointer, ADestTopics) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeTopicNames;
      Exit;
    end;

    if not AddByteToDynArray(ASrcPayload.Content^[CurrentBufferPointer], ADestSubscriptionOptions) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_SubscriptionOptionsAlloc;
      Exit;
    end;

    CurrentBufferPointer := CurrentBufferPointer + 1; //one byte: ADestSubscriptionOptions
  until CurrentBufferPointer >= ASrcPayload.Len;

  Result := CMQTTDecoderNoErr;
end;


//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_SubscribeToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_SubscribeToCtrlPacket, but this time, there is no low-level validation
function Decode_Subscribe(var AReceivedPacket: TMQTTControlPacket;
                          var ASubscribeFields: TMQTTSubscribeFields;
                          var ASubscribeProperties: TMQTTSubscribeProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  ASubscribeFields.EnabledProperties := 0;
  ASubscribeFields.PacketIdentifier := AReceivedPacket.VarHeader.Content^[0] shl 8 + AReceivedPacket.VarHeader.Content^[1];

  if AReceivedPacket.VarHeader.Len < 3 then
  begin
    Result := CMQTTDecoderNoErr;
    //PropertyLen := 0;
    Exit;                //end of packet
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
    if not Decode_SubscribeProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, ASubscribeProperties, ASubscribeFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if ASubscribeFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;

end.
