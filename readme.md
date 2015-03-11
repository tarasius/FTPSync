This console tool syncs local folder and FTP folder.
FTP folder contains master data, i.e. it is the source and local folder is the destination.
If FTP server supports hashes or other file verification methods, they will be used.
Otherwise size and modified timestamps are compared.
Filenames match is case insensitive.

Source code is written in Delphi XE.

Parameters are:
* 1 - local folder path
* 2 - FTP URL with port and remote folder path
* 3 - FTP login
* 4 - FTP password

Example:
*c:/foldersync ftp://server.com:21/var/www/server.com/folder/ root qwerty*

If no commandline parameters then INI file will be used instead