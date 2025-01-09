import base64
import json
import uuid
import time
import os
import boto3
from typing import Dict, Any, Optional
from botocore.exceptions import ClientError

class ImageUploadHandler:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.eventbridge_client = boto3.client('events')
        self.bucket_name = os.environ['BUCKET_NAME']
        
    def extract_client_id(self, event: Dict[str, Any]) -> Optional[str]:
        """Extract client_id from event headers or query parameters."""
        if 'headers' in event and 'x-client-id' in event['headers']:
            return event['headers']['x-client-id']
        elif ('queryStringParameters' in event and 
              event['queryStringParameters'] and 
              'client_id' in event['queryStringParameters']):
            return event['queryStringParameters']['client_id']
        return None
        
    def create_response(self, status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
        """Create standardized API response."""
        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(body)
        }
        
    def upload_to_s3(self, file_content: bytes, file_path: str, metadata: Dict[str, str]) -> bool:
        """Upload file to S3 with metadata."""
        try:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_path,
                Body=file_content,
                ContentType='image/jpeg',
                Metadata=metadata
            )
            return True
        except ClientError as e:
            print(f"Error uploading to S3: {str(e)}")
            return False
            
    def send_event_to_eventbridge(self, bucket: str, key: str, metadata: Dict[str, str], file_id: str) -> bool:
        """Send processing events to EventBridge."""
        try:
            # Prepare common event details
            common_detail = {
                'bucket': bucket,
                'key': key,
                'client_id': metadata['client_id'],
                'file_id': file_id,
                'timestamp': metadata['timestamp'],
                'version': '1.0'
            }

            # Send main upload event
            main_event = {
                'Source': 'custom.imageUpload',
                'DetailType': 'ImageUploaded',
                'Detail': json.dumps({
                    **common_detail,
                    'processingType': 'upload'
                }),
                'EventBusName': 'default'
            }

            # Send events for each processing module
            events = [main_event]
            for module_type in ['lambda', 'eks']:
                for module_num in range(1, 4):
                    module_name = f"{module_type}-module{module_num}"
                    event = {
                        'Source': 'custom.imageUpload',
                        'DetailType': f"{module_name.title()}Processing",
                        'Detail': json.dumps({
                            **common_detail,
                            'processingType': module_name
                        }),
                        'EventBusName': 'default'
                    }
                    events.append(event)

            # Send all events in a single batch
            self.eventbridge_client.put_events(Entries=events)
            return True
            
        except Exception as e:
            print(f"Error sending events to EventBridge: {str(e)}")
            return False

    def handle_upload(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main handler for image upload."""
        try:
            # Validate request body
            if 'body' not in event:
                return self.create_response(400, {'error': 'No file content found'})

            # Get and validate client_id
            client_id = self.extract_client_id(event)
            if not client_id:
                return self.create_response(400, {'error': 'client_id is required'})

            # Decode file content
            try:
                file_content = base64.b64decode(event['body'])
            except Exception:
                return self.create_response(400, {'error': 'Invalid file content'})

            # Generate file metadata
            timestamp = str(int(time.time()))
            file_id = str(uuid.uuid4())
            metadata = {
                'timestamp': timestamp,
                'uuid': file_id,
                'client_id': client_id
            }

            # Generate file path
            filename = f"{client_id}/{file_id}-{timestamp}.jpg"
            file_path = f"uploads/{filename}"

            # Upload to S3
            if not self.upload_to_s3(file_content, file_path, metadata):
                return self.create_response(500, {'error': 'Failed to upload file'})

            # Send events to EventBridge
            if not self.send_event_to_eventbridge(
                self.bucket_name, file_path, metadata, file_id
            ):
                print("Warning: EventBridge event sending failed")

            # Return success response
            return self.create_response(200, {
                'message': 'Upload successful',
                'filename': filename,
                'file_id': file_id,
                'timestamp': timestamp,
                'client_id': client_id
            })

        except Exception as e:
            print(f"Unexpected error: {str(e)}")
            return self.create_response(500, {'error': 'Internal server error'})

# Initialize handler
handler = ImageUploadHandler()

# Lambda entry point
def handle_upload(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    return handler.handle_upload(event, context)