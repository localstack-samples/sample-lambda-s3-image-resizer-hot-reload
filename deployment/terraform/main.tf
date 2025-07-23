locals {
  # TO-DO: The environment variable STAGE is required for Lambdas to connect to LocalStack endpoints. 
  # The environment variable can be removed once Lambdas are adapted to support transparent endpoint injection.
  env_variables               = { STAGE = "local" }
  root_dir                    = "${path.module}/../.."
  images_bucket               = "localstack-thumbnails-app-images"
  image_resized_bucket        = "localstack-thumbnails-app-resized"
  website_bucket              = "localstack-website"
  failure_notifications_email = "my-email@example.com"
}

# S3
resource "aws_s3_bucket" "images_bucket" {
  bucket = local.images_bucket
}

resource "aws_s3_bucket" "image_resized_bucket" {
  bucket = local.image_resized_bucket
}

# SSM

resource "aws_ssm_parameter" "images_bucket_ssm" {
  name  = "/localstack-thumbnail-app/buckets/images"
  type  = "String"
  value = aws_s3_bucket.images_bucket.bucket
}

resource "aws_ssm_parameter" "images_resized_bucket_ssm" {
  name  = "/localstack-thumbnail-app/buckets/resized"
  type  = "String"
  value = aws_s3_bucket.image_resized_bucket.bucket
}

## Lambdas

# IAM SSM Policy

resource "aws_iam_policy" "lambdas_ssm" {
  name   = "LambdasAccessSsm"
  policy = file("policies/lambda_ssm.json")
}

# Presign Lambda

resource "aws_iam_role" "presign_lambda_role" {
  name               = "PresignLambdaRole"
  assume_role_policy = file("policies/lambda.json")
}

resource "aws_iam_policy" "presign_lambda_s3_buckets" {
  name = "PresignLambdaS3AccessPolicy"
  policy = templatefile("policies/presign_lambda_s3_buckets.json.tpl", {
    images_bucket = aws_s3_bucket.images_bucket.bucket
  })
}

resource "aws_iam_role_policy_attachment" "presign_lambda_s3_buckets" {
  role       = aws_iam_role.presign_lambda_role.name
  policy_arn = aws_iam_policy.presign_lambda_s3_buckets.arn
}

resource "aws_iam_role_policy_attachment" "presign_lambda_ssm" {
  role       = aws_iam_role.presign_lambda_role.name
  policy_arn = aws_iam_policy.lambdas_ssm.arn
}

resource "aws_lambda_function" "presign_lambda" {
  function_name = "presign"
  filename      = "${local.root_dir}/lambdas/presign/lambda.zip"
  handler       = "handler.handler"
  runtime       = "python3.11"
  timeout       = 10
  role          = aws_iam_role.presign_lambda_role.arn
  source_code_hash = filebase64sha256("${local.root_dir}/lambdas/presign/lambda.zip")

  environment {
    variables = local.env_variables
  }
}

resource "aws_lambda_function_url" "presign_lambda_function" {
  function_name      = aws_lambda_function.presign_lambda.function_name
  authorization_type = "NONE"
}

# List images lambda

resource "aws_iam_role" "list_lambda_role" {
  name               = "ListLambdaRole"
  assume_role_policy = file("policies/lambda.json")
}

resource "aws_iam_policy" "list_lambda_s3_buckets" {
  name = "ListLambdaS3AccessPolicy"
  policy = templatefile("policies/list_lambda_s3_buckets.json.tpl", {
    images_bucket         = aws_s3_bucket.images_bucket.bucket,
    images_resized_bucket = aws_s3_bucket.image_resized_bucket.bucket
  })
}

resource "aws_iam_role_policy_attachment" "list_lambda_s3_buckets" {
  role       = aws_iam_role.list_lambda_role.name
  policy_arn = aws_iam_policy.list_lambda_s3_buckets.arn
}

resource "aws_iam_role_policy_attachment" "list_lambda_ssm" {
  role       = aws_iam_role.list_lambda_role.name
  policy_arn = aws_iam_policy.lambdas_ssm.arn
}

resource "aws_lambda_function" "list_lambda" {
  function_name = "list"
  filename      = "${local.root_dir}/lambdas/list/lambda.zip"
  handler       = "handler.handler"
  runtime       = "python3.11"
  timeout       = 10
  role          = aws_iam_role.list_lambda_role.arn
  source_code_hash = filebase64sha256("${local.root_dir}/lambdas/list/lambda.zip")

  environment {
    variables = local.env_variables
  }
}

