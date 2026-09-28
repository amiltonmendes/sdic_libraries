# Biblioteca SDIC - Dados de Emprego

Biblioteca unificada para acessar dados de saldo e estoque de emprego brasileiro com suporte completo para Python e R.

## 🚀 Instalação Rápida

### Python

```bash
# Instalação local (recomendada para desenvolvimento)
cd sdic_libraries/python
pip install -e .

# Ou instalação direta
pip install git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python
```

### R

```r
# Instalação via source local
source("sdic_libraries/r/install.R")

# Ou instalação via GitHub
devtools::install_github("amiltonmendes/sdic_libraries", subdir="r")
```

## 🛠️ Uso Básico

### Python

```python
from sdic_libraries.dados.emprego import (
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
    colunas_valores=['estoque_trabalhadores']
)
```

### R

```r
# Carregar biblioteca (após instalar o pacote)
library(sdic.libraries)

# Obter dados de saldo
api <- Emprego$new()
dados_saldo <- api$get_saldo_emprego_detalhado(
  nivel_agregacao = "nacional",
  nivel_cnae = 2,
  codigo_cnae = "10",
  data_minima = "2023-01-01",
  data_maxima = "2025-12-31"
)

# Criar índices temporais (base 2020 = 100) sobre o estoque anual
dados_estoque <- get_estoque_emprego_nacional(codigos_cnae = "10", nivel_cnae = 2, agregado = TRUE)
dados_com_indice <- criar_indice(
  df = dados_estoque,
  ano_base = 2020,
  coluna_data = "ano",
  colunas_valores = "estoque_trabalhadores"
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

## 🧮 Dados RAIS: porte, Potec e demais tabelas (`mte_rais`)

| Tema | Python / R | Metodologia |
|---|---|---|
| Estoque por CNAE (divisão/grupo) | `get_estoque_emprego_nacional`, `get_estoque_emprego_estadual`, `get_estoque_emprego_*_agrupado` | — |
| **Porte** do estabelecimento e setor (indústria × comércio/serviços) | `get_estoque_emprego_porte_nacional`, `get_estoque_emprego_porte_estadual` | Critério Sebrae/DIEESE por pessoas ocupadas; limiares distintos por setor → [METODOLOGIA.md §2](METODOLOGIA.md#2-classificação-de-porte) |
| Estoque por classe CNAE (4 dígitos) | `get_estoque_emprego_classe_cnae_nacional/estadual` | — |
| Estoque por UF × classe × ocupação (CBO) | `get_estoque_emprego_uf_cbo` | — |
| Remuneração média | `get_renda_media_emprego` | — |
| **Potec** (pessoal ocupado técnico-científico) | `get_potec_emprego` | Proxy da PINTEC (gasto empresarial em inovação) construída pelo IPEA com a RAIS (Araújo, Cavalcante e Alves, 2009) → [METODOLOGIA.md §3](METODOLOGIA.md#3-índice-potec-pessoal-ocupado-técnico-científico) |
| Data de atualização das bases | `get_date_bases` | — |

```python
from sdic_libraries.dados.emprego import get_estoque_emprego_porte_nacional, get_potec_emprego

# Microempresas da indústria de alimentos (divisão 10), série 2006+
porte = get_estoque_emprego_porte_nacional("divisao", codigos_cnae=["10"],
                                           setor="Indústria", porte=["Microempresa"])

# Intensidade técnico-científica de P&D (classe 7210); potec é fração 0–1
potec = get_potec_emprego(codigos_classe=["7210"])
```

```r
porte <- get_estoque_emprego_porte_nacional("divisao", codigos_cnae = "10",
                                            setor = "Indústria", porte = "Microempresa")
