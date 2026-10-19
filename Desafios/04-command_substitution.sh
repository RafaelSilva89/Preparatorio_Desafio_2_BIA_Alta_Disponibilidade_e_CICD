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