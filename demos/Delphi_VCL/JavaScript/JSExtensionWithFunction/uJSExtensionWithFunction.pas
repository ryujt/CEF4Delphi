// ************************************************************************
// ***************************** CEF4Delphi *******************************
// ************************************************************************
//
// CEF4Delphi is based on DCEF3 which uses CEF3 to embed a chromium-based
// browser in Delphi applications.
//
// The original license of DCEF3 still applies to CEF4Delphi.
//
// For more information about CEF4Delphi visit :
//         https://www.briskbard.com/index.php?lang=en&pageid=cef
//
//        Copyright � 2019 Salvador Diaz Fau. All rights reserved.
//
// ************************************************************************
// ************ vvvv Original license and comments below vvvv *************
// ************************************************************************
(*
 *                       Delphi Chromium Embedded 3
 *
 * Usage allowed under the restrictions of the Lesser GNU General Public License
 * or alternatively the restrictions of the Mozilla Public License 1.1
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 *
 * Unit owner : Henri Gourvest <hgourvest@gmail.com>
 * Web site   : http://www.progdigy.com
 * Repository : http://code.google.com/p/delphichromiumembedded/
 * Group      : http://groups.google.com/group/delphichromiumembedded
 *
 * Embarcadero Technologies, Inc is not permitted to use or redistribute
 * this source code without explicit permission.
 *
 *)

unit uJSExtensionWithFunction;

{$I cef.inc}

interface

uses
  {$IFDEF DELPHI16_UP}
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  {$ELSE}
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  {$ENDIF}
  uCEFChromium, uCEFWindowParent, uCEFInterfaces, uCEFApplication, uCEFTypes, uCEFConstants,
  uCEFWinControl, uCEFSentinel;

