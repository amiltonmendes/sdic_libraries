# Guia de Instalação - SDIC Libraries

Este guia contém instruções completas para instalar e configurar a biblioteca SDIC para Python e R.

## 📋 Pré-requisitos

### Python
- Python 3.8 ou superior
- pip (gerenciador de pacotes Python)
- Conexão com a internet

### R
- R 4.0 ou superior
- pacote `devtools` (para instalação via GitHub)
- Conexão com a internet

## 🚀 Instalação Rápida (Recomendada)

### Método 1: Instalação Local

```bash
# 1. Clone ou baixe o repositório
git clone https://github.com/<SEU_USUARIO>/sdic_libraries.git
cd sdic_libraries

# 2. Python - Instalação automática
cd python
python install.py

# 3. R - Instalação automática  
cd ../r
Rscript install.R
```

### Método 2: Instalação via GitHub

**Python:**
```bash
pip install git+https://github.com/<SEU_USUARIO>/sdic_libraries.git#subdirectory=python
```

**R:**
```r
devtools::install_github("<SEU_USUARIO>/sdic_libraries", subdir="r")
```

## 🔧 Instalação Manual

### Python (Passo a Passo)

```bash
# 1. Navegar para pasta Python
cd sdic_libraries/python

# 2. Instalar dependências
pip install -r requirements.txt

# 3. Instalar biblioteca em modo desenvolvimento
pip install -e .

# 4. Testar instalação
python -c "from sdic_libraries.dados.emprego import Emprego; print('✅ Instalação bem-sucedida!')"
```

### R (Passo a Passo)

```r
# 1. Instalar dependências
install.packages(c(
    "R6", "httr2", "jsonlite", "dplyr", 
    "tibble", "lubridate", "cli", "rlang"
))

# 2. Carregar biblioteca local
source("sdic_libraries/r/R/emprego.R")
source("sdic_libraries/r/R/utils/transformacoes.R")

# 3. Testar instalação
api <- Emprego$new()
cat("✅ Instalação bem-sucedida!\n")
```

## ✅ Verificação da Instalação

### Teste Rápido - Python

```python
from sdic_libraries.dados.emprego import get_saldo_emprego_nacional_mensal
from sdic_libraries.utils.transformacoes import criar_indice

# Teste de conectividade
try:
    dados = get_saldo_emprego_nacional_mensal(
        nivel_cnae='divisao',
        codigo_cnae='10',
        data_minima='2024-01-01'
    )
    print(f"✅ Sucesso! {len(dados)} registros obtidos")
except Exception as e:
    print(f"❌ Erro: {e}")

# Teste de utilitários
import pandas as pd
df_teste = pd.DataFrame({
    'ano': [2020, 2021, 2022],
    'valor': [100, 110, 120]
})

indices = criar_indice(df_teste, ano_base=2020, coluna_data='ano', colunas_valores=['valor'])
print(f"✅ Funções de transformação funcionais")
```

### Teste Rápido - R

```r
# Carregar bibliotecas
source("sdic_libraries/r/R/emprego.R")
source("sdic_libraries/r/R/utils/transformacoes.R")

# Teste de conectividade
api <- Emprego$new()
tryCatch({
    dados <- api$get_saldo_emprego_detalhado("nacional", 2, "10", "2024-01-01")
    cat("✅ Sucesso!", nrow(dados), "registros obtidos\n")
}, error = function(e) {
    cat("❌ Erro:", e$message, "\n")
})

# Teste de utilitários
df_teste <- data.frame(
    ano = c(2020, 2021, 2022),
    valor = c(100, 110, 120)
)

indices <- criar_indice(df_teste, 2020, 'ano', 'valor')
cat("✅ Funções de transformação funcionais\n")
```

### Teste Completo

Execute os testes consolidados para validação completa:

**Python:**
```bash
cd sdic_libraries/python
python testes_consolidados.py
```

**R:**
```bash
cd sdic_libraries/r
Rscript testes_consolidados.R
```

## 🌍 Configuração de Ambiente

> ℹ️ **Funciona out-of-the-box:** o endpoint público (DNS próprio) já vem embutido e também
> no `.env` versionado da raiz — não é preciso configurar nada para começar. Para sobrescrever,
> defina `EMPLOYMENT_API_BASE_URL` (env do SO, `.env` ou `/etc/sdic/.env`).
>
> 🔒 **Segredos nunca no repositório:** o `.env` versionado guarda só a URL pública. Se a API
> exigir `EMPLOYMENT_API_KEY`, coloque-a em **`.env.local`** (ignorado pelo git) ou como
> *secret* do pipeline em CI/CD — nunca em arquivos versionados.

