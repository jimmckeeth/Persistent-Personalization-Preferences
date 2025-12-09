unit PerPerPref_Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Windows.Personalization, Vcl.ExtCtrls, Vcl.Menus;

type
  TPerPerPrefMain = class(TForm)
    btnLight: TButton;
    btnDark: TButton;
    grpLockTheme: TRadioGroup;
    TrayIcon1: TTrayIcon;
    ckKeepInTray: TCheckBox;
    PopupMenu1: TPopupMenu;
    GoLight1: TMenuItem;
    GoDark1: TMenuItem;
    GoDark2: TMenuItem;
    LockLight1: TMenuItem;
    LockDark1: TMenuItem;
    Unlock1: TMenuItem;
    N1: TMenuItem;
    Exitr1: TMenuItem;
    ShowHide1: TMenuItem;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    ckAutoStart: TCheckBox;
    procedure ChangeToLight(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ChangeToDark(Sender: TObject);
    procedure grpLockThemeClick(Sender: TObject);
    procedure TrayIcon1Click(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ckKeepInTrayClick(Sender: TObject);
    procedure Unlock1Click(Sender: TObject);
    procedure LockLight1Click(Sender: TObject);
    procedure LockDark1Click(Sender: TObject);
    procedure Exitr1Click(Sender: TObject);
    procedure ckAutoStartClick(Sender: TObject);
  private
    { Private declarations }
    FPM: TPersonalizationManager;
  public
    { Public declarations }
    procedure WMSize(var Msg: TWMSize); message WM_SIZE;
  end;

var
  PerPerPrefMain: TPerPerPrefMain;

implementation

uses
  Registry,
  Vcl.Themes;

{$R *.dfm}

procedure TPerPerPrefMain.ChangeToLight(Sender: TObject);
begin
  TStyleManager.SetStyle('Windows10');
  FPM.SystemTheme := TThemeMode.Light;
  FPM.AppTheme := TThemeMode.Light;
end;

procedure TPerPerPrefMain.ckAutoStartClick(Sender: TObject);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;
    if reg.OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Run', False) then
    begin
      if ckAutoStart.Checked then
        reg.WriteString(Application.Title, Application.ExeName + ' -Tray')
      else
        if Reg.ValueExists(Application.Title) then
          Reg.DeleteValue(Application.Title);
    end;
    if reg.OpenKey('SOFTWARE\'+Application.Title, True) then
      Reg.WriteBool(ckAutoStart.Name, ckAutoStart.Checked);
  finally
    reg.Free;
  end;
end;

procedure TPerPerPrefMain.ckKeepInTrayClick(Sender: TObject);
begin
  TrayIcon1.Visible := ckKeepInTray.Checked;
  var reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;

    if reg.OpenKey('SOFTWARE\'+Application.Title, True) then
    begin
      Reg.WriteBool(ckKeepInTray.Name, ckKeepInTray.Checked);
    end;
  finally
    reg.Free;
  end;
end;

procedure TPerPerPrefMain.Exitr1Click(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TPerPerPrefMain.ChangeToDark(Sender: TObject);
begin
  TStyleManager.SetStyle('Glossy');
  FPM.SystemTheme := TThemeMode.Dark;
  FPM.AppTheme := TThemeMode.Dark;
end;

procedure TPerPerPrefMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if ckKeepInTray.Checked then
  begin
    CanClose := False;
    Hide;
    TrayIcon1.Visible := True;
  end
  else
    CanClose := True;
end;

procedure TPerPerPrefMain.FormCreate(Sender: TObject);
var
  reg: TRegistry;
begin
  FPM := TPersonalizationManager.Create(self);
  if FPM.AppTheme = TThemeMode.Dark then
    TStyleManager.SetStyle('Glossy')
  else
    TStyleManager.SetStyle('Windows10');

  reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;

    if reg.OpenKey('SOFTWARE\'+Application.Title, False) then
    begin
      if Reg.ValueExists(ckKeepInTray.Name) then
        ckKeepInTray.Checked := Reg.ReadBool(ckKeepInTray.Name);
      if Reg.ValueExists(ckAutoStart.Name) then
        ckAutoStart.Checked := Reg.ReadBool(ckAutoStart.Name);
      if Reg.ValueExists(grpLockTheme.Name) then
        grpLockTheme.ItemIndex := Reg.ReadInteger(grpLockTheme.Name);
    end;
  finally
    reg.Free;
  end;

  if UpperCase(ParamStr(1)).Contains('TRAY') then
  begin
    ckKeepInTray.Checked := True;
    Application.ShowMainForm := False;
  end;

  grpLockThemeClick(Sender);
  ckAutoStartClick(Sender);
  ckKeepInTrayClick(Sender);
end;

procedure TPerPerPrefMain.grpLockThemeClick(Sender: TObject);
begin
  FPM.OnSettingsChanged := nil;
  case grpLockTheme.ItemIndex of
    1: begin
      FPM.OnSettingsChanged := ChangeToLight;
      ChangeToLight(Sender);
    end;
    2: begin
      FPM.OnSettingsChanged := ChangeToDark;
      ChangeToDark(Sender);
    end
  end;
  Unlock1.Checked := grpLockTheme.ItemIndex = 0;
  LockLight1.Checked := grpLockTheme.ItemIndex = 1;
  LockDark1.Checked := grpLockTheme.ItemIndex = 2;

  var reg := TRegistry.Create;
  try
    reg.RootKey := HKEY_CURRENT_USER;

    if reg.OpenKey('SOFTWARE\'+Application.Title, True) then
      Reg.WriteInteger(grpLockTheme.Name, grpLockTheme.ItemIndex);
  finally
    reg.Free;
  end;
end;

procedure TPerPerPrefMain.LockDark1Click(Sender: TObject);
begin
  grpLockTheme.ItemIndex := 2;
  grpLockThemeClick(Sender);
end;

procedure TPerPerPrefMain.LockLight1Click(Sender: TObject);
begin
  grpLockTheme.ItemIndex := 1;
  grpLockThemeClick(Sender);
end;

procedure TPerPerPrefMain.TrayIcon1Click(Sender: TObject);
begin
  Visible := not Visible;
  if Visible then
  begin
    Application.BringToFront;
    WindowState := TWindowState.wsNormal;
    BringToFront;
  end;

end;

procedure TPerPerPrefMain.Unlock1Click(Sender: TObject);
begin
  grpLockTheme.ItemIndex := 0;
  grpLockThemeClick(Sender);
end;

procedure TPerPerPrefMain.WMSize(var Msg: TWMSize);
begin
  if (Msg.SizeType = SIZEICONIC) and ckKeepInTray.Checked then
    Visible := False;
end;

end.
