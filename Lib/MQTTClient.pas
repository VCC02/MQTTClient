{
    Copyright (C) 2023 VCC
    creation date: 31 Jul 2023
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


unit MQTTClient;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ELSE}

{$ENDIF}

interface

uses
  DynArrays, MQTTUtils,
  MQTTConnectCtrl, MQTTConnAckCtrl,
  MQTTPublishCtrl, MQTTCommonCodecCtrl, MQTTPubAckCtrl, MQTTPubRecCtrl, MQTTPubRelCtrl, MQTTPubCompCtrl,
  MQTTSubscribeCtrl

  {$IFDEF IsDesktop}
    , SysUtils
  {$ENDIF}
  ;

{Warning:
  If the library functions return with OutOfMemory errors, it means the library buffers and/or flags are usually, in an unconsistent state.
  Although some functions may not cause inconsistencies, a working state is most of the times, unrecoverable.
  In this case, the reserved memory has to be increased.
  It is also possible that there are still some memory leaks, caused by various unhandled error conditions (either the library or the user code).

  It may also happen that processing one client instance will fill the heap, while processing the next one(s) would free some heap.
  Because of such unique condition, it would be difficult to reproduce OutOfMemory errors with multiple clients.
}

type
  PMQTTBuffer = PDynArrayOfByte;
  PMQTTMultiBuffer = PDynArrayOfTDynArrayOfByte;

  TOnMQTTAfterCreateClient = procedure(ClientInstance: DWord); //ClientInstance is the newly generated index
  POnMQTTAfterCreateClient = ^TOnMQTTAfterCreateClient;

  TOnMQTTBeforeDestroyClient = procedure(ClientInstance: DWord); //ClientInstance is the deleted index. After returning from callback, ClientInstance either points to another client, or becomes out of range.
  POnMQTTBeforeDestroyClient = ^TOnMQTTBeforeDestroyClient;

  TOnMQTTError = procedure(ClientInstance: DWord; AErr: Word; APacketType: Byte);
  POnMQTTError = ^TOnMQTTError;


  TOnMQTTClientRequestsDisconnection = procedure(ClientInstance: DWord; AErr: Word); //This is used to disconnect the client, when an error occurs, which must be handled this way.
  POnMQTTClientRequestsDisconnection = ^TOnMQTTClientRequestsDisconnection;          //Upon executing this event, the caller library/app should finish sending the remaining packets to server (which should include a DISCONNECT packet), then actually disconnect.


  TOnBeforeMQTT_CONNECT = function(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                   var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                   var AConnectProperties: TMQTTConnectProperties;            //user code has to fill-in this parameter
                                   ACallbackID: Word): Boolean;
  POnBeforeMQTT_CONNECT = ^TOnBeforeMQTT_CONNECT;


  TOnAfterMQTT_CONNACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                   var AConnAckFields: TMQTTConnAckFields;
                                   var AConnAckProperties: TMQTTConnAckProperties);
  POnAfterMQTT_CONNACK = ^TOnAfterMQTT_CONNACK;


  //Called when user code sends a publish packet to server.
  TOnBeforeSendingMQTT_PUBLISH = function(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                          var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                          var APublishProperties: TMQTTPublishProperties;            //user code has to fill-in this parameter
                                          ACallbackID: Word): Boolean;
  POnBeforeSendingMQTT_PUBLISH = ^TOnBeforeSendingMQTT_PUBLISH;


  //Called when receiving a publish packet from server.
  TOnAfterReceivingMQTT_PUBLISH = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                            var APublishFields: TMQTTPublishFields;
                                            var APublishProperties: TMQTTPublishProperties);
  POnAfterReceivingMQTT_PUBLISH = ^TOnAfterReceivingMQTT_PUBLISH;


  TOnBeforeSendingMQTT_PUBACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var APubAckFields: TMQTTPubAckFields;
                                          var APubAckProperties: TMQTTPubAckProperties);
  POnBeforeSendingMQTT_PUBACK = ^TOnBeforeSendingMQTT_PUBACK;


  TOnBeforeSendingMQTT_PUBREC = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var APubRecFields: TMQTTPubRecFields;
                                          var APubRecProperties: TMQTTPubRecProperties);
  POnBeforeSendingMQTT_PUBREC = ^TOnBeforeSendingMQTT_PUBREC;


  TOnBeforeSendingMQTT_PUBREL = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var APubRelFields: TMQTTPubRelFields;
                                          var APubRelProperties: TMQTTPubRelProperties);
  POnBeforeSendingMQTT_PUBREL = ^TOnBeforeSendingMQTT_PUBREL;


  TOnBeforeSendingMQTT_PUBCOMP = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var APubCompFields: TMQTTPubCompFields;
                                           var APubCompProperties: TMQTTPubCompProperties);
  POnBeforeSendingMQTT_PUBCOMP = ^TOnBeforeSendingMQTT_PUBCOMP;

  TOnBeforeSendingMQTT_SUBSCRIBE = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                             var ASubscribeFields: TMQTTSubscribeFields;
                                             var ASubscribeProperties: TMQTTSubscribeProperties;
                                             ACallbackID: Word);
  POnBeforeSendingMQTT_SUBSCRIBE = ^TOnBeforeSendingMQTT_SUBSCRIBE;


procedure MQTT_Init; //Initializes library vars   (call this before any other library function)
procedure MQTT_Done; //Frees library vars  (after this call, none of the library functions should be called)

function MQTT_CreateClient: Boolean;  //returns True if successful, or False if it can't allocate memory

//Make sure MQTT_Process is called enough times on all the clients with greater index, before calling MQTT_DestroyClient, because their index will be decremented.
//After a call to MQTT_DestroyClient, all the other clients, after this one, will have a new index (decremented).
function MQTT_DestroyClient(ClientInstance: DWord): Boolean;  //returns True if successful, or False if it can't reallocate memory or the ClientInstance is out of range.

function MQTT_GetClientCount: TDynArrayLength; //Can be used in for loops, which iterate ClientInstance, from 0 to MQTT_GetClientCount - 1.

{$IFDEF SingleOutputBuffer}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success
{$ELSE}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
{$ENDIF}
function GetServerToClientBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success

function MQTT_Process(ClientInstance: DWord): Word; //Should be called in the main loop (not necessarily at every iteration), to do packet processing and trigger events. It should be called for every client. If it returns OutOfMemory, then the application has to be adjusted to call MQTT_Process more often and/or reserve more heap memory for MQTT library.
function PutReceivedBufferToMQTTLib(ClientInstance: DWord; var ABuffer: TDynArrayOfByte): Boolean; //Should be called by user code, after receiving data from server. When a valid packet is formed, the MQTT library will process it and call the decoded event.
function CreateClientToServerPacketIdentifier(ClientInstance: DWord): Word;
function ClientToServerPacketIdentifierIsUsed(ClientInstance: DWord; APacketIdentifier: Word): Boolean;

{$IFnDEF SingleOutputBuffer}
  function RemovePacketFromClientToServerBuffer(ClientInstance: DWord): Boolean;
{$ENDIF}

//In the following (main) functions, the lower word of the ClientInstance parameter identifies the client instance (the library is able to implement multiple MQTT clients / device)
function MQTT_CONNECT_NoCallback(ClientInstance: DWord;
                                 var AConnectFields: TMQTTConnectFields;                    //user code should initialize and fill-in this parameter
                                 var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code should initialize and fill-in this parameter

function MQTT_PUBLISH_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                 var APublishProperties: TMQTTPublishProperties): Boolean;  //user code has to fill-in this parameter

function MQTT_CONNECT(ClientInstance: DWord; ACallbackID: Word): Boolean;  //ClientInstance identifies the client instance
function MQTT_PUBLISH(ClientInstance: DWord; ACallbackID: Word; AQoS: Byte): Boolean;  //will call OnBeforeSendingMQTT_PUBLISH, to get the content to publish
//function MQTT_PUBACK(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance ////////// should be documented as not to be called by user code (unless there is a use for it). It is public, for testing purposes only.
//function MQTT_PUBREC(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance ////////// should be documented as not to be called by user code (unless there is a use for it). It is public, for testing purposes only.
function MQTT_SUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;


