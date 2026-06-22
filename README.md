# Biblioteca SDIC - Dados de Emprego

Biblioteca unificada para acessar dados de saldo e estoque de emprego brasileiro com suporte completo para Python e R.

## 🚀 Instalação Rápida

### Python

```bash
# Instalação local (recomendada para desenvolvimento)
cd sdic_libraries/python
pip install -e .

# Ou instalação direta
pip install git+https://github.com/<SEU_USUARIO>/sdic_libraries.git#subplot=python
```

### R

```r
# Instalação via source local
source("sdic_libraries/r/install.R")

# Ou instalação via GitHub
devtools::install_github("<SEU_USUARIO>/sdic_libraries", subdir="r")
```

## 🛠️ Uso Básico

### Python

```python
from sdic_libraries.data_access.emprego import (
    get_saldo_emprego_nacional_mensal,
  get_estoque_emprego_nacional
)
from sdic_libraries.utils.transformacoes import criar_indice

# Obter dados de saldo mensal
dados_saldo = get_saldo_emprego_nacional_mensal(
    nivel_cnae='divisao',
    codigo_cnae='10',  # Indústria alimentícia
    data_minima='2023-01-01'
)

# Obter dados de estoque
dados_estoque = get_estoque_emprego_nacional(
  codigos_cnae=['10'],
  nivel_cnae=2,
  agregado=True
)

# Filtro de ano (manual)
dados_estoque = dados_estoque[dados_estoque['ano'].astype(int) >= 2023]

# Criar índices temporais
indices = criar_indice(
    df=dados_estoque,
    ano_base=2020,
    coluna_data='ano',
    colunas_valores=['estoque_emprego', 'admissoes']
)
```

### R

```r
# Carregar biblioteca
source("sdic_libraries/r/R/data_access/emprego.R")
source("sdic_libraries/r/R/utils/transformacoes.R")

# Obter dados de saldo
api <- Emprego$new()
dados_saldo <- api$get_saldo_emprego_detalhado(
  nivel_agregacao = "nacional",
  nivel_cnae = 2,
  codigo_cnae = "10",
  data_minima = "2023-01-01"
)

# Criar índices temporais
dados_com_indice <- criar_indice(
  df = dados_saldo,
  ano_base = 2020,
  coluna_data = 'ano',
  colunas_valores = c('saldo_emprego', 'admissoes')
)
```

## 📊 Funcionalidades Principais

### Dados de Saldo de Emprego
- ✅ **Nacional, Estadual e Municipal**
- ✅ **Mensal e Anual**  
- ✅ **Por códigos CNAE** (divisão, grupo, subclasse)
- ✅ **Agrupamentos temáticos** (agropecuária, tecnologia, etc.)

### Dados de Estoque de Emprego
- ✅ **Nacional e Estadual**
- ✅ **Anuais com séries históricas**
- ✅ **Estimativas municipais**
- ✅ **Agrupamentos por intensidade tecnológica**

### Utilitários
- ✅ **Criação de índices temporais** (base = 100)
- ✅ **Filtragem por agregação**
- ✅ **Validação de códigos CNAE**
- ✅ **Tratamento amigável de erros**

## 🧪 Testes

Execute os testes consolidados para validar a instalação:

### Python
```bash
python sdic_libraries/python/testes_consolidados.py --modo rapido
```

### R
```r
source("sdic_libraries/r/testes_consolidados.R")
```

### Resultados Esperados
- ✅ **Função criar_indice**: 100% dos testes aprovados
- ✅ **API de Emprego**: Conectividade básica funcional
- ✅ **Demonstrações**: Exemplos práticos executados

## ⚙️ Configuração necessária

> ⚠️ **Importante:** por segurança, a URL da API **não vem mais embutida** na biblioteca.
> Antes do primeiro uso, defina o endpoint da API. Sem isso, a biblioteca usa apenas um
> placeholder (`https://api.example.com`) e não acessará dados reais.

Variáveis reconhecidas:

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `EMPLOYMENT_API_BASE_URL` | **Sim** | Endpoint base da API de emprego (ex.: a URL do seu serviço). |
| `EMPLOYMENT_API_KEY` | Não | Token de autenticação, se a API exigir. |
| `API_TIMEOUT` | Não | Timeout das requisições em segundos (padrão 30). |

**Via arquivo `.env`** (copie de `.env.example` e renomeie para `.env`):

