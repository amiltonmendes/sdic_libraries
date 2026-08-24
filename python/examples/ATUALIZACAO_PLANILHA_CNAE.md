# Atualização automática da planilha de CNAE (emprego e empresas)

Documento de acompanhamento do script [`atualizar_planilha_cnae.py`](atualizar_planilha_cnae.py),
que regenera a planilha *"Lista de CNAE para medição do emprego e empresas"* a partir da
API SDIC, usando as funções da `sdic_libraries`.

- **Arquivo de origem:** `2026-04-28-Lista de CNAE para medição do emprego e empresas24082026.xlsx`
- **Aba processada:** `Dados atualizados para 2025`
- **Saída:** `examples/saida/` (planilha atualizada + `relatorio_comparacao.md` + `.csv`)
- **Fonte:** `https://sdicapi.dados.ninja` (48 endpoints, catálogo lido de `/openapi.json`)
- **Última execução:** 24/08/2026 — último mês CAGED disponível: **2025-12**

---

## 1. Situação atual em uma linha

Das **1.567 células com dado** na aba, **592 (37,8%)** são hoje reproduzíveis a partir da API.
As **975 restantes** dependem de duas lacunas de fonte de dados descritas na
[seção 5](#5-o-que-falta-para-igualar-a-planilha-de-origem).

| | Células |
|---|---:|
| Rastreadas pelo relatório | 2.021 |
| Com valor na origem | 1.567 |
| ✅ Atualizadas pela API (idênticas + divergentes) | 592 |
| ⛔ Pendentes de fonte de dados | 975 |
| ◻️ Vazias também na origem (colunas K–N) | 424 |

---

## 2. Alterações implementadas

### 2.1 Novo script `atualizar_planilha_cnae.py`

Lê o layout da aba **dinamicamente** — não há linhas nem colunas fixas no código. Cada linha é
classificada por `A`/`B` em `total_geral`, `total_lista`, `grupo` (CNAE de 3 dígitos) ou
`classe` (5 dígitos), e o roteamento das consultas segue essa classificação.

### 2.2 Preservação integral do layout

Verificado por comparação célula a célula entre origem e saída:

- as **3 linhas de cabeçalho** (1–3) permanecem idênticas, incluindo quebras de linha nos rótulos;
- as **mesclagens** (`D1:J1`, `H2:J2`, `K2:N2`, `O2:R2`, `S2:V2`, `A4:B4`, `A5:B5`) são preservadas;
- a **ordem das linhas** (`A`, `B`, `C`) e a **ordem das colunas** (A–V) não mudam — dimensão `A1:V110` nos dois arquivos;
- estilos, formatos numéricos e larguras são mantidos, pois o script abre o arquivo original com
  `openpyxl` e sobrescreve apenas os valores;
- a aba `Planilha1` é copiada sem qualquer alteração;
- as **fórmulas são mantidas como fórmulas**: coluna `G` (`=F{n}+J{n}`) e linha 5 (`=SUM(...)`),
  recalculadas pelo Excel na abertura.

### 2.3 Colunas efetivamente atualizadas

| Colunas | Conteúdo | Linhas | Função da biblioteca |
|---|---|---|---|
| `D`,`E`,`F` | Estoque 2022/2023/2024 | grupo (6–58) | `get_estoque_emprego_nacional(nivel_cnae=3, agregado=True)` |
| `D`,`E`,`F` | Estoque total nacional | linha 4 | `get_estoque_emprego_nacional(nivel_cnae=2, agregado=True)`, somado |
| `G` | Estoque 2025 projetado | todas | fórmula `=F+J` preservada |
| `H`,`I`,`J` | Saldo 2023/2024/2025 | grupo (6–58) | `get_saldo_caged_nacional('grupo')` |
| `H`,`I`,`J` | Saldo 2023/2024/2025 | classe (59–110) | `get_saldo_caged_nacional('subclasse')`, agregado pelos 5 primeiros dígitos |
| `H`,`I`,`J` | Saldo total nacional | linha 4 | `get_saldo_caged_nacional('divisao')`, somado |

### 2.4 Resolução de classe (5 díg.) via subclasse (7 díg.)

O CAGED só é publicado no nível **subclasse** (7 dígitos), mas a planilha usa **classe**
(5 dígitos) nas linhas 59–110. O script resolve isso em duas etapas:

1. busca um único mês de todas as subclasses (1.304 códigos) e monta o mapa `classe → subclasses`
   por prefixo dos 5 primeiros dígitos;
2. consulta apenas as **115 subclasses** que compõem as 52 classes da planilha e soma por classe.

Validado contra a origem: CNAE 46141 → saldo 2023 = 279 e 2024 = 347, exatamente os valores da linha 59.

### 2.5 Relatório de comparação

`relatorio_comparacao.md` (leitura) e `relatorio_comparacao.csv` (2.021 linhas, para auditoria).
Traz cobertura por coluna, resumo por resultado, as 30 maiores divergências e o inventário do
que não foi atualizado, com o motivo. Para poder comparar também as linhas de total, o relatório
avalia em Python as fórmulas `=SUM(X:X)` e `=Xn+Yn` — o arquivo gerado ainda não passou pelo Excel
e portanto não tem valores em cache.

### 2.6 Dependência adicional

`openpyxl` passou a ser necessário para rodar o exemplo. Ainda **não** foi acrescentado a
`requirements.txt` / `pyproject.toml` — ver checklist na seção 6.

---

## 3. Validação: a base confere

A coluna `D` (estoque 2022) bateu **exatamente**: 54 células atualizadas pela API, zero divergências,
mais o total da linha 5 — 55 idênticas ao todo, incluindo o total nacional de **52.790.864**. Isso confirma que a planilha de origem e a API partem da mesma base
RAIS, e que as divergências das demais colunas são de *vintage*, não de fonte.

---

## 4. Divergências esperadas (não são erro)

| Coluna | Divergentes | Δ% médio | Causa |
|---|---:|---:|---|
| `E`, `F` | 104 | −0,76% / −1,02% | A origem trazia estoque **projetado** (2022 + saldo acumulado); a API já devolve o estoque **efetivo** da RAIS. Diferença sistemática para baixo. |
| `H`, `I` | 113 | −0,07% / +0,32% | Revisões mensais do CAGED. Mediana do desvio absoluto: **2 postos**; máximo: 1.160. |
| `J` | 95 | +0,24% | A origem carregava o acumulado **jan–set/2025** (o rótulo da linha 3 já dizia "jan-dez", mas os números eram os de setembro); o arquivo gerado traz o ano **fechado**. No total nacional: 1.716.600 → 1.271.548. |
| `G` | 103 | −0,51% | Consequência aritmética de `F` e `J`. |

Um único caso de dado ausente: **CNAE 305** (fabricação de veículos militares de combate), saldo
2024 — sem registro no CAGED e também vazio na origem. Consistente, não é lacuna.

---

## 5. O que falta para igualar a planilha de origem

As 975 células pendentes se dividem em **duas lacunas**, ambas de *fonte de dados* — nenhuma é
limitação do script.

### 🔴 Lacuna 1 — Estoque no nível classe (156 células)

**Onde:** colunas `D`,`E`,`F` das linhas 59–110 (52 classes × 3 anos).

**Por quê:** `/get_estoque_emprego_nacional/` aceita apenas `nivel_cnae` **2 (divisão)** ou
**3 (grupo)**. Testado: `nivel_cnae=4` e `nivel_cnae=5` retornam **HTTP 500**, e passar um código de
5 dígitos com `nivel_cnae=3` devolve `count: 0`.

**Para fechar:**

1. **API** — aceitar `nivel_cnae=5` em `/get_estoque_emprego_nacional/` (e no `_estadual`),
   devolvendo `classe_cnae_cod` / `classe_cnae_desc` no payload. A RAIS tem a classe na origem;
   é uma questão de expor o nível de agregação.
2. **Biblioteca** — relaxar a validação `if nivel_cnae not in [2, 3]` em
   [`api.py`](../sdic_libraries/dados/emprego/api.py) (6 métodos de estoque) e estender
   `_validate_cnae_level` / `_filter_cnae_columns_by_level` para o nível `classe`.
3. **Script** — remover a exceção que hoje marca essas células como `indisponivel`
   (constante `MOTIVO_ESTOQUE_CLASSE`); o roteamento por tipo de linha já está pronto.

> **Alternativa provisória:** projetar o estoque da classe a partir do estoque do grupo,
> rateado pelo peso do saldo CAGED da classe. Produz estimativa, não o dado RAIS — só vale
> se houver aceite metodológico explícito.

### 🔴 Lacuna 2 — Estabelecimentos por porte, RAIS / metodologia Sebrae (819 células)

**Onde:** colunas `O`–`R` (2023, 411 células preenchidas) e `S`–`V` (2024, 408 células).
As colunas `K`–`N` (2022) estão **vazias também na origem** — 424 células que não exigem ação.

**Por quê:** não há na biblioteca nem na API endpoint equivalente. Existe
`/estabelecimentos/{cnae_primeiros_digitos}` — **não exposto pela biblioteca** — mas ele não serve
para estas colunas:

| Requisito da planilha | O que o endpoint entrega |
|---|---|
| Recorte anual (2022, 2023, 2024) | ❌ retrato único, sem campo de ano |
| 4 portes (micro, pequeno, médio, grande) | ❌ 3 portes — "Demais" funde médio + grande |
| CNAE de 3 e 5 dígitos | ❌ só 2–3 dígitos (`maxLength: 3`; 5 dígitos → HTTP 422) |
| Universo RAIS / metodologia Sebrae | ❌ ordem de grandeza incompatível: CNAE 141 → **305.580** micro contra **77.357** na planilha, indicando cadastro de CNPJ e não RAIS |

**Para fechar:**

1. **Carga** — publicar a tabela de estabelecimentos da RAIS por porte Sebrae, com as chaves
   `ano`, `cnae` (classe e grupo), `porte` (4 faixas) e `contagem`.
2. **API** — novo endpoint, p.ex. `GET /estabelecimentos_rais/{nivel_cnae}` com filtros
   `codigos_cnae`, `anos` e `portes`, paginado como os demais.
3. **Biblioteca** — expor `get_estabelecimentos_rais_nacional(...)` em
   `dados/emprego/api.py` e reexportar em `dados/emprego/__init__.py`.
4. **Script** — trocar `_registrar_estabelecimentos` (que hoje só registra a indisponibilidade)
   por uma escrita real, usando o mapa `COLUNAS_ESTABELECIMENTOS`, que já associa ano → 4 colunas.

> **Nota:** vale decidir à parte se `/estabelecimentos/{cnae}` deve ser exposto pela biblioteca
> como funcionalidade própria (cadastro de CNPJ por UF e porte). É um dado útil, mas **não** é o
> dado destas colunas e não deve ser escrito nelas.

---

## 6. Checklist

**Concluído**

- [x] Mapear a cobertura de cada coluna contra a biblioteca e os 48 endpoints da API
- [x] Script que regenera a planilha preservando cabeçalho, ordem de linhas/colunas, mesclagens e fórmulas
- [x] Resolução classe → subclasse para o saldo CAGED das linhas 59–110
- [x] Relatório de comparação origem × gerado (Markdown + CSV)
- [x] Validar a base pela coluna `D` (bate exatamente, inclusive no total nacional)

**Pendente**

- [ ] Acrescentar `openpyxl` a `requirements.txt` e ao `pyproject.toml` (extra `examples`)
- [ ] **API:** suportar `nivel_cnae=5` no estoque → destrava 156 células
- [ ] **Biblioteca:** liberar o nível classe nos 6 métodos de estoque
- [ ] **Carga + API:** expor estabelecimentos RAIS/Sebrae por ano e 4 portes → destrava 819 células
- [ ] **Biblioteca:** `get_estabelecimentos_rais_nacional(...)`
- [ ] Decidir se `/estabelecimentos/{cnae}` (cadastro CNPJ) entra na biblioteca como função própria
- [ ] Definir se a linha 3 da planilha deve passar a refletir a cobertura real do CAGED
      (hoje o rótulo de `J` diz "jan-dez" e o script mantém o cabeçalho intacto, como solicitado)

---

## 7. Como executar

```bash
pip install openpyxl

cd python
python examples/atualizar_planilha_cnae.py

# opcional
python examples/atualizar_planilha_cnae.py \
    --origem "examples/<arquivo>.xlsx" \
    --aba "Dados atualizados para 2025" \
    --saida examples/saida
```

Tempo típico: ~40 s (6 cadeias de requisições paginadas).
