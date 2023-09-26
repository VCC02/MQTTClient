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


unit MQTTUnsubscribeCtrl;

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
  DynArrays, MQTTUtils, MQTTSubscribeCtrl;


function FillIn_UnsubscribeProperties(AEnabledProperties: Word; var AUnsubscribeProperties: TMQTTUnsubscribeProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function FillIn_UnsubscribePayload({$IFnDEF FPC} var {$ENDIF} AContent: string; var ADestPayload: TDynArrayOfByte): Boolean;
function FillIn_Unsubscribe(var AUnsubscribeFields: TMQTTUnsubscribeFields;
                            var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                            var ADestPacket: TMQTTControlPacket): Boolean;        //The payload should be passed to FillIn_Unsubscribe, through AUnsubscribeFields.TopicFilters.

function Decode_UnsubscribeProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AUnsubscribeProperties: TMQTTUnsubscribeProperties; var AEnabledProperties: Word): Boolean;
function Decode_UnsubscribePayload(var ASrcPayload: TDynArrayOfByte; var ADestTopics: TDynArrayOfTDynArrayOfByte): Word;

//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_UnsubscribeToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;

//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_UnsubscribeToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_UnsubscribeToCtrlPacket, but this time, there is no low-level validation
function Decode_Unsubscribe(var AReceivedPacket: TMQTTControlPacket;
                            var AUnsubscribeFields: TMQTTUnsubscribeFields;
                            var AUnsubscribeProperties: TMQTTUnsubscribeProperties): Word;

implementation


function FillIn_UnsubscribeProperties(AEnabledProperties: Word; var AUnsubscribeProperties: TMQTTUnsubscribeProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTUnsubscribe_EnUserProperty = CMQTTUnsubscribe_EnUserProperty then
  begin
    Result := MQTT_AddUserPropertyToPacket(AUnsubscribeProperties.UserProperty, AVarHeader);
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


function FillIn_UnsubscribePayload({$IFnDEF FPC} var {$ENDIF} AContent: string; var ADestPayload: TDynArrayOfByte): Boolean;
begin
  Result := AddUTF8StringToPropertiesWithoutIdentifier(ADestPayload, AContent);
end;


function FillIn_Unsubscribe(var AUnsubscribeFields: TMQTTUnsubscribeFields;
                            var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                            var ADestPacket: TMQTTControlPacket): Boolean;        //The payload should be passed to FillIn_Unsubscribe, through AUnsubscribeFields.TopicFilters.
var
  PropLen: DWord;
  TempProperties: TDynArrayOfByte;
begin
  Result := False;
  MQTT_InitControlPacket(ADestPacket);

  InitDynArrayToEmpty(TempProperties);
  if not FillIn_UnsubscribeProperties(AUnsubscribeFields.EnabledProperties, AUnsubscribeProperties, TempProperties, PropLen) then
    Exit;

  if not FillIn_SubscribeVarHeader(AUnsubscribeFields, ADestPacket.VarHeader) then
    Exit;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.VarHeader, PropLen) then
    Exit;

  if not ConcatDynArrays(ADestPacket.VarHeader, TempProperties) then
    Exit;

  FreeDynArray(TempProperties);

  if not ConcatDynArrays(ADestPacket.Payload, AUnsubscribeFields.TopicFilters) then
    Exit;

  if not SetDynLength(ADestPacket.Header, 1) then
    Exit;
  ADestPacket.Header.Content^[0] := CMQTT_UNSUBSCRIBE or 2;

  if not AddVarIntAsDWordToPropertiesWithoutIdentifier(ADestPacket.Header, ADestPacket.VarHeader.Len + ADestPacket.Payload.Len) then
    Exit;

  Result := True;
end;


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: AUnsubscribeProperties, AEnabledProperties
function Decode_UnsubscribeProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var AUnsubscribeProperties: TMQTTUnsubscribeProperties; var AEnabledProperties: Word): Boolean;
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
      CMQTT_UserProperty_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTUnsubscribe_EnUserProperty;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
        if not AddDynArrayOfByteToDynOfDynOfByte(AUnsubscribeProperties.UserProperty, TempBinData) then
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


function Decode_UnsubscribePayload(var ASrcPayload: TDynArrayOfByte; var ADestTopics: TDynArrayOfTDynArrayOfByte): Word;
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
  until CurrentBufferPointer >= ASrcPayload.Len;

  Result := CMQTTDecoderNoErr;
end;


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_UnsubscribeToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
begin
  Result := Decode_SubscribeToCtrlPacket(ABuffer, ADestPacket, ADecodedBufferLen);
end;


//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_UnsubscribeToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_UnsubscribeToCtrlPacket, but this time, there is no low-level validation
function Decode_Unsubscribe(var AReceivedPacket: TMQTTControlPacket;
                            var AUnsubscribeFields: TMQTTUnsubscribeFields;
                            var AUnsubscribeProperties: TMQTTUnsubscribeProperties): Word;
var
  CurrentBufferPointer, PropertyLen: DWord;
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  AUnsubscribeFields.EnabledProperties := 0;
  AUnsubscribeFields.PacketIdentifier := AReceivedPacket.VarHeader.Content^[0] shl 8 + AReceivedPacket.VarHeader.Content^[1];

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
    if not Decode_UnsubscribeProperties(AReceivedPacket.VarHeader, CurrentBufferPointer, PropertyLen, AUnsubscribeProperties, AUnsubscribeFields.EnabledProperties) then
    begin
      Result := CMQTTDecoderOutOfMemory or CMQTT_OOM_DecodeProperties;
      Exit;
    end;

  if AUnsubscribeFields.EnabledProperties and CMQTTUnknownPropertyWord = CMQTTUnknownPropertyWord then
  begin
    Result := CMQTTDecoderUnknownProperty;
    Exit;
  end;

  Result := CMQTTDecoderNoErr;
end;


end.
