eksctl create cluster --version 1.32 --name eks-ps-cluster

eksctl utils associate-iam-oidc-provider --cluster=eks-ps-cluster --approve

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-cli-pod
spec:
  selector:
    matchLabels:
      app: aws-cli-pod
  template:
    metadata:
      labels:
        app: aws-cli-pod
    spec:
      containers:
      - name: aws-cli-pod
        image: public.ecr.aws/aws-cli/aws-cli
        command: [ "sh", "-c", "while true; do sleep 3600; done" ]
EOF

pod_name=$(kubectl get pods -l app=aws-cli-pod | grep Running | awk '{print $1}')
kubectl exec -it $pod_name -- sh
# Inside here, run "aws s3 ls". It won't work because it doesn't have permissions

# Create the IRSA 
eksctl create iamserviceaccount \
    --cluster=eks-ps-cluster \
    --name=aws-cli-pod-sa \
    --namespace=default \
    --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3FullAccess --approve


kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aws-cli-pod
spec:
  selector:
    matchLabels:
      app: aws-cli-pod
  template:
    metadata:
      labels:
        app: aws-cli-pod
    spec:
      serviceAccountName: aws-cli-pod-sa
      containers:
      - name: aws-cli-pod
        image: public.ecr.aws/aws-cli/aws-cli
        command: [ "sh", "-c", "while true; do sleep 3600; done" ]
EOF

pod_name=$(kubectl get pods -l app=aws-cli-pod | grep Running | awk '{print $1}')
kubectl exec -it $pod_name -- sh
# Now run "aws s3 ls" again and it should work this time