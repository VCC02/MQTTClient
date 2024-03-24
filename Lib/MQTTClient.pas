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

{$IFNDEF IsMCU}
  interface
{$ENDIF}

uses
  DynArrays, MQTTUtils,
  MQTTConnectCtrl, MQTTConnAckCtrl,
  MQTTPublishCtrl, MQTTCommonCodecCtrl, MQTTPubRecCtrl, MQTTPubRelCtrl,
  MQTTSubscribeCtrl, MQTTSubAckCtrl, MQTTUnSubscribeCtrl, MQTTUnsubAckCtrl,
  MQTTPingReqCtrl, MQTTPingRespCtrl, MQTTDisconnectCtrl, MQTTAuthCtrl

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

  TOnSend_MQTT_Packet = procedure(ClientInstance: DWord; APacketType: Byte);  //The lower word of ClientInstance identifies the client instance
  POnSend_MQTT_Packet = ^TOnSend_MQTT_Packet;


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


  TOnAfterReceivingMQTT_PUBACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var APubAckFields: TMQTTPubAckFields;
                                           var APubAckProperties: TMQTTPubAckProperties);
  POnAfterReceivingMQTT_PUBACK = ^TOnAfterReceivingMQTT_PUBACK;


  TOnBeforeSendingMQTT_PUBREC = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var APubRecFields: TMQTTPubRecFields;
                                          var APubRecProperties: TMQTTPubRecProperties);
  POnBeforeSendingMQTT_PUBREC = ^TOnBeforeSendingMQTT_PUBREC;


  TOnAfterReceivingMQTT_PUBREC = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var APubRecFields: TMQTTPubRecFields;
                                           var APubRecProperties: TMQTTPubRecProperties);
  POnAfterReceivingMQTT_PUBREC = ^TOnAfterReceivingMQTT_PUBREC;


  TOnBeforeSendingMQTT_PUBREL = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                          var APubRelFields: TMQTTPubRelFields;
                                          var APubRelProperties: TMQTTPubRelProperties);
  POnBeforeSendingMQTT_PUBREL = ^TOnBeforeSendingMQTT_PUBREL;


  TOnAfterReceivingMQTT_PUBREL = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var APubRelFields: TMQTTPubRelFields;
                                           var APubRelProperties: TMQTTPubRelProperties);
  POnAfterReceivingMQTT_PUBREL = ^TOnAfterReceivingMQTT_PUBREL;


  TOnBeforeSendingMQTT_PUBCOMP = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var APubCompFields: TMQTTPubCompFields;
                                           var APubCompProperties: TMQTTPubCompProperties);
  POnBeforeSendingMQTT_PUBCOMP = ^TOnBeforeSendingMQTT_PUBCOMP;


  TOnAfterReceivingMQTT_PUBCOMP = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                            var APubCompFields: TMQTTPubCompFields;
                                            var APubCompProperties: TMQTTPubCompProperties);
  POnAfterReceivingMQTT_PUBCOMP = ^TOnAfterReceivingMQTT_PUBCOMP;


  TOnBeforeSendingMQTT_SUBSCRIBE = function(ClientInstance: DWord;  //The lower word identifies the client instance
                                            var ASubscribeFields: TMQTTSubscribeFields;
                                            var ASubscribeProperties: TMQTTSubscribeProperties;
                                            ACallbackID: Word): Boolean;
  POnBeforeSendingMQTT_SUBSCRIBE = ^TOnBeforeSendingMQTT_SUBSCRIBE;


  //Called when receiving a SubAck packet from server.
  TOnAfterReceivingMQTT_SUBACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                           var ASubAckFields: TMQTTSubAckFields;
                                           var ASubAckProperties: TMQTTSubAckProperties);
  POnAfterReceivingMQTT_SUBACK = ^TOnAfterReceivingMQTT_SUBACK;


  TOnBeforeSendingMQTT_UNSUBSCRIBE = function(ClientInstance: DWord;  //The lower word identifies the client instance
                                              var AUnsubscribeFields: TMQTTUnsubscribeFields;
                                              var AUnsubscribeProperties: TMQTTUnsubscribeProperties;
                                              ACallbackID: Word): Boolean;
  POnBeforeSendingMQTT_UNSUBSCRIBE = ^TOnBeforeSendingMQTT_UNSUBSCRIBE;


  //Called when receiving an UnSubAck packet from server.
  TOnAfterReceivingMQTT_UNSUBACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                             var AUnsubAckFields: TMQTTUnsubAckFields;
                                             var AUnsubAckProperties: TMQTTUnsubAckProperties);
  POnAfterReceivingMQTT_UNSUBACK = ^TOnAfterReceivingMQTT_UNSUBACK;


  TOnAfterReceivingMQTT_PINGRESP = procedure(ClientInstance: DWord);  //The lower word identifies the client instance
  POnAfterReceivingMQTT_PINGRESP = ^TOnAfterReceivingMQTT_PINGRESP;


  TOnBeforeSendingMQTT_DISCONNECT = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                              var ADisconnectFields: TMQTTDisconnectFields;
                                              var ADisconnectProperties: TMQTTDisconnectProperties;
                                              ACallbackID: Word);
  POnBeforeSendingMQTT_DISCONNECT = ^TOnBeforeSendingMQTT_DISCONNECT;


  TOnAfterReceivingMQTT_DISCONNECT = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                              var ADisconnectFields: TMQTTDisconnectFields;
                                              var ADisconnectProperties: TMQTTDisconnectProperties);
  POnAfterReceivingMQTT_DISCONNECT = ^TOnAfterReceivingMQTT_DISCONNECT;


  TOnBeforeSendingMQTT_AUTH = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                        var AAuthFields: TMQTTAuthFields;
                                        var AAuthProperties: TMQTTAuthProperties;
                                        ACallbackID: Word);
  POnBeforeSendingMQTT_AUTH = ^TOnBeforeSendingMQTT_AUTH;


  TOnAfterReceivingMQTT_AUTH = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                         var AAuthFields: TMQTTAuthFields;
                                         var AAuthProperties: TMQTTAuthProperties);
  POnAfterReceivingMQTT_AUTH = ^TOnAfterReceivingMQTT_AUTH;



procedure MQTT_Init; //Initializes library vars   (call this before any other library function)
procedure MQTT_Done; //Frees library vars  (after this call, none of the library functions should be called)

function MQTT_CreateClient: Boolean;  //returns True if successful, or False if it can't allocate memory

//Make sure MQTT_Process is called enough times on all the clients with greater index, before calling MQTT_DestroyClient, because their index will be decremented.
//After a call to MQTT_DestroyClient, all the other clients, after this one, will have a new index (decremented).
function MQTT_DestroyClient(ClientInstance: DWord): Boolean;  //returns True if successful, or False if it can't reallocate memory or the ClientInstance is out of range.

function MQTT_GetClientCount: TDynArrayLength; //Can be used in for loops, which iterate ClientInstance, from 0 to MQTT_GetClientCount - 1.

{$IFDEF SingleOutputBuffer}
  function MQTT_GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success
{$ELSE}
  function MQTT_GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
{$ENDIF}
function MQTT_GetClientToServerResendBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
function MQTT_GetServerToClientBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success

function MQTT_Process(ClientInstance: DWord): Word; //Should be called in the main loop (not necessarily at every iteration), to do packet processing and trigger events. It should be called for every client. If it returns OutOfMemory, then the application has to be adjusted to call MQTT_Process more often and/or reserve more heap memory for MQTT library.
function MQTT_PutReceivedBufferToMQTTLib(ClientInstance: DWord; var ABuffer: TDynArrayOfByte): Boolean; //Should be called by user code, after receiving data from server. When a valid packet is formed, the MQTT library will process it and call the decoded event.
function MQTT_CreateClientToServerPacketIdentifier(ClientInstance: DWord): Word;
function MQTT_ClientToServerPacketIdentifierIsUsed(ClientInstance: DWord; APacketIdentifier: Word): Boolean;
function MQTT_CreateClientToServerSubscriptionIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
function MQTT_RemoveClientToServerSubscriptionIdentifier(ClientInstance: DWord; AIdentifier: Word): Word; // Returns 0 if sucess or $FFFF if it can't reallocate memory.

{$IFnDEF SingleOutputBuffer}
  function MQTT_RemovePacketFromClientToServerBuffer(ClientInstance: DWord): Boolean;
{$ENDIF}

//In the following (main) functions, the lower word of the ClientInstance parameter identifies the client instance (the library is able to implement multiple MQTT clients / device)
function MQTT_CONNECT_NoCallback(ClientInstance: DWord;
                                 var AConnectFields: TMQTTConnectFields;                    //user code should initialize and fill-in this parameter
                                 var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code should initialize and fill-in this parameter

function MQTT_PUBLISH_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                 var APublishProperties: TMQTTPublishProperties): Boolean;  //user code has to fill-in this parameter

function MQTT_SUBSCRIBE_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                   var ASubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
                                   var ASubscribeProperties: TMQTTSubscribeProperties): Boolean;  //user code has to fill-in this parameter

function MQTT_UNSUBSCRIBE_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                     var AUnsubscribeFields: TMQTTUnsubscribeFields;                    //user code has to fill-in this parameter
                                     var AUnsubscribeProperties: TMQTTUnsubscribeProperties): Boolean;  //user code has to fill-in this parameter

function MQTT_DISCONNECT_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                    var ADisconnectFields: TMQTTDisconnectFields;                    //user code has to fill-in this parameter
                                    var ADisconnectProperties: TMQTTDisconnectProperties): Boolean;  //user code has to fill-in this parameter


function MQTT_CONNECT(ClientInstance: DWord; ACallbackID: Word): Boolean;  //ClientInstance identifies the client instance
function MQTT_PUBLISH(ClientInstance: DWord; ACallbackID: Word; AQoS: Byte): Boolean;  //will call OnBeforeSendingMQTT_PUBLISH, to get the content to publish
function MQTT_SUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;
function MQTT_UNSUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;
function MQTT_PINGREQ(ClientInstance: DWord): Boolean;
function MQTT_DISCONNECT(ClientInstance: DWord; ACallbackID: Word): Boolean;
function MQTT_AUTH(ClientInstance: DWord; ACallbackID: Word): Boolean;


