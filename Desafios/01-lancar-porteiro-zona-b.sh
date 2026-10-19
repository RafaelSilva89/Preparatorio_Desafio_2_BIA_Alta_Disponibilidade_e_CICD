#!/usr/bin/env bash
# Lanca a EC2 "porteiro" na subnet default da zona informada.
# Uso: ./01-lancar-porteiro-zona-b.sh <nome> [zona] [tipo]
# O profile vem do ambiente (export AWS_PROFILE), nao do codigo.

NOME=$1
ZONA=${2:-us-east-1b}
TIPO=${3:-t3.micro}
PERFIL_SSM=role-acesso-ssm
SG_NOME=bia-porteiro

if [ -z "$NOME" ]; then
    echo "Uso: $0 <nome-do-porteiro> [zona] [tipo]"
    exit 1
fi

# 1. ja existe uma instancia com esse nome? entao nao lance outra.
EXISTENTE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$NOME" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[].Instances[].InstanceId[]" \
    --output text)

if [ -n "$EXISTENTE" ]; then
    echo "Porteiro ja existe: $EXISTENTE - nada a fazer"
    exit 0
fi

# 2. a subnet default da zona pedida
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=default-for-az,Values=true" "Name=availability-zone,Values=$ZONA" \
    --query "Subnets[0].SubnetId" --output text)

if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "None" ]; then
    echo "Subnet default da zona $ZONA nao encontrada"
    exit 1
fi

VPC_ID=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" \
    --query "Subnets[0].VpcId" --output text)

# 3. a AMI mais recente do Amazon Linux 2023, direto do parametro publico
AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query "Parameters[0].Value" --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    echo "AMI do Amazon Linux 2023 nao encontrada"
    exit 1
fi

# 4. o security group do porteiro: criado sem regra de entrada, de proposito
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NOME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" --output text)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    echo "Criando o security group $SG_NOME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NOME" \
        --description "EC2 porteiro - entrada apenas por SSM" \
        --vpc-id "$VPC_ID" \
        --query "GroupId" --output text)

    if [ -z "$SG_ID" ]; then
        echo "Falha ao criar o security group $SG_NOME"
        exit 1
    fi
fi

echo "Zona:   $ZONA"
echo "Subnet: $SUBNET_ID (VPC $VPC_ID)"
echo "AMI:    $AMI_ID"
echo "SG:     $SG_ID"

# 5. lancar a instancia
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$TIPO" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name=$PERFIL_SSM \
    --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NOME}]" \
    --query "Instances[0].InstanceId" --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "Falha ao lancar a instancia"
    exit 1
fi

echo "Porteiro lancado: $INSTANCE_ID"
echo "Aguardando o estado running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "Pronto: $NOME esta running na zona $ZONA"
