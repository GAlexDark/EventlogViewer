#include "evtlogdb.h"
#include "../../Core_SQLiteDB/exceptions.h"

#ifndef QT_LIB
    BOOL APIENTRY DllMain(HMODULE hModule,
                          DWORD  ul_reason_for_call,
                          LPVOID lpReserved)
{
	switch (ul_reason_for_call) {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
            break;
    }
    return TRUE;
}
#endif

void _SQLiteSetLastError(dbErrorInfo *db_ErrorInfo, pl_ulong Code, pl_ulong SysCode, const QString &Description)
{
	if (db_ErrorInfo != NULL) {
        const ushort *pEStr = Description.utf16();
        qMemSet(db_ErrorInfo, 0x00, sizeof(DBERRORINFO));
		db_ErrorInfo->Code = Code;
		db_ErrorInfo->SysCode = SysCode;
        qMemCopy(db_ErrorInfo->Description, pEStr, (size_t)Description.length()*sizeof(QChar));
		}
    return;
}

#ifndef QT_LIB
    pcFUNC(bool) SQLite_Create(const USHORT *ConnectionName)
#else
    bool SQLite_Create(const ushort *ConnectionName)
#endif
{
    bool res = false;
    try {
        db = new DBEngine(QString::fromUtf16(ConnectionName));
        HolderList.append(":strSID");
        HolderList.append(":UserName");
        HolderList.append(":SIDType");
        qMemSet(&ErrorInfo,0x00,sizeof(DBERRORINFO));
        IsInited = true;
        res = true;
    } catch (const std::bad_alloc &BA) {
            HolderList.clear();
            IsInited = false;
            _SQLiteSetLastError(&ErrorInfo, -1, 1, PL_NotEnoughMemory.arg(BA.what()));
    } catch (...) {
            HolderList.clear();
            IsInited = false;
            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_Init");
    }
    return res;
}

#ifndef QT_LIB
    pcFUNC(void) SQLite_Free()
#else
    void SQLite_Free()
#endif

{
    delete db;
    db = NULL;
    HolderList.clear();
    IsInited = false;
    return;
}
//#ifdef _SQLite
//#ifndef QT_LIB
//    pcFUNC(bool) SQLite_Connect(const USHORT *dbDir, const USHORT *FileName, const USHORT *PluginName)
//#else
//    bool SQLite_Connect(const ushort *dbDir, const ushort *FileName, const ushort *PluginName)
//#endif
//{
//    bool res = false;
//    if ((dbDir == NULL || dbDir == 0x00) ||
//            (FileName == NULL || FileName == 0x00) ||
//            (PluginName == NULL || PluginName == 0x00)) {
//        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
//        return res;
//        }
//    QString _dbDir		= QString::fromUtf16(dbDir);
//    QString _FileName	= QString::fromUtf16(FileName);
//    QString _PluginName = QString::fromUtf16(PluginName);

//    try {
//        if (!IsInited) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Library was not initialized.\nPointer error in SQLite_Connect");
//            }
//        else {
//            db->Init(_dbDir,_FileName, _PluginName);
//            res = true;
//            }
//    } catch (const EDBError &EDBE) {
//        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
//    } catch (...) {
//        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Connect");
//    }
//    return res;
//}
//#else
#ifndef QT_LIB
    pcFUNC(bool) SQLite_Connect(const USHORT *ConnectionString, const USHORT *PluginName)
#else
    bool SQLite_Connect(const ushort *ConnectionString, const ushort *PluginName)
#endif
{
    bool res = false;
    if ((ConnectionString == NULL || ConnectionString == 0x00) ||
            (PluginName == NULL || PluginName == 0x00)) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _ConnectionString = QString::fromUtf16(ConnectionString);
    QString _PluginName = QString::fromUtf16(PluginName);

    try {
        if (!IsInited) {
            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Library was not initialized.\nPointer error in SQLite_Connect");
            }
        else {
            //QString connectionTemplate = "DRIVER={SQL SERVER};SERVER=%1;DATABASE=%2;Trusted_Connection=Yes;";
            //QString connectionTemplate = "DRIVER={SQL Native Client};SERVER=%1;DATABASE=%2;Trusted_Connection=Yes;";
            //QString connectionString = connectionTemplate.arg(_ServerName).arg(_DBName);
            db->Init(_ConnectionString, _PluginName);
            res = true;
            }
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Connect");
    }
    return res;
}
//#endif
#ifndef QT_LIB
    pcFUNC(bool) SQLite_Open()
#else
    bool SQLite_Open()
