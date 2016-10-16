/*
    Define a set of Views in order to analyze index usage
*/

/*
    KPI 1:      V_KPI_INDEX_MON_PCNT_USED
    Show per index the total number of days that has not been used. Compare this with the total number of days
    of the monitoring period (give a percent: PCTN_NO_USED)
    
    Required fields:
    INDEX_OWNER     owner of the index
    INDEX_NAME      name of the index
    TABLE_OWNER     owner of the table that the index belongs
    TABLE_NAME      name of the table that the index belongs
    MIN_START_MONITORING    minimum date of the start of the monitoring period
    MAX_END_MONITORING      maximum date of the end of the monitoring period
    (Note: their might be some periods (hopefully small) between MIN and MAX that no monitoring has taken place)
    NUM_DAYS_MONITORING     total number of days between MIN and MAX
    NUM_DAYS_USED        total number of days within MIN and MAX that the index was used
    PCNT_USED            percent of days of MIN MAX period that the index was used 
*/

create or replace view monitor_dw.V_KPI_INDEX_MON_PCNT_USED
as
select 
         INDEX_OWNER,
         INDEX_NAME,
         TABLE_OWNER,
         TABLE_NAME,
         MIN_START_MONITORING,
         MAX_END_MONITORING,
         NUM_DAYS_MONITORING,
         NUM_DAYS_USED,
         round((NUM_DAYS_USED/NUM_DAYS_MONITORING)*100) as  PCNT_USED
from (
    select
         INDEX_OWNER,
         INDEX_NAME,
         TABLE_OWNER,
         TABLE_NAME,
         MIN_START_MONITORING,
         MAX_END_MONITORING,
         round(MAX_END_MONITORING - MIN_START_MONITORING) as  NUM_DAYS_MONITORING,
         round(sum (
            case when USED = 'YES'
            then    END_MONITORING - START_MONITORING
            else    0
            end     
         )) as NUM_DAYS_USED
    from (
        select      
            t1.INDEX_OWNER as INDEX_OWNER,
            t1.INDEX_NAME as INDEX_NAME,
            t2.TABLE_OWNER as TABLE_OWNER,
            t2.TABLE_NAME as TABLE_NAME,
            min(T1.START_MONITORING) over (partition by T1.INDEX_OWNER, T1.INDEX_NAME )  as  MIN_START_MONITORING,
            max(T1.END_MONITORING) over (partition by T1.INDEX_OWNER, T1.INDEX_NAME ) as  MAX_END_MONITORING,
            T1.USED as USED,
            T1.START_MONITORING,
            T1.END_MONITORING,
            T1.POPULATION_DATE 
        from     MONITOR_DW.MONDW_INDEX_USAGE t1,
                    ALL_INDEXES t2
        where
            T1.INDEX_OWNER = T2.OWNER
            AND T1.INDEX_NAME = T2.INDEX_NAME
    ) t3
    group by
       INDEX_OWNER,
         INDEX_NAME,
         TABLE_OWNER,
         TABLE_NAME,
         MIN_START_MONITORING,
         MAX_END_MONITORING,
         MAX_END_MONITORING - MIN_START_MONITORING
)         
order by  PCNT_USED asc
/                

grant select on monitor_dw.V_KPI_INDEX_MON_PCNT_USED to ETL_DW
grant select on monitor_dw.V_KPI_INDEX_MON_PCNT_USED to LSINOS
/

------------------------- DRAFT ---------------------
select * 
from MONITOR_DW.MONDW_INDEX_USAGE t
where
    t.USED = 'NO'
order by t.INDEX_OWNER, t.TABLE_NAME, t.INDEX_NAME, t.START_MONITORING asc


select t.INDEX_OWNER, t.TABLE_NAME, t.INDEX_NAME, min(t.START_MONITORING), max(t.END_MONITORING)
from MONITOR_DW.MONDW_INDEX_USAGE t
where
    t.USED = 'NO'
group by t.INDEX_OWNER, t.TABLE_NAME, t.INDEX_NAME
order by 1,2,3


select round(7.73)
from dual

select sum(null)
from dual


delete from  MONITOR_DW.MONDW_INDEX_USAGE
where index_owner = 'NKARAG'

commit