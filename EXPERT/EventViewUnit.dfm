object Form1: TForm1
  Left = 216
  Top = 188
  Caption = 
    #1040#1076#1084#1080#1085#1080#1089#1090#1088#1072#1090#1080#1074#1085#1072#1103' '#1091#1090#1080#1083#1080#1090#1072' '#1072#1085#1072#1083#1080#1079#1072' '#1078#1091#1088#1085#1072#1083#1086#1074' '#1073#1077#1079#1086#1087#1072#1089#1085#1086#1089#1090#1080' MS Window' +
    's'
  ClientHeight = 606
  ClientWidth = 879
  Color = clBtnFace
  Font.Charset = RUSSIAN_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Icon.Data = {
    0000010001002020100000000000E80200001600000028000000200000004000
    0000010004000000000080020000000000000000000000000000000000000000
    000000008000008000000080800080000000800080008080000080808000C0C0
    C0000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF009999
    999999999999999999999999999994444F00F40F444444444444444444499C44
    4F00F40F444444444444444444499CC44F0F0F0F444444440000004444499CCC
    4F0F0F0F444440008888880044499CCCCF04F00F444008888888888804499CCC
    CF00000F4008F8F8F8F8888804499CCCCF04F00F0F8F88888888800004499CCC
    CF0F0040F8F8F8F8F800078804499CCCCCF0040F8F888F880077787804499CCC
    CCCFC0F8F8F8F8F00787878044499CCCCCCC0F8F8F8F80070878788044499CCC
    CCC0F8F8F8F807770787880444499CCCCCC0FFFF8F8077780878780444499CCC
    CC08F8F8F80F77870787804444499CCCCC0FFF8F80F0F7780878044444499CCC
    C0F8F8F8078F0F870787044444499CCCC0FF8FF07777F0F80880444444499CCC
    C0F8F8F077878F0F0804444444499CCC0FFFFF07777878F00044444444499CCC
    0FF8F000000000000F4F444444499CCC0FFFF07778787880F0F0F44444499CCC
    0FF807878787870CCF00F44444499CCC0FFF0778787870CCF000F44444499CCC
    0FF8078787800CCCCFFF0F4444499CCC0FF07878780CCCCCCCCCFF4444499CCC
    C0F0777700CCCCCCCCCCCC4444499CCCC0F07700CCCCCCCCCCCCCCC444499CCC
    CC0000CCCCCCCCCCCCCCCCCC44499CCCCCCCCCCCCCCCCCCCCCCCCCCCC4499CCC
    CCCCCCCCCCCCCCCCCCCCCCCCCC49999999999999999999999999999999990000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000}
  OldCreateOrder = False
  Position = poScreenCenter
  OnActivate = FormActivate
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 879
    Height = 121
    Align = alTop
    TabOrder = 0
    object Label1: TLabel
      Left = 18
      Top = 27
      Width = 37
      Height = 13
      Caption = #1057#1077#1088#1074#1077#1088
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
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
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object Label4: TLabel
      Left = 616
      Top = 27
      Width = 7
      Height = 13
      Caption = 'C'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object Label5: TLabel
      Left = 609
      Top = 51
      Width = 14
      Height = 13
      Caption = #1055#1086
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
    end
    object SpeedButton1: TSpeedButton
      Left = 314
      Top = 79
      Width = 23
      Height = 22
      Caption = '...'
      OnClick = SpeedButton1Click
    end
    object btRead: TButton
      Left = 352
      Top = 17
      Width = 75
      Height = 25
      Hint = #1063#1090#1077#1085#1080#1077' '#1076#1072#1085#1085#1099#1093' '#1089' '#1091#1076#1072#1083#1077#1085#1085#1086#1075#1086' '#1089#1077#1088#1074#1077#1088#1072
      Caption = #1063#1090#1077#1085#1080#1077
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = btReadClick
    end
    object Edit1: TEdit
      Left = 82
      Top = 24
      Width = 225
      Height = 21
      TabOrder = 1
    end
    object btSave: TButton
      Left = 433
      Top = 17
      Width = 75
      Height = 25
      Hint = #1057#1086#1093#1088#1072#1085#1080#1090#1100' '#1073#1072#1079#1086#1074#1099#1081' '#1078#1091#1088#1085#1072#1083
      Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      OnClick = btSaveClick
    end
    object Button3: TButton
      Left = 514
      Top = 17
      Width = 75
      Height = 25
      Caption = #1040#1085#1072#1083#1080#1079
      Enabled = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 3
      OnClick = Button3Click
    end
    object edStrID: TEdit
      Left = 82
      Top = 51
      Width = 225
      Height = 21
      TabOrder = 4
    end
    object btStop: TButton
      Left = 352
      Top = 48
      Width = 75
      Height = 25
      Caption = 'Stop'
      TabOrder = 5
      OnClick = btStopClick
    end
    object Edit3: TEdit
      Left = 185
      Top = 78
      Width = 122
      Height = 21
      Hint = #1047#1085#1072#1095#1077#1085#1080#1077' 0 - '#1095#1080#1090#1072#1090#1100' '#1079#1072#1087#1080#1089#1080' '#1089' '#1083#1102#1073#1099#1084' '#1082#1086#1076#1086#1084
      TabOrder = 6
    end
    object StartDate: TDateTimePicker
      Left = 629
      Top = 24
      Width = 89
      Height = 21
      Date = 39840.000000000000000000
      Time = 39840.000000000000000000
      Enabled = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 7
    end
    object StartTime: TDateTimePicker
      Left = 724
      Top = 24
      Width = 74
      Height = 21
      Date = 39840.985590277780000000
      Time = 39840.985590277780000000
      Enabled = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      Kind = dtkTime
      ParentFont = False
      TabOrder = 8
    end
    object EndDate: TDateTimePicker
      Left = 629
      Top = 51
      Width = 89
      Height = 21
      Date = 39840.000000000000000000
      Time = 39840.000000000000000000
      Enabled = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
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
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      Kind = dtkTime
      ParentFont = False
      TabOrder = 10
    end
    object CheckBox1: TCheckBox
      Left = 535
      Top = 78
      Width = 218
      Height = 17
      Caption = #1048#1089#1087#1086#1083#1100#1079#1086#1074#1072#1090#1100' '#1092#1080#1083#1100#1090#1088' '#1076#1072#1090#1099'/'#1074#1088#1077#1084#1077#1085#1080
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 11
      OnClick = CheckBox1Click
    end
    object CBVisible: TCheckBox
      Left = 352
      Top = 81
      Width = 177
      Height = 17
      Caption = #1042#1082#1083#1102#1095#1080#1090#1100' '#1074#1080#1079#1091#1072#1083#1080#1079#1072#1094#1080#1102
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 12
    end
    object cbFindDubl: TCheckBox
      Left = 352
      Top = 96
      Width = 177
      Height = 17
      Caption = #1054#1090#1082#1083#1102#1095#1080#1090#1100' '#1087#1086#1080#1089#1082' '#1076#1091#1073#1083#1080#1082#1072#1090#1086#1074
      Enabled = False
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 13
    end
    object cbUseUniqueID: TCheckBox
      Left = 535
      Top = 98
      Width = 290
      Height = 17
      Caption = #1048#1089#1087#1086#1083#1100#1079#1086#1074#1072#1090#1100' '#1091#1085#1080#1082#1072#1083#1100#1085#1099#1077' '#1087#1072#1088#1099' EventID/EventType'
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 14
    end
    object ComboBox1: TComboBox
      Left = 433
      Top = 48
      Width = 156
      Height = 21
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      TabOrder = 15
      Text = #1058#1080#1087' '#1089#1086#1073#1099#1090#1080#1103' ('#1042#1089#1077')'
      Items.Strings = (
        #1042#1089#1077
        #1040#1091#1076#1080#1090' '#1091#1089#1087#1077#1093#1086#1074
        #1040#1091#1076#1080#1090' '#1086#1090#1082#1072#1079#1086#1074)
    end
    object CheckBox2: TCheckBox
      Left = 315
      Top = 53
      Width = 26
      Height = 17
      Hint = #1042#1082#1083#1102#1095#1080#1090#1100'/'#1080#1089#1082#1083#1102#1095#1080#1090#1100' '#1076#1072#1085#1085#1099#1077' '#1089#1086#1073#1099#1090#1080#1103
      Checked = True
      Font.Charset = RUSSIAN_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      State = cbChecked
      TabOrder = 16
    end
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
  object StringGrid1: TStringGrid
    Left = 0
    Top = 121
    Width = 879
    Height = 466
    Hint = 
      #1050#1083#1080#1082#1072#1085#1100#1077' '#1087#1088#1072#1074#1086#1081' '#1082#1085#1086#1087#1082#1086#1081' '#1084#1099#1096#1080' '#1087#1086' '#1089#1090#1088#1086#1082#1077' '#1082#1086#1087#1080#1088#1091#1077#1090' '#1077#1077' '#1074' '#1073#1091#1092#1092#1077#1088' '#1086#1073#1084#1077 +
      #1085#1072
    TabStop = False
    Align = alClient
    BorderStyle = bsNone
    ColCount = 11
    Ctl3D = False
    DefaultRowHeight = 17
    DoubleBuffered = True
    FixedCols = 0
    RowCount = 25
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Arial'
    Font.Style = []
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goRangeSelect, goColSizing, goRowSelect]
    ParentCtl3D = False
    ParentDoubleBuffered = False
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
    TabOrder = 2
    Touch.ParentTabletOptions = False
    Touch.TabletOptions = []
    OnDrawCell = StringGrid1DrawCell
    OnMouseDown = StringGrid1MouseDown
    ColWidths = (
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64
      64)
  end
  object SaveDialog1: TSaveDialog
    Filter = #1058#1077#1082#1089#1090#1086#1074#1099#1077' '#1076#1086#1082#1091#1084#1077#1085#1090#1099' (*.txt)|*.txt|'#1042#1089#1077' '#1092#1072#1081#1083#1099'|*.*'
    Left = 824
    Top = 16
  end
end