### Variáveis de Ambiente

Crie um arquivo `.env` na pasta do projeto (modelo em `.env.example`):

```bash
# .env
SDIC_API_URL=https://api.sua-instancia.com
SDIC_API_KEY=sua_chave_opcinal
SDIC_TIMEOUT=30
SDIC_VERSION=1.0.0
```

### Python - Configuração Personalizada

```python
from sdic_libraries.dados.emprego import Emprego
import os

# Opção 1: Através de parâmetros
api = Emprego(
    base_url="https://api-customizada.com",
    timeout=60,
    api_key="minha_chave"
)

# Opção 2: Através de variáveis de ambiente
os.environ['SDIC_API_URL'] = 'https://api-customizada.com'
os.environ['SDIC_TIMEOUT'] = '60'
api = Emprego()  # Lê automaticamente as variáveis
```

### R - Configuração Personalizada

```r
# Opção 1: Através de parâmetros
api <- Emprego$new(
    base_url = "https://api-customizada.com",
    timeout = 60,
    api_key = "minha_chave"
)

# Opção 2: Através de variáveis de ambiente
Sys.setenv(SDIC_API_URL = "https://api-customizada.com")
Sys.setenv(SDIC_TIMEOUT = "60")
api <- Emprego$new()  # Lê automaticamente as variáveis
```

## 🐛 Solução de Problemas

### Problemas Comuns

#### ❌ "Module not found" (Python)
```bash
# Solução 1: Reinstalar
pip uninstall sdic-libraries  # Se instalado via pip
pip install -e .

# Solução 2: Verificar PATH
python -c "import sys; print(sys.path)"

# Solução 3: Instalar dependências
pip install -r requirements.txt
```

#### ❌ "Object not found" (R)
```r
# Solução 1: Verificar se devtools está instalado
install.packages("devtools")

# Solução 2: Carregar diretamente
source("sdic_libraries/r/R/emprego.R")

# Solução 3: Instalar dependências
install.packages(c("R6", "httr2", "jsonlite", "dplyr"))
```

#### ❌ Erro de Conexão
```bash
# Verificar conectividade
curl -I https://api.emprego.gov.br/health

# Ou teste básico
ping google.com
```

#### ❌ Erro de Permissão
```bash
# Linux/Mac - dar permissões
chmod +x install.py
chmod +x install.R

# Windows - executar como administrador
# Abrir terminal como administrator
```

### Logs de Debug

#### Python
```python
import logging
logging.basicConfig(level=logging.DEBUG)

from sdic_libraries.dados.emprego import Emprego
api = Emprego(debug=True)
```

#### R
```r
api <- Emprego$new(verbose = TRUE)
```

## 🆗 Desinstalação

### Python
```bash
# Se instalado via pip
pip uninstall sdic-libraries

# Se instalado em modo desenvolvimento
cd python/
pip uninstall -e .
```

### R
```r
# Remover referências
rm(api)
detach(package:sdic.libraries)

# Limpar workspace
rm(list=ls())
```

## 🔄 Atualização

### Python
```bash
# Atualizar via GitHub
pip install --upgrade git+https://github.com/<SEU_USUARIO>/sdic_libraries.git#subdirectory=python

# Ou atualizar local
cd python/
git pull
pip install -e . --force-reinstall
```

### R
```r
# Atualizar via GitHub
devtools::install_github("<SEU_USUARIO>/sdic_libraries", subdir="r", force=TRUE)

# Ou atualizar local
# git pull no terminal, depois
source("r/install.R")
```

## 📚 Referência Completa

### Dependências Python
- `requests>=2.28.0` - Requisições HTTP
- `pandas>=1.5.0` - Manipulação de dados
- `numpy>=1.24.0` - Computação numérica  
- `python-dotenv>=1.0.0` - Variáveis de ambiente

### Dependências R
- `R6>=2.5.0` - Sistema de classes
- `httr2>=1.0.0` - Cliente HTTP
- `jsonlite>=1.8.0` - Parsing JSON
- `dplyr>=1.1.0` - Manipulação de dados
- `tibble`, `lubridate`, `cli`, `rlang`

---

**💡 Dica**: Para usar em produção, sempre teste a instalação completamente antes do deployment usando os testes consolidados fornecidos com a biblioteca.