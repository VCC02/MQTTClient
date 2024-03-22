object frmMQTTClientAppMain: TfrmMQTTClientAppMain
  Left = 387
  Height = 317
  Top = 43
  Width = 900
  Caption = 'MQTT Client App'
  ClientHeight = 317
  ClientWidth = 900
  LCLVersion = '8.2'
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object btnConnect: TButton
    Left = 152
    Height = 25
    Top = 240
    Width = 75
    Caption = 'Connect'
    ParentFont = False
    TabOrder = 0
    OnClick = btnConnectClick
  end
  object memLog: TMemo
    Left = 8
    Height = 186
    Top = 8
    Width = 881
    Lines.Strings = (
      'memLog'
    )
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
    WordWrap = False
  end
  object lbeAddress: TLabeledEdit
    Left = 8
    Height = 23
    Top = 216
    Width = 80
    EditLabel.Height = 15
    EditLabel.Width = 80
    EditLabel.Caption = 'Address'
    EditLabel.ParentFont = False
    ParentFont = False
    TabOrder = 2
    Text = '127.0.0.1'
  end
  object lbePort: TLabeledEdit
    Left = 99
    Height = 23
    Top = 216
    Width = 45
    EditLabel.Height = 15
    EditLabel.Width = 45
    EditLabel.Caption = 'Port'
    EditLabel.ParentFont = False
    ParentFont = False
    TabOrder = 3
    Text = '1883'
  end
  object lbeUser: TLabeledEdit
    Left = 152
    Height = 23
    Top = 216
    Width = 71
    EditLabel.Height = 15
    EditLabel.Width = 71
    EditLabel.Caption = 'User'
    EditLabel.ParentFont = False
    ParentFont = False
    TabOrder = 4
    Text = 'VCC'
  end
  object btnDisconnect: TButton
    Left = 152
    Height = 25
    Top = 272
    Width = 75
    Caption = 'Disconnect'
    ParentFont = False
    TabOrder = 5
    OnClick = btnDisconnectClick
  end
  object btnSetToLocalhost: TButton
    Left = 8
    Height = 25
    Top = 240
    Width = 88
    Caption = 'Set to localhost'
    TabOrder = 6
    OnClick = btnSetToLocalhostClick
  end
  object grpPublish: TGroupBox
    Left = 240
    Height = 113
    Top = 201
    Width = 264
    Caption = 'Publish'
    ClientHeight = 93
    ClientWidth = 260
    Color = 14678015
    ParentBackground = False
    ParentColor = False
    TabOrder = 7
    object lbeTopicNameToPublish: TLabeledEdit
      Left = 8
      Height = 23
      Top = 16
      Width = 113
      EditLabel.Height = 15
      EditLabel.Width = 113
      EditLabel.Caption = 'Topic name'
      TabOrder = 0
      Text = 'SomeTopic'
    end
    object lbeAppMsgToPublish: TLabeledEdit
      Left = 8
      Height = 23
      Top = 64
      Width = 113
      EditLabel.Height = 15
      EditLabel.Width = 113
      EditLabel.Caption = 'Application Message'
      TabOrder = 1
      Text = 'Some message'
    end
    object btnPublish: TButton
      Left = 192
      Height = 25
      Top = 16
      Width = 59
      Caption = 'Publish'
      Enabled = False
      TabOrder = 2
      OnClick = btnPublishClick
    end
    object chkAddInc: TCheckBox
      Left = 128
      Height = 19
      Hint = 'Appends an incremented number to the message.'
      Top = 68
      Width = 59
      Caption = 'Add Inc'
      Checked = True
      ParentShowHint = False
      ShowHint = True
      State = cbChecked
      TabOrder = 3
    end
    object cmbQoS: TComboBox
      Left = 128
      Height = 21
      Top = 16
      Width = 48
      ItemHeight = 15
      ItemIndex = 2
      Items.Strings = (
        '0'
        '1'
        '2'
      )
      Style = csOwnerDrawFixed
      TabOrder = 4
      Text = '2'
    end
    object lblQoS: TLabel
      Left = 128
      Height = 15
      Top = -3
      Width = 22
      Caption = 'QoS'
    end
  end
  object grpSubscription: TGroupBox
    Left = 512
    Height = 113
    Top = 201
    Width = 144
    Caption = 'Subscription'
    ClientHeight = 93
    ClientWidth = 140
    Color = 16775135
    ParentBackground = False
    ParentColor = False
    TabOrder = 8
    object btnSubscribeTo: TButton
      Left = 8
      Height = 25
      Top = 16
      Width = 75
      Caption = 'Subscribe to'
      Enabled = False
      TabOrder = 0
      OnClick = btnSubscribeToClick
    end
    object lbeTopicName: TLabeledEdit
      Left = 8
      Height = 23
      Top = 64
      Width = 128
      EditLabel.Height = 15
      EditLabel.Width = 128
      EditLabel.Caption = 'Topic name'
      TabOrder = 1
      Text = 'SomeTopic'
    end
    object btnUnSubscribeFrom: TButton
      Left = 88
      Height = 25
      Top = 16
      Width = 48
      Caption = 'UnSub'
      Enabled = False
      TabOrder = 2
      OnClick = btnUnSubscribeFromClick
    end
  end
  object prbUsedMemory: TProgressBar
    Left = 8
    Height = 12
    Top = 302
    Width = 136
    TabOrder = 9
  end
  object grpStatistics: TGroupBox
    Left = 664
    Height = 113
    Top = 201
    Width = 225
    Caption = 'Statistics'
    ClientHeight = 93
    ClientWidth = 221
    TabOrder = 10
    object lblServerToClientBufferSizeInfo: TLabel
      Left = 8
      Height = 15
      Top = 16
      Width = 132
      Caption = 'ServerToClientBufferSize:'
    end
    object lblServerToClientBufferSize: TLabel
      Left = 184
      Height = 15
      Top = 16
      Width = 18
      Caption = '000'
    end
    object lblClientToServerPacketIDCountInfo: TLabel
      Left = 8
      Height = 15
      Hint = 'One value is preallocated (i.e. 0).'
      Top = 32
      Width = 159
      Caption = 'ClientToServerPacketIDCount:'
      ParentShowHint = False
      ShowHint = True
    end
    object lblClientToServerIDCount: TLabel
      Left = 184
      Height = 15
      Top = 32
      Width = 18
      Caption = '000'
    end
    object lblServerToClientPacketIDCountInfo: TLabel
      Left = 8
      Height = 15
      Top = 48
      Width = 159
      Caption = 'ServerToClientPacketIDCount:'
    end
    object lblServerToClientIDCount: TLabel
      Left = 184
      Height = 15
      Top = 48
      Width = 18
      Caption = '000'
    end
    object lblClientToServerBufferSizeInfo: TLabel
      Left = 8
      Height = 15
      Top = 0
      Width = 132
      Caption = 'ClientToServerBufferSize:'
    end
    object lblClientToServerBufferSize: TLabel
      Left = 184
      Height = 15
      Top = 0
      Width = 18
      Caption = '000'
    end
  end
  object btnPing: TButton
    Left = 99
    Height = 25
    Top = 240
    Width = 45
    Caption = 'Ping'
    TabOrder = 11
    OnClick = btnPingClick
  end
  object btnAuth: TButton
    Left = 99
    Height = 25
    Hint = 'Sends an AUTH packet.'
    Top = 272
    Width = 45
    Caption = 'Auth'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 12
    OnClick = btnAuthClick
  end
  object IdTCPClient1: TIdTCPClient
    ConnectTimeout = 0
    Port = 0
    ReadTimeout = -1
    UseNagle = False
    Left = 56
    Top = 96
  end
  object tmrStartup: TTimer
    Enabled = False
    Interval = 10
    OnTimer = tmrStartupTimer
    Left = 240
    Top = 96
  end
  object tmrProcessLog: TTimer
    Enabled = False
    Interval = 10
    OnTimer = tmrProcessLogTimer
    Left = 320
    Top = 96
  end
  object tmrProcessRecData: TTimer
    Enabled = False
    Interval = 10
    OnTimer = tmrProcessRecDataTimer
    Left = 424
    Top = 96
  end
end
