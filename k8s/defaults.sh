# These defaults are for first time initializations only

# password for root user
postgres_default_root_password="my_db_password"
# password for user 'airflow_admin' on 'airflow_db' database (also the Airflow web ui login credentials)
postgres_default_airflow_admin_password="my_sv_password"
# password for user 'hive' on 'hive_metastore' database
postgres_default_hive_password="1234aa"
# password for user 'admin' of minio
default_minio_password="console1234"
# password for user 'superset' of Superset (database)
# for web login (localhost:32000), use admin/admin
superset_default_password="super"