//Testing functions (should not be called by user code)
function MQTT_GetServerToClientPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
function MQTT_GetServerToClientPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of ClientToServerPacketIdentifiers array
function MQTT_GetClientToServerPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
function MQTT_GetClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of ClientToServerPacketIdentifiers array
function MQTT_GetSendQuota(ClientInstance: DWord): Word;

//From spec, pag 96:
//When a Client reconnects with Clean Start set to 0 and a session is present, both the Client and Server
//MUST resend any unacknowledged PUBLISH packets (where QoS > 0) and PUBREL packets using their
//original Packet Identifiers.

//MQTT_ResendUnacknowledged should be called by user code after a CONNACK, if TempConnAckFields.SessionPresentFlag is 1, and CMQTT_CleanStartInConnectFlagsBitMask is not present in CONNECT
function MQTT_ResendUnacknowledged(ClientInstance: DWord): Boolean;


//Some of the following events are optional, i.e. the user code doesn't have to assign handlers to them.
//Others are required. If no handler is assigned to required events, the OnMQTTError event is called with error 203 (CMQTT_HandlerNotAssigned).
var
  OnMQTTAfterCreateClient: POnMQTTAfterCreateClient;                     //Optional. This event can be assigned by user code to allocate memory for every new client instance.
  OnMQTTBeforeDestroyClient: POnMQTTBeforeDestroyClient;                 //Optional. This event can be assigned by user code to free memory for every destroyed client instance.

  OnMQTTError: POnMQTTError;                                             //Optional, recommended.
  OnSendMQTT_Packet: POnSend_MQTT_Packet;                                //Required (a handler has to be assigned to it).
  OnMQTTClientRequestsDisconnection: POnMQTTClientRequestsDisconnection; //Required (for protocol only). The library can work without it.

  OnBeforeMQTT_CONNECT: POnBeforeMQTT_CONNECT;                           //Required by MQTT_CONNECT to prepare parameters for CONNECT packet before sending.
  OnAfterMQTT_CONNACK: POnAfterMQTT_CONNACK;                             //Required (the library may need (in the future) info returned by this packet). See Process_CONNACK function.

  OnBeforeSendingMQTT_PUBLISH: POnBeforeSendingMQTT_PUBLISH;             //Required by MQTT_PUBLISH to get parameters for PUBLISH packet before sending.
  OnAfterReceivingMQTT_PUBLISH: POnAfterReceivingMQTT_PUBLISH;           //Required by Process_PUBLISH. This how the library returns the received application message to user code.

  OnBeforeSendingMQTT_PUBACK: POnBeforeSendingMQTT_PUBACK;               //Required by Process_PUBLISH
  OnAfterReceivingMQTT_PUBACK: POnAfterReceivingMQTT_PUBACK;             //Optional.

  OnBeforeSendingMQTT_PUBREC: POnBeforeSendingMQTT_PUBREC;               //Optional.
  OnAfterReceivingMQTT_PUBREC: POnAfterReceivingMQTT_PUBREC;             //Optional.

  OnBeforeSendingMQTT_PUBREL: POnBeforeSendingMQTT_PUBREL;               //Optional.
  OnAfterReceivingMQTT_PUBREL: POnBeforeSendingMQTT_PUBREL;              //Optional.

  OnBeforeSendingMQTT_PUBCOMP: POnBeforeSendingMQTT_PUBCOMP;             //Optional.
  OnAfterReceivingMQTT_PUBCOMP: POnAfterReceivingMQTT_PUBCOMP;           //Optional.

  OnBeforeSendingMQTT_SUBSCRIBE: POnBeforeSendingMQTT_SUBSCRIBE;         //Required by MQTT_SUBSCRIBE, to prepare parameters for SUBSCRIBE packet before sending.
  OnAfterReceivingMQTT_SUBACK: POnAfterReceivingMQTT_SUBACK;             //Required by Process_SUBACK, to get the list of valid subscriptions.

  OnBeforeSendingMQTT_UNSUBSCRIBE: POnBeforeSendingMQTT_UNSUBSCRIBE;     //Required by MQTT_UNSUBSCRIBE, to prepare parameters for UNSUBSCRIBE packet before sending.
  OnAfterReceivingMQTT_UNSUBACK: POnAfterReceivingMQTT_UNSUBACK;         //Required by Process_UNSUBACK, to get the list of valid "un"-subscriptions.

  OnAfterReceivingMQTT_PINGRESP: POnAfterReceivingMQTT_PINGRESP;         //Optional. The handler should be implemented in user code, only if the ping response is useful.

  OnBeforeSendingMQTT_DISCONNECT: POnBeforeSendingMQTT_DISCONNECT;       //Optional.
  OnAfterReceivingMQTT_DISCONNECT: POnAfterReceivingMQTT_DISCONNECT;     //Optional. The handler should be implemented in user code, only if the client has to do some memory clean-up when disconnected by server.

  OnBeforeSendingMQTT_AUTH: POnBeforeSendingMQTT_AUTH;                   //Required by MQTT_AUTH, to prepare parameters for AUTH packet before sending.
  OnAfterReceivingMQTT_AUTH: POnAfterReceivingMQTT_AUTH;                 //Optional. The handler should be implemented in user code, only if the client requires further authentication.

const
  //for codes 0 to 11+, see CMQTTDecoderNoErr from MQTTUtils unit.
  CMQTT_Success = 0;     //The following error codes are 200+, to have a different range, compared to standard MQTT error codes. They fit into a byte.
  CMQTT_BadClientIndex = 201;       //ClientInstance parameter, from main functions, is out of bounds
  CMQTT_UnhandledPacketType = 202;  //The client received a packet that is not supposed to receive (that includes packets which are normally sent from client to server)
  CMQTT_HandlerNotAssigned = 203;   //Mostly for internal use. Some user functions may also use it.
  CMQTT_BadQoS = 204;               //The client received a bad QoS value (i.e. 3). It should disconnect from server. Or, the user code calls Publish with a bad QoS.
  CMQTT_ProtocolError = 205;        //The server sent this in a ReasonCode field
  CMQTT_PacketIdentifierNotFound_ClientToServer = 206;            //The server sent an unknown Packet identifier, so the client responds with this error in a PubComp packet
  CMQTT_PacketIdentifierNotFound_ServerToClient = 207;            //The server sent an unknown Packet identifier (in PubAck, i.e. QoS=1), so the client notifies the user about it. No further response to server is expected.
  CMQTT_NoMorePacketIdentifiersAvailable = 208; //Likely a bad state or a memory leak would lead to this error. Usually, the library should not end up here.
  CMQTT_ReceiveMaximumExceeded = 209; //The user code gets this error when attempting to publish more packets than acknowledged by server. The ReceiveMaximum value is set on connect.
  CMQTT_ReceiveMaximumReset = 210;    //The user code gets this error when too many SubAck (and PubRec) packets are received without being published. This may point to a retransmission case.
  CMQTT_OutOfMemory = 200 + CMQTTDecoderOutOfMemory; //11
  CMQTT_NoMoreSubscriptionIdentifiersAvailable = 212; //Likely a bad state or a memory leak would lead to this error. Usually, the library should not end up here.
  CMQTT_CannotReserveBadSubscriptionIdentifier = 213; //The library cannot preallocate the value 0 (which is a current limitation of DynArrays lib).
  CMQTT_CannotReserveBadPacketIdentifier = 214; //see 213
  CMQTT_PacketIdentifierNotFound_ClientToServerResend = 215;


  //The following values are start values for various identifiers. The allocated identifiers are incremented by the library (if required) on every new allocation.
  CMQTT_ClientToServerPacketIdentifiersInitOffset = 200;  //ClientToServer packet identifiers start at 200.
  CMQTT_ServerToClientPacketIdentifiersInitOffset = 300;  //ServerToClient packet identifiers start at 300.
  CMQTT_ClientToServerSubscriptionIdentifiersInitOffset = 700;


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
  ClientToServerResendBuffer: TDynArrayOfPDynArrayOfTDynArrayOfByte;
  ClientToServerResendPacketIdentifier: TDynArrayOfTDynArrayOfWord;  //for every array of byte in the ClientToServerResendBuffer array, there is one packet identifier
  ServerToClientBuffer: TDynArrayOfTDynArrayOfByte;   //indexed by ClientInstance parameter from main functions
  ServerToClientPacketIdentifiers: TDynArrayOfTDynArrayOfWord;  //used when Servers send Publish.   Used on QoS = 2.  Process_PUBLISH adds items to this array.
  ClientToServerPacketIdentifiers: TDynArrayOfTDynArrayOfWord;  //used when Clients send Publish.
  //ClientToServerUnAckPacketIdentifiers: TDynArrayOfTDynArrayOfByte;  //should be kept in sync with ClientToServerPacketIdentifiers array. Uncomment when implementing retransmission.
  ClientToServerPacketIdentifiersInit: TDynArrayOfWord;  //one word for every Client
  MaximumQoS: TDynArrayOfTDynArrayOfByte; //used when initiating connections.  This keeps track of the requested and server-updated value of QoS. Updated by SubAck. For each client, there might be multiple topics or subscriptions (which can be a QoS or an error code).
  ClientToServerSendQuota: TDynArrayOfWord; //used on Publish, initialized by Connect, updated by Publish and PubAck/PubRec
  ClientToServerReceiveMaximum: TDynArrayOfWord; //used on Publish, initialized by Connect
  //TopicAliases: TDynArrayOfTDynArrayOfWord; //used when initiating connections.   See also TMQTTProp_TopicAliasMaximum type.
  //an array based on TMQTTProp_ReceiveMaximum
  ClientToServerSubscriptionIdentifiers: TDynArrayOfTDynArrayOfWord; //limited to 65534 subscriptions at a time
  ClientToServerSubscriptionIdentifiersInit: TDynArrayOfWord;  //one word for every Client


