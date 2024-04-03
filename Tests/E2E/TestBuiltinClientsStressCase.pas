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


unit TestBuiltinClientsStressCase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls,
  fpcunit, testregistry, IdGlobal,
  TestE2EUtils;


type
  TTestE2EBuiltinClientsStressCase = class(TTestE2EBuiltinClientsMain)
  private
    procedure StressTest(AQoS: Byte; ATimeout: Integer = 10 * 1000; AMinDataSize: Integer = 500);  //ms

  published
    procedure StressTest_10s_Qos0;
    procedure StressTest_10s_Qos1;
    procedure StressTest_10s_Qos2;

    procedure StressTest_70s_Qos0;
    procedure StressTest_70s_Qos1;
    procedure StressTest_70s_Qos2;

    procedure StressTest_10s_7kB_Qos0;
    procedure StressTest_10s_7kB_Qos1;
    procedure StressTest_10s_7kB_Qos2;

    procedure StressTest_70s_7kB_Qos0;
    procedure StressTest_70s_7kB_Qos1;
    procedure StressTest_70s_7kB_Qos2;
  end;


implementation


uses
  Math, MQTTClient, MQTTUtils,
  Expectations, ExpectationsDynArrays
  {$IFDEF UsingDynTFT}
    , MemManager
  {$ENDIF}
  ;


procedure TTestE2EBuiltinClientsStressCase.StressTest(AQoS: Byte; ATimeout: Integer = 10 * 1000; AMinDataSize: Integer = 500);  //ms
var
  tk: QWord;
  i, n: Integer;
  PacketName: string;
begin
  Randomize;
  TestPublish_Client0ToClient1_HappyFlow_SendSubscribe;

  n := 0;
  tk := GetTickCount64;
  repeat
    SetLength(FMsgToPublish, AMinDataSize + Random(16));
    for i := 1 to Length(FMsgToPublish) do
      FMsgToPublish[i] := Chr(Random(256));  //hopefully, this content does not affect test result

    TestClients[1].ReceivedPublishedMessage := '-'; //clear before receiving a new one
    try
      TestPublish_Client0ToClient1_HappyFlow_SendPublish(AQoS, FMsgToPublish);
    except
      on E: Exception do
        Expect(E.Message).ToBe('', 'Expected successful publish call at iteration ' + IntToStr(n));
    end;

    Inc(n);
    try
      LoopedExpect(PString(@TestClients[1].ReceivedPublishedMessage), Max(3000, ATimeout)).ToBe(FMsgToPublish, 'Should receive a message of ' + IntToStr(Length(FMsgToPublish)) + ' bytes. Current duration: ' + IntToStr(GetTickCount64 - tk) + 'ms.');
    except
      on E: Exception do
      begin
        MQTTPacketToString(TestClients[1].LatestPacketOnError, PacketName);
        Expect(E.Message).ToBe('', 'Expected to receive published message at iteration ' + IntToStr(n) + '.  Err = ' + IntToStr(TestClients[1].LatestError) + '  ErrOnPacket: ' + PacketName {$IFDEF UsingDynTFT} + '  FreeMem = ' + IntToStr(MM_TotalFreeMemSize) + 'B.' {$ENDIF});
      end;
    end;
  until GetTickCount64 - tk > ATimeout;
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_Qos0;
begin
  StressTest(0);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_Qos1;
begin
  StressTest(1);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_Qos2;
begin
  StressTest(2);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_Qos0;
begin
  StressTest(0, 70 * 1000);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_Qos1;
begin
  StressTest(1, 70 * 1000);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_Qos2;
begin
  StressTest(2, 70 * 1000);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_7kB_Qos0;
begin
  StressTest(0, 10 * 1000, 7 * 1024);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_7kB_Qos1;
begin
  StressTest(1, 10 * 1000, 7 * 1024);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_10s_7kB_Qos2;
begin
  StressTest(2, 10 * 1000, 7 * 1024);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_7kB_Qos0;
begin
  StressTest(0, 70 * 1000, 7 * 1024);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_7kB_Qos1;
begin
  StressTest(1, 70 * 1000, 7 * 1024);
end;


procedure TTestE2EBuiltinClientsStressCase.StressTest_70s_7kB_Qos2;
begin
  StressTest(2, 70 * 1000, 7 * 1024);
end;


initialization

  RegisterTest(TTestE2EBuiltinClientsStressCase);
end.

