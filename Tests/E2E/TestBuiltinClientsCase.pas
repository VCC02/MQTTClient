{
    Copyright (C) 2024 VCC
    creation date: 28 Mar 2024
    initial release date: 28 Mar 2024

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


unit TestBuiltinClientsCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls,
  fpcunit, testregistry, IdGlobal, IdTCPClient,
  DynArrays, PollingFIFO;


type
  TMQTTTestClient = class(TComponent)
  private
    FClientIndex: Integer;
    FIdTCPClientObj: TIdTCPClient;
    FRecBufFIFO: TPollingFIFO; //used by the reading thread to pass data to MQTT library
    tmrProcessRecData: TTimer;
    FMQTTUsername: string;
    FMQTTPassword: string;

    FReceivedConAck: Boolean;
    FSubscribePacketID: Integer;
    FSubAckPacketID: Integer;
    FReceivedPublishedMessage: string;

    procedure InitHandlers;
    procedure SendDynArrayOfByte(AArr: TDynArrayOfByte);
    procedure SendPacketToServer(ClientInstance: DWord);

    procedure tmrProcessRecDataTimer(Sender: TObject);
    procedure HandleClientOnConnected(Sender: TObject);
    procedure HandleClientOnDisconnected(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SyncReceivedBuffer(var AReadBuf: TDynArrayOfByte);
    procedure ProcessReceivedBuffer;
    procedure AddToLog(s: string);

    property ClientIndex: Integer read FClientIndex write FClientIndex; //identifies the client instance in the array of clients
    property IdTCPClientObj: TIdTCPClient read FIdTCPClientObj;

    property ReceivedConAck: Boolean read FReceivedConAck write FReceivedConAck;
    property SubscribePacketID: Integer read FSubscribePacketID write FSubscribePacketID;
    property SubAckPacketID: Integer read FSubAckPacketID write FSubAckPacketID;
    property ReceivedPublishedMessage: string read FReceivedPublishedMessage write FReceivedPublishedMessage;
  end;


  TTestE2EBuiltinClientsCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPublish_Client0ToClient1_HappyFlow_QoS0;
    procedure TestPublish_Client0ToClient1_HappyFlow_QoS1;
    procedure TestPublish_Client0ToClient1_HappyFlow_QoS2;
  end;

implementation


uses
  MQTTClient, MQTTUtils, MQTTTestUtils,
  MQTTConnectCtrl, MQTTConnAckCtrl, MQTTPublishCtrl, MQTTPubAckCtrl, MQTTSubscribeCtrl, MQTTUnsubscribeCtrl,
  Expectations, ExpectationsDynArrays;


var
  TestClients: array of TMQTTTestClient;
  FSubscribeToTopicNames: TStringArray;
  FMsgToPublish: string;
  FTopicNameToPublish: string;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
var
  PacketTypeStr: string;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  MQTTPacketToString(APacketType, PacketTypeStr);
  TestClients[TempClientInstance].AddToLog('Client: ' + IntToHex(ClientInstance, 8) + '  Err: $' + IntToHex(AErr) + '  PacketType: $' + IntToHex(APacketType) + ' (' + PacketTypeStr + ').');  //The error is made of an upper byte and a lower byte.

  if Hi(AErr) = CMQTT_Reason_NotAuthorized then   // $87
  begin
    TestClients[TempClientInstance].AddToLog('Server error: Not authorized.');
    if APacketType = CMQTT_CONNACK then
      TestClients[TempClientInstance].AddToLog('             on receiving CONNACK.');
  end;

  if Lo(AErr) = CMQTT_PacketIdentifierNotFound_ClientToServer then   // $CE
    TestClients[TempClientInstance].AddToLog('Client error: PacketIdentifierNotFound.');

  if Lo(AErr) = CMQTT_UnhandledPacketType then   // $CA
    TestClients[TempClientInstance].AddToLog('Client error: UnhandledPacketType.');  //Usually appears when an incomplete packet is received, so the packet type by is 0.
end;


procedure HandleOnSend_MQTT_Packet(ClientInstance: DWord; APacketType: Byte);
var
  PacketName: string;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  MQTTPacketToString(APacketType, PacketName);
  TestClients[TempClientInstance].AddToLog('Sending ' + PacketName + ' packet...');

  try
    TestClients[TempClientInstance].SendPacketToServer(ClientInstance);
  except
    on E: Exception do
      TestClients[TempClientInstance].AddToLog('Cannot send ' + PacketName + ' packet... Ex: ' + E.Message);
  end;
end;


function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
var
  TempWillProperties: TMQTTWillProperties;
  UserName, Password: string;
  //ClientId: string;
  //Id: Char;
  ConnectFlags: Byte;
  EnabledProperties: Word;
  TempClientInstance: DWord;
begin
  Result := True;
  TempClientInstance := ClientInstance and CClientIndexMask;

  TestClients[TempClientInstance].AddToLog('Preparing CONNECT data..');

  //Id := Chr((ClientInstance and $FF) + 48);
  //ClientId := 'MyClient' + Id;
  UserName := TestClients[TempClientInstance].FMQTTUsername;
  Password := TestClients[TempClientInstance].FMQTTPassword;

  //StringToDynArrayOfByte(ClientId, AConnectFields.PayloadContent.ClientID);
  StringToDynArrayOfByte(UserName, AConnectFields.PayloadContent.UserName);
  StringToDynArrayOfByte(Password, AConnectFields.PayloadContent.Password);

  ConnectFlags := CMQTT_UsernameInConnectFlagsBitMask or
                  CMQTT_PasswordInConnectFlagsBitMask or
                  CMQTT_CleanStartInConnectFlagsBitMask {or
                  CMQTT_WillQoSB1InConnectFlagsBitMask};

  EnabledProperties := CMQTTConnect_EnSessionExpiryInterval or
                       CMQTTConnect_EnRequestResponseInformation or
                       CMQTTConnect_EnRequestProblemInformation {or
                       CMQTTConnect_EnAuthenticationMethod or
                       CMQTTConnect_EnAuthenticationData};

  MQTT_InitWillProperties(TempWillProperties);
  TempWillProperties.WillDelayInterval := 30; //some value
  TempWillProperties.PayloadFormatIndicator := 1;  //0 = do not send.  1 = UTF-8 string
  TempWillProperties.MessageExpiryInterval := 3600;
  StringToDynArrayOfByte('SomeType', TempWillProperties.ContentType);
  StringToDynArrayOfByte('SomeTopicName', TempWillProperties.ResponseTopic);
  StringToDynArrayOfByte('MyCorrelationData', TempWillProperties.CorrelationData);
  AddStringToDynOfDynArrayOfByte('Key=Value', TempWillProperties.UserProperty);
  AddStringToDynOfDynArrayOfByte('NewKey=NewValue', TempWillProperties.UserProperty);

  FillIn_PayloadWillProperties(TempWillProperties, AConnectFields.PayloadContent.WillProperties);
  MQTT_FreeWillProperties(TempWillProperties);
  StringToDynArrayOfByte('WillTopic', AConnectFields.PayloadContent.WillTopic);

  //Please set the Will Flag in ConnectFlags below, then uncomment above code, if "Will" properties are required.
  AConnectFields.ConnectFlags := ConnectFlags;  //bits 7-0:  User Name, Password, Will Retain, Will QoS, Will Flag, Clean Start, Reserved
  AConnectFields.EnabledProperties := EnabledProperties;
  AConnectFields.KeepAlive := 0; //any positive values require pinging the server if no other packet is being sent

  AConnectProperties.SessionExpiryInterval := 3600; //[s]
  AConnectProperties.ReceiveMaximum := 7000;
  AConnectProperties.MaximumPacketSize := 10 * 1024 * 1024;
  AConnectProperties.TopicAliasMaximum := 100;
  AConnectProperties.RequestResponseInformation := 1;
  AConnectProperties.RequestProblemInformation := 1;
  AddStringToDynOfDynArrayOfByte('UserProp=Value', AConnectProperties.UserProperty);
  StringToDynArrayOfByte('SCRAM-SHA-1', AConnectProperties.AuthenticationMethod);       //some example from spec, pag 108   the server may add to its log: "bad AUTH method"
  StringToDynArrayOfByte('client-first-data', AConnectProperties.AuthenticationData);   //some example from spec, pag 108

  TestClients[TempClientInstance].AddToLog('Done preparing CONNECT data..');
  TestClients[TempClientInstance].AddToLog('');
end;


procedure HandleOnAfterMQTT_CONNACK(ClientInstance: DWord; var AConnAckFields: TMQTTConnAckFields; var AConnAckProperties: TMQTTConnAckProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].ReceivedConAck := True;
  TestClients[TempClientInstance].AddToLog('Received CONNACK');

  TestClients[TempClientInstance].AddToLog('ConnAckFields.EnabledProperties: ' + IntToStr(AConnAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('ConnAckFields.SessionPresentFlag: ' + IntToStr(AConnAckFields.SessionPresentFlag));
  TestClients[TempClientInstance].AddToLog('ConnAckFields.ConnectReasonCode: ' + IntToStr(AConnAckFields.ConnectReasonCode));  //should be 0

  TestClients[TempClientInstance].AddToLog('SessionExpiryInterval: ' + IntToStr(AConnAckProperties.SessionExpiryInterval));
  TestClients[TempClientInstance].AddToLog('ReceiveMaximum: ' + IntToStr(AConnAckProperties.ReceiveMaximum));
  TestClients[TempClientInstance].AddToLog('MaximumQoS: ' + IntToStr(AConnAckProperties.MaximumQoS));
  TestClients[TempClientInstance].AddToLog('RetainAvailable: ' + IntToStr(AConnAckProperties.RetainAvailable));
  TestClients[TempClientInstance].AddToLog('MaximumPacketSize: ' + IntToStr(AConnAckProperties.MaximumPacketSize));
  TestClients[TempClientInstance].AddToLog('AssignedClientIdentifier: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AssignedClientIdentifier), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('TopicAliasMaximum: ' + IntToStr(AConnAckProperties.TopicAliasMaximum));
  TestClients[TempClientInstance].AddToLog('ReasonString: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AConnAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('WildcardSubscriptionAvailable: ' + IntToStr(AConnAckProperties.WildcardSubscriptionAvailable));
  TestClients[TempClientInstance].AddToLog('SubscriptionIdentifierAvailable: ' + IntToStr(AConnAckProperties.SubscriptionIdentifierAvailable));
  TestClients[TempClientInstance].AddToLog('SharedSubscriptionAvailable: ' + IntToStr(AConnAckProperties.SharedSubscriptionAvailable));
  TestClients[TempClientInstance].AddToLog('ServerKeepAlive: ' + IntToStr(AConnAckProperties.ServerKeepAlive));
  TestClients[TempClientInstance].AddToLog('ResponseInformation: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ResponseInformation), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('ServerReference: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ServerReference), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AuthenticationMethod: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AuthenticationMethod), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AuthenticationData: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AuthenticationData), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');

  ///////////////////////////////////////// when the server returns SessionPresentFlag set to 1, the library resends unacknowledged Publish and PubRel packets.
  //AConnAckFields.SessionPresentFlag := 1;
end;


function HandleOnBeforeSendingMQTT_SUBSCRIBE(ClientInstance: DWord;  //The lower word identifies the client instance
                                             var ASubscribeFields: TMQTTSubscribeFields;
                                             var ASubscribeProperties: TMQTTSubscribeProperties;
                                             ACallbackID: Word): Boolean;
var
  Options, QoS: Byte;
  SubId: Word;
  TempClientInstance: DWord;
  i: Integer;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Options := 0;
  QoS := 2;

  Options := Options or QoS; //bits 1 and 0
  //Bit 2 of the Subscription Options represents the No Local option.  - spec pag 73
  //Bit 3 of the Subscription Options represents the Retain As Published option.  - spec pag 73
  //Bits 4 and 5 of the Subscription Options represent the Retain Handling option.  - spec pag 73
  //Bits 6 and 7 of the Subscription Options byte are reserved for future use. - Must be set to 0.  - spec pag 73

                                                                            //Subscription identifiers are not mandatory (per spec).
  SubId := MQTT_CreateClientToServerSubscriptionIdentifier(ClientInstance); //This function has to be called here, in this handler only. The library does not call this function other than for init purposes.
                                                                            //If SubscriptionIdentifiers are used, then user code should free them when resubscribing or when unsubscribing.
  ASubscribeProperties.SubscriptionIdentifier := SubId;  //For now, the user code should keep track of these identifiers and free them on resubscribing or unsubscribing.
  TestClients[TempClientInstance].AddToLog('Subscribing with new SubscriptionIdentifier: ' + IntToStr(SubId));

  for i := 0 to Length(FSubscribeToTopicNames) - 1 do
  begin
    Result := FillIn_SubscribePayload(FSubscribeToTopicNames[i], Options, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
    if not Result then
    begin
      TestClients[TempClientInstance].AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
      Exit;
    end;
  end;

  //Enable SubscriptionIdentifier only if required (allocated above with CreateClientToServerSubscriptionIdentifier) !!!
  //The library initializes EnabledProperties to 0.
  //A subscription is allowed to be made without a SubscriptionIdentifier.
  ASubscribeFields.EnabledProperties := CMQTTSubscribe_EnSubscriptionIdentifier {or CMQTTSubscribe_EnUserProperty};

  TestClients[TempClientInstance].AddToLog('Subscribing with PacketIdentifier: ' + IntToStr(ASubscribeFields.PacketIdentifier));
  TestClients[TempClientInstance].AddToLog('Subscribing to: ' + StringReplace(DynArrayOfByteToString(ASubscribeFields.TopicFilters), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');
  TestClients[TempClientInstance].SubscribePacketID := ASubscribeFields.PacketIdentifier;
end;


procedure HandleOnAfterReceivingMQTT_SUBACK(ClientInstance: DWord; var ASubAckFields: TMQTTSubAckFields; var ASubAckProperties: TMQTTSubAckProperties);
var
  i: Integer;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received SUBACK');
  //TestClients[TempClientInstance].AddToLog('ASubAckFields.IncludeReasonCode: ' + IntToStr(ASubAckFields.IncludeReasonCode));  //not used
  //TestClients[TempClientInstance].AddToLog('ASubAckFields.ReasonCode: ' + IntToStr(ASubAckFields.ReasonCode));              //not used
  TestClients[TempClientInstance].AddToLog('ASubAckFields.EnabledProperties: ' + IntToStr(ASubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('ASubAckFields.PacketIdentifier: ' + IntToStr(ASubAckFields.PacketIdentifier));  //This must be the same as sent in SUBSCRIBE packet.

  TestClients[TempClientInstance].AddToLog('ASubAckFields.Payload.Len: ' + IntToStr(ASubAckFields.SrcPayload.Len));

  for i := 0 to ASubAckFields.SrcPayload.Len - 1 do         //these are QoS values for each TopicFilter (if ok), or error codes (if not ok).
    TestClients[TempClientInstance].AddToLog('ASubAckFields.ReasonCodes[' + IntToStr(i) + ']: ' + IntToStr(ASubAckFields.SrcPayload.Content^[i]));

  TestClients[TempClientInstance].AddToLog('ASubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(ASubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('ASubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(ASubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');
  TestClients[TempClientInstance].SubAckPacketID := ASubAckFields.PacketIdentifier;
end;


function HandleOnBeforeSendingMQTT_UNSUBSCRIBE(ClientInstance: DWord;  //The lower word identifies the client instance
                                               var AUnsubscribeFields: TMQTTUnsubscribeFields;
                                               var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                                               ACallbackID: Word): Boolean;
var
  TempClientInstance: DWord;
  i: Integer;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  for i := 0 to Length(FSubscribeToTopicNames) - 1 do
  begin
    Result := FillIn_UnsubscribePayload(FSubscribeToTopicNames[i], AUnsubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to AUnsubscribeFields.TopicFilters
    if not Result then
    begin
      TestClients[TempClientInstance].AddToLog('HandleOnBeforeSendingMQTT_UNSUBSCRIBE not enough memory to add TopicFilters.');
      Exit;
    end;
    TestClients[TempClientInstance].AddToLog('Unsubscribing from "' + FSubscribeToTopicNames[i] + '"...');
  end;

  //the user code should call RemoveClientToServerSubscriptionIdentifier to remove the allocate identifier.
end;


procedure HandleOnAfterReceivingMQTT_UNSUBACK(ClientInstance: DWord; var AUnsubAckFields: TMQTTUnsubAckFields; var AUnsubAckProperties: TMQTTUnsubAckProperties);
var
  i: Integer;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received UNSUBACK');
  //TestClients[TempClientInstance].AddToLog('AUnsubAckFields.IncludeReasonCode: ' + IntToStr(ASubAckFields.IncludeReasonCode));  //not used
  //TestClients[TempClientInstance].AddToLog('AUnsubAckFields.ReasonCode: ' + IntToStr(ASubAckFields.ReasonCode));              //not used
  TestClients[TempClientInstance].AddToLog('AUnsubAckFields.EnabledProperties: ' + IntToStr(AUnsubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('AUnsubAckFields.PacketIdentifier: ' + IntToStr(AUnsubAckFields.PacketIdentifier));  //This must be the same as sent in SUBSCRIBE packet.

  TestClients[TempClientInstance].AddToLog('AUnsubAckFields.Payload.Len: ' + IntToStr(AUnsubAckFields.SrcPayload.Len));

  for i := 0 to AUnsubAckFields.SrcPayload.Len - 1 do         //these are QoS values for each TopicFilter (if ok), or error codes (if not ok).
    TestClients[TempClientInstance].AddToLog('AUnsubAckFields.ReasonCodes[' + IntToStr(i) + ']: ' + IntToStr(AUnsubAckFields.SrcPayload.Content^[i]));

  TestClients[TempClientInstance].AddToLog('AUnsubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(AUnsubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AUnsubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AUnsubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');
end;


//This handler is used when this client publishes a message to broker.
function HandleOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                           var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                           var APublishProperties: TMQTTPublishProperties;            //user code has to fill-in this parameter
                                           ACallbackID: Word): Boolean;
var
  QoS: Byte;
  TempClientInstance: DWord;
begin
  Result := True;
  TempClientInstance := ClientInstance and CClientIndexMask;

  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  TestClients[TempClientInstance].AddToLog('Publishing "' + FMsgToPublish + '" at QoS = ' + IntToStr(QoS));

  Result := Result and StringToDynArrayOfByte(FMsgToPublish, APublishFields.ApplicationMessage);
  Result := Result and StringToDynArrayOfByte(FTopicNameToPublish, APublishFields.TopicName);

  TestClients[TempClientInstance].AddToLog('');
  //QoS can be overriden here. If users override QoS in this handler, then a a different PacketIdentifier might be allocated (depending on what is available)
end;


//This handler is used when this client publishes a message to broker and the broker responds with PUBACK.
procedure HandleOnBeforeSendingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBACK');
  TestClients[TempClientInstance].AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  TestClients[TempClientInstance].AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  TestClients[TempClientInstance].AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  TestClients[TempClientInstance].AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');
  //This handler can be used to override what is being sent to server as a reply to PUBLISH
end;


procedure HandleOnAfterReceivingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  TestClients[TempClientInstance].AddToLog('Received PUBACK');
  TestClients[TempClientInstance].AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  TestClients[TempClientInstance].AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  TestClients[TempClientInstance].AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  TestClients[TempClientInstance].AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  TestClients[TempClientInstance].AddToLog('');
end;


procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var APublishFields: TMQTTPublishFields; var APublishProperties: TMQTTPublishProperties);
var
  QoS: Byte;
  ID: Word;
  Topic, s, Msg: string;
  i: Integer;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  Msg := StringReplace(DynArrayOfByteToString(APublishFields.ApplicationMessage), #0, '#0', [rfReplaceAll]);
  ID := APublishFields.PacketIdentifier;
  Topic := StringReplace(DynArrayOfByteToString(APublishFields.TopicName), #0, '#0', [rfReplaceAll]);

  TestClients[TempClientInstance].AddToLog('Received PUBLISH  ServerPacketIdentifier: ' + IntToStr(ID) +
                                                 '  Msg: ' + Msg +
                                                 '  QoS: ' + IntToStr(QoS) +
                                                 '  TopicName: ' + Topic);

  s := '';
  for i := 0 to APublishProperties.SubscriptionIdentifier.Len - 1 do
    s := s + IntToStr(APublishProperties.SubscriptionIdentifier.Content^[i]) + ', ';
  TestClients[TempClientInstance].AddToLog('SubscriptionIdentifier(s): ' + s);

  TestClients[TempClientInstance].ReceivedPublishedMessage := Msg;

  TestClients[TempClientInstance].AddToLog('');
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBREC for ServerPacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received PUBREC for PacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


//Sending PUBREL after the PUBREC response from server, after the client has sent a PUBLISH packet with QoS=2.
procedure HandleOnBeforeSending_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBREL for PacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received PUBREL for ServerPacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBCOMP for PacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received PUBCOMP for ServerPacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceivingMQTT_PINGRESP(ClientInstance: DWord);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received PINGRESP');
end;


procedure HandleOnBeforeSendingMQTT_DISCONNECT(ClientInstance: DWord;  //The lower word identifies the client instance
                                               var ADisconnectFields: TMQTTDisconnectFields;
                                               var ADisconnectProperties: TMQTTDisconnectProperties;
                                               ACallbackID: Word);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Sending DISCONNECT');
  //ADisconnectFields.EnabledProperties := CMQTTDisconnect_EnSessionExpiryInterval;   //uncomment if needed
  //ADisconnectProperties.SessionExpiryInterval := 1;

  //From spec, pag 89:
  //If the Session Expiry Interval is absent, the Session Expiry Interval in the CONNECT packet is used.
  //If the Session Expiry Interval in the CONNECT packet was zero, then it is a Protocol Error to set a non-
  //zero Session Expiry Interval in the DISCONNECT packet sent by the Client.

  //From spec, pag 89:
  //After sending a DISCONNECT packet the sender
  //  MUST NOT send any more MQTT Control Packets on that Network Connection
  //  MUST close the Network Connection
end;


procedure HandleOnAfterReceivingMQTT_DISCONNECT(ClientInstance: DWord;  //The lower word identifies the client instance
                                                var ADisconnectFields: TMQTTDisconnectFields;
                                                var ADisconnectProperties: TMQTTDisconnectProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received DISCONNECT');

  TestClients[TempClientInstance].AddToLog('ADisconnectFields.EnabledProperties' + IntToStr(ADisconnectFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('ADisconnectFields.DisconnectReasonCode' + IntToStr(ADisconnectFields.DisconnectReasonCode));

  TestClients[TempClientInstance].AddToLog('ADisconnectProperties.SessionExpiryInterval' + IntToStr(ADisconnectProperties.SessionExpiryInterval));
  TestClients[TempClientInstance].AddToLog('ADisconnectProperties.ReasonString' + StringReplace(DynArrayOfByteToString(ADisconnectProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('ADisconnectProperties.ServerReference' + StringReplace(DynArrayOfByteToString(ADisconnectProperties.ServerReference), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('ADisconnectProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(ADisconnectProperties.UserProperty), #0, '#0', [rfReplaceAll]));
end;


procedure HandleOnBeforeSendingMQTT_AUTH(ClientInstance: DWord;  //The lower word identifies the client instance
                                         var AAuthFields: TMQTTAuthFields;
                                         var AAuthProperties: TMQTTAuthProperties;
                                         ACallbackID: Word);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Sending AUTH');
  AAuthFields.AuthReasonCode := $19; //Example: reauth   - see spec, pag 108.

  StringToDynArrayOfByte('SCRAM-SHA-1', AAuthProperties.AuthenticationMethod);       //some example from spec, pag 108
  StringToDynArrayOfByte('client-second-data', AAuthProperties.AuthenticationData);   //some modified example from spec, pag 108
end;


procedure HandleOnAfterReceivingMQTT_AUTH(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var AAuthFields: TMQTTAuthFields;
                                          var AAuthProperties: TMQTTAuthProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].AddToLog('Received AUTH');

  TestClients[TempClientInstance].AddToLog('AAuthFields.EnabledProperties' + IntToStr(AAuthFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('AAuthFields.AuthReasonCode' + IntToStr(AAuthFields.AuthReasonCode));

  TestClients[TempClientInstance].AddToLog('AAuthProperties.ReasonString' + StringReplace(DynArrayOfByteToString(AAuthProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AAuthProperties.ServerReference' + StringReplace(DynArrayOfByteToString(AAuthProperties.AuthenticationMethod), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AAuthProperties.ServerReference' + StringReplace(DynArrayOfByteToString(AAuthProperties.AuthenticationData), #0, '#0', [rfReplaceAll]));
  TestClients[TempClientInstance].AddToLog('AAuthProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(AAuthProperties.UserProperty), #0, '#0', [rfReplaceAll]));
end;


constructor TMQTTTestClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRecBufFIFO := TPollingFIFO.Create;
  FIdTCPClientObj := TIdTCPClient.Create(Self);
  FIdTCPClientObj.OnConnected := @HandleClientOnConnected;
  FIdTCPClientObj.OnDisconnected := @HandleClientOnDisconnected;

  tmrProcessRecData := TTimer.Create(Self);
  tmrProcessRecData.Interval := 10;
  tmrProcessRecData.OnTimer := @tmrProcessRecDataTimer;
  tmrProcessRecData.Enabled := True;

  FMQTTUsername := '';
  FMQTTPassword := '';

  FReceivedConAck := False;
  FSubscribePacketID := 0;
  FSubAckPacketID := 0;
  FReceivedPublishedMessage := 'NotSetYet';
end;


destructor TMQTTTestClient.Destroy;
begin
  FreeAndNil(FRecBufFIFO);

  inherited Destroy;
end;


procedure TMQTTTestClient.AddToLog(s: string);
begin
  //
end;


procedure TMQTTTestClient.HandleClientOnConnected(Sender: TObject);
begin
  AddToLog('Connected to broker... on port ' + IntToStr((Sender as TIdTCPClient).Port));
end;


procedure TMQTTTestClient.HandleClientOnDisconnected(Sender: TObject);
begin
  AddToLog('Disconnected from broker...');
  //Th.Terminate;   ..both clients will have to be disconnected, in order to terminate the thread
end;


procedure TMQTTTestClient.SyncReceivedBuffer(var AReadBuf: TDynArrayOfByte); //thread safe
begin
  FRecBufFIFO.Put(DynArrayOfByteToString(AReadBuf));
end;


procedure TMQTTTestClient.ProcessReceivedBuffer;  //called by a timer, to process received data
var
  TempReadBuf: TDynArrayOfByte;
  NewData: string;
  i: Integer;
begin
  if FRecBufFIFO.Pop(NewData) then
  begin
    InitDynArrayToEmpty(TempReadBuf);
    try
      if StringToDynArrayOfByte(NewData, TempReadBuf) then
      begin
        MQTT_PutReceivedBufferToMQTTLib(FClientIndex, TempReadBuf);
        MQTT_Process(FClientIndex);
      end
      else
        AddToLog('Out of memory in ProcessReceivedBuffer.');
    finally
      FreeDynArray(TempReadBuf);
    end;
  end;
end;


procedure TMQTTTestClient.tmrProcessRecDataTimer(Sender: TObject);
begin
  ProcessReceivedBuffer;
end;


procedure TMQTTTestClient.InitHandlers;
begin
  {$IFDEF IsDesktop}
    OnMQTTError^ := @HandleOnMQTTError;
    OnSendMQTT_Packet^ := @HandleOnSend_MQTT_Packet;
    OnBeforeMQTT_CONNECT^ := @HandleOnBeforeMQTT_CONNECT;
    OnAfterMQTT_CONNACK^ := @HandleOnAfterMQTT_CONNACK;
    OnBeforeSendingMQTT_PUBLISH^ := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK^ := @HandleOnBeforeSendingMQTT_PUBACK;
    OnAfterReceivingMQTT_PUBACK^ := @HandleOnAfterReceivingMQTT_PUBACK;
    OnAfterReceivingMQTT_PUBLISH^ := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBREC^ := @HandleOnBeforeSending_MQTT_PUBREC;
    OnAfterReceivingMQTT_PUBREC^ := @HandleOnAfterReceiving_MQTT_PUBREC;
    OnBeforeSendingMQTT_PUBREL^ := @HandleOnBeforeSending_MQTT_PUBREL;
    OnAfterReceivingMQTT_PUBREL^ := @HandleOnAfterReceiving_MQTT_PUBREL;
    OnBeforeSendingMQTT_PUBCOMP^ := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnAfterReceivingMQTT_PUBCOMP^ := @HandleOnAfterReceiving_MQTT_PUBCOMP;
    OnBeforeSendingMQTT_SUBSCRIBE^ := @HandleOnBeforeSendingMQTT_SUBSCRIBE;
    OnAfterReceivingMQTT_SUBACK^ := @HandleOnAfterReceivingMQTT_SUBACK;
    OnBeforeSendingMQTT_UNSUBSCRIBE^ := @HandleOnBeforeSendingMQTT_UNSUBSCRIBE;
    OnAfterReceivingMQTT_UNSUBACK^ := @HandleOnAfterReceivingMQTT_UNSUBACK;
    OnAfterReceivingMQTT_PINGRESP^ := @HandleOnAfterReceivingMQTT_PINGRESP;
    OnBeforeSendingMQTT_DISCONNECT^ := @HandleOnBeforeSendingMQTT_DISCONNECT;
    OnAfterReceivingMQTT_DISCONNECT^ := @HandleOnAfterReceivingMQTT_DISCONNECT;
    OnBeforeSendingMQTT_AUTH^ := @HandleOnBeforeSendingMQTT_AUTH;
    OnAfterReceivingMQTT_AUTH^ := @HandleOnAfterReceivingMQTT_AUTH;
  {$ELSE}
    OnMQTTError := @HandleOnMQTTError;
    OnSendMQTT_Packet := @HandleOnSend_MQTT_Packet;
    OnBeforeMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
    OnAfterMQTT_CONNACK := @HandleOnAfterMQTT_CONNACK;
    OnBeforeSendingMQTT_PUBLISH := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBACK := @HandleOnBeforeSendingMQTT_PUBACK;
    OnAfterReceivingMQTT_PUBACK := @HandleOnAfterReceivingMQTT_PUBACK;
    OnAfterReceivingMQTT_PUBLISH := @HandleOnAfterReceivingMQTT_PUBLISH;
    OnBeforeSendingMQTT_PUBREC := @HandleOnBeforeSending_MQTT_PUBREC;
    OnAfterReceivingMQTT_PUBREC := @HandleOnAfterReceiving_MQTT_PUBREC;
    OnBeforeSendingMQTT_PUBREL := @HandleOnBeforeSending_MQTT_PUBREL;
    OnAfterReceivingMQTT_PUBREL := @HandleOnAfterReceiving_MQTT_PUBREL;
    OnBeforeSendingMQTT_PUBCOMP := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnAfterReceivingMQTT_PUBCOMP := @HandleOnAfterReceiving_MQTT_PUBCOMP;
    OnBeforeSendingMQTT_SUBSCRIBE := @HandleOnBeforeSendingMQTT_SUBSCRIBE;
    OnAfterReceivingMQTT_SUBACK := @HandleOnAfterReceivingMQTT_SUBACK;
    OnBeforeSendingMQTT_UNSUBSCRIBE := @HandleOnBeforeSendingMQTT_UNSUBSCRIBE;
    OnAfterReceivingMQTT_UNSUBACK := @HandleOnAfterReceivingMQTT_UNSUBACK;
    OnAfterReceivingMQTT_PINGRESP := @HandleOnAfterReceivingMQTT_PINGRESP;
    OnBeforeSendingMQTT_DISCONNECT := @HandleOnBeforeSendingMQTT_DISCONNECT;
    OnAfterReceivingMQTT_DISCONNECT := @HandleOnAfterReceivingMQTT_DISCONNECT;
    OnBeforeSendingMQTT_AUTH := @HandleOnBeforeSendingMQTT_AUTH;
    OnAfterReceivingMQTT_AUTH := @HandleOnAfterReceivingMQTT_AUTH;
  {$ENDIF}
end;


procedure TMQTTTestClient.SendDynArrayOfByte(AArr: TDynArrayOfByte);
var
  TempArr: TIdBytes;
begin
  SetLength(TempArr, AArr.Len);
  Move(AArr.Content^, TempArr[0], AArr.Len);
  IdTCPClientObj.IOHandler.Write(TempArr);
end;


procedure TMQTTTestClient.SendPacketToServer(ClientInstance: DWord);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  BufferPointer := MQTT_GetClientToServerBuffer(ClientInstance, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  SendDynArrayOfByte(BufferPointer^);

  {$IFnDEF SingleOutputBuffer}
    if not MQTT_RemovePacketFromClientToServerBuffer(ClientInstance) then
      AddToLog('Can''t remove latest packet from send buffer.');
  {$ELSE}
    raise Exception.Create('MQTT_RemovePacketFromClientToServerBuffer not implemented for SingleOutputBuffer.');
  {$ENDIF}
end;


type
  TMQTTReceiveThread = class(TThread)
  private
    procedure AddToLog(s: string);
  protected
    procedure Execute; override;
  end;


procedure TMQTTReceiveThread.AddToLog(s: string);
begin
  //TTestE2EBuiltinClientsCase.AddToLog(s);
end;



procedure TMQTTReceiveThread.Execute;
var
  TempReadBuf: TDynArrayOfByte;
  TempByte: Byte;
  PacketName: string;
  LoggedDisconnection: Boolean;
  i: Integer;
begin
  try
    InitDynArrayToEmpty(TempReadBuf);

    try
      LoggedDisconnection := False;
      repeat
        for i := 0 to Length(TestClients) - 1 do
        begin
          try
            TempByte := TestClients[i].IdTCPClientObj.IOHandler.ReadByte;
            AddByteToDynArray(TempByte, TempReadBuf);

            if MQTT_ProcessBufferLength(TempReadBuf) = CMQTTDecoderNoErr then
            begin
              MQTTPacketToString(TempReadBuf.Content^[0], PacketName);
              AddToLog('done receiving packet');
              AddToLog('Buffer size: ' + IntToStr(TempReadBuf.Len) + '  Packet header: $' + IntToHex(TempReadBuf.Content^[0]) + ' (' + PacketName + ')');

              TestClients[i].SyncReceivedBuffer(TempReadBuf);   //MQTT_Process returns an error for unknown and incomplete packets

              FreeDynArray(TempReadBuf);   //freed here, only when a valid packet is formed
              Sleep(1);
            end;
          except
          end;
        end;

      until Terminated;
    finally
      AddToLog('Thread done..');
    end;
  except
    on E: Exception do
      AddToLog('Th ex: ' + E.Message);
  end;
end;


type
  TExHandler = class
    procedure CustomExceptionHandler(Sender: TObject; E: Exception);
  end;

var
  FExHandler: TExHandler;


//see https://wiki.freepascal.org/Logging_exceptions
procedure TExHandler.CustomExceptionHandler(Sender: TObject; E: Exception);
var
  ClName, EMsg: string;
begin
  try
    ClName := Sender.ClassName;
  except
    ClName := '';
  end;

  try
    EMsg := E.Message;
  except
    EMsg := '';
  end;

  try
    MessageBoxFunction(PChar('Custom exception in test app: "' + EMsg + '"   Class: "' + ClName + '"."'), 'test app', 0);
  except
    on EE: Exception do
      //MessageBox(0, PChar('Ex on custom exception: ' + EE.Message), 'test app', MB_ICONERROR);
  end;
end;


//see https://wiki.freepascal.org/Logging_exceptions
procedure CatchUnhandledException(Obj: TObject; Addr: Pointer; FrameCount: LongInt; Frames: PPointer);
var
  Msg: string;
  i: Integer;
begin
  try //use another try..excempt, just in case parsing the stack would raise more exceptions
    Msg := 'Unhandled exception at adddr $' + SysBacktraceStr(Addr) + ':' + #13#10;

    if Obj is Exception then
      Msg := Msg + Exception(Obj).ClassName + ' : ' + Exception(Obj).Message
    else
      Msg := Msg + 'Exception object '  + Exception(Obj).ClassName + ' is not class Exception.';

    Msg := Msg + #13#10;
    Msg := Msg + BacktraceStrFunc(Addr) + #13#10;

    for i := 0 to FrameCount - 1 do
      Msg := Msg + BacktraceStrFunc(Frames[i]) + #13#10;

    MessageBoxFunction(PChar('Custom exception in test app: "' + Msg + '".'), 'test app', 0);
  except
  end;
end;


var
  Th: TMQTTReceiveThread;


type                                 ////////////////// Should be moved to Expectations unit
  TLoopedExpect = class(TExpect)
  private
    FActualValue: PString;
    FActualValueInt: PInteger;
    FActualValueBoolean: PBoolean;
  public
    procedure ToBe(ExpectedValue: string; ExtraMessage: string = ''); overload;
    procedure ToBe(ExpectedValue: Integer; ExtraMessage: string = ''); overload;
    procedure ToBe(ExpectedValue: Boolean; ExtraMessage: string = ''); overload;
  end;


function LoopedExpect(ActualValue: PString): TLoopedExpect; overload;
begin
  Result := TLoopedExpect.Create;
  Result.FActualValueInt := nil;
  //Result.FActualValueDWord := ActualValue;
  Result.FActualValue := ActualValue;
  Result.FActualValueBoolean := nil;
end;


function LoopedExpect(ActualValue: PInteger): TLoopedExpect; overload;
begin
  Result := TLoopedExpect.Create;
  Result.FActualValueInt := ActualValue;
  //Result.FActualValueDWord := ActualValue;
  Result.FActualValue := nil;
  Result.FActualValueBoolean := nil;
end;


function LoopedExpect(ActualValue: PBoolean): TLoopedExpect; overload;
begin
  Result := TLoopedExpect.Create;
  Result.FActualValueInt := nil;
  //Result.FActualValueDWord := ActualValue;
  Result.FActualValue := nil;
  Result.FActualValueBoolean := ActualValue;
end;


procedure ExpectStr(ActualValue, ExpectedValue: string; ExtraMsg: string = '');
begin
  if ExpectedValue <> ActualValue then
    raise Exception.Create('Expected "' + ExpectedValue + '", but is was "' + ActualValue + '".  ' + ExtraMsg);
end;


procedure ExpectInt(ActualValue, ExpectedValue: Integer; ExtraMsg: string = '');
begin
  if ExpectedValue <> ActualValue then
    raise Exception.Create('Expected ' + IntToStr(ExpectedValue) + ', but is was ' + IntToStr(ActualValue) + '.  ' + ExtraMsg);
end;


procedure ExpectBoolean(ActualValue, ExpectedValue: Boolean; ExtraMsg: string = '');
begin
  if ExpectedValue <> ActualValue then
    raise Exception.Create('Expected ' + BoolToStr(ExpectedValue, 'True', 'False') + ', but is was ' + BoolToStr(ActualValue, 'True', 'False') + '.  ' + ExtraMsg);
end;


procedure TLoopedExpect.ToBe(ExpectedValue: string; ExtraMessage: string = '');
var
  tk: DWord;
begin
  try
    tk := GetTickCount64;
    repeat
      try
        ExpectStr(FActualValue^, ExpectedValue, ExtraMessage);
        Break;
      except
        if GetTickCount64 - tk > 1000 then
          raise;
      end;

      Application.ProcessMessages;
      Sleep(1);
    until False;
  finally
    Free;
  end;
end;


procedure TLoopedExpect.ToBe(ExpectedValue: Integer; ExtraMessage: string = '');
var
  tk: DWord;
begin
  try
    tk := GetTickCount64;
    repeat
      try
        ExpectInt(FActualValueInt^, ExpectedValue, ExtraMessage);
        Break;
      except
        if GetTickCount64 - tk > 1000 then
          raise;
      end;

      Application.ProcessMessages;
      Sleep(1);
    until False;
  finally
    Free;
  end;
end;


procedure TLoopedExpect.ToBe(ExpectedValue: Boolean; ExtraMessage: string = '');
var
  tk: DWord;
begin
  try
    tk := GetTickCount64;
    repeat
      try
        ExpectBoolean(FActualValueBoolean^, ExpectedValue, ExtraMessage);
        Break;
      except
        if GetTickCount64 - tk > 1000 then
          raise;
      end;

      Application.ProcessMessages;
      Sleep(1);
    until False;
  finally
    Free;
  end;
end;


procedure TTestE2EBuiltinClientsCase.SetUp;
var
  tk: QWord;
  i: Integer;
begin
  FExHandler := TExHandler.Create;
  ExceptProc := @CatchUnhandledException;
  Application.OnException := @FExHandler.CustomExceptionHandler;

  SetLength(TestClients, 2);
  TestClients[0] := TMQTTTestClient.Create(nil);
  TestClients[1] := TMQTTTestClient.Create(nil);
  TestClients[0].ClientIndex := 0;
  TestClients[1].ClientIndex := 1;

  MQTT_Init;
  MQTT_CreateClient; //create first client
  MQTT_CreateClient; //create second client
  //Assigning library events should be done after calling MQTT_Init!
  TestClients[0].InitHandlers;
  TestClients[1].InitHandlers;

  if Th <> nil then
  begin
    Th.Terminate;
    tk := GetTickCount64;
    repeat
      Application.ProcessMessages;
      Sleep(10);
    until (GetTickCount64 - tk > 1500) or Th.Terminated;
    Th := nil;
  end;

  TestClients[0].IdTCPClientObj.Connect('127.0.0.1', 1883);
  TestClients[0].IdTCPClientObj.IOHandler.ReadTimeout := 10;
  TestClients[1].IdTCPClientObj.Connect('127.0.0.1', 1883);
  TestClients[1].IdTCPClientObj.IOHandler.ReadTimeout := 10;

  Th := TMQTTReceiveThread.Create(True);
  Th.FreeOnTerminate := False;
  Th.Start;

  for i := 0 to Length(TestClients) - 1 do
  begin
    Expect(MQTT_CONNECT(i, 0)).ToBe(True, 'Can''t prepare MQTTConnect packet at client index ' + IntToStr(i));
    LoopedExpect(PBoolean(@TestClients[i].ReceivedConAck)).ToBe(True, 'Should receive a ConAck at client index ' + IntToStr(i));
  end;
end;


procedure TTestE2EBuiltinClientsCase.TearDown;
var
  tk: QWord;
  ClientToServerBuf: {$IFDEF SingleOutputBuffer} PMQTTBuffer; {$ELSE} PMQTTMultiBuffer; {$ENDIF}
  Err: Word;
  i: Integer;
begin
  for i := 0 to Length(TestClients) - 1 do
  begin
    if not MQTT_DISCONNECT(i, 0) then
    begin
      TestClients[i].AddToLog('Can''t prepare MQTTDisconnect packet.');
      Exit;
    end;

    tk := GetTickCount64;
    repeat
      try
        ClientToServerBuf := MQTT_GetClientToServerBuffer(i, Err);
        Application.ProcessMessages;
      except
      end;

      Sleep(1);
    until (GetTickCount64 - tk > 1500) or ((ClientToServerBuf <> nil) and (ClientToServerBuf^.Len = 0));
  end;

  TestClients[0].tmrProcessRecData.Enabled := False;
  TestClients[1].tmrProcessRecData.Enabled := False;

  Th.Terminate;
  tk := GetTickCount64;
  repeat
    try
      Application.ProcessMessages;
    except
    end;

    Sleep(1);
  until (GetTickCount64 - tk > 1500) or Th.Terminated;
  Th := nil;

  TestClients[0].IdTCPClientObj.Disconnect(False);
  TestClients[1].IdTCPClientObj.Disconnect(False);

  MQTT_DestroyClient(1);     //after destroying clients, the value of their ClientIndex property becomes invalid
  MQTT_DestroyClient(0);
  MQTT_Done;

  FreeAndNil(TestClients[1]);
  FreeAndNil(TestClients[0]);
  SetLength(TestClients, 0);

  SetLength(FSubscribeToTopicNames, 0);

  FExHandler.Free;
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS0;
begin
  SetLength(FSubscribeToTopicNames, 1);
  FSubscribeToTopicNames[0] := 'abc';

  Expect(MQTT_SUBSCRIBE(1, 0)).ToBe(True);
  LoopedExpect(PInteger(@TestClients[1].FSubscribePacketID)).ToBe(CMQTT_ClientToServerPacketIdentifiersInitOffset);
  LoopedExpect(PInteger(@TestClients[1].FSubAckPacketID)).ToBe(TestClients[1].FSubscribePacketID, 'Should receive a SubAck');

  FTopicNameToPublish := FSubscribeToTopicNames[0];
  FMsgToPublish := 'some content';
  Expect(MQTT_PUBLISH(0, 0, 0)).ToBe(True);
  LoopedExpect(PString(@TestClients[1].FReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS1;
begin
  SetLength(FSubscribeToTopicNames, 1);
  FSubscribeToTopicNames[0] := 'abc';

  Expect(MQTT_SUBSCRIBE(1, 0)).ToBe(True);
  LoopedExpect(PInteger(@TestClients[1].FSubscribePacketID)).ToBe(CMQTT_ClientToServerPacketIdentifiersInitOffset);
  LoopedExpect(PInteger(@TestClients[1].FSubAckPacketID)).ToBe(TestClients[1].FSubscribePacketID, 'Should receive a SubAck');

  FTopicNameToPublish := FSubscribeToTopicNames[0];
  FMsgToPublish := 'some content';
  Expect(MQTT_PUBLISH(0, 0, 1)).ToBe(True);
  LoopedExpect(PString(@TestClients[1].FReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS2;
begin
  SetLength(FSubscribeToTopicNames, 1);
  FSubscribeToTopicNames[0] := 'abc';

  Expect(MQTT_SUBSCRIBE(1, 0)).ToBe(True);
  LoopedExpect(PInteger(@TestClients[1].FSubscribePacketID)).ToBe(CMQTT_ClientToServerPacketIdentifiersInitOffset);
  LoopedExpect(PInteger(@TestClients[1].FSubAckPacketID)).ToBe(TestClients[1].FSubscribePacketID, 'Should receive a SubAck');

  FTopicNameToPublish := FSubscribeToTopicNames[0];
  FMsgToPublish := 'some content';
  Expect(MQTT_PUBLISH(0, 0, 2)).ToBe(True);
  LoopedExpect(PString(@TestClients[1].FReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
end;


initialization
  Th := nil;
  RegisterTest(TTestE2EBuiltinClientsCase);
end.