type
  TJSExtensionWithFunctionFrm = class(TForm)
    NavControlPnl: TPanel;
    Edit1: TEdit;
    GoBtn: TButton;
    CEFWindowParent1: TCEFWindowParent;
    Chromium1: TChromium;
    Timer1: TTimer;
    StatusBar1: TStatusBar;
    CEFSentinel1: TCEFSentinel;
    procedure FormShow(Sender: TObject);
    procedure GoBtnClick(Sender: TObject);
    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
    procedure Timer1Timer(Sender: TObject);
    procedure Chromium1BeforePopup(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame; const targetUrl,
      targetFrameName: ustring;
      targetDisposition: TCefWindowOpenDisposition; userGesture: Boolean;
      const popupFeatures: TCefPopupFeatures; var windowInfo: TCefWindowInfo;
      var client: ICefClient; var settings: TCefBrowserSettings;
      var extra_info: ICefDictionaryValue;
      var noJavascriptAccess: Boolean; var Result: Boolean);
    procedure Chromium1ProcessMessageReceived(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame; sourceProcess: TCefProcessId;
      const message: ICefProcessMessage; out Result: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Chromium1Close(Sender: TObject; const browser: ICefBrowser;
      var aAction : TCefCloseBrowserAction);
    procedure Chromium1BeforeClose(Sender: TObject;
      const browser: ICefBrowser);
    procedure CEFSentinel1Close(Sender: TObject);
  protected
    // Variables to control when can we destroy the form safely
    FCanClose : boolean;  // Set to True in TChromium.OnBeforeClose
    FClosing  : boolean;  // Set to True in the CloseQuery event.

    procedure BrowserCreatedMsg(var aMessage : TMessage); message CEF_AFTERCREATED;
    procedure BrowserDestroyMsg(var aMessage : TMessage); message CEF_DESTROY;
    procedure WMMove(var aMessage : TWMMove); message WM_MOVE;
    procedure WMMoving(var aMessage : TMessage); message WM_MOVING;
    procedure WMEnterMenuLoop(var aMessage: TMessage); message WM_ENTERMENULOOP;
    procedure WMExitMenuLoop(var aMessage: TMessage); message WM_EXITMENULOOP;

    {$IFNDEF DELPHI12_UP}class procedure GlobalCEFApp_OnWebKitInitializedEvent;{$ENDIF}
  public
    { Public declarations }
  end;

var
  JSExtensionWithFunctionFrm: TJSExtensionWithFunctionFrm;

procedure CreateGlobalCEFApp;

implementation

{$R *.dfm}

uses
  uCEFMiscFunctions, uMyV8Handler;

// The CEF3 document describing JavaScript integration is here :
// https://bitbucket.org/chromiumembedded/cef/wiki/JavaScriptIntegration.md

// The HTML file in this demo has a button that shows the contents of 'test.myfunc()'
// which was registered in the GlobalCEFApp.OnWebKitInitialized event.

// Destruction steps
// =================
// 1. FormCloseQuery sets CanClose to FALSE calls TChromium.CloseBrowser which triggers the TChromium.OnClose event.
// 2. TChromium.OnClose sends a CEFBROWSER_DESTROY message to destroy CEFWindowParent1 in the main thread, which triggers the TChromium.OnBeforeClose event.
// 3. TChromium.OnBeforeClose calls TCEFSentinel.Start, which will trigger TCEFSentinel.OnClose when the renderer processes are closed.
// 4. TCEFSentinel.OnClose sets FCanClose := True and sends WM_CLOSE to the form.

{$IFDEF DELPHI12_UP}procedure
{$ELSE}class procedure TJSSimpleExtensionFrm.{$ENDIF}GlobalCEFApp_OnWebKitInitializedEvent;
var
  TempExtensionCode : string;
  TempHandler       : ICefv8Handler;
begin
  // This is the JS extension example with a function in the "JavaScript Integration" wiki page at
  // https://bitbucket.org/chromiumembedded/cef/wiki/JavaScriptIntegration.md

  TempExtensionCode := 'var test;' +
                       'if (!test)' +
                       '  test = {};' +
                       '(function() {' +
                       '  test.myfunc = function() {' +
                       '    native function myfunc();' +
                       '    return myfunc();' +
                       '  };' +
                       '})();';

  TempHandler := TMyV8Handler.Create;

  CefRegisterExtension('v8/test', TempExtensionCode, TempHandler);
end;

procedure CreateGlobalCEFApp;
begin
  GlobalCEFApp                     := TCefApplication.Create;
  GlobalCEFApp.OnWebKitInitialized := {$IFNDEF DELPHI12_UP}TJSSimpleExtensionFrm.{$ENDIF}
      GlobalCEFApp_OnWebKitInitializedEvent;
end;

procedure TJSExtensionWithFunctionFrm.GoBtnClick(Sender: TObject);
begin
  Chromium1.LoadURL(Edit1.Text);
end;

procedure TJSExtensionWithFunctionFrm.CEFSentinel1Close(Sender: TObject);
begin
  FCanClose := True;
  PostMessage(Handle, WM_CLOSE, 0, 0);
end;

procedure TJSExtensionWithFunctionFrm.Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
begin
  PostMessage(Handle, CEF_AFTERCREATED, 0, 0);
end;

procedure TJSExtensionWithFunctionFrm.Chromium1BeforeClose(Sender: TObject;
  const browser: ICefBrowser);
begin
  CEFSentinel1.Start;
end;

procedure TJSExtensionWithFunctionFrm.Chromium1BeforePopup(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame; const targetUrl,
  targetFrameName: ustring; targetDisposition: TCefWindowOpenDisposition;
  userGesture: Boolean; const popupFeatures: TCefPopupFeatures;
  var windowInfo: TCefWindowInfo; var client: ICefClient;
  var settings: TCefBrowserSettings; var extra_info: ICefDictionaryValue;
  var noJavascriptAccess: Boolean;
  var Result: Boolean);
begin
  // For simplicity, this demo blocks all popup windows and new tabs
  Result := (targetDisposition in [WOD_NEW_FOREGROUND_TAB, WOD_NEW_BACKGROUND_TAB, WOD_NEW_POPUP, WOD_NEW_WINDOW]);
end;

procedure TJSExtensionWithFunctionFrm.Chromium1Close(Sender: TObject;
  const browser: ICefBrowser; var aAction : TCefCloseBrowserAction);
begin
  PostMessage(Handle, CEF_DESTROY, 0, 0);
  aAction := cbaDelay;
end;

procedure TJSExtensionWithFunctionFrm.Chromium1ProcessMessageReceived(
  Sender: TObject; const browser: ICefBrowser; const frame: ICefFrame;
  sourceProcess: TCefProcessId; const message: ICefProcessMessage;
  out Result: Boolean);
begin
  if (message.Name = TEST_MESSAGE_NAME) then
    begin
      StatusBar1.Panels[0].Text := DateTimeToStr(now) + ' - ' + message.ArgumentList.GetString(0); // this doesn't create/destroy components
      Result := True;
    end
end;

procedure TJSExtensionWithFunctionFrm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  CanClose := FCanClose;

  if not(FClosing) then
    begin
      FClosing := True;
      Visible  := False;
      Chromium1.CloseBrowser(True);
    end;
end;

procedure TJSExtensionWithFunctionFrm.FormCreate(Sender: TObject);
begin
  FCanClose := False;
  FClosing  := False;
end;

procedure TJSExtensionWithFunctionFrm.FormShow(Sender: TObject);
begin
  // GlobalCEFApp.GlobalContextInitialized has to be TRUE before creating any browser
  // If it's not initialized yet, we use a simple timer to create the browser later.
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) then Timer1.Enabled := True;
end;

procedure TJSExtensionWithFunctionFrm.WMMove(var aMessage : TWMMove);
begin
  inherited;

  if (Chromium1 <> nil) then Chromium1.NotifyMoveOrResizeStarted;
end;

procedure TJSExtensionWithFunctionFrm.WMMoving(var aMessage : TMessage);
begin
  inherited;

  if (Chromium1 <> nil) then Chromium1.NotifyMoveOrResizeStarted;
end;

procedure TJSExtensionWithFunctionFrm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) and not(Chromium1.Initialized) then
    Timer1.Enabled := True;
end;

procedure TJSExtensionWithFunctionFrm.BrowserCreatedMsg(var aMessage : TMessage);
begin
  Caption := 'JSExtensionWithFunction';
  CEFWindowParent1.UpdateSize;
  NavControlPnl.Enabled := True;
  GoBtn.Click;
end;

procedure TJSExtensionWithFunctionFrm.WMEnterMenuLoop(var aMessage: TMessage);
begin
  inherited;

  if (aMessage.wParam = 0) and (GlobalCEFApp <> nil) then GlobalCEFApp.OsmodalLoop := True;
end;

procedure TJSExtensionWithFunctionFrm.WMExitMenuLoop(var aMessage: TMessage);
begin
  inherited;

  if (aMessage.wParam = 0) and (GlobalCEFApp <> nil) then GlobalCEFApp.OsmodalLoop := False;
end;

procedure TJSExtensionWithFunctionFrm.BrowserDestroyMsg(var aMessage : TMessage);
begin
  CEFWindowParent1.Free;
end;

end.
