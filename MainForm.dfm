object PingForm: TPingForm
  Left = 0
  Top = 0
  VertScrollBar.Increment = 15
  VertScrollBar.Style = ssFlat
  Caption = 'Xping v 0'
  ClientHeight = 421
  ClientWidth = 694
  Color = clSilver
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Visible = True
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  DesignSize = (
    694
    421)
  PixelsPerInch = 96
  TextHeight = 13
  object chxDrawStat: TCheckBox
    Left = 8
    Top = 386
    Width = 97
    Height = 17
    Anchors = [akLeft, akBottom]
    Caption = 'Auto draw stat'
    TabOrder = 0
  end
  object sbInfo: TStatusBar
    Left = 0
    Top = 402
    Width = 694
    Height = 19
    Panels = <
      item
        Text = 'App startup...'
        Width = 300
      end
      item
        Text = 'value = 0'
        Width = 50
      end>
  end
  object PageCtrl: TPageControl
    Left = 0
    Top = 0
    Width = 694
    Height = 380
    Align = alCustom
    Anchors = [akLeft, akTop, akRight, akBottom]
    Style = tsFlatButtons
    TabOrder = 2
  end
  object tmrUpdate: TTimer
    Interval = 500
    OnTimer = tmrUpdateTimer
    Left = 776
    Top = 272
  end
  object pmContext: TPopupMenu
    Left = 112
    Top = 224
    object miLookupHost: TMenuItem
      Caption = 'Lookup host'
      OnClick = miLookupHostClick
    end
    object miShowLog: TMenuItem
      AutoCheck = True
      Caption = 'Show log'
      OnClick = miShowLogClick
    end
    object miSaveSS: TMenuItem
      Caption = 'Save Screenshot'
      OnClick = miSaveSSClick
    end
  end
  object svdlg: TSaveDialog
    DefaultExt = 'png'
    FileName = 'xping'
    Filter = 'PNG Files|*.png'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 96
    Top = 288
  end
end
