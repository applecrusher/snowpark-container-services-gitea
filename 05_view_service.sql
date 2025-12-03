SHOW SERVICE CONTAINERS IN SERVICE GITEA_SERVICE;


--There are several ways to call the logs and get the status
SELECT SYSTEM$GET_SERVICE_STATUS('GITEA_SERVICE');
SELECT SYSTEM$GET_SERVICE_LOGS('GITEA_DB.PUBLIC.GITEA_SERVICE', 0, 'gitea-app');
SELECT SYSTEM$GET_SERVICE_LOGS('GITEA_DB.PUBLIC.GITEA_SERVICE', 0, 'postgres-db');

SELECT SYSTEM$GET_SERVICE_LOGS('GITEA_SERVICE', 0, 'gitea-app', 1000); -- Get last ten, modify accordingly.
SELECT SYSTEM$GET_SERVICE_LOGS('GITEA_SERVICE', 0, 'postgres-db', 1000); -- Get last ten, modify accordingly.



--This is the endpoint you need to connect to your app
SHOW ENDPOINTS IN SERVICE GITEA_SERVICE;