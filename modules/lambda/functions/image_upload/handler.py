import base64
import json
import uuid
import time
import os
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
eventbridge_client = boto3.client('events')
BUCKET_NAME = os.environ['BUCKET_NAME']

def handle_upload(event, context):
    try:
        # Parse the request
        if 'body' not in event:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'No file content found'})
            }
            
        # Get client_id from request headers or query parameters
        client_id = None
        if 'headers' in event and 'x-client-id' in event['headers']:
            client_id = event['headers']['x-client-id']
        elif 'queryStringParameters' in event and event['queryStringParameters'] and 'client_id' in event['queryStringParameters']:
            client_id = event['queryStringParameters']['client_id']
            
        if not client_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'client_id is required'})
            }

        # Get file from request
        try:
            file_content = base64.b64decode(event['body'])
        except Exception as e:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Invalid file content'})
            }
        
        # Generate unique filename
        timestamp = int(time.time())
        unique_id = str(uuid.uuid4())
        filename = f"{client_id}/{unique_id}-{timestamp}.jpg"
        
        # Upload to S3 with client metadata
        try:
            s3_client.put_object(
                Bucket=BUCKET_NAME,
                Key=f"uploads/{filename}",
                Body=file_content,
                ContentType='image/jpeg',
                Metadata={
                    'timestamp': str(timestamp),
                    'uuid': unique_id,
                    'client_id': client_id
                }
            )
        except ClientError as e:
            print(f"Error uploading to S3: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Failed to upload file'})
            }
        
        # Put custom event to EventBridge with client_id
        try:
            eventbridge_client.put_events(
                Entries=[
                    {
                        'Source': 'custom.imageUpload',
                        'DetailType': 'ImageUploaded',
                        'Detail': json.dumps({
                            'bucket': BUCKET_NAME,
                            'key': f"uploads/{filename}",
                            'client_id': client_id,
                            'timestamp': timestamp,
                            'uuid': unique_id
                        }),
                        'EventBusName': 'default'
                    }
                ]
            )
        except Exception as e:
            print(f"Error sending event to EventBridge: {str(e)}")
            # Continue even if EventBridge fails
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Upload successful',
                'filename': filename,
                'timestamp': timestamp,
                'client_id': client_id
            })
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }