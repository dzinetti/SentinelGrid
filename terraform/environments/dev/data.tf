# Identità IAM corrente (chiunque esegua Terraform da terminale)
data "aws_caller_identity" "current" {}

# Ruolo IAM per CodePipeline (risolto dinamicamente per nome)
data "aws_iam_role" "codepipeline" {
  name = "AWSCodePipelineServiceRole-eu-west-1-sentinelgrid-pipeline-v2"
}

# Ruolo IAM per CodeBuild (risolto dinamicamente per nome)
data "aws_iam_role" "codebuild" {
  name = "codebuild-SentinelGrid-CodeBuild-2-service-role"
}