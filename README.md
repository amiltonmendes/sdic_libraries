# Biblioteca SDIC — leitura dos dados da plataforma

Biblioteca Python (`sdic_libraries`) + R (`sdic.libraries`), com as mesmas funções nas duas linguagens, para
ler os dados da plataforma da SDIC sempre como tabela (`DataFrame`/`tibble`):

- **emprego** (RAIS, Novo CAGED) e **comércio exterior** (ComexStat), pela `sdic_api`;
- **séries** das bases do `carga_base` (SIDRA, Contas Regionais, comex por UF) e indicadores oficiais (`get_serie`);
- **seções publicadas** em JSON, as mesmas do portal e dos subsídios (`get_kpis_publicados` e afins);
- **políticas** da SDIC publicadas pelo `gaia_nib` (`listar_politicas`, `get_politica`).

Documentação completa em [docs/](docs/index.md) (também no painel de cargas, em `/docs/biblioteca`).
[AGENTS.md](AGENTS.md) é leitura obrigatória antes de mudar código aqui.

## 🧭 Por onde começar

1. **Instale** (abaixo) e defina a chave da API em `.env.local` (`SDIC_API_KEY=...`). Seções publicadas e
   políticas são arquivos públicos e dispensam chave.
2. **Descubra a função** com `listar_bases()`, o [catálogo](CATALOGO.md) ou [Qual função usar](docs/qual_funcao_usar.md).
3. **Veja de onde vem o dado** e que colunas ele tem: `descrever("get_kpis_publicados")`.
4. **Travou?** `help(<funcao>)` / `?<funcao>`; `sdic_config()` mostra de onde a biblioteca está lendo;
   erros comuns em [docs/configuracao.md](docs/configuracao.md).

## 🚀 Instalação

```bash
pip install "git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python"   # Python
pip install -e python/                                                                      # desenvolvimento local
```

```r
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r")   # R
devtools::load_all("r")                                                  # desenvolvimento local
```

Pré-requisitos e verificação: [INSTALL.md](INSTALL.md).

## 🔎 Catálogo: qual função eu uso?

`listar_bases()` devolve uma tabela com toda função pública, o que ela traz, o nível de
agregação e um exemplo — filtre por tema ou assunto em vez de ler o README inteiro. Mesmo
conteúdo, em página: [CATALOGO.md](CATALOGO.md) (gerado de `contrato/catalogo.json`, a fonte única
lida pelas duas linguagens).

```python
from sdic_libraries import listar_bases
listar_bases()                        # tudo
listar_bases(tema="comex")            # só comércio exterior
listar_bases(subtema="saldo_caged")   # só saldo mensal/anual do CAGED
```
```r
listar_bases()
listar_bases(tema = "comex")
listar_bases(subtema = "saldo_caged")
```

## 🛠️ Uso básico

### Python

```python
from sdic_libraries.dados.emprego import get_saldo_emprego_nacional_mensal, get_estoque_emprego_nacional
from sdic_libraries.utils import criar_indice

# Saldo mensal (admissões − desligamentos), divisão 10 = indústria alimentícia
saldo = get_saldo_emprego_nacional_mensal(nivel_cnae='divisao', codigo_cnae='10', data_minima='2024-01-01')

# Estoque anual (RAIS), filtrado já no servidor
estoque = get_estoque_emprego_nacional(codigos_cnae=['10'], nivel_cnae=2, agregado=True, ano_minimo=2020)

# Índice com base 2020 = 100
indice = criar_indice(df=estoque, ano_base=2020, coluna_data='ano', colunas_valores=['estoque_trabalhadores'])
```

### R

```r
library(sdic.libraries)

saldo <- get_saldo_emprego_nacional_mensal(nivel_cnae = "divisao", codigo_cnae = "10", data_minima = "2024-01-01")

estoque <- get_estoque_emprego_nacional(codigos_cnae = "10", nivel_cnae = 2, agregado = TRUE, ano_minimo = 2020)

indice <- criar_indice(df = estoque, ano_base = 2020, coluna_data = "ano", colunas_valores = "estoque_trabalhadores")
```

**Um código CNAE vs. vários:** `codigo_cnae='10'` (singular) traz um código por vez; para somar
vários sob um nome, use a variante `_agrupado` (`get_estoque_emprego_nacional_agrupado`,
`get_saldo_emprego_nacional_mensal_agrupado`, ...) com `nome_grupo=` + `lista_cnae=[...]`.

