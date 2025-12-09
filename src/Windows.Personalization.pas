unit Windows.Personalization;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Win.Registry,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Graphics;

type
  TThemeMode = (Light, Dark);

  // Scopes for Windows 10/11 personalization
  TThemeScope = (System, App);

  TRegistryChangeEvent = procedure(Sender: TObject) of object;

  /// <summary>
  /// Manages Windows personalization settings including Theme, Accent Color, and Wallpaper.
  /// Includes threaded registry monitoring and non-blocking change broadcasting.
  /// </summary>
  TPersonalizationManager = class(TComponent)
  private
    FOnSettingsChanged: TRegistryChangeEvent;
    FMonitorThread: TThread;
    FUpdating: Boolean;
    function GetThemeMode(Scope: TThemeScope): TThemeMode;
    function GetAccentColor: TColor;
    procedure SetAccentColor(const Value: TColor);
    function GetWallpaper: string;
    procedure SetWallpaper(const Value: string);
    procedure StartRegistryMonitor;
    procedure StopRegistryMonitor;
    procedure SetThemeMode(const Scope: TThemeScope; const Value: TThemeMode);
    procedure SetOnSettingsChanged(const Value: TRegistryChangeEvent);
  protected
    procedure DoSettingsChanged; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Broadcasts a WM_SETTINGCHANGE message to all top-level windows.
    /// Uses SendNotifyMessage to prevent deadlocks if a listening application is hung.
    /// </summary>
    procedure BroadcastChange;

    // Properties
    property SystemTheme: TThemeMode index TThemeScope.System read GetThemeMode write SetThemeMode;
    property AppTheme: TThemeMode index TThemeScope.App read GetThemeMode write SetThemeMode;
    property AccentColor: TColor read GetAccentColor write SetAccentColor;
    property Wallpaper: string read GetWallpaper write SetWallpaper;

  published
    /// <summary>
    /// Fired when the specific Personalization registry key changes.
    /// </summary>
    property OnSettingsChanged: TRegistryChangeEvent read FOnSettingsChanged write SetOnSettingsChanged;
  end;

implementation

const
  REG_PERSONALIZE_KEY = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';
  REG_DWM_KEY         = 'Software\Microsoft\Windows\DWM';

{ TPersonalizationManager }

constructor TPersonalizationManager.Create(AOwner: TComponent);
begin
  inherited;
  FMonitorThread := nil;
  FUpdating := False;
end;

destructor TPersonalizationManager.Destroy;
begin
  StopRegistryMonitor;
  inherited;
end;

procedure TPersonalizationManager.BroadcastChange;
begin
  // SendNotifyMessage puts the message in the queue and returns immediately.
  // This prevents the "deadlock" scenario where a hung target window blocks the sender.
  // We broadcast "ImmersiveColorSet" which is often used by modern Windows apps to refresh themes.
  Winapi.Windows.SendNotifyMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, LPARAM(PChar('ImmersiveColorSet')));

  // Also generic environment update
  Winapi.Windows.SendNotifyMessage(HWND_BROADCAST, WM_SETTINGCHANGE, 0, LPARAM(PChar('Environment')));
end;

// -----------------------------------------------------------------------------
// Theme Modes (Dark/Light)
// -----------------------------------------------------------------------------
function TPersonalizationManager.GetThemeMode(Scope: TThemeScope): TThemeMode;
var
  Reg: TRegistry;
  KeyName: string;
  Val: Integer;
begin
  Result := TThemeMode.Light; // Default
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(REG_PERSONALIZE_KEY) then
    begin
      case Scope of
        TThemeScope.System: KeyName := 'SystemUsesLightTheme';
        TThemeScope.App:    KeyName := 'AppsUseLightTheme';
      end;

      if Reg.ValueExists(KeyName) then
      begin
        Val := Reg.ReadInteger(KeyName);
        if Val = 0 then
          Result := TThemeMode.Dark
        else
          Result := TThemeMode.Light;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TPersonalizationManager.SetThemeMode(const Scope: TThemeScope; const Value: TThemeMode);
var
  Reg: TRegistry;
  KeyName: string;
  IntVal: Integer;
