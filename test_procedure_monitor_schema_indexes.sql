declare
    s   number;
    f   number;
begin
    monitor_dw.MONITOR_INDEX_USAGE.monitor_schema_indexes (
            ownname_in => 'nkarag',
            success_counter_out => s,
            failed_counter_out => f,
            monitoring_in => FALSE
        );             
    dbms_output.put_line('s = '||s||', f = '||f);        
end;


exec monitor_dw.MONITOR_INDEX_USAGE.manage_index_monitoring(TRUE);

exec monitor_dw.MONITOR_INDEX_USAGE.manage_index_monitoring(FALSE);