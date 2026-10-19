#!/usr/bin/env bash
# Liga o porteiro (se preciso) e abre o tunel SSM ate o RDS.
# Uso: ./02-iniciar-porteiro-tunel-rds.sh <nome-do-porteiro> <id-do-rds> [porta-local]

NOME=$1
NOME_RDS=$2
PORTA_LOCAL=${3:-5433}

if [ -z "$NOME" ] || [ -z "$NOME_RDS" ]; then
    echo "Uso: $0 <nome-do-porteiro> <id-do-rds> [porta-local]"
    exit 1
fi

# 1. achar o porteiro em qualquer estado - inclusive desligado
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$NOME" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId[]" \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Porteiro '$NOME' nao encontrado"
    exit 1
fi
echo "Porteiro encontrado: $INSTANCE_ID"

# 2. ligar, se estiver parado
ESTADO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query "Reservations[].Instances[].State.Name" --output text)

if [ "$ESTADO" != "running" ]; then
    echo "Porteiro esta '$ESTADO' - ligando"
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" > /dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
fi

# 3. esperar o agente do SSM responder, no maximo 5 minutos
echo "Aguardando o agente do SSM..."
PING=""
for _ in $(seq 1 30); do
    PING=$(aws ssm describe-instance-information \
        --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
        --query "InstanceInformationList[0].PingStatus" --output text)
    [ "$PING" = "Online" ] && break
    sleep 10
done

if [ "$PING" != "Online" ]; then
    echo "O agente do SSM nao ficou Online a tempo"
    exit 1
fi
echo "SSM: Online"

# 4. descobrir o endereco do banco
ENDPOINT_RDS=$(aws rds describe-db-instances --db-instance-identifier "$NOME_RDS" \
    --query "DBInstances[0].Endpoint.Address" --output text)

if [ -z "$ENDPOINT_RDS" ] || [ "$ENDPOINT_RDS" = "None" ]; then
    echo "RDS '$NOME_RDS' nao localizado"
    exit 1
fi

echo "Endpoint do RDS: $ENDPOINT_RDS"
echo "Tunel: localhost:$PORTA_LOCAL --> $ENDPOINT_RDS:5432"
echo "Deixe este terminal aberto. Ctrl+C encerra o tunel."

# 5. abrir o encaminhamento de porta
aws ssm start-session --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$ENDPOINT_RDS\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"$PORTA_LOCAL\"]}"
