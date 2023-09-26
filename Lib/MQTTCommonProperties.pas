{
    Copyright (C) 2023 VCC
    creation date: 09 May 2023
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


unit MQTTCommonProperties;

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


function MQTT_FillIn_CommonProperties(AEnabledProperties: Word; var ACommonProperties: TMQTTCommonProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
function MQTT_Decode_CommonProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ACommonProperties: TMQTTCommonProperties; var AEnabledProperties: Word): Boolean;


implementation


function MQTT_FillIn_CommonProperties(AEnabledProperties: Word; var ACommonProperties: TMQTTCommonProperties; var AVarHeader: TDynArrayOfByte; var APropLen: DWord): Boolean;
begin
  Result := False;
  APropLen := AVarHeader.Len;

  if AEnabledProperties and CMQTTCommon_EnReasonString = CMQTTCommon_EnReasonString then
  begin
    Result := AddBinaryDataToProperties(AVarHeader, ACommonProperties.ReasonString, CMQTT_ReasonString_PropID);
    if not Result then
      Exit;
  end;

  if AEnabledProperties and CMQTTCommon_EnUserProperty = CMQTTCommon_EnUserProperty then
  begin
    Result := MQTT_AddUserPropertyToPacket(ACommonProperties.UserProperty, AVarHeader);
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


//input args: AVarHeader, APropertiesOffset, PropertyLen
//output args: ACommonProperties, AEnabledProperties         AEnabledProperties will have its MSB set, if an unknown property is decoded
function MQTT_Decode_CommonProperties(var AVarHeader: TDynArrayOfByte; APropertiesOffset, APropertyLen: DWord; var ACommonProperties: TMQTTCommonProperties; var AEnabledProperties: Word): Boolean;
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
      CMQTT_ReasonString_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTCommon_EnReasonString;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, ACommonProperties.ReasonString);
      end;

      CMQTT_UserProperty_PropID: //
      begin
        AEnabledProperties := AEnabledProperties or CMQTTCommon_EnUserProperty;
        MQTT_DecodeBinaryData(AVarHeader, CurrentBufferPointer, TempBinData);
        if not AddDynArrayOfByteToDynOfDynOfByte(ACommonProperties.UserProperty, TempBinData) then
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

end.
