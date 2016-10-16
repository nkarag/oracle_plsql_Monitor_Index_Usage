/**
    This package will containt code that deals with the monitoring of index usage    
    @author nkarag
*/
CREATE OR REPLACE PACKAGE MONITOR_DW.MONITOR_INDEX_USAGE
AS

/**
    @procedure manage_index_monitoring  
    
    Main procedure for index monitoring. It does the following:
    - Activates or Deactivates index monitoring for all indexes owned by the schemas in a driver table (monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS)
    - After deactivation and Before activation, it logs the current index usage results for all indexes of the schemas on which it will operate (i.e. included in the driver table)
    
    @param  monitoring_in           Used to switch monitoring on (TRUE) or off (FALSE)                                 
    @param  logging_in              Used to switch logging of previous index usage results on (TRUE) or off (FALSE) 
*/
    procedure manage_index_monitoring (
        monitoring_in in  BOOLEAN,
        logging_in  in BOOLEAN DEFAULT TRUE
    );


/**
    @procedure  start_index_monitor     starts the usage monitoring of a specific index
    
    @param  owner_in    schema owner of the index
    @param index_name_in    index name
*/
    procedure start_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    ); 

/**
    @procedure  stop_index_monitor     stops the usage monitoring of a specific index
    
    @param  owner_in    schema owner of the index
    @param index_name_in    index name
*/
    procedure stop_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    ); 

/**
    @procedure  start_tblindex_monitor     start the monitor of all indexes of a specific table (not an IOT table,
                                           nor a domain index)
    
    @param  owner_in    schema owner of the table
    @param table_name_in    table name
*/
    procedure start_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    ); 

/**
    @procedure  stop_tblindex_monitor     stop the monitor of all indexes of a specific table
    
    @param  owner_in    schema owner of the table
    @param table_name_in    table name
*/
    procedure stop_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    ); 

/**
    @procedure   monitor_schema_indexes    enables or disables the usage monitoring of all indexes of a specific schema
                                          (not an IOT table, nor a domain index)
                                          It records the num of successes and failures (in terms of number of indexes) in a log table.
                                          
    @param  ownname_in              Schema name on which to operate. If NULL, the current schema is used
    @param  success_counter_out     counter of for how many indexes managed to enable (or disable) monitoring                           
    @param  failed_counter_out      Returns the number of times an ALTER INDEX statement failed due to 
                                    “ORA-00054 resource busy and acquire with NOWAIT specified.” This 
                                    happens when another session holds an incompatible lock on the base 
                                    table of an index, such as when a transaction on the table is open.
    @param  monitoring_in           Used to switch monitoring on (TRUE) or off (FALSE)                                        
                                            
*/
    procedure monitor_schema_indexes (
        ownname_in VARCHAR2 DEFAULT NULL,
        success_counter_out out number,
    	failed_counter_out out number,
    	monitoring_in BOOLEAN DEFAULT TRUE
    );     
    
/**
    @procedure  log_index_monitor     log in a table the usage results of a specific index.
                                      the procedure logs the single row found for a specific index in
                                      monitor_dw.V_INDEX_USAGE view. NOTE: it only records the row if the 
                                      monitoring has stopped and the end_monitoring_date is filled (ie not null).
                                      This means, that it will not log entries with MONITORING = 'YES' nor entries
                                      with MONITORING = 'NO' and END_MONITORING_DATE is null. The latter happens after
                                      a rebuild of the index.
    
    @param  owner_in    schema owner of the index
    @param index_name_in    index name
*/
    procedure log_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    ); 


/**
    @procedure  log_tblindex_monitor  log in a table the usage results of all indexes of a specific table
                                      the procedure logs the rows found for all indexes of a specific table in
                                      monitor_dw.V_INDEX_USAGE view. NOTE: it only records rows if the 
                                      monitoring has stopped and the end_monitoring_date is filled (ie not null).
                                      This means, that it will not log entries with MONITORING = 'YES' nor entries
                                      with MONITORING = 'NO' and END_MONITORING_DATE is null. The latter happens after
                                      a rebuild of the index.
        
    @param  owner_in    schema owner of the table
    @param table_name_in    table name
*/
    procedure log_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    ); 

/**
    @procedure  log_schema_index_monitor  log in a table the usage results of all indexes of a specific schema
                                      the procedure logs the rows found for all indexes of a specific schema in
                                      monitor_dw.V_INDEX_USAGE view. NOTE: it only records rows if the 
                                      monitoring has stopped and the end_monitoring_date is filled (ie not null).
                                      This means, that it will not log entries with MONITORING = 'YES' nor entries
                                      with MONITORING = 'NO' and END_MONITORING_DATE is null. The latter happens after
                                      a rebuild of the index.
        
    @param  owner_in    Schema name on which to operate. If NULL, the current schema is used
*/
    procedure log_schema_index_monitor (
        owner_in    in  varchar2
    );
    
/**
    function    bool_to_integer     simple conversion function from boolean to integer
    
    @param  bool_value_in in      input boolean value
    
    @return     0 if false, 1 if true, null if null
*/  
    function bool_to_integer(
        bool_value_in  in boolean   
    )   return  number;

END MONITOR_INDEX_USAGE;
/
grant execute on monitor_dw.MONITOR_INDEX_USAGE to ETL_DW;
