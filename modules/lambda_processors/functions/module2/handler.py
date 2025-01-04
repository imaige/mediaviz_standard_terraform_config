import json
import os
import logging
import boto3
from typing import Dict, Any
from botocore.config import Config

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configure AWS RDS Data client
config = Config(
    retries = dict(
        max_attempts = 3
    )
)

rds_client = boto3.client('rds-data', config=config)

def handle_processing(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Process SQS messages containing client_id and file_id
    
    Args:
        event: Lambda event containing SQS messages
        context: Lambda context
    
    Returns:
        Dict containing processing results
    """
    try:
        logger.info("Processing event: %s", json.dumps(event))
        
        # Process each message in the batch
        for record in event['Records']:
            # Parse message body
            message = json.loads(record['body'])
            
            # Extract parameters
            client_id = message.get('client_id')
            file_id = message.get('file_id')
            
            if not client_id or not file_id:
                logger.error("Missing required parameters. client_id: %s, file_id: %s", 
                           client_id, file_id)
                continue
                
            logger.info("Processing file %s for client %s", file_id, client_id)
            
            # Process the message
            process_message(client_id, file_id)
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Processing completed successfully'})
        }
        
    except Exception as e:
        logger.error("Error processing messages: %s", str(e), exc_info=True)
        raise

def process_message(client_id: str, file_id: str) -> None:
    """
    Process a message with database interaction
    
    Args:
        client_id: ID of the client
        file_id: ID of the file to process
    """
    try:
        # Execute query using Data API
        response = rds_client.execute_statement(
            resourceArn=os.environ['DB_CLUSTER_ARN'],
            secretArn=os.environ['DB_SECRET_ARN'],
            database=os.environ['DB_NAME'],
            sql='SELECT * FROM files WHERE client_id = :client_id AND file_id = :file_id',
            parameters=[
                {'name': 'client_id', 'value': {'stringValue': client_id}},
                {'name': 'file_id', 'value': {'stringValue': file_id}}
            ]
        )
        
        # Process the database response
        if response['records']:
            # Add your processing logic here
            logger.info("Successfully processed file %s for client %s", file_id, client_id)
        else:
            logger.warning("No record found for file %s and client %s", file_id, client_id)
            
    except Exception as e:
        logger.error("Error processing message for client %s, file %s: %s", 
                    client_id, file_id, str(e), exc_info=True)
        raise