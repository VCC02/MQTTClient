{
    Copyright (C) 2023 VCC
    creation date: 27 Apr 2023
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


unit MQTTUtils;

{$IFNDEF IsMCU}
  {$DEFINE IsDesktop}
{$ENDIF}

{$IFDEF FPC}
  {$mode ObjFPC}{$H+}
{$ENDIF}

{$IFDEF IsDesktop}
interface
{$ENDIF}

uses
  DynArrays;

//  Classes, SysUtils;

type
  T4ByteArray = array[0..3] of Byte;

  TMQTTControlPacket = record
    Header: TDynArrayOfByte;
    VarHeader: TDynArrayOfByte;  //This will be 0 bytes in length for some packet types.
    Payload: TDynArrayOfByte;    // not all packet types will have a payload
  end;

  TMQTTProp_PayloadFormatIndicator = Byte;
  TMQTTProp_MessageExpiryInterval = DWord;
  TMQTTProp_ContentType = TDynArrayOfByte; //UTF-8 string
  TMQTTProp_ResponseTopic = TDynArrayOfByte; //UTF-8 string
  TMQTTProp_CorrelationData = TDynArrayOfByte; //binary data
  TMQTTProp_SingleSubscriptionIdentifier = DWord; //VarInt
  TMQTTProp_SubscriptionIdentifier = TDynArrayOfDWord; //VarInt   //These are VarInts on protocol only. The array stores DWords.
  TMQTTProp_SessionExpiryInterval = DWord; //[s]
  TMQTTProp_AssignedClientIdentifier = TDynArrayOfByte; //UTF-8 string
  TMQTTProp_ServerKeepAlive = Word;
  TMQTTProp_AuthenticationMethod = TDynArrayOfByte; //UFT-8 string. This is string content only. The length is read from the "Len" field and then saved as 2-byte length in the VarHeader array. This encoding is different than the "UserProperty", where the array from the "Content" field, already contains string lengths.
  TMQTTProp_AuthenticationData = TDynArrayOfByte; //Binary Data (some user array)   - The length is read from the "Len" field and then saved as 2-byte length in the VarHeader array, then the actual data.
  TMQTTProp_RequestProblemInformation = Byte; //0 or 1
  TMQTTProp_WillDelayInterval = DWord;
  TMQTTProp_RequestResponseInformation = Byte; //0 or 1
  TMQTTProp_ResponseInformation = TDynArrayOfByte; //UFT-8 string
  TMQTTProp_ServerReference = TDynArrayOfByte; //UFT-8 string
  TMQTTProp_ReasonString = TDynArrayOfByte; //UFT-8 string
  TMQTTProp_ReceiveMaximum = Word;
  TMQTTProp_TopicAliasMaximum = Word;
  TMQTTProp_TopicAlias = Word;
  TMQTTProp_MaximumQoS = Byte;
  TMQTTProp_RetainAvailable = Byte;
  TMQTTProp_UserProperty = TDynArrayOfTDynArrayOfByte;   //UTF-8 string pair(s)  //One or more String Pairs, encoded as UFT-8 (two UTF-8 Encoded Strings / pair), including every 2-byte lengths before their content. This field is concatentated to VarHeader without any other processing. If multiple pairs exist in this content, they have to be concatenated prior to using this structure.
  TMQTTProp_MaximumPacketSize = DWord;
  TMQTTProp_WildcardSubscriptionAvailable = Byte;
  TMQTTProp_SubscriptionIdentifierAvailable = Byte;
  TMQTTProp_SharedSubscriptionAvailable = Byte;

const
  //Property identifiers
  CMQTT_PayloadFormatIndicator_PropID = 1;
  CMQTT_MessageExpiryInterval_PropID = 2;
  CMQTT_ContentType_PropID = 3;
  CMQTT_ResponseTopic_PropID = 8;
  CMQTT_CorrelationData_PropID = 9;
  CMQTT_SubscriptionIdentifier_PropID = 11;
  CMQTT_SessionExpiryInterval_PropID = 17;
  CMQTT_AssignedClientIdentifier_PropID = 18;
  CMQTT_ServerKeepAlive_PropID = 19;
  CMQTT_AuthenticationMethod_PropID = 21;
  CMQTT_AuthenticationData_PropID = 22;
  CMQTT_RequestProblemInformation_PropID = 23;
  CMQTT_WillDelayInterval_PropID = 24;
  CMQTT_RequestResponseInformation_PropID = 25;
  CMQTT_ResponseInformation_PropID = 26;
  CMQTT_ServerReference_PropID = 28;
  CMQTT_ReasonString_PropID = 31;
  CMQTT_ReceiveMaximum_PropID = 33;
  CMQTT_TopicAliasMaximum_PropID = 34;
  CMQTT_TopicAlias_PropID = 35;
  CMQTT_MaximumQoS_PropID = 36;
  CMQTT_RetainAvailable_PropID = 37;
  CMQTT_UserProperty_PropID = 38;
  CMQTT_MaximumPacketSize_PropID = 39;
  CMQTT_WildcardSubscriptionAvailable_PropID = 40;
  CMQTT_SubscriptionIdentifierAvailable_PropID = 41;
  CMQTT_SharedSubscriptionAvailable_PropID = 42;
  CMQTT_UnknownProperty_PropID = 170; //Used for testing CMQTTDecoderUnknownProperty error code. This constant is not defined in spec, it's just an available value.

  CMQTT_TypeByte = 0;             //Byte
  CMQTT_TypeWord = 1;             //Word
  CMQTT_TypeDoubleWord = 2;       //DWord
  CMQTT_TypeString = 3;           //array of byte
  CMQTT_TypeVarInt = 4;           //DWord
  CMQTT_TypeBinaryData = 5;       //array of byte
  CMQTT_TypeBinaryDataArray = 6;  //array of array of byte

  //CMQTT_PropertyDataTypes: array[0..42] of Byte = (
  //
  //);


type
  TMQTTConnectProperties = record
    SessionExpiryInterval: TMQTTProp_SessionExpiryInterval; //[s]
    ReceiveMaximum: TMQTTProp_ReceiveMaximum;
    MaximumPacketSize: TMQTTProp_MaximumPacketSize;
    TopicAliasMaximum: TMQTTProp_TopicAliasMaximum;
    RequestResponseInformation: TMQTTProp_RequestResponseInformation;
    RequestProblemInformation: TMQTTProp_RequestProblemInformation;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF}
    AuthenticationMethod: TMQTTProp_AuthenticationMethod;
    AuthenticationData: TMQTTProp_AuthenticationData;
  end;

  TMQTTWillProperties = record
    WillDelayInterval: TMQTTProp_WillDelayInterval;
    PayloadFormatIndicator: TMQTTProp_PayloadFormatIndicator;
    MessageExpiryInterval: TMQTTProp_MessageExpiryInterval;
    ContentType: TMQTTProp_ContentType;
    ResponseTopic: TMQTTProp_ResponseTopic;
    CorrelationData: TMQTTProp_CorrelationData;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF}
  end;

  TMQTTConnectPayloadContent = record  //  The Will Message consists of the Will Properties, Will Topic, and Will Payload fields in the CONNECT Payload.
    ClientID: TDynArrayOfByte;  //UTF-8 Encoded String
    WillProperties: TDynArrayOfByte; //will be encoded as binary data (Property length and Properties) - concatenation of TMQTTWillProperties.
    WillTopic: TDynArrayOfByte; //UTF-8 string
    WillPayload: TDynArrayOfByte; //binary data   (still UTF-8)
    UserName: TDynArrayOfByte; //UTF-8 string
    Password: TDynArrayOfByte; //binary data
  end;

  /////////////////

  TMQTTConnAckProperties = record
    SessionExpiryInterval: TMQTTProp_SessionExpiryInterval; //[s]
    ReceiveMaximum: TMQTTProp_ReceiveMaximum;
    MaximumQoS: TMQTTProp_MaximumQoS;
    RetainAvailable: TMQTTProp_RetainAvailable;
    MaximumPacketSize: TMQTTProp_MaximumPacketSize;
    AssignedClientIdentifier: TMQTTProp_AssignedClientIdentifier;
    TopicAliasMaximum: TMQTTProp_TopicAliasMaximum;
    ReasonString: TMQTTProp_ReasonString;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF}
    WildcardSubscriptionAvailable: TMQTTProp_WildcardSubscriptionAvailable;
    SubscriptionIdentifierAvailable: TMQTTProp_SubscriptionIdentifierAvailable;
    SharedSubscriptionAvailable: TMQTTProp_SharedSubscriptionAvailable;
    ServerKeepAlive: TMQTTProp_ServerKeepAlive;
    ResponseInformation: TMQTTProp_ResponseInformation;
    ServerReference: TMQTTProp_ServerReference;
    AuthenticationMethod: TMQTTProp_AuthenticationMethod;
    AuthenticationData: TMQTTProp_AuthenticationData;
  end;

  /////////////////

  TMQTTPublishProperties = record
    PayloadFormatIndicator: TMQTTProp_PayloadFormatIndicator;
    MessageExpiryInterval: TMQTTProp_MessageExpiryInterval;
    TopicAlias: TMQTTProp_TopicAlias;
    ResponseTopic: TMQTTProp_ResponseTopic;
    CorrelationData: TMQTTProp_CorrelationData;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF} //UTF-8 string pairs
    SubscriptionIdentifier: TMQTTProp_SubscriptionIdentifier;    //These are VarInts on protocol only. The array stores DWords.
    ContentType: TMQTTProp_ContentType;
  end;

  /////////////////

  TMQTTCommonProperties = record
    ReasonString: TMQTTProp_ReasonString;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF} //UTF-8 string pairs
  end;

  /////////////////

  TMQTTPubAckProperties = TMQTTCommonProperties;

  /////////////////

  TMQTTPubRecProperties = TMQTTCommonProperties;

  /////////////////
  
  TMQTTPubRelProperties = TMQTTCommonProperties;

  /////////////////

  TMQTTPubCompProperties = TMQTTCommonProperties;

  /////////////////

  TMQTTSubscribeProperties = record
    SubscriptionIdentifier: TMQTTProp_SingleSubscriptionIdentifier;    //This is VarInt on protocol only.
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF} //UTF-8 string pairs
  end;

  /////////////////

  TMQTTSubAckProperties = TMQTTCommonProperties;   //Only the properties are identical to the other packets. This one does not have packet identifier field.

  /////////////////

  TMQTTUnsubscribeProperties = record
    {$IFDEF EnUserProperty}
      UserProperty: TMQTTProp_UserProperty;  //UTF-8 string pairs
    {$ELSE}
      {$IFDEF IsMCU}
        Dummy: Byte; //something, to avoid having an empty structure
      {$ENDIF}
    {$ENDIF}
  end;

  /////////////////

  TMQTTUnsubAckProperties = TMQTTCommonProperties;

  /////////////////

  TMQTTPingReqProperties = record   //ping request has no properties
    {$IFDEF IsMCU}
      Dummy: Byte;  //mP doesn't like empty records
    {$ENDIF}
  end;

  /////////////////

  TMQTTPingRespProperties = record   //ping response has no properties
    {$IFDEF IsMCU}
      Dummy: Byte;  //mP doesn't like empty records
    {$ENDIF}
  end;


  /////////////////

  TMQTTDisconnectProperties = record
    SessionExpiryInterval: TMQTTProp_SessionExpiryInterval; //[s]
    ReasonString: TMQTTProp_ReasonString;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF} //UTF-8 string pairs
    ServerReference: TMQTTProp_ServerReference;
  end;

  /////////////////

  TMQTTAuthProperties = record
    AuthenticationMethod: TMQTTProp_AuthenticationMethod;
    AuthenticationData: TMQTTProp_AuthenticationData;
    ReasonString: TMQTTProp_ReasonString;
    {$IFDEF EnUserProperty} UserProperty: TMQTTProp_UserProperty; {$ENDIF} //UTF-8 string pairs
  end;

  //////////////////// Fields

  TMQTTConnectFields = record
    PayloadContent: TMQTTConnectPayloadContent;
    EnabledProperties: Word;
    KeepAlive: Word;
    ConnectFlags: Byte;  //bits 7-0:  User Name, Password, Will Retain, Will QoS, Will Flag, Clean Start, Reserved
    ProtocolVersion: Byte; //should return 5 on decoder.  Not used on FillIn.
  end;

  TMQTTConnAckFields = record
    EnabledProperties: DWord;
    SessionPresentFlag: Byte;
    ConnectReasonCode: Byte;
  end;

  TMQTTPublishFields = record
    TopicName: TDynArrayOfByte;
    ApplicationMessage: TDynArrayOfByte;
    PacketIdentifier: Word;
    EnabledProperties: Word;
    PublishCtrlFlags: Byte;  //bits 3-0:  Dup(3), QoS(2-1), Retain(0)
  end;

  TMQTTCommonFields = record
    PacketIdentifier: Word;
    ReasonCode: Byte;
    IncludeReasonCode: Byte; //1, if ReasonCode should be included in VarHeader
    EnabledProperties: Word;
    SrcPayload: TDynArrayOfByte; //SrcPayload is used for SubAck and UnsubAck only (as SubscribeReasonCodes).
                                 //It has to be initialized for these two packets only.
                                 //This array should have the same length as the number of topics in a matching Subscribe/Unsubscribe packet. The matching is done by PacketIdentifier.
  end;

  TMQTTPubAckFields = TMQTTCommonFields;
  TMQTTPubRecFields = TMQTTCommonFields;
  TMQTTPubRelFields = TMQTTCommonFields;
  TMQTTPubCompFields = TMQTTCommonFields;

  TMQTTSubscribeFields = record
    PacketIdentifier: Word;
    EnabledProperties: Word;
    TopicFilters: TDynArrayOfByte; //A concatenated array of topic filters and their subscription options. This array can be encoded using FillIn_SubscribePayload and decoded with Decode_SubscribePayload.
  end;

  TMQTTSubAckFields = TMQTTCommonFields;

  TMQTTUnsubscribeFields = TMQTTSubscribeFields;

  TMQTTUnsubAckFields = TMQTTCommonFields;

  //no ping fields

  TMQTTDisconnectFields = record
    DisconnectReasonCode: Byte;
    EnabledProperties: Word;
  end;

  TMQTTAuthFields = record      //Same structure as TMQTTDisconnectFields. Maybe the codec can be merged if they are not very different.
    AuthReasonCode: Byte;
    EnabledProperties: Word;
  end;