begin
  if Value = TThemeMode.Dark then
    IntVal := 0
  else
    IntVal := 1;

  case Scope of
    TThemeScope.System: KeyName := 'SystemUsesLightTheme';
    TThemeScope.App:    KeyName := 'AppsUseLightTheme';
  end;

  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_PERSONALIZE_KEY, True) then
    begin
      if not Reg.ValueExists(KeyName) or (Reg.ReadInteger(KeyName) <> IntVal) then
      begin
        FUpdating := True;
        try
          Reg.WriteInteger(KeyName, IntVal);
          BroadcastChange;
        finally
          FUpdating := False;
        end;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

// -----------------------------------------------------------------------------
// Accent Color
// -----------------------------------------------------------------------------

function TPersonalizationManager.GetAccentColor: TColor;
var
  Reg: TRegistry;
  Code: Integer;
begin
  Result := clNone;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(REG_DWM_KEY) then
    begin
      if Reg.ValueExists('AccentColor') then
      begin
        // Windows stores this as ABGR usually, requires casting
        Code := Reg.ReadInteger('AccentColor');
        // Convert DWORD (00BBGGRR) format if necessary or cast directly
        Result := TColor(Code);
      end;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TPersonalizationManager.SetAccentColor(const Value: TColor);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey(REG_DWM_KEY, True) then
    begin
      Reg.WriteInteger('AccentColor', Integer(Value));
      Reg.WriteInteger('ColorizationColor', Integer(Value)); // Legacy compatibility
      BroadcastChange;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TPersonalizationManager.SetOnSettingsChanged(const Value: TRegistryChangeEvent);
begin
  FOnSettingsChanged := Value;
  if Assigned(FOnSettingsChanged) then
    StartRegistryMonitor
  else
    StopRegistryMonitor;
end;

// -----------------------------------------------------------------------------
// Wallpaper
// -----------------------------------------------------------------------------

function TPersonalizationManager.GetWallpaper: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  if SystemParametersInfo(SPI_GETDESKWALLPAPER, MAX_PATH, @Buffer, 0) then
    Result := StrPas(Buffer)
  else
    Result := '';
end;

procedure TPersonalizationManager.SetWallpaper(const Value: string);
begin
  // SPIF_UPDATEINIFILE = 0x01; Writes to user profile
  // SPIF_SENDCHANGE = 0x02; Broadcasts the change
  SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, PChar(Value), $01 or $02);
end;

// -----------------------------------------------------------------------------
// Registry Monitoring (Threaded)
// -----------------------------------------------------------------------------

procedure TPersonalizationManager.StartRegistryMonitor;
begin
  if Assigned(FMonitorThread) or not assigned(FOnSettingsChanged) then Exit;

  FMonitorThread := TThread.CreateAnonymousThread(
    procedure
    var
      RegKey: HKEY;
      WaitResult: DWORD;
      EventHandle: THandle;
    begin
      if RegOpenKeyEx(HKEY_CURRENT_USER, PChar(REG_PERSONALIZE_KEY), 0, KEY_NOTIFY, RegKey) <> ERROR_SUCCESS then
        Exit;

      EventHandle := CreateEvent(nil, False, False, nil);
      try
        while not TThread.CheckTerminated do
        begin
          // Watch for changes in attributes (values)
          RegNotifyChangeKeyValue(RegKey, True, REG_NOTIFY_CHANGE_LAST_SET, EventHandle, True);

          WaitResult := WaitForSingleObject(EventHandle, 500); // Check every 500ms for termination

          if not FUpdating and (WaitResult = WAIT_OBJECT_0) then
          begin
            TThread.Queue(nil,
              procedure
              begin
                if Assigned(FOnSettingsChanged) then
                  DoSettingsChanged;
              end);
          end;
        end;
      finally
        CloseHandle(EventHandle);
        RegCloseKey(RegKey);
      end;
    end);

  FMonitorThread.FreeOnTerminate := True;
  FMonitorThread.Start;
end;

procedure TPersonalizationManager.StopRegistryMonitor;
begin
  if Assigned(FMonitorThread) then
  begin
    FMonitorThread.Terminate;
    // We cannot easily force the Wait to stop immediately without a second event,
    // but the 500ms timeout in WaitForSingleObject allows it to exit gracefully.
    FMonitorThread := nil;
  end;
end;

procedure TPersonalizationManager.DoSettingsChanged;
begin
  if Assigned(FOnSettingsChanged) then
    FOnSettingsChanged(Self);
end;

end.