potec <- get_potec_emprego(codigos_classe = "7210")
```

**Porte, em uma linha:** micro/pequena/média/grande por número de ocupados —
Indústria: até 19 / 20–99 / 100–499 / 500+; Comércio e Serviços: até 9 / 10–49 /
50–99 / 100+ (fonte: Sebrae/DIEESE). **Potec:** proxy anual da PINTEC — (pesquisadores + engenheiros +
profissionais científicos) ÷ estoque total da classe CNAE. Detalhes, cuidados e
referências completas em [METODOLOGIA.md](METODOLOGIA.md).

> A view `rais_agregado_estoque_intensidade_pavitt` (intensidade tecnológica
> Pavitt) ainda não tem endpoint na API e, portanto, não está na biblioteca.

## 🚢 Comércio exterior (`dados.comex`)

Todos os dados vêm da **sdic_api** (`COMEX_API_BASE_URL`); a biblioteca nunca consulta o ComexStat diretamente.
As funções soltas devolvem `DataFrame` (Python) / `tibble` (R) com o **mesmo esquema nas duas linguagens**
(contrato testado em [contrato/comex_amostras.json](contrato/comex_amostras.json)):

| Coluna | Tipo | Observação |
|---|---|---|
| `ano`, `mes` | inteiro | `mes` é nulo com `agregado_ano=True` |
| `ncm` | texto, 8 dígitos | com zeros à esquerda (`01011010`) |
| `divisao_isic_cod` | texto, 2 dígitos | mesma chave do mapa NCM × ISIC |
| `*_desc`, `uf`, `pais`, `regiao` | texto | `uf` traz o nome (`São Paulo`); `secao_isic_desc` é o nome da seção |
| `vl_fob`, `kg_liquido`, `quantidade_estatistica` | numérico | `quantidade_estatistica` unifica `QTEstat`/`QuantidadeEstatistica` |

```python
from sdic_libraries.dados.comex import get_exportacao_ncm_nacional_mensal, get_ncm_isic_mapa

exp = get_exportacao_ncm_nacional_mensal(ano_minimo=2025, agregado_ano=True)  # 1 linha por (ano, NCM)
exp = exp.merge(get_ncm_isic_mapa()[["ncm", "divisao_isic_cod"]], on="ncm")
```

```r
exp <- get_exportacao_ncm_nacional_mensal(ano_minimo = 2025, agregado_ano = TRUE)
exp <- dplyr::left_join(exp, get_ncm_isic_mapa()[, c("ncm", "divisao_isic_cod")], by = "ncm")
```

> No Python os parâmetros são só por nome (`ano_minimo=...`). A classe `Comex` continua disponível e devolve os registros crus.

### Emprego × comércio exterior

`juntar_emprego_comex()` une as duas bases por **divisão (2 dígitos) e ano**: `divisao_cnae_cod` (emprego) =
`divisao_isic_cod` (comex). Coincidem 38 divisões (as de serviços só existem no emprego; a `89` só no comex).
O comex é somado por (ano, divisão) antes da união, então meses, países ou UFs não multiplicam as linhas do emprego.
Use o ano fechado no comex: o ano corrente é parcial.

```python
from sdic_libraries.dados.emprego import get_estoque_emprego_nacional
from sdic_libraries.dados.comex import get_exportacao_isic_divisao_nacional_mensal
from sdic_libraries.utils import juntar_emprego_comex

emp = get_estoque_emprego_nacional(nivel_cnae=2, agregado=True, ano_minimo=2024, ano_maximo=2024)
exp = get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)
df = juntar_emprego_comex(emp, exp[exp["ano"] == 2024])   # how="left" (padrão), "inner" ou "outer"
df["fob_por_trabalhador"] = df["vl_fob"] / df["estoque_trabalhadores"]
```

```r
emp <- get_estoque_emprego_nacional(nivel_cnae = 2, agregado = TRUE, ano_minimo = 2024, ano_maximo = 2024)
exp <- get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)
df  <- juntar_emprego_comex(emp, exp[exp$ano == 2024, ])   # how = "left" (padrão), "inner" ou "full"
```

## 💾 Cache local (opcional)

Desligado por padrão. Guarda em disco as respostas da **sdic_api** (nenhuma outra fonte é consultada), e a
mesma consulta repetida passa a vir do disco em vez da rede (mapa NCM × ISIC: 14,7 s → 0,1 s).

```python
import os; os.environ["SDIC_CACHE_TTL"] = "3600"   # segundos de validade; 0 ou ausente = desligado
```
```r
Sys.setenv(SDIC_CACHE_TTL = 3600)
```

A chave inclui método, endereço completo, parâmetros e corpo da requisição; erros nunca são gravados. Pasta:
`SDIC_CACHE_DIR` ou `~/.cache/sdic_libraries` (Python) / `tools::R_user_dir("sdic.libraries", "cache")` (R) — apague-a
para limpar. Os dados são atualizados mensalmente: use validade curta se precisar do dado mais recente.

> **Nota:** `ano_minimo`/`ano_maximo` das funções de emprego também são aplicados no cliente, então o resultado é o
> mesmo mesmo que a sdic_api implantada seja anterior a esses filtros (nesse caso só o volume baixado é maior).

## 🗂️ Relatórios e Portal de Emprego por Estado (`dados.emprego.portal`)

Além de consultar a API ao vivo, a biblioteca **lê os artefatos de emprego já
publicados no GitHub Pages** pelo pipeline `cgid_cargas`. São dois produtos por UF:

- **Relatório** (cache, dados brutos): `saldo` (CAGED mensal por divisão CNAE),
  `estoque` (RAIS por divisão) e `acum12m_total`.
- **Portal** (payload v1.1, pronto para apresentação): `capa_kpi`, `kpis`,
  `charts`, `ranked_lists`, `breakdowns` — já em pt-BR.

Há dois ambientes: `producao` (default) e `homologacao`. A URL base é configurável
por `PORTAL_EMPREGO_BASE_URL` (default: `https://amiltonmendes.github.io/sdic_libraries`).