////////////////////////////////////////////////////////// Multiple functions require calls to Free, both in happy flow and error cases.
////////////////////////////////////////////////////////// all decoder functions (e.g. Decode_ConnAckToCtrlPacket) should return the decoded length. Not sure how to compute in case of an error. Probably, it's what the protocol spec says, to disconnect.
////////////////////////////////////////////////////////// all decoder functions should not compute lengths based on ActualVarAndPayloadLen, because ActualVarAndPayloadLen depends on initial buffer, which may contain multiple packets


//Testing functions (should not be called by user code)
function GetServerToClientPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
function GetServerToClientPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of ClientToServerPacketIdentifiers array
function GetClientToServerPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
function GetClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of ClientToServerPacketIdentifiers array
function GetSendQuota(ClientInstance: DWord): Word;


var
  OnMQTTAfterCreateClient: POnMQTTAfterCreateClient;      //This event is not mandatory to be assigned (and used).
  OnMQTTBeforeDestroyClient: POnMQTTBeforeDestroyClient;  //This event is not mandatory to be assigned (and used).

  OnMQTTError: POnMQTTError;
  OnMQTTClientRequestsDisconnection: POnMQTTClientRequestsDisconnection;

  OnBeforeMQTT_CONNECT: POnBeforeMQTT_CONNECT;
  OnAfterMQTT_CONNACK: POnAfterMQTT_CONNACK;
  OnBeforeSendingMQTT_PUBLISH: POnBeforeSendingMQTT_PUBLISH;
  OnAfterReceivingMQTT_PUBLISH: POnAfterReceivingMQTT_PUBLISH;
  OnBeforeSendingMQTT_PUBACK: POnBeforeSendingMQTT_PUBACK;
  OnBeforeSendingMQTT_PUBREC: POnBeforeSendingMQTT_PUBREC;
  OnBeforeSendingMQTT_PUBREL: POnBeforeSendingMQTT_PUBREL;
  OnBeforeSendingMQTT_PUBCOMP: POnBeforeSendingMQTT_PUBCOMP;
  OnBeforeSendingMQTT_SUBSCRIBE: POnBeforeSendingMQTT_SUBSCRIBE;

const
  CMQTT_Success = 0;     //the following error codes are 300+, to have a different range, compared to standard MQTT error codes
  CMQTT_BadClientIndex = 301;       //ClientInstance parameter, from main functions, is out of bounds
  CMQTT_UnhandledPacketType = 302;  //The client received a packet that is not supposed to receive (that includes packets which are normally sent from client to server)
  CMQTT_HandlerNotAssigned = 303;   //Mostly for internal use. Some user functions may also use it.
  CMQTT_BadQoS = 304;               //The client received a bad QoS value (i.e. 3). It should disconnect from server. Or, the user code calls Publish with a bad QoS.
  CMQTT_ProtocolError = 305;        //The server sent this in a ReasonCode field
  CMQTT_PacketIdentifierNotFound_ClientToServer = 306;            //The server sent an unknown Packet identifier, so the client responds with this error in a PubComp packet
  CMQTT_PacketIdentifierNotFound_ServerToClient = 307;            //The server sent an unknown Packet identifier (in PubAck, i.e. QoS=1), so the client notifies the user about it. No further response to server is expected.
  CMQTT_NoMorePacketIdentifiersAvailable = 308; //Likely a bad state or a memory leak would lead to this error. Usually, the library should not end up here.
  CMQTT_ReceiveMaximumExceeded = 309; //The user code gets this error when attempting to publish more packets than acknowledged by server. The ReceiveMaximum value is set on connect.
  CMQTT_ReceiveMaximumReset = 310;    //The user code gets this error when too many SubAck (and PubRec) packets are received without being published. This may point to a retransmission case.
  CMQTT_OutOfMemory = 300 + CMQTTDecoderOutOfMemory; //11
  CMQTT_NoMoreSubscriptionIdentifiersAvailable = 312; //Likely a bad state or a memory leak would lead to this error. Usually, the library should not end up here.

implementation

//Publish request-response:
//QoS=0:
//Server (Sender) -> Client (Receiver):   Server sends Publish,  Client does not respond
//Client (Sender) -> Server (Receiver):   Client sends Publish,  Server does not respond
//
//QoS=1:
//Server (Sender) -> Client (Receiver):   Server sends Publish,  Client responds with PubAck
//Client (Sender) -> Server (Receiver):   Client sends Publish,  Server responds with PubAck
//
//QoS=2:
//Server (Sender) -> Client (Receiver):   Server sends Publish,  Client responds with PubRec,  Server sends PubRel,  Client responds with PubComp
//Client (Sender) -> Server (Receiver):   Client sends Publish,  Server responds with PubRec,  Client sends PubRel,  Server responds with PubComp

const
  CClientIndexMask = $0000FFFF;


var
  //This is array of array of Byte, i.e. array of buffers. The outer array is indexed by ClientInstance parameter from below functions.
  {$IFDEF SingleOutputBuffer}
    //- Indexed by ClientInstance parameter from main functions.
    //- Packets are concatenated into one buffer / client.
    //- The Ethernet library sends chunks of data (concatenated packets)
    ClientToServerBuffer: TDynArrayOfTDynArrayOfByte;
  {$ELSE}
    //- Indexed by ClientInstance parameter from main functions
    //- packets are items of an array
    //- The Ethernet library sends individual packets
    ClientToServerBuffer: TDynArrayOfPDynArrayOfTDynArrayOfByte;
  {$ENDIF}
  ServerToClientBuffer: TDynArrayOfTDynArrayOfByte;   //indexed by ClientInstance parameter from main functions
  ServerToClientPacketIdentifiers: TDynArrayOfTDynArrayOfWord;  //used when Servers send Publish.   Used on QoS = 2.  Process_PUBLISH adds items to this array.
  ClientToServerPacketIdentifiers: TDynArrayOfTDynArrayOfWord;  //used when Clients send Publish.
  ClientToServerUnAckPacketIdentifiers: TDynArrayOfTDynArrayOfByte;  //should be kept in sync with ClientToServerPacketIdentifiers array
  MaximumQoS: TDynArrayOfTDynArrayOfByte; //used when initiating connections.  This keeps track of the requested and server-updated value of QoS. Updated by SubAck. For each client, there might be multiple topics or subscriptions (which can be a QoS or an error code).
  ClientToServerSendQuota: TDynArrayOfWord; //used on Publish, initialized by Connect, updated by Publish and PubAck/PubRec
  ClientToServerReceiveMaximum: TDynArrayOfWord; //used on Publish, initialized by Connect
  //TopicAliases: TDynArrayOfTDynArrayOfWord; //used when initiating connections.   See also TMQTTProp_TopicAliasMaximum type.
  //an array based on TMQTTProp_ReceiveMaximum
  ClientToServerSubscriptionIdentifier: TDynArrayOfTDynArrayOfWord; //limited to 65534 subscriptions at a time


procedure InitLibStateVars;
begin
  {$IFDEF SingleOutputBuffer}
    InitDynOfDynOfByteToEmpty(ClientToServerBuffer);
  {$ELSE}
    InitDynArrayOfPDynArrayOfTDynArrayOfByteToEmpty(ClientToServerBuffer);
  {$ENDIF}

  InitDynOfDynOfByteToEmpty(ServerToClientBuffer);
  InitDynOfDynOfWordToEmpty(ServerToClientPacketIdentifiers);
  InitDynOfDynOfWordToEmpty(ClientToServerPacketIdentifiers);
  InitDynOfDynOfByteToEmpty(ClientToServerUnAckPacketIdentifiers);
  InitDynArrayOfWordToEmpty(ClientToServerSendQuota);
  InitDynArrayOfWordToEmpty(ClientToServerReceiveMaximum);
  InitDynOfDynOfByteToEmpty(MaximumQoS);
  InitDynOfDynOfWordToEmpty(ClientToServerSubscriptionIdentifier);
end;


