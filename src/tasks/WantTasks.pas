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

    @author Juanco Añez
}

unit WantTasks;

interface
uses
  SysUtils,
  Classes,

  JclSysUtils,

  WantClasses,
  ScriptRunner,
  WildPaths,
  PatternSets;


type
  TSubProjectPropertyElement = class(TScriptElement)
  public
    class function TagName :string;              override;
    procedure SetProperty(Name, Value :string; overwrite :boolean = false); override;
  end;

  TCustomWantTask = class(TTask)
  protected
    FTarget     :string;
  public
    property _target   :string read FTarget    write FTarget;
  end;

  TWantTask = class(TCustomWantTask)
  protected
    FBuildFile  :TPath;
    FSubProject :TProject;
    FDir        :TPath;
  public
    constructor Create(Owner: TScriptElement = nil); override;
    destructor  Destroy; override;

    procedure Init; override;
    procedure Execute;  override;
  published
    property _target;
    property buildfile :TPath read FBuildFile write FBuildFile;
    property dir       :TPath read FDir write FDir;
  end;


implementation

{ TWantTask }

constructor TWantTask.Create(Owner: TScriptElement);
begin
  inherited Create(Owner);
  FSubProject := TProject.Create(Self);
  FSubProject.Listener := Self.Project.Listener;
end;

destructor TWantTask.Destroy;
begin
  FSubProject.Free;
  inherited Destroy;
end;


procedure TWantTask.Init;
begin
  inherited Init;
  FSubProject.RootPath := ToAbsolutePath(PathConcat(Project.RootPath, Dir));
  Log(vlDebug, 'dir=%s(%s)', [dir, ToAbsolutePath(dir)]);
  Log(vlDebug, 'BasePath=%s(%s)', [BasePath, ToAbsolutePath(BasePath)]);
end;

procedure TWantTask.Execute;
var
  FRunner :TScriptRunner;
begin
  ChangeDir(BasePath);
  Log(vlDebug, 'dir=%s(%s)', [dir, ToAbsolutePath(dir)]);
  Log(vlDebug, 'basePath=%s(%s)', [BasePath, ToAbsolutePath(BasePath)]);
  try
    FRunner := TScriptRunner.Create;
    try
      FRunner.Listener  := Self.Project.Listener;
      ChangeDir(FSubProject.BasePath);
      FRunner.LoadProject(FSubProject, buildfile, false);
      FRunner.BuildProject(FSubProject, _target);
    finally
      FRunner.Free;
    end;
  except
    on e :Exception do
      TaskError(e.Message, ExceptAddr);
  end;
end;

{ TSubProjectPropertyElement }

class function TSubProjectPropertyElement.TagName: string;
begin
  Result := 'property';
end;

procedure TSubProjectPropertyElement.SetProperty(Name, Value: string; overwrite :boolean);
begin
  (Owner as TWantTask).FSubProject.SetProperty(Name, Value, overwrite);
end;

initialization
 RegisterTasks([TWantTask]);
 //RegisterElements(TWantTask,[TSubProjectPropertyElement]);
end.