//  TMQTTPropertySet = array[0..16 - 1] of Byte;
//  PMQTTPropertySet = ^TMQTTPropertySet;  //probably it requires the following on mP:  "^far const code Byte" for 16-bit, and "^const code Byte" on 32-bit
//
//const          //enums are not available on mP
//  CMQTTPropDataType_Byte = 0;
//  CMQTTPropDataType_Word = 1;
//  CMQTTPropDataType_DWord = 2;
//  CMQTTPropDataType_VarIntAsDWord = 3;
//  CMQTTPropDataType_TDynArrayOfByte = 4;
//  CMQTTPropDataType_TDynArrayOfWord = 5; //reserved for now
//  CMQTTPropDataType_TDynArrayOfDWord = 6;
//  CMQTTPropDataType_TDynArrayOfTDynArrayOfByte = 7;
//
//  CMQTTPropertyAllocationSize: array[0..7] of Byte = (
//    SizeOf(Byte),
//    SizeOf(Word),
//    SizeOf(DWord),
//    SizeOf(DWord), //VarIntAsDWord
//    SizeOf(TDynArrayOfByte),
//    SizeOf(TDynArrayOfDWord),   //TDynArrayOfWord
//    SizeOf(TDynArrayOfDWord),
//    SizeOf(TDynArrayOfTDynArrayOfByte)
//  );
//
//  //Ctrl properties
//  CMQTTConnectPropertyCount = 9;
//  CMQTTConnAckPropertyCount = 17;
//  CMQTTPublishPropertyCount = 8;
//
//  CMQTTConnectPropertiesSet: array[0..CMQTTConnectPropertyCount - 1] of Byte = (
//    CMQTT_SessionExpiryInterval_PropID,
//    CMQTT_ReceiveMaximum_PropID,
//    CMQTT_MaximumPacketSize_PropID,
//    CMQTT_TopicAliasMaximum_PropID,
//    CMQTT_RequestResponseInformation_PropID,
//    CMQTT_RequestProblemInformation_PropID,
//    CMQTT_UserProperty_PropID,
//    CMQTT_AuthenticationMethod_PropID,
//    CMQTT_AuthenticationData_PropID
//  );
//
//  CMQTTConnAckPropertiesSet: array[0..CMQTTConnAckPropertyCount - 1] of Byte = (
//    CMQTT_SessionExpiryInterval_PropID,
//    CMQTT_ReceiveMaximum_PropID,
//    CMQTT_MaximumQoS_PropID,
//    CMQTT_RetainAvailable_PropID,
//    CMQTT_MaximumPacketSize_PropID,
//    CMQTT_AssignedClientIdentifier_PropID,
//    CMQTT_TopicAliasMaximum_PropID,
//    CMQTT_ReasonString_PropID,
//    CMQTT_UserProperty_PropID,
//    CMQTT_WildcardSubscriptionAvailable_PropID,
//    CMQTT_SubscriptionIdentifierAvailable_PropID,
//    CMQTT_SharedSubscriptionAvailable_PropID,
//    CMQTT_ServerKeepAlive_PropID,
//    CMQTT_ResponseInformation_PropID,
//    CMQTT_ServerReference_PropID,
//    CMQTT_AuthenticationMethod_PropID,
//    CMQTT_AuthenticationData_PropID
//  );
//
//  CMQTTPublishPropertiesSet: array[0..CMQTTPublishPropertyCount - 1] of Byte = (
//    CMQTT_PayloadFormatIndicator_PropID,
//    CMQTT_MessageExpiryInterval_PropID,
//    CMQTT_TopicAlias_PropID,
//    CMQTT_ResponseTopic_PropID,
//    CMQTT_CorrelationData_PropID,
//    CMQTT_UserProperty_PropID,
//    CMQTT_SubscriptionIdentifier_PropID,
//    CMQTT_ContentType_PropID
//  );
//
//
//  CMQTTPropertySets: array[0..15] of PMQTTPropertySet = (
//    nil, //no ctrl packet at index 0
//    @CMQTTConnectPropertiesSet,
//    @CMQTTConnAckPropertiesSet,
//    @CMQTTPublishPropertiesSet,
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil, //ToDo
//    nil  //ToDo
//  );
//
//  //Non-Ctrl properties
//  CMQTTConnectWillPropertyCount = 7;
//
//  CMQTTConnectWillPropertiesSet: array[0..CMQTTConnectWillPropertyCount - 1] of Byte = (
//    CMQTT_WillDelayInterval_PropID,
//    CMQTT_PayloadFormatIndicator_PropID,
//    CMQTT_MessageExpiryInterval_PropID,
//    CMQTT_ContentType_PropID,
//    CMQTT_ResponseTopic_PropID,
//    CMQTT_CorrelationData_PropID,
//    CMQTT_UserProperty_PropID
//  );
//
//type
//  TMQTTProperty = record                    //the DWord type, used for pointer, can be replaced with Word on 16-bit
//    PropData: {$IFDEF FPC} Pointer; {$ELSE} DWord; {$ENDIF}  //points to a Byte, Word, DWord, VarIntAsDWord, TDynArrayOfByte, TDynArrayOfDWord or TDynArrayOfTDynArrayOfByte
//    PropID: Byte;  //See property identifiers
//    PropDataType: Byte;  //Can be one of the above CMQTTPropDataType_<type> constants. This field decides which CMQTT_Decode<type> function to use.
//  end;

