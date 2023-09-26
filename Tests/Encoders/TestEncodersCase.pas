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



unit TestEncodersCase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  TEncodersCase = class(TTestCase)
  published
    procedure Test_DWordToVarInt_Byte_LowerThan128;
    procedure Test_DWordToVarInt_Byte_GreaterThan128;
    procedure Test_DWordToVarInt_Word_LowerThan16384;
    procedure Test_DWordToVarInt_Word_GreaterThan16384;
    procedure Test_DWordToVarInt_DWord_LowerThan2097152;
    procedure Test_DWordToVarInt_DWord_GreaterThan2097152;

    procedure Test_AddDoubleWordToProperties_OnEmptyHeader;
    procedure Test_AddDoubleWordToProperties_OnExistingHeader;
    procedure Test_AddWordToProperties_OnEmptyHeader;
    procedure Test_AddWordToProperties_OnExistingHeader;
    procedure Test_AddByteToProperties_OnEmptyHeader;
    procedure Test_AddByteToProperties_OnExistingHeader;

    procedure Test_AddVarIntToProperties_OnEmptyHeader;
    procedure Test_AddVarIntToProperties_OnExistingHeader;
    procedure Test_AddVarIntToPropertiesWithoutIdentifier_OnEmptyHeader;
    procedure Test_AddVarIntToPropertiesWithoutIdentifier_OnExistingHeader;
    procedure Test_AddVarIntAsDWordToProperties_OnEmptyHeader;
    procedure Test_AddVarIntAsDWordToProperties_OnExistingHeader;
    procedure Test_AddVarIntAsDWordToPropertiesWithoutIdentifier_OnEmptyHeader;
    procedure Test_AddVarIntAsDWordToPropertiesWithoutIdentifier_OnExistingHeader;

    procedure Test_AddBinaryDataToProperties_OnEmptyHeader;
    procedure Test_AddBinaryDataToProperties_OnExistingHeader;
    procedure Test_AddBinaryDataToPropertiesWithoutIdentifier_OnEmptyHeader;
    procedure Test_AddBinaryDataToPropertiesWithoutIdentifier_OnExistingHeader;

    procedure Test_AddUTF8StringToProperties_OnEmptyHeader;
    procedure Test_AddUTF8StringToProperties_OnExistingHeader;
    procedure Test_AddUTF8StringToPropertiesWithoutIdentifier_OnEmptyHeader;
    procedure Test_AddUTF8StringToPropertiesWithoutIdentifier_OnExistingHeader;

    procedure Test_ConvertStringToDynArrayOfByte;
  end;

implementation


uses
  DynArrays, MQTTUtils, Expectations;


procedure TEncodersCase.Test_DWordToVarInt_Byte_LowerThan128;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(30, Res);
  Expect(Len).ToBe(1);
  Expect(Res[0]).ToBe(30);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(30);
  Expect(DecodedLen).ToBe(1);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_DWordToVarInt_Byte_GreaterThan128;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(190, Res);
  Expect(Len).ToBe(2);
  Expect(@Res, 2).ToBe(@[190, 1]);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(190);
  Expect(DecodedLen).ToBe(2);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_DWordToVarInt_Word_LowerThan16384;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(60 shl 8 + 192, Res);
  Expect(Len).ToBe(2);
  Expect(@Res, 2).ToBe(@[192, 121]);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(60 shl 8 + 192);
  Expect(DecodedLen).ToBe(2);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_DWordToVarInt_Word_GreaterThan16384;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(65 shl 8 + 193, Res);
  Expect(Len).ToBe(3);
  Expect(@Res, 3).ToBe(@[193, 131, 1]);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(65 shl 8 + 193);
  Expect(DecodedLen).ToBe(3);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_DWordToVarInt_DWord_LowerThan2097152;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(30 shl 16 + 85 shl 8 + 194, Res);
  Expect(Len).ToBe(3);
  Expect(@Res, 3).ToBe(@[194, 171, 121]);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(30 shl 16 + 85 shl 8 + 194);
  Expect(DecodedLen).ToBe(3);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_DWordToVarInt_DWord_GreaterThan2097152;
var
  Res: T4ByteArray;
  Len: Byte;
  DecodedValue: DWord;
  DecErr: Boolean;
  DecodedLen: Byte;
