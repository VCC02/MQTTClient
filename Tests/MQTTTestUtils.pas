{
    Copyright (C) 2023 VCC
    creation date: 11 May 2023
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


unit MQTTTestUtils;

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ENDIF}

interface


uses
  DynArrays, MQTTUtils;


function EncodeControlPacketToBuffer(var ASrcCtrlPacket: TMQTTControlPacket; var ADestEncodedBuffer: TDynArrayOfByte): Boolean;

function FillIn_ConnAckPropertiesForTest(AEnabledProperties: DWord; var ADestProperties: TMQTTConnAckProperties): Boolean;
function FillIn_PublishPropertiesForTest(AEnabledProperties: Byte; var ADestProperties: TMQTTPublishProperties): Boolean;
function FillIn_CommonPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTCommonProperties): Boolean;
function FillIn_SubscribePropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTSubscribeProperties): Boolean;
function FillIn_UnsubscribePropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTUnsubscribeProperties): Boolean;
function FillIn_DisconnectPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTDisconnectProperties): Boolean;
function FillIn_AuthPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTAuthProperties): Boolean;


implementation


function EncodeControlPacketToBuffer(var ASrcCtrlPacket: TMQTTControlPacket; var ADestEncodedBuffer: TDynArrayOfByte): Boolean;
begin
  Result := True;
  Result := Result and ConcatDynArrays(ADestEncodedBuffer, ASrcCtrlPacket.Header);
  Result := Result and ConcatDynArrays(ADestEncodedBuffer, ASrcCtrlPacket.VarHeader);
  Result := Result and ConcatDynArrays(ADestEncodedBuffer, ASrcCtrlPacket.Payload);
end;


function FillIn_ConnAckPropertiesForTest(AEnabledProperties: DWord; var ADestProperties: TMQTTConnAckProperties): Boolean;
var
  TempStr: string;
begin
  Result := True;

  if AEnabledProperties and CMQTTConnAck_EnSessionExpiryInterval = CMQTTConnAck_EnSessionExpiryInterval then
    ADestProperties.SessionExpiryInterval := 5678;

  if AEnabledProperties and CMQTTConnAck_EnReceiveMaximum = CMQTTConnAck_EnReceiveMaximum then
    ADestProperties.ReceiveMaximum := 432;

  if AEnabledProperties and CMQTTConnAck_EnMaximumQoS = CMQTTConnAck_EnMaximumQoS then
    ADestProperties.MaximumQoS := 2;

  if AEnabledProperties and CMQTTConnAck_EnRetainAvailable = CMQTTConnAck_EnRetainAvailable then
    ADestProperties.RetainAvailable := 1;

  if AEnabledProperties and CMQTTConnAck_EnMaximumPacketSize = CMQTTConnAck_EnMaximumPacketSize then
    ADestProperties.MaximumPacketSize := 789;

  if AEnabledProperties and CMQTTConnAck_EnAssignedClientIdentifier = CMQTTConnAck_EnAssignedClientIdentifier then
  begin
    TempStr := 'Client name, assigned by server.';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.AssignedClientIdentifier);
  end;

  if AEnabledProperties and CMQTTConnAck_EnTopicAliasMaximum = CMQTTConnAck_EnTopicAliasMaximum then
    ADestProperties.TopicAliasMaximum := 40;

  if AEnabledProperties and CMQTTConnAck_EnReasonString = CMQTTConnAck_EnReasonString then
  begin
    TempStr := 'for no reason';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.ReasonString);
  end;

  if AEnabledProperties and CMQTTConnAck_EnUserProperty = CMQTTConnAck_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;

  if AEnabledProperties and CMQTTConnAck_EnWildcardSubscriptionAvailable = CMQTTConnAck_EnWildcardSubscriptionAvailable then
    ADestProperties.WildcardSubscriptionAvailable := 1
  else
    ADestProperties.WildcardSubscriptionAvailable := 0;

  if AEnabledProperties and CMQTTConnAck_EnSubscriptionIdentifierAvailable = CMQTTConnAck_EnSubscriptionIdentifierAvailable then
    ADestProperties.SubscriptionIdentifierAvailable := 1
  else
    ADestProperties.SubscriptionIdentifierAvailable := 0;

  if AEnabledProperties and CMQTTConnAck_EnSharedSubscriptionAvailable = CMQTTConnAck_EnSharedSubscriptionAvailable then
    ADestProperties.SharedSubscriptionAvailable := 1
  else
    ADestProperties.SharedSubscriptionAvailable := 0;

  if AEnabledProperties and CMQTTConnAck_EnServerKeepAlive = CMQTTConnAck_EnServerKeepAlive then
    ADestProperties.ServerKeepAlive := 478;

  if AEnabledProperties and CMQTTConnAck_EnResponseInformation = CMQTTConnAck_EnResponseInformation then
  begin
    TempStr := 'no new info';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.ResponseInformation);
  end;

  if AEnabledProperties and CMQTTConnAck_EnServerReference = CMQTTConnAck_EnServerReference then
  begin
    TempStr := 'address_of_backup_server';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.ServerReference);
  end;

  if AEnabledProperties and CMQTTConnAck_EnAuthenticationMethod = CMQTTConnAck_EnAuthenticationMethod then
  begin
    TempStr := 'some authentication method';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.AuthenticationMethod);
  end;

  if AEnabledProperties and CMQTTConnAck_EnAuthenticationData = CMQTTConnAck_EnAuthenticationData then
  begin
    Result := Result and SetDynLength(ADestProperties.AuthenticationData, 3);
    ADestProperties.AuthenticationData.Content^[0] := 70;
    ADestProperties.AuthenticationData.Content^[1] := 80;
    ADestProperties.AuthenticationData.Content^[2] := 90;
  end;
