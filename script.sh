#!/usr/bin/env bash
# ============================================================
# 03 - Compilar, enviar a imagem para o Amazon ECR e rodar
# ============================================================
set -e

# ---------- PARAMETROS (ajuste se precisar) ----------
REGION="us-east-2"          # mesma regiao da sua EC2/RDS
REPO="class3"               # nome do repositorio no ECR
TAG="latest"
JVM_OPTS=""                 # ex.: "-Xms512m -Xmx1536m" (ja estao no Dockerfile)
# A senha do banco NAO fica no script. Defina antes de rodar a app:
#   export DB_PASSWORD='suaSenhaAqui'
# -----------------------------------------------------

echo "==> 1) Compilando o projeto com Maven..."
mvn clean package -DskipTests

echo "==> Conferindo o jar gerado:"
ls -1 target/*.jar | grep -v '\.original$'
# O Dockerfile espera: target/hello-0.0.1-SNAPSHOT.jar
# Se o nome for outro, ajuste a linha COPY do Dockerfile.

echo "==> 2) Descobrindo seu Account ID e montando o endereco do ECR..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}"
echo "    ECR = ${ECR}"

echo "==> 3) Criando o repositorio no ECR (ignora erro se ja existir)..."
aws ecr create-repository --repository-name "${REPO}" --region "${REGION}" \
  >/dev/null 2>&1 || echo "    (repositorio ja existe, seguindo)"

echo "==> 4) Build da imagem (forcando arquitetura amd64)..."
docker buildx build --platform linux/amd64 -t "${REPO}" --load .

echo "==> 5) Tag apontando para o ECR..."
docker tag "${REPO}:latest" "${ECR}:${TAG}"

echo "==> 6) Login no ECR..."
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${ECR}"

echo "==> 7) Push da imagem para o ECR..."
docker push "${ECR}:${TAG}"

echo ""
echo "============================================================"
echo "Imagem enviada: ${ECR}:${TAG}"
echo ""
echo "Para RODAR (aqui ou em outra EC2):"
echo "    aws ecr get-login-password --region ${REGION} \\"
echo "      | docker login --username AWS --password-stdin ${ECR}"
echo "    docker pull ${ECR}:${TAG}"
echo "    docker run -d -p 8080:8080 -e DB_PASSWORD=\"\$DB_PASSWORD\" ${ECR}:${TAG}"
echo ""
echo "Depois teste:  curl http://localhost:8080/usuarios"
echo "============================================================"