procedure CleanupLibStateVars;
begin
  {$IFDEF SingleOutputBuffer}
    FreeDynOfDynOfByteArray(ClientToServerBuffer);
  {$ELSE}
    FreeDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerBuffer);
  {$ENDIF}

  FreeDynOfDynOfByteArray(ServerToClientBuffer);
  FreeDynOfDynOfWordArray(ServerToClientPacketIdentifiers);
  FreeDynOfDynOfWordArray(ClientToServerPacketIdentifiers);
  FreeDynOfDynOfByteArray(ClientToServerUnAckPacketIdentifiers);
  FreeDynArrayOfWord(ClientToServerSendQuota);
  FreeDynArrayOfWord(ClientToServerReceiveMaximum);
  FreeDynOfDynOfByteArray(MaximumQoS);
  FreeDynOfDynOfWordArray(ClientToServerSubscriptionIdentifier);
end;


procedure InitEvents;
begin
  {$IFDEF IsDesktop}
    New(OnMQTTAfterCreateClient);
    New(OnMQTTBeforeDestroyClient);

    New(OnMQTTError);
    New(OnMQTTClientRequestsDisconnection);
    New(OnBeforeMQTT_CONNECT);
    New(OnAfterMQTT_CONNACK);
    New(OnBeforeSendingMQTT_PUBLISH);
    New(OnAfterReceivingMQTT_PUBLISH);
    New(OnBeforeSendingMQTT_PUBACK);
    New(OnBeforeSendingMQTT_PUBREC);
    New(OnBeforeSendingMQTT_PUBREL);
    New(OnBeforeSendingMQTT_PUBCOMP);
    New(OnBeforeSendingMQTT_SUBSCRIBE);

    OnMQTTAfterCreateClient^ := nil;
    OnMQTTBeforeDestroyClient^ := nil;

    OnMQTTError^ := nil;
    OnMQTTClientRequestsDisconnection^ := nil;
    OnBeforeMQTT_CONNECT^ := nil;
    OnAfterMQTT_CONNACK^ := nil;
    OnBeforeSendingMQTT_PUBLISH^ := nil;
    OnAfterReceivingMQTT_PUBLISH^ := nil;
    OnBeforeSendingMQTT_PUBACK^ := nil;
    OnBeforeSendingMQTT_PUBREC^ := nil;
    OnBeforeSendingMQTT_PUBREL^ := nil;
    OnBeforeSendingMQTT_PUBCOMP^ := nil;
    OnBeforeSendingMQTT_SUBSCRIBE^ := nil;
  {$ELSE}
    OnMQTTAfterCreateClient := nil;
    OnMQTTBeforeDestroyClient := nil;

    OnMQTTError := nil;
    OnMQTTClientRequestsDisconnection := nil;
    OnBeforeMQTT_CONNECT := nil;
    OnAfterMQTT_CONNACK := nil;
    OnBeforeSendingMQTT_PUBLISH := nil;
    OnAfterReceivingMQTT_PUBLISH := nil;
    OnBeforeSendingMQTT_PUBACK := nil;
    OnBeforeSendingMQTT_PUBREC := nil;
    OnBeforeSendingMQTT_PUBREL := nil;
    OnBeforeSendingMQTT_PUBCOMP := nil;
    OnBeforeSendingMQTT_SUBSCRIBE := nil;
  {$ENDIF}
end;


procedure CleanupEvents;
begin
  {$IFDEF IsDesktop}
    Dispose(OnMQTTAfterCreateClient);
    Dispose(OnMQTTBeforeDestroyClient);

    Dispose(OnMQTTError);
    Dispose(OnMQTTClientRequestsDisconnection);
    Dispose(OnBeforeMQTT_CONNECT);
    Dispose(OnAfterMQTT_CONNACK);
    Dispose(OnBeforeSendingMQTT_PUBLISH);
    Dispose(OnAfterReceivingMQTT_PUBLISH);
    Dispose(OnBeforeSendingMQTT_PUBACK);
    Dispose(OnBeforeSendingMQTT_PUBREC);
    Dispose(OnBeforeSendingMQTT_PUBREL);
    Dispose(OnBeforeSendingMQTT_PUBCOMP);
    Dispose(OnBeforeSendingMQTT_SUBSCRIBE);
  {$ENDIF}

  OnMQTTAfterCreateClient := nil;
  OnMQTTBeforeDestroyClient := nil;

  OnMQTTError := nil;
  OnMQTTClientRequestsDisconnection := nil;
  OnBeforeMQTT_CONNECT := nil;
  OnAfterMQTT_CONNACK := nil;
  OnBeforeSendingMQTT_PUBLISH := nil;
  OnAfterReceivingMQTT_PUBLISH := nil;
  OnBeforeSendingMQTT_PUBACK := nil;
  OnBeforeSendingMQTT_PUBREC := nil;
  OnBeforeSendingMQTT_PUBREL := nil;
  OnBeforeSendingMQTT_PUBCOMP := nil;
  OnBeforeSendingMQTT_SUBSCRIBE := nil;
end;


procedure MQTT_Init; //Init library vars
begin
  InitLibStateVars;
  InitEvents;
end;


procedure MQTT_Done; //Frees library vars
begin
  CleanupEvents;
  CleanupLibStateVars;
end;


function IsValidClientInstance(ClientInstance: DWord): Boolean;
begin
  ClientInstance := ClientInstance and CClientIndexMask;
  Result := (ClientToServerBuffer.Len > 0) and (ClientInstance < ClientToServerBuffer.Len);
  //ClientToServerBuffer should have the same length as ServerToClientBuffer. They may get out of sync in case of an OutOfMemory error.
end;


procedure DoOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnMQTTError) or not Assigned(OnMQTTError^) then
  {$ELSE}
    if OnMQTTError = nil then
  {$ENDIF}
    begin
      //AErr := CMQTT_HandlerNotAssigned;   //exiting anyway
      Exit;
    end;

  OnMQTTError^(ClientInstance, AErr, APacketType);
end;


//Called in case of a protocol error, to notify user application that is should disconnect from server.
procedure DoOnMQTTClientRequestsDisconnection(ClientInstance: DWord; AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnMQTTClientRequestsDisconnection) or not Assigned(OnMQTTClientRequestsDisconnection^) then
  {$ELSE}
    if OnMQTTClientRequestsDisconnection = nil then
  {$ENDIF}
    begin
      //AErr := CMQTT_HandlerNotAssigned;   //exiting anyway
      Exit;
    end;

  OnMQTTClientRequestsDisconnection^(ClientInstance, AErr);
end;


function DoOnBeforeMQTT_CONNECT(ClientInstance: DWord; var ATempConnectFields: TMQTTConnectFields; var ATempConnectProperties: TMQTTConnectProperties; var AErr: Word; ACallbackID: Word): Boolean;
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeMQTT_CONNECT) or not Assigned(OnBeforeMQTT_CONNECT^) then
  {$ELSE}
    if OnMQTT_CONNECT = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Result := False;
      Exit;
    end;

  Result := OnBeforeMQTT_CONNECT^(ClientInstance, ATempConnectFields, ATempConnectProperties, ACallbackID);
end;

                                 //The lower word identifies the client instance
procedure DoOnAfterMQTT_CONNACK(ClientInstance: DWord; var AConnAckFields: TMQTTConnAckFields; var AConnAckProperties: TMQTTConnAckProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterMQTT_CONNACK) or not Assigned(OnAfterMQTT_CONNACK^) then
  {$ELSE}
    if OnAfterMQTT_CONNACK = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterMQTT_CONNACK^(ClientInstance, AConnAckFields, AConnAckProperties);
end;


function DoOnBeforeSendingMQTT_PUBLISH(ClientInstance: DWord; var ATempPublishFields: TMQTTPublishFields; var ATempPublishProperties: TMQTTPublishProperties; var AErr: Word; ACallbackID: Word): Boolean;
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_PUBLISH) or not Assigned(OnBeforeSendingMQTT_PUBLISH^) then
  {$ELSE}
    if OnBeforeSendingMQTT_PUBLISH = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Result := False;
      Exit;
    end;

  Result := OnBeforeSendingMQTT_PUBLISH^(ClientInstance, ATempPublishFields, ATempPublishProperties, ACallbackID);
