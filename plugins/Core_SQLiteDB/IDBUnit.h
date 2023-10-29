#ifndef IDBUNIT_H
#define IDBUNIT_H

#include "core_headers.h"
#include "exceptions.h"
#include "DBUnit.h"

    DBEngine *db = NULL;
    dbErrorInfo ErrorInfo;

    const QString SQLSelectAll = "SELECT strSID, UserName, SIDType FROM tableSID";
    const QString SQLPrepareInsert = "INSERT INTO tableSID (strSID, UserName, SIDType) VALUES (:strSID, :UserName, :SIDType)";

    THolderList HolderList;
    bool IsInited;

    void _SQLiteSetLastError(dbErrorInfo *db_ErrorInfo, pl_ulong Code, pl_ulong SysCode, QString Description);
    void SQLite_GetLastError(dbErrorInfo *db_ErrorInfo);
    void SQLite_ClearError();

    bool SQLite_Init(const ushort *ConnectionName); //*
    void SQLite_DeInit(); //*

    bool SQLite_Connect();
    bool Connected()
        {return IsInited; }
    bool SQLite_Disconnect();

    bool SQLite_BeginTransaction();
    bool SQLite_CommitTransaction();
    bool SQLite_RollbackTransaction();
    bool SQLite_Execute(const ushort *SQLString);
    bool SQLite_PrepareInsert(const ushort *SQLString);
    bool SQLite_BindValue(const ushort *SID, const ushort *UserName, ulong SIDType);
    bool SQLite_WhoSearch(const ushort *SQLString);
    bool SQLite_SearchResult(ushort *strSID, ushort *UserName, ulong &SIDType, int Count);


#endif // IDBUNIT_H