const

  //Connect specific constants, matching TMQTTConnectProperties structure
  CMQTTConnect_EnSessionExpiryInterval = 1;
  CMQTTConnect_EnReceiveMaximum = 2;
  CMQTTConnect_EnMaximumPacketSize = 4;
  CMQTTConnect_EnTopicAliasMaximum = 8;
  CMQTTConnect_EnRequestResponseInformation = 16;
  CMQTTConnect_EnRequestProblemInformation = 32;
  CMQTTConnect_EnUserProperty = 64;
  CMQTTConnect_EnAuthenticationMethod = 128;
  CMQTTConnect_EnAuthenticationData = 256;

  //ConnAck specific constants, matching TMQTTConnAckProperties structure
  CMQTTConnAck_EnSessionExpiryInterval = 1;
  CMQTTConnAck_EnReceiveMaximum = 2;
  CMQTTConnAck_EnMaximumQoS = 4;
  CMQTTConnAck_EnRetainAvailable = 8;
  CMQTTConnAck_EnMaximumPacketSize = 16;
  CMQTTConnAck_EnAssignedClientIdentifier = 32;
  CMQTTConnAck_EnTopicAliasMaximum = 64;
  CMQTTConnAck_EnReasonString = 128;
  CMQTTConnAck_EnUserProperty = 256;
  CMQTTConnAck_EnWildcardSubscriptionAvailable = 512;
  CMQTTConnAck_EnSubscriptionIdentifierAvailable = 1024;
  CMQTTConnAck_EnSharedSubscriptionAvailable = 2048;
  CMQTTConnAck_EnServerKeepAlive = 4096;
  CMQTTConnAck_EnResponseInformation = 8192;
  CMQTTConnAck_EnServerReference = 16384;
  CMQTTConnAck_EnAuthenticationMethod = 32768;
  CMQTTConnAck_EnAuthenticationData = 65536;

  //Publish specific constants, matching TMQTTPublishProperties structure
  CMQTTPublish_EnPayloadFormatIndicator = 1;
  CMQTTPublish_EnMessageExpiryInterval = 2;
  CMQTTPublish_EnTopicAlias = 4;
  CMQTTPublish_EnResponseTopic = 8;
  CMQTTPublish_EnCorrelationData = 16;
  CMQTTPublish_EnUserProperty = 32;
  CMQTTPublish_EnSubscriptionIdentifier = 64;
  CMQTTPublish_EnContentType = 128;

   //Common properties, for multiple structures
  CMQTTCommon_EnReasonString = 1;
  CMQTTCommon_EnUserProperty = 2;

  //Subscribe specific constants, matching TMQTTSubscribeProperties structure
  CMQTTSubscribe_EnSubscriptionIdentifier = 1;
  CMQTTSubscribe_EnUserProperty = 2;

  //Unsubscribe specific constants, matching TMQTTUnsubscribeProperties structure
  CMQTTUnsubscribe_EnUserProperty = 1;

  //Disconnect specific constants, matching TMQTTDisconnectProperties structure
  CMQTTDisconnect_EnSessionExpiryInterval = 1;
  CMQTTDisconnect_EnReasonString = 2;
  CMQTTDisconnect_EnUserProperty = 4;
  CMQTTDisconnect_EnServerReference = 8;

  //Auth specific constants, matching TMQTTAuthProperties structure
  CMQTTAuth_EnAuthenticationMethod = 1;
  CMQTTAuth_EnAuthenticationData = 2;
  CMQTTAuth_EnReasonString = 4;
  CMQTTAuth_EnUserProperty = 8;

const
  CMQTTUnknownPropertyWord = $8000;             //used when EnabledProperties argument is a Word
  CMQTTUnknownPropertyDoubleWord = $8000000;    //used when EnabledProperties argument is a Word

