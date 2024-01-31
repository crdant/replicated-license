output "template_url" {
  value = "https://${aws_s3_bucket.template_bucket.bucket}.s3.${var.aws_region}.amazonaws.com/${aws_s3_object.cloudformation_template.key}"
}
