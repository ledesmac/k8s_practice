locals {
  cluster_name = "eks-playground"
  vpc_id        = data.aws_ssm_parameter.vpc_id.value
  subnet_ids    = data.aws_subnets.subnet_ids.ids
}

data "aws_ssm_parameter" "vpc_id" {
  name = "vpc_id"
}

data "aws_subnets" "subnet_ids" {
  filter {
    name   = "vpc-id"
    values = [data.aws_ssm_parameter.vpc_id.value]
  }
  tags = {
    tier = "private"
  }
}
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name
  cluster_version = "1.24"

  vpc_id                         = local.vpc_id
  subnet_ids                     = local.subnet_ids
  cluster_endpoint_public_access = true
}

module eks_mng {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "19.5.1"
  name            = "${local.cluster_name}-mng"
  cluster_name    = local.cluster_name
  cluster_version = "1.24"

  subnet_ids = local.subnet_ids

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  // Note: `disk_size`, and `remote_access` can only be set when using the EKS managed node group default launch template
  // This module defaults to providing a custom launch template to allow for custom security groups, tag propagation, etc.
  // use_custom_launch_template = false
  // disk_size = 50
  //
  //  # Remote access cannot be specified with a launch template
  //  remote_access = {
  //    ec2_ssh_key               = module.key_pair.key_pair_name
  //    source_security_group_ids = [aws_security_group.remote_access.id]
  //  }

  min_size     = 1
  max_size     = 10
  desired_size = 1

  instance_types = ["t3.large"]
  capacity_type  = "SPOT"

  /*labels = {
    Environment = "test"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }*/

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.5.2-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}