resource "aws_lambda_function_url" "list_lambda_function" {
  function_name      = aws_lambda_function.list_lambda.function_name
  authorization_type = "NONE"
}

# Resize lambda

resource "aws_iam_role" "resize_lambda_role" {
  name               = "ResizeLambdaRole"
  assume_role_policy = file("policies/lambda.json")
}

resource "aws_iam_policy" "resize_lambda_s3_buckets" {
  name = "ResizeLambdaS3Buckets"
  policy = templatefile("policies/resize_lambda_s3_buckets.json.tpl", {
    images_resized_bucket = aws_s3_bucket.image_resized_bucket.bucket
  })
}

resource "aws_iam_role_policy_attachment" "resize_lambda_s3_buckets" {
  role       = aws_iam_role.resize_lambda_role.name
  policy_arn = aws_iam_policy.resize_lambda_s3_buckets.arn
}

resource "aws_iam_policy" "resize_lambda_sns" {
  name = "ResizeLambdaSNS"
  policy = templatefile("policies/resize_lambda_sns.json.tpl", {
    failure_notifications_topic_arn = aws_sns_topic.failure_notifications.arn,
    resize_lambda_arn = aws_lambda_function.resize_lambda.arn
  })
}

resource "aws_iam_role_policy_attachment" "resize_lambda_sns" {
  role       = aws_iam_role.resize_lambda_role.name
  policy_arn = aws_iam_policy.resize_lambda_sns.arn
}

resource "aws_iam_role_policy_attachment" "resize_lambda_ssm" {
  role       = aws_iam_role.resize_lambda_role.name
  policy_arn = aws_iam_policy.lambdas_ssm.arn
}

resource "aws_lambda_function" "resize_lambda" {
  function_name = "resize"
  filename      = "${local.root_dir}/lambdas/resize/lambda.zip"
  handler       = "handler.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.resize_lambda_role.arn
  source_code_hash = filebase64sha256("${local.root_dir}/lambdas/resize/lambda.zip")

  environment {
    variables = local.env_variables
  }

  dead_letter_config {
    target_arn = aws_sns_topic.failure_notifications.arn
  }
}

# SNS Topic for failure notifications
resource "aws_sns_topic" "failure_notifications" {
  name = "image_resize_failures"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.failure_notifications.arn
  protocol  = "email"
  endpoint  = local.failure_notifications_email
}

# S3 Bucket Notification for Lambda trigger
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.images_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.resize_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "s3_invoke_resize_lambda" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resize_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images_bucket.arn
}

# CloudFront

resource "aws_s3_bucket" "website_bucket" {
  bucket = local.website_bucket
}

resource "aws_s3_bucket_website_configuration" "website_configuration" {
  bucket = aws_s3_bucket.website_bucket.bucket
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "website_file_index" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "index.html"
  source       = "${local.root_dir}/website/index.html"
  etag         = filemd5("${local.root_dir}/website/index.html")
  content_type = "text/html"
  acl          = "public-read"
}

resource "aws_s3_object" "website_file_js" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "app.js"
  source       = "${local.root_dir}/website/app.js"
  etag         = filemd5("${local.root_dir}/website/app.js")
  content_type = "application/javascript"
  acl          = "public-read"
}

resource "aws_s3_object" "website_file_icon" {
  bucket       = aws_s3_bucket.website_bucket.bucket
  key          = "favicon.ico"
  source       = "${local.root_dir}/website/favicon.ico"
  etag         = filemd5("${local.root_dir}/website/favicon.ico")
  content_type = "image/x-icon"
  acl          = "public-read"
}

resource "aws_cloudfront_origin_access_identity" "cdn_identity" {
  comment = "OAI for CloudFront to access S3 bucket"
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.bucket
  policy = templatefile("policies/website_s3_bucket.json.tpl", {
    cdn_identity_arn   = aws_cloudfront_origin_access_identity.cdn_identity.iam_arn
    website_bucket_arn = aws_s3_bucket.website_bucket.arn
  })
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website_bucket.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cdn_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.website_bucket.bucket

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website_block_public_access" {
  bucket = aws_s3_bucket.website_bucket.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Outputs

output "presign_lambda_function_url" {
  value = aws_lambda_function_url.presign_lambda_function.function_url
}

output "list_lambda_function_url" {
  value = aws_lambda_function_url.list_lambda_function.function_url
}

output "cloudfront_url" {
  value = "Now open the Web app under: http://${aws_cloudfront_distribution.cdn.domain_name}"
}