end;


function FillIn_PublishPropertiesForTest(AEnabledProperties: Byte; var ADestProperties: TMQTTPublishProperties): Boolean;
var
  TempStr: string;
begin
  Result := True;

  if AEnabledProperties and CMQTTPublish_EnPayloadFormatIndicator = CMQTTPublish_EnPayloadFormatIndicator then
    ADestProperties.PayloadFormatIndicator := 1;  //1 means there will be a payload

  if AEnabledProperties and CMQTTPublish_EnMessageExpiryInterval = CMQTTPublish_EnMessageExpiryInterval then
    ADestProperties.MessageExpiryInterval := 5678;

  if AEnabledProperties and CMQTTPublish_EnTopicAlias = CMQTTPublish_EnTopicAlias then
    ADestProperties.TopicAlias := 44;

  if AEnabledProperties and CMQTTPublish_EnResponseTopic = CMQTTPublish_EnResponseTopic then
  begin
    TempStr := 'some/name';
    Result := Result and StringToDynArrayOfByte(TempStr, ADestProperties.ResponseTopic);
  end;

  if AEnabledProperties and CMQTTPublish_EnCorrelationData = CMQTTPublish_EnCorrelationData then
  begin
    Result := Result and SetDynLength(ADestProperties.CorrelationData, 3);
    ADestProperties.CorrelationData.Content^[0] := 40;
    ADestProperties.CorrelationData.Content^[1] := 50;
    ADestProperties.CorrelationData.Content^[2] := 60;
  end;

  if AEnabledProperties and CMQTTPublish_EnUserProperty = CMQTTPublish_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;

  if AEnabledProperties and CMQTTPublish_EnSubscriptionIdentifier = CMQTTPublish_EnSubscriptionIdentifier then
  begin
    Result := Result and SetDynOfDWordLength(ADestProperties.SubscriptionIdentifier, 3);
    ADestProperties.SubscriptionIdentifier.Content^[0] := 4000;
    ADestProperties.SubscriptionIdentifier.Content^[1] := 5000;
    ADestProperties.SubscriptionIdentifier.Content^[2] := 8000;
  end;

  if AEnabledProperties and CMQTTPublish_EnContentType = CMQTTPublish_EnContentType then
  begin
    Result := Result and SetDynLength(ADestProperties.ContentType, 3);
    ADestProperties.ContentType.Content^[0] := 70;
    ADestProperties.ContentType.Content^[1] := 80;
    ADestProperties.ContentType.Content^[2] := 90;
  end;
end;


function FillIn_CommonPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTCommonProperties): Boolean;
begin
  Result := True;

  if AEnabledProperties and CMQTTCommon_EnReasonString = CMQTTCommon_EnReasonString then
    Result := Result and StringToDynArrayOfByte('for no reason', ADestProperties.ReasonString);

  if AEnabledProperties and CMQTTCommon_EnUserProperty = CMQTTCommon_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;
end;


function FillIn_SubscribePropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTSubscribeProperties): Boolean;
begin
  Result := True;

  if AEnabledProperties and CMQTTSubscribe_EnSubscriptionIdentifier = CMQTTSubscribe_EnSubscriptionIdentifier then
    ADestProperties.SubscriptionIdentifier := $08ABCDEF;

  if AEnabledProperties and CMQTTSubscribe_EnUserProperty = CMQTTSubscribe_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;
end;


function FillIn_UnsubscribePropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTUnsubscribeProperties): Boolean;
begin
  Result := True;

  if AEnabledProperties and CMQTTUnsubscribe_EnUserProperty = CMQTTUnsubscribe_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;
end;


function FillIn_DisconnectPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTDisconnectProperties): Boolean;
begin
  Result := True;

  if AEnabledProperties and CMQTTDisconnect_EnSessionExpiryInterval = CMQTTDisconnect_EnSessionExpiryInterval then
    ADestProperties.SessionExpiryInterval := $08ABCDEF;

  if AEnabledProperties and CMQTTDisconnect_EnReasonString = CMQTTDisconnect_EnReasonString then
    Result := Result and StringToDynArrayOfByte('for no reason', ADestProperties.ReasonString);

  if AEnabledProperties and CMQTTDisconnect_EnUserProperty = CMQTTDisconnect_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;

  if AEnabledProperties and CMQTTDisconnect_EnServerReference = CMQTTDisconnect_EnServerReference then
    Result := Result and StringToDynArrayOfByte('new server', ADestProperties.ServerReference);
end;


function FillIn_AuthPropertiesForTest(AEnabledProperties: Word; var ADestProperties: TMQTTAuthProperties): Boolean;
begin
  Result := True;

  if AEnabledProperties and CMQTTAuth_EnAuthenticationMethod = CMQTTAuth_EnAuthenticationMethod then
    Result := Result and StringToDynArrayOfByte('some method', ADestProperties.AuthenticationMethod);

  if AEnabledProperties and CMQTTAuth_EnAuthenticationData = CMQTTAuth_EnAuthenticationData then
    Result := Result and StringToDynArrayOfByte('some data.', ADestProperties.AuthenticationData);

  if AEnabledProperties and CMQTTAuth_EnReasonString = CMQTTAuth_EnReasonString then
    Result := Result and StringToDynArrayOfByte('for no reason', ADestProperties.ReasonString);

  if AEnabledProperties and CMQTTAuth_EnUserProperty = CMQTTAuth_EnUserProperty then
  begin
    Result := Result and AddStringToDynOfDynArrayOfByte('first_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('second_user_property', ADestProperties.UserProperty);
    Result := Result and AddStringToDynOfDynArrayOfByte('third_user_property', ADestProperties.UserProperty);
  end;
end;


end.

