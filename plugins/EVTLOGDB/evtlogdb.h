#ifndef EVTLOGDB_H
#define EVTLOGDB_H


//#define QT_LIB /* переменная используется только в случае работы в Qt Creator */

#ifndef QT_LIB
	#include "windows.h"
#endif // QT_LIB

#include "EVTLOGDB_global.h"
#include "../../Core_SQLiteDB/core_headers.h"
#include "../../Core_SQLiteDB/DBUnit.h"


    DBEngine    *db         = NULL;
    bool        IsInited    = false;
    dbErrorInfo ErrorInfo;
    THolderList HolderList;


/* описание списка импортируемых функций */
#ifdef QT_LIB
    extern "C" {
    void SQLite_GetLastError(dbErrorInfo *db_ErrorInfo);
    void SQLite_ClearError();

    bool SQLite_Create(const ushort *ConnectionName);
    void SQLite_Free();

    bool SQLite_Connect(const ushort *ConnectionString, const ushort *PluginName);
    bool SQLite_Disconnect();
    bool SQLite_Open();
    bool SQLite_Close();
    bool SQLite_Inited();

    bool SQLite_BeginTransaction();
    bool SQLite_CommitTransaction();
    bool SQLite_RollbackTransaction();
    bool SQLite_Execute(const ushort *SQLString);
    bool SQLite_PrepareInsert(const ushort *SQLString);
    bool SQLite_BindValue(const ushort *SID, const ushort *UserName, int SIDType);
    bool SQLite_WhoSearch(const ushort *SQLString);
    bool SQLite_SearchResult(ushort *strSID, ushort *UserName, int &SIDType, int &Count);
    }
#else
    #define pcAPI      __stdcall
    #ifdef __cplusplus
        #define pcEXTERN_C extern "C"
    #else
        #define pcEXTERN_C
    #endif

    #define pcFUNC(ret) pcEXTERN_C ret pcAPI
    pcFUNC(void) SQLite_GetLastError(dbErrorInfo *db_ErrorInfo);
    pcFUNC(void) SQLite_ClearError();

    pcFUNC(bool) SQLite_Create(const USHORT *ConnectionName); //*
    pcFUNC(void) SQLite_Free(); //*

    pcFUNC(bool) SQLite_Connect(const USHORT *ConnectionString, const USHORT *PluginName);
    pcFUNC(bool) SQLite_Disconnect();
    pcFUNC(bool) SQLite_Open();
    pcFUNC(bool) SQLite_Close();
    pcFUNC(bool) SQLite_Inited();

    pcFUNC(bool) SQLite_BeginTransaction();
    pcFUNC(bool) SQLite_CommitTransaction();
    pcFUNC(bool) SQLite_RollbackTransaction();
    pcFUNC(bool) SQLite_Execute(const USHORT *SQLString);
    pcFUNC(bool) SQLite_PrepareInsert(const USHORT *SQLString);
    pcFUNC(bool) SQLite_BindValue(const USHORT *SID, const USHORT *UserName, int SIDType);	
    pcFUNC(bool) SQLite_WhoSearch(const USHORT *SQLString);
    pcFUNC(bool) SQLite_SearchResult(USHORT *strSID, USHORT *UserName, int &SIDType, int &Count);
#endif

#endif // EVTLOGDB_H
