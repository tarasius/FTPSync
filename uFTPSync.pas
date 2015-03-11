{
Author: Taras Muravskyi
This unit contains a procedure that syncs local folder and FTP folder.
FTP folder contains master data, i.e. it is the source and local folder is the destination.
If FTP server supports hashes or other file verification methods, they will be used.
Otherwise size and modified timestamps are compared.
Filenames match is case insensitive.
}

unit uFTPSync;

interface

procedure DoSync(localfolder,ftpurl:string; login, password: string);

implementation

uses idFTP, classes, sysutils, iduri, Generics.Collections, Generics.Defaults,Windows,
     StrUtils, IdFTPList, IdAllFTPListParsers;

type
  TFtpFile = class
  public
    FileName: string;
    Description: string;
    Path: string;
    Content: TMemoryStream;
    Size:Int64;
    FileDate:tdatetime; //last modified
    constructor Create;
    destructor Destroy; override;
    function ToString: string; override;
    procedure FetchContent(AFtp: TIdFTP);
  end;

  TFtpFileList = class(TObjectList<TFtpFile>)
  public
    constructor Create; overload;
    procedure ParseFtp(AFtp: TIdFTP);
  end;

  TFileAttr=record
    Size:DWORD;
    DateTime:TDateTime;
  end;

  TLocalFileList=TDictionary<string,TFileAttr>;

constructor TFtpFile.Create;
begin
  Content := TMemoryStream.Create; // supports all encodings
end;

destructor TFtpFile.Destroy;
begin
  FreeAndNil(Content);
  inherited;
end;

function TFtpFile.ToString: string;
begin
  if (Path <> '') and not EndsStr('/', Path) then
    Path := Path + '/';
  Result := Path + FileName;
end;

procedure TFtpFile.FetchContent(AFtp: TIdFTP);
begin
  if AFtp.Connected then begin
    AFtp.Get(ToString, Content, False);
    Content.Seek(0, soFromBeginning);
  end;
end;

constructor TFtpFileList.Create;
begin
  inherited Create;
  OwnsObjects := True;
end;

procedure TFtpFileList.ParseFtp(AFtp: TIdFTP);

  procedure ParseDir(const ADir: string);
  var
    fr: TFtpFile;
    i,p: Integer;
    Name: string;
    AFList:TStringList;
    li:string;
  begin
    if ADir <> '' then
      AFtp.ChangeDir(ADir);
    AFList:=TStringList.Create;
    try
      AFtp.List(AFList);
      for i := 0 to AFList.Count - 1 do begin
        li := AFList[i];
        p:=LastDelimiter(' ',li);
        if p>0 then
          Name := copy(li,p+1, length(li)-p)
        else
          Name:=li;
        if li[1]='d' then
          ParseDir(Name)
        else begin
          fr := TFtpFile.Create;
          try
            fr.FileName := Name;
            fr.Description :=li;
            fr.Path := ADir;
            fr.Size:=Aftp.Size(name);
            fr.filedate:=aftp.FileDate(name);
            Add(fr);
          except
            FreeAndNil(fr);
            raise;
          end;
        end;
      end;
    finally
      freeandnil(AFList);
    end;
    if ADir <> '' then
      AFtp.ChangeDirUp;
  end;

var
  comp: TDelegatedComparer<TFtpFile>;
begin
  if not AFtp.Connected then
    Exit;
  Clear;
  ParseDir('');
  comp := TDelegatedComparer<TFtpFile>.Create(
    function(const Left, Right: TFtpFile): Integer
    begin
      Result := CompareText(Left.ToString, Right.ToString);
    end);
  Sort(comp);
end;

procedure GetAllSubFolders(sPath: String; result:TLocalFileList);
var
  Path : String;
  Rec : TSearchRec;
  fa:TFileAttr;
begin
  Path := IncludeTrailingPathDelimiter(sPath);
  if FindFirst(Path + '*.*', faDirectory, Rec) = 0 then
  try
    repeat
      if (Rec.Name<>'.') and (Rec.Name<>'..') then
      begin
        if rec.Attr<>faDirectory then //do not add directories
        begin
          fa.Size:=rec.Size;
          fa.DateTime:=rec.TimeStamp;
          result.Add(ansilowercase(Path+Rec.Name), fa);
        end;
        GetAllSubFolders(Path + Rec.Name, result);
      end;
    until FindNext(Rec) <> 0;
  finally
    SysUtils.FindClose(Rec);
  end;
end;

function GetFileAttr(filename:string):TFileAttr;
var FFileHandle:cardinal;
begin
  FFileHandle := THandle(FileOpen(FileName, FileMode));
  try
    if FFileHandle = INVALID_HANDLE_VALUE then
      RaiseLastOSError;
    result.Size := GetFileSize(FFileHandle, nil);
    result.DateTime:=FileDateToDateTime(FileGetDate(FFileHandle));
  finally
    FileClose(FFileHandle);
  end;