procedure InitLibStateVars;
begin
  {$IFDEF SingleOutputBuffer}
    InitDynOfDynOfByteToEmpty(ClientToServerBuffer);
  {$ELSE}
    InitDynArrayOfPDynArrayOfTDynArrayOfByteToEmpty(ClientToServerBuffer);
  {$ENDIF}

  InitDynArrayOfPDynArrayOfTDynArrayOfByteToEmpty(ClientToServerResendBuffer);
  InitDynOfDynOfWordToEmpty(ClientToServerResendPacketIdentifier);
  InitDynOfDynOfByteToEmpty(ServerToClientBuffer);
  InitDynOfDynOfWordToEmpty(ServerToClientPacketIdentifiers);
  InitDynOfDynOfWordToEmpty(ClientToServerPacketIdentifiers);
  //InitDynOfDynOfByteToEmpty(ClientToServerUnAckPacketIdentifiers);
  InitDynArrayOfWordToEmpty(ClientToServerPacketIdentifiersInit);
  InitDynArrayOfWordToEmpty(ClientToServerSendQuota);
  InitDynArrayOfWordToEmpty(ClientToServerReceiveMaximum);
  InitDynOfDynOfByteToEmpty(MaximumQoS);
  InitDynOfDynOfWordToEmpty(ClientToServerSubscriptionIdentifiers);
  InitDynArrayOfWordToEmpty(ClientToServerSubscriptionIdentifiersInit);
end;


procedure CleanupLibStateVars;
begin
  {$IFDEF SingleOutputBuffer}
    FreeDynOfDynOfByteArray(ClientToServerBuffer);
  {$ELSE}
    FreeDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerBuffer);
  {$ENDIF}

  FreeDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerResendBuffer);
  FreeDynOfDynOfWordArray(ClientToServerResendPacketIdentifier);
  FreeDynOfDynOfByteArray(ServerToClientBuffer);
  FreeDynOfDynOfWordArray(ServerToClientPacketIdentifiers);
  FreeDynOfDynOfWordArray(ClientToServerPacketIdentifiers);
  //FreeDynOfDynOfByteArray(ClientToServerUnAckPacketIdentifiers);
  FreeDynArrayOfWord(ClientToServerPacketIdentifiersInit);
  FreeDynArrayOfWord(ClientToServerSendQuota);
  FreeDynArrayOfWord(ClientToServerReceiveMaximum);
  FreeDynOfDynOfByteArray(MaximumQoS);
  FreeDynOfDynOfWordArray(ClientToServerSubscriptionIdentifiers);
  FreeDynArrayOfWord(ClientToServerSubscriptionIdentifiersInit);
end;


procedure SetEventsToNil;
begin
  OnMQTTAfterCreateClient := nil;
  OnMQTTBeforeDestroyClient := nil;

  OnMQTTError := nil;
  OnSendMQTT_Packet := nil;

  OnMQTTClientRequestsDisconnection := nil;
  OnBeforeMQTT_CONNECT := nil;
  OnAfterMQTT_CONNACK := nil;
  OnBeforeSendingMQTT_PUBLISH := nil;
  OnAfterReceivingMQTT_PUBLISH := nil;
  OnBeforeSendingMQTT_PUBACK := nil;
  OnAfterReceivingMQTT_PUBACK := nil;
  OnBeforeSendingMQTT_PUBREC := nil;
  OnAfterReceivingMQTT_PUBREC := nil;
  OnBeforeSendingMQTT_PUBREL := nil;
  OnAfterReceivingMQTT_PUBREL := nil;
  OnBeforeSendingMQTT_PUBCOMP := nil;
  OnAfterReceivingMQTT_PUBCOMP := nil;
  OnBeforeSendingMQTT_SUBSCRIBE := nil;
  OnAfterReceivingMQTT_SUBACK := nil;
  OnBeforeSendingMQTT_UNSUBSCRIBE := nil;
  OnAfterReceivingMQTT_UNSUBACK := nil;
  OnAfterReceivingMQTT_PINGRESP := nil;
  OnBeforeSendingMQTT_DISCONNECT := nil;
  OnAfterReceivingMQTT_DISCONNECT := nil;
  OnBeforeSendingMQTT_AUTH := nil;
  OnAfterReceivingMQTT_AUTH := nil;
end;


procedure InitEvents;
begin
  {$IFDEF IsDesktop}
    New(OnMQTTAfterCreateClient);
    New(OnMQTTBeforeDestroyClient);

    New(OnMQTTError);
    New(OnSendMQTT_Packet);
    New(OnMQTTClientRequestsDisconnection);
    New(OnBeforeMQTT_CONNECT);
    New(OnAfterMQTT_CONNACK);
    New(OnBeforeSendingMQTT_PUBLISH);
    New(OnAfterReceivingMQTT_PUBLISH);
    New(OnBeforeSendingMQTT_PUBACK);
    New(OnAfterReceivingMQTT_PUBACK);
    New(OnBeforeSendingMQTT_PUBREC);
    New(OnAfterReceivingMQTT_PUBREC);
    New(OnBeforeSendingMQTT_PUBREL);
    New(OnAfterReceivingMQTT_PUBREL);
    New(OnBeforeSendingMQTT_PUBCOMP);
    New(OnAfterReceivingMQTT_PUBCOMP);
    New(OnBeforeSendingMQTT_SUBSCRIBE);
    New(OnAfterReceivingMQTT_SUBACK);
    New(OnBeforeSendingMQTT_UNSUBSCRIBE);
    New(OnAfterReceivingMQTT_UNSUBACK);
    New(OnAfterReceivingMQTT_PINGRESP);
    New(OnBeforeSendingMQTT_DISCONNECT);
    New(OnAfterReceivingMQTT_DISCONNECT);
    New(OnBeforeSendingMQTT_AUTH);
    New(OnAfterReceivingMQTT_AUTH);

    OnMQTTAfterCreateClient^ := nil;
    OnMQTTBeforeDestroyClient^ := nil;

    OnMQTTError^ := nil;
    OnSendMQTT_Packet^ := nil;

    OnMQTTClientRequestsDisconnection^ := nil;
    OnBeforeMQTT_CONNECT^ := nil;
    OnAfterMQTT_CONNACK^ := nil;
    OnBeforeSendingMQTT_PUBLISH^ := nil;
    OnAfterReceivingMQTT_PUBLISH^ := nil;
    OnBeforeSendingMQTT_PUBACK^ := nil;
    OnAfterReceivingMQTT_PUBACK^ := nil;
    OnBeforeSendingMQTT_PUBREC^ := nil;
    OnAfterReceivingMQTT_PUBREC^ := nil;
    OnBeforeSendingMQTT_PUBREL^ := nil;
    OnAfterReceivingMQTT_PUBREL^ := nil;
    OnBeforeSendingMQTT_PUBCOMP^ := nil;
    OnAfterReceivingMQTT_PUBCOMP^ := nil;
    OnBeforeSendingMQTT_SUBSCRIBE^ := nil;
    OnAfterReceivingMQTT_SUBACK^ := nil;
    OnBeforeSendingMQTT_UNSUBSCRIBE^ := nil;
    OnAfterReceivingMQTT_UNSUBACK^ := nil;
    OnAfterReceivingMQTT_PINGRESP^ := nil;
    OnBeforeSendingMQTT_DISCONNECT^ := nil;
    OnAfterReceivingMQTT_DISCONNECT^ := nil;
    OnBeforeSendingMQTT_AUTH^ := nil;
    OnAfterReceivingMQTT_AUTH^ := nil;
  {$ELSE}
    SetEventsToNil;
  {$ENDIF}
end;


procedure CleanupEvents;
begin
  {$IFDEF IsDesktop}
    Dispose(OnMQTTAfterCreateClient);
    Dispose(OnMQTTBeforeDestroyClient);

    Dispose(OnMQTTError);
    Dispose(OnSendMQTT_Packet);

    Dispose(OnMQTTClientRequestsDisconnection);
    Dispose(OnBeforeMQTT_CONNECT);
    Dispose(OnAfterMQTT_CONNACK);
    Dispose(OnBeforeSendingMQTT_PUBLISH);
    Dispose(OnAfterReceivingMQTT_PUBLISH);
    Dispose(OnBeforeSendingMQTT_PUBACK);
    Dispose(OnAfterReceivingMQTT_PUBACK);
    Dispose(OnBeforeSendingMQTT_PUBREC);
    Dispose(OnAfterReceivingMQTT_PUBREC);
    Dispose(OnBeforeSendingMQTT_PUBREL);
    Dispose(OnAfterReceivingMQTT_PUBREL);
    Dispose(OnBeforeSendingMQTT_PUBCOMP);
    Dispose(OnAfterReceivingMQTT_PUBCOMP);
    Dispose(OnBeforeSendingMQTT_SUBSCRIBE);
    Dispose(OnAfterReceivingMQTT_SUBACK);
    Dispose(OnBeforeSendingMQTT_UNSUBSCRIBE);
    Dispose(OnAfterReceivingMQTT_UNSUBACK);
    Dispose(OnAfterReceivingMQTT_PINGRESP);
    Dispose(OnBeforeSendingMQTT_DISCONNECT);
    Dispose(OnAfterReceivingMQTT_DISCONNECT);
    Dispose(OnBeforeSendingMQTT_AUTH);
    Dispose(OnAfterReceivingMQTT_AUTH);
  {$ENDIF}

  SetEventsToNil;
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


//Required, to tell user code to send the packet, which is currently in bufer.
procedure DoOnSend_MQTT_Packet(ClientInstance: DWord; APacketType: Byte; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnSendMQTT_Packet) or not Assigned(OnSendMQTT_Packet^) then
  {$ELSE}
    if OnSendMQTT_Packet = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnSendMQTT_Packet^(ClientInstance, APacketType);
end;


//Called in case of a protocol error, to notify user application that it should disconnect from server.
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
    if OnBeforeMQTT_CONNECT = nil then
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