end;


procedure DoOnAfterReceivingMQTT_PUBLISH(ClientInstance: DWord; var ATempPublishFields: TMQTTPublishFields; var ATempPublishProperties: TMQTTPublishProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PUBLISH) or not Assigned(OnAfterReceivingMQTT_PUBLISH^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PUBLISH = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PUBLISH^(ClientInstance, ATempPublishFields, ATempPublishProperties);
end;


procedure DoOnBeforeSending_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_PUBACK) or not Assigned(OnBeforeSendingMQTT_PUBACK^) then
  {$ELSE}
    if OnBeforeSendingMQTT_PUBACK = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_PUBACK^(ClientInstance, ATempPubAckFields, ATempPubAckProperties);
end;


procedure DoOnBeforeSending_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_PUBREC) or not Assigned(OnBeforeSendingMQTT_PUBREC^) then
  {$ELSE}
    if OnBeforeSendingMQTT_PUBREC = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_PUBREC^(ClientInstance, ATempPubRecFields, ATempPubRecProperties);
end;


procedure DoOnBeforeSending_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_PUBREL) or not Assigned(OnBeforeSendingMQTT_PUBREL^) then
  {$ELSE}
    if OnBeforeSendingMQTT_PUBREL = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_PUBREL^(ClientInstance, ATempPubRelFields, ATempPubRelProperties);
end;


procedure DoOnBeforeSending_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_PUBCOMP) or not Assigned(OnBeforeSendingMQTT_PUBCOMP^) then
  {$ELSE}
    if OnBeforeSendingMQTT_PUBCOMP = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_PUBCOMP^(ClientInstance, ATempPubCompFields, ATempPubCompProperties);
end;


procedure DoOnBeforeSending_MQTT_SUBSCRIBE(ClientInstance: DWord; var ATempSubscribeFields: TMQTTSubscribeFields; var ATempSubscribeProperties: TMQTTSubscribeProperties; var AErr: Word; ACallbackID: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_SUBSCRIBE) or not Assigned(OnBeforeSendingMQTT_SUBSCRIBE^) then
  {$ELSE}
    if OnBeforeSendingMQTT_SUBSCRIBE = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_SUBSCRIBE^(ClientInstance, ATempSubscribeFields, ATempSubscribeProperties, ACallbackID);
end;


/////////////////////////////////


function CreateClientToServerPacketIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^);

  if Result <> $FFFF then
    if not AddByteToDynArray(0, ClientToServerUnAckPacketIdentifiers.Content^[TempClientInstance]^) then
    begin
      Result := $FFFF;
      DoOnMQTTError(ClientInstance, CMQTT_OutOfMemory, CMQTT_UNDEFINED);
    end;
end;


function GetIndexOfClientToServerPacketIdentifier(ClientInstance: DWord; APacketIdentifier: Word): TDynArrayLengthSig; //returns -1 if not found
var
  i, Dest: TDynArrayLengthSig;
  TempClientInstance: DWord;
begin
  Result := -1;

  TempClientInstance := ClientInstance and CClientIndexMask;
  Dest := ClientToServerPacketIdentifiers.Content^[TempClientInstance]^.Len - 1;

  for i := 0 to Dest do
    if ClientToServerPacketIdentifiers.Content^[TempClientInstance]^.Content^[i] = APacketIdentifier then
    begin
      Result := i;
      Exit;
    end;
end;


function RemoveClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: Word): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := DeleteItemFromDynArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
  if Result then
    Result := DeleteItemFromDynArray(ClientToServerUnAckPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
end;


function ClientToServerPacketIdentifierIsUsed(ClientInstance: DWord; APacketIdentifier: Word): Boolean;
begin
  Result := GetIndexOfClientToServerPacketIdentifier(ClientInstance, APacketIdentifier) <> -1;
end;


/////////////


function CreateServerToClientPacketIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWord(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^);

  //if Result <> $FFFF then
  //  if not AddByteToDynArray(0, ServerToClientUnAckPacketIdentifiers.Content^[TempClientInstance]^) then
  //  begin
  //    Result := $FFFF;
  //    DoOnMQTTError(ClientInstance, CMQTT_OutOfMemory, CMQTT_UNDEFINED);
  //  end;
end;


function GetIndexOfServerToClientPacketIdentifier(ClientInstance: DWord; APacketIdentifier: Word): TDynArrayLengthSig; //returns -1 if not found
var
  i, Dest: TDynArrayLengthSig;
  TempClientInstance: DWord;
begin
  Result := -1;

  TempClientInstance := ClientInstance and CClientIndexMask;
  Dest := ServerToClientPacketIdentifiers.Content^[TempClientInstance]^.Len - 1;

  for i := 0 to Dest do
    if ServerToClientPacketIdentifiers.Content^[TempClientInstance]^.Content^[i] = APacketIdentifier then
    begin
      Result := i;
      Exit;
    end;
end;


function RemoveServerToClientPacketIdentifierByIndex(ClientInstance: DWord; AIndex: Word): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := DeleteItemFromDynArrayOfWord(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
  //if Result then
  //  Result := DeleteItemFromDynArray(ServerToClientUnAckPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
end;


function ServerToClientPacketIdentifierIsUsed(ClientInstance: DWord; APacketIdentifier: Word): Boolean;
begin
  Result := GetIndexOfServerToClientPacketIdentifier(ClientInstance, APacketIdentifier) <> -1;
end;


function DecrementSendQuota(ClientInstance: DWord): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := True;

  if ClientToServerSendQuota.Content^[TempClientInstance] > 0 then
    Dec(ClientToServerSendQuota.Content^[TempClientInstance])
  else
    Result := False;
end;


function IncrementSendQuota(ClientInstance: DWord): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := True;

  if ClientToServerSendQuota.Content^[TempClientInstance] < ClientToServerReceiveMaximum.Content^[TempClientInstance] then
    Inc(ClientToServerSendQuota.Content^[TempClientInstance])
  else
    Result := False;
end;


/////////////////////


function CreateClientToServerSubscriptionIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWord(ClientToServerSubscriptionIdentifier.Content^[TempClientInstance]^);
end;


/////////////////////////////////

function MQTT_CreateClient: Boolean;  //returns True if successful, or False if it can't allocate memory
begin
  {$IFDEF SingleOutputBuffer}
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ELSE}
    Result := SetDynOfPDynArrayOfTDynArrayOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ENDIF}

  if Result then
  begin
    Result := SetDynOfDynOfByteLength(ServerToClientBuffer, ServerToClientBuffer.Len + 1);
    Result := Result and SetDynOfDynOfWordLength(ServerToClientPacketIdentifiers, ServerToClientPacketIdentifiers.Len + 1);
    Result := Result and SetDynOfDynOfWordLength(ClientToServerPacketIdentifiers, ClientToServerPacketIdentifiers.Len + 1);
    Result := Result and SetDynOfDynOfByteLength(ClientToServerUnAckPacketIdentifiers, ClientToServerUnAckPacketIdentifiers.Len + 1);
    Result := Result and SetDynOfWordLength(ClientToServerSendQuota, ClientToServerSendQuota.Len + 1);
    Result := Result and SetDynOfWordLength(ClientToServerReceiveMaximum, ClientToServerSendQuota.Len + 1);
    Result := Result and SetDynOfDynOfByteLength(MaximumQoS, MaximumQoS.Len + 1);

    {$IFDEF IsDesktop}
      if Assigned(OnMQTTAfterCreateClient) and Assigned(OnMQTTAfterCreateClient^) then
    {$ELSE}
      if OnMQTTAfterCreateClient <> nil then
    {$ENDIF}
        OnMQTTAfterCreateClient^(ClientToServerBuffer.Len);
  end;
end;