end;

function UpdateFileTime(filename: string; filedatetime:tdatetime): boolean;
var
  F: THandle;
begin
  if not ForceDirectories(ExtractFilePath(filename)) then
    raise Exception.CreateFmt('Unable to access file %s', [filename]);

  F := CreateFile(Pchar(filename), GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, 0);
  Result := F <> THandle(-1);
  if Result then begin
  {$WARN SYMBOL_PLATFORM OFF}
    FileSetDate(F, DateTimeToFileDate(filedatetime));
  {$WARN SYMBOL_PLATFORM ON}
    FileClose(F);
  end;
end;


procedure DoSync(localfolder,ftpurl:string; login, password: string);
var Ftp: TIdFTP;
    URL: TIdURI;
    FTPFileList:TFtpFileList;
    i:integer;
    info, curpath:string;
    curdir:string;
    LocalFile:TMemoryStream;
    fileattr:TFileAttr;
    CoolCheck:boolean;
    localfiles:TLocalFileList;

  procedure FetchFile;
  begin
    if not DirectoryExists(curdir+FTPFileList[i].Path) then
      MkDir(curdir+FTPFileList[i].Path);
    FTPFileList[i].FetchContent(Ftp);
    FTPFileList[i].Content.SaveToFile(curpath);
    UpdateFileTime(curpath, FTPFileList[i].FileDate);
  end;

begin
  assert(localfolder<>emptystr,'Local folder is not specified');
  assert(ftpurl<>emptystr,'FTP URL folder is not specified');
  //Get local files
  curdir:=IncludeTrailingPathDelimiter(localfolder);
  LocalFiles:=TLocalFileList.Create;
  //Check FTP files
  FTPFileList := TFtpFileList.Create;
  LocalFile:=TMemoryStream.Create;
  Ftp := TIdFTP.Create(nil);
  URL := TIdURI.Create(ftpurl);
  try
    GetAllSubFolders(curdir,LocalFiles);
    Ftp.Host := URL.Host;
    Ftp.port := strtointdef(URL.Port,21);
    Ftp.UserName := login;
    Ftp.Password := password;
    Ftp.AutoLogin := True;
    Ftp.Passive := True;
    writeln('Connecting to '+login+':'+password+'@'+ftpurl);
    Ftp.Connect;
    try
      if Ftp.Connected then
      begin
        Ftp.ChangeDir(url.Path);
        FTPFileList.ParseFtp(Ftp);
        CoolCheck:=FTP.SupportsVerification;
        writeln('Server supports verification = ',CoolCheck);
        for i := 0 to FTPFileList.Count - 1 do begin
          info := FTPFileList[i].Description;
          Write('Checking '+FTPFileList[i].FileName+ '. ');
          curpath:=ansilowercase(ansireplacestr(curdir+FTPFileList[i].Path+FTPFileList[i].FileName,'/','\'));
          if localfiles.ContainsKey(curpath) then
          begin
            write('File exists ');
            //Check file
            if CoolCheck then
            begin
              //Easy way to check (FTP server supports checksum verification)
              LocalFile.Clear;
              LocalFile.LoadFromFile(curpath);
              if not FTP.VerifyFile(LocalFile,FTPFileList[i].Path+FTPFileList[i].FileName) then
              begin
                //Files do not match
                writeln('but differ. Fetching.');
                FetchFile;
              end else
                writeln('and is the same.');
            end else begin
              //Complex way to check
              if not localfiles.TryGetValue(curpath,fileattr)
                then raise Exception.Create('Can''t get local file attributes: '+curpath);
              if   (fileattr.Size     <> DWORD(FTPFileList[i].Size))
                or (abs(fileattr.DateTime - FTPFileList[i].FileDate)>2/SecsPerDay) //2 sec diff in modified time is acceptable due to strange round functionality
              then begin
                writeln('but differ. Fetching.');
                FetchFile;
              end else
                writeln('and is the same.');
            end;
            //remove from local files list
            LocalFiles.Remove(curpath);
          end else begin
            //Local file does not exist. Fetch it from FTP
            writeln('File do not exist. Fetching.');
            FetchFile;
          end;
        end;
        Ftp.Disconnect;
      end;
      for info in localfiles.keys do
      begin
        writeln('Local file '+info + ' is absent on the FTP server. Removing.');
        DeleteFile(PWideChar(info));
      end;
    except
      on E: Exception do
        WriteLn('ftp error for ' + info + sLineBreak + E.Message);
    end;
  finally
    freeandnil(localfile);
    freeandnil(ftp);
    freeandnil(url);
    freeandnil(FTPFileList);
    freeandnil(LocalFiles);
  end;
end;

end.
