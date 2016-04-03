unit StatChart;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, TeEngine, Series, ExtCtrls, TeeProcs, Chart;

type
  TChartForm = class(TForm)
    chStat: TChart;
    pingTimes: TAreaSeries;
    btnClose: TButton;
    procedure btnCloseClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ChartForm: TChartForm;

implementation

{$R *.dfm}

procedure TChartForm.btnCloseClick(Sender: TObject);
begin
 Hide;
end;

end.
