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
  MQTTConnectCtrl, MQTTConnAckCtrl, MQTTPublishCtrl;

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

  TOnMQTTError = procedure(ClientInstance: DWord; AErr: Word; APacketType: Byte);
  POnMQTTError = ^TOnMQTTError;

  TOnBeforeMQTT_CONNECT = function(ClientInstance: DWord;  //The lower word identifies the client instance (the library is able to implement multiple MQTT clients / device). The higher byte can identify the call in user handlers for various events (e.g. TOnBeforeMQTT_CONNECT).
                                   var AConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
                                   var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code has to fill-in this parameter
  POnBeforeMQTT_CONNECT = ^TOnBeforeMQTT_CONNECT;

  TOnAfterMQTT_CONNACK = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                   var AConnAckFields: TMQTTConnAckFields;
                                   var AConnAckProperties: TMQTTConnAckProperties;
                                   AErr: Word
                                   );
  POnAfterMQTT_CONNACK = ^TOnAfterMQTT_CONNACK;

  TOnAfterReceivingMQTT_PUBLISH = procedure(ClientInstance: DWord;  //The lower word identifies the client instance
                                            var APublishFields: TMQTTPublishFields;
                                            var APublishProperties: TMQTTPublishProperties);
  POnAfterReceivingMQTT_PUBLISH = ^TOnAfterReceivingMQTT_PUBLISH;

procedure MQTT_Init; //Initializes library vars   (call this before any other library function)
procedure MQTT_Done; //Frees library vars  (after this call, none of the library functions should be called)
function MQTT_CreateClient: Boolean;
function MQTT_DestroyClient(ClientInstance: DWord): Boolean;
function MQTT_GetClientCount: TDynArrayLength; //Can be used in for loops, which iterate ClientInstance, from 0 to MQTT_GetClientCount - 1.

{$IFDEF SingleOutputBuffer}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success
{$ELSE}
  function GetClientToServerBuffer(ClientInstance: DWord; var AErr: Word): PMQTTMultiBuffer;  //Err is 0 for success
{$ENDIF}
function GetServerToClientBuffer(ClientInstance: DWord; var AErr: Word): PMQTTBuffer;  //Err is 0 for success

function MQTT_Process(ClientInstance: DWord): Word; //Should be called in the main loop (not necessarily at every iteration), to do packet processing and trigger events. It should be called for every client. If it returns OutOfMemory, then the application has to be adjusted to call MQTT_Process more often and/or reserve more heap memory for MQTT library.
function PutReceivedBufferToMQTTLib(ClientInstance: DWord; var ABuffer: TDynArrayOfByte): Boolean; //Should be called by user code, after receiving data from server. When a valid packet is formed, the MQTT library will process it and call the decoded event.

{$IFnDEF SingleOutputBuffer}
  function RemovePacketFromClientToServerBuffer(ClientInstance: DWord): Boolean;
{$ENDIF}

//In the following (main) functions, the lower word of the ClientInstance parameter identifies the client instance (the library is able to implement multiple MQTT clients / device)
function MQTT_CONNECT_NoCallback(ClientInstance: DWord;
                                 var AConnectFields: TMQTTConnectFields;                    //user code should initialize and fill-in this parameter
                                 var AConnectProperties: TMQTTConnectProperties): Boolean;  //user code should initialize and fill-in this parameter

