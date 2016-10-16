CREATE OR REPLACE PACKAGE BODY MONITOR_DW.MONITOR_INDEX_USAGE AS

    procedure manage_index_monitoring (
        monitoring_in in BOOLEAN,
        logging_in  in BOOLEAN DEFAULT TRUE         
    )
    IS
        CURSOR included_schemas_cur 
        IS
        SELECT SCHEMA_NAME 
        from monitor_dw.MONDW_INDEX_USAGE_TRG_SCHEMAS 
        where
            INCLUDE_IND = 1;
        
        l_success_cnt   PLS_INTEGER;
        l_failure_cnt   PLS_INTEGER;
    BEGIN
        
        -- if we want to activate monitoring
        IF (monitoring_in = TRUE) THEN

            -- activate monitoring for the included schemas            
            -- loop for each schema
            for r in included_schemas_cur 
            LOOP        
                -- first log any existing monitoring results
                IF (logging_in = TRUE) THEN
                    log_schema_index_monitor(r.schema_name);                                    
                END IF;        
                -- activate for all indexes of the schema
                monitor_dw.MONITOR_INDEX_USAGE.monitor_schema_indexes (
                        ownname_in => r.schema_name,
                        success_counter_out => l_success_cnt,
                        failed_counter_out => l_failure_cnt,
                        monitoring_in => TRUE
                );                                             
            END LOOP;                
        ELSE                                                         
        -- else if we want to deactivate monitoring
            -- deactivate monitoring for the included schemas
            -- loop for each schema
            for r in included_schemas_cur 
            LOOP        
                -- deactivate for all indexes of the schema
                monitor_dw.MONITOR_INDEX_USAGE.monitor_schema_indexes (
                        ownname_in => r.schema_name,
                        success_counter_out => l_success_cnt,
                        failed_counter_out => l_failure_cnt,
                        monitoring_in => FALSE
                );
                -- log index usage result for current schema
                IF (logging_in = TRUE) THEN
                    log_schema_index_monitor(r.schema_name);                                    
                END IF;                                                                     
            END LOOP;                                
        END IF;                      
    END manage_index_monitoring;
    

    procedure start_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    )
    IS
    begin
        execute immediate 'alter index '||owner_in||'.'||index_name_in||' monitoring usage';
    end start_index_monitor;

    procedure stop_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    )
    IS
    begin
        execute immediate 'alter index '||owner_in||'.'||index_name_in||' nomonitoring usage';
    end stop_index_monitor;
    
    procedure start_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    )
    IS
        
    begin
        --  loop for each index of this table
        for r in (
                    select i.OWNER, i.INDEX_NAME
                    from all_indexes i, all_tables t
                    where    
                        t.owner = upper(owner_in)
                        and t.table_name = upper(table_name_in)
                   		and i.table_name = t.table_name
                		and i.table_owner = t.owner
                		-- cannot be used on index of type IOT ORA-25176: storage specification not permitted for primary key
                		and t.iot_type IS NULL
                		and i.index_type != 'DOMAIN'                        
        )
        LOOP
            execute immediate 'alter index '||r.owner||'.'||r.index_name||' monitoring usage';
        END LOOP;                        
    end start_tblindex_monitor;

    procedure stop_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    )
    IS 
    begin
        --  loop for each index of this table
        for r in (
                    select OWNER, INDEX_NAME
                    from all_indexes
                    where    TABLE_OWNER = upper(owner_in)
                        and      TABLE_NAME = upper(table_name_in)
                        )
        LOOP
            execute immediate 'alter index '||r.owner||'.'||r.index_name||' nomonitoring usage';
        END LOOP;                        
    end stop_tblindex_monitor; 
    
    procedure monitor_schema_indexes (
        ownname_in VARCHAR2 DEFAULT NULL,
        success_counter_out out number,
    	failed_counter_out out number,
    	monitoring_in BOOLEAN DEFAULT TRUE
    )
    IS
    	resource_busy exception;
    	PRAGMA exception_init(resource_busy, -54);
    	--l_counter integer:=0;
    	l_schema_name varchar2(30);
    	l_stmt varchar2(256);
        l_monitoring_ind    number;
        
    	cursor not_monitored_cur(p_schema_name varchar2) is 
    		SELECT index_name 
    		FROM all_indexes i, all_tables t
    		where i.owner=upper(p_schema_name)
    		and i.table_name=t.table_name
    		and i.table_owner=t.owner
    		-- cannot be used on index of type IOT ORA-25176: storage specification not permitted for primary key
    		and t.iot_type IS NULL
    		and index_type != 'DOMAIN'
    		MINUS
    		SELECT index_name 
    		FROM monitor_dw.V_INDEX_USAGE 
    		WHERE index_owner=upper(p_schema_name) 
    		AND monitoring='YES';
    	cursor monitored_cur(p_schema_name varchar2) is
    	SELECT index_name
    	FROM monitor_dw.V_INDEX_USAGE
    	WHERE index_owner=upper(p_schema_name)
    	and monitoring='YES';    
    BEGIN
    	l_schema_name       := nvl(ownname_in,user);
    	failed_counter_out  := 0;
        success_counter_out := 0;
    	IF monitoring_in = TRUE THEN
    		for record in not_monitored_cur(l_schema_name) LOOP
    			BEGIN
    				l_stmt:='ALTER INDEX '||l_schema_name||'."'||record.index_name||'" monitoring usage';
    				execute immediate l_stmt;
                    success_counter_out :=  success_counter_out + 1;
    				--counter:=counter+1;
    			EXCEPTION WHEN resource_busy THEN
    				failed_counter_out:=failed_counter_out+1;
    			END;
    		END LOOP;
    	ELSE
    		for record in monitored_cur(l_schema_name) LOOP
    			BEGIN
    				l_stmt:='ALTER INDEX '||l_schema_name||'."'||record.index_name||'" NOMONITORING USAGE';
    				execute immediate l_stmt;
    				--counter:=counter+1;
                    success_counter_out :=  success_counter_out + 1;
    			EXCEPTION WHEN resource_busy THEN
    				failed_counter_out:=failed_counter_out+1;
    			END;
    		END LOOP;
    	END IF;
        
        -- log result of procedure 
        l_monitoring_ind    :=  bool_to_integer(monitoring_in);
        INSERT INTO monitor_dw.MONDW_INDEX_USG_PROC_RESULTS (
            POPULATION_DATE,
            SCHEMA_NAME,
            SUCCESSES,
            FAILURES,
            monitoring_on_ind
        )
        VALUES (
            SYSDATE,
            ownname_in,
            success_counter_out,
            failed_counter_out,
            l_monitoring_ind
        );            
        
        COMMIT;                                                
    END monitor_schema_indexes;     
    
    procedure log_index_monitor (
        owner_in    in  varchar2,
        index_name_in   in varchar2
    )
    IS
    	unique_constraint exception;
    	PRAGMA exception_init(unique_constraint, -1);    
    BEGIN
        INSERT INTO MONITOR_DW.MONDW_INDEX_USAGE t1 (
                INDEX_OWNER,
                INDEX_NAME, 
                TABLE_NAME, 
                MONITORING, 
                USED, 
                START_MONITORING, 
                END_MONITORING, 
                POPULATION_DATE)
        select
            INDEX_OWNER, 
            INDEX_NAME,
            TABLE_NAME,
            MONITORING,
            USED, 
            START_MONITORING,
            END_MONITORING,
            sysdate    
        from monitor_dw.V_INDEX_USAGE t2
        where
            t2.INDEX_OWNER = upper(owner_in)
            and t2.INDEX_NAME = upper(index_name_in)
            and t2.MONITORING = 'NO' and t2.END_MONITORING is NOT NULL; -- get only valid entries where monitoring has been completed

        commit;       
        
    EXCEPTION WHEN unique_constraint THEN
        null; -- just end the procedure gracefully, without raising an exception, so that other calls to
              -- this procedure may continue                                                     
    END log_index_monitor; 

    procedure log_tblindex_monitor (
        owner_in    in  varchar2,
        table_name_in   in varchar2
    )
    IS
    BEGIN
        --  loop for each index of this table and log the corresponding usage row
        for r in (
                    select OWNER, INDEX_NAME
                    from all_indexes
                    where    TABLE_OWNER = upper(owner_in)
                        and      TABLE_NAME = upper(table_name_in)
        )
        LOOP
            log_index_monitor(r.owner, r.index_name);
        END LOOP;                                
    END log_tblindex_monitor;

    procedure log_schema_index_monitor (
        owner_in    in  varchar2
    )
    IS
        l_schema_name varchar2(30);
    BEGIN
    	l_schema_name       := nvl(owner_in,user);    
        --  loop for each index in this schema
        for r in (
                    select OWNER, INDEX_NAME
                    from all_indexes
                    where    OWNER = upper(l_schema_name)
        )
        LOOP
            log_index_monitor(r.owner, r.index_name);
        END LOOP;                                
    
    END log_schema_index_monitor; 

    function bool_to_integer(
        bool_value_in  in  boolean   
    )   return  number
    AS
    BEGIN
        if bool_value_in then
            return 1;
        elsif bool_value_in is null then
            return null;           
        else
            return 0;
        end if;                        
    END bool_to_integer;

        
END MONITOR_INDEX_USAGE;
/
