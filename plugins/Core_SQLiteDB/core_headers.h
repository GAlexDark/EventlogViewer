#ifndef CORE_HEADERS_H
#define CORE_HEADERS_H

#include <QString>
#include <QChar>
#include <QObject>
#include <QList>
#include <QVariant>

//#define _SQLite //используеи БД SQLite
//#define _MSSQL  //используеи БД MS SQL

/*-----------------------------------------------------------------*/
typedef QList<QString> THolderList; //список полей для bindValue (в формате ":holder_name")
typedef QList<QVariant> TValueList;

/*
добавление элементов QList<...> только через используя QList<...>::append() !!!!!!
*/

/*
ToDo: позже заменить на конструкцию типа:
#include <QPair>
typedef QPair<QString, QVariant> TValues;

http://www.cyberforum.ru/qt/thread366239.html
*/


#define NO_COLUMNS                  -100
#define END_OF_DATA                 -101
#define DATA_ERROR                  -102
#define ERROR_DESCRIPTION_MAX_SIZE  512

typedef struct dbErrorInfo
{
    int	Code;       /* Module error code */
    int	SysCode;    /* OS error code */

    /* String description of error          */
    QChar   Description[ERROR_DESCRIPTION_MAX_SIZE];
} DBERRORINFO;

//Other const
const QString DefBkpExt = QObject::tr("bak");
const QString DefDBExt = QObject::tr("db3");
const QString DefBackupName = QObject::tr("%1.%2.%3");
            /*
            %1 - имя файла БД
            %2 - дата выполнения резервного копирования
            %3 - расширение 'bak'
            */
const QString DefDateFormat = QObject::tr("yyyyMMdd");
/*-----------------------------------------------------------------*/
const QString PL_NotEnoughMemory = QObject::tr("Not enough memory: %1");
const QString PL_BadPluginFile = QObject::tr("This file is not a DB plug-in, or has the wrong version.\nDetails: %1");
const QString PL_ErrorLoadPlugin = QObject::tr("Loading SQL Driver Instance failed");
const QString PL_ErrorLoadDrv = QObject::tr("Error loading DB driver.\nDetails: %1");
const QString PL_ErrorOpenDBFile = QObject::tr("Error open DB file.\nDetails: %1");
//const QString PL_ErrorTransaction = QObject::tr("Transaction Error. Details: %1\n Rollback status:\nCode: %2\nDescription: %3");
const QString PL_ErrorTransaction = QObject::tr("Transaction Error. Details: %1");
const QString PL_ErrorOpenFile = QObject::tr("Error opening file %1.\nDetails: %2");
const QString PL_ErrorDeleteFile = QObject::tr("Error deleting a file %1.\nDetails: %2");
const QString PL_FileNotFind = QObject::tr("File %1 not find.");
const QString PL_PathNotFind = QObject::tr("Backup path %1 not find");
const QString PL_ErrorCopyFile = QObject::tr("Error copy file %1.\nDetails: %2");
const QString PL_ErrorLoadingFile = QObject::tr("Error loading file %1.\nDetails: %2");
const QString PL_ErrorSQLExec = QObject::tr("SQL command error.\nDetails: %1");
const QString PL_DataError = QObject::tr("Wrong data.\nDetails: %1");
const QString PL_ErrorLoadDrvInst = QObject::tr("Loading %1 Driver Instance failed");
const QString PL_GetDataError = QObject::tr("Get result error.\nDetails: %1");
const QString PL_UncnownError = QObject::tr("Unknown error occurred while loading the driver");

/*-----------------------------------------------------------------*/
const int PL_ERROR_SUCCESS				= 0;
const int PL_ERROR_NOT_ENOUGH_MEMORY   = 1;
const int PL_ERROR_BAD_PLUGIN			= 2;
const int PL_ERROR_LOAD_PLUGIN			= 3;
const int PL_ERROR_LOAD_DRV			= 4;
const int PL_ERROR_OPEN_DB             = 5;
const int PL_ERROR_TRANSACTION			= 6;
const int PL_ERROR_COMMIT				= 7;
const int PL_ERROR_ROLLBACK			= 8;
const int PL_ERROR_OPEN_FILE			= 9;
const int PL_ERROR_DELETE_FILE			= 10;
const int PL_FILE_NOT_FIND				= 11;
const int PL_PATH_NOT_FIND             = 12;
const int PL_ERROR_COPY_FILE			= 13;
const int PL_ERROR_LOAD_FILE           = 14;
const int PL_ERROR_SQL_EXECUTE         = 15;
const int PL_ERROR_DATA                = 16;
const int PL_GET_DATA_ERROR            = 17;
const int PL_UNCNOWN_ERROR             = 100;

/*-----------------------------------------------------------------*/


#endif // CORE_HEADERS_H
