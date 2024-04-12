{
    Copyright (C) 2024 VCC
    creation date: 03 Apr 2024 (copied from TestBuiltinClientsCase.pas)
    initial release date: 03 Apr 2024

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


//These tests assume that the broker is configured to relay the messages at the same QoS as published.


unit TestE2EUtils;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls,
  fpcunit, testregistry, IdGlobal, IdTCPClient,
  DynArrays, DynArrayFIFO;


type
  TMQTTTestClient = class(TComponent)
  private
    FClientIndex: Integer;
    FIdTCPClientObj: TIdTCPClient;
    FRecBufFIFO: TDynArrayOfByteFIFO; //used by the reading thread to pass data to MQTT library
    tmrProcessRecData: TTimer;
    FMQTTUsername: string;
    FMQTTPassword: string;

    FIncludeCleanStartFlag: Boolean;

    FReceivedConAck: Boolean;
    FSubscribePacketID: DWord;
    FUnsubscribePacketID: DWord;
    FSubAckPacketID: DWord;
    FUnsubAckPacketID: DWord;

    FSentPublishedMessage: string;
    FReceivedPublishedMessage: string;
    FAllReceivedPublishedMessages: TStringArray;

    FAllReceivedPackets: TStringArray;

    FReceivedPubAck: Boolean;
    FReceivedPubRec: Boolean;
    FReceivedPubRel: Boolean;
    FReceivedPubComp: Boolean;

    FSentPubAck: Boolean;
    FSentPubRec: Boolean;
    FSentPubRel: Boolean;
    FSentPubComp: Boolean;

    FReceivedSessionPresentFlag: Boolean;
    FClientId: string;
    FUseCurrentClientIdInConnect: Boolean;

    FAllowReceivingPubAck: Boolean;
    FAllowReceivingPubRec: Boolean;
    FAllowReceivingPubComp: Boolean;

    FLatestError: Integer;         //Integer, to allow using LoopedExpect
    FLatestPacketOnError: Integer; //Integer, to allow using LoopedExpect

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
    property SubscribePacketID: DWord read FSubscribePacketID write FSubscribePacketID;
    property UnsubscribePacketID: DWord read FUnsubscribePacketID write FUnsubscribePacketID;
    property SubAckPacketID: DWord read FSubAckPacketID write FSubAckPacketID;
    property UnsubAckPacketID: DWord read FUnsubAckPacketID write FUnsubAckPacketID;

    property SentPublishedMessage: string read FSentPublishedMessage write FSentPublishedMessage;
    property ReceivedPublishedMessage: string read FReceivedPublishedMessage write FReceivedPublishedMessage;
    property AllReceivedPublishedMessages: TStringArray read FAllReceivedPublishedMessages;

    property ReceivedPubAck: Boolean read FReceivedPubAck write FReceivedPubAck;
    property ReceivedPubRec: Boolean read FReceivedPubRec write FReceivedPubRec;
    property ReceivedPubRel: Boolean read FReceivedPubRel write FReceivedPubRel;
    property ReceivedPubComp: Boolean read FReceivedPubComp write FReceivedPubComp;

    property SentPubAck: Boolean read FSentPubAck write FSentPubAck;
    property SentPubRec: Boolean read FSentPubRec write FSentPubRec;
    property SentPubRel: Boolean read FSentPubRel write FSentPubRel;
    property SentPubComp: Boolean read FSentPubComp write FSentPubComp;

    property AllowReceivingPubAck: Boolean read FAllowReceivingPubAck write FAllowReceivingPubAck;
    property AllowReceivingPubRec: Boolean read FAllowReceivingPubRec write FAllowReceivingPubRec;
    property AllowReceivingPubComp: Boolean read FAllowReceivingPubComp write FAllowReceivingPubComp;

    property LatestError: Integer read FLatestError;
    property LatestPacketOnError: Integer read FLatestPacketOnError;
  end;


  TMQTTReceiveThread = class(TThread)
  private
    FClient: TMQTTTestClient;
    FAllowExecution: Boolean;

    procedure AddToLog(s: string);
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: Boolean; const StackSize: SizeUInt = DefaultStackSize);

    procedure SuspendExecution;
    procedure ResumeExecution;
  end;


  TTestE2EBuiltinClientsMain = class(TTestCase)
  protected
    procedure TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
    procedure TestPublish_Client0ToClient1_HappyFlow_SendPublish(AQoS: Byte; AMsgToPublish: string = 'some content');
    procedure TestPublish_Client0ToClient1_HappyFlow_SendUnsubscribe(APacketIDOffset: Word = 1);
    procedure DisconnectWithNoCleanStartFlag(AClientIndex: Integer);
    procedure ReconnectToBroker(AClientIndex: Integer; AExpectSessionPresentFlag: Boolean = True);

    procedure SetUp; override;
    procedure TearDown; override;
  end;


var
  TestClients: array of TMQTTTestClient;
  FSubscribeToTopicNames: TStringArray;
  FMsgToPublish: string;
  FTopicNameToPublish: string;

  Ths: array of TMQTTReceiveThread;

