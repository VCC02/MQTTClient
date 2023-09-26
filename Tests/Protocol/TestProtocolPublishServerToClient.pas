{
    Copyright (C) 2023 VCC
    creation date: 25 Sep 2023
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


unit TestProtocolPublishServerToClient;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TTestProtocolReceivePublishCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;

  published
    //procedure TestClientToServerBufferContent_AfterConnAck_OnePacket;

  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils, DynArrays, MQTTPublishCtrl,
  Expectations, ExpectationsDynArrays;


type
  TMQTTPublishPropertiesArr = array of TMQTTPublishProperties;

var
  FieldsToSend: TMQTTPublishFields;
  PropertiesToSend: TMQTTPublishProperties;
  DestPacket: TMQTTControlPacket;

  DecodedPublishFields: TMQTTPublishFields;
  DecodedPublishPropertiesArr: TMQTTPublishPropertiesArr;

  FoundError: Word;
  ErrorOnPacketType: Byte;

                                             //The lower word identifies the client instance
procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var APublishFields: TMQTTPublishFields; var APublishProperties: TMQTTPublishProperties);
var
  n: Integer;
begin
  DecodedPublishFields := APublishFields;

  //Expect(AErr).ToBe(CMQTT_Success);  //////////////////////////////////////////////////////// verify for incomplete packets???????????

  n := Length(DecodedPublishPropertiesArr);
  SetLength(DecodedPublishPropertiesArr, n + 1);
  MQTT_InitPublishProperties(DecodedPublishPropertiesArr[n]);
  MQTT_CopyPublishProperties(APublishProperties, DecodedPublishPropertiesArr[n]);
end;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  FoundError := AErr;
  ErrorOnPacketType := APacketType;
end;


procedure TTestProtocolReceivePublishCase.SetUp;
begin
  MQTT_Init;
  MQTT_CreateClient; //create a client

  //Assigning library events should be done after calling MQTT_Init!

  {$IFDEF IsDesktop}
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnMQTTError^ := @HandleOnMQTTError;
  {$ELSE}
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnMQTTError := @HandleOnMQTTError;
  {$ENDIF}

  FieldsToSend.PacketIdentifier := 0;
  FieldsToSend.EnabledProperties := 0;
  FieldsToSend.PublishCtrlFlags := 0;

  MQTT_InitPublishProperties(PropertiesToSend);
  MQTT_InitControlPacket(DestPacket);

  FoundError := CMQTT_Success;
end;


procedure TTestProtocolReceivePublishCase.TearDown;
var
  i: Integer;
begin
  MQTT_FreeControlPacket(DestPacket);
  MQTT_FreePublishProperties(PropertiesToSend);

  for i := 0 to Length(DecodedPublishPropertiesArr) - 1 do
    MQTT_FreePublishProperties(DecodedPublishPropertiesArr[i]);

  SetLength(DecodedPublishPropertiesArr, 0);

  MQTT_Done;
end;


initialization

  RegisterTest(TTestProtocolReceivePublishCase);

end.

