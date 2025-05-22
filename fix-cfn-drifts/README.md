
## Lab Setup
All the files in this folder were used in the demo in this [video](https://youtu.be/ir0qd06jwq8)
### Stack Setup and Drifts 
1. Set up your stack using this[template](fix-cfn-drifts\lab-original.yaml)
2. Cause drifts on the EC2 instance:
    - Update the EC2 Instance type to t2.small
    - Update the volume size to 44 GiB
    - Add a new tag to the EC2 instance.

### Fix the drifts caused above following steps below:

1. Update the stack using this [tempalte](fix-cfn-drifts\labAddDeletePolicy-Step1.yaml). This step adds the DeletionPolicy:Retain attribute to the EC2 instance.
2. Update the stack again to remove resources from stack/template. This [template](fix-cfn-drifts\labRemoveResources-Step2.yaml) doesn't contain the EC2, thus remove it from the stack
3. Import the resource and upload this [template](fix-cfn-drifts\labImportResources-Step3.yaml) when prompted.This template contains the current configuration and fixes drifts on the EC2 instance. Update parameters as follow:
    - InstanceType = t2.small
    - VolumeSize = 44
4. Remove the DeletionPolicy:Retain from the EC2 instance. Update the stack using this [template](fix-cfn-drifts\labRemoveDeletePolicy-Step4.yaml).
