cluster_name="eks-ps-cluster"
kubectl set env daemonset -n kube-system aws-node ENABLE_POD_ENI=true

# Get VPC ID from the Cluster
vpc_id=$(aws eks describe-cluster --name ${cluster_name} \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

# Create NGinx Pod Security Group
nginx_pod_sg_id=$(aws ec2 create-security-group --group-name NginxPod \
   --description "Security group to apply yo all Nginx pods" --vpc-id ${vpc_id} \
   --query "GroupId" --output text)

# Allow all ingress through port 80
aws ec2 authorize-security-group-ingress \
  --group-id ${nginx_pod_sg_id} \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Create SecurityGroupPolicy
kubectl apply -f - <<EOF
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: ps-security-group-policy
spec:
  serviceAccountSelector: 
    matchLabels: 
      app: nginx
  securityGroups:
    groupIds: 
      - ${nginx_pod_sg_id}
EOF