procedure DoOnAfterReceiving_MQTT_PUBACK(ClientInstance: DWord; var ATempPubAckFields: TMQTTPubAckFields; var ATempPubAckProperties: TMQTTPubAckProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PUBACK) or not Assigned(OnAfterReceivingMQTT_PUBACK^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PUBACK = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PUBACK^(ClientInstance, ATempPubAckFields, ATempPubAckProperties);
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


procedure DoOnAfterReceiving_MQTT_PUBREC(ClientInstance: DWord; var ATempPubRecFields: TMQTTPubRecFields; var ATempPubRecProperties: TMQTTPubRecProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PUBREC) or not Assigned(OnAfterReceivingMQTT_PUBREC^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PUBREC = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PUBREC^(ClientInstance, ATempPubRecFields, ATempPubRecProperties);
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


procedure DoOnAfterReceiving_MQTT_PUBREL(ClientInstance: DWord; var ATempPubRelFields: TMQTTPubRelFields; var ATempPubRelProperties: TMQTTPubRelProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PUBREL) or not Assigned(OnAfterReceivingMQTT_PUBREL^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PUBREL = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PUBREL^(ClientInstance, ATempPubRelFields, ATempPubRelProperties);
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


procedure DoOnAfterReceiving_MQTT_PUBCOMP(ClientInstance: DWord; var ATempPubCompFields: TMQTTPubCompFields; var ATempPubCompProperties: TMQTTPubCompProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PUBCOMP) or not Assigned(OnAfterReceivingMQTT_PUBCOMP^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PUBCOMP = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PUBCOMP^(ClientInstance, ATempPubCompFields, ATempPubCompProperties);
end;


function DoOnBeforeSending_MQTT_SUBSCRIBE(ClientInstance: DWord; var ATempSubscribeFields: TMQTTSubscribeFields; var ATempSubscribeProperties: TMQTTSubscribeProperties; var AErr: Word; ACallbackID: Word): Boolean;
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_SUBSCRIBE) or not Assigned(OnBeforeSendingMQTT_SUBSCRIBE^) then
  {$ELSE}
    if OnBeforeSendingMQTT_SUBSCRIBE = nil then
  {$ENDIF}
    begin
      Result := False;
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  Result := OnBeforeSendingMQTT_SUBSCRIBE^(ClientInstance, ATempSubscribeFields, ATempSubscribeProperties, ACallbackID);
end;


procedure DoOnAfterReceivingMQTT_SUBACK(ClientInstance: DWord; var ATempSubAckFields: TMQTTSubAckFields; var ATempSubAckProperties: TMQTTSubAckProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_SUBACK) or not Assigned(OnAfterReceivingMQTT_SUBACK^) then
  {$ELSE}
    if OnAfterReceivingMQTT_SUBACK = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_SUBACK^(ClientInstance, ATempSubAckFields, ATempSubAckProperties);
end;


function DoOnBeforeSending_MQTT_UNSUBSCRIBE(ClientInstance: DWord; var ATempUnsubscribeFields: TMQTTUnsubscribeFields; var ATempUnsubscribeProperties: TMQTTUnsubscribeProperties; var AErr: Word; ACallbackID: Word): Boolean;
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_UNSUBSCRIBE) or not Assigned(OnBeforeSendingMQTT_UNSUBSCRIBE^) then
  {$ELSE}
    if OnBeforeSendingMQTT_UNSUBSCRIBE = nil then
  {$ENDIF}
    begin
      Result := False;
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  Result := OnBeforeSendingMQTT_UNSUBSCRIBE^(ClientInstance, ATempUnsubscribeFields, ATempUnsubscribeProperties, ACallbackID);
end;


procedure DoOnAfterReceivingMQTT_UNSUBACK(ClientInstance: DWord; var ATempUnsubAckFields: TMQTTUnsubAckFields; var ATempUnsubAckProperties: TMQTTUnsubAckProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_UNSUBACK) or not Assigned(OnAfterReceivingMQTT_UNSUBACK^) then
  {$ELSE}
    if OnAfterReceivingMQTT_UNSUBACK = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_UNSUBACK^(ClientInstance, ATempUnsubAckFields, ATempUnsubAckProperties);
end;


procedure DoOnAfterReceivingMQTT_PINGRESP(ClientInstance: DWord; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_PINGRESP) or not Assigned(OnAfterReceivingMQTT_PINGRESP^) then
  {$ELSE}
    if OnAfterReceivingMQTT_PINGRESP = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_PINGRESP^(ClientInstance);
end;


procedure DoOnBeforeSending_MQTT_DISCONNECT(ClientInstance: DWord; var ATempDisconnectFields: TMQTTDisconnectFields; var ATempDisconnectProperties: TMQTTDisconnectProperties; var AErr: Word; ACallbackID: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_DISCONNECT) or not Assigned(OnBeforeSendingMQTT_DISCONNECT^) then
  {$ELSE}
    if OnBeforeSendingMQTT_DISCONNECT = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_DISCONNECT^(ClientInstance, ATempDisconnectFields, ATempDisconnectProperties, ACallbackID);
end;


procedure DoOnAfterReceiving_MQTT_DISCONNECT(ClientInstance: DWord; var ATempDisconnectFields: TMQTTDisconnectFields; var ATempDisconnectProperties: TMQTTDisconnectProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_DISCONNECT) or not Assigned(OnAfterReceivingMQTT_DISCONNECT^) then
  {$ELSE}
    if OnAfterReceivingMQTT_DISCONNECT = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_DISCONNECT^(ClientInstance, ATempDisconnectFields, ATempDisconnectProperties);
end;


procedure DoOnBeforeSending_MQTT_AUTH(ClientInstance: DWord; var ATempAuthFields: TMQTTAuthFields; var ATempAuthProperties: TMQTTAuthProperties; var AErr: Word; ACallbackID: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeSendingMQTT_AUTH) or not Assigned(OnBeforeSendingMQTT_AUTH^) then
  {$ELSE}
    if OnBeforeSendingMQTT_AUTH = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnBeforeSendingMQTT_AUTH^(ClientInstance, ATempAuthFields, ATempAuthProperties, ACallbackID);
end;


procedure DoOnAfterReceiving_MQTT_AUTH(ClientInstance: DWord; var ATempAuthFields: TMQTTAuthFields; var ATempAuthProperties: TMQTTAuthProperties; var AErr: Word);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnAfterReceivingMQTT_AUTH) or not Assigned(OnAfterReceivingMQTT_AUTH^) then
  {$ELSE}
    if OnAfterReceivingMQTT_AUTH = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnAfterReceivingMQTT_AUTH^(ClientInstance, ATempAuthFields, ATempAuthProperties);
end;


/////////////////////////////////


//ClientToServer functions
function MQTT_CreateClientToServerPacketIdentifierWithStart(ClientInstance: DWord; AStartAt: Word): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWordWithStart(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, AStartAt);

  //if Result <> $FFFF then
  //  if not AddByteToDynArray(0, ClientToServerUnAckPacketIdentifiers.Content^[TempClientInstance]^) then  //the byte is added at the end of the array, assuming that CreateUniqueWordWithStart does the same
  //  begin
  //    Result := $FFFF;
  //    DoOnMQTTError(ClientInstance, CMQTT_OutOfMemory, CMQTT_UNDEFINED);
  //  end;
end;


function MQTT_CreateClientToServerPacketIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
  InitValue: Word;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  InitValue := ClientToServerPacketIdentifiersInit.Content^[TempClientInstance];

  Result := MQTT_CreateClientToServerPacketIdentifierWithStart(ClientInstance, InitValue);
  Inc(ClientToServerPacketIdentifiersInit.Content^[TempClientInstance]);
end;


function MQTT_GetIndexOfClientToServerPacketIdentifier(ClientInstance: DWord; APacketIdentifier: Word): TDynArrayLengthSig; //returns -1 if not found
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


function MQTT_RemoveClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: Word): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := DeleteItemFromDynArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
  //if Result then
  //  Result := DeleteItemFromDynArray(ClientToServerUnAckPacketIdentifiers.Content^[TempClientInstance]^, AIndex);
end;


function MQTT_ClientToServerPacketIdentifierIsUsed(ClientInstance: DWord; APacketIdentifier: Word): Boolean;
begin
  Result := MQTT_GetIndexOfClientToServerPacketIdentifier(ClientInstance, APacketIdentifier) <> -1;
end;


function MQTT_GetClientToServerPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
begin
  if ClientInstance > ClientToServerPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  Result := ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Len;
end;


function MQTT_GetClientToServerPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of PacketIdentifiers array
begin
  if ClientInstance > ClientToServerPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  if AIndex > ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('AIndex out of bounds: ' + IntToStr(AIndex));
  {$ENDIF}


  Result := ClientToServerPacketIdentifiers.Content^[ClientInstance]^.Content^[AIndex];
end;


{$IFnDEF SingleOutputBuffer}
  function MQTT_RemovePacketFromClientToServerBuffer(ClientInstance: DWord): Boolean;
  begin
    Result := True;
    if ClientToServerBuffer.Len = 0 then
      Exit;

    Result := DeleteItemFromDynOfDynOfByte(ClientToServerBuffer.Content^[ClientInstance and CClientIndexMask]^, 0);
  end;
{$ENDIF}


function MQTT_RemovePacketFromClientToServerResendBufferByIndex(ClientInstance: DWord; AIndex: Word): Boolean;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := DeleteItemFromDynOfDynOfByte(ClientToServerResendBuffer.Content^[TempClientInstance]^, AIndex);
  Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerResendPacketIdentifier.Content^[TempClientInstance]^, AIndex);
end;


//ServerToClient functions
function MQTT_GetServerToClientPacketIdentifiersCount(ClientInstance: DWord): TDynArrayLength;
begin
  if ClientInstance > ServerToClientPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  Result := ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Len;
end;


