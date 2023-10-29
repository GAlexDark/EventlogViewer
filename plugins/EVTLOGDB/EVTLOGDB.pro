#-------------------------------------------------
#
# Project created by QtCreator 2012-04-13T23:20:17
#
#-------------------------------------------------

QT       -= gui
QT       += sql


TARGET = EVTLOGDB
TEMPLATE = lib

DEFINES += EVTLOGDB_LIBRARY

SOURCES += evtlogdb.cpp \
    ../../Core_SQLiteDB/exceptions.cpp \
    ../../Core_SQLiteDB/DBUnit.cpp

HEADERS += evtlogdb.h\
        EVTLOGDB_global.h \
    ../../Core_SQLiteDB/DBUnit.h \
    ../../Core_SQLiteDB/exceptions.h \
    ../../Core_SQLiteDB/core_headers.h