```bash
EMPLOYMENT_API_BASE_URL=https://sua-api.example.com
EMPLOYMENT_API_KEY=sua_chave_opcional
```

**Via variável de ambiente:**

```bash
# Python / shell
export EMPLOYMENT_API_BASE_URL="https://sua-api.example.com"
```

```r
# R
Sys.setenv(EMPLOYMENT_API_BASE_URL = "https://sua-api.example.com")
```

Em CI/CD, defina `EMPLOYMENT_API_BASE_URL` (e `EMPLOYMENT_API_KEY` se aplicável) como
*secret*/variável do pipeline — nunca commite a URL real no repositório.

## ⚙️ Configuração Avançada

### Variáveis de Ambiente

Crie um arquivo `.env` para configuração personalizada:

```bash
# .env
SDIC_API_URL=https://sua-api-customizada.com
SDIC_API_KEY=sua_chave_opcional
SDIC_TIMEOUT=30
SDIC_VERSION=1.0.0
```

### Python - Configuração Manual

```python
from sdic_libraries.data_access.emprego import Emprego

# Configuração customizada
api = Emprego(
    base_url="https://api-alternativa.com",
    timeout=60,
    api_key="sua_chave"
)
```

### R - Configuração Manual

```r
# Configuração customizada
api <- Emprego$new(
  base_url = "https://api-alternativa.com",
  timeout = 60,
  api_key = "sua_chave"
)
```

## 📈 Exemplos Avançados

### Análise Temporal com Índices

```python
import pandas as pd
from sdic_libraries.utils.transformacoes import criar_indice

# Dados históricos de emprego
dados_historicos = get_estoque_emprego_nacional(
  codigos_cnae=['101'],  # Frigoríficos
  nivel_cnae=3,
  agregado=True
)

dados_historicos = dados_historicos[dados_historicos['ano'].astype(int) >= 2019]

# Criar índice com base em 2019
indice_emprego = criar_indice(
    df=dados_historicos,
    ano_base=2019,
    coluna_data='ano',
    colunas_valores=['estoque_emprego']
)

# Análise de crescimento
crescimento_2023 = indice_emprego.loc[
    indice_emprego['ano'] == 2023, 'estoque_emprego_indice'
].iloc[0]

print(f"Crescimento do emprego 2019-2023: {crescimento_2023-100:.1f}%")
```

### Comparação Regional

```python
# Dados de múltiplos estados
estados = ['SP', 'RJ', 'MG', 'RS']
dados_regionais = []

for uf in estados:
    dados = get_saldo_emprego_estadual_mensal(
        sigla_uf=uf,
        nivel_cnae='divisao',
        codigo_cnae='10',
        data_minima='2023-01-01'
    )
    dados['uf'] = uf
    dados_regionais.append(dados)

# Consolidar dados regionais
dados_consolidados = pd.concat(dados_regionais, ignore_index=True)
```

## 🔧 Solução de Problemas

### Erro de Conectividade
- ✅ Verifique sua conexão com a internet
- ✅ Execute os testes consolidados para diagnóstico
- ✅ Verifique se a API está online

### Erro de Importação
- ✅ Confirme que a instalação foi feita corretamente
- ✅ Verifique se todas as dependências foram instaladas
- ✅ Para Python: `pip install -r requirements.txt`
- ✅ Para R: `install.packages(c("httr2", "R6", "dplyr", "cli"))`

### Dados Vazios
- ✅ Verifique se os códigos CNAE estão corretos
- ✅ Confirme se o período solicitado tem dados disponíveis
- ✅ Use períodos mais amplos para teste

## 📞 Suporte

- 📧 **Problemas**: Abra uma issue no GitHub
- 📚 **Documentação**: Execute os testes consolidados para exemplos
- 🔧 **Desenvolvimento**: Leia `INSTALL_ADVANCED.md` para setup completo

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

**Versão**: 1.0  
**Última atualização**: Abril 2026  
**Compatibilidade**: Python 3.8+ | R 4.0+
    sigla_uf='SP', 
    codigo_cnae='29',  # UM código apenas
    nivel_cnae='divisao'
)

# 🏙️ Dados municipais (São Paulo capital - código IBGE: 355030)  
df_sp_capital = get_saldo_emprego_municipal_mensal(
    sigla_uf='SP', 
    municipio=355030,
    codigo_cnae='62'  # UM código apenas
)

