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
  IdTCPClient, IdGlobal,
  DynArrays;

type

  { TfrmMQTTClientAppMain }

  TfrmMQTTClientAppMain = class(TForm)
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnSetToLocalhost: TButton;
    btnPublish: TButton;
    btnSubscribeTo: TButton;
    chkAddInc: TCheckBox;
    cmbQoS: TComboBox;
    grpSubscription: TGroupBox;
    grpPublish: TGroupBox;
    IdTCPClient1: TIdTCPClient;
    lblQoS: TLabel;
    lbeTopicName: TLabeledEdit;
    lbeTopicNameToPublish: TLabeledEdit;
    lbeAppMsgToPublish: TLabeledEdit;
    lbeUser: TLabeledEdit;
    lbeAddress: TLabeledEdit;
    lbePort: TLabeledEdit;
    memLog: TMemo;
    tmrStartup: TTimer;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnPublishClick(Sender: TObject);
    procedure btnSetToLocalhostClick(Sender: TObject);
    procedure btnSubscribeToClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure tmrStartupTimer(Sender: TObject);
  private
    FMQTTPassword: string;

    procedure LogDynArrayOfByte(var AArr: TDynArrayOfByte; ADisplayName: string = '');

    procedure HandleClientOnConnected(Sender: TObject);
    procedure HandleClientOnDisconnected(Sender: TObject);

    procedure SendString(AString: string);
    procedure SendDynArrayOfByte(AArr: TDynArrayOfByte);
    procedure SendPacketToServer(ClientInstance: DWord);

    procedure AddToLog(AMsg: string);

    procedure InitHandlers;
  public

  end;


var
  frmMQTTClientAppMain: TfrmMQTTClientAppMain;

implementation

{$R *.frm}

uses
  MQTTUtils, MQTTClient, MQTTConnectCtrl, MQTTConnAckCtrl, MQTTSubscribeCtrl;


var
  DecodedConnAckPropertiesArr: TMQTTConnAckPropertiesArr;


procedure HandleOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  frmMQTTClientAppMain.AddToLog('Client: ' + IntToHex(ClientInstance, 8) + '  Err: $' + IntToHex(AErr) + '  PacketType: $' + IntToHex(APacketType));
  //The error is made of an upper byte and a lower byte.

  if Hi(AErr) = $87 then
  begin
    frmMQTTClientAppMain.AddToLog('Error: Not authorized.');
    if APacketType = CMQTT_CONNACK then
      frmMQTTClientAppMain.AddToLog('             on receiving CONNACK.');
  end;
end;


function HandleOnBeforeMQTT_CONNECT(ClientInstance: DWord;  //The lower byte identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                    var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                    var AConnectProperties: TMQTTConnectProperties;
                                    ACallbackID: Word): Boolean;
