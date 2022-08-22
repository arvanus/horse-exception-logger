# horse-exception-logger
Middleware for exception logging in HORSE

### For install in your project using [boss](https://github.com/HashLoad/boss):
``` sh
$ boss install arvanus/horse-exception-logger
```

### Format
`Format` defines the logging format with defined variables

Default: `${request_clientip} [${time}] ${request_method} ${request_path_info} ${request_version} ${response_status} ${exception}`

Possible values: `time`,`execution_time`,`request_clientip`,`request_method`,`request_version`,`request_url`,`request_query`,`request_path_info`,`request_path_translated`,`request_cookie`,`request_accept`,`request_from`,`request_host`,`request_referer`,`request_user_agent`,`request_connection`,`request_derived_from`,`request_remote_addr`,`request_remote_host`,`request_script_name`,`request_server_port`,`request_remote_ip`,`request_internal_path_info`,`request_raw_path_info`,`request_cache_control`,`request_script_name`,`request_authorization`,`request_content_encoding`,`request_content_type`,`request_content_length`,`request_content_version`,`response_version`,`response_reason`,`response_server`,`response_realm`,`response_allow`,`response_location`,`response_log_message`,`response_title`,`response_content_encoding`,`response_content_type`,`response_content_length`,`response_content_version`,`response_status`, `exception`

Sample Horse Logger
```delphi
uses Horse, Horse.Exception.Logger;

begin
  THorse.Use(THorseExceptionLogger.New()); // Must come after HandleException middleware

  THorse.Get('/raise',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      raise Exception.Create('Exception test');
    end);

  THorse.Listen(9000);
end.
```

Sample Horse Exception Logger with custom log format and log folder
```delphi
uses Horse, Horse.Logger;

var
  HorseLoggerConfig: THorseLoggerConfig;

begin
  HorseLoggerConfig := THorseLoggerConfig.Create('${time} - ${request_method} ${request_path_info} {exception}', '/var/log/horse');
  THorse.Use(THorseExceptionLogger.New(HorseLoggerConfig));

  THorse.Get('/raise',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      raise Exception.Create('Exception test');
    end);

  THorse.Listen(9000);
end.
```


### Note
Middleware based at `horse-logger` and `horse-HandleException`
