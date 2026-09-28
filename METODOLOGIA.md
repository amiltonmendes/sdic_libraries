# Metodologia dos dados RAIS (dataset `mte_rais`)

Este documento descreve como são construídos o **porte do estabelecimento** e o
**índice Potec**, usados pelas funções `get_estoque_emprego_porte_*` e
`get_potec_emprego` (Python e R). Os dados vêm do dataset BigQuery
`fast-sdic.mte_rais`, servido pela API SDIC.

## 1. Catálogo do dataset `mte_rais`

| Objeto BigQuery | Endpoint da API | Python | R |
|---|---|---|---|
| `rais_agregado_estoque` (via view `..._estoque_descricao`) | `/get_estoque_emprego_nacional/`, `/get_estoque_emprego_estadual/`, POST `..._lista_cnae`, `..._grupos_cnae` | `get_estoque_emprego_nacional`, `get_estoque_emprego_estadual`, `get_estoque_emprego_*_agrupado` | idem |
| `rais_agregado_estoque_porte` | `/get_estoque_emprego_porte_nacional/`, `/get_estoque_emprego_porte_estadual/` | `get_estoque_emprego_porte_nacional`, `get_estoque_emprego_porte_estadual` | idem |
| `rais_agregado_estoque_classe_cnae` (via view `..._classe_cnae_descricao`) | `/get_estoque_emprego_classe_cnae_nacional/`, `/get_estoque_emprego_classe_cnae_estadual/` | `get_estoque_emprego_classe_cnae_nacional`, `get_estoque_emprego_classe_cnae_estadual` | idem |
| `rais_agregado_estoque_uf_e_cbo` | `/get_estoque_emprego_uf_cbo/` | `get_estoque_emprego_uf_cbo` | idem |
| `rais_agregado_renda` | `/get_renda_media_emprego/` | `get_renda_media_emprego` | idem |
| `rais_potec` | `/get_potec_emprego/` | `get_potec_emprego` | idem |
| `rais_agregado_estoque_intensidade_pavitt` (view) | **não exposto pela API** | — | — |
| (metadado) data de atualização das bases | `/data_bases` | `get_date_bases` | idem |

Convenção de códigos CNAE 2.0 no dataset: **divisão = 2 dígitos, grupo = 3,
classe = 4** (sem dígito verificador), subclasse = 7. Os dados por CNAE 2.0
começam em **2006**: a RAIS só adotou a CNAE 2.0 nesse ano e, antes disso, a
coluna de CNAE 2.0 é nula.

## 2. Classificação de porte

### Fonte