#endif
{
    bool res = false;
    try {
        if (!IsInited) {
            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Library was not initialized.\nPointer error in SQLite_Connect");
            }
        else {
            db->Open();
            res = true;
            }
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Open");
    }
    return res;
}

#ifndef QT_LIB
    pcFUNC(bool) SQLite_Close()
#else
    bool SQLite_Close()
#endif
{
    bool res = false;
    try {
        db->Close();
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Close");
    }
    return res;
}

#ifndef QT_LIB
	pcFUNC(bool) SQLite_Inited()
#else
	bool SQLite_Inited()
#endif
{
	return IsInited;
}

#ifndef QT_LIB
    pcFUNC(bool) SQLite_Disconnect()
#else
    bool SQLite_Disconnect()
#endif
{
    bool res = false;
    try {
        db->DeInit();
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Disconnect");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_BeginTransaction()
#else
    bool SQLite_BeginTransaction()
#endif
{
    bool res = false;
    try {
        db->BeginTransaction();
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_BeginTransaction");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_CommitTransaction()
#else
    bool SQLite_CommitTransaction()
#endif
{
    bool res = false;
    try {
        db->CommitTransaction();
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_CommitTransaction");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_RollbackTransaction()
#else
    bool SQLite_RollbackTransaction()
#endif
{
    bool res = false;
    try {
        db->RollbackTransaction();
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_RollbackTransaction");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_Execute(const USHORT *SQLString)
#else
    bool SQLite_Execute(const ushort *SQLString)
#endif
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
        db->Execute(_SQLString);
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_Execute");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_PrepareInsert(const USHORT *SQLString)
#else
    bool SQLite_PrepareInsert(const ushort *SQLString)
#endif
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
        db->PrepareInsert(_SQLString);
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_PrepareInsert");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_BindValue(const USHORT *SID, const USHORT *UserName, int SIDType)
#else
    bool SQLite_BindValue(const ushort *SID, const ushort *UserName, int SIDType)
#endif
{
    bool res = false;
    if ((SID == NULL || SID == 0x00) ||
            (UserName == NULL || UserName == 0x00) || (SIDType == 0)) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SID = QString::fromUtf16(SID);
    QString _UserName = QString::fromUtf16(UserName);

    try {
        TValueList ValueList;
        ValueList.append(_SID);
        ValueList.append(_UserName);
        ValueList.append(SIDType);
        db->BindValue(HolderList, ValueList);
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_BindValue");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_WhoSearch(const USHORT *SQLString)
#else
    bool SQLite_WhoSearch(const ushort *SQLString)
#endif
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
        db->WhoSearch(_SQLString);
        res = true;
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_WhoSearch");
    }
    return res;
}
#ifndef QT_LIB
    pcFUNC(bool) SQLite_SearchResult(USHORT *strSID, USHORT *UserName, int &SIDType, int &Count)
#else
    bool SQLite_SearchResult(ushort *strSID, ushort *UserName, int &SIDType, int &Count)
#endif
{
    bool Next = false;

    if ((strSID == NULL) || (UserName == NULL)) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return Next;
        }

    TValueList ValueList;
    QString _strSID, _UserName;
    try {
        Next = db->SearchResult(ValueList,Count);
        if (Next) {
            TValueList::iterator itV = ValueList.begin();
            QVariant buf = *itV;
            _strSID = buf.toString();
            ++itV;
            buf = *itV;
            _UserName = buf.toString();
            ++itV;
            buf = *itV;
            SIDType = buf.toInt();

            const ushort *pstrSID   = _strSID.utf16();
            const ushort *pUserName = _UserName.utf16();

            int len = _strSID.length();
            size_t size = (size_t)(len+1)*sizeof(QChar);
            qMemCopy(strSID,pstrSID, size);

            len = _UserName.length();
            size = (size_t)(len+1)*sizeof(QChar);
            qMemCopy(UserName,pUserName, size);
            }
    } catch (const EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
        Next = false;
        Count = DATA_ERROR;
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Unknown error in SQLite_WhoSearch");
        Next = false;
        Count = DATA_ERROR;
    }
    return Next;
}
#ifndef QT_LIB
    pcFUNC(void) SQLite_GetLastError(dbErrorInfo *db_ErrorInfo)
#else
    void SQLite_GetLastError(dbErrorInfo *db_ErrorInfo)
#endif
{
    qMemCopy(db_ErrorInfo,&ErrorInfo,sizeof(DBERRORINFO));
    return;
}
#ifndef QT_LIB
    pcFUNC(void) SQLite_ClearError()
#else
    void SQLite_ClearError()
#endif
{
    qMemSet(&ErrorInfo,0x00,sizeof(DBERRORINFO));
    return;
}

