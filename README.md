to initialize:
terraform init -backend-config=dev/backend-config.hcl

next, run validate:
terraform validate -var-file dev/terraform.tfvars

to plan:
terraform plan -var-file dev/terraform.tfvars -out plan.out

to apply: (importantly, pass plan.out to apply)
terraform apply -input=false plan.out

security resource scans:
https://www.checkov.io/5.Policy%20Index/terraform.html 
(can also use extensions in VSCode or JetBrains/PyCharm/etc.)

To bind a new AWS Account to local machine:
kubectl edit configmap aws-auth -n kube-system

To add a cluster to configmap:
aws eks update-kubeconfig --region us-east-2 --name [cluster_name]