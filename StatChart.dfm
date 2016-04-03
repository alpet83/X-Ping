object ChartForm: TChartForm
  Left = 0
  Top = 0
  Caption = 'Ping stat'
  ClientHeight = 458
  ClientWidth = 833
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    833
    458)
  PixelsPerInch = 96
  TextHeight = 13
  object chStat: TChart
    Left = 0
    Top = 8
    Width = 825
    Height = 417
    Title.Text.Strings = (
      'Ping times')
    View3D = False
    TabOrder = 0
    Anchors = [akLeft, akTop, akRight, akBottom]
    object pingTimes: TAreaSeries
      Gradient.EndColor = 8421631
      Gradient.MidColor = 8454143
      Gradient.StartColor = clLime
      Gradient.Visible = True
      Marks.Arrow.Visible = False
      Marks.Callout.Brush.Color = clBlack
      Marks.Callout.Style = psCircle
      Marks.Callout.Visible = True
      Marks.Callout.Arrow.Visible = False
      Marks.Callout.ArrowHead = ahSolid
      Marks.Shadow.Color = 8553090
      Marks.Shadow.Visible = False
      Marks.Visible = False
      SeriesColor = 12615680
      ShowInLegend = False
      AreaLinesPen.Color = clSilver
      AreaLinesPen.Style = psDot
      AreaLinesPen.EndStyle = esFlat
      DrawArea = True
      Pointer.HorizSize = 3
      Pointer.InflateMargins = True
      Pointer.Style = psDownTriangle
      Pointer.VertSize = 3
      Pointer.Visible = True
      XValues.Name = 'X'
      XValues.Order = loAscending
      YValues.Name = 'Y'
      YValues.Order = loNone
    end
  end
  object btnClose: TButton
    Left = 750
    Top = 431
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Close'
    TabOrder = 1
    OnClick = btnCloseClick
  end
end
