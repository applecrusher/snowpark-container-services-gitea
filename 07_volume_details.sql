USE ROLE GITEA_SERVICE_ROLE;

--Service must be running to see results from this query
SHOW SERVICE VOLUMES IN SERVICE GITEA_DB.PUBLIC.GITEA_SERVICE;

SELECT 
    usage_date,
    compute_pool_name,
    bytes,
    storage_type
FROM snowflake.account_usage.block_storage_history
WHERE storage_type = 'BLOCK_STORAGE'
ORDER BY usage_date DESC;