import boto3
import json
import time
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables
QUEUE_URL = os.getenv("SQS_QUEUE_URL")
AWS_REGION = os.getenv("AWS_REGION", "us-west-2")

# Initialize AWS clients
sqs = boto3.client("sqs", region_name=AWS_REGION)

def process_message(message_body):
    """
    Simulate model processing for the given task.
    Replace this with your actual model logic.
    """
    logger.info(f"Received task: {message_body}")
    
    # Simulated model processing
    try:
        task = json.loads(message_body)
        # Example: Perform some task based on the message content
        # TODO: send link to S3 bucket photo along with other info (project_table_name, photo_id) to EKS deployment/service for processing
        result = f"Processed file {task['file']} from bucket {task['bucket']}"
        logger.info(f"Model processed result: {result}")
        return result
    except Exception as e:
        logger.error(f"Error processing message: {e}")
        raise

def poll_sqs_queue():
    """
    Poll the SQS queue for new messages and process them.
    """
    while True:
        try:
            # Receive messages from the queue
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=10,  # Long-polling
            )

            if "Messages" in response:
                for message in response["Messages"]:
                    receipt_handle = message["ReceiptHandle"]
                    message_body = message["Body"]

                    # Process the message
                    process_message(message_body)

                    # Delete the message from the queue
                    sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt_handle)
                    logger.info(f"Message deleted from queue: {receipt_handle}")
            else:
                logger.info("No messages in the queue. Waiting...")
                time.sleep(5)

        except Exception as e:
            logger.error(f"Error polling the SQS queue: {e}")
            time.sleep(10)  # Backoff on errors

if __name__ == "__main__":
    logger.info("Starting SQS listener...")
    poll_sqs_queue()
