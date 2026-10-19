NOME=$1
NOME_RDS=$2
INSTANCE_ID=$(aws ec2 describe-instances \
               --filter "Name=tag:Name,Values=$NOME" \
               --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
               --output text --profile desafios-fundamentais)

if [ -z "$INSTANCE_ID" ]; then
    echo "Instancia nao localizada"
    exit 1
fi

DNS_PRIVADO_DO_RDS=$(aws rds describe-db-instances --db-instance-identifier $NOME_RDS --query 'DBInstances[0].Endpoint.Address' --output text --profile desafios-fundamentais)

if [ -z "$DNS_PRIVADO_DO_RDS" ]; then
    echo "RDS nao localizado"
    exit 1
fi

echo "DNS Privado do RDS: $DNS_PRIVADO_DO_RDS"


#create the port forwarding tunnel
aws ssm start-session --target $INSTANCE_ID \
                       --document-name AWS-StartPortForwardingSessionToRemoteHost \
                       --parameters '{"host":["'$DNS_PRIVADO_DO_RDS'"],"portNumber":["'5432'"],"localPortNumber":["'5433'"]}' --profile desafios-fundamentais                       