function MQTT_GetServerToClientPacketIdentifierByIndex(ClientInstance: DWord; AIndex: TDynArrayLength): Word; //returns content of PacketIdentifiers array
begin
  if ClientInstance > ServerToClientPacketIdentifiers.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('ClientInstance out of bounds: ' + IntToStr(ClientInstance));
  {$ENDIF}

  if AIndex > ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Len - 1 then
  {$IFnDEF IsDesktop}
    begin
      Result := 0;
      Exit;
    end;
  {$ELSE}
    raise Exception.Create('AIndex out of bounds: ' + IntToStr(AIndex));
  {$ENDIF}

  Result := ServerToClientPacketIdentifiers.Content^[ClientInstance]^.Content^[AIndex];
end;


function CreateServerToClientPacketIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWordWithStart(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^, CMQTT_ServerToClientPacketIdentifiersInitOffset);

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


//Quota functions
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


function MQTT_GetSendQuota(ClientInstance: DWord): Word;
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := ClientToServerSendQuota.Content^[TempClientInstance];
end;


/////////////////////


//SubscriptionIdentifier functions
function MQTT_CreateClientToServerSubscriptionIdentifierWithStart(ClientInstance: DWord; AStartAt: Word): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  Result := CreateUniqueWordWithStart(ClientToServerSubscriptionIdentifiers.Content^[TempClientInstance]^, AStartAt);
end;


function MQTT_CreateClientToServerSubscriptionIdentifier(ClientInstance: DWord): Word;   // Returns $FFFF if it can't find a new available number to allocate
var
  TempClientInstance: DWord;
  InitValue: Word;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  InitValue := ClientToServerSubscriptionIdentifiersInit.Content^[TempClientInstance];

  Result := MQTT_CreateClientToServerSubscriptionIdentifierWithStart(ClientInstance, InitValue);
  Inc(ClientToServerSubscriptionIdentifiersInit.Content^[TempClientInstance]);
end;


function MQTT_RemoveClientToServerSubscriptionIdentifier(ClientInstance: DWord; AIdentifier: Word): Word; // Returns 0 if sucess or $FFFF if it can't reallocate memory.
var
  TempClientInstance: DWord;
  Index: TDynArrayLengthSig;
begin
  Result := CMQTT_Success;

  TempClientInstance := ClientInstance and CClientIndexMask;
  Index := IndexOfWordInArrayOfWord(ClientToServerSubscriptionIdentifiers.Content^[TempClientInstance]^, AIdentifier);
  if Index = -1 then  //not found
  begin
    Result := $FFFF;
    Exit;
  end;

  if not DeleteItemFromDynArrayOfWord(ClientToServerSubscriptionIdentifiers.Content^[TempClientInstance]^, Index) then
    Result := $FFFF;
end;


/////////////////////////////////

function MQTT_CreateClient: Boolean;  //returns True if successful, or False if it can't allocate memory
var
  NewLen: TDynArrayLength;
begin
  {$IFDEF SingleOutputBuffer}
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ELSE}
    Result := SetDynOfPDynArrayOfTDynArrayOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ENDIF}

  if Result then
  begin
    NewLen := ServerToClientBuffer.Len + 1;

    Result := SetDynOfPDynArrayOfTDynArrayOfByteLength(ClientToServerResendBuffer, NewLen);
    Result := Result and SetDynOfDynOfWordLength(ClientToServerResendPacketIdentifier, NewLen);
    Result := Result and SetDynOfDynOfByteLength(ServerToClientBuffer, NewLen);
    Result := Result and SetDynOfDynOfWordLength(ServerToClientPacketIdentifiers, NewLen);
    Result := Result and SetDynOfDynOfWordLength(ClientToServerPacketIdentifiers, NewLen);
    //Result := Result and SetDynOfDynOfByteLength(ClientToServerUnAckPacketIdentifiers, NewLen);
    Result := Result and SetDynOfWordLength(ClientToServerPacketIdentifiersInit, NewLen);
    Result := Result and SetDynOfWordLength(ClientToServerSendQuota, NewLen);
    Result := Result and SetDynOfWordLength(ClientToServerReceiveMaximum, NewLen);
    Result := Result and SetDynOfDynOfByteLength(MaximumQoS, NewLen);
    Result := Result and SetDynOfDynOfWordLength(ClientToServerSubscriptionIdentifiers, NewLen);
    Result := Result and SetDynOfWordLength(ClientToServerSubscriptionIdentifiersInit, NewLen);

    if MQTT_CreateClientToServerPacketIdentifierWithStart(ClientToServerPacketIdentifiers.Len - 1, 0) <> 0 then
      DoOnMQTTError(ClientToServerSubscriptionIdentifiers.Len - 1, CMQTT_CannotReserveBadPacketIdentifier, 0); //preallocate 0,

    if MQTT_CreateClientToServerSubscriptionIdentifierWithStart(ClientToServerSubscriptionIdentifiers.Len - 1, 0) <> 0 then  //preallocate 0, since this not a valid identifier
      DoOnMQTTError(ClientToServerSubscriptionIdentifiers.Len - 1, CMQTT_CannotReserveBadSubscriptionIdentifier, 0);

    ClientToServerPacketIdentifiersInit.Content^[ClientToServerPacketIdentifiersInit.Len - 1] := CMQTT_ClientToServerPacketIdentifiersInitOffset;
    ClientToServerSubscriptionIdentifiersInit.Content^[ClientToServerSubscriptionIdentifiersInit.Len - 1] := CMQTT_ClientToServerSubscriptionIdentifiersInitOffset;

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

    ClientInstance := ClientInstance and CClientIndexMask;

    Result := DeleteItemFromDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerResendBuffer, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ClientToServerResendPacketIdentifier, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfByte(ServerToClientBuffer, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ServerToClientPacketIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ClientToServerPacketIdentifiers, ClientInstance);
    //Result := Result and DeleteItemFromDynOfDynOfByte(ClientToServerUnAckPacketIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerPacketIdentifiersInit, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerSendQuota, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerReceiveMaximum, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfByte(MaximumQoS, ClientInstance);
    Result := Result and DeleteItemFromDynOfDynOfWord(ClientToServerSubscriptionIdentifiers, ClientInstance);
    Result := Result and DeleteItemFromDynArrayOfWord(ClientToServerSubscriptionIdentifiersInit, ClientInstance);
  end;
end;


function MQTT_GetClientCount: TDynArrayLength;
begin
  Result := ServerToClientBuffer.Len;
end;


{$IFDEF SingleOutputBuffer}
  function MQTT_GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success
{$ELSE}
  function MQTT_GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
{$ENDIF}
begin
  AErr := CMQTT_Success;

  if IsValidClientInstance(ClientInstance) then
    Result := ClientToServerBuffer.Content^[ClientInstance and CClientIndexMask]
  else
  begin
    Result := nil;
    AErr := CMQTT_BadClientIndex;
  end;
end;


function MQTT_GetClientToServerResendBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
begin
  AErr := CMQTT_Success;

  if IsValidClientInstance(ClientInstance) then
    Result := ClientToServerResendBuffer.Content^[ClientInstance and CClientIndexMask]
  else
  begin
    Result := nil;
    AErr := CMQTT_BadClientIndex;
  end;
end;


function MQTT_GetServerToClientBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //AErr is 0 for success
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

function AddMQTTControlPacket_ToBuffer(var ABuffer: TDynArrayOfByte; var ASrcPacket: TMQTTControlPacket): Boolean;
begin
  Result := ConcatDynArrays(ABuffer, ASrcPacket.Header);      //Concats ABuffer with ASrcPacket.<Array>. Places new array in ABuffer.

  if Result then
    Result := ConcatDynArrays(ABuffer, ASrcPacket.VarHeader);

  if Result then
    Result := ConcatDynArrays(ABuffer, ASrcPacket.Payload);
end;