const
  CMQTT_UNDEFINED_NoSHL = 0; //0      //for testing only
  CMQTT_CONNECT_NoSHL = 1;  //16      //Client to Server
  CMQTT_CONNACK_NoSHL = 2;  //32      //Server to Client
  CMQTT_PUBLISH_NoSHL = 3;  //48      //  Client to Server or Server to Client
  CMQTT_PUBACK_NoSHL = 4;  //64       //  Client to Server or Server to Client
  CMQTT_PUBREC_NoSHL = 5;  //80       //  Client to Server or Server to Client
  CMQTT_PUBREL_NoSHL = 6;             //  Client to Server or Server to Client
  CMQTT_PUBCOMP_NoSHL = 7;            //  Client to Server or Server to Client
  CMQTT_SUBSCRIBE_NoSHL = 8;          //Client to Server
  CMQTT_SUBACK_NoSHL = 9;             //Server to Client
  CMQTT_UNSUBSCRIBE_NoSHL = 10;       //Client to Server
  CMQTT_UNSUBACK_NoSHL = 11;          //Server to Client
  CMQTT_PINGREQ_NoSHL = 12;           //Client to Server
  CMQTT_PINGRESP_NoSHL = 13;          //Server to Client
  CMQTT_DISCONNECT_NoSHL = 14;        //  Client to Server or Server to Client
  CMQTT_AUTH_NoSHL = 15;              //  Client to Server or Server to Client

  CMQTT_UNDEFINED = 0 shl 4; //0      //for testing only
  CMQTT_CONNECT = 1 shl 4;  //16      //Client to Server
  CMQTT_CONNACK = 2 shl 4;  //32      //Server to Client
  CMQTT_PUBLISH = 3 shl 4;  //48      //  Client to Server or Server to Client
  CMQTT_PUBACK = 4 shl 4;  //64       //  Client to Server or Server to Client
  CMQTT_PUBREC = 5 shl 4;  //80       //  Client to Server or Server to Client
  CMQTT_PUBREL = 6 shl 4;             //  Client to Server or Server to Client
  CMQTT_PUBCOMP = 7 shl 4;            //  Client to Server or Server to Client
  CMQTT_SUBSCRIBE = 8 shl 4;          //Client to Server
  CMQTT_SUBACK = 9 shl 4;             //Server to Client
  CMQTT_UNSUBSCRIBE = 10 shl 4;       //Client to Server
  CMQTT_UNSUBACK = 11 shl 4;          //Server to Client
  CMQTT_PINGREQ = 12 shl 4;           //Client to Server
  CMQTT_PINGRESP = 13 shl 4;          //Server to Client
  CMQTT_DISCONNECT = 14 shl 4;        //  Client to Server or Server to Client
  CMQTT_AUTH = 15 shl 4;              //  Client to Server or Server to Client


  CMQTT_UsernameInConnectFlagsBitMask = 128;
  CMQTT_PasswordInConnectFlagsBitMask = 64;
  CMQTT_WillRetainInConnectFlagsBitMask = 32;
  CMQTT_WillQoSB1InConnectFlagsBitMask = 16;
  CMQTT_WillQoSB0InConnectFlagsBitMask = 8;
  CMQTT_WillFlagInConnectFlagsBitMask = 4;
  CMQTT_CleanStartInConnectFlagsBitMask = 2;
  CMQTT_ReservedInConnectFlagsBitMask = 1;


const
  CMQTT_Reason_Success = $0;                               //CONNACK, PUBACK, PUBREC, PUBREL, PUBCOMP, UNSUBACK, AUTH
  CMQTT_Reason_NormalDisconnection = $0;                   //DISCONNECT
  CMQTT_Reason_GrantedQoS0 = $0;                           //SUBACK
  CMQTT_Reason_GrantedQoS1 = $1;                           //SUBACK
  CMQTT_Reason_GrantedQoS2 = $2;                           //SUBACK
  CMQTT_Reason_DisconnectWithWillMessage = $4;             //DISCONNECT
  CMQTT_Reason_NoMatchingSubscribers = $10;                //PUBACK, PUBREC
  CMQTT_Reason_NoSubscriptionExisted = $11;                //UNSUBACK
  CMQTT_Reason_ContinueAuthentication = $18;               //AUTH
  CMQTT_Reason_ReAuthenticate = $19;                       //AUTH
  CMQTT_Reason_UnspecifiedError = $80;                     //CONNACK, PUBACK, PUBREC, SUBACK, UNSUBACK, DISCONNECT
  CMQTT_Reason_MalformedPacket = $81;                      //CONNACK, DISCONNECT
  CMQTT_Reason_ProtocolError = $82;                        //CONNACK, DISCONNECT
  CMQTT_Reason_ImplementationSpecificError = $83;          //CONNACK, PUBACK, PUBREC, SUBACK, UNSUBACK, DISCONNECT
  CMQTT_Reason_UnsupportedProtocolVersion = $84;           //CONNACK
  CMQTT_Reason_ClientIdentifierNotValid = $85;             //CONNACK
  CMQTT_Reason_BadUserNameOrPassword = $86;                //CONNACK
  CMQTT_Reason_NotAuthorized = $87;                        //CONNACK, PUBACK, PUBREC, SUBACK, UNSUBACK, DISCONNECT
  CMQTT_Reason_ServerUnavailable = $88;                    //CONNACK
  CMQTT_Reason_ServerBusy = $89;                           //CONNACK, DISCONNECT
  CMQTT_Reason_Banned = $8A;                               //CONNACK
  CMQTT_Reason_ServerShuttingDown = $8B;                   //DISCONNECT
  CMQTT_Reason_BadAuthenticationMethod = $8C;              //CONNACK, DISCONNECT
  CMQTT_Reason_KeepAliveTimeout = $8D;                     //DISCONNECT
  CMQTT_Reason_SessionTakenOver = $8E;                     //DISCONNECT
  CMQTT_Reason_TopicFilterInvalid = $8F;                   //SUBACK, UNSUBACK, DISCONNECT
  CMQTT_Reason_TopicNameInvalid = $90;                     //CONNACK, PUBACK, PUBREC, DISCONNECT
  CMQTT_Reason_PacketIdentifierInUse = $91;                //PUBACK, PUBREC, SUBACK, UNSUBACK
  CMQTT_Reason_PacketIdentifierNotFound = $92;             //PUBREL, PUBCOMP
  CMQTT_Reason_ReceiveMaximumExceeded = $93;               //DISCONNECT
  CMQTT_Reason_TopicAliasInvalid = $94;                    //DISCONNECT
  CMQTT_Reason_PacketTooLarge = $95;                       //CONNACK, DISCONNECT
  CMQTT_Reason_MessageRateTooHigh = $96;                   //DISCONNECT
  CMQTT_Reason_QuotaExceeded = $97;                        //CONNACK, PUBACK, PUBREC, SUBACK, DISCONNECT
  CMQTT_Reason_AdministrativeAaction = $98;                //DISCONNECT
  CMQTT_Reason_PayloadFormatInvalid = $99;                 //CONNACK, PUBACK, PUBREC, DISCONNECT
  CMQTT_Reason_RetainNotSupported = $9A;                   //CONNACK, DISCONNECT
  CMQTT_Reason_QoSNotSupported = $9B;                      //CONNACK, DISCONNECT
  CMQTT_Reason_UseAnotherServer = $9C;                     //CONNACK, DISCONNECT
  CMQTT_Reason_ServerMoved = $9D;                          //CONNACK, DISCONNECT
  CMQTT_Reason_SharedSubscriptionsNotSupported = $9E;      //SUBACK, DISCONNECT
  CMQTT_Reason_ConnectionRateExceeded = $9F;               //CONNACK, DISCONNECT
  CMQTT_Reason_MaximumConnectTime = $A0;                   //DISCONNECT
  CMQTT_Reason_SubscriptionIdentifiersNotSupported = $A1;  //SUBACK, DISCONNECT
  CMQTT_Reason_WildcardSubscriptionsNotSupported = $A2;    //SUBACK, DISCONNECT

  CMQTT_OOM_HeaderAlloc = 1 shl 8;
  CMQTT_OOM_VarHeaderAlloc = 2 shl 8;
  CMQTT_OOM_PayloadAlloc = 3 shl 8;
  CMQTT_OOM_DecodeProperties = 4 shl 8;
  CMQTT_OOM_TopicNameAlloc = 5 shl 8;
  CMQTT_OOM_DecodeTopicNames = 6 shl 8;
  CMQTT_OOM_ApplicationMessageAlloc = 7 shl 8;
  CMQTT_OOM_SubscriptionOptionsAlloc = 8 shl 8;

const
  CMQTTDecoderNoErr = 0;
  CMQTTDecoderEmptyBuffer = 1;
  CMQTTDecoderBadCtrlPacket = 2;
  CMQTTDecoderBadVarInt = 3;
  CMQTTDecoderServerErr = 4;          //this is accompanied by the error number returned from server at higher byte
  CMQTTDecoderBadHeaderSize = 5;      //one of the mentioned field size may be corrupt
  CMQTTDecoderIncompleteBuffer = 6;   //usually, the decoder functions will return this, until the received buffer has the full content  (used for FSM control)
  CMQTTDecoderOverfilledBuffer = 7;   //received too much in the same buffer  (usually bad decoding or bad content)
  CMQTTDecoderUnknownProperty = 8;    //a property is found which should not be part of the current packet or is outside of defined properties
  CMQTTDecoderMissingPayload = 9;
  CMQTTDecoderBadCtrlPacketOnDisconnect = 10;  //a special case of CMQTTDecoderBadCtrlPacket, where the receiver is required to send a DISCONNECT with an error code
  CMQTTDecoderOutOfMemory = 11;


