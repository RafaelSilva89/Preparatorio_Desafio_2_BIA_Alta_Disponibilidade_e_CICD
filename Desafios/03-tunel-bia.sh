#!/usr/bin/env bash
# Abre o tunel SSM ate a aplicacao BIA, passando pelo porteiro.
# Uso: ./03-tunel-bia.sh <nome-do-porteiro> <host-da-bia> [porta-remota] [porta-local]

NOME=$1
HOST_BIA=$2
PORTA_REMOTA=${3:-80}
PORTA_LOCAL=${4:-3002}

if [ -z "$NOME" ] || [ -z "$HOST_BIA" ]; then
    echo "Uso: $0 <nome-do-porteiro> <host-da-bia> [porta-remota] [porta-local]"
    exit 1
fi

# o host precisa ser um endereco de verdade, nao o exemplo do guia
case "$HOST_BIA" in
    *x.x*|None)
        echo "Host da BIA invalido: '$HOST_BIA' - refaca o passo 1.4"
        exit 1
        ;;
esac

# o porteiro precisa estar de pe: quem liga e o script 02
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$NOME" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId[]" \
    --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Porteiro '$NOME' nao esta rodando."
    echo "Rode antes: ./02-iniciar-porteiro-tunel-rds.sh $NOME bia"
    exit 1
fi

echo "Porteiro: $INSTANCE_ID"
echo "Tunel: localhost:$PORTA_LOCAL --> $HOST_BIA:$PORTA_REMOTA"
echo "Teste em: http://localhost:$PORTA_LOCAL/api/versao"

aws ssm start-session --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$HOST_BIA\"],\"portNumber\":[\"$PORTA_REMOTA\"],\"localPortNumber\":[\"$PORTA_LOCAL\"]}"
