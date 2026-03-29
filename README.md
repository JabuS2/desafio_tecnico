# W-Core — Motor de Estado em Tempo Real

Sistema de monitoramento de sensores industriais em tempo real para a Planta 42.
Construído com Elixir, Phoenix LiveView, ETS e SQLite para operação em edge computing.

## Arquitetura resumida
```
Sensores → IngestServer (GenServer) → ETS (memória) → Dashboard (LiveView)
                                          ↓
                                 WriteBehindWorker → SQLite (persistência)
```

## Pré-requisitos

- [Docker](https://www.docker.com/products/docker-desktop) instalado e rodando
- [Git](https://git-scm.com/) instalado

## Instalação e execução

### 1. Clone o repositório
```bash
git clone https://github.com/JabuS2/desafio_tecnico.git
cd desafio_tecnico
```

### 2. Configure o ambiente

Crie o arquivo `.env` na raiz do projeto:
```bash
cp .env.example .env
```

Edite o `.env` com suas configurações:
```env
PHX_HOST=localhost
PORT=4000
DATABASE_PATH=/app/data/w_core_prod.db
SECRET_KEY_BASE=SUBSTITUA_AQUI
```

Para gerar uma `SECRET_KEY_BASE` segura, você precisa do Elixir instalado:
```bash
mix phx.gen.secret
```

Ou gere uma string aleatória de 64 caracteres e cole no `.env`.

### 3. Suba o container
```bash
docker compose up --build -d
```

### 4. Crie o primeiro operador
```bash
docker compose exec w_core bin/w_core remote
```

No console interativo:
```elixir
WCore.Accounts.register_user(%{
  email: "operador@planta42.com",
  password: "suasenha123456"
})
```

Pressione `Ctrl+C` duas vezes para sair.

### 5. Acesse o sistema

Abra o browser em `http://localhost:4000` e faça login com as credenciais criadas.

---

## Simulando sensores

Com o sistema rodando, abra o console remoto e injete pulsos de sensores:
```bash
docker compose exec w_core bin/w_core remote
```
```elixir
WCore.Telemetry.IngestServer.ingest(1, "ok", %{
  temperatura: 72.5,
  pressao: 1.2,
  vibracao: 0.3,
  rpm: 1450,
  voltagem: 220.1,
  corrente: 12.4
})

WCore.Telemetry.IngestServer.ingest(2, "critical", %{
  temperatura: 98.1,
  pressao: 3.7,
  vibracao: 2.1,
  rpm: 2100,
  voltagem: 218.5,
  corrente: 18.9
})

WCore.Telemetry.IngestServer.ingest(3, "warning", %{
  temperatura: 85.0,
  pressao: 2.1,
  vibracao: 1.1,
  rpm: 1780,
  voltagem: 219.8,
  corrente: 15.2
})
```

O dashboard atualiza em tempo real sem recarregar a página.

---

## Desenvolvimento local

### Pré-requisitos

- Elixir 1.19.5+
- Erlang/OTP 28+

### Setup
```bash
# Instala dependências
mix deps.get

# Cria e migra o banco
mix ecto.setup

# Sobe o servidor
iex -S mix phx.server
```

Acesse `http://localhost:4000`.

### Testes
```bash
# Todos os testes
mix test

# Apenas telemetria (incluindo testes de concorrência)
mix test test/w_core/telemetry/
```

---

## Documentação de arquitetura

Cada etapa de desenvolvimento está documentada em `/docs/drafts/`:

| Arquivo | Conteúdo |
|---|---|
| `step-1-foundation.md` | Fundação, SQLite e autenticação |
| `step-2-otp-ets.md` | GenServers, ETS e Write-Behind |
| `step-3-liveview-ds.md` | Dashboard LiveView e Design System |
| `step-4-tests.md` | Testes de concorrência e performance |
| `step-5-infra-arch.md` | Dockerfile, Docker Compose e deploy |

---

## Stack

| Tecnologia | Versão | Uso |
|---|---|---|
| Elixir | 1.19.5 | Linguagem principal |
| Erlang/OTP | 28 | Runtime BEAM |
| Phoenix | 1.8.5 | Framework web |
| Phoenix LiveView | 1.1.28 | Interface reativa |
| SQLite (Exqlite) | 0.36.0 | Banco de dados embutido |
| Tailwind CSS | 4.1.12 | Estilização |
| Docker | — | Empacotamento para edge |