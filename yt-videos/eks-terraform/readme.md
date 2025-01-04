This directory contains the code for the tutorial covered in the video.

The [video-progression.md](video-progression.md) file contains the steps performed in the video.

The [tf_modules](tf_modules) directory contains the code needed to create an EKS cluster and its required resources using Terraform modules.

The [without_modules](without_modules) directory contains the code needed to create an EKS cluster and its required resources without using Terraform modules.

### Important Notes

**Don't forget to run terraform destroy to clean up resources once you're done.**

Destroying Resources Without Modules

When destroying resources created without modules, you may encounter the following issue:

`Error: deleting EKS Cluster (demo-eks-cluster): operation error EKS: DeleteCluster, https response error StatusCode: 409, RequestID: 63c01105-9ff0-48f7-94d1-449ee0657688, ResourceInUseException: Cluster has nodegroups attached`

Simply run the `terraform destroy` command again to resolve this issue.