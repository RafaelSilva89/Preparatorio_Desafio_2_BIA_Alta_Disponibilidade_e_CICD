NOME=$1
INSTANCE_ID=$(aws ec2 describe-instances \
               --filter "Name=tag:Name,Values=$NOME" \
               --query "Reservations[].Instances[].InstanceId[]" \
               --output text --profile desafios-fundamentais)

#check if my instance_id is empty
if [ -z "$INSTANCE_ID" ]; then
    echo "Instancia nao encontrada"
    exit 1
fi
echo "Instancia encontrada: $INSTANCE_ID"


STATUS_PORTEIRO=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --profile desafios-fundamentais --query "Reservations[].Instances[].State.Name" --output text | grep running)

if [ "$STATUS_PORTEIRO" != "running" ]; then
  echo "Iniciando EC2 $INSTANCE_ID"
  aws ec2 start-instances --instance-ids $INSTANCE_ID --profile desafios-fundamentais &> /dev/null &
  echo "Aguardando 30 segundos para porteiro ficar pronto"
  sleep 30
fi

aws ssm start-session --target $INSTANCE_ID \
                       --document-name AWS-StartPortForwardingSession \
                       --parameters '{"portNumber":["3001"],"localPortNumber":["3002"]}' --profile desafios-fundamentais
