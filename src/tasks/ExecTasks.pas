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

    @author Juancarlo Añez
}
unit ExecTasks;

interface
uses
  SysUtils,
  Math,
  Classes,

  JclBase,
  JclMiscel,
  JclSysInfo,
  JclSecurity,

  JalPaths,

  XPerlRE,

  WildPaths,
  WantUtils,
  WantClasses,
  Attributes,
  JalProcesses;



type
  TArgElement = class(TScriptElement)
  protected
    FVAlue  :string;
    FIsPath :boolean;

    function Getpath :TPath;
    procedure SetPath(Path :TPath);

  public
    procedure Init; override;

    function ExternalValue :string;
  published
    property value :string read FValue  write FValue;
    property path  :TPath  read GetPath write SetPath;
    property IsPath :boolean read FIsPath;
  end;

  TCustomExecTask = class(TTask)
  protected
    FOS          :string;
    FExecutable  :string;
    FArguments   :TStrings;
    FSkipLines   :Integer;
    FFailOnError :boolean;
    FErrorLevel  :Integer;
    FTimeOut     :Longint;
    FOutput      :string;
    FQuiet       :boolean;

    FFilters        :TStrings;
    FErrorFilters   :TStrings;
    FWarningFilters :TStrings;

    FDefaultFilters :boolean;

    procedure Init; override;
    
    function BuildExecutable :string; virtual;
    function BuildArguments  :string; virtual;
    function BuildCmdLine    :string; virtual;

    function  GetArguments :string;
    procedure SetArguments(Value :string);
    procedure SetArgumentList(Value :TStrings);

    function  GetFilters: string;
    procedure AddFilter(const Value: string);

    function  GetErrorFilters: string;
    procedure AddErrorFilter(const Value: string);

    function  GetWarningFilters: string;
    procedure AddWarningFilter(const Value: string);

    procedure Run(CmdLine: string);
    procedure HandleOutput(Child :TChildProcess);
    procedure HandleOutputLine(Line :string); virtual;
  public
    constructor Create(Owner: TScriptElement);  override;
    destructor Destroy; override;

    procedure Execute; override;
    function  ToSystemPath(const Path: TPath; const Base: TPath = ''):string; override;

  protected
    property Arguments:    string   read GetArguments write SetArguments;
    property ArgumentList: TStrings read FArguments   write SetArgumentList stored False;
    property Executable:   string   read FExecutable  write FExecutable;
    property SkipLines:    Integer  read FSkipLines   write FSkipLines;
    property OS:           string   read FOS          write FOS;
    property failonerror:  boolean  read FFailOnError write FFailOnError default True;
    property errorlevel:   Integer  read FErrorLevel  write FErrorLevel;
    property output:       string   read FOutput      write FOutput;
    property quiet:        boolean  read FQuiet       write FQuiet;

    property filter:       string   read GetFilters    write AddFilter;
    property errorfilter:  string   read GetErrorFilters    write AddErrorFilter;
    property warningfilter:string   read GetWarningFilters  write AddWarningFilter;

    property defaultfilters :boolean read FDefaultFilters write FDefaultFilters;
    {:@TODO Implement a TWaitableTimer class to implement timeouts.
      Use Windows.CreateWaitableTimer and Windows.SetWaitableTimer.
      !!!
    }
    property timeout:      Longint  read FTimeout     write FTimeout;
  published
  end;

  TExecTask = class(TCustomExecTask)
  public
    procedure Init; override;
    procedure Execute; override;
  published
    property basedir;
    property Arguments;
    property ArgumentList stored False;
    property Executable;
    property SkipLines :Integer     read FSkipLines   write FSkipLines;
    property OS;
    property failonerror;
    property errorlevel;
    property output;
    property quiet;
    property filter;
    property errorfilter;
    property warningfilter;
    property defaultfilters;
  end;

  // this class will pass commands through the command processor
  TShellTask = class(TExecTask)
  protected
    function BuildExecutable :string; override;
  end;

implementation

{ TExecTask }

procedure TExecTask.Execute;
begin
  Log(PathFile(Executable));
  Log(vlDebug, 'executable=' + ToPath(Executable));
  Log(vlDebug, 'arguments='  + BuildArguments);
  inherited Execute;
end;

procedure TExecTask.Init;
begin
  inherited Init;
  RequireAttribute('executable');
end;

{ TShellTask }

function TShellTask.BuildExecutable: string;
const
  SHELL_VAR = 'COMSPEC';
var
  ComSpec :string;
begin
  Result := inherited BuildExecutable;
  if GetEnvironmentVar(SHELL_VAR, Comspec, false) then
    Result := ComSpec + ' /c ' + Result
  else if IsWinNT then
    Result := 'cmd.exe /c ' + Result
  else
    Result := 'command.com /c ' + Result;
end;

{ TCustomExecTask }

function TCustomExecTask.BuildExecutable: string;
begin
  Result := WildPaths.ToSystemPath(Executable);
end;

function TCustomExecTask.BuildCmdLine: string;
begin
  Result := Trim(Trim(BuildExecutable) + ' ' + BuildArguments);
end;

function TCustomExecTask.BuildArguments: string;
var
  i: Integer;
begin
  Result := '';
  { Arguments.CommaText screws with the contents. See unit test }
  for i := 0 to FArguments.Count-1 do
  begin
    Result := Result + ' ' + FArguments[i];
  end;
  for i := 0 to ChildCount-1 do
  begin
    if Children[i] is TArgElement then
      Result := Result + ' ' + TArgElement(Children[i]).ExternalValue;
  end;
  Result := Trim(Result);