function MQTT_DestroyClient(ClientInstance: DWord): Boolean;
begin
  Result := IsValidClientInstance(ClientInstance);
  if not Result then
  begin
    DoOnMQTTError(ClientInstance, CMQTT_BadClientIndex, CMQTT_UNDEFINED);
    Exit;
  end;

  {$IFDEF SingleOutputBuffer}
    Result := DeleteItemFromDynOfDynOfByte(ClientToServerBuffer, ClientInstance);
  {$ELSE}
    Result := DeleteItemFromDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerBuffer, ClientInstance);
  {$ENDIF}

  if Result then     //There is some internal reallocation while deleting, so it is possible that Result would be False, in case of an OutOfMemory error.
  begin
    {$IFDEF IsDesktop}
      if Assigned(OnMQTTBeforeDestroyClient) and Assigned(OnMQTTBeforeDestroyClient^) then
    {$ELSE}
      if OnMQTTBeforeDestroyClient <> nil then
    {$ENDIF}
        OnMQTTBeforeDestroyClient^(ClientInstance);

    Result := DeleteItemFromDynOfDynOfByte(ServerToClientBuffer, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ServerToClientPacketIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ClientToServerPacketIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfByte(ClientToServerUnAckPacketIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerSendQuota, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerReceiveMaximum, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfByte(MaximumQoS, ClientInstance);
  end;
end;


function MQTT_GetClientCount: TDynArrayLength;
begin
  Result := ServerToClientBuffer.Len;
end;


{$IFDEF SingleOutputBuffer}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success
{$ELSE}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
{$ENDIF}
begin
  AErr := CMQTT_Success;

  if IsValidClientInstance(ClientInstance) then
    {$IFDEF SingleOutputBuffer}
      Result := ClientToServerBuffer.Content^[ClientInstance and CClientIndexMask]
    {$ELSE}
      Result := ClientToServerBuffer.Content^[ClientInstance and CClientIndexMask]
    {$ENDIF}
  else
  begin
    Result := nil;
    AErr := CMQTT_BadClientIndex;
  end;
end;


function GetServerToClientBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //AErr is 0 for success
begin
  AErr := CMQTT_Success;

  if IsValidClientInstance(ClientInstance) then
    Result := ServerToClientBuffer.Content^[ClientInstance and CClientIndexMask]
  else
  begin
    Result := nil;
    AErr := CMQTT_BadClientIndex;
  end;
end;

/////////////////////////////////

function AddMQTTControlPacket_ToBuffer(var ABuffer: TDynArrayOfByte; var APacket: TMQTTControlPacket): Boolean;
begin
  Result := ConcatDynArrays(ABuffer, APacket.Header);

  if Result then
    Result := ConcatDynArrays(ABuffer, APacket.VarHeader);

  if Result then
    Result := ConcatDynArrays(ABuffer, APacket.Payload);
end;


function AddCONNECT_ToBuffer(var ABuffer: TDynArrayOfByte;
                             var AConnectFields: TMQTTConnectFields;
                             var AConnectProperties: TMQTTConnectProperties;
                             var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Connect(AConnectFields, AConnectProperties, ADestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, ADestPacket);
end;


function AddPUBLISH_ToBuffer(var ABuffer: TDynArrayOfByte;
                             var APublishFields: TMQTTPublishFields;
                             var APublishProperties: TMQTTPublishProperties;
                             var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Publish(APublishFields, APublishProperties, ADestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, ADestPacket);
end;


function AddPUBResponse_ToBuffer(var ABuffer: TDynArrayOfByte;
                                 var APubRespFields: TMQTTCommonFields;
                                 var APubRespProperties: TMQTTCommonProperties;
                                 APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                                 var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Common(APubRespFields, APubRespProperties, APacketType, ADestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, ADestPacket);
end;


function AddSUBSCRIBE_ToBuffer(var ABuffer: TDynArrayOfByte;
                               var ASubscribeFields: TMQTTSubscribeFields;
                               var ASubscribeProperties: TMQTTSubscribeProperties;
                               // APacketType: Byte; //valid values are
                               var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Subscribe(ASubscribeFields, ASubscribeProperties, ADestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, ADestPacket);
end;



/////////////////////////////////


function MQTT_CONNECT_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                 var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code has to fill-in this parameter
var
  TempDestPacket: TMQTTControlPacket;
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // AConnectFields and AConnectProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, AConnectFields, AConnectProperties, TempDestPacket);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, AConnectFields, AConnectProperties, TempDestPacket);
  {$ENDIF}

  MQTT_FreeControlPacket(TempDestPacket);
end;


function MQTT_PUBLISH_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                 var APublishProperties: TMQTTPublishProperties): Boolean;  //user code has to fill-in this parameter
var
  TempDestPacket: TMQTTControlPacket;
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // APublishFields and APublishProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddPUBLISH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, APublishFields, APublishProperties, TempDestPacket);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddPUBLISH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, APublishFields, APublishProperties, TempDestPacket);
  {$ENDIF}

  MQTT_FreeControlPacket(TempDestPacket);
end;


function MQTT_PUBResponse_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                     APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                                     var APubAckFields: TMQTTPubAckFields;                    //user code has to fill-in this parameter
                                     var APubAckProperties: TMQTTPubAckProperties): Boolean;  //user code has to fill-in this parameter
var
  TempDestPacket: TMQTTControlPacket;
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // APubAckFields and APubAckProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddPUBResponse_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, APubAckFields, APubAckProperties, TempDestPacket);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddPUBResponse_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, APubAckFields, APubAckProperties, APacketType, TempDestPacket);
  {$ENDIF}

  MQTT_FreeControlPacket(TempDestPacket);
end;


function MQTT_SUBSCRIBE_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                   var ASubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
                                   var ASubscribeProperties: TMQTTSubscribeProperties): Boolean;  //user code has to fill-in this parameter
var
  TempDestPacket: TMQTTControlPacket;
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // ASubscribeFields and ASubscribeProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, ASubscribeFields, ASubscribeProperties, TempDestPacket);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, ASubscribeFields, ASubscribeProperties, TempDestPacket);
  {$ENDIF}

  MQTT_FreeControlPacket(TempDestPacket);
end;


/////////////////////////////////


function Process_ErrPacket(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_UnhandledPacketType;
end;


//Used in ClientToServer scenario.
function Process_CONNACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  TempConnAckFields: TMQTTConnAckFields;
  TempConnAckProperties: TMQTTConnAckProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);

  Result := Decode_ConnAckToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitConnAckProperties(TempConnAckProperties);
    Result := Decode_ConnAck(TempReceivedPacket, TempConnAckFields, TempConnAckProperties);
  end;

  if Lo(Result) <> CMQTTDecoderNoErr then
  begin
    //MQTT_FreeConnAckProperties(TempConnAckProperties);    // not initialized here
    MQTT_FreeControlPacket(TempReceivedPacket);
    Exit;
  end;
  ////////////////////////////////////// There may be some error cases, which will safely allow the packet to be discarded.  ToDo: handle those cases.


  if Lo(Result) = CMQTTDecoderNoErr then   //Decode_ConnAck can return CMQTTDecoderIncompleteBuffer, which is not an error, is likely an info.   However, the event should not be triggered by it.
  begin
    DoOnAfterMQTT_CONNACK(ClientInstance, TempConnAckFields, TempConnAckProperties, Result);

    if Result <> CMQTTDecoderNoErr then
    begin
      MQTT_FreeConnAckProperties(TempConnAckProperties);
      MQTT_FreeControlPacket(TempReceivedPacket);
      Exit;
    end;
  end;

  MQTT_FreeConnAckProperties(TempConnAckProperties);
  MQTT_FreeControlPacket(TempReceivedPacket);
end;


procedure InitRespPubFieldsAndProperties(var ARespPubFields: TMQTTCommonFields; var ARespPubProperties: TMQTTCommonProperties; APacketIdentifier: Word);
begin
  MQTT_InitCommonProperties(ARespPubProperties);
  ARespPubFields.PacketIdentifier := APacketIdentifier;
  ARespPubFields.ReasonCode := CMQTT_Reason_Success;
  ARespPubFields.IncludeReasonCode := 0; //if IncludeReasonCode is 0, probably ReasonCode doesn't matter
  ARespPubFields.EnabledProperties := 0;
  InitDynArrayToEmpty(ARespPubFields.SrcPayload);
end;


//Used in ServerToClient scenario (It can handle QoS=0..2).
function Process_PUBLISH(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempClientInstance: DWord;
  TempReceivedPacket: TMQTTControlPacket;
  TempPublishFields: TMQTTPublishFields;
  TempPublishProperties: TMQTTPublishProperties;

  RespPubFields: TMQTTCommonFields;
  RespPubProperties: TMQTTCommonProperties;

  QoS: Byte;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := Decode_PublishToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitPublishProperties(TempPublishProperties);
    InitDynArrayToEmpty(TempPublishFields.TopicName);
    InitDynArrayToEmpty(TempPublishFields.ApplicationMessage);
    Result := Decode_Publish(TempReceivedPacket, TempPublishFields, TempPublishProperties);
  end;
  MQTT_FreeControlPacket(TempReceivedPacket);

  QoS := 4; //some unhandled value
  if Lo(Result) = CMQTTDecoderNoErr then      // Hi(Result) may contain more info about the error, like the error location.
  begin
    QoS := (TempPublishFields.PublishCtrlFlags shr 1) and 3;

    //ToDo: verify if this is an "unsolicited Application Message (not resulting from a subscription)"
    //with "QoS greater than Maximum QoS" (see spec pag 61), (see MaximumQoS[ClientInstance] array, for each client, set on connect), then
    //call MQTT_DISCONNECTResponse_NoCallback(ClientInstance, RespPubFields, RespPubProperties) with CMQTT_Reason_QoSNotSupported
    //and call OnMQTTClientRequestsDisconnection(ClientInstance, CMQTT_Reason_QoSNotSupported).

    //ToDo: also verify if "Topic Alias" is greater than "Maximum Topic Alias". If that's the case, disconnect with CMQTT_Reason_TopicAliasInvalid.
    //      if (TempPublishProperties.TopicAlias = 0) or (TempPublishProperties.TopicAlias >= TempConnAckProperties.TopicAliasMaximum) then   (see pag 61 of MQTT doc)
    //ToDo: update "Topic Name", based on "Topic Alias".

    DoOnAfterReceivingMQTT_PUBLISH(ClientInstance, TempPublishFields, TempPublishProperties, Result);

    if Result <> CMQTTDecoderNoErr then
    begin
      MQTT_FreePublishProperties(TempPublishProperties);
      Exit;
    end;
  end
  else
  begin
    MQTT_FreePublishProperties(TempPublishProperties);
    Exit;
  end;

  Result := CMQTT_Success;
  //TempPublishProperties.SubscriptionIdentifier;      //  - array of DWord


  case QoS of
    0 : //  Expected Response: None
    begin
      ////////////////////////////////////////////////////////////////////////////////////////////////////
    end;

    1 : //  Expected response to server: PUBACK packet           QoS=1 allows duplicates, so PacketIdentifier is not added to ServerToClientPacketIdentifiers array
    begin    //the receiver MUST respond with a PUBACK packet containing the Packet Identifier from the incoming PUBLISH packet, having accepted ownership of the Application Message (spec pag 94)
      InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPublishFields.PacketIdentifier);  //TempPublishFields comes from Decode_Publish above
      DoOnBeforeSending_MQTT_PUBACK(ClientInstance, RespPubFields, RespPubProperties, Result);

      if Result = CMQTT_Success then
        if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBACK, RespPubFields, RespPubProperties) then
          MQTT_FreeCommonProperties(RespPubProperties)
        else
          Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server
    end;

    2 : //  Expected response to server: PUBREC packet
    begin
      ///////////////////////////////////// check for  quota exceeded, authorization etc. Based on this, set RespPubFields and RespPubProperties!  (see spec, pag 96)
      //If responding (as PUBREC) with an error code (greater than $80) in RespPubFields,
      //then add a flag (maybe to a new array) with that PacketIdentifier, to treat it as new, until a PUBREL packet is received (with that ID). (see spec, pag 96)

      InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPublishFields.PacketIdentifier);   //TempPublishFields comes from Decode_Publish above

      //This should be filtered further, by Topic Filters. (spec pag 77)

      if GetIndexOfServerToClientPacketIdentifier(ClientInstance, TempPublishFields.PacketIdentifier) = -1 then
        DoOnBeforeSending_MQTT_PUBREC(ClientInstance, RespPubFields, RespPubProperties, Result);   //calling user code is done regardless of responding with error code, but should not be called as duplicate message

      if Result = CMQTT_Success then
        if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBREC, RespPubFields, RespPubProperties) then
        begin
          MQTT_FreeCommonProperties(RespPubProperties);
          //if CreateServerToClientPacketIdentifier(ClientInstance) = $FFFF then  /////////// Do not use CreateServerToClientPacketIdentifier, because the existing value has to be added.
          if not AddWordToDynArraysOfWord(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^, RespPubFields.PacketIdentifier) then //a new item is aded to PacketIdentifiers array
            Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server  .  It is possible that $FFFF is returned as array full, but it's unlikely.
        end
        else
          Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server
    end;

    3 : //  Expected Response: Protocol error, should disconnect
    begin
      Result := CMQTT_BadQoS;
      Exit;
    end;
  end;

  MQTT_FreePublishProperties(TempPublishProperties);

  FreeDynArray(TempPublishFields.TopicName);
  FreeDynArray(TempPublishFields.ApplicationMessage);
