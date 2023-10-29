#include "cdatabase.h"
#include <QUuid>
#include <QSqlError>
#include "exceptions.h"


CDataBase::CDataBase(const QString &aConnectionName): m_driver(NULL), m_IsInited(false), m_IsOpen(false), m_ConnectionName(aConnectionName),
    m_ErrorCode(0), m_IsDBLock(false), m_IsBeginTransaction(false), m_dbdir("")
{

    if (m_ConnectionName.isEmpty() || m_ConnectionName.isNull()) {
        QUuid guid = QUuid::createUuid();
        m_ConnectionName = guid.toString();
        }
}

CDataBase::~CDataBase()
{
    m_driver = NULL;
    DeInit();
}

void CDataBase::SetDrvInstanse(QSqlDriver* Drv)
{ // получаем указатель на адрес экземпляра класса сиквельного драйвера
    if (Drv == NULL)
        throw EDBError(0,0,"Error pointer to driver");
    m_driver = Drv;
}

/*
    aConnectionString - для SQLite это путь к файлу БД
*/
void CDataBase::Init(const QString &aConnectionString)
{
    if (m_IsInited) //IsConnected
        return;

    if (aConnectionString.isEmpty() || aConnectionString.isNull())
        throw EDBError(0,0, "Empty string");

    m_dbdir = "";

    if (m_driver == NULL)
        throw EDBError(0,0, "Error pointer to driver");

    // соединяемся с базой данных
    m_dbinstance = QSqlDatabase::addDatabase(m_driver, m_ConnectionName);
    m_IsInited = m_dbinstance.isValid ();
    if (!m_IsInited) { //Если DBDrv недоступен или не может быть загружен
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_LOAD_DRV, error.number(),
                        PL_ErrorLoadDrv.arg(error.databaseText()));
        }
    m_dbinstance.setDatabaseName(aConnectionString);
}
/*
    закончить транзакции (commit)
    закрыть подключение к базе
    деинициализация подключения
*/
void CDataBase::_DeInit()
{
    // код избавления от бага:
    // QSqlDatabasePrivate::removeDatabase connection is still in use, all queries will cease to work.
    if (m_IsInited) {
        QString qs;
        qs.append(QSqlDatabase::database().connectionName());
        QSqlDatabase::removeDatabase(qs);
        //конец кода
        m_IsInited = false;
        }
}

void CDataBase::DeInit()
{
    if (m_IsInited) {
        _Close();
        _DeInit();
        }
}

void CDataBase::Open()
{
    if(m_IsOpen)
        return;

    m_IsOpen = m_dbinstance.open();
    if (!m_IsOpen) {
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_OPEN_DB, error.number(),
                        PL_ErrorOpenDBFile.arg(error.databaseText()));
        }

    m_SQLRes = QSqlQuery(m_dbinstance); // <-- единое связывание всех запросов
}

void CDataBase::_Close()
{
    if (m_IsOpen) {
        m_SQLRes.finish(); //отцепляем все запросы от БД
        m_dbinstance.close ();
        m_IsOpen = false;
        }
}

void CDataBase::Close()
{
    if (m_IsOpen) {
        try {
            CommitTransaction(); //throw
            _Close();
        } catch (EDBError){
            _Close();
            throw;
        } catch (...) {
            throw EDBError(0,0,"Uncnown error");
            }
        }
}

void CDataBase::BeginTransaction()
{
    if (m_IsBeginTransaction)
        return;
    m_IsBeginTransaction = m_dbinstance.transaction ();
    if (!m_IsBeginTransaction) {
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_TRANSACTION, error.number (),
                        PL_ErrorTransaction.arg(error.databaseText()).arg(error.number ()).arg(PL_ERROR_TRANSACTION)); //<---***
        }
}

void CDataBase::CommitTransaction ()
{
    if (!m_IsBeginTransaction)
        return;

    if (!m_dbinstance.commit()) {
        QSqlError error1 = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_COMMIT, error1.number(),
                       PL_ErrorTransaction.arg(error1.databaseText()));
        }
    m_IsBeginTransaction = false;
}

void CDataBase::RollbackTransaction()
{
    if (!m_dbinstance.rollback ()){
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_ROLLBACK, error.number(),
                       PL_ErrorTransaction.arg("See rollback status").arg(error.number()).arg(error.databaseText()));
        }
    m_IsBeginTransaction = false;
}

