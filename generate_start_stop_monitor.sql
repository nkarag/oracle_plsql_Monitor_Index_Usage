   set    termout off  
   set heading off
   set echo off
   set feedback off
   set pages 10000
   spool startmonitor.sql
   -- modify appropriately to select the schemas you want
   select 'alter index '||owner||'.'||index_name||' monitoring usage;'
   from dba_indexes
   where owner not in ('SYS','SYSTEM');
   spool off
   
   spool stopmonitor.sql
      -- modify appropriately to select the schemas you want
   select 'alter index '||owner||'.'||index_name||' nomonitoring usage;'
   from dba_indexes
   where owner not in ('SYS','SYSTEM');
   spool off

