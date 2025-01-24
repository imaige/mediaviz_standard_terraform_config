import base64
import json
import uuid
import time
import os
import boto3
from typing import Dict, Any, Optional, List, Union
from botocore.exceptions import ClientError
from botocore.config import Config
from datetime import datetime
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configure AWS RDS Data client
config = Config(
    retries=dict(
        max_attempts=3
    )
)


class ImageUploadHandler:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.eventbridge_client = boto3.client('events')
        self.rds_client = boto3.client('rds-data', config=config)
        self.region = self.s3_client.meta.region_name

    def extract_and_validate_header_photo_details(self, event: Dict[str, Any]) -> Optional[Dict]:
        """Extract client_id from event headers or query parameters."""
        if 'headers' in event:
            headers = event.get('headers', {})
            if 'x-bucket-name' in event['headers'] and 'x-file-name' in event['headers']:
                return {
                    'bucket_name': headers.get('x-bucket-name'),
                    'file_name': headers.get('x-file-name'),
                    'models': headers.get('x-models'),
                    'company_id': headers.get('x-company-id'),
                    'user_id': headers.get('x-user-id'),
                    'project_table_name': headers.get('x-project-table-name'),
                    'client_side_id': headers.get('x-client-side-id'),
                    'title': headers.get('x-title'),
                    'description': headers.get('x-description'),
                    'format': headers.get('x-format'),
                    'size': headers.get('x-size'),
                    'source_resolution_x': headers.get('x-source-resolution-x'),
                    'source_resolution_y': headers.get('x-source-resolution-y'),
                    'date_taken': headers.get('x-date-taken'),
                    'latitude': headers.get('x-latitude'),
                    'longitude': headers.get('x-longitude'),
                }
            else:
                return None
        # elif 'queryStringParameters' in event and event['queryStringParameters']:
        #     if 'bucket_name' in event['queryStringParameters'] and 'file_name' in event['queryStringParameters']:
        #         return {
        #             'bucket-name': event['queryStringParameters']['bucket_name'],
        #             'file-name': event['queryStringParameters']['file_name']
        #         }
        #     else:
        #         return None
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

    def upload_to_s3(self, file_content: bytes, file_path: str, bucket_name: str, content_type: str) -> bool:
        """Upload file to S3 with metadata."""
        try:
            content_type = ''
            if content_type.lower() in ['jpg', 'jpeg']:
                content_type = 'image/jpeg'
            elif content_type.lower() == 'png':
                content_type = 'image/png'
            elif content_type.lower() == 'heic':
                content_type = 'image/heic'
            self.s3_client.put_object(
                Bucket=bucket_name,
                Key=file_path,
                Body=file_content,
                ContentType=content_type
            )
            return True
        except ClientError as e:
            logger.error(f"Error uploading to S3: {str(e)}")
            return False

    def insert_photo_to_database(
            self,
            request_id: uuid,
            user_id: int,
            company_id: int,
            photo_s3_link: str,
            project_table_name: str,
            client_side_id: Union[str, None],
            file_path: Union[str, None],
            title: Union[str, None],
            description: Union[str, None],
            format: Union[str, None],
            size: Union[int, None],
            source_resolution_x: Union[int, None],
            source_resolution_y: Union[int, None],
            date_taken: Union[str, None],
            latitude: Union[float, None],
            longitude: Union[float, None],
    ) -> int:
        # date_taken_converted = convert_to_postgres_date(date_taken) if date_taken is not None else None
        response = self.rds_client.execute_statement(
            resourceArn=os.environ['DB_CLUSTER_ARN'],
            secretArn=os.environ['DB_SECRET_ARN'],
            database=os.environ['DB_NAME'],
            sql='''
                INSERT INTO 
                    photos (
                        user_id, 
                        company_id, 
                        photo_s3_link, 
                        project_table_name, 
                        client_side_id, 
                        file_path, 
                        title, 
                        description, 
                        format, 
                        size, 
                        source_resolution_x, 
                        source_resolution_y, 
                        date_taken, 
                        date_uploaded, 
                        latitude, 
                        longitude
                    )
                VALUES (
                    :user_id, 
                    :company_id, 
                    :photo_s3_link, 
                    :project_table_name, 
                    :client_side_id, 
                    :file_path, 
                    :title, 
                    :description, 
                    :format, 
                    :size, 
                    :source_resolution_x, 
                    :source_resolution_y, 
                    CAST(:date_taken AS TIMESTAMP), 
                    CAST(:date_uploaded AS TIMESTAMP), 
                    :latitude, 
                    :longitude
                )
                RETURNING
                    id
                ''',
            parameters=[
                {'name': 'user_id', 'value': {'longValue': user_id}},
                {'name': 'company_id', 'value': {'longValue': company_id}},
                {'name': 'photo_s3_link', 'value': {'stringValue': photo_s3_link}},
                {'name': 'project_table_name', 'value': {'stringValue': project_table_name}},
                {'name': 'client_side_id',
                 'value': {'stringValue': client_side_id} if client_side_id else {'isNull': True}},
                {'name': 'file_path', 'value': {'stringValue': file_path} if file_path else {'isNull': True}},
                {'name': 'title', 'value': {'stringValue': title} if title else {'isNull': True}},
                {'name': 'description', 'value': {'stringValue': description} if description else {'isNull': True}},
                {'name': 'format', 'value': {'stringValue': format} if format else {'isNull': True}},
                {'name': 'size', 'value': {'longValue': size} if size else {'isNull': True}},
                {'name': 'source_resolution_x',
                 'value': {'longValue': source_resolution_x} if source_resolution_x else {'isNull': True}},
                {'name': 'source_resolution_y',
                 'value': {'longValue': source_resolution_y} if source_resolution_y else {'isNull': True}},
                {'name': 'date_taken', 'value': {'stringValue': date_taken} if date_taken else {'isNull': True}},
                # handling of None done above
                {'name': 'date_uploaded', 'value': {'stringValue': datetime.now().isoformat()}},
                {'name': 'latitude', 'value': {'doubleValue': latitude} if latitude else {'isNull': True}},
                {'name': 'longitude', 'value': {'doubleValue': longitude} if longitude else {'isNull': True}},
            ]
        )
        if response['records']:
            generated_photo_id = response['records'][0][0]['longValue']
            logger.info(f"DB insert Successful for photo {generated_photo_id} for client {company_id}")
            return generated_photo_id
        else:
            logger.error(f"Error generating record for photo from request {request_id} for client {company_id}")

    def send_events_to_eventbridge(self, request_id: uuid, bucket: str, photo_id: int, photo_s3_url: str, models: str,
                                   timestamp) -> bool:
        """Send processing events to EventBridge."""
        try:
            # Prepare common event details
            common_detail = {
                'request_id': request_id,
                'bucket': bucket,
                'photo_id': photo_id,
                'timestamp': timestamp,
                'version': '1.0',
                'photo_s3_link': photo_s3_url
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

            events = [main_event]

            models_parsed = models.split(",")

            # Create events for each processing model
            for model_name in models_parsed:
                event = {
                    'Source': 'custom.imageUpload',
                    'DetailType': f"{model_name.strip()}_processing",
                    'Detail': json.dumps({
                        **common_detail,
                        'processingType': model_name.strip()
                    }),
                    'EventBusName': 'default'
                }

                events.append(event)

            # Send all events in a single batch
            self.eventbridge_client.put_events(Entries=events)
            logger.info(f"Upload & event creation complete for photo {photo_id} for client {company_id}")
            return True

        except Exception as e:
            logger.error(f"Error sending events to EventBridge: {str(e)}")
            return False

    def handle_upload(self, event: Dict[str, Any], context: Any) -> Dict[str, Any]:
        """Main handler for image upload."""
        try:
            # Validate request body
            if 'body' not in event:
                return self.create_response(400, {'error': 'No file content found'})

            headers = self.extract_and_validate_header_photo_details(event)
            if not headers:
                self.create_response(400, {'error': 'Header does not contain required detail'})

            logger.info(f"headers: {headers}")

            # TODO: auth check with token against DB

            # photo_encoded = event['body']
            body = json.loads(event['body'])
            # Extract fields
            base64_content = body.get('file_content')
            filename = body.get('filename', 'unknown')
            mimetype = body.get('mimetype', 'application/octet-stream')
            try:
                # file_content = base64.b64decode(photo_encoded)
                file_content = base64.b64decode(base64_content)
            except Exception as e:
                logger.error(f"Exception decoding file: {e}")
                return self.create_response(400, {'error': 'Invalid file content'})

            bucket_name = headers.get('bucket_name')
            file_name = headers.get('file_name')
            # s3_response = self.s3_client.head_object(
            #     Bucket=bucket_name,
            #     Key=file_name
            # )

            # Generate file path
            file_path = f"uploads/{file_name}"
            logger.info(f"file_path is: {file_path}")
            s3_url = f"https://{bucket_name}.s3.{self.region}.amazonaws.com/{file_path}"
            logger.info(f"s3_url: {s3_url}")

            # Extract required fields from body
            # TODO: crystallize request format for request/EventBridge event/S3 photo publish that the frontend will use
            models = headers.get("models")
            bucket_name = headers.get("bucket_name")
            user_id = headers.get("user_id")
            company_id = headers.get("company_id")
            photo_s3_link = s3_url
            project_table_name = headers.get("project_table_name")
            client_side_id = headers.get("client_side_id", None)
            title = headers.get("title", None)
            description = headers.get("description", None)
            format = headers.get("format", None)
            size = headers.get("size", None)
            source_resolution_x = headers.get("source_resolution_x", None)
            source_resolution_y = headers.get("source_resolution_y", None)
            date_taken = headers.get("date_taken", None)
            latitude = headers.get("latitude", None)
            longitude = headers.get("longitude", None)

            # TODO: validate company_id and user_id against DB

            # Generate file metadata
            timestamp = str(int(time.time()))
            request_id = str(uuid.uuid4())

            # insert into database returning ID for push to future events
            photo_id = self.insert_photo_to_database(
                request_id,
                int(user_id),
                int(company_id),
                photo_s3_link,
                project_table_name,
                client_side_id,
                file_path,
                title,
                description,
                format,
                int(size) if size else None,
                int(source_resolution_x) if source_resolution_x else None,
                int(source_resolution_y) if source_resolution_y else None,
                date_taken,
                float(latitude) if latitude else None,
                float(longitude) if longitude else None
            )

            # Upload to S3
            # TODO: add retry logic
            if not self.upload_to_s3(file_content, file_path, bucket_name, mimetype):
                return self.create_response(500, {'error': f'Failed to upload file for photo {photo_id}'})

            # Send events to EventBridge - retry handled by DLQ
            if not self.send_events_to_eventbridge(
                    request_id, bucket_name, photo_id, s3_url, models, timestamp
            ):
                logger.error(f"Warning: EventBridge event sending failed for photo {photo_id}")

            # Return success response
            return self.create_response(200, {
                'message': 'Upload successful',
                'photo_id': photo_id,
                'timestamp': timestamp,
                'company_id': company_id
            })

        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            return self.create_response(500, {'error': 'Internal server error'})


# Initialize handler
handler = ImageUploadHandler()


# Lambda entry point
def handle_upload(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    return handler.handle_upload(event, context)


# Helpers
def convert_to_postgres_date(date_str):
    input_formats = ["%Y-%m-%d", "%m/%d/%y", "%m-%d-%y", "%m/%d/%y %H:%M:%S.%f"]
    for fmt in input_formats:
        try:
            parsed_date = datetime.strptime(date_str, fmt)
            postgres_date = parsed_date.strftime('%Y-%m-%d')
            return postgres_date
        except ValueError as e:
            logger.error(f"Error converting date: {e}")

    raise ValueError("Unknown date format")