# 💻 Grupo de CNAEs de TI por estado (CORRETO para múltiplos)
df_ti_sp = get_saldo_emprego_estadual_mensal_agrupado(
    sigla_uf="SP",
    nome_grupo="Tecnologia da Informação", 
    lista_cnae=["62", "63"]  # Múltiplos CNAEs
)
```

#### R
```r
library(sdic.libraries)

# 📊 Dados nacionais mensais por nível CNAE
df_nacional <- get_saldo_emprego_nacional_mensal(
  nivel_cnae = 'divisao',  # ou 'subclasse', 'grupo'
  data_minima = '2024-01-01'
)

# 📈 Dados anuais agregados automaticamente
df_anual <- get_saldo_emprego_nacional_anual(
  nivel_cnae = 'divisao',
  ano_minimo = 2023
)

# 🏭 Dados agrupados para múltiplos CNAEs (sem códigos específicos)
cnae_industria <- c("10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
                    "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", 
                    "30", "31", "32", "33")
df_industria <- get_saldo_emprego_nacional_mensal_agrupado(
  nome_grupo = "Indústria de Transformação",
  lista_cnae = cnae_industria,
  data_minima = "2024-01-01"
)

# 🗺️ Dados estaduais com um CNAE específico
df_sp <- get_saldo_emprego_estadual_mensal(
  sigla_uf = 'SP', 
  codigo_cnae = '29',  # UM código apenas
  nivel_cnae = 'divisao'
)

# 🏙️ Dados municipais (São Paulo capital - código IBGE: 355030)  
df_sp_capital <- get_saldo_emprego_municipal_mensal(
  sigla_uf = 'SP', 
  municipio = 355030,
  codigo_cnae = '62'  # UM código apenas
)

# 💻 Grupo de CNAEs de TI por estado (CORRETO para múltiplos)
df_ti_sp <- get_saldo_emprego_estadual_mensal_agrupado(
  sigla_uf = "SP",
  nome_grupo = "Tecnologia da Informação",
  lista_cnae = c("62", "63")  # Múltiplos CNAEs
)
```

### ⚡ **Características da Nova API**

### 📦 **Funções de Estoque de Emprego**

#### Python
```python
from sdic_libraries.data_access.emprego import (
    # Estoque nacional
  get_estoque_emprego_nacional,
  get_estoque_emprego_nacional_agrupado,
    # Estoque estadual
  get_estoque_emprego_estadual,
  get_estoque_emprego_estadual_agrupado,
)

# 📦 Estoque nacional anual por divisão CNAE
df_estoque = get_estoque_emprego_nacional(
  nivel_cnae=2,
  agregado=True
)
df_estoque = df_estoque[df_estoque['ano'].astype(int) >= 2019]
# Colunas: ano, codigo_divisao, descricao_divisao, secao, descricao_secao, estoque

# 📦 Estoque estadual anual para SP por grupo CNAE
df_estoque_sp = get_estoque_emprego_estadual(
  uf='SP',
  nivel_cnae=3
)
df_estoque_sp = df_estoque_sp[df_estoque_sp['ano'].astype(int) >= 2020]
# Colunas: ano, sigla_uf, uf, codigo_grupo, descricao_grupo, secao, descricao_secao, estoque

# 📦 Estoque agrupado nacional (consolidado por lista de CNAEs)
df_estoque_ti = get_estoque_emprego_nacional_agrupado(
    nome_grupo="Tecnologia da Informação",
  lista_cnae=["620", "631"]
)
df_estoque_ti = df_estoque_ti[df_estoque_ti['ano'].astype(int) >= 2020]
# Colunas: ano, nome_grupo, estoque

# 📦 Estoque agrupado estadual
df_estoque_fin_rj = get_estoque_emprego_estadual_agrupado(
  uf='RJ',
    nome_grupo="Financeiro",
  lista_cnae=["641", "642"]
)
df_estoque_fin_rj = df_estoque_fin_rj[df_estoque_fin_rj['ano'].astype(int) >= 2020]
# Colunas: ano, sigla_uf, uf, nome_grupo, estoque
```

#### R
```r
library(sdic.libraries)

# 📦 Estoque nacional anual por divisão CNAE
df_estoque <- get_estoque_emprego_nacional(
  nivel_cnae = 2,
  agregado = TRUE
)
df_estoque <- dplyr::filter(df_estoque, as.integer(ano) >= 2019)

