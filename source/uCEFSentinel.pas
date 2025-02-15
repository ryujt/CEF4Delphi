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

 // Attribution :
 // TCEFSentinel icon made by Everaldo Coelho
 // https://www.iconfinder.com/icons/17914/castle_fortress_tower_war_icon
 // http://www.everaldo.com/

unit uCEFSentinel;

{$IFDEF FPC}
  {$MODE OBJFPC}{$H+}
{$ENDIF}

{$IFNDEF CPUX64}{$ALIGN ON}{$ENDIF}
{$MINENUMSIZE 4}

{$I cef.inc}

interface

uses
  {$IFDEF DELPHI16_UP}
    {$IFDEF MSWINDOWS}WinApi.Windows, WinApi.Messages,{$ENDIF}
    System.Classes, Vcl.Controls, Vcl.ExtCtrls, System.SysUtils, System.SyncObjs, System.Math,
  {$ELSE}
    {$IFDEF MSWINDOWS}Windows, {$ENDIF} Classes, Controls, ExtCtrls, SysUtils, SyncObjs, Math,
    {$IFDEF FPC}
    LCLProc, LCLIntf, LResources, LMessages, InterfaceBase,
    {$ELSE}
    Messages,
    {$ENDIF}
  {$ENDIF}
  uCEFTypes, uCEFInterfaces;

const
  CEFSENTINEL_DEFAULT_DELAYPERPROCMS = 200;
  CEFSENTINEL_DEFAULT_MININITDELAYMS = 1500;
  CEFSENTINEL_DEFAULT_FINALDELAYMS   = 100;
  CEFSENTINEL_DEFAULT_MINCHILDPROCS  = 2;
  CEFSENTINEL_DEFAULT_MAXCHECKCOUNTS = 10;

type
  TSentinelStatus = (ssIdle, ssInitialDelay, ssCheckingChildren, ssClosing);

  {$IFNDEF FPC}{$IFDEF DELPHI16_UP}[ComponentPlatformsAttribute(pidWin32 or pidWin64)]{$ENDIF}{$ENDIF}
  TCEFSentinel = class(TComponent)
    protected
      FCompHandle             : HWND;
      FStatus                 : TSentinelStatus;
      FStatusCS               : TCriticalSection;
      FDelayPerProcMs         : cardinal;
      FMinInitDelayMs         : cardinal;
      FFinalDelayMs           : cardinal;
      FMinChildProcs          : integer;
      FMaxCheckCount          : integer;
      FCheckCount             : integer;
      FOnClose                : TNotifyEvent;
      FTimer                  : TTimer;

      function  GetStatus : TSentinelStatus;
      function  GetChildProcCount : integer;

      {$IFDEF MSWINDOWS}
      procedure WndProc(var aMessage: TMessage);
      procedure doStartMsg(var aMessage : TMessage); virtual;
      procedure doCloseMsg(var aMessage : TMessage); virtual;
      {$ENDIF}
      function  SendCompMessage(aMsg : cardinal) : boolean;
      function  CanClose : boolean; virtual;

      procedure Timer_OnTimer(Sender: TObject); virtual;

    public
      constructor Create(AOwner: TComponent); override;
      destructor  Destroy; override;
      procedure   AfterConstruction; override;
      procedure   Start; virtual;

      property Status          : TSentinelStatus  read GetStatus;
      property ChildProcCount  : integer          read GetChildProcCount;

    published
      property DelayPerProcMs  : cardinal         read FDelayPerProcMs   write FDelayPerProcMs  default CEFSENTINEL_DEFAULT_DELAYPERPROCMS;
      property MinInitDelayMs  : cardinal         read FMinInitDelayMs   write FMinInitDelayMs  default CEFSENTINEL_DEFAULT_MININITDELAYMS;
      property FinalDelayMs    : cardinal         read FFinalDelayMs     write FFinalDelayMs    default CEFSENTINEL_DEFAULT_FINALDELAYMS;
      property MinChildProcs   : integer          read FMinChildProcs    write FMinChildProcs   default CEFSENTINEL_DEFAULT_MINCHILDPROCS;
      property MaxCheckCount   : integer          read FMaxCheckCount    write FMaxCheckCount   default CEFSENTINEL_DEFAULT_MAXCHECKCOUNTS;

      property OnClose         : TNotifyEvent     read FOnClose          write FOnClose;
  end;

{$IFDEF FPC}
procedure Register;
{$ENDIF}

implementation

uses
  uCEFLibFunctions, uCEFApplication, uCEFMiscFunctions, uCEFConstants;

constructor TCEFSentinel.Create(AOwner: TComponent);
begin
  inherited Create(aOwner);

  FCompHandle             := 0;
  FDelayPerProcMs         := CEFSENTINEL_DEFAULT_DELAYPERPROCMS;
  FMinInitDelayMs         := CEFSENTINEL_DEFAULT_MININITDELAYMS;
  FFinalDelayMs           := CEFSENTINEL_DEFAULT_FINALDELAYMS;
  FMinChildProcs          := CEFSENTINEL_DEFAULT_MINCHILDPROCS;
  FMaxCheckCount          := CEFSENTINEL_DEFAULT_MAXCHECKCOUNTS;
  FOnClose                := nil;
  FTimer                  := nil;
  FStatusCS               := nil;
  FStatus                 := ssIdle;
  FCheckCount             := 0;