function AddCONNECT_ToBuffer(var ABuffer: TDynArrayOfByte;
                             var AConnectFields: TMQTTConnectFields;
                             var AConnectProperties: TMQTTConnectProperties): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Connect(AConnectFields, AConnectProperties, TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddPUBLISH_ToBuffer(var ABuffer: TDynArrayOfByte;
                             var APublishFields: TMQTTPublishFields;
                             var APublishProperties: TMQTTPublishProperties;
                             AIncludePacketIdentifier: Boolean): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Publish(APublishFields, APublishProperties, TempDestPacket);

  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddPUBResponse_ToBuffer(var ABuffer: TDynArrayOfByte;
                                 var APubRespFields: TMQTTCommonFields;
                                 var APubRespProperties: TMQTTCommonProperties;
                                 APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                                 AIncludePacketIdentifier: Boolean): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Common(APubRespFields, APubRespProperties, APacketType, TempDestPacket);

  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddSUBSCRIBE_ToBuffer(var ABuffer: TDynArrayOfByte;
                               var ASubscribeFields: TMQTTSubscribeFields;
                               var ASubscribeProperties: TMQTTSubscribeProperties): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Subscribe(ASubscribeFields, ASubscribeProperties, TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddUNSUBSCRIBE_ToBuffer(var ABuffer: TDynArrayOfByte;
                                 var AUnsubscribeFields: TMQTTUnsubscribeFields;
                                 var AUnsubscribeProperties: TMQTTUnsubscribeProperties): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Unsubscribe(AUnsubscribeFields, AUnsubscribeProperties, TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddPINGREQ_ToBuffer(var ABuffer: TDynArrayOfByte): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_PingReq(TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddDISCONNECT_ToBuffer(var ABuffer: TDynArrayOfByte;
                                var ADisconnectFields: TMQTTDisconnectFields;
                                var ADisconnectProperties: TMQTTDisconnectProperties): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Disconnect(ADisconnectFields, ADisconnectProperties, TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


function AddAUTH_ToBuffer(var ABuffer: TDynArrayOfByte;
                          var AAuthFields: TMQTTAuthFields;
                          var AAuthProperties: TMQTTAuthProperties): Boolean;
var
  TempDestPacket: TMQTTControlPacket;
begin
  Result := FillIn_Auth(AAuthFields, AAuthProperties, TempDestPacket);
  if Result then
    Result := AddMQTTControlPacket_ToBuffer(ABuffer, TempDestPacket);

  MQTT_FreeControlPacket(TempDestPacket);
end;


/////////////////////////////////


function MQTT_CONNECT_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                 var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // AConnectFields and AConnectProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, AConnectFields, AConnectProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, AConnectFields, AConnectProperties);
  {$ENDIF}
end;


function MQTT_PUBLISH_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                 var APublishFields: TMQTTPublishFields;                    //user code has to fill-in this parameter
                                 var APublishProperties: TMQTTPublishProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // APublishFields and APublishProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddPUBLISH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, APublishFields, APublishProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddPUBLISH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, APublishFields, APublishProperties, False);
  {$ENDIF}

  if (APublishFields.PublishCtrlFlags shr 1) > 0 then  //QoS > 0
    if Result then
    begin
      n := ClientToServerResendBuffer.Content^[TempClientInstance]^.Len;
      Result := SetDynOfDynOfByteLength(ClientToServerResendBuffer.Content^[TempClientInstance]^, n + 1);
      if Result then
        Result := AddPUBLISH_ToBuffer(ClientToServerResendBuffer.Content^[TempClientInstance]^.Content^[n]^, APublishFields, APublishProperties, True);

      if Result then
        Result := AddWordToDynArraysOfWord(ClientToServerResendPacketIdentifier.Content^[TempClientInstance]^, APublishFields.PacketIdentifier);
    end;
end;


function MQTT_PUBResponse_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                     APacketType: Byte; //valid values are CMQTT_PUBACK, CMQTT_PUBREC, CMQTT_PUBREL and CMQTT_PUBCOMP  (other packets are not compatible)
                                     var APubAckFields: TMQTTCommonFields;                    //user code has to fill-in this parameter
                                     var APubAckProperties: TMQTTCommonProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // APubAckFields and APubAckProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddPUBResponse_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, APubAckFields, APubAckProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddPUBResponse_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, APubAckFields, APubAckProperties, APacketType, False);
  {$ENDIF}

  if Result then
    if APacketType and $F0 = CMQTT_PUBREL then
    begin
      n := ClientToServerResendBuffer.Content^[TempClientInstance]^.Len;
      Result := SetDynOfDynOfByteLength(ClientToServerResendBuffer.Content^[TempClientInstance]^, n + 1);
      if Result then
        Result := AddPUBResponse_ToBuffer(ClientToServerResendBuffer.Content^[TempClientInstance]^.Content^[n]^, APubAckFields, APubAckProperties, APacketType, True);

      if Result then
        Result := AddWordToDynArraysOfWord(ClientToServerResendPacketIdentifier.Content^[TempClientInstance]^, APubAckFields.PacketIdentifier);
    end;
end;


function MQTT_SUBSCRIBE_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                   var ASubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
                                   var ASubscribeProperties: TMQTTSubscribeProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // ASubscribeFields and ASubscribeProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, ASubscribeFields, ASubscribeProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
    begin
      Result := AddSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, ASubscribeFields, ASubscribeProperties);

      //The library assumes that the user code calls CreateClientToServerSubscriptionIdentifier in OnBeforeSendingMQTT_SUBSCRIBE handler.
    end;
    {$ENDIF}
end;


function MQTT_UNSUBSCRIBE_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                     var AUnsubscribeFields: TMQTTUnsubscribeFields;                    //user code has to fill-in this parameter
                                     var AUnsubscribeProperties: TMQTTUnsubscribeProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // ASubscribeFields and ASubscribeProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddUNSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, AUnsubscribeFields, AUnsubscribeProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
    begin
      Result := AddUNSUBSCRIBE_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, AUnsubscribeFields, AUnsubscribeProperties);
      //The library assumes that the user code calls RemoveClientToServerSubscriptionIdentifier in OnBeforeSendingMQTT_UNSUBSCRIBE handler.
    end;
  {$ENDIF}
end;


function MQTT_DISCONNECT_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                                    var ADisconnectFields: TMQTTDisconnectFields;                    //user code has to fill-in this parameter
                                    var ADisconnectProperties: TMQTTDisconnectProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // ADisconnectFields and ADisconnectProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddDISCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, ADisconnectFields, ADisconnectProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddDISCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, ADisconnectFields, ADisconnectProperties);
  {$ENDIF}
end;


function MQTT_AUTH_NoCallback(ClientInstance: DWord;  //ClientInstance identifies the client instance (the library is able to implement multiple MQTT clients / device)
                              var AAuthFields: TMQTTAuthFields;                    //user code has to fill-in this parameter
                              var AAuthProperties: TMQTTAuthProperties): Boolean;  //user code has to fill-in this parameter
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  // AAuthFields and AAuthProperties should be initialized by user code

  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddAUTH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, AAuthFields, AAuthProperties);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddAUTH_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, AAuthFields, AAuthProperties);
  {$ENDIF}
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

  Err: Word;
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
      //
    end;

    1 : //  Expected response to server: PUBACK packet           QoS=1 allows duplicates, so PacketIdentifier is not added to ServerToClientPacketIdentifiers array
    begin    //the receiver MUST respond with a PUBACK packet containing the Packet Identifier from the incoming PUBLISH packet, having accepted ownership of the Application Message (spec pag 94)
      InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPublishFields.PacketIdentifier);  //TempPublishFields comes from Decode_Publish above
      DoOnBeforeSending_MQTT_PUBACK(ClientInstance, RespPubFields, RespPubProperties, Err);

      if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBACK, RespPubFields, RespPubProperties) then
      begin
        MQTT_FreeCommonProperties(RespPubProperties);
        DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PUBACK, Result);    //mandatory
      end
      else
        Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server
    end;

    2 : //  Expected response to server: PUBREC packet
    begin
      InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPublishFields.PacketIdentifier);   //TempPublishFields comes from Decode_Publish above

      if GetIndexOfServerToClientPacketIdentifier(ClientInstance, TempPublishFields.PacketIdentifier) = -1 then
        DoOnBeforeSending_MQTT_PUBREC(ClientInstance, RespPubFields, RespPubProperties, Err);   //calling user code is done regardless of responding with error code, but should not be called as duplicate message

      if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBREC, RespPubFields, RespPubProperties) then
      begin
        MQTT_FreeCommonProperties(RespPubProperties);
        //if CreateServerToClientPacketIdentifier(ClientInstance) = $FFFF then  /////////// Do not use CreateServerToClientPacketIdentifier, because the existing value has to be added.
        if not AddWordToDynArraysOfWord(ServerToClientPacketIdentifiers.Content^[TempClientInstance]^, RespPubFields.PacketIdentifier) then //a new item is aded to PacketIdentifiers array
          Result := CMQTT_OutOfMemory;    //probably nothing gets sent to server  .  It is possible that $FFFF is returned as array full, but it's unlikely.

        if Result = CMQTT_Success then
          DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PUBREC, Result);    //mandatory
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
  PacketIdentifierIdx, PacketIdentifierIdxInResend: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempCommonFields: TMQTTCommonFields;
  TempCommonProperties: TMQTTCommonProperties;
  Err: Word;
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

    if PacketIdentifierIdx = -1 then    // $CE = 206    (maybe the PacketIdentifier got removed by Process_PUBREC
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServer, APacketType) //calling the event with APacketType, because this is Process_PUBACK_OR_PUBCOMP
    else
    begin
      //PacketIdentifierIdxInResend is set here, because TempCommonFields can be altered in user code, from DoOnAfterReceiving_MQTT_*.
      PacketIdentifierIdxInResend := IndexOfWordInArrayOfWord(ClientToServerResendPacketIdentifier.Content^[TempClientInstance]^, TempCommonFields.PacketIdentifier);

      if not IncrementSendQuota(ClientInstance) then
      begin
        DoOnMQTTError(TempClientInstance, CMQTT_ReceiveMaximumReset, APacketType);   //too many acknowledgements
        Result := CMQTT_ReceiveMaximumReset;
      end
      else
      begin
        Err := CMQTT_Success;
        if APacketType = CMQTT_PUBACK then
          DoOnAfterReceiving_MQTT_PUBACK(ClientInstance, TempCommonFields, TempCommonProperties, Err) //If Err is not used to set Result, then no handler is mandatory.
        else
          if APacketType = CMQTT_PUBCOMP then
            DoOnAfterReceiving_MQTT_PUBCOMP(ClientInstance, TempCommonFields, TempCommonProperties, Err); //Not mandatory
      end;

      MQTT_RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx);

      if PacketIdentifierIdxInResend <> -1 then
      begin
        if not MQTT_RemovePacketFromClientToServerResendBufferByIndex(ClientInstance, PacketIdentifierIdxInResend) then
          Result := CMQTT_OutOfMemory;
      end
      else
        DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServerResend, APacketType) //calling the event with APacketType, because this is Process_PUBACK_OR_PUBCOMP
    end;  //PacketIdentifierIdx <> -1
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
  PacketIdentifierIdxInResend: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempPubRecFields: TMQTTPubRecFields;
  TempPubRecProperties: TMQTTPubRecProperties;
  RespPubFields: TMQTTCommonFields;
  RespPubProperties: TMQTTCommonProperties;
  Err: Word;
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
      DoOnMQTTError(TempClientInstance, CMQTT_ProtocolError or TempPubRecFields.ReasonCode shl 8, CMQTT_PUBREC);   //not sure what to do here. Disconnect?

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, TempPubRecFields.PacketIdentifier);
    //If the server sends a wrong Packet Identifier, respond with some error code.////////////////////////////////////

    Err := CMQTT_Success;
    DoOnAfterReceiving_MQTT_PUBREC(ClientInstance, TempPubRecFields, TempPubRecProperties, Err); //Not mandatory

    // respond with PUBREL to server
    InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPubRecFields.PacketIdentifier);

    if PacketIdentifierIdx = -1 then
    begin
      RespPubFields.ReasonCode := CMQTT_Reason_PacketIdentifierNotFound;
      RespPubFields.IncludeReasonCode := 1;
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServer, CMQTT_PUBREC); //calling the event with CMQTT_PUBREC, because this is Process_PUBREC
    end;

    DoOnBeforeSending_MQTT_PUBREL(ClientInstance, RespPubFields, RespPubProperties, Err);

    if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBREL or 2, RespPubFields, RespPubProperties) then
    begin
      MQTT_FreeCommonProperties(RespPubProperties);
      // The PacketIdentifier is removed here, not in MQTT_PUBResponse_NoCallback, because its index is already available here.
      if PacketIdentifierIdx <> -1 then
      begin
        //PacketIdentifierIdxInResend is set here, because TempCommonFields can be altered in user code, from DoOnAfterReceiving_MQTT_*.
        PacketIdentifierIdxInResend := IndexOfWordInArrayOfWord(ClientToServerResendPacketIdentifier.Content^[TempClientInstance]^, TempPubRecFields.PacketIdentifier);

        if TempPubRecFields.ReasonCode >= 128 then  //Verify response error for PUBREC only !!! Other packets should not have this check.
          if not IncrementSendQuota(ClientInstance) then
            DoOnMQTTError(TempClientInstance, CMQTT_ReceiveMaximumReset, CMQTT_PUBREC);   //too many acknowledgements

        //The spec says that the PacketIdentifier should be removed on receiving PUBREC, but it is still required in PUBCOMP.
        //Since the following code is commented, if no PUBCOMP is received, this will result in a memory leak.
        //When the client instance is destroyed, the allocated memory is released, so no leak occurs.

        //if not RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
        //  Result := CMQTT_OutOfMemory;

        if Result = CMQTT_Success then
          DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PUBREL, Result);    //mandatory

        if PacketIdentifierIdxInResend <> -1 then
        begin
          if not MQTT_RemovePacketFromClientToServerResendBufferByIndex(ClientInstance, PacketIdentifierIdxInResend) then
            Result := CMQTT_OutOfMemory;
        end
        else
          DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ClientToServerResend, CMQTT_PUBREC);

      end; //PacketIdentifierIdx <> -1
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
  Err: Word;
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

    Err := CMQTT_Success;
    DoOnAfterReceiving_MQTT_PUBREL(ClientInstance, TempPubRelFields, TempPubRelProperties, Err); //Not mandatory

    // respond with PUBCOMP to server
    InitRespPubFieldsAndProperties(RespPubFields, RespPubProperties, TempPubRelFields.PacketIdentifier);

    if PacketIdentifierIdx = -1 then
    begin
      RespPubFields.ReasonCode := CMQTT_Reason_PacketIdentifierNotFound;
      RespPubFields.IncludeReasonCode := 1;
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ServerToClient, CMQTT_PUBREL); //calling the event with CMQTT_PUBREL, because this is Process_PUBREL
    end;

    DoOnBeforeSending_MQTT_PUBCOMP(ClientInstance, RespPubFields, RespPubProperties, Err);

    if Result = CMQTT_Success then
      if MQTT_PUBResponse_NoCallback(ClientInstance, CMQTT_PUBCOMP, RespPubFields, RespPubProperties) then
      begin
        MQTT_FreeCommonProperties(RespPubProperties);
        // The PacketIdentifier is removed here, not in MQTT_PUBResponse_NoCallback, because its index is already available here.
        if PacketIdentifierIdx <> -1 then
        begin
          if not RemoveServerToClientPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
            Result := CMQTT_OutOfMemory;

          DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PUBCOMP, Result);
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


