#!/bin/bash
# =============================================================
# Script: deploy_lambda_sns.sh
# Descricao: Empacota e publica a Lambda SNS completa
# Rotas: /health /actuator/health /sns/publish /sns/subscribe
#        /sns/subscribe-app /sns/sms /sns/receiver
# Uso: bash deploy_lambda_sns.sh
# =============================================================

set -e

# =============================================================
# CONFIGURACOES
# =============================================================
REGION="us-east-2"
FUNCTION_NAME="lambda-api-sns"
ROLE_NAME="lambda-sns-role"
SNS_TOPIC_ARN="arn:aws:sns:us-east-2:ACCOUNT_ID:email-notifications"  # <- Troque

# =============================================================
# VALIDACAO
# =============================================================
if [[ "$SNS_TOPIC_ARN" == *"ACCOUNT_ID"* ]]; then
  echo "❌ Erro: Troque ACCOUNT_ID pelo ID real da sua conta."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo ""
echo "=============================================="
echo " Deploy: Lambda API SNS Completa"
echo " Regiao   : $REGION"
echo " Funcao   : $FUNCTION_NAME"
echo " Account  : $ACCOUNT_ID"
echo " TopicARN : $SNS_TOPIC_ARN"
echo "=============================================="
echo ""

# =============================================================
# PASSO 1: IAM Role
# =============================================================
echo "📌 [1/5] Criando IAM Role..."

TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query 'Role.Arn' \
  --output text 2>/dev/null) || \
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess 2>/dev/null || true

echo "✅ Role: $ROLE_ARN"
echo "   Aguardando IAM propagar (10s)..."
sleep 10

# =============================================================
# PASSO 2: Empacotar
# =============================================================
echo ""
echo "📌 [2/5] Empacotando Lambda..."

cat > lambda_function.py << 'PYTHON'
import json, os, logging, boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION    = os.environ.get("AWS_REGION", "us-east-2")
TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
sns       = boto3.client("sns", region_name=REGION)

def ok(b):       return resposta(200, b)
def bad(m):      return resposta(400, {"erro": m})
def err(m):      return resposta(500, {"erro": m})

def resposta(s, c):
    return {"statusCode": s, "headers": {"Content-Type": "application/json"},
            "body": json.dumps(c, ensure_ascii=False)}

def qp(event, k):
    return (event.get("queryStringParameters") or {}).get(k, "").strip()

def health():
    return ok({"status": "UP"})

def publish(event):
    msg = qp(event, "message")
    if not msg:   return bad("Parametro 'message' obrigatorio.")
    if not TOPIC_ARN: return err("SNS_TOPIC_ARN nao configurada.")
    try:
        r = sns.publish(TopicArn=TOPIC_ARN, Message=msg, Subject="Notificacao SNS")
        return ok({"mensagem": "Publicado com sucesso.", "messageId": r["MessageId"]})
    except ClientError as e:
        return err(f"Erro SNS: {e.response['Error']['Message']}")

def subscribe_email(event):
    email = qp(event, "email")
    if not email: return bad("Parametro 'email' obrigatorio.")
    if not TOPIC_ARN: return err("SNS_TOPIC_ARN nao configurada.")
    try:
        r = sns.subscribe(TopicArn=TOPIC_ARN, Protocol="email", Endpoint=email)
        return ok({"mensagem": f"Confirmacao enviada para {email}.", "subscriptionArn": r["SubscriptionArn"]})
    except ClientError as e:
        return err(f"Erro SNS: {e.response['Error']['Message']}")

def subscribe_app(event):
    url = qp(event, "endpointUrl")
    if not url: return bad("Parametro 'endpointUrl' obrigatorio.")
    if not TOPIC_ARN: return err("SNS_TOPIC_ARN nao configurada.")
    try:
        r = sns.subscribe(TopicArn=TOPIC_ARN, Protocol="http", Endpoint=url)
        return ok({"mensagem": f"Endpoint inscrito: {url}", "subscriptionArn": r["SubscriptionArn"]})
    except ClientError as e:
        return err(f"Erro SNS: {e.response['Error']['Message']}")

def send_sms(event):
    phone = qp(event, "phoneNumber")
    msg   = qp(event, "message")
    if not phone: return bad("Parametro 'phoneNumber' obrigatorio.")
    if not msg:   return bad("Parametro 'message' obrigatorio.")
    try:
        r = sns.publish(PhoneNumber=phone, Message=msg)
        return ok({"mensagem": f"SMS enviado para {phone}.", "messageId": r["MessageId"]})
    except ClientError as e:
        return err(f"Erro SNS: {e.response['Error']['Message']}")

def receiver(event):
    try:
        body = json.loads(event.get("body", "{}"))
    except:
        return bad("Body invalido.")
    t = body.get("Type", "")
    logger.info(f"SNS Receiver Type={t}")
    if t == "SubscriptionConfirmation":
        return ok({"tipo": t, "subscribeUrl": body.get("SubscribeURL","")})
    if t == "Notification":
        return ok({"tipo": t, "messageId": body.get("MessageId",""),
                   "topicArn": body.get("TopicArn",""),
                   "message": body.get("Message",""),
                   "timestamp": body.get("Timestamp","")})
    return ok({"tipo": t or "desconhecido", "body": body})