- Microdados de estabelecimentos da RAIS (MTE), acessados pela
  [Base dos Dados](https://basedosdados.org) — tabela
  `basedosdados.br_me_rais.microdados_estabelecimentos`.
- **Unidade de análise: estabelecimento** (não a empresa/CNPJ raiz).
- **Estoque de trabalhadores** = soma de `quantidade_vinculos_ativos`
  (vínculos ativos em 31/12 de cada ano).
- O porte é derivado da faixa de tamanho declarada na RAIS
  (`tamanho_estabelecimento`), sem recontar os vínculos.

### Critério

O critério é o do **Sebrae/DIEESE** (*Anuário do Trabalho na Micro e Pequena
Empresa*): o porte é definido pelo **número de pessoas ocupadas** e **depende do
setor de atividade**. Não se usa faturamento (a Lei Complementar nº 123/2006
define ME/EPP por receita bruta — critério diferente e não aplicado aqui).

| Porte | Indústria (inclui construção) | Comércio e Serviços |
|---|---|---|
| Microempresa | até 19 ocupados | até 9 |
| Empresa de pequeno porte | 20 a 99 | 10 a 49 |
| Empresa de médio porte | 100 a 499 | 50 a 99 |
| Grande empresa | 500 ou mais | 100 ou mais |

### Diferença de cálculo entre indústria e comércio/serviços

1. **Setor** — pela divisão CNAE 2.0 do estabelecimento: divisões **05 a 43**
   (extrativas, transformação, eletricidade e gás, água/esgoto/resíduos e
   construção) = `Indústria`; todas as demais = `Comércio e Serviços`.
   Atenção: a **agropecuária (divisões 01–03) cai em `Comércio e Serviços`** por
   essa regra.
2. **Limiares** — a RAIS informa o tamanho em faixas. Cada faixa é mapeada
   para um porte com cortes diferentes por setor:

| Faixa RAIS (`tamanho_estabelecimento`, escala 2002+) | Código | Indústria | Comércio e Serviços |
|---|:-:|---|---|
| zero vínculos | 1 | Micro | Micro |
| até 4 | 2 | Micro | Micro |
| 5 a 9 | 3 | Micro | Micro |
| 10 a 19 | 4 | Micro | Pequena |
| 20 a 49 | 5 | Pequena | Pequena |
| 50 a 99 | 6 | Pequena | Média |
| 100 a 249 | 7 | Média | Grande |
| 250 a 499 | 8 | Média | Grande |
| 500 a 999 | 9 | Grande | Grande |
| 1000 ou mais | 10 | Grande | Grande |

Como as faixas da RAIS coincidem com os cortes do Sebrae (9/19/49/99/499), não há
aproximação por interpolação.

### Cuidados

- **Mudança de escala em 2002**: até 2001 os códigos vão de 0 a 9 (0 = zero,
  9 = 1000+); de 2002 em diante, de 1 a 10. A carga soma +1 aos códigos de
  ≤ 2001 antes de classificar.
- No dicionário da Base dos Dados o código 10 (2002–2018) aparece como
  "IGNORADO"; a verificação nos microdados mostra que ele corresponde a
  **1000 ou mais vínculos** (mediana ≈ 1.600), e é assim que a carga o trata.
- A faixa é a declarada na RAIS: em alguns anos o estabelecimento pode ter uma
  contagem de vínculos ativos ligeiramente fora da faixa (faixa e vínculos ativos
  em 31/12 podem diferir).
- Estabelecimentos sem CNAE 2.0 (anos anteriores a 2006) são descartados na
  carga: a série de porte começa em 2006 (validado: 2006–2025).

### Como usar

```python
from sdic_libraries.dados.emprego import get_estoque_emprego_porte_nacional
df = get_estoque_emprego_porte_nacional(nivel_cnae="divisao", codigos_cnae=["10"],
                                        setor="Indústria", porte=["Microempresa"])
```

```r
df <- get_estoque_emprego_porte_nacional("divisao", codigos_cnae = "10",
                                         setor = "Indústria", porte = "Microempresa")
```

Valores válidos: `porte` = `Microempresa`, `Empresa de pequeno porte`,
`Empresa de médio porte`, `Grande empresa`; `setor` = `Indústria`,
`Comércio e Serviços`; `nivel_cnae` = `divisao`, `grupo`, `classe`.

### Referências

- SEBRAE; DIEESE. *Anuário do Trabalho na Micro e Pequena Empresa* (edições
  2010-2011 a 2016). Critério de porte por pessoas ocupadas e setor:
  <https://www.dieese.org.br/anuario/2011/anuarioSebrae10-11/15.html>.
- MTE. *Relação Anual de Informações Sociais (RAIS)* — microdados de
  estabelecimentos, via Base dos Dados:
  <https://basedosdados.org/dataset/br-me-rais>.

## 3. Índice Potec (Pessoal Ocupado Técnico-Científico)

### Fonte

O Potec (Pessoal Ocupado Técnico-Científico) é a *proxy* da **PINTEC** (Pesquisa
de Inovação, IBGE) construída pelo IPEA a partir da RAIS. A PINTEC mede os gastos
empresariais em inovação e P&D, mas não é anual; o Potec reproduz essa medida
anualmente com o pessoal técnico-científico registrado na RAIS. Estudo do IPEA:

> ARAÚJO, Bruno César Pino Oliveira de; CAVALCANTE, Luiz Ricardo; ALVES,
> Patrick Franco. **Variáveis proxy para os gastos empresariais em inovação com
> base no pessoal ocupado técnico-científico disponível na Relação Anual de
> Informações Sociais (Rais)**. *Radar: tecnologia, produção e comércio
> exterior*, Brasília: Ipea, n. 5, dez. 2009, p. 16-21.
> <http://repositorio.ipea.gov.br/handle/11058/5431>

O estudo compara o Potec com os gastos internos e externos em P&D da PINTEC e
encontra correlações entre 0,83 e 0,92 (período 2000–2005), justificando seu uso
como indicador anual de intensidade de inovação quando a PINTEC não está
disponível.

### Cálculo no SDIC

Por classe CNAE 2.0 (4 dígitos) e ano, sobre o estoque de vínculos ativos da RAIS:

```
Potec = (pesquisadores + engenheiros + profissionais científicos) / estoque total
```

| Componente (coluna) | Grupos da CBO 2002 |
|---|---|
| Pesquisadores (`estoque_pesquisadores`) | 203 |
| Engenheiros (`estoque_engenheiros`) | 202, 214, 222 |
| Profissionais científicos (`estoque_profissionais_cientificos`) | 201, 211, 212, 213, 221 |
| Total (`estoque_total`) | todos os vínculos ativos da classe |

`potec` é uma **fração entre 0 e 1** (0,33 = 33% dos vínculos da classe são
técnico-científicos), não um percentual. A composição por CBO acima é a
adotada no cálculo do SDIC; a definição original está no artigo do IPEA citado.

### Cuidados

- Classes CNAE com poucos vínculos geram razões instáveis — considere
  `estoque_total` ao interpretar.
- O Potec mede **intensidade de mão de obra técnico-científica**, não
  classifica setores em níveis tecnológicos, e não substitui a PINTEC (que mede o
  gasto declarado pelas empresas). Para intensidade tecnológica (Pavitt/OCDE)
  existe a view `rais_agregado_estoque_intensidade_pavitt`, ainda sem endpoint na API.

### Como usar

```python
from sdic_libraries.dados.emprego import get_potec_emprego
df = get_potec_emprego(codigos_classe=["7210"])   # P&D em ciências físicas e naturais
```

```r
df <- get_potec_emprego(codigos_classe = "7210")
```
