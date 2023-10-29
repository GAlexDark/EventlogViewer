#include "cdatabase.h"
#include <QUuid>
#include <QSqlError>
#include "exceptions.h"
#include <QDebug>

CDataBase::CDataBase(const QString &aConnectionName): m_driver(NULL), m_IsInited(false), m_IsOpen(false), m_ConnectionName(aConnectionName),
    m_ErrorCode(0), m_IsDBLock(false), m_dbdir(""), m_IsTransaction(false)
{
    //m_IsConnected = false -- нет соединения
    //m_IsDBLock = false -- _cs.lock не вызывалась
    //m_ErrorCode = 0;

    qDebug() << "CDataBase::CDataBase(const QString &aConnectionName)";
    if (m_ConnectionName.isEmpty() || m_ConnectionName.isNull()) {
        QUuid guid = QUuid::createUuid();
        m_ConnectionName = guid.toString();
        }
}

CDataBase::~CDataBase()
{
    qDebug() << "CDataBase::~CDataBase()";
    DeInit();
}

void CDataBase::SetDrvInstanse(QSqlDriver* Drv)
{ // получаем указатель на адрес экземпляра класса сиквельного драйвера
    qDebug() << "CDataBase::SetDrvInstanse(QSqlDriver* Drv)";
    if (Drv == 0) {
        qDebug() << "Error pointer to driver";
        throw EDBError(0,0,"Error pointer to driver");
        }
    m_driver = Drv;
}

