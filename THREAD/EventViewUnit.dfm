object Form1: TForm1
  Left = 221
  Top = 186
  ClientHeight = 606
  ClientWidth = 879
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnActivate = FormActivate
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 879
    Height = 113
    Align = alTop
    TabOrder = 0
    object Label1: TLabel
      Left = 18
      Top = 27
      Width = 37
      Height = 13
      Caption = #1057#1077#1088#1074#1077#1088
    end
    object Label2: TLabel
      Left = 16
      Top = 53
      Width = 39
      Height = 13
      Caption = 'EventID'
    end
    object Label3: TLabel
      Left = 16
      Top = 81
      Width = 163
      Height = 13
      Caption = #1048#1089#1082#1072#1090#1100' '#1074' '#1079#1085#1072#1095#1077#1085#1080#1103#1093' '#1072#1088#1075#1091#1084#1077#1085#1090#1086#1074
    end
    object Label4: TLabel
      Left = 616
      Top = 27
      Width = 7
      Height = 13
      Caption = 'C'
    end
    object Label5: TLabel
      Left = 609
      Top = 51
      Width = 14
      Height = 13
      Caption = #1055#1086
    end
    object SpeedButton1: TSpeedButton
      Left = 310
      Top = 23
      Width = 23
      Height = 22
      Caption = '...'
      OnClick = SpeedButton1Click
    end
    object SpeedButton2: TSpeedButton
      Left = 313
      Top = 78
      Width = 23
      Height = 22
      Caption = '...'
      OnClick = SpeedButton2Click
    end
    object Button1: TButton
      Left = 364
      Top = 17
      Width = 75
      Height = 25
      Hint = #1063#1090#1077#1085#1080#1077' '#1076#1072#1085#1085#1099#1093' '#1089' '#1091#1076#1072#1083#1077#1085#1085#1086#1075#1086' '#1089#1077#1088#1074#1077#1088#1072
      Caption = #1063#1090#1077#1085#1080#1077
      TabOrder = 0
      OnClick = Button1Click
    end
    object Edit1: TEdit
      Left = 82
      Top = 24
      Width = 225
      Height = 21
      TabOrder = 1
    end
    object Button2: TButton
      Left = 445
      Top = 19
      Width = 75
      Height = 25
      Hint = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1073#1072#1079#1086#1074#1099#1081' '#1078#1091#1088#1085#1072#1083
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      TabOrder = 2
      OnClick = Button2Click
    end
    object Button3: TButton
      Left = 527
      Top = 19
      Width = 75
      Height = 25
      Caption = #1040#1085#1072#1083#1080#1079
      TabOrder = 3
      OnClick = Button3Click
    end
    object Edit2: TEdit
      Left = 82
      Top = 51
      Width = 225
      Height = 21
      TabOrder = 4
      Text = '680'
    end
    object Button4: TButton
      Left = 362
      Top = 48
      Width = 75
      Height = 25
      Caption = 'Stop'
      TabOrder = 5
      OnClick = Button4Click
    end
    object Edit3: TEdit
      Left = 186
      Top = 78
      Width = 121
      Height = 21
      Hint = #1047#1085#1072#1095#1077#1085#1080#1077' 0 - '#1095#1080#1090#1072#1090#1100' '#1079#1072#1087#1080#1089#1080' '#1089' '#1083#1102#1073#1099#1084' '#1082#1086#1076#1086#1084
      TabOrder = 6
    end
    object StartDate: TDateTimePicker
      Left = 629
      Top = 24
      Width = 89
      Height = 21
      Date = 39840.942353692130000000
      Time = 39840.942353692130000000
      Enabled = False
      TabOrder = 7
    end
    object StartTime: TDateTimePicker
      Left = 724
      Top = 24
      Width = 74
      Height = 21
      Date = 39840.943932291670000000
      Time = 39840.943932291670000000
      Enabled = False
      Kind = dtkTime
      TabOrder = 8
    end
    object EndDate: TDateTimePicker
      Left = 629
      Top = 51
      Width = 89
      Height = 21
      Date = 39840.947450439810000000
      Time = 39840.947450439810000000
      Enabled = False
      TabOrder = 9
    end
    object EndTime: TDateTimePicker
      Left = 724
      Top = 51
      Width = 74
      Height = 21
      Date = 39840.948188287040000000
      Time = 39840.948188287040000000
      Enabled = False
      Kind = dtkTime
      TabOrder = 10
    end
    object CheckBox1: TCheckBox
      Left = 629
      Top = 78
      Width = 196
      Height = 17
      Caption = #1048#1089#1087#1086#1083#1100#1079#1086#1074#1072#1090#1100' '#1092#1080#1083#1100#1090#1088' '#1074#1088#1077#1084#1077#1085#1080
      TabOrder = 11
      OnClick = CheckBox1Click
    end
    object CBVisible: TCheckBox
      Left = 352
      Top = 78
      Width = 177
      Height = 17
      Caption = #1042#1082#1083#1102#1095#1080#1090#1100' '#1074#1080#1079#1091#1072#1083#1080#1079#1072#1094#1080#1102
      TabOrder = 12
    end
    object cbFindDubl: TCheckBox
      Left = 352
      Top = 95
      Width = 177
      Height = 17
      Caption = #1054#1090#1082#1083#1102#1095#1080#1090#1100' '#1087#1086#1080#1089#1082' '#1076#1091#1073#1083#1080#1082#1072#1090#1086#1074
      TabOrder = 13
    end
    object ComboBox1: TComboBox
      Left = 443
      Top = 51
      Width = 160
      Height = 21
      TabOrder = 14
      Text = #1058#1080#1087' '#1089#1086#1073#1099#1090#1080#1103' ('#1042#1089#1077')'
      Items.Strings = (
        #1042#1089#1077
        #1040#1091#1076#1080#1090' '#1091#1089#1087#1077#1093#1086#1074
        #1040#1091#1076#1080#1090' '#1086#1090#1082#1072#1079#1086#1074)
    end
  end
  object Memo1: TMemo
    Left = 0
    Top = 113
    Width = 879
    Height = 474
    Align = alClient
    ScrollBars = ssBoth
    TabOrder = 1
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 587
    Width = 879
    Height = 19
    Panels = <
      item
        Width = 200
      end
      item
        Width = 400
      end
      item
        Width = 50
      end>
  end
  object SaveDialog1: TSaveDialog
    Left = 824
    Top = 16
  end
end
