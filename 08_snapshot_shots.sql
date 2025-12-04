CREATE OR REPLACE PROCEDURE GITEA_DAILY_BACKUP_AND_CLEANUP(
    service_name VARCHAR, 
    retention_days INT
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.13'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run_backup'
AS
$$
from snowflake.snowpark.functions import col
import datetime

def run_backup(session, service_name, retention_days):
    # 1. GET VOLUME NAMES
    # We need to know which volumes are attached to the service to snapshot them.
    # Note: This assumes you have block volumes attached.
    volumes_df = session.sql(f"SHOW SERVICE VOLUMES IN SERVICE {service_name}").collect()
    
    snapshot_log = []
    
    for row in volumes_df:
        vol_name = row['name']
        # We only snapshot 'BLOCK' volumes
        if row['volume_type'] != 'BLOCK':
            continue
            
        # 2. CREATE NEW SNAPSHOT
        # Naming convention: svc_vol_YYYYMMDD_HHMM
        now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M")
        snap_name = f"{service_name}_{vol_name}_{now_str}"
        
        # Command to snapshot instance 0 (primary)
        create_cmd = f"""
            CREATE SNAPSHOT {snap_name}
            FROM SERVICE {service_name}
            VOLUME '{vol_name}'
            INSTANCE 0
        """
        try:
            session.sql(create_cmd).collect()
            snapshot_log.append(f"Created: {snap_name}")
        except Exception as e:
            snapshot_log.append(f"Failed to create {snap_name}: {str(e)}")

        # 3. DELETE OLD SNAPSHOTS
        # List all snapshots matching this service/volume pattern
        # Note: We filter strictly to avoid deleting other unrelated snapshots
        show_snaps = session.sql(f"SHOW SNAPSHOTS LIKE '{service_name}_{vol_name}%'").collect()
        
        cutoff_date = datetime.datetime.now() - datetime.timedelta(days=retention_days)
        
        for snap in show_snaps:
            # created_on is usually a datetime object in Snowpark
            created_on = snap['created_on']
            # Ensure timezone awareness compatibility if needed, usually simplest to compare non-tz or convert both
            if created_on.replace(tzinfo=None) < cutoff_date:
                drop_cmd = f"DROP SNAPSHOT {snap['name']}"
                session.sql(drop_cmd).collect()
                snapshot_log.append(f"Deleted Old: {snap['name']}")

    return "\n".join(snapshot_log)
$$;


CREATE OR REPLACE TASK DAILY_GITEA_BACKUP_TASK
    WAREHOUSE = 'GITEA_WH'  -- Use a small warehouse, it takes seconds
    SCHEDULE = 'USING CRON 0 0 * * * UTC'
AS
    CALL SP_DAILY_BACKUP_AND_CLEANUP('GITEA_DB.PUBLIC.GITEA_SERVICE', 21);

-- Enable the task (Tasks are created suspended by default)
ALTER TASK DAILY_GITEA_BACKUP_TASK RESUME;