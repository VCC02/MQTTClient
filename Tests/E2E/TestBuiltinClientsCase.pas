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


//These tests assume that the broker is configured to relay the messages at the same QoS as published.


unit TestBuiltinClientsCase;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls,
  fpcunit, testregistry, IdGlobal,
  TestE2EUtils;


type
  TTestE2EBuiltinClientsCase = class(TTestE2EBuiltinClientsMain)
  published
    procedure TestMemoryLeakInSetupAndTearDown;

    procedure TestPublish_Client0ToClient1_HappyFlow_QoS0;
    procedure TestPublish_Client0ToClient1_HappyFlow_QoS1;
    procedure TestPublish_Client0ToClient1_HappyFlow_QoS2;

    procedure TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS0;
    procedure TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS1;
    procedure TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS2;

    procedure TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS0;
    procedure TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS1;
    procedure TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS2;

    procedure TestReconnectWithSessionPresentFlag;
    procedure TestReconnectWithReceiveMissingPacketsFromServer_QoS1;
    procedure TestReconnectWithReceiveMissingPacketsFromServer_QoS2;

    procedure TestReconnectWithResend_QoS1;
    procedure TestReconnectWithResend_QoS2_PubRec;
    procedure TestReconnectWithResend_QoS2_PubComp;

    procedure TestReconnectWithResend_TwoReconnections_QoS1;
    procedure TestReconnectWithResend_TwoReconnections_QoS2_PubRec;
    procedure TestReconnectWithResend_TwoReconnections_QoS2_PubComp;
  end;

implementation


uses
  MQTTClient, MQTTUtils,
  Expectations, ExpectationsDynArrays;


procedure TTestE2EBuiltinClientsCase.TestMemoryLeakInSetupAndTearDown;
begin
  Expect(True).ToBe(True, 'Only a simple content.');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS0;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(0);

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1);

  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).ToBe(True, 'Should receive a PubAck');

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
  LoopedExpect(PBoolean(@TestClients[1].SentPubAck)).ToBe(True, 'Should send a PubAck');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_QoS2;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2);

  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).ToBe(True, 'Should receive a PubRec');
  LoopedExpect(PBoolean(@TestClients[0].SentPubRel)).ToBe(True, 'Should send a PubRel');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).ToBe(True, 'Should receive a PubComp');

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
  LoopedExpect(PBoolean(@TestClients[1].SentPubRec)).ToBe(True, 'Should send a PubRec');
  LoopedExpect(PBoolean(@TestClients[1].ReceivedPubRel)).ToBe(True, 'Should receive a PubRel');
  LoopedExpect(PBoolean(@TestClients[1].SentPubComp)).ToBe(True, 'Should send a PubComp');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS0;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendUnsubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(0);

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage), 400).NotToBe(FMsgToPublish, 'NotSetYet');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendUnsubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1);

  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).ToBe(True, 'Should receive a PubAck');

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage), 400).NotToBe(FMsgToPublish, 'NotSetYet');
  LoopedExpect(PBoolean(@TestClients[1].SentPubAck), 400).NotToBe(True, 'Should not send a PubAck');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlowUnsubscribed_QoS2;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendUnsubscribe;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2);

  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).ToBe(True, 'Should receive a PubRec');
  LoopedExpect(PBoolean(@TestClients[0].SentPubRel)).ToBe(True, 'Should send a PubRel');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).ToBe(True, 'Should receive a PubComp');

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage), 400).NotToBe(FMsgToPublish, 'NotSetYet');
  LoopedExpect(PBoolean(@TestClients[1].SentPubRec), 400).NotToBe(True, 'Should not send a PubRec');
  LoopedExpect(PBoolean(@TestClients[1].ReceivedPubRel), 400).NotToBe(True, 'Should not receive a PubRel');
  LoopedExpect(PBoolean(@TestClients[1].SentPubComp), 400).NotToBe(True, 'Should not send a PubComp');
end;


function LengthOfAllRecMsgs: Integer;
begin
  Result := Length(TestClients[1].AllReceivedPublishedMessages);
