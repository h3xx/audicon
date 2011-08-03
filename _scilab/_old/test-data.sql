/* clear file table */
delete from file;

insert into file (file_name, file_description) values ('./foo.wav', 'test file');
