program samples;

{$APPTYPE CONSOLE}
{$R *.res}

uses System.SysUtils, Horse, Horse.Exception.Logger;

begin
  THorse.Use(THorseExceptionLogger.New()); // Must come after HandleException middleware

  THorse.Get('/raise',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      raise Exception.Create('Exception test');
    end);


  THorse.Listen(9000);
end.
