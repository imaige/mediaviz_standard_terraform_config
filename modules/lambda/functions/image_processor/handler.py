import json
import boto3
import os
from PIL import Image
import io

s3_client = boto3.client('s3')
SOURCE_BUCKET = os.environ['SOURCE_BUCKET']
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']

def handle_processing(event, context):
    for record in event['Records']:
        # Parse SQS message
        body = json.loads(record['body'])
        detail = json.loads(body.get('detail', '{}'))
        
        try:
            # Get image details from event
            source_key = detail.get('key')
            client_id = detail.get('client_id')
            
            if not source_key or not client_id:
                print(f"Missing required fields in event: {detail}")
                continue
                
            # Download image from S3
            response = s3_client.get_object(
                Bucket=SOURCE_BUCKET,
                Key=source_key
            )
            image_content = response['Body'].read()
            
            # Process image with PIL
            with Image.open(io.BytesIO(image_content)) as img:
                # Example: Create thumbnail
                img.thumbnail((300, 300))
                
                # Save processed image
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG')
                buffer.seek(0)
                
                # Generate output key
                filename = source_key.split('/')[-1]
                output_key = f"processed/{client_id}/{filename}"
                
                # Upload processed image
                s3_client.put_object(
                    Bucket=OUTPUT_BUCKET,
                    Key=output_key,
                    Body=buffer,
                    ContentType='image/jpeg',
                    Metadata={
                        'client_id': client_id,
                        'source_image': source_key,
                        'processed': 'true'
                    }
                )
                
                print(f"Successfully processed image: {source_key} -> {output_key}")
                
        except Exception as e:
            print(f"Error processing message: {str(e)}")
            # The message will be moved to DLQ if max retries exceeded
            raise