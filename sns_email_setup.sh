#!/bin/bash
# =============================================================
# Script: sns_email_setup.sh
# Descricao: Cria SNS Topic, Subscription de email e publica
#            uma mensagem de teste na regiao us-east-2 (Ohio)
# Uso: bash sns_email_setup.sh
# =============================================================

set -e  # Para execucao se qualquer comando falhar

# =============================================================
# CONFIGURACOES - Edite antes de executar
# =============================================================
EMAIL="seu@email.com"          # <- Troque pelo seu email
TOPIC_NAME="email-notifications"
REGION="us-east-2"
SUBJECT="Teste SNS - Notificacao"
MESSAGE="Olá! Esta é uma mensagem de teste enviada via Amazon SNS."

# =============================================================
# VALIDACOES
# =============================================================
if [[ "$EMAIL" == "seu@email.com" ]]; then
  echo "❌ Erro: Edite o script e troque EMAIL pelo seu email real."
  exit 1
fi

echo ""
echo "=============================================="
echo " AWS SNS - Setup de Email"
echo " Regiao : $REGION"
echo " Topic  : $TOPIC_NAME"
echo " Email  : $EMAIL"
echo "=============================================="
echo ""

# =============================================================
# PASSO 1: Criar o Topic SNS
# =============================================================
echo "📌 [1/3] Criando o Topic SNS..."

TOPIC_ARN=$(aws sns create-topic \
  --name "$TOPIC_NAME" \
  --region "$REGION" \
  --query 'TopicArn' \
  --output text)

echo "✅ Topic criado:"
echo "   $TOPIC_ARN"
echo ""

# =============================================================
# PASSO 2: Criar Subscription de Email
# =============================================================
echo "📌 [2/3] Criando subscription de email..."

SUBSCRIPTION_ARN=$(aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$EMAIL" \
  --region "$REGION" \
  --query 'SubscriptionArn' \
  --output text)

echo "✅ Subscription criada: $SUBSCRIPTION_ARN"
echo ""
echo "⚠️  ATENÇÃO: Um email de confirmação foi enviado para:"
echo "   $EMAIL"
echo "   Abra o email e clique em 'Confirm subscription' antes de continuar."
echo ""

# =============================================================
# AGUARDA confirmacao do usuario
# =============================================================
read -rp "👉 Pressione ENTER após confirmar o email para enviar a mensagem de teste..."
echo ""

# =============================================================
# PASSO 3: Publicar mensagem de teste
# =============================================================
echo "📌 [3/3] Publicando mensagem de teste..."

MESSAGE_ID=$(aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --subject "$SUBJECT" \
  --message "$MESSAGE" \
  --region "$REGION" \
  --query 'MessageId' \
  --output text)

echo "✅ Mensagem publicada com sucesso!"
echo "   MessageId: $MESSAGE_ID"
echo ""

# =============================================================
# RESUMO FINAL
# =============================================================
echo "=============================================="
echo " ✅ Setup concluído!"
echo "=============================================="
echo " Topic ARN : $TOPIC_ARN"
echo " Email     : $EMAIL"
echo " MessageId : $MESSAGE_ID"
echo ""
echo " Guarde o Topic ARN para usar na tua aplicação Java:"
echo " $TOPIC_ARN"
echo "=============================================="