//Other library constants
const
  CMQTT_DefaultReceiveMaximum = $0003; //Some valid value, greater than 0, used to initialize the ReceiveMaximum property. The greater the value, the greater the number of Publish packets can be sent from this client without a PubAck or PubRec response.


const
  CFFArr: array[0..4] of Byte = ($FF, $FF, $FF, $FF, $FF);  //Used by decoders to initialize remaining buffer with invalid data (i.e. $FF, instead of random data found in memory).


type
  TCtrlPacketDecoderFunc = function(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var AErr: Word): Boolean;
  PCtrlPacketDecoderFunc = ^TCtrlPacketDecoderFunc;


function DWordToVarInt(X: DWord; var AVarInt: T4ByteArray): Byte;
function VarIntToDWord(var AVarInt: T4ByteArray; var AVarIntLen: Byte; var Err: Boolean): DWord;

function AddDoubleWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: DWord; APropertyIdentifier: Byte): Boolean;
function AddWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: Word; APropertyIdentifier: Byte): Boolean;
function AddWordToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; AProperty: Word): Boolean;
function AddByteToProperties(var AVarHeader: TDynArrayOfByte; AProperty: Byte; APropertyIdentifier: Byte): Boolean;
function AddVarIntToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: T4ByteArray; APropertyLen: Byte; APropertyIdentifier: Byte): Boolean;
function AddVarIntToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: T4ByteArray; APropertyLen: Byte): Boolean;
function AddVarIntAsDWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: DWord; APropertyIdentifier: Byte): Boolean;
function AddVarIntAsDWordToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; AProperty: DWord): Boolean;
function AddBinaryDataToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: TDynArrayOfByte; APropertyIdentifier: Byte): Boolean;
function AddBinaryDataToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: TDynArrayOfByte): Boolean;
function AddUTF8StringToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: string; APropertyIdentifier: Byte): Boolean;
function AddUTF8StringToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: string): Boolean;

function MQTT_AddUserPropertyToPacket(var AUserProperty: TMQTTProp_UserProperty; var ADestProperties: TDynArrayOfByte): Boolean;
function MQTT_AddSubscriptionIdentifierToPacket(var ASubscriptionIdentifier: TMQTTProp_SubscriptionIdentifier; var ADestProperties: TDynArrayOfByte): Boolean;

function MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, AActualVarAndPayloadLen: DWord): Byte;

//function BufferToMQTTControlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var AErr: Word): Boolean;
//procedure MQTTRegisterDecoderFunc(AFunc: TCtrlPacketDecoderFunc; AIndex: Byte);

procedure MQTT_DecodeByte(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: Byte);
procedure MQTT_DecodeWord(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: Word);
procedure MQTT_DecodeDoubleWord(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: DWord);
procedure MQTT_DecodeVarInt(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: DWord);
procedure MQTT_DecodeBinaryData(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: TDynArrayOfByte);


procedure MQTT_InitControlPacket(var APacket: TMQTTControlPacket);
procedure MQTT_FreeControlPacket(var APacket: TMQTTControlPacket);

procedure MQTT_InitConnectProperties(var AProperties: TMQTTConnectProperties);
procedure MQTT_FreeConnectProperties(var AProperties: TMQTTConnectProperties);
procedure MQTT_InitWillProperties(var AProperties: TMQTTWillProperties);   //used by Connect packet
procedure MQTT_FreeWillProperties(var AProperties: TMQTTWillProperties);   //used by Connect packet
procedure MQTT_InitConnectPayloadContentProperties(var AProperties: TMQTTConnectPayloadContent);   //used by Connect packet
procedure MQTT_FreeConnectPayloadContentProperties(var AProperties: TMQTTConnectPayloadContent);   //used by Connect packet

procedure MQTT_InitConnAckProperties(var AProperties: TMQTTConnAckProperties);
procedure MQTT_FreeConnAckProperties(var AProperties: TMQTTConnAckProperties);
procedure MQTT_CopyConnAckProperties(var ASrcProperties, ADestProperties: TMQTTConnAckProperties);

procedure MQTT_InitPublishProperties(var AProperties: TMQTTPublishProperties);
procedure MQTT_FreePublishProperties(var AProperties: TMQTTPublishProperties);
procedure MQTT_CopyPublishProperties(var ASrcProperties, ADestProperties: TMQTTPublishProperties);

procedure MQTT_InitCommonProperties(var AProperties: TMQTTCommonProperties);
procedure MQTT_FreeCommonProperties(var AProperties: TMQTTCommonProperties);

procedure MQTT_InitSubscribeProperties(var AProperties: TMQTTSubscribeProperties);
procedure MQTT_FreeSubscribeProperties(var AProperties: TMQTTSubscribeProperties);

procedure MQTT_InitUnsubscribeProperties(var AProperties: TMQTTUnsubscribeProperties);
procedure MQTT_FreeUnsubscribeProperties(var AProperties: TMQTTUnsubscribeProperties);

procedure MQTT_InitDisconnectProperties(var AProperties: TMQTTDisconnectProperties);
procedure MQTT_FreeDisconnectProperties(var AProperties: TMQTTDisconnectProperties);

procedure MQTT_InitAuthProperties(var AProperties: TMQTTAuthProperties);
procedure MQTT_FreeAuthProperties(var AProperties: TMQTTAuthProperties);


//extra functions, for mP compatibility:
{$IFnDEF IsDesktop}
  function CompareMem(AP1, AP2: PByte; ALength: LongInt): Boolean;
{$ENDIF}

procedure MQTTPacketToString(APacketType: Byte; var AResult: string {$IFnDEF IsDesktop}[12]{$ENDIF}); {$IFDEF IsDesktop} overload; {$ENDIF}

{$IFDEF IsDesktop}
  function MQTTPacketToString(APacketType: Byte): string; overload;
{$ENDIF}

procedure InitVarIntDecoderArr(var ABuffer: TDynArrayOfByte; var DestTempArr4: T4ByteArray);


implementation


//returns the length
function DWordToVarInt(X: DWord; var AVarInt: T4ByteArray): Byte;  //see algorithm in MQTT spec, at "Variable Byte Integer" chapter
var
  EncodedByte: Byte;
begin
  Result := 0;
  repeat
    EncodedByte := X and 127; // X mod 128;
    X := X shr 7; // X div 128;

    if X > 0 then
      EncodedByte := EncodedByte or 128;

    AVarInt[Result] := EncodedByte;
    Inc(Result);
  until X = 0;
end;


function VarIntToDWord(var AVarInt: T4ByteArray; var AVarIntLen: Byte; var Err: Boolean): DWord;  //see algorithm in MQTT spec, at "Variable Byte Integer" chapter
var
  Multiplier, Value: DWord;
  EncodedByte, NextByte: Byte;
begin
  Err := False;
  Multiplier := 1;
  Value := 0;

  NextByte := 0;
  AVarIntLen := 0;
  repeat
    EncodedByte := AVarInt[NextByte];
    Inc(NextByte);

    Value := Value + DWord(EncodedByte and 127) * Multiplier;
    if Multiplier > 128 * 128 * 128 then   //this comparison can be replaced with "if NextByte > 3 then"
    begin
      Err := True;   //Malformed Variable Byte Integer
      Result := 0;
      Exit;
    end;

    Multiplier := Multiplier shl 7; // Multiplier * 128;
  until EncodedByte and 128 = 0;

  AVarIntLen := NextByte;
  Result := Value;
end;


function AddDoubleWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: DWord; APropertyIdentifier: Byte): Boolean;
var
  TempDWord: DWord;
  TempArr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 5);
  if not Result then
    Exit;

  TempArr.Content^[0] := APropertyIdentifier;

  TempDWord := AProperty;
  TempArr.Content^[4] := TempDWord and $FF;

  TempDWord := TempDWord shr 8;
  TempArr.Content^[3] := TempDWord and $FF;

  TempDWord := TempDWord shr 8;
  TempArr.Content^[2] := TempDWord and $FF;

  TempDWord := TempDWord shr 8;
  TempArr.Content^[1] := TempDWord and $FF;

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: Word; APropertyIdentifier: Byte): Boolean;
var
  TempWord: Word;
  TempArr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 3);
  if not Result then
    Exit;

  TempArr.Content^[0] := APropertyIdentifier;

  TempWord := AProperty;
  TempArr.Content^[2] := TempWord and $FF;

  TempWord := TempWord shr 8;
  TempArr.Content^[1] := TempWord and $FF;

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddWordToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; AProperty: Word): Boolean;
var
  TempWord: Word;
  TempArr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 2);
  if not Result then
    Exit;

  TempWord := AProperty;
  TempArr.Content^[1] := TempWord and $FF;

  TempWord := TempWord shr 8;
  TempArr.Content^[0] := TempWord and $FF;

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddByteToProperties(var AVarHeader: TDynArrayOfByte; AProperty: Byte; APropertyIdentifier: Byte): Boolean;
var
  TempArr: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 2);
  if not Result then
    Exit;

  TempArr.Content^[0] := APropertyIdentifier;
  TempArr.Content^[1] := AProperty;

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddVarIntToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: T4ByteArray; APropertyLen: Byte; APropertyIdentifier: Byte): Boolean;
var
  TempArr: TDynArrayOfByte;
  i: Integer;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 1 + APropertyLen);
  if not Result then
    Exit;

  TempArr.Content^[0] := APropertyIdentifier;

  for i := 0 to Integer(APropertyLen) - 1 do
    TempArr.Content^[i + 1] := AProperty[i];

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddVarIntToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: T4ByteArray; APropertyLen: Byte): Boolean;
var
  TempArr: TDynArrayOfByte;
  i: Integer;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, APropertyLen);
  if not Result then
    Exit;

  for i := 0 to Integer(APropertyLen) - 1 do
    TempArr.Content^[i] := AProperty[i];

  Result := ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddVarIntAsDWordToProperties(var AVarHeader: TDynArrayOfByte; AProperty: DWord; APropertyIdentifier: Byte): Boolean;
var
  PropertyAsVarInt: T4ByteArray;
  PropertyLen: Byte;
begin
  if AProperty > 268435455 then
  begin
    Result := False;
    Exit;
  end;

  PropertyLen := DWordToVarInt(AProperty, PropertyAsVarInt);
  Result := AddVarIntToProperties(AVarHeader, PropertyAsVarInt, PropertyLen, APropertyIdentifier);
end;


function AddVarIntAsDWordToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; AProperty: DWord): Boolean;
var
  PropertyAsVarInt: T4ByteArray;
  PropertyLen: Byte;
begin
  if AProperty > 268435455 then
  begin
    Result := False;
    Exit;
  end;

  PropertyLen := DWordToVarInt(AProperty, PropertyAsVarInt);
  Result := AddVarIntToPropertiesWithoutIdentifier(AVarHeader, PropertyAsVarInt, PropertyLen);
end;


//binary data will be stored/passed using TDynArrayOfByte, as this datatype is already a pointer and a length
function AddBinaryDataToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: TDynArrayOfByte; APropertyIdentifier: Byte): Boolean;
var
  TempArr: TDynArrayOfByte;
  TempWord: Word;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 3);    //one byte for identifier, two bytes for data length
  if not Result then
    Exit;

  TempArr.Content^[0] := APropertyIdentifier;

  TempWord := AProperty.Len;
  TempArr.Content^[2] := TempWord and $FF;

  TempWord := TempWord shr 8;
  TempArr.Content^[1] := TempWord and $FF;

  Result := ConcatDynArrays(TempArr, AProperty);
  Result := Result and ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


function AddBinaryDataToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: TDynArrayOfByte): Boolean;
var
  TempArr: TDynArrayOfByte;
  TempWord: Word;
begin
  InitDynArrayToEmpty(TempArr);
  Result := SetDynLength(TempArr, 2);    //two bytes for data length
  if not Result then
    Exit;

  TempWord := AProperty.Len;
  TempArr.Content^[1] := TempWord and $FF;

  TempWord := TempWord shr 8;
  TempArr.Content^[0] := TempWord and $FF;

  Result := ConcatDynArrays(TempArr, AProperty);
  Result := Result and ConcatDynArrays(AVarHeader, TempArr);
  SetDynLength(TempArr, 0);
end;


//Single UTF-8 strings are not stored the same way as binary data in a TDynArrayOfByte.
//However, when a string is added as a property, to a header/payload, the string content has to be prefixed by its length (two bytes).
//UTF-8 pairs are already encoded (length + content) in the "Content" field of a binary data var.
function AddUTF8StringToProperties(var AVarHeader: TDynArrayOfByte; var AProperty: string; APropertyIdentifier: Byte): Boolean;
var
  OldLength: DWord;
  TempLen: Word; //Should stay word!  Any range validations should be done before setting TempLen.
begin
  OldLength := AVarHeader.Len;
  TempLen := Length(AProperty);
  Result := SetDynLength(AVarHeader, OldLength + DWord(TempLen) + 3);
  if not Result then
    Exit;

  AVarHeader.Content^[OldLength] := APropertyIdentifier;

  AVarHeader.Content^[OldLength + 2] := TempLen and $FF;
  TempLen := TempLen shr 8;
  AVarHeader.Content^[OldLength + 1] := TempLen and $FF;

  MemMove(@AVarHeader.Content^[OldLength + 3], @AProperty[{$IFDEF IsDesktop}1{$ELSE}0{$ENDIF}], Length(AProperty));
end;


//See also ConvertStringToDynArrayOfByte from DynArrays, for a function which does not add string length to array content.
function AddUTF8StringToPropertiesWithoutIdentifier(var AVarHeader: TDynArrayOfByte; var AProperty: string): Boolean;
var
  OldLength: DWord;
  TempLen: Word; //Should stay word!  Any range validations should be done before setting TempLen.
begin
  OldLength := AVarHeader.Len;
  TempLen := Length(AProperty);
  Result := SetDynLength(AVarHeader, OldLength + DWord(TempLen) + 2);
  if not Result then
    Exit;

  AVarHeader.Content^[OldLength + 1] := TempLen and $FF;
  TempLen := TempLen shr 8;
  AVarHeader.Content^[OldLength] := TempLen and $FF;

  MemMove(@AVarHeader.Content^[OldLength + 2], @AProperty[{$IFDEF IsDesktop}1{$ELSE}0{$ENDIF}], Length(AProperty));
end;


function MQTT_AddUserPropertyToPacket(var AUserProperty: TMQTTProp_UserProperty; var ADestProperties: TDynArrayOfByte): Boolean;
var
  i: LongInt;
begin
  for i := 0 to LongInt(AUserProperty.Len) - 1 do
  begin
    Result := AddBinaryDataToProperties(ADestProperties, AUserProperty.Content^[i]^, CMQTT_UserProperty_PropID);
    if not Result then
      Exit;
  end;

  Result := True;
end;


function MQTT_AddSubscriptionIdentifierToPacket(var ASubscriptionIdentifier: TMQTTProp_SubscriptionIdentifier; var ADestProperties: TDynArrayOfByte): Boolean;
var
  i: LongInt;
begin
  for i := 0 to LongInt(ASubscriptionIdentifier.Len) - 1 do
  begin
    Result := AddVarIntAsDWordToProperties(ADestProperties, ASubscriptionIdentifier.Content^[i], CMQTT_SubscriptionIdentifier_PropID);
    if not Result then
      Exit;
  end;

  Result := True;
end;


function MQTT_VerifyExpectedAndActual_VarAndPayloadLen(AExpectedVarAndPayloadLen, AActualVarAndPayloadLen: DWord): Byte;
begin
  if AExpectedVarAndPayloadLen > AActualVarAndPayloadLen then
    Result := CMQTTDecoderIncompleteBuffer
  else
    //if AExpectedVarAndPayloadLen < AActualVarAndPayloadLen then
    //  Result := CMQTTDecoderOverfilledBuffer     //the library should be able to handle multiple packets in the same buffer, so this verification makes no sense now
    //else
      Result := CMQTTDecoderNoErr;
end;


function BadCtrlPacketDecoder(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var AErr: Word): Boolean;
begin
  Result := True; //no memory error
  AErr := CMQTTDecoderBadCtrlPacket;
end;