## 🧮 Dados RAIS: porte, Potec e demais tabelas (`mte_rais`)

| Tema | Função | Metodologia |
|---|---|---|
| Estoque por CNAE (divisão/grupo) | `get_estoque_emprego_nacional`, `_estadual`, `_*_agrupado` | — |
| **Porte** do estabelecimento e setor (indústria × comércio/serviços) | `get_estoque_emprego_porte_nacional`, `_estadual` | Sebrae/DIEESE por pessoas ocupadas → [METODOLOGIA.md §2](METODOLOGIA.md#2-classificação-de-porte) |
| Estoque por classe CNAE (4 dígitos) | `get_estoque_emprego_classe_cnae_nacional/estadual` | — |
| Estoque por UF × classe × ocupação (CBO) | `get_estoque_emprego_uf_cbo` | — |
| Remuneração média | `get_renda_media_emprego` | — |
| **Potec** (pessoal ocupado técnico-científico) | `get_potec_emprego` | Proxy da PINTEC/IPEA → [METODOLOGIA.md §3](METODOLOGIA.md#3-índice-potec-pessoal-ocupado-técnico-científico) |
| Data de atualização das bases | `get_date_bases` | — |

```python
porte = get_estoque_emprego_porte_nacional("divisao", codigos_cnae=["10"], setor="Indústria", porte=["Microempresa"])
potec = get_potec_emprego(codigos_classe=["7210"])  # fração 0–1
```
```r
porte <- get_estoque_emprego_porte_nacional("divisao", codigos_cnae = "10", setor = "Indústria", porte = "Microempresa")
potec <- get_potec_emprego(codigos_classe = "7210")
```

Detalhes, cuidados e referências completas em [METODOLOGIA.md](METODOLOGIA.md).

> A view `rais_agregado_estoque_intensidade_pavitt` (intensidade tecnológica Pavitt) não tem
> endpoint na sdic_api e, por isso, não está na biblioteca.

## 🚢 Comércio exterior (`dados.comex`)

Sempre via **sdic_api** — a biblioteca nunca consulta o ComexStat/MDIC diretamente. Esquema
padronizado, testado nas duas linguagens ([contrato/comex_amostras.json](contrato/comex_amostras.json)):
`ano`/`mes` inteiros (`mes` nulo com `agregado_ano=True`), `ncm` (8 dígitos) e `divisao_isic_cod`
(2 dígitos) como texto com zeros à esquerda, `vl_fob`/`kg_liquido`/`quantidade_estatistica` numéricos.

```python
from sdic_libraries.dados.comex import get_exportacao_ncm_nacional_mensal, get_ncm_isic_mapa

exp = get_exportacao_ncm_nacional_mensal(ano_minimo=2025, agregado_ano=True)  # 1 linha por (ano, NCM)
exp = exp.merge(get_ncm_isic_mapa()[["ncm", "divisao_isic_cod"]], on="ncm")
```
```r
exp <- get_exportacao_ncm_nacional_mensal(ano_minimo = 2025, agregado_ano = TRUE)
exp <- dplyr::left_join(exp, get_ncm_isic_mapa()[, c("ncm", "divisao_isic_cod")], by = "ncm")
```

### Emprego × comércio exterior

`juntar_emprego_comex()` une as duas bases por **divisão CNAE/ISIC (2 dígitos) e ano** — o comex é
somado por (ano, divisão) antes da união, então meses/países/UFs não multiplicam as linhas do
emprego. 38 divisões coincidem (serviços só existem no emprego; a `89`, só no comex). Use o ano
fechado no comex — o ano corrente é parcial.

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

Desligado por padrão. Guarda em disco as respostas da **sdic_api** (só ela) — a mesma consulta
repetida vem do disco em vez da rede (mapa NCM × ISIC: 14,7s → 0,1s).

```python
import os; os.environ["SDIC_CACHE_TTL"] = "3600"   # segundos; 0/ausente = desligado
```
```r
Sys.setenv(SDIC_CACHE_TTL = 3600)
```

Chave = método + endereço + parâmetros + corpo; erros nunca são gravados. Pasta:
`SDIC_CACHE_DIR` ou `~/.cache/sdic_libraries` (Python) / `tools::R_user_dir("sdic.libraries", "cache")`
(R) — apague para limpar. Dados atualizam mensalmente: use validade curta se precisar do mais recente.

## 📰 Seções publicadas, séries e políticas

```python
from sdic_libraries import get_kpis_publicados, get_series_publicadas, get_serie, get_politicas_estado

get_kpis_publicados("SP", "emprego", ambiente="homologacao")     # os números do portal, um por linha
get_series_publicadas("SP", "comercio", ambiente="homologacao")  # séries dos gráficos, formato longo
get_serie("sidra_producao", cod_tabela=8888, cod_localidade="35", desde="2025-01-01", com_nomes=True)
get_politicas_estado("SP", ambiente="homologacao")               # ordem publicada; não some unidades diferentes
```
```r
get_kpis_publicados("SP", "emprego", ambiente = "homologacao")
get_series_publicadas("SP", "comercio", ambiente = "homologacao")
get_serie("sidra_producao", cod_tabela = 8888, cod_localidade = "35", desde = "2025-01-01", com_nomes = TRUE)
get_politicas_estado("SP", ambiente = "homologacao")
```

`listar_secoes_publicadas()`, `listar_series()` e `listar_politicas()` dizem o que existe. O ambiente padrão é
`producao` (`SDIC_AMBIENTE` ou o argumento `ambiente` mudam). As funções `get_portal_emprego_*` e
`get_relatorio_emprego_*` (layout antigo do Pages) estão depreciadas.

## 📐 Convenções e comportamento

- **Todo retorno é tabela.** Nenhuma função pública devolve lista/dict cru; ver
  [contrato/](contrato/) para o esquema testado de cada base.
- **Filtre no servidor**, não no DataFrame: `ano_minimo`/`ano_maximo`/`codigos_cnae` (RAIS) e
  `secao`/`bloco`/`ano_minimo` (comex) reduzem o volume baixado — ver ⏱️ Desempenho abaixo.
- **Colunas somem automaticamente por nível.** Filtros de agregação: `*_nacional_*` remove
  `uf`/`municipio`; `*_estadual_*` remove só `municipio`; `*_municipal_*` mantém tudo. Filtros de
  CNAE: pedir `nivel_cnae='divisao'` remove as colunas de grupo/subclasse (e vice-versa); funções
  `*_agrupado` removem todas as colunas de código específico, mantendo só `nome_grupo`.
- **API avançada (acesso direto à classe):** `Emprego`/`Comex` (Python) e o objeto R6 (R) continuam
  disponíveis para quem precisa controlar o número exato de requisições — ex. `cgid_cargas` chama
  `Emprego$new()$get_saldo_caged_estadual_divisao(siglas_uf=<27 UFs>)`, 1 requisição para todas as
  UFs, em vez de 27 chamadas às funções de módulo. Não é "modo legado"; é a opção certa quando o
  número de chamadas importa. Ver [AGENTS.md](AGENTS.md).
- **Paginação é sempre interna** — nunca informe `pagina`/`tamanho_pagina` na API pública.

## ⏱️ Desempenho (dados RAIS)

Cada página executa 1 consulta no BigQuery (~1s); a biblioteca pagina em 5.000 linhas e junta
tudo. **Filtre o ano na origem** — sem `ano_minimo`, a série completa (2006+) é baixada:

| Chamada | Todos os anos | Com `ano_minimo` |
|---|---|---|
| estoque estadual, 27 UFs, divisão | 45.833 linhas, ~13s | `2025`: 2.267 linhas, ~1s |
| `uf_cbo` SP + classe 4711 | 12.587 linhas, ~3,4s | `2024`: 1.091 linhas, ~2,3s |
| porte estadual SP, classe, indústria | 21.374 linhas, ~6s | `2024`: 2.139 linhas, ~1,3s |

```python
df = get_estoque_emprego_estadual(uf="SP", nivel_cnae=2, ano_minimo=2025)
```
```r
df <- get_estoque_emprego_estadual(sigla_uf = "SP", nivel_cnae = 2, ano_minimo = 2025)
```

`get_estoque_emprego_uf_cbo` é o endpoint mais pesado (26,8 milhões de linhas sem filtro —
~5,4 mil páginas): **sempre** filtre `siglas_uf` e `codigos_classe`. `get_estoque_emprego_porte_estadual`
em nível `classe` sem `codigos_cnae` também retorna dezenas de milhares de linhas.

## ⚙️ Configuração

Uma chave e três endereços, resolvidos num lugar só (`config.py` / `config.R`). Precedência: argumento da
função, variável de ambiente, `.env.local`, `.env`, `~/.env`, `/etc/sdic/.env`, padrão do catálogo.

| Variável | Descrição | Padrão |
|---|---|---|
| `SDIC_API_KEY` | Chave individual da API. Guarde em **`.env.local`** (fora do git) | sem chave |
| `SDIC_AMBIENTE` | `producao` ou `homologacao` (seções publicadas e políticas) | `producao` |
| `SDIC_API_URL`, `SDIC_DADOS_URL`, `SDIC_PAGES_URL` | Endereço da API, dos JSON publicados e das políticas | os do catálogo |
| `SDIC_TIMEOUT` | Segundos por requisição | 30 |
| `SDIC_CACHE_TTL`, `SDIC_CACHE_DIR` | Cache local — ver 💾 acima | desligado |

`sdic_config()` mostra o que está valendo e de onde veio cada valor. Os nomes antigos (`EMPLOYMENT_API_KEY`,
`COMEX_API_KEY`, `*_API_BASE_URL`, `PORTAL_EMPREGO_*`, `API_TIMEOUT`) continuam aceitos, com aviso. Detalhes,
segurança da chave e erros comuns: [docs/configuracao.md](docs/configuracao.md).

## 🧪 Testes

```bash
make test          # as duas linguagens e a conferência do que é gerado
cd python && python -m pytest -q
Rscript -e 'testthat::test_local("r", reporter = "summary")'
```

Os testes rodam sem rede, contra amostras em `contrato/*.json` lidas pelas duas linguagens. Os que chamam a
**API de verdade** apontam para `http://127.0.0.1:8123` e são **pulados** se ela não responder.

## 📦 Atualizando

```bash
pip install --upgrade git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python
```
```r
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r", force = TRUE)
```

O que mudou entre versões: [CHANGELOG.md](CHANGELOG.md). Funções depreciadas continuam
funcionando (emitem aviso, nunca quebram sem uma versão de aviso antes) — ver o aviso da própria
função para a substituta recomendada.

> ℹ️ `sdic_libraries.data_access` foi renomeado para `sdic_libraries.dados` na v0.4.0; o alias
> `data_access` ainda existe (emite `DeprecationWarning`).

## 🔧 Solução de problemas

- **Erro de conectividade:** confira a rede e se a API está no ar (`get_date_bases()` funciona
  mesmo sem outros parâmetros). `sdic_config()` mostra para onde a biblioteca está apontando.
- **Erro de importação:** reinstale (`pip install -e python/` / `devtools::load_all("r")`);
  Python precisa de `pandas`/`requests`; R precisa de `httr2`/`R6`/`dplyr`/`tibble`/`cli`/`rlang`.
- **Dados vazios:** confira o código CNAE/NCM (zeros à esquerda importam — `"01"`, não `"1"`) e se
  o período pedido tem dado publicado; teste com um intervalo mais amplo primeiro.
- **Coluna que eu esperava não veio:** veja "Convenções e comportamento" acima — é comportamento
  esperado (filtro automático por nível), não bug.
- Nada disso resolveu? Abra uma issue no GitHub com a chamada exata e a mensagem de erro completa.

## 📚 Exemplos completos

Notebooks e scripts prontos em [`python/examples/`](python/examples/) e [`r/examples/`](r/examples/)
— demonstrações completas (estoque + saldo, intensidade tecnológica, atualização de planilha CNAE).

## 📖 Referências

- ARAÚJO, B. C. P. O.; CAVALCANTE, L. R.; ALVES, P. F. Variáveis proxy para os gastos empresariais em inovação com base no pessoal ocupado técnico-científico disponível na Rais. *Radar*, Ipea, n. 5, 2009. <http://repositorio.ipea.gov.br/handle/11058/5431>
- SEBRAE; DIEESE. *Anuário do Trabalho na Micro e Pequena Empresa*. <https://www.dieese.org.br/anuario/2011/anuarioSebrae10-11/15.html>
- MTE. RAIS — microdados de estabelecimentos (via Base dos Dados). <https://basedosdados.org/dataset/br-me-rais>

## 📄 Licença

MIT — veja [LICENSE](LICENSE).

---

**Versão**: 0.6.0 · **Compatibilidade**: Python 3.8+ | R 4.0+ · [AGENTS.md](AGENTS.md) ·
[CATALOGO.md](CATALOGO.md) · [CHANGELOG.md](CHANGELOG.md)