end;

procedure TCEFSentinel.AfterConstruction;
{$IFDEF FPC}
var
  TempWndMethod : TWndMethod;
{$ENDIF}
begin
  inherited AfterConstruction;

  if not(csDesigning in ComponentState) then
    begin
      {$IFDEF FPC}
      {$IFDEF MSWINDOWS}
      TempWndMethod    := @WndProc;
      FCompHandle      := AllocateHWnd(TempWndMethod);
      {$ENDIF}
      {$ELSE}
      FCompHandle      := AllocateHWnd(WndProc);
      {$ENDIF}

      FStatusCS        := TCriticalSection.Create;
      FTimer           := TTimer.Create(nil);
      FTimer.Enabled   := False;
      FTimer.OnTimer   := {$IFDEF FPC}@{$ENDIF}Timer_OnTimer;
    end;
end;

destructor TCEFSentinel.Destroy;
begin
  try
    {$IFDEF MSWINDOWS}
    if (FCompHandle <> 0) then
      begin
        DeallocateHWnd(FCompHandle);
        FCompHandle := 0;
      end;
    {$ENDIF}

    if (FTimer    <> nil) then FreeAndNil(FTimer);
    if (FStatusCS <> nil) then FreeAndNil(FStatusCS);
  finally
    inherited Destroy;
  end;
end;

{$IFDEF MSWINDOWS}
procedure TCEFSentinel.WndProc(var aMessage: TMessage);
begin
  case aMessage.Msg of
    CEF_SENTINEL_START   : doStartMsg(aMessage);
    CEF_SENTINEL_DOCLOSE : doCloseMsg(aMessage);

    else aMessage.Result := DefWindowProc(FCompHandle, aMessage.Msg, aMessage.WParam, aMessage.LParam);
  end;
end;

procedure TCEFSentinel.doStartMsg(var aMessage : TMessage);
begin
  if (FTimer <> nil) then
    begin
      FTimer.Interval := max(ChildProcCount * CEFSENTINEL_DEFAULT_DELAYPERPROCMS, FMinInitDelayMs);
      FTimer.Enabled  := True;
    end;
end;

procedure TCEFSentinel.doCloseMsg(var aMessage : TMessage);
begin
  if assigned(FOnClose) then FOnClose(self);
end;
{$ENDIF}

function TCEFSentinel.SendCompMessage(aMsg : cardinal) : boolean;
begin
  Result := (FCompHandle <> 0) and PostMessage(FCompHandle, aMsg, 0, 0);
end;

procedure TCEFSentinel.Start;
begin
  try
    if (FStatusCS <> nil) then FStatusCS.Acquire;

    if (FStatus = ssIdle) then
      begin
        FStatus := ssInitialDelay;
        SendCompMessage(CEF_SENTINEL_START);
      end;
  finally
    if (FStatusCS <> nil) then FStatusCS.Release;
  end;
end;

function TCEFSentinel.GetStatus : TSentinelStatus;
begin
  Result := ssIdle;

  if (FStatusCS <> nil) then
    try
      FStatusCS.Acquire;
      Result := FStatus;
    finally
      FStatusCS.Release;
    end;
end;

function TCEFSentinel.GetChildProcCount : integer;
begin
  if (GlobalCEFApp <> nil) then
    Result := GlobalCEFApp.ChildProcessesCount
   else
    Result := 0;
end;

function TCEFSentinel.CanClose : boolean;
begin
  Result := (FCheckCount >= FMaxCheckCount) or
            (GlobalCEFApp = nil) or
            (ChildProcCount <= FMinChildProcs);
end;

procedure TCEFSentinel.Timer_OnTimer(Sender: TObject);
begin
  FTimer.Enabled := False;

  try
    if (FStatusCS <> nil) then FStatusCS.Acquire;

    case FStatus of
      ssInitialDelay :
        if CanClose then
          begin
            FStatus := ssClosing;
            SendCompMessage(CEF_SENTINEL_DOCLOSE);
          end
         else
          begin
            FStatus         := ssCheckingChildren;
            FCheckCount     := 0;
            FTimer.Interval := FFinalDelayMs;
            FTimer.Enabled  := True;
          end;

      ssCheckingChildren :
        if CanClose then
          begin
            FStatus := ssClosing;
            SendCompMessage(CEF_SENTINEL_DOCLOSE);
          end
         else
          begin
            inc(FCheckCount);
            FTimer.Enabled := True;
          end;
    end;
  finally
    if (FStatusCS <> nil) then FStatusCS.Release;
  end;
end;

{$IFDEF FPC}
procedure Register;
begin
  {$I res/tcefsentinel.lrs}
  RegisterComponents('Chromium', [TCEFSentinel]);
end;
{$ENDIF}

end.
