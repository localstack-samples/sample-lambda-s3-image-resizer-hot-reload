# adapted from https://docs.aws.amazon.com/lambda/latest/dg/with-s3-tutorial.html
import os
import typing
import uuid
from urllib.parse import unquote_plus

import boto3
from PIL import Image

if typing.TYPE_CHECKING:
    from mypy_boto3_s3 import S3Client
    from mypy_boto3_ssm import SSMClient

MAX_DIMENSIONS = 400, 400
"""The max width and height to scale the image to."""

endpoint_url = None
if os.getenv("STAGE") == "local":
    endpoint_url = "https://localhost.localstack.cloud:4566"

s3: "S3Client" = boto3.client("s3", endpoint_url=endpoint_url)
ssm: "SSMClient" = boto3.client("ssm", endpoint_url=endpoint_url)


def get_bucket_name() -> str:
    parameter = ssm.get_parameter(Name="/localstack-thumbnail-app/buckets/resized")
    return parameter["Parameter"]["Value"]


def resize_image(image_path, resized_path):
    try:
        # Open the image using PIL
        with Image.open(image_path) as image:
            # Calculate thumbnail size
            width, height = image.size
            max_width, max_height = MAX_DIMENSIONS
            if width > max_width or height > max_height:
                ratio = max(width / max_width, height / max_height)
                width = int(width / ratio)
                height = int(height / ratio)
            size = width, height

            # Resize the image using thumbnail method
            image.thumbnail(size)

            # Save the resized image
            image.save(resized_path)
            return True
    except Exception as e:
        print(f"Error resizing image: {e}")
        return False


def download_and_resize(bucket, key, target_bucket) -> str:
    tmpkey = key.replace("/", "")
    download_path = f"/tmp/{uuid.uuid4()}{tmpkey}"
    upload_path = f"/tmp/resized-{tmpkey}"
    s3.download_file(bucket, key, download_path)
    success = resize_image(download_path, upload_path)
    if success:
        s3.upload_file(upload_path, target_bucket, key)
        return upload_path
    else:
        print(f"Failed to resize image: {key}")
        return None


def handler(event, context):
    print(f"Event received: {event}")
    target_bucket = get_bucket_name()

    for record in event["Records"]:
        source_bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        print(f"Processing {source_bucket}/{key}")

        try:
            resized_path = download_and_resize(source_bucket, key, target_bucket)
            if resized_path:
                print(f"Resized image saved to: {resized_path}")
            else:
                print(f"Skipping non-image file: {key}")
        except Exception as e:
            print(f"Error processing image: {e}")
            # Continue processing other records even if one fails
