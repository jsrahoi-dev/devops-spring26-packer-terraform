# Cleanup Instructions (OPTIONAL)

**WARNING**: This document describes how to destroy all infrastructure and resources created by this project. Only proceed if you intend to completely remove all resources from AWS.

## Overview

This cleanup process will:
1. Destroy all Terraform-managed infrastructure
2. Verify resource deletion
3. Deregister the custom AMI
4. Delete EBS snapshots
5. Verify cleanup in the AWS Console

---

## Prerequisites

Before proceeding with cleanup, ensure you have:
- AWS credentials configured and valid
- Terraform initialized in the working directory
- Access to the AWS Console for verification
- A backup of any important data stored on instances

---

## Step 1: Destroy Terraform Infrastructure

### 1.1 Review Resources to be Destroyed

First, preview what will be destroyed:

```bash
cd /Users/unotest/dev/grad_school/devops/devops-spring26-packer-terraform
terraform plan -destroy
```

This will show all resources that Terraform will remove.

### 1.2 Destroy All Managed Resources

Execute the destroy command:

```bash
terraform destroy
```

When prompted, review the list of resources and type `yes` to confirm destruction.

**Expected output**: All Terraform-managed resources will be deleted (instances, security groups, VPC components, etc.).

---

## Step 2: Verify Terraform Resources Deleted

### 2.1 Check Terraform State

Verify that the state file has been updated:

```bash
terraform show
```

This should return minimal or no output, indicating no resources are managed by Terraform.

### 2.2 Verify in AWS Console

1. Sign in to the AWS Console
2. Check the following regions/services:
   - **EC2 Dashboard**: Verify no instances are running
   - **VPC**: Confirm security groups and network resources are removed
   - **CloudFormation**: Check for any orphaned stacks

---

## Step 3: Deregister the Custom AMI

The AMI created by Packer must be deregistered separately from Terraform.

### 3.1 Identify the AMI

Find the AMI ID created by Packer:

```bash
aws ec2 describe-images \
  --owners self \
  --query 'Images[0].[ImageId,Name,CreationDate]' \
  --output table
```

Note the `ImageId` of the AMI created by this project.

### 3.2 Deregister the AMI

```bash
aws ec2 deregister-image --image-id <AMI_ID>
```

Replace `<AMI_ID>` with the actual ID from step 3.1.

**Expected output**: The command returns the deregistered ImageId.

---

## Step 4: Delete Associated Snapshots

When deregistering an AMI, associated snapshots may remain. These should be deleted to avoid incurring storage costs.

### 4.1 List Snapshots

Find snapshots associated with the deregistered AMI:

```bash
aws ec2 describe-snapshots \
  --owner-ids self \
  --query 'Snapshots[*].[SnapshotId,StartTime,VolumeSize,Description]' \
  --output table
```

Look for snapshots with descriptions related to the custom AMI.

### 4.2 Delete Snapshots

Delete each snapshot:

```bash
aws ec2 delete-snapshot --snapshot-id <SNAPSHOT_ID>
```

Repeat for each snapshot you want to remove.

**Expected output**: The command returns the deleted SnapshotId.

---

## Step 5: Verify Complete Cleanup in AWS Console

### 5.1 AWS Management Console Verification

1. **EC2 Dashboard**:
   - Navigate to Instances → verify no instances remain
   - Navigate to AMIs (under Images) → filter by "Owned by me" → verify custom AMI is gone
   - Navigate to Snapshots → verify snapshots are deleted

2. **VPC Dashboard**:
   - Verify security groups are removed
   - Verify custom VPC components are deleted (if applicable)

3. **IAM Roles** (if created):
   - Check IAM Roles section for any orphaned roles
   - Delete manually if necessary

### 5.2 Cost Verification

- Confirm no new charges are accruing
- Check the Billing Dashboard for stopped resources

---

## Troubleshooting

### Issue: Terraform destroy fails

**Solution**: Manually delete resources in AWS Console, then clear the Terraform state:

```bash
terraform destroy -auto-approve
terraform state rm <resource_path>
```

### Issue: AMI cannot be deregistered

**Cause**: Snapshots or instances still depend on the AMI.

**Solution**:
1. Ensure all instances are terminated
2. Wait a few minutes for AWS to process terminations
3. Retry deregistration

### Issue: Snapshots cannot be deleted

**Cause**: Another resource may reference the snapshot.

**Solution**: Check for any pending AMIs or volumes, delete them first, then retry snapshot deletion.

---

## Rollback (If Needed)

If you need to restore infrastructure:

1. Restore Terraform state from backup (if available)
2. Run `terraform apply` to recreate resources
3. Packer can be re-run to create a new AMI: `packer build packer.pkr.hcl`

---

## Safety Checklist

Before executing cleanup, confirm:

- [ ] You have backed up any important data
- [ ] You have documented the AMI ID and snapshot IDs
- [ ] You understand the costs that will stop accruing
- [ ] You have received approval from project stakeholders (if applicable)
- [ ] You are targeting the correct AWS account

---

## Post-Cleanup Verification

After completing all steps, verify:

1. No instances running: `aws ec2 describe-instances --query 'Reservations[*].Instances[*].State.Name' --output text`
2. No custom AMIs: `aws ec2 describe-images --owners self --query 'Images[*].ImageId' --output text`
3. No snapshots: `aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].SnapshotId' --output text`

All should return empty or minimal output.

---

## Additional Resources

- [Terraform Destroy Documentation](https://www.terraform.io/cli/commands/destroy)
- [AWS EC2 Deregister AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/deregister-ami.html)
- [AWS EBS Snapshot Deletion](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-deleting-snapshot.html)

---

**Last Updated**: 2026-03-29
**Project**: devops-spring26-packer-terraform
