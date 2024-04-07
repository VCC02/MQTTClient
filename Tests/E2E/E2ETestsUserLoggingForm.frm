object frmE2ETestsUserLogging: TfrmE2ETestsUserLogging
  Left = 373
  Height = 441
  Top = 185
  Width = 713
  Caption = 'E2ETests - User Logging'
  ClientHeight = 441
  ClientWidth = 713
  LCLVersion = '8.2'
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object btnCopyLogToClipboard: TButton
    Left = 565
    Height = 25
    Top = 272
    Width = 147
    Anchors = [akRight, akBottom]
    Caption = 'Copy log to clipboard'
    TabOrder = 0
    OnClick = btnCopyLogToClipboardClick
  end
  object PageControlLogging: TPageControl
    Left = 0
    Height = 265
    Top = 0
    Width = 712
    ActivePage = tsRawLog
    Anchors = [akTop, akLeft, akRight, akBottom]
    TabIndex = 0
    TabOrder = 1
    object tsRawLog: TTabSheet
      Caption = 'Raw log'
      ClientHeight = 237
      ClientWidth = 704
      object memLog: TMemo
        Left = 0
        Height = 233
        Top = 0
        Width = 704
        Anchors = [akTop, akLeft, akRight, akBottom]
        Font.CharSet = ANSI_CHARSET
        Font.Height = -13
        Font.Name = 'Courier New'
        Font.Pitch = fpFixed
        Font.Quality = fqDraft
        ParentFont = False
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
      end
    end
    object tsEntries: TTabSheet
      Caption = 'Entries'
      ClientHeight = 252
      ClientWidth = 704
      object vstLog: TVirtualStringTree
        Left = 0
        Height = 248
        Top = 0
        Width = 704
        DefaultText = 'Node'
        Header.AutoSizeIndex = 0
        Header.Columns = <>
        Header.MainColumn = -1
        TabOrder = 0
        TreeOptions.SelectionOptions = [toFullRowSelect]
        OnGetText = vstLogGetText
      end
    end
  end
  object btnClearLog: TButton
    Left = 480
    Height = 25
    Top = 272
    Width = 75
    Anchors = [akRight, akBottom]
    Caption = 'Clear log...'
    TabOrder = 2
    OnClick = btnClearLogClick
  end
  object btnDrawMemContent: TButton
    Left = 352
    Height = 25
    Hint = 'This also logs info about overlapped areas.'
    Top = 272
    Width = 115
    Anchors = [akRight, akBottom]
    Caption = 'Draw mem content'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 3
    OnClick = btnDrawMemContentClick
  end
  object scrboxMem: TScrollBox
    Left = 0
    Height = 128
    Top = 305
    Width = 712
    HorzScrollBar.Increment = 68
    HorzScrollBar.Page = 680
    HorzScrollBar.Smooth = True
    HorzScrollBar.Tracking = True
    VertScrollBar.Increment = 12
    VertScrollBar.Page = 120
    VertScrollBar.Smooth = True
    VertScrollBar.Tracking = True
    Anchors = [akLeft, akRight, akBottom]
    ClientHeight = 124
    ClientWidth = 708
    TabOrder = 4
    object imgMem: TImage
      Left = 0
      Height = 114
      Hint = 'Free areas are marked with yellow.'#13#10'Overlapped areas are marked with bright red.'
      Top = 6
      Width = 680
      ParentShowHint = False
      ShowHint = True
    end
  end
  object chkDrawMemWithTimer: TCheckBox
    Left = 200
    Height = 19
    Hint = 'When checked, the memory (free blocks info is drawn by a timer,'
    Top = 278
    Width = 133
    Anchors = [akRight, akBottom]
    Caption = 'Draw mem with timer'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
    OnChange = chkDrawMemWithTimerChange
  end
  object tmrLog: TTimer
    Interval = 10
    OnTimer = tmrLogTimer
    Left = 445
    Top = 184
  end
  object tmrUpdateVST: TTimer
    Enabled = False
    Interval = 300
    OnTimer = tmrUpdateVSTTimer
    Left = 528
    Top = 184
  end
  object tmrDrawMem: TTimer
    Enabled = False
    Interval = 100
    OnTimer = tmrDrawMemTimer
    Left = 296
    Top = 184
  end
end
