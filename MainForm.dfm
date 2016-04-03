object PingForm: TPingForm
  Left = 0
  Top = 0
  Caption = 'Xping v 0'
  ClientHeight = 355
  ClientWidth = 179
  Color = clSilver
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  DesignSize = (
    179
    355)
  PixelsPerInch = 96
  TextHeight = 13
  object imgResults: TImage
    Left = 4
    Top = 0
    Width = 174
    Height = 334
    Anchors = [akLeft, akTop, akRight, akBottom]
    AutoSize = True
    PopupMenu = pmContext
    OnDblClick = imgResultsDblClick
    OnMouseDown = imgResultsMouseDown
    ExplicitWidth = 1206
    ExplicitHeight = 433
  end
  object chxDrawStat: TCheckBox
    Left = 8
    Top = 336
    Width = 97
    Height = 17
    Anchors = [akLeft, akBottom]
    Caption = 'Auto draw stat'
    TabOrder = 0
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
