#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef _
#undef _
#endif

#include <libpq-fe.h>

/* static SV * */
/* wrap_hv(void *ptr, char *klass) { */
/*     HV *hv = newHV(); */
/*     SV *sv = newRV_noinc((SV*)hv); */
/*     sv_bless(sv, gv_stashpv(klass, TRUE)); */
/*     hv_stores(hv, "ptr", newSViv(PTR2IV(ptr))); */
/*     return sv; */
/* } */

/* static void * */
/* unwrap_hv(SV *sv) { */
/*     if (SvOK(sv) && SvROK(sv)) { */
/*         HV *hv = SvRV(sv); */
/*         if (SvTYPE((SV*)hv) == SVt_HVPV) { */
/*             SV **psv = hv_fetchs(hv, "ptr", 0); */
/*             if (psv && SvOK(*psv)) */
/*                 return INT2PTR(SvIV(*psv)); */
/*         } */
/*     } */
/*     Perl_croak(aTHX_ "Invalid wrapper"); */
/* } */

static SV *
make_constant(char *name, STRLEN l, U32 value, char *tag) {
    SV *sv = newSV(0);
    SvUPGRADE(sv, SVt_PVIV);
    sv_setpvn(sv, name, l);
    SvIOK_on(sv);
    SvIsUV_on(sv);
    SvUV_set(sv, value);
    SvREADONLY_on(sv);
    newCONSTSUB(gv_stashpv("Pg::PQ", 1), name, sv);
    if (tag) {
        HV *hv = get_hv("Pg::PQ::EXPORT_TAGS", TRUE);
        SV **svp = hv_fetch(hv, tag, strlen(tag), 1);
        if (!svp || !*svp)
            Perl_croak(aTHX_ "internal error populating EXPORT_TAGS");
        if (!SvOK(*svp) || !SvROK(*svp) || (SvTYPE(SvRV(*svp)) != SVt_PVAV))
            sv_setsv(*svp, sv_2mortal(newRV_noinc((SV*)newAV())));
        av_push((AV*)SvRV(*svp), newSVpv(name, 0));
    }
    return sv;
}

static void
sv_chomp(SV *sv) {
    while (SvOK(sv) && SvPOK(sv) && SvCUR(sv) && SvPVX(sv)[SvCUR(sv) - 1] == '\n')
        SvCUR_set(sv, SvCUR(sv) - 1);
}


#include "enums.h"


MODULE = Pg::PQ		PACKAGE = Pg::PQ		PREFIX=PQ

PROTOTYPES: DISABLE

BOOT:
    init_constants();



MODULE = Pg::PQ		PACKAGE = Pg::PQ::Conn          PREFIX=PQ

PGconn *PQconnectdb(const char *conninfo);

PGconn *PQconnectStart(char *conninfo)

PostgresPollingStatusType PQconnectPoll(PGconn *conn)

char *PQdb(PGconn *conn)

char *PQuser(PGconn *conn)

char *PQpass(PGconn *conn)

char *PQhost(PGconn *conn)

char *PQport(PGconn *conn)

char *PQoptions( PGconn *conn)

ConnStatusType PQstatus(PGconn *conn)

PGTransactionStatusType PQtransactionStatus(PGconn *conn)

const char *PQparameterStatus(PGconn *conn, char *paramName)

int PQprotocolVersion(PGconn *conn)

int PQserverVersion(PGconn *conn)

char *PQerrorMessage(PGconn *conn)
CLEANUP:
    sv_chomp(ST(0));

int PQsocket(PGconn *conn)

int PQbackendPID(PGconn *conn)

int PQconnectionNeedsPassword(PGconn *conn)

int PQconnectionUsedPassword(PGconn *conn)

# SSL *PQgetssl(PGconn *conn)

void PQfinish(PGconn *conn)
POSTCALL:
    sv_setsv(SvRV(ST(0)), &PL_sv_undef);

void PQreset(PGconn *conn);

int PQresetStart(PGconn *conn);

PostgresPollingStatusType PQresetPoll(PGconn *conn);

const char *PQclientEncoding(PGconn *conn)
CODE:
    RETVAL = pg_encoding_to_char(PQclientEncoding(conn));
