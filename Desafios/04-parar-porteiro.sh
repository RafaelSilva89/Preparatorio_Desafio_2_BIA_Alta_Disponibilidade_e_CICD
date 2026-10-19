#!/usr/bin/env bash
# Para a EC2 do porteiro, se ela estiver ligada.
# Uso: ./04-parar-porteiro.sh <nome-do-porteiro>

NOME=$1

if [ -z "$NOME" ]; then
    echo "Uso: $0 <nome-do-porteiro>"
    exit 1
fi

# achar em qualquer estado: parar uma maquina ja parada nao pode ser um erro
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$NOME" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId[]" \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Porteiro '$NOME' nao encontrado"
    exit 1
fi

ESTADO=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query "Reservations[].Instances[].State.Name" --output text)

if [ "$ESTADO" != "running" ]; then
    echo "Porteiro $INSTANCE_ID ja esta '$ESTADO' - nada a fazer"
    exit 0
fi

echo "Parando o porteiro $INSTANCE_ID"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" > /dev/null
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
echo "Porteiro $NOME parado"
