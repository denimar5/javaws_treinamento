"""
Lambda Function - API SNS completa
Handler: lambda_function.lambda_handler

Rotas:
  GET  /health
  GET  /actuator/health
  POST /sns/publish?message=...
  POST /sns/subscribe?email=...
  POST /sns/subscribe-app?endpointUrl=...
  POST /sns/sms?phoneNumber=...&message=...
  POST /sns/receiver  (webhook receptor SNS)
"""

import json
import os
import logging

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION    = os.environ.get("AWS_REGION", "us-east-2")
TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")

sns = boto3.client("sns", region_name=REGION)


# =============================================================
# HELPERS
# =============================================================

def ok(body):
    return resposta(200, body)

def bad_request(msg):
    return resposta(400, {"erro": msg})

def server_error(msg):
    return resposta(500, {"erro": msg})

def resposta(status, corpo):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, ensure_ascii=False),
    }

def get_query_param(event, nome):
    params = event.get("queryStringParameters") or {}
    return params.get(nome, "").strip()


# =============================================================
# HANDLERS DE CADA ROTA
# =============================================================

def health():
    return ok({"status": "UP"})


def publish(event):
    message = get_query_param(event, "message")
    if not message:
        return bad_request("Parametro 'message' obrigatorio.")
    if not TOPIC_ARN:
        return server_error("Variavel SNS_TOPIC_ARN nao configurada.")
    try:
        resp = sns.publish(
            TopicArn=TOPIC_ARN,
            Message=message,
            Subject="Notificacao SNS",
        )
        logger.info(f"Publicado MessageId={resp['MessageId']}")
        return ok({
            "mensagem": "Publicado com sucesso.",
            "messageId": resp["MessageId"],
        })
    except ClientError as e:
        return server_error(f"Erro SNS: {e.response['Error']['Message']}")


def subscribe_email(event):
    email = get_query_param(event, "email")
    if not email:
        return bad_request("Parametro 'email' obrigatorio.")
    if not TOPIC_ARN:
        return server_error("Variavel SNS_TOPIC_ARN nao configurada.")
    try:
        resp = sns.subscribe(
            TopicArn=TOPIC_ARN,
            Protocol="email",
            Endpoint=email,
        )
        logger.info(f"Subscription email criada: {resp['SubscriptionArn']}")
        return ok({
            "mensagem": f"Confirmacao enviada para {email}. Verifique sua caixa de entrada.",
            "subscriptionArn": resp["SubscriptionArn"],
        })
    except ClientError as e:
        return server_error(f"Erro SNS: {e.response['Error']['Message']}")


def subscribe_app(event):
    endpoint_url = get_query_param(event, "endpointUrl")
    if not endpoint_url:
        return bad_request("Parametro 'endpointUrl' obrigatorio.")
    if not TOPIC_ARN:
        return server_error("Variavel SNS_TOPIC_ARN nao configurada.")
    try:
        resp = sns.subscribe(
            TopicArn=TOPIC_ARN,
            Protocol="http",
            Endpoint=endpoint_url,
        )
        logger.info(f"Subscription HTTP criada: {resp['SubscriptionArn']}")
        return ok({
            "mensagem": f"Endpoint HTTP inscrito: {endpoint_url}",
            "subscriptionArn": resp["SubscriptionArn"],
        })
    except ClientError as e:
        return server_error(f"Erro SNS: {e.response['Error']['Message']}")


def send_sms(event):
    phone   = get_query_param(event, "phoneNumber")
    message = get_query_param(event, "message")
    if not phone:
        return bad_request("Parametro 'phoneNumber' obrigatorio.")
    if not message:
        return bad_request("Parametro 'message' obrigatorio.")
    try:
        resp = sns.publish(
            PhoneNumber=phone,
            Message=message,
        )
        logger.info(f"SMS enviado para {phone}, MessageId={resp['MessageId']}")
        return ok({
            "mensagem": f"SMS enviado para {phone}.",
            "messageId": resp["MessageId"],
        })
    except ClientError as e:
        return server_error(f"Erro SNS: {e.response['Error']['Message']}")


def receiver(event):
    body_raw = event.get("body", "{}")
    try:
        body = json.loads(body_raw) if isinstance(body_raw, str) else body_raw
    except json.JSONDecodeError:
        return bad_request("Body invalido.")

    msg_type = body.get("Type", "")
    logger.info(f"SNS Receiver - Type={msg_type}")

    if msg_type == "SubscriptionConfirmation":
        subscribe_url = body.get("SubscribeURL", "")
        return ok({
            "tipo": "SubscriptionConfirmation",
            "mensagem": "Confirmacao recebida. Acesse SubscribeURL para confirmar.",
            "subscribeUrl": subscribe_url,
        })

    if msg_type == "Notification":
        return ok({
            "tipo": "Notification",
            "messageId": body.get("MessageId", ""),
            "topicArn":  body.get("TopicArn", ""),
            "message":   body.get("Message", ""),
            "timestamp": body.get("Timestamp", ""),
        })

    return ok({"tipo": msg_type or "desconhecido", "body": body})


# =============================================================
# ROUTER
# =============================================================

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
    method = (event.get("requestContext", {})
                   .get("http", {})
                   .get("method", event.get("httpMethod", "GET"))
                   .upper())
    path = event.get("rawPath", event.get("path", "/"))

    logger.info(f"Requisicao: {method} {path}")

    handler_fn = ROUTES.get((method, path))
    if handler_fn is None:
        return resposta(404, {
            "erro": f"Rota nao encontrada: {method} {path}",
            "rotas_disponiveis": [f"{m} {p}" for m, p in ROUTES],
        })

    return handler_fn(event)
