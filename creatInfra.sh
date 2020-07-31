str="Cisco SPL"
vpcID=`aws ec2 create-vpc --cidr-block 10.0.0.0/16 |  jq -r '.Vpc.VpcId'`

subnetID1=`aws ec2 create-subnet --vpc-id $vpcID --cidr-block 10.0.1.0/24 --availability-zone us-east-2a| jq -r '.Subnet.SubnetId'`
subnetID2=`aws ec2 create-subnet --vpc-id $vpcID --cidr-block 10.0.2.0/24 --availability-zone us-east-2b| jq -r '.Subnet.SubnetId'`

InternetGatewayID=`aws ec2 create-internet-gateway |  jq -r '.InternetGateway.InternetGatewayId'`



aws ec2 attach-internet-gateway --vpc-id $vpcID  --internet-gateway-id $InternetGatewayID


RoutetableID=`aws ec2 create-route-table --vpc-id $vpcID |jq -r '.RouteTable.RouteTableId'`


aws ec2 create-route --route-table-id $RoutetableID  --destination-cidr-block 0.0.0.0/0 --gateway-id $InternetGatewayID

aws ec2 describe-route-tables --route-table-id $RoutetableID

aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcID" --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock}'


aws ec2 associate-route-table  --subnet-id $subnetID1 --route-table-id $RoutetableID
aws ec2 associate-route-table  --subnet-id $subnetID2 --route-table-id $RoutetableID


aws ec2 modify-subnet-attribute --subnet-id $subnetID1  --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $subnetID2 --map-public-ip-on-launch


aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPair.pem

chmod 400 MyKeyPair.pem

groupID=`aws ec2 create-security-group --group-name SSHAccess --description "Security group for SSH access" --vpc-id $vpcID| jq -r '.GroupId'`


aws ec2 authorize-security-group-ingress --group-id $groupID  --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $groupID  --protocol tcp  --port 80 --cidr 0.0.0.0/0



instanceID1=`aws ec2 run-instances --image-id ami-07c1207a9d40bc3bd --count 1 --instance-type t2.micro --key-name MyKeyPair --security-group-ids $groupID --subnet-id $subnetID1 | jq -r '.Instances[].InstanceId'`
sleep 60

publicIpAddr=`aws ec2 describe-instances --instance-ids $instanceID1 | jq -r '.Reservations[].Instances[].PublicIpAddress'`

ssh -i MyKeyPair.pem ubuntu@"$publicIpAddr" "sudo apt-get -y update"

ssh -i  MyKeyPair.pem ubuntu@"$publicIpAddr" "sudo apt-get  install -y nginx"

ssh -i  MyKeyPair.pem ubuntu@"$publicIpAddr" "sudo echo $str > /tmp/index.html"
ssh -i  MyKeyPair.pem ubuntu@"$publicIpAddr" "sudo cp /tmp/index.html /var/www/html/index.nginx-debian.html"
ssh -i  MyKeyPair.pem ubuntu@"$publicIpAddr" "sudo service nginx start"



###CREATE Load balancer 



loadbalancerarn=`aws elbv2 create-load-balancer --name my-load-balancer --subnets $subnetID1 $subnetID2 --security-groups $groupID | jq -r '.LoadBalancers[].LoadBalancerArn'`

targetgrouparn=`aws elbv2 create-target-group --name my-targets --protocol HTTP --port 80 --vpc-id $vpcID | jq -r '.TargetGroups[].TargetGroupArn'`

aws elbv2 register-targets --target-group-arn $targetgrouparn --targets Id=$instanceID1 

aws elbv2 create-listener --load-balancer-arn $loadbalancerarn --protocol HTTP --port 80  --default-actions Type=forward,TargetGroupArn=$targetgrouparn

sleep 30

echo "Congratulations entire setup is done and ready"

echo "EC2 with webserver1:  http://$instanceID1"


echo "Load balancer url: "





