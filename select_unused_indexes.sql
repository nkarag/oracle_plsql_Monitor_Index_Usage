select d.owner, v.index_name
   from dba_indexes d, v$object_usage v
   where 
	v.used='NO' 
	and d.index_name=v.index_name
	and d.table_name = v.table_name;
