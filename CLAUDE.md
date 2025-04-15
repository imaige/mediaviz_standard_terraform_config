# MediaViz Terraform Configuration Guidelines

## Commands
- **Init**: `terraform init -backend-config=backend-config.hcl`
- **Validate**: `terraform validate -var-file terraform.tfvars`
- **Plan**: `terraform plan -var-file terraform.tfvars -out plan.out`
- **Apply**: `terraform apply -input=false plan.out`
- **Format**: `terraform fmt -check -recursive`
- **Security Scan**: `checkov -d . --framework terraform`

## Code Style Guidelines
- **Formatting**: 2-space indentation, aligned parameter values, empty lines between logical blocks
- **Naming**: Snake_case for variables; hyphenated resource names `${var.project_name}-${var.env}-[resource-purpose]`
- **Variables**: Include description, type, and default value; mark sensitive variables
- **Module Structure**: Separate `main.tf`, `variables.tf`, and `outputs.tf` files per module
- **Resource Naming**: Function/resource type appended at end (e.g., `-role`, `-policy`, `-sg`)
- **Error Handling**: Use `depends_on`, `lifecycle` blocks, DLQs for processing failures
- **Security**: Follow least privilege principle, use KMS encryption, specific ingress/egress rules
- **Tags**: Apply standard tags with `merge(var.tags, {...})` pattern

## Best Practices
- Always run validation before applying changes
- Review security scan results before applying changes
- Use branch protection and require PR reviews
- Maintain separate environments (dev/qa/prod)
- Never expose database credentials in code or version control