var
  TempWillProperties: TMQTTWillProperties;
  ClientId, UserName, Password: string[20];
  Id: Char;
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
                       CMQTTConnect_EnRequestProblemInformation;

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
  AConnectProperties.MaximumPacketSize := 7000;
  AConnectProperties.TopicAliasMaximum := 100;
  AConnectProperties.RequestResponseInformation := 1;
  AConnectProperties.RequestProblemInformation := 1;
  AddStringToDynOfDynArrayOfByte('UserProp=Value', AConnectProperties.UserProperty);
  StringToDynArrayOfByte('MyAuthMethod', AConnectProperties.AuthenticationMethod);
  StringToDynArrayOfByte('MyAuthData', AConnectProperties.AuthenticationData);

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
  frmMQTTClientAppMain.AddToLog('');
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

  SubId := CreateClientToServerSubscriptionIdentifier(ClientInstance); //This function has to be called here, in this handler only. The library caches the values added to ASubscribeProperties.SubscriptionIdentifier array.
  frmMQTTClientAppMain.AddToLog('Subscribing with new SubscriptionIdentifier: ' + IntToStr(SubId)); //should be added to array automatically by lib

  Result := AddDWordToDynArraysOfDWord(ASubscribeProperties.SubscriptionIdentifier, SubId);
  if not Result then
  begin
    frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add SubId.');
    Exit;
  end;

  //frmMQTTClientAppMain.AddToLog('SubscriptionIdentifier len: ' + IntToStr(ASubscribeProperties.SubscriptionIdentifier.Len)); //should not be 0
  //for i := 0 to ASubscribeProperties.SubscriptionIdentifier.Len - 1 do
  //  frmMQTTClientAppMain.AddToLog('Subscribing with SubscriptionIdentifier[' + IntToStr(i) + ']: ' + IntToStr(ASubscribeProperties.SubscriptionIdentifier.Content^[i])); //must be >0

  Result := FillIn_SubscribePayload(frmMQTTClientAppMain.lbeTopicName.Text, Options, ASubscribeFields.TopicFilters);  //call this again with a different string (i.e. TopicFilter), in order to add it to ASubscribeFields.TopicFilters
  if not Result then
  begin
    frmMQTTClientAppMain.AddToLog('HandleOnBeforeSendingMQTT_SUBSCRIBE not enough memory to add TopicFilters.');
    Exit;
  end;

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
  frmMQTTClientAppMain.AddToLog('ASubAckFields.IncludeReasonCode: ' + IntToStr(ASubAckFields.IncludeReasonCode));
  frmMQTTClientAppMain.AddToLog('ASubAckFields.EnabledProperties: ' + IntToStr(ASubAckFields.EnabledProperties));
  frmMQTTClientAppMain.AddToLog('ASubAckFields.PacketIdentifier: ' + IntToStr(ASubAckFields.PacketIdentifier));
  frmMQTTClientAppMain.AddToLog('ASubAckFields.ReasonCode: ' + IntToStr(ASubAckFields.ReasonCode));

  for i := 0 to ASubAckFields.SrcPayload.Len - 1 do
    frmMQTTClientAppMain.AddToLog('ASubAckFields.ReasonCodes[' + IntToStr(i) + ']: ' + IntToStr(ASubAckFields.SrcPayload.Content^[i]));

  frmMQTTClientAppMain.AddToLog('ASubAckProperties.ReasonString: ' + StringReplace(DynArrayOfByteToString(ASubAckProperties.ReasonString), #0, '#0', [rfReplaceAll]));
  frmMQTTClientAppMain.AddToLog('ASubAckProperties.UserProperty: ' + StringReplace(DynOfDynArrayOfByteToString(ASubAckProperties.UserProperty), #0, '#0', [rfReplaceAll]));
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
  Result := Result and StringToDynArrayOfByte(frmMQTTClientAppMain.lbeTopicName.Text, APublishFields.TopicName);

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
  Msg: string;
  ID: Word;
  Topic: string;
begin
  QoS := (APublishFields.PublishCtrlFlags shr 1) and 3;
  Msg := StringReplace(DynArrayOfByteToString(APublishFields.ApplicationMessage), #0, '#0', [rfReplaceAll]);
  ID := APublishFields.PacketIdentifier;
  Topic := StringReplace(DynArrayOfByteToString(APublishFields.TopicName), #0, '#0', [rfReplaceAll]);

  frmMQTTClientAppMain.AddToLog('Received PUBLISH  PacketIdentifier: ' + IntToStr(ID) +
                                                 '  Msg: ' + Msg +
                                                 '  QoS: ' + IntToStr(QoS) +
                                                 '  TopicName: ' + Topic);

  frmMQTTClientAppMain.AddToLog('');
end;


procedure HandleOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBREC for PacketID: ' + IntToStr(ATempPubRecFields.PacketIdentifier));
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
  frmMQTTClientAppMain.AddToLog('Received PUBREL for PacketID: ' + IntToStr(ATempPubRelFields.PacketIdentifier));
end;


procedure HandleOnSend_MQTT_PUBREL(ClientInstance: DWord);
begin
  frmMQTTClientAppMain.AddToLog('Sending PUBREL packet...');
  frmMQTTClientAppMain.SendPacketToServer(ClientInstance);
end;


procedure HandleOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  frmMQTTClientAppMain.AddToLog('Acknowledging with PUBCOMP for PacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


procedure HandleOnAfterReceiving_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties);
begin
  frmMQTTClientAppMain.btnPublish.Enabled := True;
  frmMQTTClientAppMain.AddToLog('Received PUBCOMP for PacketID: ' + IntToStr(ATempPubCompFields.PacketIdentifier));
end;


{ TfrmMQTTClientAppMain }

procedure TfrmMQTTClientAppMain.AddToLog(AMsg: string);
begin
  memLog.Lines.Add(DateTimeToStr(Now) + '  ' + AMsg);
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
    OnSendMQTT_PUBREL^ := @HandleOnSend_MQTT_PUBREL;
    OnBeforeSendingMQTT_PUBCOMP^ := @HandleOnBeforeSending_MQTT_PUBCOMP;
    OnAfterReceivingMQTT_PUBCOMP^ := @HandleOnAfterReceiving_MQTT_PUBCOMP;
    OnBeforeSendingMQTT_SUBSCRIBE^ := @HandleOnBeforeSendingMQTT_SUBSCRIBE;
    OnAfterReceivingMQTT_SUBACK^ := @HandleOnAfterReceivingMQTT_SUBACK;
  {$ELSE}
    OnMQTTError := @HandleOnMQTTError;
    OnBeforeMQTT_CONNECT := @HandleOnBeforeMQTT_CONNECT;
    OnAfterMQTT_CONNACK := @HandleOnAfterMQTT_CONNACK;
    OnBeforeSendingMQTT_PUBLISH := @HandleOnBeforeSendingMQTT_PUBLISH;
    OnBeforeSending_MQTT_PUBACK := @HandleOnBeforeSendingMQTT_PUBACK;
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
  {$ENDIF}
end;


procedure TfrmMQTTClientAppMain.SendPacketToServer(ClientInstance: DWord);
var
  BufferPointer: PMQTTBuffer;
  Err: Word;
begin
  BufferPointer := GetClientToServerBuffer(ClientInstance, Err){$IFnDEF SingleOutputBuffer}^.Content^[0]{$ENDIF};
  SendDynArrayOfByte(BufferPointer^);
  if not RemovePacketFromClientToServerBuffer(ClientInstance) then
    AddToLog('Can''t remove latest packet from send buffer.');
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
begin
  try
    //ReadCount := 0;
    InitDynArrayToEmpty(TempReadBuf);

    try
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

              PutReceivedBufferToMQTTLib(0, TempReadBuf);
              MQTT_Process(0);

              FreeDynArray(TempReadBuf);
              //ReadCount := 0; //reset for next packet
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
begin
  IdTCPClient1.OnConnected := @HandleClientOnConnected;
  IdTCPClient1.OnDisconnected := @HandleClientOnDisconnected;

  try
    IdTCPClient1.Connect(lbeAddress.Text, StrToIntDef(lbePort.Text, 1883));
    IdTCPClient1.IOHandler.ReadTimeout := 1000;
    //AddToLog('Connected to broker...');

    Th := TMQTTReceiveThread.Create(True);
    Th.FreeOnTerminate := False;
    Th.Start;

    if not MQTT_CONNECT(0, 0) then
    begin
      AddToLog('Can''t prepare MQTTConnect packet.');
      Exit;
    end;

    SendPacketToServer(0);
  except
    on E: Exception do
      AddToLog('Can''t connect.  ' + E.Message + '   Class: ' + E.ClassName);
  end;
end;


procedure TfrmMQTTClientAppMain.btnDisconnectClick(Sender: TObject);
var
  tk: QWord;
begin
  Th.Terminate;

  tk := GetTickCount64;
  repeat
    Application.ProcessMessages;
    Sleep(10);
  until (GetTickCount64 - tk > 1500) or Th.Terminated;

  IdTCPClient1.Disconnect(True);
end;


procedure TfrmMQTTClientAppMain.btnPublishClick(Sender: TObject);
begin
  btnPublish.Enabled := False;
  if not MQTT_PUBLISH(0, 0, cmbQoS.ItemIndex) then
  begin
    AddToLog('Can''t prepare MQTT_PUBLISH packet.');
    Exit;
  end;

  SendPacketToServer(0);
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

  SendPacketToServer(0);
end;


procedure TfrmMQTTClientAppMain.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  MQTT_DestroyClient(0);
end;


procedure TfrmMQTTClientAppMain.FormCreate(Sender: TObject);
begin
  tmrStartup.Enabled := True;
end;


procedure TfrmMQTTClientAppMain.tmrStartupTimer(Sender: TObject);
var
  Content: TStringList;
begin
  tmrStartup.Enabled := False;

  Content := TStringList.Create;
  try
    Content.LoadFromFile(ExtractFilePath(ParamStr(0)) + '..\p.txt');

    if Content.Count > 0 then
      FMQTTPassword := Content.Strings[0]
    else
      FMQTTPassword := '';
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