end;

constructor TCustomExecTask.Create(Owner: TScriptElement);
begin
  inherited Create(Owner);
  FArguments      := TStringList.Create;
  FFilters        := TStringList.Create;
  FErrorFilters   := TStringList.Create;
  FWarningFilters := TStringList.Create;
  FFailOnError := True;
end;

destructor TCustomExecTask.Destroy;
begin
  FreeAndNil(FArguments);
  FreeAndNil(FFilters);
  FreeAndNil(FErrorFilters);
  FreeAndNil(FWarningFilters);
  inherited;
end;

procedure TCustomExecTask.Execute;
var
  CmdLine :string;
begin
  inherited;
  Log(vlDebug, 'currentDir=%s', [CurrentDir] );
  CmdLine := BuildCmdLine;
  Log(vlVerbose, CmdLine);
  Run(CmdLine);
end;


function TCustomExecTask.GetArguments: string;
begin
  Result := FArguments.CommaText;
end;

procedure TCustomExecTask.SetArguments(Value: string);
begin
  FArguments.CommaText := Value;
end;

procedure TCustomExecTask.SetArgumentList(Value: TStrings);
begin
  FArguments.Assign(Value);
end;

procedure TCustomExecTask.Run(CmdLine :string);
var
  Child    :TChildProcess;
  ExitCode :Integer;
begin
  if ChildProcessClass = nil then
    TaskError('No Child Process implementation?');

  Child := ChildProcessClass.Create;
  try
    try
      Child.Run(CmdLine);
    except
      on e :Exception do
        TaskFailure(e.Message, ExceptAddr);
    end;
    HandleOutput(Child);
    ExitCode := Child.ExitCode;
    if (ExitCode > errorlevel) and FailOnError then
      TaskFailure(Format('Exit code was %d', [ExitCode]));
  finally
    FreeAndNil(Child);
  end;
end;


procedure TCustomExecTask.HandleOutput(Child :TChildProcess);
const
  TimeOutMillis = 100;
var
  Line          :String;
  LineNo        :Integer;
  OutFile       :Text;
begin
  LineNo := 0;

  if output <> '' then
  begin
    Log(vlVerbose, 'output to "%s"', [output]);
    Assign(OutFile, ToSystemPath(output));
    Rewrite(OutFile);
  end;

  try
    while not Child.EOF
    and (LineNo < SkipLines) do
    begin
      Child.ReadLine;
      Inc(LineNo);
    end;

    while not Child.EOF do
    begin
      Line := Child.ReadLine;
      Log(vlDebug, 'output :%s', [Line]);
      //!!! Inc(LineNo); // never used
      if output <> '' then
        Writeln(OutFile, Line)
      else
        HandleOutputLine(Line);
    end;
  finally
    if output <> '' then
      Close(OutFile);
  end;
end;


procedure TCustomExecTask.HandleOutputLine(Line: string);
  function MatchFilters(F :TStrings) :boolean;
  var
    i :Integer;
  begin
    Result := false;
    for i := 0 to F.Count-1 do
    begin
      if XPerlre.regex.Match(F[i], Line) then
      begin
        Result := True;
        break
      end;
    end;
  end;

begin
  if not quiet then
    Log(Line)
  else
  begin
    if MatchFilters(FErrorFilters) then
      Log(vlErrors, Line)
    else if MatchFilters(FWarningFilters) then
      Log(vlWarnings, Line)
    else if MatchFilters(FFilters) then
      Log(Line)
  end;
end;

function TCustomExecTask.GetFilters: string;
begin
  Result := FFilters.CommaText;
end;

procedure TCustomExecTask.AddFilter(const Value: string);
begin
  FFilters.Add(Value);
end;

procedure TCustomExecTask.AddErrorFilter(const Value: string);
begin
  FErrorFilters.Add(Value);
end;

function TCustomExecTask.GetErrorFilters: string;
begin
  Result := FErrorFilters.CommaText;
end;

procedure TCustomExecTask.AddWarningFilter(const Value: string);
begin
  FWarningFilters.Add(Value);
end;

function TCustomExecTask.GetWarningFilters: string;
begin
  Result := FWarningFilters.CommaText;
end;

procedure TCustomExecTask.Init;
begin
  inherited Init;
  if defaultfilters then
  begin
    quiet         := true;
    errorfilter   := '[Ee]rror';
    errorfilter   := 'ERROR';
    errorfilter   := '[Ff]atal';
    errorfilter   := 'FATAL';
    warningfilter := '[Ww]arning';
    warningfilter := 'WARNING';
  end;
end;

function TCustomExecTask.ToSystemPath(const Path, Base: TPath): string;
begin
  Result :=inherited ToSystemPath(Path, Base);
  if Pos(' ', Result) > 0 then
    Result := '"' + Trim(Result) + '"';
end;

{ TArgElement }

function TArgElement.ExternalValue :string;
begin
  if not IsPath then
  begin
     Result := Value
  end
  else
  begin
     Result := ToSystemPath(ToRelativePath(Path));
     if Pos(' ', Result) > 0 then
     begin
       Result := Format('"%s"', [Result]);
     end;
  end;
end;

function TArgElement.Getpath: TPath;
begin
   Result := Value;
end;

procedure TArgElement.SetPath(Path: TPath);
begin
   Value := Path;
   FIsPath := true;
end;

procedure TArgElement.Init;
begin
  inherited Init;
  RequireAttribute('path|value');
end;

initialization
  RegisterTasks([TCustomExecTask, TExecTask, TShellTask]);
  RegisterElements(TCustomExecTask, [TArgElement]);
end.