end;


//This function processes, in the same way, both PUBACK and PUBCOMP.
//PUBACK is a response from server, after the client has sent a PUBLISH packet with QoS=1.  No further request is expected from this function.
//PUBACK is used in ClientToServer scenario (QoS=1 only).
function Process_PUBACK_OR_PUBCOMP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord; APacketType: Byte): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  PacketIdentifierIdx: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempCommonFields: TMQTTCommonFields;
  TempCommonProperties: TMQTTCommonProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := Decode_CommonToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitCommonProperties(TempCommonProperties);
    InitDynArrayToEmpty(TempCommonFields.SrcPayload);
    Result := Decode_Common(TempReceivedPacket, TempCommonFields, TempCommonProperties);
    MQTT_FreeControlPacket(TempReceivedPacket);

    if TempCommonFields.ReasonCode >= 128 then  //expecting CMQTT_Reason_PacketIdentifierNotFound
      DoOnMQTTError(TempClientInstance, CMQTT_ProtocolError or TempCommonFields.ReasonCode shl 8, APacketType);   //not sure what to do here. Disconnect?

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, TempCommonFields.PacketIdentifier);
    //No sure what happens if the server sends a wrong Packet Identifier.

    if PacketIdentifierIdx = -1 then
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServer, APacketType) //calling the event with APacketType, because this is Process_PUBACK_OR_PUBCOMP
    else
    begin
      if not IncrementSendQuota(ClientInstance) then
        DoOnMQTTError(TempClientInstance, CMQTT_ReceiveMaximumReset, APacketType);   //too many acknowledgements

      RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx);
    end;
  end;
end;


//PUBACK is a response from server, after the client has sent a PUBLISH packet with QoS=1.  No further request is expected from this function.
//Used in ClientToServer scenario (QoS=1 only).
function Process_PUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := Process_PUBACK_OR_PUBCOMP(ClientInstance, ABuffer, ASizeToFree, CMQTT_PUBACK);
end;