//This is a response from server, after the client has sent a PubRel.
//Used in ClientToServer scenario (QoS=2).
function Process_PUBCOMP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := Process_PUBACK_OR_PUBCOMP(ClientInstance, ABuffer, ASizeToFree, CMQTT_PUBCOMP);
end;


function Process_SUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  PacketIdentifierIdx: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempSubAckFields: TMQTTSubAckFields;
  TempSubAckProperties: TMQTTSubAckProperties;

  //s, msg: string;
  //i: Integer;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;

  //msg := '';
  //s := DynArrayOfByteToString(ABuffer);
  //for i := 1 to Length(s) do
  //  msg := msg + '$' + IntToHex(Ord(s[i])) + ', ';
  //raise Exception.Create('Received SUBACK buffer: ' + msg);
  //MessageBox(0, PChar(msg), 'msg', MB_ICONINFORMATION);
                                     //ABuffer example: $90, $06, $00, $01, $00, $02, $02, $02,
                                     //ABuffer example: $90, $07, $00, $01, $00, $02, $02, $01, $00  ($90=SUBACK, $07=NumberOfNextBytes, $00, $01 = PacketIdentifier (word), $00 = SUBACK Properties Len(No Reason String, No user prop),  $02, $02, $01, $00 = QoS[0], QoS[1], QoS[2], QoS[3]
  Result := Decode_SubAckToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitCommonProperties(TempSubAckProperties);
    InitDynArrayToEmpty(TempSubAckFields.SrcPayload);
    Result := Decode_SubAck(TempReceivedPacket, TempSubAckFields, TempSubAckProperties);
    if Result <> CMQTTDecoderNoErr then
    begin
      DoOnMQTTError(TempClientInstance, Result, CMQTT_SUBACK);
      Exit;
    end;

    DoOnAfterReceivingMQTT_SUBACK(ClientInstance, TempSubAckFields, TempSubAckProperties, Result);
    if Result <> CMQTTDecoderNoErr then
    begin
      DoOnMQTTError(TempClientInstance, Result, CMQTT_SUBACK);
      Exit;
    end;

    if Result <> CMQTTDecoderNoErr then
    MQTT_FreeControlPacket(TempReceivedPacket);

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, TempSubAckFields.PacketIdentifier);
    if PacketIdentifierIdx = -1 then
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ServerToClient, CMQTT_SUBACK)
    else
      if not MQTT_RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
        DoOnMQTTError(TempClientInstance, CMQTT_OutOfMemory, CMQTT_SUBACK);

    FreeDynArray(TempSubAckFields.SrcPayload);
    MQTT_FreeCommonProperties(TempSubAckProperties);
  end;
end;


function Process_UNSUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  PacketIdentifierIdx: TDynArrayLengthSig;
  TempClientInstance: DWord;

  TempUnsubAckFields: TMQTTUnsubAckFields;
  TempUnsubAckProperties: TMQTTUnsubAckProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);
  TempClientInstance := ClientInstance and CClientIndexMask;

  Result := Decode_UnsubAckToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitCommonProperties(TempUnsubAckProperties);
    InitDynArrayToEmpty(TempUnsubAckFields.SrcPayload);
    Result := Decode_UnsubAck(TempReceivedPacket, TempUnsubAckFields, TempUnsubAckProperties);
    if Result <> CMQTTDecoderNoErr then
    begin
      DoOnMQTTError(TempClientInstance, Result, CMQTT_UNSUBACK);
      Exit;
    end;

    DoOnAfterReceivingMQTT_UNSUBACK(ClientInstance, TempUnsubAckFields, TempUnsubAckProperties, Result);
    if Result <> CMQTTDecoderNoErr then
    begin
      DoOnMQTTError(TempClientInstance, Result, CMQTT_UNSUBACK);
      Exit;
    end;

    MQTT_FreeControlPacket(TempReceivedPacket);

    PacketIdentifierIdx := IndexOfWordInArrayOfWord(ClientToServerPacketIdentifiers.Content^[TempClientInstance]^, TempUnsubAckFields.PacketIdentifier);
    if PacketIdentifierIdx = -1 then
      DoOnMQTTError(TempClientInstance, CMQTT_PacketIdentifierNotFound_ServerToClient, CMQTT_UNSUBACK)
    else
      if not MQTT_RemoveClientToServerPacketIdentifierByIndex(ClientInstance, PacketIdentifierIdx) then
        DoOnMQTTError(TempClientInstance, CMQTT_OutOfMemory, CMQTT_UNSUBACK);

    FreeDynArray(TempUnsubAckFields.SrcPayload);
    MQTT_FreeCommonProperties(TempUnsubAckProperties);
  end;
end;


function Process_PINGRESP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  Err: Word;
begin
  Err := CMQTT_Success;
  MQTT_InitControlPacket(TempReceivedPacket);

  Result := Decode_PingRespToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
    DoOnAfterReceivingMQTT_PINGRESP(ClientInstance, Err);
end;


