{
Parameters are:
1 - local folder path
2 - FTP URL with port and remote folder path
3 - FTP login
4 - FTP password
Example:
c:/foldersync ftp://server.com:21/var/www/server.com/folder/ root qwerty

If no commandline parameters then INI file will be used instead
}

program FTPSync;

{$APPTYPE CONSOLE}

uses
  SysUtils, inifiles, strutils,
  uFTPSync in 'uFTPSync.pas';

var ini:TInifile;
begin
  try
    if paramstr(4)<>emptystr then
      DoSync(paramstr(1),paramstr(2), paramstr(3), paramstr(4))
    else begin
      ini:=tinifile.Create(ExtractFilePath( GetModuleName(HInstance) ) + ansireplacestr(ExtractFileName(paramstr(0)),'.exe','.ini'));
      try
        DoSync(
          ini.ReadString('ftpsync','localfolder',''),
          ini.ReadString('ftpsync','ftpfolder',''),
          ini.ReadString('ftpsync','login',''),
          ini.ReadString('ftpsync','password','')
        );
      finally
        freeandnil(ini);
      end;
    end;
    readln;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