//PUBREC is a response from server, after the client has sent a PUBLISH packet with QoS=2.
//This function (as Client) sends PubRel to server.
//Used in ClientToServer scenario (QoS=2).
function Process_PUBREC(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  PacketIdentifierIdx: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempPubRecFields: TMQTTPubRecFields;
  TempPubRecProperties: TMQTTPubRecProperties;
  RespPubFields: TMQTTCommonFields;
  RespPubProperties: TMQTTCommonProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CMQTT_Success;

  Result := Decode_PubRecToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitCommonProperties(TempPubRecProperties);
    InitDynArrayToEmpty(TempPubRecFields.SrcPayload);
    Result := Decode_PubRec(TempReceivedPacket, TempPubRecFields, TempPubRecProperties);
    MQTT_FreeControlPacket(TempReceivedPacket);

    if TempPubRecFields.ReasonCode >= 128 then  //expecting CMQTT_Reason_PacketIdentifierNotFound
      DoOnMQTTError(TempClientInstance, CMQTT_ProtocolError or TempPubRecFields.ReasonCode shl 8, CMQTT_PUBACK);   //not sure what to do here. Disconnect?

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, TempPubRecFields.PacketIdentifier);
    //If the server sends a wrong Packet Identifier, respond with some error code.////////////////////////////////////

    // respond with PUBREL to server
    InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPubRecFields.PacketIdentifier);

    if PacketIdentifierIdx = -1 then
    begin
      RespPubFields.ReasonCode := CMQTT_Reason_PacketIdentifierNotFound;
      RespPubFields.IncludeReasonCode := 1;
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServer, CMQTT_PUBREC); //calling the event with CMQTT_PUBREC, because this is Process_PUBREC
    end;

    DoOnBeforeSending_MQTT_PUBREL(ClientInstance, RespPubFields, RespPubProperties, Result);

    if Result = CMQTT_Success then
      if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBREL, RespPubFields, RespPubProperties) then
      begin
        MQTT_FreeCommonProperties(RespPubProperties);
        // The PacketIdentifier is removed here, not in MQTT_PUBResponse_NoCallback, because its index is already available here.
        if PacketIdentifierIdx <> -1 then
        begin
          if TempPubRecFields.ReasonCode >= 128 then  //Verify response error for PUBREC only !!! Other packets should not have this check.
            if not IncrementSendQuota(ClientInstance) then
              DoOnMQTTError(TempClientInstance, CMQTT_ReceiveMaximumReset, CMQTT_PUBACK);   //too many acknowledgements

          if not RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
            Result := CMQTT_OutOfMemory;
        end;
      end
      else
        Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server
  end
  else
  begin
    //respond with some error code ?
  end;
end;


//Used in ServerToClient scenario (QoS=2).
function Process_PUBREL(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;  //responds with PUBCOMP to server
var
  TempReceivedPacket: TMQTTControlPacket;
  PacketIdentifierIdx: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempPubRelFields: TMQTTPubRelFields;
  TempPubRelProperties: TMQTTPubRelProperties;
  RespPubFields: TMQTTCommonFields;
  RespPubProperties: TMQTTCommonProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := Decode_PubRelToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitCommonProperties(TempPubRelProperties);
    InitDynArrayToEmpty(TempPubRelFields.SrcPayload);
    Result := Decode_PubRel(TempReceivedPacket, TempPubRelFields, TempPubRelProperties);
    MQTT_FreeControlPacket(TempReceivedPacket);

    if TempPubRelFields.ReasonCode >= 128 then  //expecting CMQTT_Reason_PacketIdentifierNotFound
      DoOnMQTTError(TempClientInstance, CMQTT_ProtocolError or TempPubRelFields.ReasonCode shl 8, CMQTT_PUBREL);   //not sure what to do here. Disconnect?

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^, TempPubRelFields.PacketIdentifier);

    // respond with PUBCOMP to server
    InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPubRelFields.PacketIdentifier);

    if PacketIdentifierIdx = -1 then
    begin
      RespPubFields.ReasonCode := CMQTT_Reason_PacketIdentifierNotFound;
      RespPubFields.IncludeReasonCode := 1;
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ServerToClient, CMQTT_PUBREL); //calling the event with CMQTT_PUBREL, because this is Process_PUBREL
    end;

    DoOnBeforeSending_MQTT_PUBCOMP(ClientInstance, RespPubFields, RespPubProperties, Result);

    if Result = CMQTT_Success then
      if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBCOMP, RespPubFields, RespPubProperties) then
      begin
        MQTT_FreeCommonProperties(RespPubProperties);
        // The PacketIdentifier is removed here, not in MQTT_PUBResponse_NoCallback, because its index is already available here.
        if PacketIdentifierIdx <> -1 then
          if not RemoveServerToClientPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
            Result := CMQTT_OutOfMemory;
      end
      else
        Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server
  end
  else
  begin
    //respond with some error code ?
  end;
end;


//This is a response from server, after the client has sent a PubRel.
//Used in ClientToServer scenario (QoS=2).
function Process_PUBCOMP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := Process_PUBACK_OR_PUBCOMP(ClientInstance, ABuffer, ASizeToFree, CMQTT_PUBCOMP);
end;