function Process_DISCONNECT(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  Err: Word;

  TempDisconnectFields: TMQTTDisconnectFields;
  TempDisconnectProperties: TMQTTDisconnectProperties;
begin
  Err := CMQTT_Success;
  MQTT_InitControlPacket(TempReceivedPacket);

  Result := Decode_DisconnectToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitDisconnectProperties(TempDisconnectProperties);
    Result := Decode_Disconnect(TempReceivedPacket, TempDisconnectFields, TempDisconnectProperties);

    DoOnAfterReceiving_MQTT_DISCONNECT(ClientInstance, TempDisconnectFields, TempDisconnectProperties, Err);

    MQTT_FreeControlPacket(TempReceivedPacket);
    MQTT_FreeDisconnectProperties(TempDisconnectProperties);
  end;
end;


function Process_AUTH(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  Err: Word;

  TempAuthFields: TMQTTAuthFields;
  TempAuthProperties: TMQTTAuthProperties;
begin
  Err := CMQTT_Success;
  MQTT_InitControlPacket(TempReceivedPacket);

  Result := Decode_AuthToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitAuthProperties(TempAuthProperties);
    Result := Decode_Auth(TempReceivedPacket, TempAuthFields, TempAuthProperties);

    DoOnAfterReceiving_MQTT_AUTH(ClientInstance, TempAuthFields, TempAuthProperties, Err);

    MQTT_FreeControlPacket(TempReceivedPacket);
    MQTT_FreeAuthProperties(TempAuthProperties);
  end;
end;


type
  TMQTTProcessPacket = function(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
  PMQTTProcessPacket = ^TMQTTProcessPacket;


const
  {$IFDEF IsDesktop}
  CPacketProcessor: array[0..15] of TMQTTProcessPacket = (
  {$ELSE}
  CPacketProcessor: array[0..15] of PMQTTProcessPacket = (
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
  {$ENDIF}
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


function MQTT_PutReceivedBufferToMQTTLib(ClientInstance: DWord; var ABuffer: TDynArrayOfByte): Boolean;
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

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_CONNECT, Err);    //mandatory
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
    NewPacketIdentifier := MQTT_CreateClientToServerPacketIdentifier(ClientInstance);
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
    NewPacketIdentifier := CMQTT_ClientToServerPacketIdentifiersInitOffset; //just set a default, but do not add it to the array of identifiers

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
      IndexOfNewPacketIdentifier := MQTT_GetIndexOfClientToServerPacketIdentifier(ClientInstance, NewPacketIdentifier);
      if IndexOfNewPacketIdentifier > -1 then
        if not MQTT_RemoveClientToServerPacketIdentifierByIndex(ClientInstance, IndexOfNewPacketIdentifier) then
        begin
          DoOnMQTTError(ClientInstance, CMQTT_OutOfMemory, CMQTT_UNDEFINED);  //
          Result := False;
          Exit;
        end;
    end;

    if NewQoS > 0 then
    begin
      NewPacketIdentifier := MQTT_CreateClientToServerPacketIdentifier(ClientInstance);    //This also allocates an UnAck flag, which can be reset later from PubAck (for QoS=1) or PubRec (for QoS=2) packet. See ClientToServerUnAckPacketIdentifiers array.
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

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PUBLISH, Err);    //mandatory
end;


function MQTT_SUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;
var
  TempSubscribeFields: TMQTTSubscribeFields;                    //user code has to fill-in this parameter
  TempSubscribeProperties: TMQTTSubscribeProperties;
  Err: Word;
  NewPacketIdentifier: Word;
begin
  Result := True;

  //MQTT_SUBSCRIBE uses both packet identifier and subscription identifier. Do not mix those two!!!

  // SubscriptionIdentifier can be a DWord, while a PacketIdentifier is a word only.

  //From spec: "A Packet Identifier cannot be used by more than one command at any time." - spec, pag 24.
  //This means that CreateClientToServerPacketIdentifier should be used to allocate a new Packet identifier.

  NewPacketIdentifier := MQTT_CreateClientToServerPacketIdentifier(ClientInstance);
  if NewPacketIdentifier = $FFFF then
  begin
    DoOnMQTTError(ClientInstance, CMQTT_NoMorePacketIdentifiersAvailable, CMQTT_SUBSCRIBE);  //
    Result := False;
    Exit;
  end;

  InitDynArrayToEmpty(TempSubscribeFields.TopicFilters);
  TempSubscribeFields.PacketIdentifier := NewPacketIdentifier;
  TempSubscribeFields.EnabledProperties := 0;
  MQTT_InitSubscribeProperties(TempSubscribeProperties);

  Err := CMQTT_Success;
  Result := DoOnBeforeSending_MQTT_SUBSCRIBE(ClientInstance, TempSubscribeFields, TempSubscribeProperties, Err, ACallbackID);

  if not Result then
  begin
    DoOnMQTTError(ClientInstance, Err, CMQTT_SUBSCRIBE);
    Exit;
  end;

  Result := Err = CMQTT_Success;

  if Result then
    Result := MQTT_SUBSCRIBE_NoCallback(ClientInstance, TempSubscribeFields, TempSubscribeProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_SUBSCRIBE);

  FreeDynArray(TempSubscribeFields.TopicFilters);
  MQTT_FreeSubscribeProperties(TempSubscribeProperties);

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_SUBSCRIBE, Err);    //mandatory
end;


function MQTT_UNSUBSCRIBE(ClientInstance: DWord; ACallbackID: Word): Boolean;
var
  TempUnsubscribeFields: TMQTTUnsubscribeFields;                    //user code has to fill-in this parameter
  TempUnsubscribeProperties: TMQTTUnsubscribeProperties;
  Err: Word;
  NewPacketIdentifier: Word;
begin
  Result := True;

  //MQTT_UNSUBSCRIBE uses both packet identifier and subscription identifier. Do not mix those two!!!

  // SubscriptionIdentifier can be a DWord, while a PacketIdentifier is a word only.

  //From spec: "A Packet Identifier cannot be used by more than one command at any time." - spec, pag 24.

  NewPacketIdentifier := MQTT_CreateClientToServerPacketIdentifier(ClientInstance); //////////////////////////////////////////  make sure it is removed on ACK
  if NewPacketIdentifier = $FFFF then
  begin
    DoOnMQTTError(ClientInstance, CMQTT_NoMorePacketIdentifiersAvailable, CMQTT_SUBSCRIBE);  //
    Result := False;
    Exit;
  end;

  InitDynArrayToEmpty(TempUnsubscribeFields.TopicFilters);
  TempUnsubscribeFields.PacketIdentifier := NewPacketIdentifier;
  TempUnsubscribeFields.EnabledProperties := 0;
  MQTT_InitUnsubscribeProperties(TempUnsubscribeProperties);

  Err := CMQTT_Success;
  Result := DoOnBeforeSending_MQTT_UNSUBSCRIBE(ClientInstance, TempUnsubscribeFields, TempUnsubscribeProperties, Err, ACallbackID);

  if not Result then
  begin
    DoOnMQTTError(ClientInstance, Err, CMQTT_SUBSCRIBE);
    Exit;
  end;

  Result := Err = CMQTT_Success;

  if Result then
    Result := MQTT_UNSUBSCRIBE_NoCallback(ClientInstance, TempUnsubscribeFields, TempUnsubscribeProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_UNSUBSCRIBE);

  FreeDynArray(TempUnsubscribeFields.TopicFilters);
  MQTT_FreeUnsubscribeProperties(TempUnsubscribeProperties);

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_UNSUBSCRIBE, Err);    //mandatory
end;


function MQTT_PINGREQ(ClientInstance: DWord): Boolean;
var
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
  Err: Word;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  {$IFDEF SingleOutputBuffer}
    Result := AddPINGREQ_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^);
  {$ELSE}
    n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
    if Result then
      Result := AddPINGREQ_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^);
  {$ENDIF}

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_PINGREQ, Err);    //mandatory
end;


function MQTT_DISCONNECT(ClientInstance: DWord; ACallbackID: Word): Boolean;
var
  TempDisconnectFields: TMQTTDisconnectFields;                    //user code has to fill-in this parameter
  TempDisconnectProperties: TMQTTDisconnectProperties;
  Err: Word;
begin
  TempDisconnectFields.DisconnectReasonCode := 0;
  TempDisconnectFields.EnabledProperties := 0;

  MQTT_InitDisconnectProperties(TempDisconnectProperties);

  Err := CMQTT_Success;
  DoOnBeforeSending_MQTT_DISCONNECT(ClientInstance, TempDisconnectFields, TempDisconnectProperties, Err, ACallbackID);

  Result := MQTT_DISCONNECT_NoCallback(ClientInstance, TempDisconnectFields, TempDisconnectProperties);
  MQTT_FreeDisconnectProperties(TempDisconnectProperties);

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_DISCONNECT, Err);    //mandatory
end;


function MQTT_AUTH(ClientInstance: DWord; ACallbackID: Word): Boolean;
var
  TempAuthFields: TMQTTAuthFields;                    //user code has to fill-in this parameter
  TempAuthProperties: TMQTTAuthProperties;
  Err: Word;
begin
  Result := True;

  TempAuthFields.AuthReasonCode := 0;
  TempAuthFields.EnabledProperties := 0;

  MQTT_InitAuthProperties(TempAuthProperties);

  Err := CMQTT_Success;
  DoOnBeforeSending_MQTT_AUTH(ClientInstance, TempAuthFields, TempAuthProperties, Err, ACallbackID);

  Result := Err = CMQTT_Success;

  if Result then
    Result := MQTT_AUTH_NoCallback(ClientInstance, TempAuthFields, TempAuthProperties)
  else
    DoOnMQTTError(ClientInstance, Err, CMQTT_AUTH);

  MQTT_FreeAuthProperties(TempAuthProperties);

  if Result then
    DoOnSend_MQTT_Packet(ClientInstance, CMQTT_AUTH, Err);    //mandatory
end;


function MQTT_ResendUnacknowledged(ClientInstance: DWord): Boolean;
var
  i, ResendBuffItemCountM1: TDynArrayLengthSig;
  TempClientInstance: DWord;
  TempArr: TDynArrayOfByte;
  ResendBufferPointer: PDynArrayOfByte;
  Err: Word;
begin
  TempClientInstance := ClientInstance and CClientIndexMask;
  ResendBuffItemCountM1 := ClientToServerResendBuffer.Content^[TempClientInstance]^.Len - 1;
  Result := True;

  for i := 0 to ResendBuffItemCountM1 do
  begin
    InitDynArrayToEmpty(TempArr);
    ResendBufferPointer := ClientToServerResendBuffer.Content^[TempClientInstance]^.Content^[i];
    CopyFromDynArray(TempArr, ResendBufferPointer^, 0, ResendBufferPointer^.Len);

    {$IFDEF SingleOutputBuffer}
      Result := ConcatDynArrays(ClientToServerBuffer.Content^[TempClientInstance]^, TempArr);
    {$ELSE}
      //n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
      //Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
      if Result then
        Result := AddDynArrayOfByteToDynOfDynOfByte(ClientToServerBuffer.Content^[TempClientInstance]^, TempArr);
    {$ENDIF}

    if Result then
      if TempArr.Len > 0 then
      begin
        DoOnSend_MQTT_Packet(ClientInstance, TempArr.Content^[0], Err);  //Publish or PubRel
        Result := Err = CMQTT_Success;      //it is fine to return the result from the last iteration
      end;

    FreeDynArray(TempArr);
  end;

  for i := 0 to ResendBuffItemCountM1 do
    MQTT_RemovePacketFromClientToServerResendBufferByIndex(TempClientInstance, 0);
end;

end.