/*
    aConnectionString - для SQLite это путь к файлу БД
*/
void CDataBase::Init(const QString &aConnectionString)
{
    if (m_IsInited) //IsConnected
        return;
    qDebug() << "void CDataBase::Init(const QString &aConnectionString)";
    if (aConnectionString.isEmpty() || aConnectionString.isNull()) {
        qDebug() << "[ERROR] " << "Empty string";
        throw EDBError(0,0, "Empty string");
        }

    m_dbdir = "";

    if (m_driver == 0) {
        qDebug("Error pointer to driver");
        throw EDBError(0,0, "Error pointer to driver");
        }

    // соединяемся с базой данных
    m_dbinstance = QSqlDatabase::addDatabase(m_driver, m_ConnectionName);
    m_IsInited = m_dbinstance.isValid ();
    if (!m_IsInited) { //Если DBDrv недоступен или не может быть загружен
        QSqlError error = m_dbinstance.lastError();
        qDebug() << "[ERROR] " << PL_ErrorLoadDrv.arg(error.text());
        throw EDBError(PL_ERROR_LOAD_DRV, error.number(),
                        PL_ErrorLoadDrv.arg(error.text()));
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
    qDebug() << "void CDataBase::_DeInit()";
    // код избавления от бага:
    // QSqlDatabasePrivate::removeDatabase connection is still in use, all queries will cease to work.
    QString qs;
    qs.append(QSqlDatabase::database().connectionName());
    QSqlDatabase::removeDatabase(qs);
    //конец кода
    m_driver = 0;
}

void CDataBase::DeInit()
{
    qDebug() << "void CDataBase::DeInit()";
    if (m_IsInited) {
        _Close();
        m_IsOpen = false;

        _DeInit();
        m_IsInited = false;
        }
}

void CDataBase::Open()
{
    if(m_IsOpen)
        return;

    qDebug("void CDataBase::Open()");
    m_IsOpen = m_dbinstance.open();
    if (!m_IsOpen) {
        QSqlError error = m_dbinstance.lastError();
        qDebug() << "[ERROR] " << PL_ErrorOpenDBFile.arg(error.text());
        throw EDBError(PL_ERROR_OPEN_DB, error.number(),
                        PL_ErrorOpenDBFile.arg(error.text()));
        }

    m_SQLRes = QSqlQuery(m_dbinstance); // <-- единое связывание всех запросов
    //m_SQLRes.exec("PRAGMA synchronous = OFF;");
    //m_SQLRes.exec("PRAGMA temp_store = MEMORY;");
    //m_SQLRes.exec("PRAGMA default_cache_size = 7340031;");
    //m_SQLRes.exec("PRAGMA page_size = 1024;");
    //m_SQLRes.exec("PRAGMA cache_size = 7340031;");
    //m_SQLRes.exec("PRAGMA auto_vacuum = NONE;");
    //m_SQLRes.exec("PRAGMA journal_mode = MEMORY;");
}

void CDataBase::_Close()
{
    qDebug() << "void CDataBase::_Close()";
    m_SQLRes.finish(); //отцепляем все запросы от БД
    if (m_dbinstance.isValid() && m_dbinstance.isOpen()) {
        m_dbinstance.close();
        }
}

bool CDataBase::Close()
{
    qDebug() << "void CDataBase::Close()";
    if (m_IsOpen) {
        try {
            CommitTransaction(); //throw
            _Close();
        } catch (EDBError){
            _Close();
        } catch (...) {
            return false;
            }
        }
    m_IsOpen = false;
    return true;
}

void CDataBase::BeginTransaction()
{
    qDebug("void CDataBase::BeginTransaction()");
    if (!m_dbinstance.transaction ()) {
        QSqlError error = m_dbinstance.lastError();
        qDebug() << "[ERROR] " << PL_ErrorTransaction.arg(error.text()).arg(error.number ()).arg(PL_ERROR_TRANSACTION);
        throw EDBError(PL_ERROR_TRANSACTION, error.number (),
                        PL_ErrorTransaction.arg(error.text()).arg(error.number ()).arg(PL_ERROR_TRANSACTION)); //<---***
        }
    m_IsTransaction = true;
}

void CDataBase::CommitTransaction()
{
    qDebug("bool CDataBase::CommitTransaction ()");
    if (m_SQLRes.isActive()) {
        qDebug("QSQLQuery::exec() active");
        m_SQLRes.finish();
        }

    if (!m_IsTransaction)
        return;

    if (!m_dbinstance.commit()) {
        QSqlError error1 = m_dbinstance.lastError();
        qDebug() << "[ERROR] " << error1.text();
        throw EDBError(PL_ERROR_COMMIT, error1.number(),
                       PL_ErrorTransaction.arg(error1.text()));
        }
    m_IsTransaction = false;
}

void CDataBase::RollbackTransaction()
{     
    qDebug("bool CDataBase::RollbackTransaction()");
    if (m_SQLRes.isActive()) {
        qDebug("QSQLQuery::exec() active");
        m_SQLRes.finish();
        }

    if (!m_IsTransaction)
        return;

    if (!m_dbinstance.rollback ()){
        QSqlError error = m_dbinstance.lastError();
        qDebug() << "[ERROR] " << PL_ErrorTransaction.arg("See rollback status").arg(error.number()).arg(error.text());
        throw EDBError(PL_ERROR_ROLLBACK, error.number(),
                       PL_ErrorTransaction.arg("See rollback status").arg(error.number()).arg(error.text()));
        }
    m_IsTransaction = false;
}

void CDataBase::_exec(const QString &sql_req)
{
	qDebug() << "void CDataBase::_exec(QString &sql_req)";
	m_SQLRes.clear();
	m_SQLRes.setForwardOnly(true); // ускорение для ::next()
	if (!m_SQLRes.exec(sql_req)) {
		QSqlError error = m_SQLRes.lastError();
		qDebug() << error.text();
		qDebug() << "[Error Code] " << QString::number(error.number());
		throw EDBError(0, error.number(), error.text());
		}
}

void CDataBase::_exec()
{
	qDebug() << "void CDataBase::_exec()";
	if (!m_SQLRes.exec()) {
		QSqlError error = m_SQLRes.lastError();
		qDebug() << error.text();
		qDebug() << "[Error Code] " << QString::number(error.number());
		throw EDBError(0, error.number(), error.text());
		}
}

void CDataBase::_prepare(const QString &sql_req)
{
	qDebug() << "void CDataBase::_prepare(QString req)";
	m_SQLRes.clear();
	if (!m_SQLRes.prepare(sql_req)) {
		QSqlError error = m_SQLRes.lastError();
		qDebug() << error.text();
		throw EDBError(0, error.number(), error.text());
		}
}