implementation


uses
  MQTTClient, MQTTUtils,
  MQTTConnectCtrl, MQTTSubscribeCtrl, MQTTUnsubscribeCtrl,
  Expectations, ExpectationsDynArrays, E2ETestsUserLoggingForm
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


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

  if Lo(AErr) in [CMQTT_ReceiveMaximumExceeded, CMQTT_ReceiveMaximumReset] then   //maybe the server
    MessageBoxFunction(PChar(IntToStr(AErr)), 'CMQTT_ReceiveMaximum', 0);

  TestClients[TempClientInstance].FLatestError := AErr;
  TestClients[TempClientInstance].FLatestPacketOnError := APacketType;
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
      TestClients[TempClientInstance].AddToLog('Cannot send ' + PacketName + ' packet... Ex: "' + E.Message + '"  Length(TestClients): ' + IntToStr(Length(TestClients)) + '  ClientInstance: ' + IntToStr(ClientInstance));
  end;
end;


function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
var
  TempWillProperties: TMQTTWillProperties;
  UserName, Password: string;
  ConnectFlags: Byte;
  EnabledProperties: Word;
  TempClientInstance: DWord;
begin
  Result := True;
  TempClientInstance := ClientInstance and CClientIndexMask;

  TestClients[TempClientInstance].AddToLog('Preparing CONNECT data..');

  TestClients[TempClientInstance].ReceivedConAck := False;  //reset for the next ConAck

  UserName := TestClients[TempClientInstance].FMQTTUsername;
  Password := TestClients[TempClientInstance].FMQTTPassword;

  if TestClients[TempClientInstance].FUseCurrentClientIdInConnect then      //FClientId is initialized on creating the client instance
    StringToDynArrayOfByte(TestClients[TempClientInstance].FClientId, AConnectFields.PayloadContent.ClientID);

  StringToDynArrayOfByte(UserName, AConnectFields.PayloadContent.UserName);
  StringToDynArrayOfByte(Password, AConnectFields.PayloadContent.Password);

  ConnectFlags := CMQTT_UsernameInConnectFlagsBitMask or
                  CMQTT_PasswordInConnectFlagsBitMask;

  if TestClients[TempClientInstance].FIncludeCleanStartFlag then
    ConnectFlags := ConnectFlags or CMQTT_CleanStartInConnectFlagsBitMask;

  //CMQTT_WillQoSB1InConnectFlagsBitMask;  //a different class field is required for this one

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

  {$IFDEF EnUserProperty}
    AddStringToDynOfDynArrayOfByte('Key=Value', TempWillProperties.UserProperty);
    AddStringToDynOfDynArrayOfByte('NewKey=NewValue', TempWillProperties.UserProperty);
  {$ENDIF}

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

  {$IFDEF EnUserProperty}
    AddStringToDynOfDynArrayOfByte('UserProp=Value', AConnectProperties.UserProperty);
  {$ENDIF}

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

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AConnAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}

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
  TestClients[TempClientInstance].FReceivedSessionPresentFlag := AConnAckFields.SessionPresentFlag = 1;
  TestClients[TempClientInstance].FClientId := StringReplace(DynArrayOfByteToString(AConnAckProperties.AssignedClientIdentifier), #0, '#0', [rfReplaceAll]);
  TestClients[TempClientInstance].ReceivedConAck := True;
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

  TestClients[TempClientInstance].SubscribePacketID := ASubscribeFields.PacketIdentifier;
  TestClients[TempClientInstance].AddToLog('');
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

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('ASubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(ASubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}

  TestClients[TempClientInstance].SubAckPacketID := ASubAckFields.PacketIdentifier;
  TestClients[TempClientInstance].AddToLog('');
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

  TestClients[TempClientInstance].UnsubscribePacketID := AUnsubscribeFields.PacketIdentifier;
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

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('AUnsubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AUnsubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}

  TestClients[TempClientInstance].UnsubAckPacketID := AUnsubAckFields.PacketIdentifier;
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
  TestClients[TempClientInstance].AddToLog('Publishing (truncated) "' + Copy(FMsgToPublish, 1, 25) + '" at QoS = ' + IntToStr(QoS));

  Result := Result and StringToDynArrayOfByte(FMsgToPublish, APublishFields.ApplicationMessage);
  Result := Result and StringToDynArrayOfByte(FTopicNameToPublish, APublishFields.TopicName);

  TestClients[TempClientInstance].SentPublishedMessage := FMsgToPublish;
  TestClients[TempClientInstance].AddToLog('');
  //QoS can be overriden here. If users override QoS in this handler, then a a different PacketIdentifier might be allocated (depending on what is available)
end;


//This handler is used when this client publishes a message to broker and the broker responds with PUBACK.
procedure HandleOnBeforeSendingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].SentPubAck := True;

  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBACK');
  TestClients[TempClientInstance].AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  TestClients[TempClientInstance].AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  TestClients[TempClientInstance].AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  TestClients[TempClientInstance].AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}

  TestClients[TempClientInstance].AddToLog('');
  //This handler can be used to override what is being sent to server as a reply to PUBLISH
end;


procedure HandleOnAfterReceivingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].ReceivedPubAck := True;

  TestClients[TempClientInstance].AddToLog('Received PUBACK');
  TestClients[TempClientInstance].AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  TestClients[TempClientInstance].AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  TestClients[TempClientInstance].AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  TestClients[TempClientInstance].AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  TestClients[TempClientInstance].AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}

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
  Msg := DynArrayOfByteToString(APublishFields.ApplicationMessage); //}FastReplace0To1(DynArrayOfByteToString(APublishFields.ApplicationMessage));
  ID := APublishFields.PacketIdentifier;
  Topic := DynArrayOfByteToString(APublishFields.TopicName); //StringReplace(DynArrayOfByteToString(APublishFields.TopicName), #0, '#0', [rfReplaceAll]);

  TestClients[TempClientInstance].AddToLog('Received PUBLISH  ServerPacketIdentifier: ' + IntToStr(ID) +
                                                 '  Msg (truncated): ' + Copy(Msg, 1, 25) +
                                                 '  QoS: ' + IntToStr(QoS) +
                                                 '  TopicName: ' + Topic);

  s := '';
  for i := 0 to APublishProperties.SubscriptionIdentifier.Len - 1 do
    s := s + IntToStr(APublishProperties.SubscriptionIdentifier.Content^[i]) + ', ';
  TestClients[TempClientInstance].AddToLog('SubscriptionIdentifier(s): ' + s);

  TestClients[TempClientInstance].ReceivedPublishedMessage := Msg; //ReceivedPublishedMessage is the latest received message
  SetLength(TestClients[TempClientInstance].FAllReceivedPublishedMessages, Length(TestClients[TempClientInstance].FAllReceivedPublishedMessages) + 1);
  TestClients[TempClientInstance].FAllReceivedPublishedMessages[Length(TestClients[TempClientInstance].FAllReceivedPublishedMessages) - 1] := Msg;

  TestClients[TempClientInstance].AddToLog('');
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].SentPubRec := True;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBREC for ServerPacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].ReceivedPubRec := True;
  TestClients[TempClientInstance].AddToLog('Received PUBREC for PacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


//Sending PUBREL after the PUBREC response from server, after the client has sent a PUBLISH packet with QoS=2.
procedure HandleOnBeforeSending_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].SentPubRel := True;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBREL for PacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].ReceivedPubRel := True;
  TestClients[TempClientInstance].AddToLog('Received PUBREL for ServerPacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].SentPubComp := True;
  TestClients[TempClientInstance].AddToLog('Acknowledging with PUBCOMP for PacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  TestClients[TempClientInstance].ReceivedPubComp := True;
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

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('ADisconnectProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(ADisconnectProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}
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

  {$IFDEF EnUserProperty}
    TestClients[TempClientInstance].AddToLog('AAuthProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(AAuthProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  {$ENDIF}
end;


{$IFDEF IsDesktop}
  {$IFDEF UsingDynTFT}
    {$IFDEF LogMem}
      type
        TMemRec = record
          Address, Size: DWord;
        end;

        TMemRecArr = array of TMemRec;

      var
        MemArr: TMemRecArr;

      function GetMemArrItemIndex(AAllocatedAddress: DWord): Integer;
      var
        i: Integer;
      begin
        Result := -1;
        for i := 0 to Length(MemArr) - 1 do
          if MemArr[i].Address = AAllocatedAddress then
          begin
            Result := i;
            Break;
          end;
      end;

      procedure HandleOnAfterGetMem(AAllocatedAddress, ARequestedSize: DWord);
      var
        FoundIndex: Integer;
      begin
        //AddToUserLog(DateTimeToStr(Now) + '(' + IntToStr(GetTickCount64) + ') [GetMem]: Req = ' + IntToStr(ARequestedSize) + ' UsedBlocks: ' + IntToStr(MM_GetNrFreeBlocksUsed)); //MM_GetNrFreeBlocksUsed is a function, declared in MemManager.pas, which returns MM_NrFreeBlocksUsed.

        FoundIndex := GetMemArrItemIndex(AAllocatedAddress);
        if FoundIndex > -1 then
        begin
          AddToUserLog('============================ Reallocation error.  OldSize: ' + IntToStr(MemArr[FoundIndex].Size) + '  NewSize: ' + IntToStr(ARequestedSize));
          MemArr[FoundIndex].Size := ARequestedSize;
          frmE2ETestsUserLogging.Caption := 'Re';
        end
        else
        begin
          SetLength(MemArr, Length(MemArr) + 1);
          MemArr[Length(MemArr) - 1].Address := AAllocatedAddress;
          MemArr[Length(MemArr) - 1].Size := ARequestedSize;
        end;
      end;

      procedure HandleOnAfterFreeMem(AAllocatedAddress, ARequestedSize: DWord);
      var
        FoundIndex, i: Integer;
      begin
        //AddToUserLog(DateTimeToStr(Now) + '(' + IntToStr(GetTickCount64) + ') [FreeMem]: Req = ' + IntToStr(ARequestedSize) + ' UsedBlocks: ' + IntToStr(MM_GetNrFreeBlocksUsed));

        FoundIndex := GetMemArrItemIndex(AAllocatedAddress);
        if FoundIndex > -1 then
        begin
          if ARequestedSize <> MemArr[FoundIndex].Size then
          begin
            AddToUserLog('============================ Free error. Attempting to free a different size.  ExistingSize: ' + IntToStr(MemArr[FoundIndex].Size) + '  ReqSize: ' + IntToStr(ARequestedSize));;
            frmE2ETestsUserLogging.Caption := 'Err1';
          end;

          for i := FoundIndex to Length(MemArr) - 2 do
            MemArr[i] := MemArr[i + 1];

          SetLength(MemArr, Length(MemArr) - 1);
        end
        else
        begin
          AddToUserLog('============================ Free error. Attempting to free from unallocated address: ' + IntToStr(AAllocatedAddress) + '  ReqSize = ' + IntToStr(ARequestedSize));
          frmE2ETestsUserLogging.Caption := 'Err2';
        end;
      end;
    {$ENDIF}
  {$ENDIF}
{$ENDIF}


constructor TMQTTTestClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRecBufFIFO := TDynArrayOfByteFIFO.Create;
  FIdTCPClientObj := TIdTCPClient.Create(Self);
  FIdTCPClientObj.OnConnected := @HandleClientOnConnected;
  FIdTCPClientObj.OnDisconnected := @HandleClientOnDisconnected;

  tmrProcessRecData := TTimer.Create(Self);
  tmrProcessRecData.Interval := 10;
  tmrProcessRecData.OnTimer := @tmrProcessRecDataTimer;
  tmrProcessRecData.Enabled := True;

  FMQTTUsername := '';
  FMQTTPassword := '';
  FIncludeCleanStartFlag := True;

  FReceivedConAck := False;
  FSubscribePacketID := 0;
  FUnsubscribePacketID := 0;
  FSubAckPacketID := 0;
  FUnsubAckPacketID := 0;
  FSentPublishedMessage := 'NotSet';
  FReceivedPublishedMessage := 'NotSetYet';
  SetLength(FAllReceivedPublishedMessages, 0);

  FReceivedPubAck := False;
  FReceivedPubRec := False;
  FReceivedPubRel := False;
  FReceivedPubComp := False;

  FSentPubAck := False;
  FSentPubRec := False;
  FSentPubRel := False;
  FSentPubComp := False;

  FReceivedSessionPresentFlag := False;
  FClientId := 'SomeClientID';
  FUseCurrentClientIdInConnect := False;

  FAllowReceivingPubAck := True;
  FAllowReceivingPubRec := True;
  FAllowReceivingPubComp := True;

  FLatestError := CMQTT_Success;
  FLatestPacketOnError := CMQTT_UNDEFINED;
end;


destructor TMQTTTestClient.Destroy;
begin
  FreeAndNil(FRecBufFIFO);
  SetLength(FAllReceivedPublishedMessages, 0);

  inherited Destroy;
end;


procedure TMQTTTestClient.AddToLog(s: string);
begin
  AddToUserLog(DateTimeToStr(Now) + '(' + IntToStr(GetTickCount64) + ') [Client ' + IntToStr(FClientIndex) + ']: ' + s);
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
  FRecBufFIFO.Put(AReadBuf);
end;


procedure TMQTTTestClient.ProcessReceivedBuffer;  //called by a timer, to process received data
var
  TempReadBuf: TDynArrayOfByte;
  NewData: string;
  Allow: Boolean;
  PacketType: Byte;
  ErrMsg: string;
begin
  //InitDynArrayToEmpty(TempReadBuf);

  if FRecBufFIFO.Pop(TempReadBuf) then
  begin
    NewData := DynArrayOfByteToString(TempReadBuf);

    SetLength(FAllReceivedPackets, Length(FAllReceivedPackets) + 1);
    FAllReceivedPackets[Length(FAllReceivedPackets) - 1] := NewData;

    try
      if TempReadBuf.Len > 0 then
      begin
        PacketType := Ord(NewData[1]) and $F0;
        Allow := (FAllowReceivingPubAck and (PacketType = CMQTT_PUBACK)) or
                 (FAllowReceivingPubRec and (PacketType = CMQTT_PUBREC)) or
                 (FAllowReceivingPubComp and (PacketType = CMQTT_PUBCOMP)) or
                 not (PacketType in [CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBCOMP]);
      end
      else
        Allow := True;

      if Allow then
      begin
        if not MQTT_PutReceivedBufferToMQTTLib(FClientIndex, TempReadBuf) then
        begin
          ErrMsg := 'Out of memory when calling MQTT_PutReceivedBufferToMQTTLib. FClientIndex = ' + IntToStr(FClientIndex) {$IFDEF UsingDynTFT} + #13#10 + 'FreeMem: ' + IntToStr(MM_TotalFreeMemSize) + #13#10 + 'LargestFreeMemBlock: ' + IntToStr(MM_LargestFreeMemBlock) {$ENDIF};
          AddToLog(ErrMsg);
          MessageBoxFunction(PChar(ErrMsg), 'ProcessReceivedBuffer', 0);
        end
        else
          if MQTT_Process(FClientIndex) and $FF = CMQTT_OutOfMemory then
          begin
            ErrMsg := 'Out of memory when calling MQTT_Process. FClientIndex = ' + IntToStr(FClientIndex) {$IFDEF UsingDynTFT} + #13#10 + 'FreeMem: ' + IntToStr(MM_TotalFreeMemSize) + #13#10 + 'LargestFreeMemBlock: ' + IntToStr(MM_LargestFreeMemBlock) {$ENDIF};
            AddToLog(ErrMsg);
            MessageBoxFunction(PChar(ErrMsg), 'ProcessReceivedBuffer', 0);
          end ;
      end;
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

  //AddToLog('---Before removing packet from buffer');
  {$IFnDEF SingleOutputBuffer}
    if not MQTT_RemovePacketFromClientToServerBuffer(ClientInstance) then
      AddToLog('Can''t remove latest packet from send buffer.');
  {$ELSE}
    raise Exception.Create('MQTT_RemovePacketFromClientToServerBuffer not implemented for SingleOutputBuffer.');
  {$ENDIF}
  //AddToLog('---After removing packet from buffer');
end;


{TMQTTReceiveThrea}
constructor TMQTTReceiveThread.Create(CreateSuspended: Boolean; const StackSize: SizeUInt = DefaultStackSize);
begin
  inherited Create(CreateSuspended, StackSize);
  FAllowExecution := True;
end;


procedure TMQTTReceiveThread.AddToLog(s: string);
begin
  try
    FClient.AddToLog('[Th]: ' + s);
  except
  end;
end;



procedure TMQTTReceiveThread.Execute;
var
  TempReadBuf, ExactPacket: TDynArrayOfByte;
  TempByte: Byte;
  PacketName: string;
  PacketSize: DWord;
  TempArr: TIdBytes;
  SuccessfullyDecoded: Boolean;
  ProcessBufferLengthResult: Word;
begin
  try
    InitDynArrayToEmpty(TempReadBuf);
    InitDynArrayToEmpty(ExactPacket);

    try
      repeat
        try
          if FAllowExecution then
          begin
            //try
            //  TempByte := FClient.IdTCPClientObj.IOHandler.ReadByte;
            //  if not AddByteToDynArray(TempByte, TempReadBuf) then
            //  begin
            //    AddToLog('Cannot allocate buffer when reading. TempReadBuf.Len = ' + IntToStr(TempReadBuf.Len));
            //    MessageBoxFunction('Cannot allocate buffer when reading.', 'th_', 0);
            //    FreeDynArray(TempReadBuf);
            //  end;
            //except
            //  on E: Exception do      ////////////////// ToDo: switch to EIdReadTimeout
            //  begin
            //    if (E.Message = 'Read timed out.') and (TempReadBuf.Len > 0) then
            //      if MQTT_ProcessBufferLength(TempReadBuf, PacketSize) = CMQTTDecoderNoErr then
            //    begin
            //      MQTTPacketToString(TempReadBuf.Content^[0], PacketName);
            //      AddToLog('done receiving packet: ' + E.Message + {'   ReadCount: ' + IntToStr(ReadCount) +} '   E.ClassName: ' + E.ClassName);
            //      AddToLog('Buffer size: ' + IntToStr(TempReadBuf.Len) + '  Packet header: $' + IntToHex(TempReadBuf.Content^[0]) + ' (' + PacketName + ')');
            //
            //      FClient.SyncReceivedBuffer(TempReadBuf);
            //
            //      FreeDynArray(TempReadBuf);
            //      //ReadCount := 0; //reset for next packet
            //    end;
            //
            //    Sleep(1);
            //  end;
            //end; //try

            TempByte := FClient.IdTCPClientObj.IOHandler.ReadByte;
            if not AddByteToDynArray(TempByte, TempReadBuf) then
            begin
              AddToLog('Cannot allocate buffer when reading. TempReadBuf.Len = ' + IntToStr(TempReadBuf.Len));
              MessageBoxFunction('Cannot allocate buffer when reading.', 'th_', 0);
              FreeDynArray(TempReadBuf);
            end
            else
            begin
              SuccessfullyDecoded := True;                                         //PacketSize should be the expected size, which can be greater than TempReadBuf.Len
              ProcessBufferLengthResult := MQTT_ProcessBufferLength(TempReadBuf, PacketSize);

              if ProcessBufferLengthResult <> CMQTTDecoderNoErr then
                SuccessfullyDecoded := False
              else
                if ProcessBufferLengthResult = CMQTTDecoderIncompleteBuffer then  //PacketSize is successfully decoded, but the packet is incomplete
                begin
                  //to get a complete packet, then the number of bytes to be read next is PacketSize - TempReadBuf.Len.
                  FClient.IdTCPClientObj.IOHandler.ReadTimeout := 1000;
                  SetLength(TempArr, 0);
                  FClient.IdTCPClientObj.IOHandler.ReadBytes(TempArr, PacketSize - TempReadBuf.Len);

                  if Length(TempArr) > 0 then //it should be >0, otherwise there should be a read timeout excption
                    if not AddBufferToDynArrayOfByte(@TempArr[0], Length(TempArr), TempReadBuf) then
                    begin
                      AddToLog('Out of memory on allocating TempReadBuf, for multiple bytes.');
                      MessageBoxFunction('Cannot allocate buffer when reading multiple bytes.', 'th_', 0);
                      FreeDynArray(TempReadBuf);
                    end
                    else
                    begin
                      ProcessBufferLengthResult := MQTT_ProcessBufferLength(TempReadBuf, PacketSize);
                      SuccessfullyDecoded := ProcessBufferLengthResult <> CMQTTDecoderNoErr;
                    end;

                  FClient.IdTCPClientObj.IOHandler.ReadTimeout := 10;
                end;

              if SuccessfullyDecoded then
              begin
                MQTTPacketToString(TempReadBuf.Content^[0], PacketName);
                AddToLog('done receiving packet');
                AddToLog('Buffer size: ' + IntToStr(TempReadBuf.Len) + '  Packet header: $' + IntToHex(TempReadBuf.Content^[0]) + ' (' + PacketName + ')');

                if PacketSize <> TempReadBuf.Len then
                begin
                  if CopyFromDynArray(ExactPacket, TempReadBuf, 0, PacketSize) then
                  begin
                    FClient.SyncReceivedBuffer(ExactPacket);
                    FreeDynArray(ExactPacket);
                    if not RemoveStartBytesFromDynArray(PacketSize, TempReadBuf) then
                      AddToLog('Cannot remove processed packet from TempReadBuf. Packet type: '+ PacketName);
                  end
                  else
                    AddToLog('Out of memory on allocating ExactPacket.');
                end
                else
                begin
                  FClient.SyncReceivedBuffer(TempReadBuf);   //MQTT_Process returns an error for unknown and incomplete packets
                  FreeDynArray(TempReadBuf);   //freed here, only when a valid packet is formed
                end;

                Sleep(1);
              end; //SuccessfullyDecoded
            end;
          end  //FAllowExecution
          else
            Sleep(1);
        except
        end;
      until Terminated;
    finally
      AddToLog('Thread done..');
      FreeDynArray(TempReadBuf);
    end;
  except
    on E: Exception do
      AddToLog('Th ex: ' + E.Message);
  end;
end;


procedure TMQTTReceiveThread.SuspendExecution;
begin
  FAllowExecution := False;
end;


procedure TMQTTReceiveThread.ResumeExecution;
begin
  FAllowExecution := True;
end;


{TTestE2EBuiltinClientsMain}
procedure TTestE2EBuiltinClientsMain.SetUp;
var
  i: Integer;
begin
  AddToUserLog('Starting test: ' + Self.GetTestName);

  {$IFDEF UsingDynTFT}
    MM_Init;
    {$IFDEF LogMem}
      SetLength(MemArr, 0);
    {$ENDIF}
    //MessageBoxFunction(PChar(IntToStr(HEAP_SIZE)), 'HEAP_SIZE', 0);
  {$ENDIF}

  SetLength(TestClients, 2);
  TestClients[0] := TMQTTTestClient.Create(nil);
  TestClients[1] := TMQTTTestClient.Create(nil);
  TestClients[0].ClientIndex := 0;
  TestClients[1].ClientIndex := 1;

  MQTT_Init;
  Expect(MQTT_CreateClient).ToBe(True, 'Should create first client.');
  Expect(MQTT_CreateClient).ToBe(True, 'Should create second client.');
  //Assigning library events should be done after calling MQTT_Init!
  TestClients[0].InitHandlers;
  TestClients[1].InitHandlers;

  SetLength(Ths, 2);

  for i := 0 to Length(TestClients) - 1 do
    if Ths[i] <> nil then
    begin
      Ths[i].Terminate;
      LoopedExpect(PBoolean(@Ths[i].Terminated), 1500).ToBe(True);
      FreeAndNil(Ths[i]);
    end;

  TestClients[0].IdTCPClientObj.Connect('127.0.0.1', 1883);
  TestClients[0].IdTCPClientObj.IOHandler.ReadTimeout := 10;
  TestClients[1].IdTCPClientObj.Connect('127.0.0.1', 1883);
  TestClients[1].IdTCPClientObj.IOHandler.ReadTimeout := 10;

  for i := 0 to Length(TestClients) - 1 do
  begin
    Ths[i] := TMQTTReceiveThread.Create(True);
    Ths[i].FreeOnTerminate := False;
    Ths[i].FClient := TestClients[i];
    Ths[i].Start;
  end;

  for i := 0 to Length(TestClients) - 1 do
  begin
    Expect(MQTT_CONNECT(i, 0)).ToBe(True, 'Can''t prepare MQTTConnect packet at client index ' + IntToStr(i));
    LoopedExpect(PBoolean(@TestClients[i].ReceivedConAck)).ToBe(True, 'Should receive a ConAck at client index ' + IntToStr(i));
  end;
end;


function ClientToServerBufEmpty0: Boolean;
var
  ClientToServerBuf: {$IFDEF SingleOutputBuffer} PMQTTBuffer; {$ELSE} PMQTTMultiBuffer; {$ENDIF}
  Err: Word;
begin
  ClientToServerBuf := MQTT_GetClientToServerBuffer(0, Err);
  Result := (ClientToServerBuf <> nil) and (ClientToServerBuf^.Len = 0);
end;


function ClientToServerBufEmpty1: Boolean;
var
  ClientToServerBuf: {$IFDEF SingleOutputBuffer} PMQTTBuffer; {$ELSE} PMQTTMultiBuffer; {$ENDIF}
  Err: Word;
begin
  ClientToServerBuf := MQTT_GetClientToServerBuffer(1, Err);
  Result := (ClientToServerBuf <> nil) and (ClientToServerBuf^.Len = 0);
end;



procedure TTestE2EBuiltinClientsMain.TearDown;
var
  i, j: Integer;
  s: string;
  MemLeft, MemTrackedByMemArr: DWord;
begin
  try
    {$IFDEF UsingDynTFT}
      MemLeft := MM_TotalFreeMemSize;
      AddToUserLog('Memory left before disconnecting: ' + IntToStr(MemLeft) + ' / ' + IntToStr(HEAP_SIZE) + '    FreeBlocksUsed: ' + IntToStr(MM_GetNrFreeBlocksUsed));

      {$IFDEF LogMem}
        MemTrackedByMemArr := 0;
        for i := 0 to Length(MemArr) - 1 do
        begin
          Inc(MemTrackedByMemArr, MemArr[i].Size);
          AddToUserLog('MemArr[' + IntToStr(i) + '].Addr = ' + IntToStr(MemArr[i].Address) + '   MemArr[' + IntToStr(i) + '].Size = ' + IntToStr(MemArr[i].Size));
        end;

        AddToUserLog('Memory left before disconnecting (tracked by MemArr): ' + IntToStr(HEAP_SIZE - MemTrackedByMemArr) + ' / ' + IntToStr(HEAP_SIZE) + '   Used: ' + IntToStr(MemTrackedByMemArr) + '   AllocationsCount: ' + IntToStr(Length(MemArr)));
      {$ENDIF}

      //Expect(MemLeft).ToBeGreaterThan(1000, 'There is no memory left to disconnect.');
    {$ENDIF}
    try
      if MemLeft > 1000 then
      begin
        Expect(MQTT_DISCONNECT(0, 0)).ToBe(True, 'Can''t prepare MQTTDisconnect packet. (Client 0)');
        Expect(MQTT_DISCONNECT(1, 0)).ToBe(True, 'Can''t prepare MQTTDisconnect packet. (Client 1)');
        LoopedExpect(@ClientToServerBufEmpty0, 1500).ToBe(True, 'Buffer 0 should be empty.');
        LoopedExpect(@ClientToServerBufEmpty1, 1500).ToBe(True, 'Buffer 1 should be empty.');
      end;
    finally
      TestClients[0].tmrProcessRecData.Enabled := False;
      TestClients[1].tmrProcessRecData.Enabled := False;

      for i := 0 to Length(TestClients) - 1 do
        Ths[i].Terminate;

      for i := 0 to Length(TestClients) - 1 do
      begin
        LoopedExpect(PBoolean(@Ths[i].Terminated), 1500).ToBe(True, 'Thread ' + IntToStr(i) + ' should be terminated.');
        FreeAndNil(Ths[i]);
      end;

      TestClients[0].IdTCPClientObj.Disconnect(False);
      TestClients[1].IdTCPClientObj.Disconnect(False);

      if MemLeft > 100 then
      begin
        MQTT_DestroyClient(1);     //after destroying clients, the value of their ClientIndex property becomes invalid
        MQTT_DestroyClient(0);
        MQTT_Done;
      end;

      //s := '';
      //for j := 0 to Length(TestClients[1].FAllReceivedPackets) - 1 do
      //begin
      //  s := s + MQTTPacketToString(Ord(TestClients[1].FAllReceivedPackets[j][1])) + '=';
      //
      //  for i := 1 to Length(TestClients[1].FAllReceivedPackets[j]) do
      //    s := s + IntToStr(Ord(TestClients[1].FAllReceivedPackets[j][i])) + ', ';
      //
      //  s := s + #13#10;
      //end;
      //MessageBoxFunction(PChar(s), 'All received packets', 0);
    end;

    SetLength(TestClients[1].FAllReceivedPackets, 0);

    FreeAndNil(TestClients[1]);
    FreeAndNil(TestClients[0]);
    SetLength(TestClients, 0);

    SetLength(FSubscribeToTopicNames, 0);
    SetLength(Ths, 0);
  finally
    {$IFDEF UsingDynTFT}
      {$IFDEF LogMem}
        SetLength(MemArr, 0);
      {$ENDIF}
    {$ENDIF}
    AddToUserLog('Done test: ' + Self.GetTestName);
  end;
end;


procedure TTestE2EBuiltinClientsMain.TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
begin
  SetLength(FSubscribeToTopicNames, 1);
  FSubscribeToTopicNames[0] := 'abc';

  Expect(MQTT_SUBSCRIBE(1, 0)).ToBe(True, 'Subscribed');
  LoopedExpect(PDWord(@TestClients[1].FSubscribePacketID)).ToBe(CMQTT_ClientToServerPacketIdentifiersInitOffset);
  LoopedExpect(PDWord(@TestClients[1].FSubAckPacketID)).ToBe(TestClients[1].FSubscribePacketID, 'Should receive a SubAck');
end;


procedure TTestE2EBuiltinClientsMain.TestPublish_Client0ToClient1_HappyFlow_SendPublish(AQoS: Byte; AMsgToPublish: string = 'some content');
begin
  Expect(Length(FSubscribeToTopicNames)).ToBeGreaterThan(0, 'There should be a topic name.');
  FTopicNameToPublish := FSubscribeToTopicNames[0];
  FMsgToPublish := AMsgToPublish;
  Expect(MQTT_PUBLISH(0, 0, AQoS)).ToBe(True, 'published at QoS = ' + IntToStr(AQoS));
  LoopedExpect(PString(@TestClients[0].FSentPublishedMessage)).ToBe(FMsgToPublish, 'Should send a Publish with "' + FMsgToPublish + '".');
end;


procedure TTestE2EBuiltinClientsMain.TestPublish_Client0ToClient1_HappyFlow_SendUnsubscribe(APacketIDOffset: Word = 1);
begin
  SetLength(FSubscribeToTopicNames, 1);
  FSubscribeToTopicNames[0] := 'abc';

  Expect(MQTT_UNSUBSCRIBE(1, 0)).ToBe(True, 'Unsubscribed');
  LoopedExpect(PDWord(@TestClients[1].FUnsubscribePacketID)).ToBe(CMQTT_ClientToServerPacketIdentifiersInitOffset + APacketIDOffset);
  LoopedExpect(PDWord(@TestClients[1].FUnsubAckPacketID)).ToBe(TestClients[1].FUnsubscribePacketID, 'Should receive an UnsubAck');
end;


procedure TTestE2EBuiltinClientsMain.DisconnectWithNoCleanStartFlag(AClientIndex: Integer);
begin
  Ths[AClientIndex].SuspendExecution; //pause the receiving thread while disconnected
  TestClients[AClientIndex].IdTCPClientObj.Disconnect;                       ////////////////// ToDo: test also with sending a DISCONNECT packet  (maybe it should not keep the session.
  Sleep(500); //wait a bit, so the broker invalidates the connection         ////////////////// ToDo: test also with  session timeouts
  TestClients[AClientIndex].FIncludeCleanStartFlag := False;
end;


procedure TTestE2EBuiltinClientsMain.ReconnectToBroker(AClientIndex: Integer; AExpectSessionPresentFlag: Boolean = True);
begin
  Ths[AClientIndex].ResumeExecution;
  TestClients[AClientIndex].IdTCPClientObj.Connect('127.0.0.1', 1883);
  TestClients[AClientIndex].IdTCPClientObj.IOHandler.ReadTimeout := 10;

  TestClients[AClientIndex].FUseCurrentClientIdInConnect := True;
  Expect(MQTT_CONNECT(AClientIndex, 1)).ToBe(True, 'Can''t prepare MQTTConnect packet at client index 1 for second connection.');  //should use FClientId
  LoopedExpect(PBoolean(@TestClients[AClientIndex].ReceivedConAck)).ToBe(True, 'Should receive a ConAck at client index 1');
  LoopedExpect(PBoolean(@TestClients[AClientIndex].FReceivedSessionPresentFlag)).ToBe(AExpectSessionPresentFlag, 'Should receive a ConAck with SessionPresent flag');
end;


initialization
  {$IFDEF IsDesktop}
    {$IFDEF UsingDynTFT}
      {$IFDEF LogMem}
        OnAfterGetMem := @HandleOnAfterGetMem;
        OnAfterFreeMem := @HandleOnAfterFreeMem;
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
end.

