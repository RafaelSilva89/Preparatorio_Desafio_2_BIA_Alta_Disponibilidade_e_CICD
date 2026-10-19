NOME=$1
INSTANCE_ID=$(aws ec2 describe-instances \
               --filter "Name=tag:Name,Values=$NOME" \
               --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
               --output text --profile desafios-fundamentais)

#check if my instance_id is empty
if [ -z "$INSTANCE_ID" ]; then
    echo "Instancia nao encontrada"
    exit 1
fi
echo "Instancia encontrada: $INSTANCE_ID"

#create the port forwarding tunnel
aws ssm start-session --target $INSTANCE_ID \
                       --document-name AWS-StartPortForwardingSession \
                       --parameters '{"portNumber":["3001"],"localPortNumber":["3002"]}' --profile desafios-fundamentais