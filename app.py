import boto3
import psycopg2
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

def handler(event, context):
    s3_client = boto3.client('s3')
    glue_client = boto3.client('glue')
    bucket_name = event['bucket_name']
    file_key = event['file_key']
    
    # RDS Configuration
    rds_host = 'your-rds-host'
    rds_port = 5432
    rds_user = 'your-username'
    rds_password = 'your-password'
    rds_db = 'your-db-name'
    
    try:
        # Read file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        data = response['Body'].read().decode('utf-8')
        
        # Push to RDS
        conn = psycopg2.connect(
            host=rds_host,
            port=rds_port,
            user=rds_user,
            password=rds_password,
            database=rds_db
        )
        cursor = conn.cursor()
        cursor.execute("INSERT INTO your_table (data_column) VALUES (%s)", (data,))
        conn.commit()
        conn.close()
        return {"status": "success", "message": "Data pushed to RDS"}
    except psycopg2.Error as e:
        print(f"RDS error: {e}")
        # Push to Glue if RDS fails
        try:
            glue_client.put_table_data(
                DatabaseName='your-glue-database',
                TableName='your-glue-table',
                Records=[{'data_column': data}]
            )
            return {"status": "success", "message": "Data pushed to Glue"}
        except Exception as e:
            print(f"Glue error: {e}")
            return {"status": "failure", "message": "Failed to push data"}