OUTPUT:
    RETVAL

int PQsetClientEncoding(PGconn *conn, const char *encoding);

PGVerbosity PQsetErrorVerbosity(PGconn *conn, PGVerbosity verbosity);

void PQtrace(PGconn *conn, FILE *stream);

void PQuntrace(PGconn *conn);

# PGresult *PQexec(PGconn *conn, const char *command);

# PGresult *PQexecParams(PGconn *conn, const char *command, int nParams, const Oid *paramTypes, const char * const *paramValues, const int *paramLengths, const int *paramFormats, int resultFormat);

PGresult *PQexec(PGconn *conn, const char *command, ...)
ALIAS:
    execQuery = 0
CODE:
    if (items <= 2) {
        RETVAL = PQexec(conn, command);
    }
    else {
        int n = items - 2, i;
        char **values;
        Newx(values, n, char *);
        for (i = 0; i < n; i++) values[i] = SvPV_nolen(ST(i + 2));
        RETVAL = PQexecParams(conn, command, n, NULL, (const char **)values, NULL, NULL, 0);
        Safefree(values);
    }
OUTPUT:
    RETVAL


# PGresult *PQprepare(PGconn *conn, const char *stmtName, const char *query, int nParams, const Oid *paramTypes);

PGresult *PQprepare(PGconn *conn, const char *stmtName, const char *query)
C_ARGS: conn, stmtName, query, 0, NULL

# PGresult *PQexecPrepared(PGconn *conn, const char *stmtName, int nParams, const char * const *paramValues, const int *paramLengths, const int *paramFormats, int resultFormat);

PGresult *PQexecPrepared(PGconn *conn, const char *stmtName, ...)
ALIAS:
    execQueryPrepared = 0
PREINIT:
    int n = items - 2, i;
    char **values;
CODE:
    Newx(values, n, char *);
    for (i = 0; i < n; i++) values[i] = SvPV_nolen(ST(i + 2));
    RETVAL = PQexecPrepared(conn, stmtName, n, (const char **)values, NULL, NULL, 0);
    Safefree(values);
OUTPUT:
    RETVAL

PGcancel *PQgetCancel(PGconn *conn);

void PQnotifies(PGconn *conn)
PREINIT:
    PGnotify *notice;
PPCODE:
    notice = PQnotifies(conn);
    if (notice) {
        int pid = notice->be_pid;
        SV *name = newSVpv(notice->relname, 0);
        PQfreemem(notice);
        mPUSHs(name);
        if (GIMME_V == G_ARRAY) {
            mPUSHi(pid);
            XSRETURN(2);
        }
        else
            XSRETURN(1);
    }
    else
        XSRETURN(0);

PGresult *PQmakeEmptyPGresult(PGconn *conn, ExecStatusType status);
ALIAS:
    PQmakeEmptyResult = 0

# size_t PQescapeStringConn (PGconn *conn, char *to, const char *from, size_t length, int *error);

SV *PQescapeString(PGconn *conn, SV *from)
PREINIT:
    STRLEN len;
    char *pv;
    int error;
CODE:
    pv = SvPV(from, len);
    RETVAL = newSV(len * 2 + 1);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, PQescapeStringConn(conn, SvPVX(RETVAL), pv, len, &error));
    if (error) {
        SvREFCNT_dec(RETVAL);
        RETVAL = &PL_sv_undef;
    }
OUTPUT:
    RETVAL

# unsigned char *PQescapeByteaConn(PGconn *conn, unsigned char *from, size_t from_length, size_t *to_length);

# int PQsendQuery(PGconn *conn, const char *command);

# int PQsendQueryParams(PGconn *conn, const char *command, int nParams, const Oid *paramTypes, const char * const *paramValues, const int *paramLengths, const int *paramFormats, int resultFormat);

int PQsendQuery(PGconn *conn, const char *command, ...)
CODE:
    if (items <= 2) {
        RETVAL = PQsendQuery(conn, command);
    }
    else {
        int n = items - 2, i;
        char **values;
        Newx(values, n, char *);
        for (i = 0; i < n; i++) values[i] = SvPV_nolen(ST(i + 2));
        RETVAL = PQsendQueryParams(conn, command, n, NULL, (const char **)values, NULL, NULL, 0);
        Safefree(values);
    }