end;


const
  CMsg1 = 'First content';
  CMsg2 = 'Second content';


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS0;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;

  Ths[1].SuspendExecution; //pause the receiving thread while sending, so that receiving buffer fills with multiple packets
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(0, CMsg1);
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(0, CMsg2);

  Ths[1].ResumeExecution;
  LoopedExpect(@LengthOfAllRecMsgs).ToBe(2, 'Expected two received messages.');
  Expect(TestClients[1].AllReceivedPublishedMessages[0]).ToBe(CMsg1, 'Should receive a Publish with "' + CMsg1 + '" (1).');
  Expect(TestClients[1].AllReceivedPublishedMessages[1]).ToBe(CMsg2, 'Should receive a Publish with "' + CMsg2 + '" (2).');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;

  Ths[1].SuspendExecution; //pause the receiving thread while sending, so that receiving buffer fills with multiple packets
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1, CMsg1);
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1, CMsg2);

  Ths[1].ResumeExecution;
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).ToBe(True, 'Should receive a PubAck');   //actually, there should be two PubAck packets
  LoopedExpect(@LengthOfAllRecMsgs).ToBe(2, 'Expected two received messages.');

  Expect(TestClients[1].AllReceivedPublishedMessages[0]).ToBe(CMsg1, 'Should receive a Publish with "' + CMsg1 + '" (1).');
  Expect(TestClients[1].AllReceivedPublishedMessages[1]).ToBe(CMsg2, 'Should receive a Publish with "' + CMsg2 + '" (2).');

  LoopedExpect(PBoolean(@TestClients[1].SentPubAck)).ToBe(True, 'Should send a PubAck');
end;


procedure TTestE2EBuiltinClientsCase.TestPublish_Client0ToClient1_HappyFlow_MultiPacket_QoS2;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;

  Ths[1].SuspendExecution; //pause the receiving thread while sending, so that receiving buffer fills with multiple packets
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2, CMsg1);
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2, CMsg2);

  Ths[1].ResumeExecution;
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).ToBe(True, 'Should receive a PubRec');
  LoopedExpect(PBoolean(@TestClients[0].SentPubRel)).ToBe(True, 'Should send a PubRel');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).ToBe(True, 'Should receive a PubComp');

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
  LoopedExpect(PBoolean(@TestClients[1].SentPubRec)).ToBe(True, 'Should send a PubRec');
  LoopedExpect(PBoolean(@TestClients[1].ReceivedPubRel)).ToBe(True, 'Should receive a PubRel');
  LoopedExpect(PBoolean(@TestClients[1].SentPubComp)).ToBe(True, 'Should send a PubComp');

  LoopedExpect(@LengthOfAllRecMsgs).ToBe(2, 'Expected two received messages.');
  Expect(TestClients[1].AllReceivedPublishedMessages[0]).ToBe(CMsg1, 'Should receive a Publish with "' + CMsg1 + '" (1).');
  Expect(TestClients[1].AllReceivedPublishedMessages[1]).ToBe(CMsg2, 'Should receive a Publish with "' + CMsg2 + '" (2).');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithSessionPresentFlag;
