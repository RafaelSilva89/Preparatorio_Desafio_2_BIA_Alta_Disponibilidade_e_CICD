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
if [ "$STATUS_PORTEIRO" == "running" ]; then
  echo "Parando EC2 $INSTANCE_ID"
  aws ec2 stop-instances --instance-ids $INSTANCE_ID --profile desafios-fundamentais &> /dev/null &
  echo "Porteiro já está sendo parado..."
else
  echo "Porteiro EC2 com ID $INSTANCE_ID já está parado"
fi

