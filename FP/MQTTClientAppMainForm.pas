{
    Copyright (C) 2024 VCC
    creation date: 22 Apr 2023
    initial release date: 14 Mar 2024

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


unit MQTTClientAppMainForm;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, IdTCPClient, IdGlobal, DynArrays, PollingFIFO;

type

  { TfrmMQTTClientAppMain }

  TfrmMQTTClientAppMain = class(TForm)
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnSetToLocalhost: TButton;
    btnPublish: TButton;
    btnSubscribeTo: TButton;
    btnUnSubscribeFrom: TButton;
    btnPing: TButton;
    btnAuth: TButton;
    btnResendUnAck: TButton;
    chkAddInc: TCheckBox;
    cmbQoS: TComboBox;
    grpStatistics: TGroupBox;
    grpSubscription: TGroupBox;
    grpPublish: TGroupBox;
    IdTCPClient1: TIdTCPClient;
    lblClientToServerBufferSize: TLabel;
    lblClientToServerResendBufferSize: TLabel;
    lblClientToServerBufferSizeInfo: TLabel;
    lblClientToServerResendBufferSizeInfo: TLabel;
    lblServerToClientIDCount: TLabel;
    lblServerToClientPacketIDCountInfo: TLabel;
    lblServerToClientBufferSize: TLabel;
    lblClientToServerIDCount: TLabel;
    lblServerToClientBufferSizeInfo: TLabel;
    lblQoS: TLabel;
    lbeTopicName: TLabeledEdit;
    lbeTopicNameToPublish: TLabeledEdit;
    lbeAppMsgToPublish: TLabeledEdit;
    lbeUser: TLabeledEdit;
    lbeAddress: TLabeledEdit;
    lbePort: TLabeledEdit;
    lblClientToServerPacketIDCountInfo: TLabel;
    memLog: TMemo;
    prbUsedMemory: TProgressBar;
    tmrProcessRecData: TTimer;
    tmrProcessLog: TTimer;
    tmrStartup: TTimer;
    procedure btnAuthClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnPingClick(Sender: TObject);
    procedure btnPublishClick(Sender: TObject);
    procedure btnResendUnAckClick(Sender: TObject);
    procedure btnSetToLocalhostClick(Sender: TObject);
    procedure btnSubscribeToClick(Sender: TObject);
    procedure btnUnSubscribeFromClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrProcessLogTimer(Sender: TObject);
    procedure tmrProcessRecDataTimer(Sender: TObject);
    procedure tmrStartupTimer(Sender: TObject);
  private
    FMQTTPassword: string;
    FLoggingFIFO: TPollingFIFO;
    FRecBufFIFO: TPollingFIFO; //used by the reading thread to pass data to MQTT library

    procedure LogDynArrayOfByte(var AArr: TDynArrayOfByte; ADisplayName: string = '');

    procedure HandleClientOnConnected(Sender: TObject);
    procedure HandleClientOnDisconnected(Sender: TObject);

    procedure SendString(AString: string);
    procedure SendDynArrayOfByte(AArr: TDynArrayOfByte);
    procedure SendPacketToServer(ClientInstance: DWord);

    procedure AddToLog(AMsg: string);
    procedure SyncReceivedBuffer(var AReadBuf: TDynArrayOfByte);
    procedure ProcessReceivedBuffer;

    procedure InitHandlers;
  public

  end;


var
  frmMQTTClientAppMain: TfrmMQTTClientAppMain;

implementation

{$R *.frm}

uses
  MQTTUtils, MQTTClient, MQTTConnectCtrl, MQTTConnAckCtrl, MQTTSubscribeCtrl, MQTTUnsubscribeCtrl;


var
  DecodedConnAckPropertiesArr: TMQTTConnAckPropertiesArr;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
var
  PacketTypeStr: string;
begin
  MQTTPacketToString(APacketType, PacketTypeStr);
  frmMQTTClientAppMain.AddToLog('Client: ' + IntToHex(ClientInstance, 8) + '  Err: $' + IntToHex(AErr) + '  PacketType: $' + IntToHex(APacketType) + ' (' + PacketTypeStr + ').');  //The error is made of an upper byte and a lower byte.

  if Hi(AErr) = CMQTT_Reason_NotAuthorized then   // $87
  begin
    frmMQTTClientAppMain.AddToLog('Server error: Not authorized.');
    if APacketType = CMQTT_CONNACK then
      frmMQTTClientAppMain.AddToLog('             on receiving CONNACK.');
  end;

  if Lo(AErr) = CMQTT_PacketIdentifierNotFound_ClientToServer then   // $CE
    frmMQTTClientAppMain.AddToLog('Client error: PacketIdentifierNotFound.');
end;


procedure HandleOnSend_MQTT_Packet(ClientInstance: DWord; APacketType: Byte);
var
  PacketName: string;
begin
  MQTTPacketToString(APacketType, PacketName);
  frmMQTTClientAppMain.AddToLog('Sending ' + PacketName + ' packet...');

  try
    frmMQTTClientAppMain.SendPacketToServer(ClientInstance);
  except
    on E: Exception do
      frmMQTTClientAppMain.AddToLog('Cannot send ' + PacketName + ' packet... Ex: ' + E.Message);
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
begin
  Result := True;

  frmMQTTClientAppMain.AddToLog('Preparing CONNECT data..');

  //Id := Chr((ClientInstance and $FF) + 48);
  //ClientId := 'MyClient' + Id;
  UserName := frmMQTTClientAppMain.lbeUser.Text;
  Password := frmMQTTClientAppMain.FMQTTPassword;

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

  frmMQTTClientAppMain.AddToLog('Done preparing CONNECT data..');
  frmMQTTClientAppMain.AddToLog('');
end;


procedure HandleOnAfterMQTT_CONNACK(ClientInstance: DWord; var AConnAckFields: TMQTTConnAckFields; var AConnAckProperties: TMQTTConnAckProperties);
var
  n, i: Integer;
begin
  frmMQTTClientAppMain.AddToLog('Received CONNACK');

  frmMQTTClientAppMain.AddToLog('ConnAckFields.EnabledProperties: ' + IntToStr(AConnAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('ConnAckFields.SessionPresentFlag: ' + IntToStr(AConnAckFields.SessionPresentFlag));
  frmMQTTClientAppMain.AddToLog('ConnAckFields.ConnectReasonCode: ' + IntToStr(AConnAckFields.ConnectReasonCode));  //should be 0

  n := Length(DecodedConnAckPropertiesArr);
  SetLength(DecodedConnAckPropertiesArr, n + 1);
  MQTT_InitConnAckProperties(DecodedConnAckPropertiesArr[n]);
  MQTT_CopyConnAckProperties(AConnAckProperties, DecodedConnAckPropertiesArr[n]);

  frmMQTTClientAppMain.AddToLog('SessionExpiryInterval: ' + IntToStr(AConnAckProperties.SessionExpiryInterval));
  frmMQTTClientAppMain.AddToLog('ReceiveMaximum: ' + IntToStr(AConnAckProperties.ReceiveMaximum));
  frmMQTTClientAppMain.AddToLog('MaximumQoS: ' + IntToStr(AConnAckProperties.MaximumQoS));
  frmMQTTClientAppMain.AddToLog('RetainAvailable: ' + IntToStr(AConnAckProperties.RetainAvailable));
  frmMQTTClientAppMain.AddToLog('MaximumPacketSize: ' + IntToStr(AConnAckProperties.MaximumPacketSize));
  frmMQTTClientAppMain.AddToLog('AssignedClientIdentifier: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AssignedClientIdentifier), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('TopicAliasMaximum: ' + IntToStr(AConnAckProperties.TopicAliasMaximum));
  frmMQTTClientAppMain.AddToLog('ReasonString: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AConnAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('WildcardSubscriptionAvailable: ' + IntToStr(AConnAckProperties.WildcardSubscriptionAvailable));
  frmMQTTClientAppMain.AddToLog('SubscriptionIdentifierAvailable: ' + IntToStr(AConnAckProperties.SubscriptionIdentifierAvailable));
  frmMQTTClientAppMain.AddToLog('SharedSubscriptionAvailable: ' + IntToStr(AConnAckProperties.SharedSubscriptionAvailable));
  frmMQTTClientAppMain.AddToLog('ServerKeepAlive: ' + IntToStr(AConnAckProperties.ServerKeepAlive));
  frmMQTTClientAppMain.AddToLog('ResponseInformation: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ResponseInformation), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('ServerReference: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.ServerReference), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AuthenticationMethod: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AuthenticationMethod), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AuthenticationData: ' + StringReplace(DynArrayOfByteToString(AConnAckProperties.AuthenticationData), #0, '#0', [rfReplaceAll]));

  ///////////////////////////////////////////
  for i := 0 to Length(DecodedConnAckPropertiesArr) - 1 do
    MQTT_FreeConnAckProperties(DecodedConnAckPropertiesArr[i]);

  SetLength(DecodedConnAckPropertiesArr, 0);

  frmMQTTClientAppMain.btnPublish.Enabled := True;
  frmMQTTClientAppMain.btnSubscribeTo.Enabled := True;
  frmMQTTClientAppMain.btnUnSubscribeFrom.Enabled := True;
  frmMQTTClientAppMain.AddToLog('');


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
begin
  Options := 0;
  QoS := 2;

  Options := Options or QoS; //bits 1 and 0
  //Bit 2 of the Subscription Options represents the No Local option.  - spec pag 73
  //Bit 3 of the Subscription Options represents the Retain As Published option.  - spec pag 73
  //Bits 4 and 5 of the Subscription Options represent the Retain Handling option.  - spec pag 73
  //Bits 6 and 7 of the Subscription Options byte are reserved for future use. - Must be set to 0.  - spec pag 73

                                                                       //Subscription identifiers are not mandatory (per spec).
  SubId := CreateClientToServerSubscriptionIdentifier(ClientInstance); //This function has to be called here, in this handler only. The library does not call this function other than for init purposes.
                                                                       //If SubscriptionIdentifiers are used, then user code should free them when resubscribing or when unsubscribing.
  ASubscribeProperties.SubscriptionIdentifier := SubId;  //For now, the user code should keep track of these identifiers and free them on resubscribing or unsubscribing.
  frmMQTTClientAppMain.AddToLog('Subscribing with new SubscriptionIdentifier: ' + IntToStr(SubId));

  Result := FillIn_SubscribePayload(frmMQTTClientAppMain.lbeTopicName.Text, Options, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
  if not Result then
  begin
    frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
    Exit;
  end;

  //Result := FillIn_SubscribePayload('Extra_' + frmMQTTClientAppMain.lbeTopicName.Text, Options, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
  //if not Result then
  //begin
  //  frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
  //  Exit;
  //end;
  //
  //Result := FillIn_SubscribePayload('MoreExtra_' + frmMQTTClientAppMain.lbeTopicName.Text, 1, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
  //if not Result then
  //begin
  //  frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
  //  Exit;
  //end;
  //
  //Result := FillIn_SubscribePayload('LastExtra_' + frmMQTTClientAppMain.lbeTopicName.Text, 0, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
  //if not Result then
  //begin
  //  frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
  //  Exit;
  //end;

  //Enable SubscriptionIdentifier only if required (allocated above with CreateClientToServerSubscriptionIdentifier) !!!
  //The library initializes EnabledProperties to 0.
  //A subscription is allowed to be made without a SubscriptionIdentifier.
  ASubscribeFields.EnabledProperties := CMQTTSubscribe_EnSubscriptionIdentifier {or CMQTTSubscribe_EnUserProperty};

  frmMQTTClientAppMain.AddToLog('Subscribing with PacketIdentifier: ' + IntToStr(ASubscribeFields.PacketIdentifier));
  frmMQTTClientAppMain.AddToLog('Subscribing to: ' + StringReplace(DynArrayOfByteToString(ASubscribeFields.TopicFilters), #0, '#0', [rfReplaceAll]));

  frmMQTTClientAppMain.AddToLog('');
end;


procedure HandleOnAfterReceivingMQTT_SUBACK(ClientInstance: DWord; var ASubAckFields: TMQTTSubAckFields; var ASubAckProperties: TMQTTSubAckProperties);
var
  i: Integer;
begin
  frmMQTTClientAppMain.AddToLog('Received SUBACK');
  //frmMQTTClientAppMain.AddToLog('ASubAckFields.IncludeReasonCode: ' + IntToStr(ASubAckFields.IncludeReasonCode));  //not used
  //frmMQTTClientAppMain.AddToLog('ASubAckFields.ReasonCode: ' + IntToStr(ASubAckFields.ReasonCode));              //not used
  frmMQTTClientAppMain.AddToLog('ASubAckFields.EnabledProperties: ' + IntToStr(ASubAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('ASubAckFields.PacketIdentifier: ' + IntToStr(ASubAckFields.PacketIdentifier));  //This must be the same as sent in SUBSCRIBE packet.

  frmMQTTClientAppMain.AddToLog('ASubAckFields.Payload.Len: ' + IntToStr(ASubAckFields.SrcPayload.Len));

  for i := 0 to ASubAckFields.SrcPayload.Len - 1 do         //these are QoS values for each TopicFilter (if ok), or error codes (if not ok).
    frmMQTTClientAppMain.AddToLog('ASubAckFields.ReasonCodes[' + IntToStr(i) + ']: ' + IntToStr(ASubAckFields.SrcPayload.Content^[i]));

  frmMQTTClientAppMain.AddToLog('ASubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(ASubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('ASubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(ASubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  frmMQTTClientAppMain.btnSubscribeTo.Enabled := True;
  frmMQTTClientAppMain.AddToLog('');
end;


function HandleOnBeforeSendingMQTT_UNSUBSCRIBE(ClientInstance: DWord;  //The lower word identifies the client instance
                                               var AUnsubscribeFields: TMQTTUnsubscribeFields;
                                               var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                                               ACallbackID: Word): Boolean;
begin
  Result := FillIn_UnsubscribePayload(frmMQTTClientAppMain.lbeTopicName.Text, AUnsubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to AUnsubscribeFields.TopicFilters
  if not Result then
  begin
    frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_UNSUBSCRIBE not enough memory to add TopicFilters.');
    Exit;
  end;

  frmMQTTClientAppMain.AddToLog('Unsubscribing from "' + frmMQTTClientAppMain.lbeTopicName.Text + '"...');

  //the user code should call RemoveClientToServerSubscriptionIdentifier to remove the allocate identifier.
end;


procedure HandleOnAfterReceivingMQTT_UNSUBACK(ClientInstance: DWord; var AUnsubAckFields: TMQTTUnsubAckFields; var AUnsubAckProperties: TMQTTUnsubAckProperties);
var
  i: Integer;
begin
  frmMQTTClientAppMain.AddToLog('Received UNSUBACK');
  //frmMQTTClientAppMain.AddToLog('AUnsubAckFields.IncludeReasonCode: ' + IntToStr(ASubAckFields.IncludeReasonCode));  //not used
  //frmMQTTClientAppMain.AddToLog('AUnsubAckFields.ReasonCode: ' + IntToStr(ASubAckFields.ReasonCode));              //not used
  frmMQTTClientAppMain.AddToLog('AUnsubAckFields.EnabledProperties: ' + IntToStr(AUnsubAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('AUnsubAckFields.PacketIdentifier: ' + IntToStr(AUnsubAckFields.PacketIdentifier));  //This must be the same as sent in SUBSCRIBE packet.

  frmMQTTClientAppMain.AddToLog('AUnsubAckFields.Payload.Len: ' + IntToStr(AUnsubAckFields.SrcPayload.Len));

  for i := 0 to AUnsubAckFields.SrcPayload.Len - 1 do         //these are QoS values for each TopicFilter (if ok), or error codes (if not ok).
    frmMQTTClientAppMain.AddToLog('AUnsubAckFields.ReasonCodes[' + IntToStr(i) + ']: ' + IntToStr(AUnsubAckFields.SrcPayload.Content^[i]));

  frmMQTTClientAppMain.AddToLog('AUnsubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(AUnsubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AUnsubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(AUnsubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  frmMQTTClientAppMain.btnUnSubscribeFrom.Enabled := True;
  frmMQTTClientAppMain.AddToLog('');
end;


//This handler is used when this client publishes a message to broker.
function HandleOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                           var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                           var APublishProperties: TMQTTPublishProperties;            //user code has to fill-in this parameter
                                           ACallbackID: Word): Boolean;
var
  Msg: string;
  QoS: Byte;
begin
  Result := True;
  Msg := frmMQTTClientAppMain.lbeAppMsgToPublish.Text;

  if frmMQTTClientAppMain.chkAddInc.Checked then
  begin
    if frmMQTTClientAppMain.chkAddInc.Tag = 10 then
      frmMQTTClientAppMain.chkAddInc.Tag := 0
    else
      frmMQTTClientAppMain.chkAddInc.Tag := frmMQTTClientAppMain.chkAddInc.Tag + 1;

    Msg := Msg + IntToStr(frmMQTTClientAppMain.chkAddInc.Tag);
  end;

  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  frmMQTTClientAppMain.AddToLog('Publishing "' + Msg + '" at QoS = ' + IntToStr(QoS));

  Result := Result and StringToDynArrayOfByte(Msg, APublishFields.ApplicationMessage);
  Result := Result and StringToDynArrayOfByte(frmMQTTClientAppMain.lbeTopicNameToPublish.Text, APublishFields.TopicName);

  frmMQTTClientAppMain.AddToLog('');
  //QoS can be overriden here. If users override QoS in this handler, then a a different PacketIdentifier might be allocated (depending on what is available)
end;


//This handler is used when this client publishes a message to broker and the broker responds with PUBACK.
procedure HandleOnBeforeSendingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBACK');
  frmMQTTClientAppMain.AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  frmMQTTClientAppMain.AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  frmMQTTClientAppMain.AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  frmMQTTClientAppMain.AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  frmMQTTClientAppMain.AddToLog('');
  //This handler can be used to override what is being sent to server as a reply to PUBLISH
end;


procedure HandleOnAfterReceivingMQTT_PUBACK(ClientInstance: DWord; var APubAckFields: TMQTTPubAckFields; var APubAckProperties: TMQTTPubAckProperties);
begin
  frmMQTTClientAppMain.btnPublish.Enabled := True;

  frmMQTTClientAppMain.AddToLog('Received PUBACK');
  frmMQTTClientAppMain.AddToLog('APubAckFields.EnabledProperties: ' + IntToStr(APubAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('APubAckFields.IncludeReasonCode: ' + IntToStr(APubAckFields.IncludeReasonCode));
  frmMQTTClientAppMain.AddToLog('APubAckFields.PacketIdentifier: ' + IntToStr(APubAckFields.PacketIdentifier));
  frmMQTTClientAppMain.AddToLog('APubAckFields.ReasonCode: ' + IntToStr(APubAckFields.ReasonCode));

  frmMQTTClientAppMain.AddToLog('APubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(APubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('APubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(APubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));

  frmMQTTClientAppMain.AddToLog('');
end;


procedure HandleOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var APublishFields: TMQTTPublishFields; var APublishProperties: TMQTTPublishProperties);
var
  QoS: Byte;
  ID: Word;
  Topic, s, Msg: string;
  i: Integer;
begin
  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  Msg := StringReplace(DynArrayOfByteToString(APublishFields.ApplicationMessage), #0, '#0', [rfReplaceAll]);
  ID := APublishFields.PacketIdentifier;
  Topic := StringReplace(DynArrayOfByteToString(APublishFields.TopicName), #0, '#0', [rfReplaceAll]);

  frmMQTTClientAppMain.AddToLog('Received PUBLISH  ServerPacketIdentifier: ' + IntToStr(ID) +
                                                 '  Msg: ' + Msg +
                                                 '  QoS: ' + IntToStr(QoS) +
                                                 '  TopicName: ' + Topic);

  s := '';
  for i := 0 to APublishProperties.SubscriptionIdentifier.Len - 1 do
    s := s + IntToStr(APublishProperties.SubscriptionIdentifier.Content^[i]) + ', ';
  frmMQTTClientAppMain.AddToLog('SubscriptionIdentifier(s): ' + s);

  frmMQTTClientAppMain.AddToLog('');
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBREC for ServerPacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
begin
  frmMQTTClientAppMain.AddToLog('Received PUBREC for PacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
end;


//Sending PUBREL after the PUBREC response from server, after the client has sent a PUBLISH packet with QoS=2.
procedure HandleOnBeforeSending_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBREL for PacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties);
begin
  frmMQTTClientAppMain.AddToLog('Received PUBREL for ServerPacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBCOMP for PacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  frmMQTTClientAppMain.btnPublish.Enabled := True;
  frmMQTTClientAppMain.AddToLog('Received PUBCOMP for ServerPacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceivingMQTT_PINGRESP(ClientInstance: DWord);
begin
  frmMQTTClientAppMain.AddToLog('Received PINGRESP');
end;


procedure HandleOnBeforeSendingMQTT_DISCONNECT(ClientInstance: DWord;  //The lower word identifies the client instance
                                               var ADisconnectFields: TMQTTDisconnectFields;
                                               var ADisconnectProperties: TMQTTDisconnectProperties;
                                               ACallbackID: Word);
begin
  frmMQTTClientAppMain.AddToLog('Sending DISCONNECT');
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
begin
  frmMQTTClientAppMain.AddToLog('Received DISCONNECT');

  frmMQTTClientAppMain.AddToLog('ADisconnectFields.EnabledProperties' + IntToStr(ADisconnectFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('ADisconnectFields.DisconnectReasonCode' + IntToStr(ADisconnectFields.DisconnectReasonCode));

  frmMQTTClientAppMain.AddToLog('ADisconnectProperties.SessionExpiryInterval' + IntToStr(ADisconnectProperties.SessionExpiryInterval));
  frmMQTTClientAppMain.AddToLog('ADisconnectProperties.ReasonString' + StringReplace(DynArrayOfByteToString(ADisconnectProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('ADisconnectProperties.ServerReference' + StringReplace(DynArrayOfByteToString(ADisconnectProperties.ServerReference), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('ADisconnectProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(ADisconnectProperties.UserProperty), #0, '#0', [rfReplaceAll]));
end;


procedure HandleOnBeforeSendingMQTT_AUTH(ClientInstance: DWord;  //The lower word identifies the client instance
                                         var AAuthFields: TMQTTAuthFields;
                                         var AAuthProperties: TMQTTAuthProperties;
                                         ACallbackID: Word);
begin
  frmMQTTClientAppMain.AddToLog('Sending AUTH');
  AAuthFields.AuthReasonCode := $19; //Example: reauth   - see spec, pag 108.

  StringToDynArrayOfByte('SCRAM-SHA-1', AAuthProperties.AuthenticationMethod);       //some example from spec, pag 108
  StringToDynArrayOfByte('client-second-data', AAuthProperties.AuthenticationData);   //some modified example from spec, pag 108
end;


procedure HandleOnAfterReceivingMQTT_AUTH(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var AAuthFields: TMQTTAuthFields;
                                          var AAuthProperties: TMQTTAuthProperties);
begin
  frmMQTTClientAppMain.AddToLog('Received AUTH');

  frmMQTTClientAppMain.AddToLog('AAuthFields.EnabledProperties' + IntToStr(AAuthFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('AAuthFields.AuthReasonCode' + IntToStr(AAuthFields.AuthReasonCode));

  frmMQTTClientAppMain.AddToLog('AAuthProperties.ReasonString' + StringReplace(DynArrayOfByteToString(AAuthProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AAuthProperties.ServerReference' + StringReplace(DynArrayOfByteToString(AAuthProperties.AuthenticationMethod), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AAuthProperties.ServerReference' + StringReplace(DynArrayOfByteToString(AAuthProperties.AuthenticationData), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('AAuthProperties.UserProperty' + StringReplace(DynOfDynArrayOfByteToString(AAuthProperties.UserProperty), #0, '#0', [rfReplaceAll]));
end;


{ TfrmMQTTClientAppMain }

procedure TfrmMQTTClientAppMain.AddToLog(AMsg: string);  //thread safe
begin
  FLoggingFIFO.Put(AMsg);
end;


procedure TfrmMQTTClientAppMain.SyncReceivedBuffer(var AReadBuf: TDynArrayOfByte); //thread safe
begin
  FRecBufFIFO.Put(DynArrayOfByteToString(AReadBuf));
end;


procedure TfrmMQTTClientAppMain.ProcessReceivedBuffer;  //called by a timer, to process received data
var
  TempReadBuf: TDynArrayOfByte;
  NewData: string;
begin
  if FRecBufFIFO.Pop(NewData) then
  begin
    InitDynArrayToEmpty(TempReadBuf);
    try
      if StringToDynArrayOfByte(NewData, TempReadBuf) then
      begin
        PutReceivedBufferToMQTTLib(0, TempReadBuf);
        MQTT_Process(0);
      end
      else
        AddToLog('Out of memory in ProcessReceivedBuffer.');
    finally
      FreeDynArray(TempReadBuf);
    end;
  end;
end;


procedure TfrmMQTTClientAppMain.SendString(AString: string);
var
  StrBytes: TIdBytes; //this is array of Byte;
  LenStr: Word;
begin
  LenStr := Length(AString);
  SetLength(StrBytes, LenStr + 2);

  StrBytes[0] := Hi(LenStr);
  StrBytes[1] := Lo(LenStr);

  Move(AString, StrBytes[2], LenStr);

  IdTCPClient1.IOHandler.Write(StrBytes);
end;


procedure TfrmMQTTClientAppMain.SendDynArrayOfByte(AArr: TDynArrayOfByte);
var
  TempArr: TIdBytes;
begin
  SetLength(TempArr, AArr.Len);
  Move(AArr.Content^, TempArr[0], AArr.Len);
  IdTCPClient1.IOHandler.Write(TempArr);
end;


procedure TfrmMQTTClientAppMain.LogDynArrayOfByte(var AArr: TDynArrayOfByte; ADisplayName: string = '');
var
  i: Integer;
  s: string;
begin
  s := ADisplayName + '  Len: ' + IntToStr(AArr.Len) + '  Data: ';
  for i := 0 to AArr.Len - 1 do
    //s := s + IntToHex(AArr.Content^[i], 2) + ' ';
    s := s + IntToStr(AArr.Content^[i]) + ' ';

  AddToLog(s);
end;


procedure TfrmMQTTClientAppMain.InitHandlers;
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


procedure TfrmMQTTClientAppMain.SendPacketToServer(ClientInstance: DWord);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  BufferPointer := GetClientToServerBuffer(ClientInstance, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  SendDynArrayOfByte(BufferPointer^);

  {$IFnDEF SingleOutputBuffer}
    if not RemovePacketFromClientToServerBuffer(ClientInstance) then
      AddToLog('Can''t remove latest packet from send buffer.');
  {$ELSE}
    raise Exception.Create('RemovePacketFromClientToServerBuffer no implemented for SingleOutputBuffer.');
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
  frmMQTTClientAppMain.AddToLog(s);
end;


procedure TMQTTReceiveThread.Execute;
var
  TempReadBuf: TDynArrayOfByte;
  //ReadCount: Integer;
  TempByte: Byte;
  PacketName: string;
  LoggedDisconnection: Boolean;
begin
  try
    //ReadCount := 0;
    InitDynArrayToEmpty(TempReadBuf);

    try
      LoggedDisconnection := False;
      repeat
        try
          TempByte := frmMQTTClientAppMain.IdTCPClient1.IOHandler.ReadByte;
          AddByteToDynArray(TempByte, TempReadBuf);
        except
          on E: Exception do      ////////////////// ToDo: switch to EIdReadTimeout
          begin
            if (E.Message = 'Read timed out.') and (TempReadBuf.Len > 0) then
            begin
              MQTTPacketToString(TempReadBuf.Content^[0], PacketName);
              AddToLog('done receiving packet: ' + E.Message + {'   ReadCount: ' + IntToStr(ReadCount) +} '   E.ClassName: ' + E.ClassName);
              AddToLog('Buffer size: ' + IntToStr(TempReadBuf.Len) + '  Packet header: $' + IntToHex(TempReadBuf.Content^[0]) + ' (' + PacketName + ')');

              frmMQTTClientAppMain.SyncReceivedBuffer(TempReadBuf);

              FreeDynArray(TempReadBuf);
              //ReadCount := 0; //reset for next packet
            end
            else
              if E.Message = 'Connection Closed Gracefully.' then
                if not LoggedDisconnection then
                begin
                  LoggedDisconnection := True;
                  AddToLog('Disconnected from server. Cannot receive more data. Ex: ' + E.Message);
                end;

            Sleep(1);
          end;
        end;

        //Inc(ReadCount);
      until Terminated;
    finally
      AddToLog('Thread done..');
    end;
  except
    on E: Exception do
      AddToLog('Th ex: ' + E.Message);
  end;
end;


var
  Th: TMQTTReceiveThread;


procedure TfrmMQTTClientAppMain.btnConnectClick(Sender: TObject);
var
  tk: QWord;
begin
  IdTCPClient1.OnConnected := @HandleClientOnConnected;
  IdTCPClient1.OnDisconnected := @HandleClientOnDisconnected;

  btnConnect.Enabled := False;
  try
    try
      IdTCPClient1.Connect(lbeAddress.Text, StrToIntDef(lbePort.Text, 1883));
      IdTCPClient1.IOHandler.ReadTimeout := 100;
      //AddToLog('Connected to broker...');

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

      Th := TMQTTReceiveThread.Create(True);
      Th.FreeOnTerminate := False;
      Th.Start;

      if not MQTT_CONNECT(0, 0) then
      begin
        AddToLog('Can''t prepare MQTTConnect packet.');
        Exit;
      end;
    except
      on E: Exception do
        AddToLog('Can''t connect.  ' + E.Message + '   Class: ' + E.ClassName);
    end;
  finally
    btnConnect.Enabled := True;
  end;
end;


procedure TfrmMQTTClientAppMain.btnAuthClick(Sender: TObject);
begin
  if not MQTT_AUTH(0, 0) then
    AddToLog('Can''t prepare MQTT_AUTH packet.');
end;


procedure TfrmMQTTClientAppMain.btnDisconnectClick(Sender: TObject);
var
  tk: QWord;
  ClientToServerBuf: {$IFDEF SingleOutputBuffer} PMQTTBuffer; {$ELSE} PMQTTMultiBuffer; {$ENDIF}
  Err: Word;
begin
  if not MQTT_DISCONNECT(0, 0) then
  begin
    AddToLog('Can''t prepare MQTTDisconnect packet.');
    Exit;
  end;

  tk := GetTickCount64;
  repeat
    ClientToServerBuf := GetClientToServerBuffer(0, Err);
    Application.ProcessMessages;
    Sleep(10);
  until (GetTickCount64 - tk > 1500) or ((ClientToServerBuf <> nil) and (ClientToServerBuf^.Len = 0));

  Th.Terminate;
  tk := GetTickCount64;
  repeat
    Application.ProcessMessages;
    Sleep(10);
  until (GetTickCount64 - tk > 1500) or Th.Terminated;
  Th := nil;

  IdTCPClient1.Disconnect(False);
end;


procedure TfrmMQTTClientAppMain.btnPingClick(Sender: TObject);
begin
  if not MQTT_PINGREQ(0) then
    AddToLog('Can''t prepare MQTT_PINGREQ packet.');
end;


procedure TfrmMQTTClientAppMain.btnPublishClick(Sender: TObject);
begin
  if cmbQoS.ItemIndex > 0 then   //for QoS = 0, there is no expected ACK
    btnPublish.Enabled := False;

  if not MQTT_PUBLISH(0, 0, cmbQoS.ItemIndex) then
    AddToLog('Can''t prepare MQTT_PUBLISH packet.');
end;


procedure TfrmMQTTClientAppMain.btnResendUnAckClick(Sender: TObject);
begin
  ResendUnacknowledged(0);
end;


procedure TfrmMQTTClientAppMain.btnSetToLocalhostClick(Sender: TObject);
begin
  lbeAddress.Text := '127.0.0.1';
end;


procedure TfrmMQTTClientAppMain.btnSubscribeToClick(Sender: TObject);
begin
  if not MQTT_SUBSCRIBE(0, 0) then
  begin
    AddToLog('Can''t prepare MQTT_SUBSCRIBE packet.');
    Exit;
  end;

  frmMQTTClientAppMain.btnSubscribeTo.Enabled := False;
end;


procedure TfrmMQTTClientAppMain.btnUnSubscribeFromClick(Sender: TObject);
begin
  if not MQTT_UNSUBSCRIBE(0, 0) then
  begin
    AddToLog('Can''t prepare MQTT_UNSUBSCRIBE packet.');
    Exit;
  end;

  frmMQTTClientAppMain.btnUnSubscribeFrom.Enabled := False;
end;


procedure TfrmMQTTClientAppMain.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  MQTT_DestroyClient(0);
end;


procedure TfrmMQTTClientAppMain.FormCreate(Sender: TObject);
begin
  Th := nil;
  FLoggingFIFO := TPollingFIFO.Create;
  FRecBufFIFO := TPollingFIFO.Create;

  tmrStartup.Enabled := True;
end;


procedure TfrmMQTTClientAppMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FLoggingFIFO);
  FreeAndNil(FRecBufFIFO);
  Th := nil;
end;


procedure TfrmMQTTClientAppMain.tmrProcessLogTimer(Sender: TObject);
var
  Msg: string;
begin
  if FLoggingFIFO.Pop(Msg) then
    memLog.Lines.Add(DateTimeToStr(Now) + '  ' + (Msg));
end;


procedure TfrmMQTTClientAppMain.tmrProcessRecDataTimer(Sender: TObject);
var
  ClientToServerBuf: {$IFDEF SingleOutputBuffer} PMQTTBuffer; {$ELSE} PMQTTMultiBuffer; {$ENDIF}
  ClientToServerResendBuf: PMQTTMultiBuffer;
  ServerToClientBuf: PMQTTBuffer;
  Err: Word;
begin
  ProcessReceivedBuffer;

  ClientToServerBuf := GetClientToServerBuffer(0, Err);
  if Err <> CMQTT_Success then
    lblClientToServerBufferSize.Caption := 'Err ' + IntToStr(Err)
  else
  begin
    try
      lblClientToServerBufferSize.Caption := IntToStr(ClientToServerBuf^.Len);
    except
      lblClientToServerBufferSize.Caption := 'Ex inst';
    end;
  end;

  ClientToServerResendBuf := GetClientToServerResendBuffer(0, Err);
  if Err <> CMQTT_Success then
    lblClientToServerResendBufferSize.Caption := 'Err ' + IntToStr(Err)
  else
  begin
    try
      lblClientToServerResendBufferSize.Caption := IntToStr(ClientToServerResendBuf^.Len);
    except
      lblClientToServerResendBufferSize.Caption := 'Ex inst';
    end;
  end;


  ServerToClientBuf := GetServerToClientBuffer(0, Err);
  if Err <> CMQTT_Success then
    lblServerToClientBufferSize.Caption := 'Err ' + IntToStr(Err)
  else
  begin
    try
      lblServerToClientBufferSize.Caption := IntToStr(ServerToClientBuf^.Len);
    except
      lblServerToClientBufferSize.Caption := 'Ex inst';
    end;
  end;

  try
    lblClientToServerIDCount.Caption := IntToStr(GetClientToServerPacketIdentifiersCount(0));
    lblServerToClientIDCount.Caption := IntToStr(GetServerToClientPacketIdentifiersCount(0));
  except
    lblClientToServerIDCount.Caption := 'Ex inst';
  end;
end;


procedure TfrmMQTTClientAppMain.tmrStartupTimer(Sender: TObject);
var
  Content: TStringList;
  Fnm: string;
begin
  tmrStartup.Enabled := False;
  tmrProcessLog.Enabled := True;
  tmrProcessRecData.Enabled := True;

  FMQTTPassword := '';

  Content := TStringList.Create;
  try
    Fnm := ExtractFilePath(ParamStr(0)) + '..\p.txt';

    if FileExists(Fnm) then
    begin
      Content.LoadFromFile(Fnm);

      if Content.Count > 0 then
        FMQTTPassword := Content.Strings[0]
    end
    else
      AddToLog('Password file not found. Using empty password..');
  finally
    Content.Free;
  end;

  MQTT_Init;
  if not MQTT_CreateClient then
    AddToLog('Can''t create client...');

  InitHandlers;
end;


procedure TfrmMQTTClientAppMain.HandleClientOnConnected(Sender: TObject);
begin
  AddToLog('Connected to broker... on port ' + IntToStr(IdTCPClient1.Port));
end;


procedure TfrmMQTTClientAppMain.HandleClientOnDisconnected(Sender: TObject);
begin
  AddToLog('Disconnected from broker...');
  Th.Terminate;
end;


end.

