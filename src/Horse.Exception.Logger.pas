unit Horse.Exception.Logger;

{$IFDEF FPC }
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC }
  SysUtils, Classes, SyncObjs, Generics.Collections,
  {$ELSE}
  System.SysUtils, System.SyncObjs, System.Classes, System.Generics.Collections,
  {$ENDIF}
  Horse, Horse.Utils.ClientIP;

type
  THorseExceptionLoggerConfig = class
  public
    LogDir: string;
    LogFormat: string;
    constructor Create(ALogFormat: string; ALogDir: string); overload;
    constructor Create(ALogFormat: string); overload;
  end;

  THorseExceptionLogger = class(TThread)
  private
    FCriticalSection: TCriticalSection;
    FEvent: TEvent;
    FLogCache: TList<string>;
    procedure SaveLogCache;
    procedure FreeInternalInstances;
    function ExtractLogCache: TArray<string>;
    class var FHorseLoggerConfig : THorseExceptionLoggerConfig;
    class var FHorseLogger: THorseExceptionLogger;
    class function ValidateValue(AValue: Integer): string; overload;
    class function ValidateValue(AValue: string): string; overload;
    class function ValidateValue(AValue: TDateTime): string; overload;
    class function GetDefaulTHorseExceptionLogger: THorseExceptionLogger;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    function NewLog(ALog: string): THorseExceptionLogger;
    procedure Execute; override;
    class destructor UnInitialize;
    class function GetDefault: THorseExceptionLogger;
    class function New(AConfig: THorseExceptionLoggerConfig): THorseCallback; overload;
    class function New: THorseCallback; overload;
  end;

const
  DEFAULT_HORSE_LOG_FORMAT =
    '${request_clientip} [${time}]'+
    ' "${request_method} ${request_path_info} ${request_version}"'+
    ' ${response_status} ${exception}';

implementation

uses
  {$IFDEF FPC }
    DateUtils, HTTPDefs, fpjson, TypInfo;
  {$else}
    Web.HTTPApp, System.DateUtils, System.JSON, System.TypInfo;
  {$ENDIF}