function Process_SUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_UNSUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_PINGRESP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_DISCONNECT(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_AUTH(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;



type
  TMQTTProcessPacket = function(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
  //PMQTTProcessPacket = ^TMQTTProcessPacket;


const
  CPacketProcessor: array[0..15] of TMQTTProcessPacket = (
    @Process_ErrPacket,    //ERR
    @Process_ErrPacket,    //CONNECT
    @Process_CONNACK,      //CONNACK      //Server to Client
    @Process_PUBLISH,      //PUBLISH      //Server to Client
    @Process_PUBACK,       //PUBACK       //Server to Client
    @Process_PUBREC,       //PUBREC       //Server to Client
    @Process_PUBREL,       //PUBREL       //Server to Client
    @Process_PUBCOMP,      //PUBCOMP      //Server to Client
    @Process_ErrPacket,    //SUBSCRIBE
    @Process_SUBACK,       //SUBACK       //Server to Client
    @Process_ErrPacket,    //UNSUBSCRIBE
    @Process_UNSUBACK,     //UNSUBACK     //Server to Client
    @Process_ErrPacket,    //PINGREQ
    @Process_PINGRESP,     //PINGRESP     //Server to Client
    @Process_DISCONNECT,   //DISCONNECT   //Server to Client
    @Process_AUTH          //AUTH         //Server to Client
  );


function MQTT_Process(ClientInstance: DWord): Word;  //this function processes incoming packets (from server to "this" client)
var
  InitialLength: TDynArrayLength;
  PacketType: Byte;
  SizeToFree: DWord;
  BufferPointer: PDynArrayOfByte;
begin
  Result := CMQTT_Success;

  if not IsValidClientInstance(ClientInstance) then
  begin
    Result := CMQTT_BadClientIndex;
    Exit;
  end;

  BufferPointer := ServerToClientBuffer.Content^[ClientInstance];
  InitialLength := BufferPointer^.Len;
  while InitialLength > 0 do
  begin
    PacketType := BufferPointer^.Content^[0];
    Result := CPacketProcessor[(PacketType shr 4) and $0F](ClientInstance, BufferPointer^, SizeToFree);

    if Lo(Result) = CMQTTDecoderNoErr then
      RemoveStartBytesFromDynArray(SizeToFree, BufferPointer^) //Delete the entire CONNACK packet from ABuffer.
    else
      DoOnMQTTError(ClientInstance, Result, PacketType);

    if (Result <> CMQTTDecoderNoErr) or (BufferPointer^.Len = InitialLength) then
      Break; //Either there is an error or nothing could be processed, so move on. This usually happens because of incomplete packets.

    InitialLength := BufferPointer^.Len;
  end;
end;


function PutReceivedBufferToMQTTLib(ClientInstance: DWord; var ABuffer: TDynArrayOfByte): Boolean;
begin
  Result := IsValidClientInstance(ClientInstance);
  if not Result then
    Exit;

  Result := ConcatDynArrays(ServerToClientBuffer.Content^[ClientInstance]^, ABuffer);
end;


//////////////////////////


function MQTT_CONNECT(ClientInstance: DWord; ACallbackID: Word): Boolean;  //ClientInstance identifies the client instance
var
  TempConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
  TempConnectProperties: TMQTTConnectProperties;
  Err: Word;
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  MQTT_InitConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_InitConnectProperties(TempConnectProperties);

  Err := CMQTT_Success;
  Result := DoOnBeforeMQTT_CONNECT(ClientInstance, TempConnectFields, TempConnectProperties, Err, ACallbackID);

  if Result then
    Result := MQTT_CONNECT_NoCallback(ClientInstance, TempConnectFields, TempConnectProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_CONNECT);

  if Result then
  begin
    ClientToServerSendQuota.Content^[TempClientInstance] := TempConnectProperties.ReceiveMaximum;       //this keeps track of current quota (valid range: 0..ReceiveMaximum)
    ClientToServerReceiveMaximum.Content^[TempClientInstance] := TempConnectProperties.ReceiveMaximum;  //this keeps track of the maximum value
  end;

  MQTT_FreeConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_FreeConnectProperties(TempConnectProperties);
end;


function MQTT_PUBLISH(ClientInstance: DWord; ACallbackID: Word; AQoS: Byte): Boolean;
var
  TempPublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
  TempPublishProperties: TMQTTPublishProperties;
  Err: Word;
  NewPacketIdentifier: Word;
  IndexOfNewPacketIdentifier: TDynArrayLengthSig;
  NewQoS: Byte;
begin
  { Every client should have a queue of "PUBLISH-sending" state machines, buffers and PacketIdentifiers for QoS > 0.
  From spec (pag 103):
  Each time the Client or Server sends a PUBLISH packet at QoS > 0, it decrements the send quota. If the
  send quota reaches zero, the Client or Server MUST NOT send any more PUBLISH packets with QoS > 0.
  It MAY continue to send PUBLISH packets with QoS 0, or it MAY choose to suspend
  sending these as well. The Client and Server MUST continue to process and respond to all other MQTT
  Control Packets even if the quota is zero.}

  Result := True;
  AQoS := AQoS and 3;

  if AQoS = 3 then
  begin
    DoOnMQTTError(ClientInstance, CMQTT_BadQoS, CMQTT_PUBLISH);  //
    Result := False;
    Exit;
  end;

  if AQoS > 0 then
  begin
    NewPacketIdentifier := CreateClientToServerPacketIdentifier(ClientInstance);
    if NewPacketIdentifier = $FFFF then
    begin
      DoOnMQTTError(ClientInstance, CMQTT_NoMorePacketIdentifiersAvailable, CMQTT_PUBLISH);  //
      Result := False;
      Exit;
    end;

    if not DecrementSendQuota(ClientInstance) then
    begin
      DoOnMQTTError(ClientInstance, CMQTT_ReceiveMaximumExceeded, CMQTT_PUBLISH);  //
      Result := False;
      Exit;
    end;
  end
  else
    NewPacketIdentifier := 0; //just set a default, but do not add it to the array of identifiers

  InitDynArrayToEmpty(TempPublishFields.ApplicationMessage);
  InitDynArrayToEmpty(TempPublishFields.TopicName);
  TempPublishFields.PacketIdentifier := NewPacketIdentifier;
  TempPublishFields.PublishCtrlFlags := AQoS shl 1; //bits 3-0:  Dup(3), QoS(2-1), Retain(0)   - should be overridden in user callback
  TempPublishFields.EnabledProperties := 0;
  MQTT_InitPublishProperties(TempPublishProperties);

  Err := CMQTT_Success;
  Result := DoOnBeforeSendingMQTT_PUBLISH(ClientInstance, TempPublishFields, TempPublishProperties, Err, ACallbackID);

  NewQoS := (TempPublishFields.PublishCtrlFlags shr 1) and $F;
  if NewQoS <> AQoS then  //if the user changed the QoS, using the handler, so allocate a PacketIdentifier
  begin
    if AQoS > 0 then //PacketIdentifier is already allocated above
    begin
      IndexOfNewPacketIdentifier := GetIndexOfClientToServerPacketIdentifier(ClientInstance, NewPacketIdentifier);
      if IndexOfNewPacketIdentifier > -1 then
        if not RemoveClientToServerPacketIdentifierByIndex(ClientInstance, IndexOfNewPacketIdentifier) then
        begin
          DoOnMQTTError(ClientInstance, CMQTT_OutOfMemory, CMQTT_UNDEFINED);  //
          Result := False;
          Exit;
        end;
    end;

    if NewQoS > 0 then
    begin
      NewPacketIdentifier := CreateClientToServerPacketIdentifier(ClientInstance);    //This also allocates an UnAck flag, which can be reset later from PubAck (for QoS=1) or PubRec (for QoS=2) packet. See ClientToServerUnAckPacketIdentifiers array.
      if NewPacketIdentifier = $FFFF then
      begin
        DoOnMQTTError(ClientInstance, CMQTT_NoMorePacketIdentifiersAvailable, CMQTT_PUBLISH);  //
        Result := False;
        Exit;
      end;

      TempPublishFields.PacketIdentifier := NewPacketIdentifier;
    end;
  end;

  if Result then
    Result := MQTT_PUBLISH_NoCallback(ClientInstance, TempPublishFields, TempPublishProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_PUBLISH);

  FreeDynArray(TempPublishFields.ApplicationMessage);
  FreeDynArray(TempPublishFields.TopicName);
  MQTT_FreePublishProperties(TempPublishProperties);
end;


//function MQTT_PUBACK(ClientInstance: DWord): Boolean;
//begin
//  Result := True;
//end;
//
//
//function MQTT_PUBREC(ClientInstance: DWord): Boolean;
//begin
//  Result := True;
//end;


function MQTT_SUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;
var
  TempSubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
  TempSubscribeProperties: TMQTTSubscribeProperties;
  Err: Word;
  NewPacketIdentifier: Word;
begin
  Result := True;

  // SubscriptionIdentifier can be a DWord, while a PacketIdentifier is a word only.

  //From spec: "A Packet Identifier cannot be used by more than one command at any time." - pag 24.
  //This means that CreateClientToServerPacketIdentifier should be used to allocate a new identifier.

  //if AQoS > 0 then
  begin
    NewPacketIdentifier := CreateClientToServerPacketIdentifier(ClientInstance);
    if NewPacketIdentifier = $FFFF then
    begin
      DoOnMQTTError(ClientInstance, CMQTT_NoMorePacketIdentifiersAvailable, CMQTT_SUBSCRIBE);  //
      Result := False;
      Exit;
    end;
  end;
  //else
  //  NewPacketIdentifier := 0; //just set a default, but do not add it to the array of identifiers

  InitDynArrayToEmpty(TempSubscribeFields.TopicFilters);
  TempSubscribeFields.PacketIdentifier := NewPacketIdentifier;
  TempSubscribeFields.EnabledProperties := CMQTTSubscribe_EnSubscriptionIdentifier;
  MQTT_InitSubscribeProperties(TempSubscribeProperties);

  Err := CMQTT_Success;
  DoOnBeforeSending_MQTT_SUBSCRIBE(ClientInstance, TempSubscribeFields, TempSubscribeProperties, Err, ACallbackID);

  //ToDo: Cache topic filters ///////////////////////////////////////////////////////////

  Result := Err = CMQTT_Success;

  if Result then
    Result := MQTT_SUBSCRIBE_NoCallback(ClientInstance, TempSubscribeFields, TempSubscribeProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_PUBLISH);

  FreeDynArray(TempSubscribeFields.TopicFilters);
  MQTT_FreeSubscribeProperties(TempSubscribeProperties);
end;


{$IFnDEF SingleOutputBuffer}
  function RemovePacketFromClientToServerBuffer(ClientInstance: DWord): Boolean;
  begin
    Result := True;
    if ClientToServerBuffer.Len = 0 then
      Exit;

    Result := DeleteItemFromDynOfDynOfByte(ClientToServerBuffer.Content^[ClientInstance and CClientIndexMask]^, 0);
  end;
{$ENDIF}


//Testing functions (should not be called by user code)
function GetServerToClientPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
begin
  if ClientInstance > ServerToClientPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  Result := ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Len;
end;


function GetServerToClientPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of PacketIdentifiers array
begin
  if ClientInstance > ServerToClientPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  if AIndex > ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('AIndex out of bounds: ' + IntToStr(AIndex));
  {$ENDIF}


  Result := ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Content^[AIndex];
end;


//Testing functions (should not be called by user code)
function GetClientToServerPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
begin
  if ClientInstance > ClientToServerPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  Result := ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Len;
end;


function GetClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of PacketIdentifiers array
begin
  if ClientInstance > ClientToServerPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  if AIndex > ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('AIndex out of bounds: ' + IntToStr(AIndex));
  {$ENDIF}


  Result := ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Content^[AIndex];
end;


function GetSendQuota(ClientInstance: DWord): Word;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := ClientToServerSendQuota.Content^[TempClientInstance];
end;

end.

