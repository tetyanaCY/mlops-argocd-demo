variable "aws_region"   { type = string }
variable "cluster_name" { type = string }

variable "namespace" {
  type    = string
  default = "infra-tools"
}