function MQTT_CONNECT(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance

function MQTT_PUBACK(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance ////////// should be documented as not to be called by user code (unless there is a use for it). It is public, for testing purposes only.
function MQTT_PUBREC(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance ////////// should be documented as not to be called by user code (unless there is a use for it). It is public, for testing purposes only.

////////////////////////////////////////////////////////// Multiple functions require calls to Free, both in happy flow and error cases.
////////////////////////////////////////////////////////// all decoder functions (e.g. Decode_ConnAckToCtrlPacket) should return the decoded length. Not sure how to compute in case of an error. Probably, it' what the protocol spec says, to disconnect.
////////////////////////////////////////////////////////// all decoder functions should not compute lengths based on ActualVarAndPayloadLen, because ActualVarAndPayloadLen depends on initial buffer, which may contain multiple packets


var
  OnMQTTError: POnMQTTError;
  OnBeforeMQTT_CONNECT: POnBeforeMQTT_CONNECT;
  OnAfterMQTT_CONNACK: POnAfterMQTT_CONNACK;
  OnAfterReceivingMQTT_PUBLISH: POnAfterReceivingMQTT_PUBLISH;

const
  CMQTT_Success = 0;
  CMQTT_BadClientIndex = 1;       //ClientInstance parameter, from main functions, is out of bounds
  CMQTT_UnhandledPacketType = 2;  //The client received a packet that is not supposed to receive (that includes packets which are normally sent from client to server)
  CMQTT_HandlerNotAssigned = 3;   //Mostly for internal use. Some user functions may also use it.
  CMQTT_BadQoS = 4;               //The client received a bad QoS value (i.e. 3). It should disconnect from server.

implementation


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


procedure MQTT_Init; //Init library vars
begin
  {$IFDEF SingleOutputBuffer}
    InitDynOfDynOfByteToEmpty(ClientToServerBuffer);
  {$ELSE}
    InitDynArrayOfPDynArrayOfTDynArrayOfByteToEmpty(ClientToServerBuffer);
  {$ENDIF}
  InitDynOfDynOfByteToEmpty(ServerToClientBuffer);

  {$IFDEF IsDesktop}
    New(OnMQTTError);
    New(OnBeforeMQTT_CONNECT);
    New(OnAfterMQTT_CONNACK);
    New(OnAfterReceivingMQTT_PUBLISH);
  {$ENDIF}

  OnMQTTError^ := nil;
  OnBeforeMQTT_CONNECT^ := nil;
  OnAfterMQTT_CONNACK^ := nil;
  OnAfterReceivingMQTT_PUBLISH^ := nil;
end;


procedure MQTT_Done; //Frees library vars
begin
  {$IFDEF IsDesktop}
    Dispose(OnMQTTError);
    Dispose(OnBeforeMQTT_CONNECT);
    Dispose(OnAfterMQTT_CONNACK);
    Dispose(OnAfterReceivingMQTT_PUBLISH);
  {$ENDIF}

  {$IFDEF SingleOutputBuffer}
    FreeDynOfDynOfByteArray(ClientToServerBuffer);
  {$ELSE}
    FreeDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerBuffer);
  {$ENDIF}
  FreeDynOfDynOfByteArray(ServerToClientBuffer);
end;


function IsValidClientInstance(ClientInstance: DWord): Boolean;
begin
  ClientInstance := ClientInstance and CClientIndexMask;
  Result := (ClientToServerBuffer.Len > 0) and (ClientInstance < ClientToServerBuffer.Len);
  //ClientToServerBuffer should have the same length as ServerToClientBuffer. They may get out of sync in case of an OutOfMemory error.
end;


function MQTT_CreateClient: Boolean;
begin
  {$IFDEF SingleOutputBuffer}
    Result := SetDynOfDynOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ELSE}
    Result := SetDynOfPDynArrayOfTDynArrayOfByteLength(ClientToServerBuffer, ClientToServerBuffer.Len + 1);
  {$ENDIF}

  if Result then
    Result := SetDynOfDynOfByteLength(ServerToClientBuffer, ServerToClientBuffer.Len + 1);
end;


function MQTT_DestroyClient(ClientInstance: DWord): Boolean;
begin
  Result := IsValidClientInstance(ClientInstance);
  if not Result then
    Exit;

  {$IFDEF SingleOutputBuffer}
    Result := DeleteItemFromDynOfDynOfByte(ClientToServerBuffer, ClientInstance);
  {$ELSE}
    Result := DeleteItemFromDynArrayOfPDynArrayOfTDynArrayOfByte(ClientToServerBuffer, ClientInstance);
  {$ENDIF}

  if Result then     //There is some internal reallocation while deleting, so it is possible that Result would be False, in case of an OutOfMemory error.
    Result := DeleteItemFromDynOfDynOfByte(ServerToClientBuffer, ClientInstance);
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


procedure DoOnMQTTError(ClientInstance: DWord; AErr: Word; APacketType: Byte);
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnMQTTError) or not Assigned(OnMQTTError^) then
  {$ELSE}
    if OnMQTTError = nil then
  {$ENDIF}
    begin
      AErr := CMQTT_HandlerNotAssigned;
      Exit;
    end;

  OnMQTTError^(ClientInstance, AErr, APacketType);
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

  OnAfterMQTT_CONNACK^(ClientInstance, AConnAckFields, AConnAckProperties, AErr);
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