begin
  DisconnectWithNoCleanStartFlag(1);
  ReconnectToBroker(1);
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithReceiveMissingPacketsFromServer_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  DisconnectWithNoCleanStartFlag(1);

  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1);
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).ToBe(True, 'Should receive a PubAck');

  ReconnectToBroker(1);

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
  LoopedExpect(PBoolean(@TestClients[1].SentPubAck)).ToBe(True, 'Should send a PubAck');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithReceiveMissingPacketsFromServer_QoS2;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  DisconnectWithNoCleanStartFlag(1);

  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2);
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).NotToBe(True, 'Should not receive a PubAck');     //no PubAck on QoS=2
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).ToBe(True, 'Should receive a PubComp');

  ReconnectToBroker(1);

  LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage)).ToBe(FMsgToPublish, 'Should receive a Publish with "' + FMsgToPublish + '".');
  LoopedExpect(PBoolean(@TestClients[1].SentPubAck)).NotToBe(True, 'Should not send a PubAck');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubAck := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).NotToBe(True, 'Should not receive a PubAck');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubAck := True;
  ReconnectToBroker(0);

  {$IfDEF SkipSendingUnAck}
    Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).ToBe(True, 'Should receive a PubAck.');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_QoS2_PubRec;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubRec := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).NotToBe(True, 'Should not receive a PubRec');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubRec := True;
  ReconnectToBroker(0);

  {$IfDEF SkipSendingUnAck}
    Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).ToBe(True, 'Should receive a PubRec.');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_QoS2_PubComp;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubComp := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).NotToBe(True, 'Should not receive a PubComp');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubComp := True;
  ReconnectToBroker(0);

  {$IfDEF SkipSendingUnAck}
    Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).ToBe(True, 'Should receive a PubComp.');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_TwoReconnections_QoS1;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubAck := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(1); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).NotToBe(True, 'Should not receive a PubAck #1');

  DisconnectWithNoCleanStartFlag(0);
  ReconnectToBroker(0);
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).NotToBe(True, 'Should not receive a PubAck #2');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubAck := True;
  ReconnectToBroker(0, False);                         //A ConAck is received, but there is no SessionPresent flag. Also, the ClientID is new.

  {$IfDEF SkipSendingUnAck}
    if TestClients[0].FReceivedSessionPresentFlag then
      Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubAck)).NotToBe(True, 'Should not receive a PubAck #3'); //because the session is not present.

  Expect(MQTT_GetClientToServerResendPacketIdentifierCount(0)).ToBe(0, 'Since the server returned with clean session, the library should clear the resend buffers.');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_TwoReconnections_QoS2_PubRec;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubRec := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).NotToBe(True, 'Should not receive a PubRec #1');

  DisconnectWithNoCleanStartFlag(0);
  ReconnectToBroker(0);
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).NotToBe(True, 'Should not receive a PubRec #2');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubRec := True;
  ReconnectToBroker(0, False);

  {$IfDEF SkipSendingUnAck}
    if TestClients[0].FReceivedSessionPresentFlag then
      Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubRec)).NotToBe(True, 'Should not receive a PubRec #3.'); //because the session is not present.

  Expect(MQTT_GetClientToServerResendPacketIdentifierCount(0)).ToBe(0, 'Since the server returned with clean session, the library should clear the resend buffers.');
end;


procedure TTestE2EBuiltinClientsCase.TestReconnectWithResend_TwoReconnections_QoS2_PubComp;
begin
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;
  TestClients[0].AllowReceivingPubComp := False;
  TestPublish_Client0ToClient1_HappyFlow_SendPublish(2); //the response is received from server, but is ignored
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).NotToBe(True, 'Should not receive a PubComp #1');

  DisconnectWithNoCleanStartFlag(0);
  ReconnectToBroker(0);
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).NotToBe(True, 'Should not receive a PubComp #2');

  DisconnectWithNoCleanStartFlag(0);
  TestClients[0].AllowReceivingPubComp := True;
  ReconnectToBroker(0, False);

  {$IfDEF SkipSendingUnAck}
    if TestClients[0].FReceivedSessionPresentFlag then
      Expect(MQTT_ResendUnacknowledged(0)).ToBe(True, 'Resending successful');
  {$ENDIF}

  LoopedExpect(PInteger(@TestClients[0].LatestError)).ToBe(CMQTT_Success, 'There should be no error.');
  LoopedExpect(PInteger(@TestClients[0].LatestPacketOnError)).ToBe(CMQTT_UNDEFINED, 'There should be no errored packet.');
  LoopedExpect(PBoolean(@TestClients[0].ReceivedPubComp)).NotToBe(True, 'Should not receive a PubComp #3.'); //because the session is not present.

  Expect(MQTT_GetClientToServerResendPacketIdentifierCount(0)).ToBe(0, 'Since the server returned with clean session, the library should clear the resend buffers.');
end;


initialization

  RegisterTest(TTestE2EBuiltinClientsCase);
end.

