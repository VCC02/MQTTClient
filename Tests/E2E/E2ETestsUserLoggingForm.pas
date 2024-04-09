{
    Copyright (C) 2024 VCC
    creation date: 06 Apr 2024
    initial release date: 07 Apr 2024

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

//Requirements:
//This logging window requires some extra code to be added to MemManager.pas (the DynTFT version):
{
{$IFNDEF IsMCU}
  procedure MM_GetBlock(AIndex: DWord; var AOffset, ASize: Int64);
  begin
    if AIndex > NR_FREE_BLOCKS - 1 then
      raise Exception.Create('MM Block out of range.');

    if MM_FreeMemTable[AIndex].Pointer = 0 then
      AOffset := 0
    else
      AOffset := MM_FreeMemTable[AIndex].Pointer - HEAP_START;

    ASize := MM_FreeMemTable[AIndex].Size;
  end;
{$ENDIF}
}


unit E2ETestsUserLoggingForm;

{$mode ObjFPC}{$H+}

interface

uses
  LCLIntf, LCLType, Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, PollingFIFO, VirtualTrees
  {$IFDEF UsingDynTFT}    //UsingDynTFT should be defined in all DynTFT projects (MCU or Desktop), which will include this unit (DynArrays).
    , MemManager          //there is only the DynTFT type of MM for MCU
  {$ENDIF}
  ;

type

  { TfrmE2ETestsUserLogging }

  TfrmE2ETestsUserLogging = class(TForm)
    btnCopyLogToClipboard: TButton;
    btnClearLog: TButton;
    btnDrawMemContent: TButton;
    chkDrawMemWithTimer: TCheckBox;
    imgMem: TImage;
    memLog: TMemo;
    PageControlLogging: TPageControl;
    scrboxMem: TScrollBox;
    tmrDrawMem: TTimer;
    tmrUpdateVST: TTimer;
    tsRawLog: TTabSheet;
    tsEntries: TTabSheet;
    tmrLog: TTimer;
    vstLog: TVirtualStringTree;
    procedure btnClearLogClick(Sender: TObject);
    procedure btnCopyLogToClipboardClick(Sender: TObject);
    procedure btnDrawMemContentClick(Sender: TObject);
    procedure chkDrawMemWithTimerChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrDrawMemTimer(Sender: TObject);
    procedure tmrLogTimer(Sender: TObject);
    procedure tmrUpdateVSTTimer(Sender: TObject);
    procedure vstLogGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
  private
    FLoggingFIFO: TPollingFIFO;

    procedure AddMemInfoToLog;
    procedure DrawMem;
  public

  end;

var
  frmE2ETestsUserLogging: TfrmE2ETestsUserLogging;

procedure AddToUserLog(s: string);


implementation

uses
  Clipbrd;

{$R *.frm}

{$IFDEF UsingDynTFT}
  {$IFDEF MMFreeBlocks}
    const NR_FREE_BLOCKS = {$I MMFreeBlocks.inc};
  {$ELSE}
    const NR_FREE_BLOCKS = 20;
  {$ENDIF}

  {$IFDEF MaxMMAtProjectLevel}
    const HEAP_SIZE = {$I MaxMM.inc};  //relative to the project file  (in the same folder as the project file)
  {$ELSE}
    const HEAP_SIZE = {$I ..\MaxMM.inc};  //relative to the project file
  {$ENDIF}
{$ENDIF}

procedure AddToUserLog(s: string);
begin
  frmE2ETestsUserLogging.FLoggingFIFO.Put(s);
end;

{ TfrmE2ETestsUserLogging }


procedure TfrmE2ETestsUserLogging.btnCopyLogToClipboardClick(Sender: TObject);
begin
  Clipboard.AsText := memLog.Lines.Text;
end;


procedure TfrmE2ETestsUserLogging.AddMemInfoToLog;
{$IFDEF UsingDynTFT}
  var
    i, j: Integer;
    Offset, Size, Offset2, Size2: Int64;
{$ENDIF}
begin
  {$IFDEF UsingDynTFT}
    for i := 0 to NR_FREE_BLOCKS - 1 do
    begin
      MM_GetBlock(i, Offset, Size);    //If the compiler returns an error about not knowing what is MM_GetBlock, then users have to add it to MemManager.pas. See requirements above.

      if Size > 0 then
        AddToUserLog('Offset: ' + IntToStr(Offset) + '  Size: ' + IntToStr(Size));
    end;

    for i := 0 to NR_FREE_BLOCKS - 1 do
    begin
      MM_GetBlock(i, Offset, Size);

      if Size > 0 then
        for j := i + 1 to NR_FREE_BLOCKS - 1 do
        begin
          MM_GetBlock(j, Offset2, Size2);

          if Size2 > 0 then
            if (Offset2 < Offset + Size) and (Offset2 >= Offset) then
              AddToUserLog('Found overlapped blocks:' +
                           '  Offset2 in [Offset .. Offset+Size]: '  +
                           '  ' + IntToStr(Offset2) + ' in [' + IntToStr(Offset) + ' .. ' + IntToStr(Offset + Size) + ']:  '  +
                           '  Offset + Size = ' + IntToStr(Offset) + '+' + IntToStr(Size) + '=' + IntToStr(Offset + Size) +
                           '  Offset2 + Size2 = ' + IntToStr(Offset2) + '+' + IntToStr(Size2) + '=' + IntToStr(Offset2 + Size2)
                           );
        end;
    end;
  {$ELSE}
    AddToUserLog('MemManager not used.');
  {$ENDIF}
end;

{$IFDEF UsingDynTFT}
  type
    TOverlappedEntry = record
      Offset, Size: Int64;
    end;

    TOverlappedEntryArr = array of TOverlappedEntry;
{$ENDIF}

procedure TfrmE2ETestsUserLogging.DrawMem;
{$IFDEF UsingDynTFT}
  var
    i, j, y: Integer;
    BlockWidth, BlockLeft, BlockRight: Integer;
    Offset, Size, Offset2, Size2: Int64;
    OverlappedEntries: TOverlappedEntryArr;
{$ENDIF}
begin
  {$IFDEF UsingDynTFT}
    imgMem.Width := 65536; //max working value is 100000
    imgMem.Height := 100;
    imgMem.Picture.Bitmap.PixelFormat := pf24bit;
    imgMem.Picture.Bitmap.Width := imgMem.Width;
    imgMem.Picture.Bitmap.Height := imgMem.Height;

    imgMem.Canvas.Pen.Style := psClear;
    imgMem.Canvas.Brush.Style := bsSolid;
    imgMem.Canvas.Brush.Color := $004000;  //assume area is used
    imgMem.Picture.Bitmap.Canvas.Rectangle(0, 0, imgMem.Width, imgMem.Height);

    imgMem.Canvas.Brush.Color := clYellow;
    for i := 0 to NR_FREE_BLOCKS - 1 do
    begin
      MM_GetBlock(i, Offset, Size);    //If the compiler returns an error about not knowing what is MM_GetBlock, then users have to add it to MemManager.pas. See requirements above.

      BlockWidth := Round((Size {* 65536} shl 16) / HEAP_SIZE); //px
      if BlockWidth > 0 then
      begin
        if BlockWidth < 2 then
          BlockWidth := 2;

        BlockLeft := Round((Offset {* 65536} shl 16) / HEAP_SIZE); //px
        BlockRight := BlockLeft + BlockWidth;  // +/- 1

        y := (i mod 4) * 20;
        imgMem.Canvas.Rectangle(BlockLeft, 20 + y, BlockRight, 20 + y + 20);
      end;
    end;

    //get overlapped blocks:
    SetLength(OverlappedEntries, 0);
    for i := 0 to NR_FREE_BLOCKS - 1 do
    begin
      MM_GetBlock(i, Offset, Size);

      if Size > 0 then
        for j := i + 1 to NR_FREE_BLOCKS - 1 do
        begin
          MM_GetBlock(j, Offset2, Size2);

          if Size2 > 0 then
            if (Offset2 < Offset + Size) and (Offset2 >= Offset) then
            begin
              SetLength(OverlappedEntries, Length(OverlappedEntries) + 1);
              OverlappedEntries[Length(OverlappedEntries) - 1].Offset := Offset;
              OverlappedEntries[Length(OverlappedEntries) - 1].Size := Size;

              SetLength(OverlappedEntries, Length(OverlappedEntries) + 1);
              OverlappedEntries[Length(OverlappedEntries) - 1].Offset := Offset2;
              OverlappedEntries[Length(OverlappedEntries) - 1].Size := Size2;
            end;
        end;
    end;

    //draw overlapped blocks
    imgMem.Canvas.Brush.Color := $4444FF;  //bright red
    for i := 0 to Length(OverlappedEntries) - 1 do
    begin
      Offset := OverlappedEntries[i].Offset;
      Size := OverlappedEntries[i].Size;

      BlockWidth := Round((Size {* 65536} shl 16) / HEAP_SIZE); //px         //ToDo: refactoring
      if BlockWidth > 0 then
      begin
        if BlockWidth < 2 then
          BlockWidth := 2;

        BlockLeft := Round((Offset {* 65536} shl 16) / HEAP_SIZE); //px
        BlockRight := BlockLeft + BlockWidth;  // +/- 1

        y := (i mod 4) * 4;
        imgMem.Canvas.Rectangle(BlockLeft, y, BlockRight, y + 8);
      end;
    end;

    SetLength(OverlappedEntries, 0);
  {$ELSE}

  {$ENDIF}
end;


procedure TfrmE2ETestsUserLogging.btnDrawMemContentClick(Sender: TObject);
begin
  AddMemInfoToLog;
  DrawMem;
end;


procedure TfrmE2ETestsUserLogging.chkDrawMemWithTimerChange(Sender: TObject);
begin
  tmrDrawMem.Enabled := chkDrawMemWithTimer.Checked;
end;


procedure TfrmE2ETestsUserLogging.btnClearLogClick(Sender: TObject);
begin
  if MessageBox(Handle, 'Are you sure you want to clear the log?', PChar(Application.Title), MB_ICONQUESTION + MB_YESNO) = IDYES then
  begin
    vstLog.RootNodeCount := 0;
    memLog.Lines.Clear;
    vstLog.Repaint;
  end;
end;


procedure TfrmE2ETestsUserLogging.FormCreate(Sender: TObject);
begin
  FLoggingFIFO := TPollingFIFO.Create;
end;


procedure TfrmE2ETestsUserLogging.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FLoggingFIFO);
end;


procedure TfrmE2ETestsUserLogging.tmrDrawMemTimer(Sender: TObject);
begin
  DrawMem;
end;


procedure TfrmE2ETestsUserLogging.tmrLogTimer(Sender: TObject);
var
  TempData: TStringList;
begin
  if FLoggingFIFO.GetLength > 0 then
  begin
    TempData := TStringList.Create;
    try
      FLoggingFIFO.PopAll(TempData);

      memLog.Lines.BeginUpdate;
      try
        memLog.Lines.AddStrings(TempData);
      finally
        memLog.Lines.EndUpdate;
      end;

      vstLog.RootNodeCount := memLog.Lines.Count;
      tmrUpdateVST.Enabled := True;
    finally
      TempData.Free;
    end;
  end;
end;


procedure TfrmE2ETestsUserLogging.tmrUpdateVSTTimer(Sender: TObject);
begin
  tmrUpdateVST.Enabled := False;
  vstLog.Repaint;
end;


procedure TfrmE2ETestsUserLogging.vstLogGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
begin
  CellText := memLog.Lines.Strings[Node^.Index];
end;


end.