# 📦 Estoque estadual anual para SP por grupo CNAE
df_estoque_sp <- get_estoque_emprego_estadual(
  sigla_uf = 'SP',
  nivel_cnae = 3
)
df_estoque_sp <- dplyr::filter(df_estoque_sp, as.integer(ano) >= 2020)

# 📦 Estoque agrupado nacional (consolidado por lista de CNAEs)
df_estoque_ti <- get_estoque_emprego_nacional_agrupado(
  nome_grupo = "Tecnologia da Informação",
  lista_cnae = c("620", "631")
)
df_estoque_ti <- dplyr::filter(df_estoque_ti, as.integer(ano) >= 2020)

# 📦 Estoque agrupado estadual
df_estoque_fin_rj <- get_estoque_emprego_estadual_agrupado(
  sigla_uf = 'RJ',
  nome_grupo = "Financeiro",
  lista_cnae = c("641", "642")
)
df_estoque_fin_rj <- dplyr::filter(df_estoque_fin_rj, as.integer(ano) >= 2020)
```

### ⚡ **Características da Nova API**

✅ **Filtros inteligentes geográficos**: Remove automaticamente colunas de UF/município por nível  
✅ **Filtros inteligentes de CNAE**: Remove colunas de subclasse/grupo/divisão por nível  
✅ **Funções de estoque**: Dados de estoque de emprego nacional e estadual por ano  
✅ **Códigos CNAE hierárquicos**: Inclui códigos de nível superior automaticamente  
✅ **Validações robustas**: Valida códigos CNAE e detecta nível automaticamente  
✅ **Métodos agrupados limpos**: Sem códigos CNAE específicos em dados consolidados  
✅ **Paginação abstraída**: Sempre retorna todos os dados sem se preocupar com páginas  

### 🔍 **Diferenças Importantes entre Funções**

**📊 Funções Individuais** (`*_mensal`, `*_anual`):  
- Aceitam **um** código CNAE por vez  
- Parâmetro: `codigo_cnae='29'`  
- Retornam dados detalhados por CNAE específico  

**🏭 Funções Agrupadas** (`*_mensal_agrupado`):  
- Aceitam **múltiplos** códigos CNAE  
- Parâmetros: `nome_grupo='Setor X'` + `lista_cnae=['29', '30']`  
- Retornam dados consolidados sem códigos específicos  

### 🔧 **API de Baixo Nível (Avançada)**

#### Python
```python
from sdic_libraries.data_access.emprego import Emprego

# Context manager (recomendado)  
with Emprego() as api:
    # Obter dados estaduais para São Paulo
    sp_data = api.get_saldo_emprego_detalhado(
        nivel_agregacao="estadual",
    sigla_uf="SP"
    )
    
    # Obter como DataFrame
    df = api.get_saldo_emprego_as_dataframe(
        nivel_agregacao="municipal",
      sigla_uf="RJ",
        codigo_cnae="62"  # Setor de TI
    )
    
    # Dados para múltiplos CNAEs
    tech_data = api.get_saldo_emprego_detalhado_lista_cnae(
        lista_cnae=["62", "63"],
        nome_grupo="Tecnologia da Informação",
        nivel_agregacao="estadual",
        sigla_uf="SP",
        nivel_cnae=2
    )

# Funções de conveniência (baixo nível)
from sdic_libraries.data_access.emprego import (
    get_saldo_emprego_as_dataframe,
    get_saldo_emprego_detalhado_lista_cnae  
)
```

#### R
```r
library(sdic.libraries)

# Context manager através de objeto
api <- Emprego$new()

# Obter dados estaduais para São Paulo 
sp_data <- api$get_saldo_emprego_detalhado(
  nivel_agregacao = "estadual",
  sigla_uf = "SP"
)

# Obter como tibble
mg_tibble <- api$get_saldo_emprego_as_tibble(
  nivel_agregacao = "municipal", 
  sigla_uf = "RJ",
  codigo_cnae = "62"  # Setor de TI
)

# Dados para múltiplos CNAEs
tech_data <- api$get_saldo_emprego_detalhado_lista_cnae(
  lista_cnae = c("62", "63"),
  nome_grupo = "Tecnologia da Informação",
  nivel_agregacao = "estadual",
  sigla_uf = "SP",
  nivel_cnae = 2
)