### Python

```python
from sdic_libraries.dados.emprego.portal import (
    get_relatorio_emprego_saldo_estadual,
    get_relatorio_emprego_estoque_estadual,
    get_portal_emprego_estadual,
    get_portal_emprego_kpis_estadual,
    listar_estados_disponiveis,
)

# Relatório (dados brutos do cache)
saldo = get_relatorio_emprego_saldo_estadual("SP")            # DataFrame
estoque = get_relatorio_emprego_estoque_estadual("SP")        # DataFrame

# Portal (payload v1.1)
payload = get_portal_emprego_estadual("SP")                   # dict completo
kpis = get_portal_emprego_kpis_estadual("SP")                 # DataFrame

# Ambiente de homologação e descoberta de UFs publicadas
ufs = listar_estados_disponiveis(ambiente="homologacao")      # ['AC', 'AL', ...]
```

### R

```r
source("sdic_libraries/r/R/portal.R")  # (já incluído no pacote)

saldo  <- get_relatorio_emprego_saldo_estadual("SP")          # tibble
kpis   <- get_portal_emprego_kpis_estadual("SP")              # tibble
ufs    <- listar_estados_disponiveis(ambiente = "homologacao")
```

> ℹ️ O caminho `sdic_libraries.data_access` foi renomeado para `sdic_libraries.dados`
> na v0.4.0. Um alias `data_access` é mantido temporariamente (emite `DeprecationWarning`).

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

### Testes de integração (API real)

Os testes `test_emprego_cobertura_completa.py` e `test_emprego_novos_metodos.py`
(Python) e `test-emprego*.R` (R) chamam a API de verdade. Por padrão apontam para
`http://127.0.0.1:8123` (API local do repositório `sdic_api`) e são **ignorados**
se ela não responder. Para usar outra instância:

```bash
EMPLOYMENT_API_BASE_URL=https://sdicapi.dados.ninja pytest python/tests
```

### Resultados Esperados
- ✅ **Função criar_indice**: 100% dos testes aprovados
- ✅ **API de Emprego**: Conectividade básica funcional
- ✅ **Demonstrações**: Exemplos práticos executados

## ⚙️ Configuração

A configuração pública é **centralizada em um único `.env` versionado** na raiz do projeto,
e o endpoint padrão (DNS próprio) já vem embutido na biblioteca — **funciona out-of-the-box**.
A URL é um domínio DNS e **não expõe** a conta de serviço nem o número de projeto da nuvem.

Ordem de precedência (maior → menor):
1. Parâmetro explícito no código (`Emprego(base_url=...)`)
2. Variável de ambiente do SO / arquivo `.env`
3. Default embutido (`https://sdicapi.dados.ninja`)

Variáveis reconhecidas:

| Variável | Obrigatória | Onde fica | Descrição |
|----------|-------------|-----------|-----------|
| `EMPLOYMENT_API_BASE_URL` | Não (tem default) | `.env` versionado | Endpoint público da API (DNS). |
| `EMPLOYMENT_API_KEY` | Não | **`.env.local` (ignorado)** | Token de autenticação, se a API exigir. |
| `API_TIMEOUT` | Não | `.env` | Timeout das requisições em segundos (padrão 30). |