//var
//  CtrlPacketDecoders: array[0..15] of TCtrlPacketDecoderFunc;
//
//procedure MQTTRegisterDecoderFunc(AFunc: TCtrlPacketDecoderFunc; AIndex: Byte);
//begin
//  AIndex := AIndex and $F;
//
//  if AIndex = 0 then
//    CtrlPacketDecoders[0] := @BadCtrlPacketDecoder
//  else
//    CtrlPacketDecoders[AIndex] := AFunc;
//end;


////input args: ABuffer
////output args: ADestPacket, AErr
////AErr is 0 if there is no error. It is greater than 0 (an error code), in case something can't be decoded  (can be a bad packet format)
////AErr is later used for FSM control
//function BufferToMQTTControlPacket(var ABuffer: TDynArrayOfByte; var ADestPacket: TMQTTControlPacket; var AErr: Word): Boolean;
//var
//  CtrlByte: Byte;
//begin
//  AErr := CMQTTDecoderNoErr;
//  Result := False;
//
//  if ABuffer.Len = 0 then     //this verification may appear in some the decoder functions, to be able to test the CMQTTDecoderEmptyBuffer error code
//  begin
//    AErr := CMQTTDecoderEmptyBuffer;
//    Result := True;  //set to True, to indicate that there is no memory error, it's just the protocol
//    Exit;
//  end;
//
//  CtrlByte := ABuffer.Content^[0] shr 4;
//  Result := CtrlPacketDecoders[CtrlByte](ABuffer, ADestPacket, AErr);
//
//  // the server may return an error  in ConnAck, Disconnect, Auth etc.
//  // this error should be encoded (in decoder functions) as follows:  AErr := (err from server) shl 8 + CMQTTDecoderServerErr
//end;


  //MQTT_TypeByte = 0;        //Byte
  //MQTT_TypeWord = 1;        //Word
  //MQTT_TypeDoubleWord = 2;  //DWord
  //MQTT_TypeVarInt = 3;      //DWord
  //MQTT_TypeBinaryData = 4;  //array    //also used for string
  //MQTT_TypeBinaryDataArray = 5;  //array of array


//AOffset is automatically incremented by size of output
procedure MQTT_DecodeByte(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: Byte);
begin
  ADest := ABuffer.Content^[AOffset];
  AOffset := AOffset + 1;
end;


//AOffset is automatically incremented by size of output
procedure MQTT_DecodeWord(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: Word);
begin
  ADest := ABuffer.Content^[AOffset] shl 8 + ABuffer.Content^[AOffset + 1];
  AOffset := AOffset + 2;
end;


//AOffset is automatically incremented by size of output
procedure MQTT_DecodeDoubleWord(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: DWord);
begin
  ADest := ABuffer.Content^[AOffset + 0] shl 24 +
           ABuffer.Content^[AOffset + 1] shl 16 +
           ABuffer.Content^[AOffset + 2] shl 8 +
           ABuffer.Content^[AOffset + 3] {shl 0};
  AOffset := AOffset + 4;
end;


//AOffset is automatically incremented by size of output
procedure MQTT_DecodeVarInt(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: DWord);
var
  TempArr4: T4ByteArray;
  VarIntLen: Byte;
  ConvErr: Boolean;
begin
  MemMove(@TempArr4[0], @ABuffer.Content^[AOffset], 4);
  ADest := VarIntToDWord(TempArr4, VarIntLen, ConvErr);
  AOffset := AOffset + VarIntLen;   // VarIntLen may not be valid in case of an error

  //if ConvErr then
  //  ADest := $FFFFFFFF;   //enable this, if the output of CMQTT_DecodeVarInt can be verified, and converted to an error condition
end;


//AOffset is automatically incremented by size of output
procedure MQTT_DecodeBinaryData(var ABuffer: TDynArrayOfByte; var AOffset: DWord; var ADest: TDynArrayOfByte);
var
  Len: Word;
begin
  InitDynArrayToEmpty(ADest);
  MQTT_DecodeWord(ABuffer, AOffset, Len);

  SetDynLength(ADest, DWord(Len));
  MemMove(ADest.Content, @ABuffer.Content^[AOffset], Len);

  AOffset := AOffset + Len;
end;


procedure MQTT_InitControlPacket(var APacket: TMQTTControlPacket);
begin
  InitDynArrayToEmpty(APacket.Header);
  InitDynArrayToEmpty(APacket.VarHeader);
  InitDynArrayToEmpty(APacket.Payload);
end;


procedure MQTT_FreeControlPacket(var APacket: TMQTTControlPacket);
begin
  FreeDynArray(APacket.Header);
  FreeDynArray(APacket.VarHeader);
  FreeDynArray(APacket.Payload);
end;


procedure MQTT_InitConnectProperties(var AProperties: TMQTTConnectProperties);
begin
  AProperties.SessionExpiryInterval := 3600; //[s]      //some valid default values
  AProperties.ReceiveMaximum := CMQTT_DefaultReceiveMaximum;
  AProperties.MaximumPacketSize := 40000;
  AProperties.TopicAliasMaximum := 20;
  AProperties.RequestResponseInformation := 1;
  AProperties.RequestProblemInformation := 1;

  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
  InitDynArrayToEmpty(AProperties.AuthenticationMethod);
  InitDynArrayToEmpty(AProperties.AuthenticationData);
end;


procedure MQTT_FreeConnectProperties(var AProperties: TMQTTConnectProperties);
begin
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
  FreeDynArray(AProperties.AuthenticationMethod);
  FreeDynArray(AProperties.AuthenticationData);
end;


procedure MQTT_InitWillProperties(var AProperties: TMQTTWillProperties);   //used by Connect packet
begin
  AProperties.WillDelayInterval := 6000;
  AProperties.PayloadFormatIndicator := 1;
  AProperties.MessageExpiryInterval := 1800;

  InitDynArrayToEmpty(AProperties.ContentType);
  InitDynArrayToEmpty(AProperties.ResponseTopic);
  InitDynArrayToEmpty(AProperties.CorrelationData);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_FreeWillProperties(var AProperties: TMQTTWillProperties);   //used by Connect packet
begin
  FreeDynArray(AProperties.ContentType);
  FreeDynArray(AProperties.ResponseTopic);
  FreeDynArray(AProperties.CorrelationData);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_InitConnectPayloadContentProperties(var AProperties: TMQTTConnectPayloadContent);   //used by Connect packet
begin
  InitDynArrayToEmpty(AProperties.ClientID);
  InitDynArrayToEmpty(AProperties.WillProperties);
  InitDynArrayToEmpty(AProperties.WillTopic);
  InitDynArrayToEmpty(AProperties.WillPayload);
  InitDynArrayToEmpty(AProperties.UserName);
  InitDynArrayToEmpty(AProperties.Password);
end;


procedure MQTT_FreeConnectPayloadContentProperties(var AProperties: TMQTTConnectPayloadContent);   //used by Connect packet
begin
  FreeDynArray(AProperties.ClientID);
  FreeDynArray(AProperties.WillProperties);
  FreeDynArray(AProperties.WillTopic);
  FreeDynArray(AProperties.WillPayload);
  FreeDynArray(AProperties.UserName);
  FreeDynArray(AProperties.Password);
end;