# Funções de conveniência (baixo nível)
df <- get_saldo_emprego_as_tibble("nacional")
tech_tibble <- get_saldo_emprego_lista_cnae_as_tibble(
  lista_cnae = c("62", "63"),
  nome_grupo = "TI",
  nivel_agregacao = "nacional"
)
```

Observação: a biblioteca consolida internamente a paginação da API. Não é necessário (nem suportado) informar `pagina` ou `tamanho_pagina` na interface pública.

## Parâmetros da API

### `get_saldo_emprego_detalhado()`

**✅ SEMPRE RETORNA TODOS OS DADOS automaticamente (paginação interna)**

- **`nivel_agregacao`** (obrigatório): `'nacional'`, `'estadual'`, ou `'municipal'`
- **`sigla_uf`** (opcional): Código do estado (ex.: 'SP', 'RJ')
- **`uf`** (opcional): Alias legado para `sigla_uf`
- **`municipio`** (opcional): Código IBGE do município
- **`codigo_cnae`** (opcional): Código CNAE da atividade econômica
- **`nivel_cnae`** (opcional): Nível CNAE (2=divisão, 3=grupo, None=subclasse)
- **`data_minima`** (opcional): Data mínima no formato YYYY-MM-DD

### `get_saldo_emprego_detalhado_lista_cnae()` ✨ **NOVO**

Permite consultar dados de emprego para múltiplos códigos CNAE simultaneamente, agrupados por categoria.

- **`lista_cnae`** (obrigatório): Lista de códigos CNAE (ex.: `["62", "63"]` em Python, `c("62", "63")` em R)
- **`nome_grupo`** (obrigatório): Nome do grupo/categoria (ex.: "Tecnologia da Informação")
- **`nivel_agregacao`** (obrigatório): `'nacional'`, `'estadual'`, ou `'municipal'`
- **`sigla_uf`** (opcional): Código do estado (ex.: 'SP', 'RJ')
- **`municipio`** (opcional): Código IBGE do município
- **`nivel_cnae`** (opcional): Nível CNAE (2=divisão, 3=grupo, None=subclasse)
- **`data_minima`** (opcional): Data mínima no formato YYYY-MM-DD

**Exemplos de Uso:**

Python:
```python
# Obter dados de emprego para setor de TI em SP
it_data = get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae=["62", "63"],
    nome_grupo="Tecnologia da Informação", 
    nivel_agregacao="estadual",
    sigla_uf="SP",
    nivel_cnae=2
)
```

R:
```r
# Obter dados de emprego para alimentos e bebidas em MG
food_data <- get_saldo_emprego_detalhado_lista_cnae(
  lista_cnae = c("10", "11", "12"),
  nome_grupo = "Alimentos e Bebidas",
  nivel_agregacao = "municipal", 
  sigla_uf = "MG"
)
```

## Executando os Testes

### `get_estoque_emprego_nacional()`

Retorna o estoque de emprego nacional por ano, filtrado por nível CNAE.

- **`nivel_cnae`** (obrigatório): `2` (divisão) ou `3` (grupo)
- **`codigos_cnae`** (opcional): Lista de códigos CNAE para filtrar
- **`agregado`** (opcional): Se `TRUE`, retorna agregado nacional
- **Filtro de ano**: aplicar manualmente no DataFrame/tibble retornado

### `get_estoque_emprego_estadual()`

Retorna o estoque de emprego de um estado por ano, filtrado por nível CNAE.

- **`sigla_uf`** (obrigatório): Código do estado (ex.: `'SP'`, `'RJ'`)
- **`nivel_cnae`** (obrigatório): `2` (divisão) ou `3` (grupo)
- **`codigos_cnae`** (opcional): Lista de códigos CNAE para filtrar
- **Filtro de ano**: aplicar manualmente no DataFrame/tibble retornado

### `get_estoque_emprego_nacional_agrupado()`

Retorna o estoque de emprego nacional por ano, consolidado para um grupo de CNAEs. Não inclui colunas de códigos CNAE específicos.

- **`nome_grupo`** (obrigatório): Nome do grupo/categoria (ex.: `"Tecnologia da Informação"`)
- **`lista_cnae`** (obrigatório): Lista de códigos CNAE a consolidar (ex.: `["620", "631"]` em Python, `c("620", "631")` em R)
- **Filtro de ano**: aplicar manualmente no DataFrame/tibble retornado

### `get_estoque_emprego_estadual_agrupado()`

Retorna o estoque de emprego de um estado por ano, consolidado para um grupo de CNAEs.

- **`sigla_uf`** (obrigatório): Código do estado (ex.: `'RJ'`, `'MG'`)
- **`nome_grupo`** (obrigatório): Nome do grupo/categoria
- **`lista_cnae`** (obrigatório): Lista de códigos CNAE a consolidar
- **Filtro de ano**: aplicar manualmente no DataFrame/tibble retornado

---

### 🔬 **Comportamento de Filtragem de Colunas**

A API remove automaticamente colunas desnecessárias conforme o nível de agregação solicitado:

**Filtros geográficos:**
| Função | Colunas removidas |
|--------|-------------------|
| `*_nacional_*` | `uf`, `sigla_uf`, `municipio`, `nome_municipio` |
| `*_estadual_*` | `municipio`, `nome_municipio` |
| `*_municipal_*` | Nenhuma (retorna todas) |

**Filtros CNAE:**
| `nivel_cnae` | Colunas sempre removidas | Adicionalmente removidas |
|--------------|--------------------------|--------------------------|
| `subclasse` | `nome_grupo`, `descricao_classe` | — |
| `grupo` | `nome_grupo`, `descricao_classe` | `subclasse`, `descricao_subclasse` |
| `divisao` | `nome_grupo`, `descricao_classe` | `codigo_grupo`, `descricao_grupo`, `subclasse`, `descricao_subclasse` |

**Funções agrupadas (`*_agrupado`):** removem **todas** as colunas CNAE específicas (mantêm apenas `nome_grupo`).

---

## Executando os Testes

### Python
```bash
# Navegar para o diretório python
cd python

