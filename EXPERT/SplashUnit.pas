unit SplashUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, MPlayer, ExtCtrls, StdCtrls;

type
  TSplashForm = class(TForm)
    Label1: TLabel;
    procedure FormActivate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    Text: string;
  end;

var
  SplashForm: TSplashForm;

implementation

{$R *.dfm}

procedure TSplashForm.FormActivate(Sender: TObject);
begin
  Application.ProcessMessages;
end;

procedure TSplashForm.FormShow(Sender: TObject);
begin
  Label1.Caption := trim(Text);
end;

end.
