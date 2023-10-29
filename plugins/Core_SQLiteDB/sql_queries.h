#ifndef SQL_QUERIES_H
#define SQL_QUERIES_H

#include <QString>
#include <QObject>


//const QString CreateTableFoo =  //its example
//                            "create table if not exist Foo ( "
//                            "  id integer PRIMARY KEY, "
//                            "  name char(30) not null, "
//                            "  born date null, "
//                            "  salary numeric(12,2), "
//                            "  married boolean NULL ); ";

//const QString Events_Creates =  " CREATE TABLE IF NOT EXIST Events ("
//                                " Date FLOAT, User VARCHAR(22), Level INTEGER, "
//                                " Type INTEGER, Message VARCHAR(128)); ";


const QString Vacuum_DB = "VACUUM;";
/*
Команда VACUUM возвращает ошибку, если есть активная транзакция.
VACUUM ничего не делает с базами размещенными в оперативной памяти.
*/

//const QString Commit = "COMMIT;";
//const QString Rollback = "ROLLBACK;";

const QString GetMaxIDFromTable = "SELECT MAX(Id) FROM [tableSID]";

#endif // SQL_QUERIES_H
