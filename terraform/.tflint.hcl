plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
}

# Require all variables to have descriptions
rule "terraform_documented_variables" {
  enabled = true
}

# Require all outputs to have descriptions
rule "terraform_documented_outputs" {
  enabled = true
}

# Disallow deprecated interpolation syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Enforce required providers version constraints
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
