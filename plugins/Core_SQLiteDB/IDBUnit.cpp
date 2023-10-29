#include "IDBUnit.h"

void _SQLiteSetLastError(dbErrorInfo *db_ErrorInfo, pl_ulong Code, pl_ulong SysCode, QString Description)
{
     const ushort *pEStr = Description.utf16();
     memset(db_ErrorInfo, 0x00, sizeof(DBERRORINFO));
     db_ErrorInfo->Code = Code;
     db_ErrorInfo->SysCode = SysCode;
     memcpy(db_ErrorInfo->Description, pEStr, Description.length()*sizeof(ushort));
     return;
}
bool SQLite_Init(const ushort *ConnectionName)
{
    db = new DBEngine(QString::fromUtf16(ConnectionName));
    bool res;
    IsInited = false;
    if (db == NULL) {
        HolderList.clear();
        res = false;
        }
    else {
        HolderList.append(":strSID");
        HolderList.append(":UserName");
        HolderList.append(":SIDType");
        res = true;
        IsInited = true;
        }
    return res;
}
void SQLite_DeInit()
{
    delete db;
    db = NULL;
    HolderList.clear();
    IsInited = false;
    return;
}

bool SQLite_Connect(const ushort *dbDir, const ushort *FileName, const ushort *PluginName)
{
    bool res = false;

    if ((dbDir == NULL || dbDir == 0x00) ||
            (FileName == NULL || FileName == 0x00) ||
            (PluginName == NULL || PluginName == 0x00)) {
            _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _dbDir = QString::fromUtf16(dbDir);
    QString _FileName = QString::fromUtf16(FileName);
    QString _PluginName = QString::fromUtf16(PluginName);

    try {
        /* ToDo: а нужна ли эта проверка?*/
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_Connect");
//            }
//        else {
            db->Connect(_dbDir,_FileName, _PluginName);
            res = true;
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_Connect");
    }
    return res;
}
bool SQLite_Disconnect()
{
    bool res = false;
    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_Disconnect");
//            }
//        else {
            db->Disconnect();
            res = true;
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_Disconnect");
    }
    return res;
}
bool SQLite_BeginTransaction()
{
    bool res = false;
    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_BeginTransaction");
//            }
//        else {
            db->BeginTransaction();
            res = true;
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_BeginTransaction");
    }
    return res;
}
bool SQLite_CommitTransaction()
{
    bool res = false;
    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_CommitTransaction");
//            }
//        else {
            db->CommitTransaction();
            res = true;
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_CommitTransaction");
    }
    return res;
}
bool SQLite_RollbackTransaction()
{
    bool res = false;
    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_RollbackTransaction");
//            }
//        else {
            db->RollbackTransaction();
            res = true;
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_RollbackTransaction");
    }
    return res;
}
bool SQLite_Execute(const ushort *SQLString)
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_Execute");
//            }
//        else {
            res = db->Execute(_SQLString);
//        }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_Execute");
    }
    return res;
}
bool SQLite_PrepareInsert(const ushort *SQLString)
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_PrepareInsert");
//        } else {
            res = db->PrepareInsert(_SQLString);
//        }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_PrepareInsert");
    }
    return res;
}
bool SQLite_BindValue(const ushort *SID, const ushort *UserName, int SIDType)
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
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_BindValue");
//        } else {
            TValueList ValueList;
            ValueList.append(_SID);
            ValueList.append(_UserName);
            ValueList.append(SIDType);
            res = db->BindValue(HolderList, ValueList);
//        }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_BindValue");
    }
    return res;
}
bool SQLite_WhoSearch(const ushort *SQLString)
{
    bool res = false;
    if (SQLString == NULL || SQLString == 0x00) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return res;
        }
    QString _SQLString = QString::fromUtf16(SQLString);

    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_WhoSearch");
//        } else {
            res = db->WhoSearch(_SQLString);
//        }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_WhoSearch");
    }
    return res;
}
bool SQLite_SearchResult(ushort *strSID, ushort *UserName, ulong &SIDType, int Count)
{
    bool Next = false;

    if ((strSID == NULL) || (UserName == NULL)) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1,"Wrong input data");
        return Next;
        }

    TValueList ValueList;
    QString _strSID, _UserName;
    try {
//        if (!db) {
//            _SQLiteSetLastError(&ErrorInfo, -1, -1, "Pointer error in SQLite_SearchResult");
//            } else {
            Next = db->SearchResult(ValueList,Count);
            TValueList::iterator itV = ValueList.begin();
            QVariant buf = *itV;
                _strSID = buf.toString();
                ++itV;
                buf = *itV;
                _UserName = buf.toString();
                ++itV;
            SIDType = buf.toInt();

            const ushort *pstrSID = _strSID.utf16();
            const ushort *pUserName = _UserName.utf16();

            int len = _strSID.length();
            memcpy(strSID,pstrSID,len*sizeof(ushort));

            len = _UserName.length();
            memcpy(UserName,pUserName,len*sizeof(ushort));
//            }
    } catch (EDBError &EDBE) {
        _SQLiteSetLastError(&ErrorInfo, EDBE.GetErrorCode(), 0, EDBE.GetErrorMessage());
    } catch (...) {
        _SQLiteSetLastError(&ErrorInfo, -1, -1, "Uncnown error in SQLite_WhoSearch");
    }
    return Next;
}
void SQLite_GetLastError(dbErrorInfo *db_ErrorInfo)
{
    memcpy(db_ErrorInfo,&ErrorInfo,sizeof(DBERRORINFO));
    return;
}
void SQLite_ClearError()
{
    memset(&ErrorInfo,0,sizeof(DBERRORINFO));
    return;
}