begin
  Len := DWordToVarInt(130 shl 16 + 85 shl 8 + 194, Res);
  Expect(Len).ToBe(4);
  Expect(@Res, 4).ToBe(@[194, 171, 137, 4]);

  DecodedValue := VarIntToDWord(Res, DecodedLen, DecErr);
  Expect(DecodedValue).ToBe(130 shl 16 + 85 shl 8 + 194);
  Expect(DecodedLen).ToBe(4);
  Expect(DecErr).ToBe(False);
end;


procedure TEncodersCase.Test_AddDoubleWordToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(AddDoubleWordToProperties(TempHeader, 50 shl 24 + 130 shl 16 + 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[40, 50, 130, 85, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddDoubleWordToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddDoubleWordToProperties(TempHeader, 50 shl 24 + 130 shl 16 + 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(8);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 40, 50, 130, 85, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddWordToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(AddWordToProperties(TempHeader, 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(3);
    Expect(@TempHeader.Content^, 3).ToBe(@[40, 85, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddWordToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddWordToProperties(TempHeader, 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(6);
    Expect(@TempHeader.Content^, 6).ToBe(@[5, 6, 7, 40, 85, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddByteToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(AddByteToProperties(TempHeader, 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(2);
    Expect(@TempHeader.Content^, 2).ToBe(@[40, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddByteToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddByteToProperties(TempHeader, 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[5, 6, 7, 40, 194]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  Res: T4ByteArray;
  Len: Byte;
begin
  InitDynArrayToEmpty(TempHeader);
  Len := DWordToVarInt(130 shl 16 + 85 shl 8 + 194, Res);
  try
    Expect(AddVarIntToProperties(TempHeader, Res, Len, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[40, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  Res: T4ByteArray;
  Len: Byte;
begin
  InitDynArrayToEmpty(TempHeader);
  Len := DWordToVarInt(130 shl 16 + 85 shl 8 + 194, Res);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddVarIntToProperties(TempHeader, Res, Len, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(8);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 40, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntToPropertiesWithoutIdentifier_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  Res: T4ByteArray;
  Len: Byte;
begin
  InitDynArrayToEmpty(TempHeader);
  Len := DWordToVarInt(130 shl 16 + 85 shl 8 + 194, Res);
  try
    Expect(AddVarIntToPropertiesWithoutIdentifier(TempHeader, Res, Len)).ToBe(True);
    Expect(TempHeader.Len).ToBe(4);
    Expect(@TempHeader.Content^, 4).ToBe(@[194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntToPropertiesWithoutIdentifier_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  Res: T4ByteArray;
  Len: Byte;
begin
  InitDynArrayToEmpty(TempHeader);
  Len := DWordToVarInt(130 shl 16 + 85 shl 8 + 194, Res);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddVarIntToPropertiesWithoutIdentifier(TempHeader, Res, Len)).ToBe(True);
    Expect(TempHeader.Len).ToBe(7);
    Expect(@TempHeader.Content^, 7).ToBe(@[5, 6, 7, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntAsDWordToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(AddVarIntAsDWordToProperties(TempHeader, 130 shl 16 + 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[40, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntAsDWordToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddVarIntAsDWordToProperties(TempHeader, 130 shl 16 + 85 shl 8 + 194, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(8);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 40, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntAsDWordToPropertiesWithoutIdentifier_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(AddVarIntAsDWordToPropertiesWithoutIdentifier(TempHeader, 130 shl 16 + 85 shl 8 + 194)).ToBe(True);
    Expect(TempHeader.Len).ToBe(4);
    Expect(@TempHeader.Content^, 4).ToBe(@[194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddVarIntAsDWordToPropertiesWithoutIdentifier_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    Expect(AddVarIntAsDWordToPropertiesWithoutIdentifier(TempHeader, 130 shl 16 + 85 shl 8 + 194)).ToBe(True);
    Expect(TempHeader.Len).ToBe(7);
    Expect(@TempHeader.Content^, 7).ToBe(@[5, 6, 7, 194, 171, 137, 4]);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddBinaryDataToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  BinaryData: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  InitDynArrayToEmpty(BinaryData);
  try
    SetDynLength(BinaryData, 3);
    BinaryData.Content^[0] := 25;
    BinaryData.Content^[1] := 26;
    BinaryData.Content^[2] := 27;

    Expect(AddBinaryDataToProperties(TempHeader, BinaryData, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(6);
    Expect(@TempHeader.Content^, 6).ToBe(@[40, 0, 3, 25, 26, 27]);
  finally
    SetDynLength(TempHeader, 0);
    SetDynLength(BinaryData, 0);
  end;
end;


procedure TEncodersCase.Test_AddBinaryDataToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  BinaryData: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  InitDynArrayToEmpty(BinaryData);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    SetDynLength(BinaryData, 3);
    BinaryData.Content^[0] := 25;
    BinaryData.Content^[1] := 26;
    BinaryData.Content^[2] := 27;

    Expect(AddBinaryDataToProperties(TempHeader, BinaryData, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(9);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 40, 0, 3, 25, 26, 27]);
  finally
    SetDynLength(TempHeader, 0);
    SetDynLength(BinaryData, 0);
  end;
end;


procedure TEncodersCase.Test_AddBinaryDataToPropertiesWithoutIdentifier_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  BinaryData: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  InitDynArrayToEmpty(BinaryData);
  try
    SetDynLength(BinaryData, 3);
    BinaryData.Content^[0] := 25;
    BinaryData.Content^[1] := 26;
    BinaryData.Content^[2] := 27;

    Expect(AddBinaryDataToPropertiesWithoutIdentifier(TempHeader, BinaryData)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[0, 3, 25, 26, 27]);
  finally
    SetDynLength(TempHeader, 0);
    SetDynLength(BinaryData, 0);
  end;
end;


procedure TEncodersCase.Test_AddBinaryDataToPropertiesWithoutIdentifier_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  BinaryData: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  InitDynArrayToEmpty(BinaryData);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    SetDynLength(BinaryData, 3);
    BinaryData.Content^[0] := 25;
    BinaryData.Content^[1] := 26;
    BinaryData.Content^[2] := 27;

    Expect(AddBinaryDataToPropertiesWithoutIdentifier(TempHeader, BinaryData)).ToBe(True);
    Expect(TempHeader.Len).ToBe(8);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 0, 3, 25, 26, 27]);
  finally
    SetDynLength(TempHeader, 0);
    SetDynLength(BinaryData, 0);
  end;
end;


procedure TEncodersCase.Test_AddUTF8StringToProperties_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  TempString: string;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    TempString := 'abc';

    Expect(AddUTF8StringToProperties(TempHeader, TempString, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(6);
    Expect(@TempHeader.Content^, 6).ToBe(@[40, 0, 3, 'a', 'b', 'c']);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddUTF8StringToProperties_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  TempString: string;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    TempString := 'abc';

    Expect(AddUTF8StringToProperties(TempHeader, TempString, 40)).ToBe(True);
    Expect(TempHeader.Len).ToBe(9);
    Expect(@TempHeader.Content^, 9).ToBe(@[5, 6, 7, 40, 0, 3, 'a', 'b', 'c']);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddUTF8StringToPropertiesWithoutIdentifier_OnEmptyHeader;
var
  TempHeader: TDynArrayOfByte;
  TempString: string;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    TempString := 'abc';

    Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempHeader, TempString)).ToBe(True);
    Expect(TempHeader.Len).ToBe(5);
    Expect(@TempHeader.Content^, 5).ToBe(@[0, 3, 'a', 'b', 'c']);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_AddUTF8StringToPropertiesWithoutIdentifier_OnExistingHeader;
var
  TempHeader: TDynArrayOfByte;
  TempString: string;
begin
  InitDynArrayToEmpty(TempHeader);
  SetDynLength(TempHeader, 3);
  try
    TempHeader.Content^[0] := 5;
    TempHeader.Content^[1] := 6;
    TempHeader.Content^[2] := 7;

    TempString := 'abc';

    Expect(AddUTF8StringToPropertiesWithoutIdentifier(TempHeader, TempString)).ToBe(True);
    Expect(TempHeader.Len).ToBe(8);
    Expect(@TempHeader.Content^, 8).ToBe(@[5, 6, 7, 0, 3, 'a', 'b', 'c']);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


procedure TEncodersCase.Test_ConvertStringToDynArrayOfByte;
var
  TempHeader: TDynArrayOfByte;
begin
  InitDynArrayToEmpty(TempHeader);
  try
    Expect(StringToDynArrayOfByte('abc', TempHeader)).ToBe(True);
    Expect(TempHeader.Len).ToBe(3);
    Expect(@TempHeader.Content^, 3).ToBe(@['a', 'b', 'c']);
  finally
    SetDynLength(TempHeader, 0);
  end;
end;


initialization

  RegisterTest(TEncodersCase);
end.

