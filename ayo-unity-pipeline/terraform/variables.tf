variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-2"
}

variable "key_name" {
  description = "AWS Key Pair name"
  type        = string
  default     = "dummy-lab-key-2"
}