function Process_ErrPacket(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_UnhandledPacketType;
end;


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


function Process_PUBLISH(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
var
  TempReceivedPacket: TMQTTControlPacket;
  TempPublishFields: TMQTTPublishFields;
  TempPublishProperties: TMQTTPublishProperties;
begin
  MQTT_InitControlPacket(TempReceivedPacket);

  Result := Decode_PublishToCtrlPacket(ABuffer, TempReceivedPacket, ASizeToFree);
  if Result = CMQTTDecoderNoErr then
  begin
    MQTT_InitPublishProperties(TempPublishProperties);
    Result := Decode_Publish(TempReceivedPacket, TempPublishFields, TempPublishProperties);
  end;

  ////////////////////////////////// depending on Topic Alias, there must be a response  (see pag 61 of MQTT doc)
  { if (TempPublishProperties.TopicAlias = 0) or (TempPublishProperties.TopicAlias >= TempConnAckProperties.TopicAliasMaximum) then
    begin
      Disconnect(ReasonCode = 0x94);
    end;
  }

  if Lo(Result) = CMQTTDecoderNoErr then      ////////////////////////////////////////////// Result or Lo(Result) ???????????//////
  begin
    DoOnAfterReceivingMQTT_PUBLISH(ClientInstance, TempPublishFields, TempPublishProperties, Result);

    if Lo(Result) <> CMQTTDecoderNoErr then   ////////////////////////////////////////////// Result or Lo(Result) ???????????//////
    begin
      MQTT_FreePublishProperties(TempPublishProperties);
      MQTT_FreeControlPacket(TempReceivedPacket);
      Exit;
    end;
  end;

  Result := CMQTT_Success;
  //TempPublishProperties.SubscriptionIdentifier;      //  - array of DWord


  case TempPublishFields.PublishCtrlFlags and $3 of
    0 : //  Expected Response: None
    begin
      ////////////////////////////////////////////////////////////////////////////////////////////////////
    end;

    1 : //  Expected Response: PUBACK packet
    begin
      //Call DoOnBeforeSending_MQTT_PUBACK
      //MQTT_PUBACK<WithCallBack>   add to send buffer
      ////////////////////////////////////////////////////////////////////////////////////////////////////
    end;

    2 : //  Expected Response: PUBREC packet
    begin
      //Call DoOnBeforeSending_MQTT_PUBREC
      //MQTT_PUBREC<WithCallBack>   add to send buffer
      ////////////////////////////////////////////////////////////////////////////////////////////////////
    end;

    3 : //  Expected Response: Protocol error, should disconnect
    begin
      Result := CMQTT_BadQoS;
      Exit;
    end;
  end;

  MQTT_FreePublishProperties(TempPublishProperties);
  MQTT_FreeControlPacket(TempReceivedPacket);
end;


function Process_PUBACK(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_PUBREC(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_PUBREL(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
end;


function Process_PUBCOMP(ClientInstance: DWord; var ABuffer: TDynArrayOfByte; var ASizeToFree: DWord): Word;
begin
  Result := CMQTT_Success;
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


function AddCONNECT_ToBuffer(var ABuffer: TDynArrayOfByte;
                             var AConnectFields: TMQTTConnectFields;
                             var AConnectProperties: TMQTTConnectProperties;
                             var ADestPacket: TMQTTControlPacket): Boolean;
begin
  Result := FillIn_Connect(AConnectFields, AConnectProperties, ADestPacket);

  if Result then
    Result := ConcatDynArrays(ABuffer, ADestPacket.Header);

  if Result then
    Result := ConcatDynArrays(ABuffer, ADestPacket.VarHeader);

  if Result then
    Result := ConcatDynArrays(ABuffer, ADestPacket.Payload);
end;


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


function MQTT_CONNECT(ClientInstance: DWord): Boolean;  //ClientInstance identifies the client instance
var
  TempConnectFields: TMQTTConnectFields;                    //user code has to fill-in this parameter
  TempConnectProperties: TMQTTConnectProperties;
  TempDestPacket: TMQTTControlPacket;
  {$IFnDEF SingleOutputBuffer}
    n: LongInt;
  {$ENDIF}
  TempClientInstance: DWord;
begin
  {$IFDEF IsDesktop}
    if not Assigned(OnBeforeMQTT_CONNECT) or not Assigned(OnBeforeMQTT_CONNECT^) then
  {$ELSE}
    if OnBeforeMQTT_CONNECT = nil then
  {$ENDIF}
    begin
      Result := False;
      Exit;
    end;

  MQTT_InitConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_InitConnectProperties(TempConnectProperties);

  Result := OnBeforeMQTT_CONNECT^(ClientInstance, TempConnectFields, TempConnectProperties);
  if Result then
  begin
    TempClientInstance := ClientInstance and CClientIndexMask;

    {$IFDEF SingleOutputBuffer}
      Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^, TempConnectFields, TempConnectProperties, TempDestPacket);
    {$ELSE}
      n := ClientToServerBuffer.Content^[TempClientInstance]^.Len;
      Result := SetDynOfDynOfByteLength(ClientToServerBuffer.Content^[TempClientInstance]^, n + 1);
      if Result then
        Result := AddCONNECT_ToBuffer(ClientToServerBuffer.Content^[TempClientInstance]^.Content^[n]^, TempConnectFields, TempConnectProperties, TempDestPacket);
    {$ENDIF}
  end;

  MQTT_FreeControlPacket(TempDestPacket);
  MQTT_FreeConnectPayloadContentProperties(TempConnectFields.PayloadContent);
  MQTT_FreeConnectProperties(TempConnectProperties);
end;


function MQTT_PUBACK(ClientInstance: DWord): Boolean;
begin
  Result := True;
end;


function MQTT_PUBREC(ClientInstance: DWord): Boolean;
begin
  Result := True;
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

end.