OUTPUT:
    RETVAL


# int PQsendPrepare(PGconn *conn, const char *stmtName, const char *query, int nParams, const Oid *paramTypes);

int PQsendPrepare(PGconn *conn, const char *stmtName, const char *query)
C_ARGS: conn, stmtName, query, 0, NULL

# int PQsendQueryPrepared(PGconn *conn, char *stmtName, int nParams, const char * const *paramValues, const int *paramLengths, const int *paramFormats, int resultFormat);

int PQsendQueryPrepared(PGconn *conn, const char *stmtName, ...)
PREINIT:
    int n = items - 2, i;
    char **values;
CODE:
    Newx(values, n, char *);
    for (i = 0; i < n; i++) values[i] = SvPV_nolen(ST(i + 2));
    RETVAL = PQsendQueryPrepared(conn, stmtName, n, (const char **)values, NULL, NULL, 0);
    Safefree(values);
OUTPUT:
    RETVAL

PGresult *PQgetResult(PGconn *conn);
ALIAS:
    result = 0

int PQconsumeInput(PGconn *conn);

int PQisBusy(PGconn *conn)
ALIAS:
    busy = 0

int PQsetnonblocking(PGconn *conn, int arg)

int PQisnonblocking(PGconn *conn);

int nonBlocking(PGconn *conn, SV *nb = &PL_sv_undef)
CODE:
    if (SvOK(nb))
        PQsetnonblocking(conn, SvIV(nb));
    RETVAL = PQisnonblocking(conn);

int PQflush(PGconn *conn);

# PGresult *PQfn(PGconn *conn, int fnid, int *result_buf, int *result_len, int result_is_int, const PQArgBlock *args, int nargs);


MODULE = Pg::PQ		PACKAGE = Pg::PQ::Result          PREFIX=PQ

ExecStatusType PQresultStatus(PGresult *res);
ALIAS:
    status = 0

char *PQresStatus(ExecStatusType status);
ALIAS:
    statusString = 0

char *PQresultErrorMessage(PGresult *res);
ALIAS:
    errorMessage = 0
CLEANUP:
    sv_chomp(ST(0));

char *PQresultErrorField(PGresult *res, int fieldcode);
ALIAS:
    errorField = 0

void PQclear(PGresult *res)
POSTCALL:
    sv_setsv(ST(0), &PL_sv_undef);

int PQntuples(PGresult *res)
ALIAS:
    nTuples = 0

int PQnfields(PGresult *res)
ALIAS:
    nFields = 0

char *PQfname(PGresult *res, int column_number)
ALIAS:
    fieldName = 0

int PQfnumber(PGresult *res, const char *column_name)
ALIAS:
    fieldNumber = 0

Oid PQftable(PGresult *res, int column_number)
ALIAS:
    fieldTable = 0

int PQftablecol(PGresult *res, int column_number);
ALIAS:
    fieldTableColumn = 0

int PQfformat(PGresult *res, int column_number);

Oid PQftype(PGresult *res, int column_number);

int PQfmod(PGresult *res, int column_number);

int PQfsize(PGresult *res, int column_number);

int PQbinaryTuples(PGresult *res);

# TODO: handle data in binary format
char *PQgetvalue(PGresult *res, int row_number, int column_number);
ALIAS:
    value = 0

int PQgetisnull(PGresult *res, int row_number, int column_number);
ALIAS:
    null = 0

int PQgetlength(PGresult *res, int row_number, int column_number);
ALIAS:
    length = 0

# void PQprint(FILE *fout, PGresult *res, PQprintOpt *po);

char *PQcmdStatus(PGresult *res);

char *PQcmdTuples(PGresult *res);

Oid PQoidValue(PGresult *res);


MODULE = Pg::PQ		PACKAGE = Pg::PQ::Cancel          PREFIX=PQ


void PQfreeCancel(PGcancel *cancel);

int PQcancel(PGcancel *cancel, char *errbuf, int errbufsize);

