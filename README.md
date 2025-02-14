# satispay challange

This challange has been only partially completed due to lack of time and use of a technlogoy i'm not familiar with.

Amazon ECR is (very basically) an abstaraction of docker with all the complications implied in the use of docker inter-host-networking and service discovery.

To simplify and improve (from my perspective) the solution, using EKS would have been beneficial.

Kubernetes allow us to: 

- Effectively connect different services by relying on a pre-built DNS service.
- Allow different pods to assume different IAM roles, enabling the implementation of the principle of least privilege access.
- Effectively isolate workloads from both a network and computational perspective.
- Control pod and nodes scaling independently ( and effective way of scaling workloads is quite complex to explain and mostly workload related but in general terms we can quantify maximum troguhput of a single pod, configure resources and then scale the pod based on troughput and the cluster on non-schedulable pods ) .
- Monitor the cluster and workloads effectively in CloudWatch ( i.e. we could monitor both at cluster and worload level)

These are just basic examples of Kubernetes' capabilities. I am quite sure that Amazon ECS offers the same (or similar) "level of expression" at this level, but the learning curve to effectively achieve these results is not exactly flat..

## this solution

### errors

This solution is grossly incorrect and approximate. The biggest issue is that the two containers are within the same service configuration, preventing them from being scaled independently and from assuming different IAM roles.

Another problem is the repetition of the ECR registry in the TF and in the containerDefinition

## workflow

This is the simple solution to achieve what is needed here is:

https://docs.github.com/en/actions/use-cases-and-examples/deploying/deploying-to-amazon-elastic-container-service

Container definition has been saved externally to be referenced in the WF

The right solution to this problem would be: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

In order to avoid having static credentials on the repository.

If the build should be scheduled in `push` a `path` filer would have allowed us to have indipendent workflow for the two docker.

the container 

## ecs problem

I've lost quite some time due to a problem into defining the differnet services inline with the ecs cluster specification ( https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/examples/complete/main.tf ). Problem was solved when i've start falling back to the single terraform resources.