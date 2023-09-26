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


unit MQTTPubCompCtrl;

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
  DynArrays, MQTTUtils, MQTTCommonCodecCtrl;


function FillIn_PubComp(var APubCompFields: TMQTTPubCompFields;
                       var APubCompProperties: TMQTTPubCompProperties;
                       var ADestPacket: TMQTTControlPacket): Boolean;


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_PubCompToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
function Decode_PubComp(var AReceivedPacket: TMQTTControlPacket;
                       var APubCompFields: TMQTTPubCompFields;
                       var APubCompProperties: TMQTTPubCompProperties): Word;

implementation


//input args: all, except ADestPacket
//output args: ADestPacket
function FillIn_PubComp(var APubCompFields: TMQTTPubCompFields;
                       var APubCompProperties: TMQTTPubCompProperties;
                       var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Common(APubCompFields, APubCompProperties, CMQTT_PUBCOMP, ADestPacket);
end;                                                      //CMQTT_PUBCOMP is the packet specific argument


//input args: ABuffer
//output args: ADestPacket
//Result: Err
function Decode_PubCompToCtrlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var ADecodedBufferLen: DWord): Word;
begin
  Result := Decode_CommonToCtrlPacket(ABuffer, ADestPacket, ADecodedBufferLen);
end;


//input args: AReceivedPacket
//output args: all the others
//Result: Err
//this function assumes that AReceivedPacket is returned by Decode_PubCompToCtrlPacket  (and there is no error)
//some calculations are also made in Decode_PubCompToCtrlPacket, but this time, there is no low-level validation
function Decode_PubComp(var AReceivedPacket: TMQTTControlPacket;
                       var APubCompFields: TMQTTPubCompFields;
                       var APubCompProperties: TMQTTPubCompProperties): Word;
begin
  Result := Decode_Common(AReceivedPacket, APubCompFields, APubCompProperties);
end;

end.

