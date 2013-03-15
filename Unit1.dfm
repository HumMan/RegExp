object Form1: TForm1
  Left = 410
  Top = 315
  Width = 601
  Height = 266
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    593
    236)
  PixelsPerInch = 96
  TextHeight = 13
  object Panel2: TPanel
    Left = 0
    Top = 153
    Width = 593
    Height = 83
    Align = alBottom
    TabOrder = 0
    object Label5: TLabel
      Left = 352
      Top = 8
      Width = 42
      Height = 13
      Caption = 'Time, ms'
    end
    object Label3: TLabel
      Left = 360
      Top = 32
      Width = 24
      Height = 13
      Caption = '____'
    end
    object Label4: TLabel
      Left = 360
      Top = 56
      Width = 24
      Height = 13
      Caption = '____'
    end
    object Label2: TLabel
      Left = 240
      Top = 56
      Width = 99
      Height = 13
      Caption = 'Match (10^5 cycles):'
    end
    object Label1: TLabel
      Left = 240
      Top = 32
      Width = 100
      Height = 13
      Caption = 'SetExpr (500 cycles):'
    end
    object Label6: TLabel
      Left = 120
      Top = 32
      Width = 53
      Height = 13
      Caption = 'Last_char='
    end
    object Button1: TButton
      Left = 24
      Top = 16
      Width = 75
      Height = 25
      Caption = 'Match'
      TabOrder = 0
      OnClick = Button1Click
    end
    object CheckBox1: TCheckBox
      Left = 48
      Top = 56
      Width = 97
      Height = 17
      Caption = 'Match=True'
      TabOrder = 1
    end
    object CheckBox2: TCheckBox
      Left = 120
      Top = 16
      Width = 97
      Height = 17
      Caption = 'DFA'
      TabOrder = 2
    end
  end
  object Edit1: TEdit
    Left = 8
    Top = 12
    Width = 572
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Courier'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
    Text = '(a|b[^\n ])abc(a|[\s0-9])'
  end
  object Memo1: TMemo
    Left = 8
    Top = 48
    Width = 577
    Height = 94
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'aabca')
    TabOrder = 2
    WantTabs = True
  end
end
