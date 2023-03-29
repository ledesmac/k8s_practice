resource "aws_eks_cluster" "test" {
  name     = "test-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    endpoint_private_access = true
    security_group_ids      = [aws_security_group.allow_http_tls.id]
    subnet_ids              = [aws_subnet.east1a.id, aws_subnet.east1b.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.test.version}/amazon-linux-2/recommended/release_version"
}

resource "aws_eks_node_group" "test" {
  cluster_name    = aws_eks_cluster.test.name
  node_group_name = "test-nodegroup"
  version         = aws_eks_cluster.test.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = [aws_subnet.east1a.id, aws_subnet.east1b.id]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
}