procedure Middleware(ARequest: THorseRequest; AResponse: THorseResponse; ANext: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
var
  LBeforeDateTime: TDateTime;
  LAfterDateTime: TDateTime;
  LMilliSecondsBetween: Integer;
  LLog: string;
  LJSON: TJSONObject;
  procedure processLog;
  begin
    LAfterDateTime := Now();
    LMilliSecondsBetween := MilliSecondsBetween(LAfterDateTime, LBeforeDateTime);

    LLog := THorseExceptionLogger.GetDefault.FHorseLoggerConfig.LogFormat;
    LLog := LLog.Replace('${time}', THorseExceptionLogger.ValidateValue(LBeforeDateTime));
    LLog := LLog.Replace('${execution_time}', THorseExceptionLogger.ValidateValue(LMilliSecondsBetween));
    LLog := LLog.Replace('${request_clientip}', THorseExceptionLogger.ValidateValue(ClientIP(ARequest)));
    LLog := LLog.Replace('${request_method}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Method));
    LLog := LLog.Replace('${request_version}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ProtocolVersion));
    LLog := LLog.Replace('${request_url}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.URL));
    LLog := LLog.Replace('${request_query}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Query));
    LLog := LLog.Replace('${request_path_info}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.PathInfo));
    LLog := LLog.Replace('${request_path_translated}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.PathTranslated));
    LLog := LLog.Replace('${request_cookie}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Cookie));
    LLog := LLog.Replace('${request_accept}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Accept));
    LLog := LLog.Replace('${request_from}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.From));
    LLog := LLog.Replace('${request_host}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Host));
    LLog := LLog.Replace('${request_referer}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Referer));
    LLog := LLog.Replace('${request_user_agent}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.UserAgent));
    LLog := LLog.Replace('${request_connection}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Connection));
    LLog := LLog.Replace('${request_remote_addr}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.RemoteAddr));
    LLog := LLog.Replace('${request_remote_host}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.RemoteHost));
    LLog := LLog.Replace('${request_script_name}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ScriptName));
    LLog := LLog.Replace('${request_server_port}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ServerPort));
    LLog := LLog.Replace('${request_script_name}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ScriptName));
    LLog := LLog.Replace('${request_authorization}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.Authorization));
    LLog := LLog.Replace('${request_content_encoding}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ContentEncoding));
    LLog := LLog.Replace('${request_content_type}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ContentType));
    LLog := LLog.Replace('${request_content_length}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.ContentLength));
    LLog := LLog.Replace('${response_server}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.Server));
    LLog := LLog.Replace('${response_allow}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.Allow));
    LLog := LLog.Replace('${response_location}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.Location));
    LLog := LLog.Replace('${response_content_encoding}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.ContentEncoding));
    LLog := LLog.Replace('${response_content_type}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.ContentType));
    LLog := LLog.Replace('${response_content_length}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.ContentLength));
    LLog := LLog.Replace('${response_status}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.{$IF DEFINED(FPC)}Code.ToString(){$ELSE}StatusCode{$ENDIF}));
    {$IF NOT DEFINED(FPC)}
    LLog := LLog.Replace('${request_derived_from}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.DerivedFrom));
    LLog := LLog.Replace('${request_remote_ip}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest. RemoteIP));
    LLog := LLog.Replace('${request_internal_path_info}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.InternalPathInfo));
    LLog := LLog.Replace('${request_raw_path_info}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.RawPathInfo));
    LLog := LLog.Replace('${request_cache_control}', THorseExceptionLogger.ValidateValue(ARequest.RawWebRequest.CacheControl));
    LLog := LLog.Replace('${response_realm}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.Realm));
    LLog := LLog.Replace('${response_log_message}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.LogMessage));
    LLog := LLog.Replace('${response_title}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.Title));
    LLog := LLog.Replace('${response_content_version}', THorseExceptionLogger.ValidateValue(AResponse.RawWebResponse.ContentVersion));
    {$ENDIF}
    LLog := LLog.Replace('${exception}', THorseExceptionLogger.ValidateValue(LJSON.ToJSON));
  end;
begin
  LBeforeDateTime := Now();
  try
    ANext();
  except
    on E: EHorseCallbackInterrupted do
      raise;
    on E: EHorseException do
    begin
      LJSON := TJSONObject.Create;
      LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('error', E.Error);
      if not E.Title.Trim.IsEmpty then
      begin
        LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('title', E.Title);
      end;
      if not E.&Unit.Trim.IsEmpty then
      begin
        LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('unit', E.&Unit);
      end;
      if E.Code <> 0 then
      begin
        LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('code', {$IF DEFINED(FPC)}TJSONIntegerNumber{$ELSE}TJSONNumber{$ENDIF}.Create(E.Code));
      end;
      if E.&Type <> TMessageType.Default then
      begin
        LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('type', GetEnumName(TypeInfo(TMessageType), Integer(E.&Type)));
      end;

      processLog;
      THorseExceptionLogger.GetDefault.NewLog(LLog);
      raise;
    end;
    on E: Exception do
    begin
      LJSON := TJSONObject.Create;
      LJSON.{$IF DEFINED(FPC)}Add{$ELSE}AddPair{$ENDIF}('error', E.Message);
      processLog;
      THorseExceptionLogger.GetDefault.NewLog(LLog);
      raise;
    end;
  end;
end;

constructor THorseExceptionLoggerConfig.Create(ALogFormat: string; ALogDir: string);
begin
  LogFormat := ALogFormat;
  LogDir := ALogDir;
end;

constructor THorseExceptionLoggerConfig.Create(ALogFormat: string);
begin
  Create(ALogFormat, ExtractFileDir(ParamStr(0)));
end;

{ THorseExceptionLogger }

procedure THorseExceptionLogger.AfterConstruction;
begin
  inherited;
  FLogCache := TList<string>.Create;
  FEvent := TEvent.Create{$IFDEF FPC}(nil, False, True, 'HORSE_EXCEPTION_LOGGER'){$ENDIF};
  FCriticalSection := TCriticalSection.Create;
end;

procedure THorseExceptionLogger.BeforeDestruction;
begin
  inherited;
  FreeInternalInstances;
end;

procedure THorseExceptionLogger.Execute;
var
  LWait: TWaitResult;
begin
  inherited;
  while not(Self.Terminated) do
  begin
    LWait := FEvent.WaitFor(INFINITE);
    FEvent.ResetEvent;
    case LWait of
      wrSignaled:
        begin
          SaveLogCache;
        end
    else
      Continue;
    end;
  end;
end;

class function THorseExceptionLogger.GetDefault: THorseExceptionLogger;
begin
  Result := GetDefaulTHorseExceptionLogger;
end;

class function THorseExceptionLogger.GetDefaulTHorseExceptionLogger: THorseExceptionLogger;
begin
  if not Assigned(FHorseLogger) then
  begin
    FHorseLogger := THorseExceptionLogger.Create(True);
    FHorseLogger.FreeOnTerminate := True;
    FHorseLogger.Start;
  end;
  Result := FHorseLogger;
end;

function THorseExceptionLogger.ExtractLogCache: TArray<string>;
var
  LLogCacheArray: TArray<string>;
begin
  FCriticalSection.Enter;
  try
    LLogCacheArray := FLogCache.ToArray;
    FLogCache.Clear;
    FLogCache.TrimExcess;
  finally
    FCriticalSection.Leave;
  end;
  Result := LLogCacheArray;
end;

procedure THorseExceptionLogger.FreeInternalInstances;
begin
  FLogCache.Free;
  FEvent.Free;
  FCriticalSection.Free;
end;

class function THorseExceptionLogger.New(AConfig: THorseExceptionLoggerConfig): THorseCallback;
begin
  Self.FHorseLoggerConfig := AConfig;
  Result := Middleware;
end;

class function THorseExceptionLogger.New: THorseCallback;
var
  LLogFormat: string;
begin
  LLogFormat := DEFAULT_HORSE_LOG_FORMAT;
  Result := THorseExceptionLogger.New(THorseExceptionLoggerConfig.Create(LLogFormat));
end;

function THorseExceptionLogger.NewLog(ALog: string): THorseExceptionLogger;
begin
  Result := Self;
  FCriticalSection.Enter;
  try
    FLogCache.Add(ALog);
  finally
    FCriticalSection.Leave;
    FEvent.SetEvent;
  end;
end;

procedure THorseExceptionLogger.SaveLogCache;
var
  LFilename: string;
  LLogCacheArray: TArray<string>;
  LTextFile: TextFile;
  I: Integer;
begin
  FCriticalSection.Enter;
  try
    if not DirectoryExists(FHorseLoggerConfig.LogDir) then
      ForceDirectories(FHorseLoggerConfig.LogDir);
    LFilename := FHorseLoggerConfig.LogDir + PathDelim + 'error_' + FormatDateTime('yyyy-mm-dd', Now()) + '.log';
    AssignFile(LTextFile, LFilename);
    if (FileExists(LFilename)) then
      Append(LTextFile)
    else
      Rewrite(LTextFile);
    try
      LLogCacheArray := ExtractLogCache;
      for I := Low(LLogCacheArray) to High(LLogCacheArray) do
      begin
        writeln(LTextFile, LLogCacheArray[I]);
      end;
    finally
      CloseFile(LTextFile);
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

class destructor THorseExceptionLogger.UnInitialize;
begin
  if Assigned(FHorseLoggerConfig) then
    FreeAndNil(FHorseLoggerConfig);
  if Assigned(FHorseLogger) then
  begin
    FHorseLogger.Terminate;
    FHorseLogger.FEvent.SetEvent;
  end;
end;

class function THorseExceptionLogger.ValidateValue(AValue: TDateTime): string;
begin
  Result := FormatDateTime('dd/MMMM/yyyy hh:mm:ss:zzz', AValue);
end;

class function THorseExceptionLogger.ValidateValue(AValue: string): string;
begin
  Result := AValue;
  if AValue.IsEmpty then
    Result := '-';
end;

class function THorseExceptionLogger.ValidateValue(AValue: Integer): string;
begin
  Result := AValue.ToString;
end;

end.