ROUTES = {
    ("GET",  "/health"):            lambda e: health(),
    ("GET",  "/actuator/health"):   lambda e: health(),
    ("POST", "/sns/publish"):       publish,
    ("POST", "/sns/subscribe"):     subscribe_email,
    ("POST", "/sns/subscribe-app"): subscribe_app,
    ("POST", "/sns/sms"):           send_sms,
    ("POST", "/sns/receiver"):      receiver,
}

def lambda_handler(event, context):
    method = event.get("requestContext",{}).get("http",{}).get("method", event.get("httpMethod","GET")).upper()
    path   = event.get("rawPath", event.get("path", "/"))
    logger.info(f"{method} {path}")
    fn = ROUTES.get((method, path))
    if not fn:
        return resposta(404, {"erro": f"Rota nao encontrada: {method} {path}",
                              "rotas": [f"{m} {p}" for m,p in ROUTES]})
    return fn(event)
PYTHON

zip -q lambda_sns.zip lambda_function.py
echo "✅ lambda_sns.zip gerado."

# =============================================================
# PASSO 3: Criar ou Atualizar Lambda
# =============================================================
echo ""
echo "📌 [3/5] Publicando Lambda..."

EXISTS=$(aws lambda get-function --function-name "$FUNCTION_NAME" \
  --region "$REGION" --query 'Configuration.FunctionName' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "$EXISTS" == "NOT_FOUND" ]]; then
  FUNCTION_ARN=$(aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.13 \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda_sns.zip \
    --role "$ROLE_ARN" \
    --timeout 15 \
    --memory-size 128 \
    --environment "Variables={SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" \
    --region "$REGION" \
    --query 'FunctionArn' --output text)
else
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda_sns.zip \
    --region "$REGION" > /dev/null
  sleep 5
  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={SNS_TOPIC_ARN=$SNS_TOPIC_ARN}" \
    --region "$REGION" > /dev/null
  FUNCTION_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" \
    --region "$REGION" --query 'Configuration.FunctionArn' --output text)
fi
echo "✅ Lambda: $FUNCTION_ARN"

# =============================================================
# PASSO 4: Function URL
# =============================================================
echo ""
echo "📌 [4/5] Criando Function URL..."

FUNCTION_URL=$(aws lambda create-function-url-config \
  --function-name "$FUNCTION_NAME" \
  --auth-type NONE --region "$REGION" \
  --query 'FunctionUrl' --output text 2>/dev/null) || \
FUNCTION_URL=$(aws lambda get-function-url-config \
  --function-name "$FUNCTION_NAME" --region "$REGION" \
  --query 'FunctionUrl' --output text)

aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id allow-public-url \
  --action lambda:InvokeFunctionUrl \
  --principal "*" \
  --function-url-auth-type NONE \
  --region "$REGION" > /dev/null 2>&1 || true

echo "✅ Function URL: $FUNCTION_URL"

# =============================================================
# PASSO 5: Curls de Teste
# =============================================================
echo ""
echo "📌 [5/5] Gerando curls de teste..."
BASE="$FUNCTION_URL"

echo ""
echo "=============================================="
echo " ✅ Deploy concluido! Curls de teste:"
echo "=============================================="
echo ""
echo "# Health"
echo "curl -s ${BASE}health"
echo ""
echo "# Actuator"
echo "curl -s ${BASE}actuator/health"
echo ""
echo "# Publicar mensagem"
echo "curl -s -X POST \"${BASE}sns/publish\" --data-urlencode \"message=Teste de publicacao no SNS\" -G"
echo ""
echo "# Inscrever email"
echo "curl -s -X POST \"${BASE}sns/subscribe\" --data-urlencode \"email=seu@email.com\" -G"
echo ""
echo "# Inscrever endpoint HTTP"
echo "curl -s -X POST \"${BASE}sns/subscribe-app\" --data-urlencode \"endpointUrl=${BASE}sns/receiver\" -G"
echo ""
echo "# Enviar SMS"
echo "curl -s -X POST \"${BASE}sns/sms\" --data-urlencode \"phoneNumber=+5562992775804\" --data-urlencode \"message=Teste SMS\" -G"
echo ""
echo "# Simular notificacao no receiver"
echo "curl -s -X POST \"${BASE}sns/receiver\" -H \"Content-Type: application/json\" \\"
echo "  -d '{\"Type\":\"Notification\",\"MessageId\":\"sim-001\",\"TopicArn\":\"$SNS_TOPIC_ARN\",\"Message\":\"mensagem simulada\",\"Timestamp\":\"2026-06-29T00:00:00.000Z\"}'"
echo ""
echo "=============================================="

rm -f lambda_function.py lambda_sns.zip
