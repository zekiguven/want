(****************************************************************************
 * WANT - A build management tool.                                          *
 * Copyright (c) 2001-2003 Juancarlo Anez, Caracas, Venezuela.              *
 * All rights reserved.                                                     *
 *                                                                          *
 * This library is free software; you can redistribute it and/or            *
 * modify it under the terms of the GNU Lesser General Public               *
 * License as published by the Free Software Foundation; either             *
 * version 2.1 of the License, or (at your option) any later version.       *
 *                                                                          *
 * This library is distributed in the hope that it will be useful,          *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU        *
 * Lesser General Public License for more details.                          *
 *                                                                          *
 * You should have received a copy of the GNU Lesser General Public         *
 * License along with this library; if not, write to the Free Software      *
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA *
 ****************************************************************************)
{
    @brief

    @author Thomas Jund
}

unit EurekaLogTasks;

interface
uses
  {Delphi}
  Windows,
  SysUtils,
  Classes,
  TypInfo,

  {Jcl}
  JclBase,
  JclSysUtils,
  JclMiscel,
  JclSysInfo,
  JclRegistry,
  JclStrings,

  {Local}
  JalStrings,

  XPerlRe,

  WantUtils,
  WantClasses,
  ExecTasks,
  WildPaths,
  PatternSets,
  Attributes,

  DelphiTasks;

  
type
  TEurekaLogElement = class(TOptionElement)
  protected
    BValue : boolean;

  public
    procedure Init; override;

  published
    property Value : boolean read BValue write BValue;
  end;

  TEurekaLogCompileTask = class(TDelphiCompileTask)
  protected
    FElogPath: TPath;
    class function ToolName : string; override;

  published
    property eurekaLogCfg :TPath read FElogPath write FElogPath;

  public
    class function TagName : string; override;
    function BuildArguments : string; override;
  end;

implementation

{ TEurekaLogElement }

procedure TEurekaLogElement.Init;
begin
  inherited Init;
  dcc.AddDefine('EUREKALOG', 'EUREKALOG');
end;


{ TEurekaLogCompileTask }

class function TEurekaLogCompileTask.ToolName : string;
begin
  Result := 'bin\ecc32.exe';
end;

class function TEurekaLogCompileTask.TagName : string;
begin
  Result := 'ecc';
end;

function TEurekaLogCompileTask.BuildArguments : string;
var
  sReturn : string;
begin
  sReturn := inherited BuildArguments;
  if eurekaLogCfg <> '' then
  begin
    Log(vlVerbose, 'eurekaLogCfg=' + ToRelativePath(eurekaLogCfg));
    Result := sReturn + PathOpt('-el_config', ToRelativePath(eurekaLogCfg));
  end;
end;

initialization
  RegisterTasks( [TEurekaLogCompileTask]);
  RegisterElements(TEurekaLogCompileTask, [
                         TDefineElement ,
                         TUsePackageElement,
                         TWarningElement,
                         TUnitAliasElement,
                         TEurekaLogElement
                         ]);
                         
end.
