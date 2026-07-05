# CI/CD security pipeline

GitHub Actions workflows: lint -> SAST (Checkov/tfsec/cfn-nag) -> secret scanning -> SCA -> policy gate -> manual approval -> apply -> DAST -> compliance evidence export. Built in Phase 3.
