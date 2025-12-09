program PerPerPref;

uses
  Vcl.Forms,
  PerPerPref_Main in 'PerPerPref_Main.pas' {PerPerPrefMain},
  Windows.Personalization in 'Windows.Personalization.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Persistent Personalization Preferences';
  Application.CreateForm(TPerPerPrefMain, PerPerPrefMain);
  Application.Run;
end.
