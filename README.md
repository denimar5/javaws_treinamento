# Job Automator

Extensão Chrome que automatiza candidaturas no LinkedIn Easy Apply e Indeed Apply, com personalização de CV via Claude API, autenticação JWT e webhook do Kiwify.

---

## Pré-requisitos

- Python 3.11+
- Docker + Docker Compose
- Conta Anthropic — API key em console.anthropic.com
- Conta Railway — railway.app (free tier disponível)
- Conta Kiwify (para webhooks de pagamento)

---

## Setup local em 5 passos

```bash
# 1. Clonar e configurar
git clone <seu-repo>
cd job-automator

# 2. Subir banco e redis
docker-compose up -d

# 3. Configurar backend
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Editar .env com suas chaves

# 4. Rodar migrations
alembic upgrade head

# 5. Iniciar API
uvicorn main:app --reload --port 8000
# API disponível em http://localhost:8000
# Docs em http://localhost:8000/docs
```

---

## Carregar extensão no Chrome

```
1. Abrir chrome://extensions
2. Ativar "Modo do desenvolvedor" (toggle superior direito)
3. Clicar "Carregar sem compactação"
4. Selecionar a pasta /extension do projeto
5. Anotar o ID gerado (ex: abcdefghijklmnop)
6. Colocar o ID no .env: CORS_ORIGINS=chrome-extension://abcdefghijklmnop
```

Após definir o ID da extensão, atualize também a constante `API_BASE_URL` nos arquivos:
- `extension/content/shared.js`
- `extension/background/service-worker.js`
- `extension/popup/popup.js`
- `extension/dashboard/dashboard.js`

---

## Testar fluxo completo

```bash
# 1. Criar usuário de teste
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"teste@teste.com","password":"senha123","name":"Teste"}'

# 2. Fazer login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"teste@teste.com","password":"senha123"}'
# Copiar o token retornado

# 3. Upload de CV
curl -X POST http://localhost:8000/api/cv/upload \
  -H "Authorization: Bearer SEU_TOKEN" \
  -F "file=@meu-curriculo.pdf"

# 4. Acessar linkedin.com/jobs e testar a extensão
```

---

## Simular webhook do Kiwify

```bash
curl -X POST http://localhost:8000/api/billing/kiwify-webhook \
  -H "Content-Type: application/json" \
  -H "X-Kiwify-Signature: teste" \
  -d '{
    "event": "order.approved",
    "customer": {
      "email": "cliente@email.com",
      "name": "João Silva"
    }
  }'
```

> Em produção, a assinatura é validada via HMAC-SHA256. No ambiente local, configure `KIWIFY_WEBHOOK_SECRET` no `.env`.

---

## Deploy no Railway

### 1. Preparar repositório

```bash
cd backend
git init && git add . && git commit -m "initial commit"
# Criar repo no GitHub e fazer push
```

### 2. Criar projeto no Railway

- Acessar railway.app → New Project
- "Deploy from GitHub repo" → selecionar seu repo

### 3. Adicionar serviços

- **PostgreSQL**: New Service → Database → PostgreSQL (injeta `DATABASE_URL` automaticamente)
- **Redis**: New Service → Database → Redis (injeta `REDIS_URL` automaticamente)

### 4. Variáveis de ambiente no Railway

```
ANTHROPIC_API_KEY=sk-ant-...
JWT_SECRET=string-aleatoria-longa
JWT_ALGORITHM=HS256
JWT_EXPIRE_DAYS=30
KIWIFY_WEBHOOK_SECRET=seu-secret
USE_S3=false
CORS_ORIGINS=chrome-extension://SEU_EXTENSION_ID
FREE_APPLICATIONS_LIMIT=10
```

### 5. Rodar migrations

```bash
railway run alembic upgrade head
```

### 6. Configurar URL pública na extensão

Railway gera: `https://seu-projeto.up.railway.app`

Substitua `https://SEU-PROJETO.railway.app` por essa URL em:
- `extension/content/shared.js`
- `extension/background/service-worker.js`
- `extension/popup/popup.js`
- `extension/dashboard/dashboard.js`

### 7. Configurar webhook no Kiwify

- Painel Kiwify → Configurações → Webhooks
- URL: `https://seu-projeto.up.railway.app/api/billing/kiwify-webhook`
- Copiar o secret gerado para `KIWIFY_WEBHOOK_SECRET`

---

## Estrutura do projeto

```
job-automator/
├── extension/                  # Chrome Extension (Manifest V3)
│   ├── manifest.json
│   ├── background/service-worker.js
│   ├── content/
│   │   ├── shared.js
│   │   ├── linkedin.js
│   │   └── indeed.js
│   ├── popup/
│   │   ├── popup.html
│   │   ├── popup.js
│   │   └── popup.css
│   ├── dashboard/
│   │   ├── dashboard.html
│   │   ├── dashboard.js
│   │   └── dashboard.css
│   └── icons/
│
├── backend/                    # FastAPI Python
│   ├── main.py
│   ├── database.py
│   ├── requirements.txt
│   ├── Procfile
│   ├── railway.toml
│   ├── alembic.ini
│   ├── routers/    (auth, cv, jobs, applications, billing)
│   ├── services/   (cv_parser, llm_service, match_service, pdf_generator, kiwify_service)
│   └── models/     (user, cv, job, application)
│
├── docker-compose.yml
└── README.md
```

---

## Variáveis de ambiente opcionais (email)

Para envio real de email de boas-vindas após compra no Kiwify:

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=seu@gmail.com
SMTP_PASS=sua-senha-de-app
SMTP_FROM=seu@gmail.com
EXTENSION_ZIP_URL=https://link-para-download.zip
TUTORIAL_URL=https://loom.com/share/...
WHATSAPP_URL=https://chat.whatsapp.com/...
```

Se não configurado, as credenciais são apenas logadas no servidor (útil no MVP local).