# Instalar dependências de desenvolvimento
pip install -e ".[dev]"

# Executar todos os testes
pytest

# Executar com cobertura de código
pytest --cov=sdic_libraries

# Executar testes verbose
pytest -v

# Executar teste específico
pytest tests/test_emprego_api.py::TestEmpregoClient::test_get_saldo_emprego_detalhado_uses_sigla_uf
```

### R
```r
# Instalar dependências de teste (se disponíveis)
# devtools::install_dev_deps()

# Para futuras implementações de teste R
# library(testthat)
# test()
```

**Nota**: Atualmente, apenas testes Python estão implementados. Os testes R podem ser adicionados em versões futuras.

## Atualizando a Biblioteca

### Python
```bash
# Atualizar do repositório remoto
pip install --upgrade git+https://github.com/your-org/sdic-libraries.git#subdirectory=python

# Ou se instalado do PyPI (quando publicado)
pip install --upgrade sdic-libraries
```

### R
```r
# Reinstalar do GitHub para obter a última versão
devtools::install_github("your-org/sdic-libraries", subdir = "r", force = TRUE)

# Ou se publicado no CRAN
update.packages("sdic.libraries")
```

## Configuração

### 🎯 Configuração Automática (Novidade!)

As bibliotecas agora carregam automaticamente as variáveis de ambiente - **nenhuma configuração manual necessária!**

**🔍 Ordem de Prioridade:**
1. Variáveis do sistema (mais alta prioridade)  
2. Arquivo `.env` no diretório atual
3. Arquivo `.env` na pasta do usuário (`~/`)
4. Valores padrão da biblioteca

**⚡ Uso sem configuração:**
```python
# Python - funciona imediatamente!
from sdic_libraries.data_access.emprego import Emprego
api = Emprego()  # Configuração carregada automaticamente
```

```r  
# R - também funciona sem configuração!
library(sdic.libraries)
api <- Emprego$new()  # Variáveis carregadas automaticamente
```

### 🛠️ Configuração Opcional

Para personalizar o comportamento, você ainda pode:

- **URLs base customizadas da API**
- **Autenticação com chaves de API**  
- **Timeouts de requisição personalizados**
- **Configuração via arquivos `.env`** (veja `.env.example`)

**Exemplo de arquivo `.env`:**
```bash
# Apenas renomeie .env.example para .env e personalize!
EMPLOYMENT_API_BASE_URL=https://api.employment.gov.br/v1
EMPLOYMENT_API_KEY=sua_chave_aqui
API_TIMEOUT=45
LOG_LEVEL=DEBUG
```

✅ **A biblioteca detecta e carrega automaticamente - personalização é 100% opcional!**

## Exemplos

Veja os diretórios `examples/` nas implementações Python e R para exemplos de uso detalhados.