procedure MQTT_InitConnAckProperties(var AProperties: TMQTTConnAckProperties);
begin
  //AProperties.SessionExpiryInterval := 4; //init to some dummy value, instead of displaying random data on err in logs
  InitDynArrayToEmpty(AProperties.AssignedClientIdentifier);
  InitDynArrayToEmpty(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
  InitDynArrayToEmpty(AProperties.ResponseInformation);
  InitDynArrayToEmpty(AProperties.ServerReference);
  InitDynArrayToEmpty(AProperties.AuthenticationMethod);
  InitDynArrayToEmpty(AProperties.AuthenticationData);
end;


procedure MQTT_FreeConnAckProperties(var AProperties: TMQTTConnAckProperties);
begin
  FreeDynArray(AProperties.AssignedClientIdentifier);
  FreeDynArray(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
  FreeDynArray(AProperties.ResponseInformation);
  FreeDynArray(AProperties.ServerReference);
  FreeDynArray(AProperties.AuthenticationMethod);
  FreeDynArray(AProperties.AuthenticationData);
end;


procedure MQTT_CopyConnAckProperties(var ASrcProperties, ADestProperties: TMQTTConnAckProperties);
begin
  ADestProperties.SessionExpiryInterval := ASrcProperties.SessionExpiryInterval;
  ADestProperties.ReceiveMaximum := ASrcProperties.ReceiveMaximum;
  ADestProperties.MaximumQoS := ASrcProperties.MaximumQoS;
  ADestProperties.RetainAvailable := ASrcProperties.RetainAvailable;
  ADestProperties.MaximumPacketSize := ASrcProperties.MaximumPacketSize;
  ConcatDynArrays(ADestProperties.AssignedClientIdentifier, ASrcProperties.AssignedClientIdentifier);
  ADestProperties.TopicAliasMaximum := ASrcProperties.TopicAliasMaximum;
  ConcatDynArrays(ADestProperties.ReasonString, ASrcProperties.ReasonString);
  {$IFDEF EnUserProperty}
    ConcatDynOfDynOfByteArrays(ADestProperties.UserProperty, ASrcProperties.UserProperty);
  {$ENDIF}
  ADestProperties.WildcardSubscriptionAvailable := ASrcProperties.WildcardSubscriptionAvailable;
  ADestProperties.SubscriptionIdentifierAvailable := ASrcProperties.SubscriptionIdentifierAvailable;
  ADestProperties.SharedSubscriptionAvailable := ASrcProperties.SharedSubscriptionAvailable;
  ADestProperties.ServerKeepAlive := ASrcProperties.ServerKeepAlive;
  ConcatDynArrays(ADestProperties.ResponseInformation, ASrcProperties.ResponseInformation);
  ConcatDynArrays(ADestProperties.ServerReference, ASrcProperties.ServerReference);
  ConcatDynArrays(ADestProperties.AuthenticationMethod, ASrcProperties.AuthenticationMethod);
  ConcatDynArrays(ADestProperties.AuthenticationData, ASrcProperties.AuthenticationData);
end;


procedure MQTT_InitPublishProperties(var AProperties: TMQTTPublishProperties);
begin
  AProperties.MessageExpiryInterval := 3600;
  InitDynArrayToEmpty(AProperties.ContentType);
  InitDynArrayToEmpty(AProperties.ResponseTopic);
  InitDynArrayToEmpty(AProperties.CorrelationData);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
  InitDynArrayOfDWordToEmpty(AProperties.SubscriptionIdentifier);
end;


procedure MQTT_FreePublishProperties(var AProperties: TMQTTPublishProperties);
begin
  FreeDynArray(AProperties.ContentType);
  FreeDynArray(AProperties.ResponseTopic);
  FreeDynArray(AProperties.CorrelationData);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
  FreeDynArrayOfDWord(AProperties.SubscriptionIdentifier);
end;


procedure MQTT_CopyPublishProperties(var ASrcProperties, ADestProperties: TMQTTPublishProperties);
begin
  ADestProperties.PayloadFormatIndicator := ASrcProperties.PayloadFormatIndicator;
  ADestProperties.MessageExpiryInterval := ASrcProperties.MessageExpiryInterval;
  ADestProperties.TopicAlias := ASrcProperties.TopicAlias;
  ConcatDynArrays(ADestProperties.ResponseTopic, ASrcProperties.ResponseTopic);
  ConcatDynArrays(ADestProperties.CorrelationData, ASrcProperties.CorrelationData);
  {$IFDEF EnUserProperty}
    ConcatDynOfDynOfByteArrays(ADestProperties.UserProperty, ASrcProperties.UserProperty);
  {$ENDIF}
  ConcatDynArraysOfDWord(ADestProperties.SubscriptionIdentifier, ASrcProperties.SubscriptionIdentifier);
  ConcatDynArrays(ADestProperties.ContentType, ASrcProperties.ContentType);
end;


procedure MQTT_InitCommonProperties(var AProperties: TMQTTCommonProperties);
begin
  InitDynArrayToEmpty(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_FreeCommonProperties(var AProperties: TMQTTCommonProperties);
begin
  FreeDynArray(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_InitSubscribeProperties(var AProperties: TMQTTSubscribeProperties);
begin
  AProperties.SubscriptionIdentifier := 3; //some valid init value
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_FreeSubscribeProperties(var AProperties: TMQTTSubscribeProperties);
begin
  AProperties.SubscriptionIdentifier := 3000; //something for debugging
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_InitUnsubscribeProperties(var AProperties: TMQTTUnsubscribeProperties);
begin
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_FreeUnsubscribeProperties(var AProperties: TMQTTUnsubscribeProperties);
begin
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_InitDisconnectProperties(var AProperties: TMQTTDisconnectProperties);
begin
  AProperties.SessionExpiryInterval := 3600; //[s]
  InitDynArrayToEmpty(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
  InitDynArrayToEmpty(AProperties.ServerReference);
end;


procedure MQTT_FreeDisconnectProperties(var AProperties: TMQTTDisconnectProperties);
begin
  FreeDynArray(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
  FreeDynArray(AProperties.ServerReference);
end;


procedure MQTT_InitAuthProperties(var AProperties: TMQTTAuthProperties);
begin
  InitDynArrayToEmpty(AProperties.AuthenticationMethod);
  InitDynArrayToEmpty(AProperties.AuthenticationData);
  InitDynArrayToEmpty(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    InitDynOfDynOfByteToEmpty(AProperties.UserProperty);
  {$ENDIF}
end;


procedure MQTT_FreeAuthProperties(var AProperties: TMQTTAuthProperties);
begin
  FreeDynArray(AProperties.AuthenticationMethod);
  FreeDynArray(AProperties.AuthenticationData);
  FreeDynArray(AProperties.ReasonString);
  {$IFDEF EnUserProperty}
    FreeDynOfDynOfByteArray(AProperties.UserProperty);
  {$ENDIF}
end;


//extra functions, for mP compatibility:
{$IFnDEF IsDesktop}
  function CompareMem(AP1, AP2: PByte; ALength: LongInt): Boolean;
  type
    TLocalArray = array[0..0] of Byte;
    PLocalArray = ^TLocalArray;
  var
    i, n: LongInt;
    a1, a2: ^array[0..0] of Byte;
  begin
    Result := True;
    n := ALength - 1;
    a1 := PLocalArray(AP1);
    a2 := PLocalArray(AP2);

    for i := 0 to n do
      if a1^[i] <> a2^[i] then
      begin
        Result := False;
        Exit;
      end;
  end;
{$ENDIF}


procedure MQTTPacketToString(APacketType: Byte; var AResult: string {$IFnDEF IsDesktop}[12]{$ENDIF});
begin
  case APacketType and $F0 of
    CMQTT_UNDEFINED : AResult := 'UNDEFINED'; //0
    CMQTT_CONNECT : AResult := 'CONNECT'; //1
    CMQTT_CONNACK : AResult := 'CONNACK'; //2
    CMQTT_PUBLISH : AResult := 'PUBLISH'; //3
    CMQTT_PUBACK : AResult := 'PUBACK'; //4
    CMQTT_PUBREC : AResult := 'PUBREC'; //5
    CMQTT_PUBREL : AResult := 'PUBREL'; //6
    CMQTT_PUBCOMP : AResult := 'PUBCOMP'; //7
    CMQTT_SUBSCRIBE : AResult := 'SUBSCRIBE'; //8
    CMQTT_SUBACK : AResult := 'SUBACK'; //9
    CMQTT_UNSUBSCRIBE : AResult := 'UNSUBSCRIBE'; //10
    CMQTT_UNSUBACK : AResult := 'UNSUBACK'; //11
    CMQTT_PINGREQ : AResult := 'PINGREQ'; //12
    CMQTT_PINGRESP : AResult := 'PINGRESP'; //13
    CMQTT_DISCONNECT : AResult := 'DISCONNECT'; //14
    CMQTT_AUTH : AResult := 'AUTH'; //15
  end;
end;


{$IFDEF IsDesktop}
  function MQTTPacketToString(APacketType: Byte): string;
  begin
    Result := 'UNKNOWN';
    MQTTPacketToString(APacketType, Result);
  end;
{$ENDIF}


procedure InitVarIntDecoderArr(var ABuffer: TDynArrayOfByte; var DestTempArr4: T4ByteArray);
begin
  MemMove(@DestTempArr4, @CFFArr[0], 4); //init DestTempArr4
  MemMove(@DestTempArr4, @ABuffer.Content^[1], Min32(4, ABuffer.Len - 1));
end;

end.