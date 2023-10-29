object DualListDlg: TDualListDlg
  Left = 250
  Top = 108
  BorderStyle = bsDialog
  Caption = #1042#1099#1073#1086#1088' '#1082#1086#1085#1090#1088#1086#1083#1083#1077#1088#1086#1074
  ClientHeight = 361
  ClientWidth = 452
  Color = clBtnFace
  ParentFont = True
  OldCreateOrder = True
  Position = poScreenCenter
  OnActivate = FormActivate
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object SrcLabel: TLabel
    Left = 10
    Top = 102
    Width = 153
    Height = 16
    AutoSize = False
    Caption = #1042#1089#1077' '#1076#1086#1089#1090#1091#1087#1085#1099#1077' '#1082#1086#1085#1090#1088#1086#1083#1083#1077#1088#1099':'
  end
  object DstLabel: TLabel
    Left = 238
    Top = 102
    Width = 145
    Height = 16
    AutoSize = False
    Caption = #1057#1095#1080#1090#1072#1090#1100' '#1078#1091#1088#1085#1072#1083#1099' '#1089':'
  end
  object IncludeBtn: TSpeedButton
    Left = 204
    Top = 126
    Width = 24
    Height = 24
    Caption = '>'
    OnClick = IncludeBtnClick
  end
  object IncAllBtn: TSpeedButton
    Left = 204
    Top = 158
    Width = 24
    Height = 24
    Caption = '>>'
    OnClick = IncAllBtnClick
  end
  object ExcludeBtn: TSpeedButton
    Left = 204
    Top = 190
    Width = 24
    Height = 24
    Caption = '<'
    Enabled = False
    OnClick = ExcludeBtnClick
  end
  object ExAllBtn: TSpeedButton
    Left = 204
    Top = 222
    Width = 24
    Height = 24
    Caption = '<<'
    Enabled = False
    OnClick = ExcAllBtnClick
  end
  object Label1: TLabel
    Left = 8
    Top = 11
    Width = 45
    Height = 13
    Caption = #1048#1084#1103' '#1083#1077#1089#1072
  end
  object Label2: TLabel
    Left = 8
    Top = 38
    Width = 59
    Height = 13
    Caption = #1048#1084#1103' '#1076#1086#1084#1077#1085#1072
  end
  object SBAdd: TSpeedButton
    Left = 257
    Top = 63
    Width = 21
    Height = 21
    Hint = #1055#1086#1079#1074#1086#1083#1103#1077#1090' '#1076#1086#1073#1072#1074#1080#1090#1100' '#1085#1086#1074#1099#1081' '#1090#1080#1087' '#1089#1077#1088#1074#1077#1088#1072
    Caption = '+'
    ParentShowHint = False
    ShowHint = True
    OnClick = SBAddClick
  end
  object SBRemove: TSpeedButton
    Left = 284
    Top = 63
    Width = 21
    Height = 21
    Hint = #1055#1086#1079#1074#1086#1083#1103#1077#1090' '#1091#1076#1072#1083#1080#1090#1100' '#1074#1099#1073#1088#1072#1085#1085#1099#1081' '#1090#1080#1087' '#1089#1077#1088#1074#1077#1088#1072
    Caption = '-'
    ParentShowHint = False
    ShowHint = True
  end
  object SpeedButton1: TSpeedButton
    Left = 314
    Top = 63
    Width = 21
    Height = 21
    Hint = #1055#1086#1079#1074#1086#1083#1103#1077#1090' '#1091#1076#1072#1083#1080#1090#1100' '#1074#1099#1073#1088#1072#1085#1085#1099#1081' '#1090#1080#1087' '#1089#1077#1088#1074#1077#1088#1072
    Caption = '>'
    ParentShowHint = False
    ShowHint = True
    OnClick = SpeedButton1Click
  end
  object Label3: TLabel
    Left = 304
    Top = 328
    Width = 31
    Height = 13
    Caption = 'Label3'
  end
  object OKBtn: TButton
    Left = 101
    Top = 315
    Width = 75
    Height = 25
    Caption = #1055#1088#1080#1084#1077#1085#1080#1090#1100
    Default = True
    ModalResult = 1
    TabOrder = 2
    OnClick = OKBtnClick
  end
  object CancelBtn: TButton
    Left = 181
    Top = 315
    Width = 75
    Height = 25
    Cancel = True
    Caption = #1054#1090#1084#1077#1085#1072
    ModalResult = 2
    TabOrder = 3
    OnClick = CancelBtnClick
  end
  object SrcList: TListBox
    Left = 8
    Top = 118
    Width = 190
    Height = 185
    ItemHeight = 13
    Items.Strings = (
      'pc-01'
      'pc-02'
      'srv-01'
      'srv-02'
      'srv-03')
    MultiSelect = True
    Sorted = True
    TabOrder = 0
  end
  object DstList: TListBox
    Left = 236
    Top = 118
    Width = 190
    Height = 185
    ItemHeight = 13
    MultiSelect = True
    TabOrder = 1
  end
  object Edit1: TEdit
    Left = 82
    Top = 8
    Width = 169
    Height = 21
    Enabled = False
    TabOrder = 4
    Text = 'Edit1'
  end
  object Edit2: TEdit
    Left = 82
    Top = 35
    Width = 169
    Height = 21
    Enabled = False
    TabOrder = 5
    Text = 'Edit2'
  end
  object CBServerType: TComboBox
    Left = 83
    Top = 62
    Width = 168
    Height = 21
    TabOrder = 6
    Text = #1053#1077' '#1074#1099#1073#1088#1072#1085#1086
    OnChange = CBServerTypeChange
  end
  object PopupMenu1: TPopupMenu
    Left = 368
    Top = 40
    object N11: TMenuItem
      Caption = #1055#1086#1083#1091#1095#1080#1090#1100' '#1089#1087#1080#1089#1086#1082' '#1082#1086#1085#1090#1088#1086#1083#1083#1077#1088#1086#1074' '#1076#1086#1084#1077#1085#1072
      OnClick = N11Click
    end
    object N21: TMenuItem
      Caption = 'test DsBrowseForContainerW'
      OnClick = N21Click
    end
    object N31: TMenuItem
      Caption = '3'
    end
  end
end
