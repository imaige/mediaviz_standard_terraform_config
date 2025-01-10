# # provider information from main.tf
# # for ex., can centralize what is currently as a provider in modules/networking/vpc.tf
# # in addition, some default tags, incl. 
# provider "aws" {
#   region = var.aws_region

#   default_tags {
#     tags = {
#       "project" = "aws"
#       "env"     = var.env
#     }
#   }
# }