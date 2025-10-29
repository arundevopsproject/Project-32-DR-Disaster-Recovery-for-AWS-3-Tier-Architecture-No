# Project-32-DR-Disaster-Recovery-for-AWS-3-Tier-Architecture-No-Trial
![dr1](https://github.com/user-attachments/assets/d6e918ea-185e-4b7a-a23b-017104abce84)


https://medium.com/@irinazarzu/implementing-warm-standby-for-aws-disaster-recovery-route-53-arc-aurora-global-database-s3-e72eb5af2037

Overview
This repository documents ThreadCraft's Disaster Recovery (DR) warm-standby strategy, designed to ensure high availability and data integrity for a critical e-commerce platform. 
The strategy leverages Amazon Aurora Global Database, AWS Route 53 ARC (Application Recovery Controller), and S3 Cross-Region Replication bi-directional (CRR) to minimize downtime and prevent data loss.the repository contains two VPCs, one for the primary region and one for the disaster recovery region. 

More details about this project are documented in my [Medium](https://medium.com/@irinazarzu/implementing-warm-standby-for-aws-disaster-recovery-route-53-arc-aurora-global-database-s3-e72eb5af2037) blog post.

Services used: VPC, SSM, ACM, Route 53, Route 53 Application Recovery Control, Aurora Global Database, S3, EC2.

Workflow:

1. The primary site, located in us-east-1, is continuously monitored with CloudWatch alarms set at the DB, ASG, and ALB levels. When one of the resources fails, an alarm is triggered via SNS and sent to the monitoring team.
2. The monitoring team contacts the decision-making committee to confirm that the primary site has failed. If a failover is necessary, the workload will be moved to the secondary site in the us-west-1 region. The DR team will take action and prepare the infrastructure to handle the application traffic.
3. Following a DR warm-standby strategy, the recovery infrastructure is pre-deployed, with resources running at a scaled-down capacity until needed.
4. EBS volumes are restored from the AWS Backup vault and attached to EC2 instances, which are then scaled up to handle the workload efficiently.
5. The Aurora Global Database is configured with two clusters: one in the primary region and one in the recovery region. Failover operations promote the replica cluster to primary, enabling it to take writes within less than a minute. The RPO is near zero, with a replication lag of 117 milliseconds.
6. S3 bucket data is asynchronously replicated across regions to another bucket. Two replication rules ensure that data is replicated bi-directionally, from Bucket A to Bucket B and vice versa.
7. DNS records are configured for each external application Load Balancer, linked to the same domain, threadcraft.link. Two ACM certificates were issued for the same domain in both regions.
8. ARC is configured with two routing controls that act as a manual on / off switch to direct traffic between regions. Routing control health checks connect routing controls to the aformentioned DNS records to make the switch between sites possible.
9. After testing the application and providing access to internal and external users, the switch will be triggered by a script, redirecting traffic from the first region to the second region.