> 🔒 **Segredos nunca no repositório.** O `.env` versionado contém **apenas** configuração
> pública (a URL). Qualquer segredo — como `EMPLOYMENT_API_KEY` — deve ir em **`.env.local`**,
> que é ignorado pelo git. Em CI/CD, injete a chave como *secret* do pipeline.

**`.env` compartilhado em servidor** (opcional): a lib também lê `/etc/sdic/.env`, útil para
configurar uma máquina inteira de uma vez.

**Override pontual no código:**

```python
api = Emprego(base_url="https://sdicapi.dados.ninja")  # Python
```
```r
api <- Emprego$new(base_url = "https://sdicapi.dados.ninja")  # R
```

## ⚙️ Configuração Avançada

As variáveis de ambiente estão documentadas na seção [Configuração](#️-configuração) acima
(`EMPLOYMENT_API_BASE_URL`, `EMPLOYMENT_API_KEY`, `API_TIMEOUT`). Abaixo, exemplos de
configuração manual passando os parâmetros diretamente no construtor.

### Python - Configuração Manual

```python
from sdic_libraries.dados.emprego import Emprego

# Configuração customizada (timeout e api_key são opcionais)
api = Emprego(
    base_url="https://sdicapi.dados.ninja",
    timeout=60,
    api_key="..."  # só se a API exigir autenticação
)
```

### R - Configuração Manual

```r
# Configuração customizada (timeout e api_key são opcionais)
api <- Emprego$new(
  base_url = "https://sdicapi.dados.ninja",
  timeout = 60,
  api_key = "..."  # só se a API exigir autenticação
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
    colunas_valores=['estoque_trabalhadores']
)

# Análise de crescimento
crescimento_2023 = indice_emprego.loc[
    indice_emprego['ano'] == 2023, 'estoque_trabalhadores_indice'
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

# 📚 Referência detalhada das funções

## Funções de saldo (CAGED)

#### Python
```python
from sdic_libraries.dados.emprego import (
    get_saldo_emprego_estadual_mensal,
    get_saldo_emprego_municipal_mensal,
    get_saldo_emprego_estadual_mensal_agrupado,
)

# 🗺️ Dados estaduais com um CNAE específico
df_sp = get_saldo_emprego_estadual_mensal(
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
from sdic_libraries.dados.emprego import (
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
# Colunas: ano, divisao_cnae_cod, divisao_cnae_desc, estoque_trabalhadores (+ 'Ano', alias de 'ano')

# 📦 Estoque estadual anual para SP por grupo CNAE
df_estoque_sp = get_estoque_emprego_estadual(
  uf='SP',
  nivel_cnae=3
)
df_estoque_sp = df_estoque_sp[df_estoque_sp['ano'].astype(int) >= 2020]
# Colunas: ano, sigla_uf, grupo_cnae_cod, grupo_cnae_desc, divisao_cnae_cod, divisao_cnae_desc, estoque_trabalhadores

# 📦 Estoque agrupado nacional (consolidado por lista de CNAEs)
df_estoque_ti = get_estoque_emprego_nacional_agrupado(
    nome_grupo="Tecnologia da Informação",
  lista_cnae=["620", "631"]
)
df_estoque_ti = df_estoque_ti[df_estoque_ti['ano'].astype(int) >= 2020]
# Colunas: ano, nome_grupo, estoque_trabalhadores

# 📦 Estoque agrupado estadual
df_estoque_fin_rj = get_estoque_emprego_estadual_agrupado(
    sigla_uf='RJ',
    nome_grupo="Financeiro",
  lista_cnae=["641", "642"]
)
df_estoque_fin_rj = df_estoque_fin_rj[df_estoque_fin_rj['ano'].astype(int) >= 2020]
# Colunas: ano, sigla_uf, nome_grupo, estoque_trabalhadores
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
from sdic_libraries.dados.emprego import Emprego

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

# Obs.: get_saldo_emprego_detalhado, get_saldo_emprego_as_dataframe e
# get_saldo_emprego_detalhado_lista_cnae são MÉTODOS da classe Emprego
# (não funções de módulo). Para consultas simples, prefira as funções de alto nível.
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
- **`data_maxima`** (opcional): Data máxima no formato YYYY-MM-DD

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

## Parâmetros das funções de estoque

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

# testthat::test_dir("r/tests/testthat")
```

**Nota**: os testes R (`r/tests/testthat`) e Python (`python/tests`) existem; os que dependem da API real precisam de `EMPLOYMENT_API_BASE_URL` (veja *Testes de integração* acima).

## Atualizando a Biblioteca

### Python
```bash
# Atualizar do repositório remoto
pip install --upgrade git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python

# Ou se instalado do PyPI (quando publicado)
pip install --upgrade sdic-libraries
```

### R
```r
# Reinstalar do GitHub para obter a última versão
devtools::install_github("amiltonmendes/sdic_libraries", subdir = "r", force = TRUE)

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
from sdic_libraries.dados.emprego import Emprego
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

**Exemplo de `.env`** (versionado — apenas configuração pública):
```bash
EMPLOYMENT_API_BASE_URL=https://sdicapi.dados.ninja
API_TIMEOUT=45
LOG_LEVEL=DEBUG
```

**Segredos vão em `.env.local`** (ignorado pelo git), nunca no `.env` versionado:
```bash
# .env.local
EMPLOYMENT_API_KEY=sua_chave_aqui
```

✅ **A biblioteca detecta e carrega automaticamente - personalização é 100% opcional!**

## Exemplos

Veja os diretórios `examples/` nas implementações Python e R para exemplos de uso detalhados.

## ⏱️ Desempenho (dados RAIS)

- Cada página da API executa 1 consulta no BigQuery (~1 s); a biblioteca usa páginas de
  5.000 linhas (o máximo da API) e junta tudo sozinha.
- **Filtre o ano na origem.** Todas as funções RAIS (`get_estoque_emprego_*`, `*_porte_*`,
  `*_classe_cnae_*`, `*_uf_cbo`, `get_renda_media_emprego`, `get_potec_emprego`) aceitam
  `ano_minimo` e `ano_maximo` (opcionais). Sem eles, a série completa (2006+) é baixada.

  | Chamada | Todos os anos | `ano_minimo` |
  |---|---|---|
  | estoque estadual, 27 UFs, divisão | 45.833 linhas, ~13 s | `ano_minimo=2025`: 2.267 linhas, ~1 s |
  | `uf_cbo` SP + classe 4711 | 12.587 linhas, ~3,4 s | `ano_minimo=2024`: 1.091 linhas, ~2,3 s |
  | porte estadual SP, classe, indústria | 21.374 linhas, ~6 s | `ano_minimo=2024`: 2.139 linhas, ~1,3 s |

  ```python
  df = get_estoque_emprego_estadual(uf="SP", nivel_cnae=2, ano_minimo=2025)   # só o último ano
  ```
  ```r
  df <- get_estoque_emprego_estadual(sigla_uf = "SP", nivel_cnae = 2, ano_minimo = 2025)
  ```
- **`get_estoque_emprego_uf_cbo`** é o endpoint mais pesado: 26,8 milhões de linhas
  (24 anos × 28 UFs × 673 classes × 2.842 CBOs), clusterizada por UF, classe e CBO.
  **Sempre filtre** por `siglas_uf` e `codigos_classe` (e, se possível, por ano). Sem filtros
  seriam ~5,4 mil páginas.
- `get_estoque_emprego_porte_estadual` em nível `classe` sem `codigos_cnae` retorna dezenas
  de milhares de linhas; prefira `divisao`/`grupo`, filtre por código ou por ano.

## 📖 Referências

- ARAÚJO, B. C. P. O.; CAVALCANTE, L. R.; ALVES, P. F. Variáveis proxy para os gastos empresariais em inovação com base no pessoal ocupado técnico-científico disponível na Rais. *Radar*, Ipea, n. 5, 2009. <http://repositorio.ipea.gov.br/handle/11058/5431>
- SEBRAE; DIEESE. *Anuário do Trabalho na Micro e Pequena Empresa*. <https://www.dieese.org.br/anuario/2011/anuarioSebrae10-11/15.html>
- MTE. RAIS — microdados de estabelecimentos (via Base dos Dados). <https://basedosdados.org/dataset/br-me-rais>

---

**Versão**: 1.0  
**Última atualização**: Setembro 2026  
**Compatibilidade**: Python 3.8+ | R 4.0+
