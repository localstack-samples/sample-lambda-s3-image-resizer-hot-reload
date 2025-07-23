{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${cdn_identity_arn}"
      },
      "Action": "s3:GetObject",
      "Resource": "${website_bucket_arn}/*"
    }
  ]
}