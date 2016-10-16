/*
goal: various tests on monitoring index usage
*/

-- create a test table 
create table nkarag.test_monidx
as select * from dba_objects where rownum < 1001

grant select on nkarag.test_monidx to monitor_dw;

-- create an index
create index nkarag.testidx on nkarag.test_monidx(owner);

-- create another index
create index nkarag.testidx2 on nkarag.test_monidx(object_name);

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;
   
   -- no rows returned
   
-- start monitoring of index
alter index NKARAG.testidx monitoring usage;

-- check monitoring of index
 select *
   from v$object_usage;
   
   INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
   TESTIDX         YES                 NO          8/4/2011 11:30    

-- gather table stats
exec dbms_stats.gather_table_stats('NKARAG',   'TEST_MONIDX')     

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;

INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
TESTIDX         YES                  NO          8/4/2011 11:30    

-- statistics collection DOES NOT affect index usage!!!!

-- use index
select * 
from nkarag.test_monidx 
where owner = 'NKARAG'

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;

INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
TESTIDX    YES    YES    8/4/2011 11:30    

-- use index again
select * 
from nkarag.test_monidx 
where owner = 'NKARAG'

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;

INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
TESTIDX    YES    YES    8/4/2011 11:30    

-- stop monitoring
alter index NKARAG.testidx nomonitoring usage;

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;
   
   INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
TESTIDX    NO    YES    8/4/2011 11:30    8/4/2011 11:49

-- start monitoring again 
 alter index NKARAG.testidx monitoring usage;

-- check monitoring of index
 select index_name,monitoring,used,start_monitoring,end_monitoring
   from v$object_usage;

INDEX_NAME    MONITORING    USED    START_MONITORING    END_MONITORING
TESTIDX    YES    NO    8/4/2011 11:50    

-- !!!! all the previous monitoring history has been GONE!!!


-- check the index usage after an index rebuild
alter index NKARAG.testidx monitoring usage;

 select *
   from v$object_usage;
   
   INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	NO	05/04/2011 15:14:00	
TESTIDX2	TEST_MONIDX	NO	NO	04/29/2011 15:33:20	04/29/2011 15:33:34

alter index NKARAG.testidx rebuild;

 select *
   from v$object_usage;
   
INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	NO	***YES***	05/04/2011 15:14:00	
TESTIDX2	TEST_MONIDX	NO	NO	04/29/2011 15:33:20	04/29/2011 15:33:34

-- unfortunately after an index rebuild the index is markes as used!!!!
-- also monitoring is stopped with a null stop date!!!

-- check index usage after taking statistics of a table
alter index NKARAG.testidx nomonitoring usage;   

   
alter index NKARAG.testidx monitoring usage;     

 select *
   from v$object_usage;

INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	NO	05/04/2011 15:16:39	
TESTIDX2	TEST_MONIDX	NO	NO	04/29/2011 15:33:20	04/29/2011 15:33:34

exec dbms_stats.gather_table_stats('NKARAG', 'TEST_MONIDX');

 select *
   from v$object_usage;
   
INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	***NO***	05/04/2011 15:16:39	
TESTIDX2	TEST_MONIDX	NO	NO	04/29/2011 15:33:20	04/29/2011 15:33:34
   
-- statistics collection, does not seem to bother index usage!!!!

alter index NKARAG.testidx nomonitoring usage; 

/*
Taking all of the findings into account, the following cases have to be considered:
    •   Rebuilt indexes are marked as used and monitoring on them is switched off, while leaving 
    the value END_MONITORING set to NULL. Since we are only interested in index usage due to 
    DML, we need to exclude this case.
    •   Indexes that were used by DML retain the settings of MONITORING (YES) and 
    END_MONITORING (NULL).
    •   Indexes on which monitoring was switched off after they were used by DML retain the 
    setting MONITORING=YES, but have an actual timestamp instead of NULL in END_MONITORING.
    The following query retrieves only indexes that were marked as used by DML, but not by 
    an index rebuild:
SQL> SELECT * FROM v$object_usage 
WHERE (monitoring='YES' AND used='YES') OR
(used='YES' AND end_monitoring IS NOT NULL)
ORDER BY index_name;
*/
alter index NKARAG.testidx monitoring usage;
alter index NKARAG.testidx2 monitoring usage;

 select *
   from v$object_usage;

INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	NO	05/04/2011 15:46:56	
TESTIDX2	TEST_MONIDX	YES	NO	05/04/2011 15:46:59	


alter index NKARAG.testidx rebuild;

--use index testidx2
select /*+ index(a testidx2) */* 
from nkarag.test_monidx a 
where object_name = 'NKARAG'

 select *
   from v$object_usage;

INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	NO	YES	05/04/2011 15:46:56	
TESTIDX2	TEST_MONIDX	YES	YES	05/04/2011 15:46:59	

-- the following query returns the right index only (ie not the one used because of the index rebuild but because of the query)
 SELECT * FROM v$object_usage 
WHERE (monitoring='YES' AND used='YES') OR
(used='YES' AND end_monitoring IS NOT NULL)
ORDER BY index_name

INDEX_NAME;TABLE_NAME;MONITORING;USED;START_MONITORING;END_MONITORING
TESTIDX2;TEST_MONIDX;YES;YES;05/04/2011 15:46:59;null

-- also it works when we stop monitoring of the index 
alter index NKARAG.testidx2 nomonitoring usage;


 SELECT * FROM v$object_usage 
WHERE (monitoring='YES' AND used='YES') OR
(used='YES' AND end_monitoring IS NOT NULL)
ORDER BY index_name

INDEX_NAME;TABLE_NAME;MONITORING;USED;START_MONITORING;END_MONITORING
TESTIDX2;TEST_MONIDX;NO;YES;05/04/2011 15:46:59;05/04/2011 15:51:50

/*
 lets check the following scenario:
 
 1.enable index monitoring on index testidx
 
 2. use the index in a query
 
 3. then at night the ETL, rebuilds the index. Does this rebuild ruin the usage results?
*/
--  1.enable index monitoring on index testidx
alter index NKARAG.testidx monitoring usage;


 select *
   from v$object_usage;


INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	NO	05/04/2011 16:24:04	

--  2. use the index in a query
select * 
from nkarag.test_monidx 
where owner = 'NKARAG'

 select *
   from v$object_usage;

INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	YES	***YES***	05/04/2011 16:24:04	

-- index is used and we want to keep this result

-- 3. then at night the ETL, rebuilds the index. Does this rebuild ruin the usage results?
alter index NKARAG.testidx rebuild;

 select *
   from v$object_usage;

INDEX_NAME	TABLE_NAME	MONITORING	USED	START_MONITORING	END_MONITORING

TESTIDX	TEST_MONIDX	NO	YES	05/04/2011 16:24:04	

-- monitoring is disabled, used is YES, END_MONIOTRING is NULL. This means that we CANNOT distinguish it 
-- from an index rebuild without an actual use of the index!!!!
-- This means that we have to keep the usage result before the index is being rebuilt!!!!
-- This means that index monitoring must be disabled before the ETL begins. But if we neglect index usage during ETL,
-- then we might drop an index that is usefull at ETL loading (e.g. in TARGET_DW) 


----------------- DRAFT 
select *
from v$object_usage 

select d.owner, v.index_name
   from dba_indexes d, v$object_usage v
   where 
    v.used='NO' 
    and d.index_name=v.index_name
    and d.table_name = v.table_name;
    

--     