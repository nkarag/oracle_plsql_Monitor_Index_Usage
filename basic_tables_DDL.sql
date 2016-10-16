-- create the following view in order to allow monitoring of indexes of other user's schema also.
-- taken from: http://ayyudba.blogspot.com/2007/12/viewing-all-indexes-being-monitored.html
create or replace view  monitor_dw.V_INDEX_USAGE
(INDEX_OWNER,
INDEX_NAME, 
TABLE_NAME, 
MONITORING, 
USED, 
START_MONITORING, 
END_MONITORING) 
as 
select u.name, io.name, t.name, 
decode(bitand(i.flags, 65536), 0, 'NO', 'YES'), 
decode(bitand(ou.flags, 1), 0, 'NO', 'YES'), 
to_date(ou.start_monitoring, 'mm/dd/yyyy HH24:MI:SS'), -- note that NLS_DATE_LANGUAGE is AMERICAN 
to_date(ou.end_monitoring, 'mm/dd/yyyy HH24:MI:SS') 
from sys.user$ u, sys.obj$ io, sys.obj$ t, sys.ind$ i, sys.object_usage ou 
where i.obj# = ou.obj# 
and io.obj# = ou.obj# 
and t.obj# = i.bo#
and u.user# = io.owner#
AND io.flags <> 128;

drop table MONITOR_DW.MONDW_INDEX_USAGE;

-- create basic table to monitor index usage
CREATE TABLE MONITOR_DW.MONDW_INDEX_USAGE (
    INDEX_OWNER,
    INDEX_NAME, 
    TABLE_NAME, 
    MONITORING, 
    USED, 
    START_MONITORING, 
    END_MONITORING NOT NULL,
    population_date    
)
AS
select
    INDEX_OWNER, 
    INDEX_NAME,
    TABLE_NAME,
    MONITORING,
    USED, 
    START_MONITORING,
    END_MONITORING,
    sysdate    
from monitor_dw.V_INDEX_USAGE
where
    1=0;
    
alter table MONITOR_DW.MONDW_INDEX_USAGE add constraint IDX_USAGE_PK primary key (INDEX_OWNER, INDEX_NAME, START_MONITORING);

-- create table to record target schemas for which we want to monitor index usage
create table monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS (
    SCHEMA_NAME varchar2(100) primary key
);

alter table monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS add INCLUDE_IND number(1);

COMMENT ON COLUMN MONDW_INDEX_USAGE_TRG_SCHEMAS.INCLUDE_IND IS '1 indicates if this schema will be included in the monitoring process. Values (0,1).';

insert into  monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS (schema_name)
select 'TARGET_DW' from dual
union
select 'PRESENT_PERIF' from dual
union
select 'ORDERS_DW' from dual
union
select 'TELEM_DW' from dual
union
select 'COMPL_DW' from dual
union
select 'CUSTOMER_VIEW' from dual;

commit;

insert into  monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS (schema_name)
values ('DM_SPSS');

commit;

drop table monitor_dw.MONDW_PROC_RESULTS;

-- create table to record results of procedure monitor_schema_indexes
CREATE TABLE monitor_dw.MONDW_INDEX_USG_PROC_RESULTS (
            POPULATION_DATE DATE,
            SCHEMA_NAME VARCHAR2(100),
            SUCCESSES   NUMBER,
            FAILURES    NUMBER
);

alter table monitor_dw.MONDW_INDEX_USG_PROC_RESULTS add monitoring_on_ind number;
COMMENT ON COLUMN MONDW_INDEX_USG_PROC_RESULTS.MONITORING_ON_IND IS '1 means that monitoring was turned on and 0 off';

ALTER TABLE monitor_dw.MONDW_INDEX_USG_PROC_RESULTS ADD CONSTRAINT PROC_RESULTS_PK PRIMARY KEY (POPULATION_DATE, SCHEMA_NAME);