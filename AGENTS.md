# sdic_libraries — guia para agentes (Codex, Claude, outros)

Leitura obrigatória antes de qualquer mudança neste repositório. Cada regra aqui
existe por um motivo verificado (não uma preferência de estilo) — o "por quê" está
junto da regra para que você possa julgar exceções sozinho em vez de só obedecer.

## O que é este repositório

Biblioteca Python + R que espelha a **sdic_api** (BigQuery, via `https://sdicapi.dados.ninja`)
para dados de emprego (RAIS/CAGED) e comércio exterior (ComexStat, via sdic_api). Nunca chama
o ComexStat/MDIC nem nenhuma outra fonte diretamente — só a sdic_api. Consumida por outros
repositórios do ecossistema SDIC (`cgid_cargas`, `report_cgid`/`cgid_reports_r`, `portal_cgid`,
`produtividade_trabalho`); ver `[[sdic-ecossistema-repos]]` na memória se disponível, ou pergunte
antes de assumir que um repositório irmão não usa uma função.

## Backlog

[TODO.md](TODO.md) — leia antes de começar uma tarefa nova; pode já haver uma investigação feita
(bloqueios reais encontrados, não só "faltou tempo") para o que você está prestes a fazer.

## Arquitetura (verificada em produção, não deduzida do código)

- **Python e R são implementações paralelas, não um binding de um para o outro.** Mesmo nome de
  função, mesmas colunas, mesmo comportamento nas duas linguagens — mas cada uma tem seu próprio
  código-fonte (`python/sdic_libraries/`, `r/R/`). Toda mudança de contrato (coluna, tipo, nome)
  precisa ser feita nas duas.
- **Duas camadas de API, as DUAS são de verdade usadas por consumidores — nenhuma é "legado":**
  - Classe (`Emprego`/`Comex`, objeto R6 em R): acesso de baixo nível, 1 requisição por chamada,
    devolve lista de dicts/listas cru. Usada diretamente por `cgid_cargas` (ex.:
    `Emprego$new()$get_saldo_caged_estadual_divisao(siglas_uf = <27 UFs>)`, 1 chamada para todas
    as UFs) quando o objetivo é controlar exatamente o número de requisições.
  - Funções de módulo (`get_*`): a API recomendada para quem só quer um `DataFrame`/`tibble`.
    Internamente instanciam a classe e delegam — não duplicam lógica.
  - **Antes de propor "unificar as duas camadas em uma só", `git grep` os repositórios irmãos.**
    Uma auditoria anterior (2026-09-28) concluiu que a classe era "só uso interno" sem checar
    isso, e estava errada — `cgid_cargas` depende da classe para controlar o número de chamadas.
- **Toda função pública devolve `DataFrame`/`tibble`, nunca lista de dicts/listas cru** — é o elo
  entre este repositório e a pergunta original que motivou a biblioteca ("dataframes tornam dados
  acessíveis para quem não programa"). Se você adicionar uma função nova, ela retorna tabela.
- **Esquema compartilhado testado, não documentado de memória:** `contrato/*_amostras.json` tem
  linhas reais da sdic_api (capturadas ao vivo) + o esquema esperado; `python/tests/test_*_contrato.py`
  e `r/tests/testthat/test-*-contrato.R` leem o MESMO arquivo. Mudou uma coluna/tipo da API ou da
  biblioteca? Atualize o contrato (com uma chamada real, não um exemplo inventado) antes do código.
- **`listar_bases()`** (Python: `from sdic_libraries import listar_bases`; R: exportada) é o
  catálogo curado das funções recomendadas — não é gerado automaticamente. Adicionou, renomeou ou
  aposentou uma função pública? Atualize `python/sdic_libraries/catalogo.py` e `r/R/catalogo.R`
  juntos (mesmas linhas, mesmas duas colunas de exemplo). Os testes de catálogo conferem que toda
  função listada existe de verdade — não conferem que o catálogo está completo.

## Antes de remover ou "simplificar" qualquer função pública

**Isso já causou uma correção pública nesta sessão — leia com atenção.**

1. `git grep -n "<nome_da_funcao>"` em TODOS os repositórios irmãos (`cgid_cargas`,
   `cgid_reports_r`, `report_cgid`, `portal_cgid`, `subsidios_sdic`, ...), não só neste repo.
   Duas funções que parecem fazer "a mesma coisa" (ex. `get_saldo_caged_nacional(codigos=[...])`
   vs. `get_saldo_emprego_nacional_mensal(codigo_cnae=...)`) podem ter uma diferença de
   assinatura real (a primeira aceita vários códigos numa chamada só; a segunda, um). Verifique a
   assinatura, não só o endpoint que ela chama.
2. Sem uso externo encontrado → pode depreciar (aviso, sem remover): Python
   `warnings.warn(..., DeprecationWarning, stacklevel=2)`; R `.Deprecated("substituta")`. Nunca
   remova de fato numa mesma sessão/PR que só descobriu a redundância.
3. Com uso externo encontrado → não remova nem substitua sozinho. Proponha ao usuário: aviso de
   depreciação primeiro, migração dos consumidores depois (em PR separado, testada lá), remoção
   só numa terceira etapa.
4. Nunca reduza a superfície pública achando que "menos funções = mais simples" sem o grep do
   passo 1 — simplicidade que quebra quem depende da biblioteca não é simplicidade.

## Qualidade de código

- Ladder do ponytail (já ativo nesta sessão por hook): antes de escrever código novo, pergunte se
  precisa existir, se já existe algo igual no repo, se a stdlib/o pacote já instalado resolve.
  Ver `.claude/` ou o hook de sessão para o texto completo.
- **Sem 3ª forma de acessar o mesmo dado.** Se uma necessidade nova parece exigir uma função nova,
  primeiro veja se um parâmetro a mais numa função existente resolve.
- **`_faixa_de_anos`/filtro de ano no cliente (Python) e o equivalente em R não são
  redundantes com `ano_minimo`/`ano_maximo` da API** — a sdic_api implantada pode estar atrás do
  código (ver seção de deploy abaixo) e ignorar esses parâmetros silenciosamente. Não remova esse
  filtro cliente-side sem confirmar que a API em produção já os respeita.
- Cache local (`python/sdic_libraries/utils/cache.py`, `r/R/cache.R`) só pode enxergar a
  **sdic_api** — nunca adicione um fallback para o ComexStat/MDIC ou qualquer outra fonte direta
  aqui; isso desfaria o motivo de a biblioteca existir (ver `README.md`, seção Comex).

## Performance

- Pagine com `tamanho_pagina=5000` (já é o padrão) e filtre no servidor
  (`ano_minimo`/`ano_maximo`/`codigos_cnae`/`agregado_ano`) antes de trazer para pandas/dplyr —
  nunca baixe a série inteira para filtrar localmente.
- Endpoints pesados (`get_estoque_emprego_uf_cbo`: ~27M linhas sem filtro) exigem filtro
  obrigatório nos exemplos/documentação, não só no código.
- Cache local (acima) é opt-in (`SDIC_CACHE_TTL`), nunca ligado por padrão — dados da SDIC mudam
  mensalmente; cache ligado por padrão serviria dado desatualizado sem avisar.

## Simplicidade de uso (o critério é "alguém que nunca programou acha a função certa")

- Toda função pública nova entra em `listar_bases()`/`catalogo.py`/`catalogo.R` no mesmo commit —
  se não é fácil de achar, não está pronta. Rode `python scripts/gerar_catalogo_md.py` depois:
  ele regenera `CATALOGO.md` e falha se `catalogo.py`/`catalogo.R` divergirem (mesma checagem do
  teste `python/tests/test_catalogo_paridade.py`).
- Prefira estender parâmetros de uma função existente a criar `..._v2`/`..._novo`/`..._alt`.
- Exemplos no README e nos docstrings usam sempre `ano_minimo`/filtro no exemplo mais simples
  possível primeiro; parâmetros avançados vêm depois, não misturados.

## Legibilidade de documentação

- Não duplique o mesmo exemplo em duas seções do README (aconteceu entre "Uso Básico" e a antiga
  "Referência detalhada das funções", ~600 linhas repetindo os mesmos exemplos — removida na
  reescrita de 2026-09-29; a referência de "qual função usar" agora é só `listar_bases()`/
  `CATALOGO.md`, não prosa no README). Se sentir vontade de listar parâmetro por função de novo,
  é sinal de que devia estar num docstring, não no README.
- Docstring de função pública sempre com 1 exemplo mínimo executável (ou `\dontrun{}` em R) —
  é a partir daí que o `catalogo.py`/`catalogo.R` tira o campo `exemplo`.
- Nomenclatura Python↔R diverge em alguns parâmetros (ex.: `uf=` em Python vs. `sigla_uf=` em R
  em `get_estoque_emprego_estadual`) — é dívida conhecida, não repita o padrão em funções novas
  (nome do parâmetro igual nas duas linguagens sempre que possível).

## Versionamento

Semver, e **sempre as duas linguagens juntas na mesma mudança** — nunca uma versão Python sem a R
correspondente (e vice-versa), mesmo que a mudança tenha afetado só uma delas. Lugares a bumpar
(todos, numa mudança só; `git grep -n "0\.5\.0"` no exemplo abaixo pra achar todos os pontos da
versão atual antes de bumpar a próxima):

- `python/pyproject.toml` (`version =`) e `python/sdic_libraries/__init__.py` (`__version__`) —
  `python/setup.py` lê a versão dali, não precisa editar os dois.
- `r/DESCRIPTION` (`Version:` e `Date:`).
- Os `os.getenv('SDIC_VERSION', '<versão>')` / `Sys.getenv("SDIC_VERSION", "<versão>")` em
  `dados/emprego/api.py`, `dados/comex/api.py`, `dados/emprego/portal.py` (Python) e
  `R/emprego.R`, `R/comex.R`, `R/portal.R` (R) — é o valor default do `User-Agent` enviado à
  sdic_api quando `SDIC_VERSION` não está no ambiente; desatualizado, a API vê a versão errada do
  cliente.
- `.env.example` (raiz) e os comentários em `python/.env.example`/`r/.env.example`.
- Footer do `README.md` (`**Versão**:`).
- `CHANGELOG.md` — uma entrada nova por versão (Adicionado/Corrigido/Descontinuado/Removido); é o
  que deixa o usuário decidir se vale a pena atualizar sem ler o diff. Referenciado em
  `python/pyproject.toml` (`Changelog =`) — não deixe esse link apontar pra um arquivo inexistente.
- Não mude o texto de blocos `.. deprecated:: <versão>` (Python) já publicados — eles marcam a
  versão em que aquele aviso específico passou a existir, não a versão atual.

Minor (`0.x.0`) para função nova ou depreciação (aviso, sem quebrar); patch (`0.x.y`) para
correção sem mudar API; major só com quebra de compatibilidade real (e aí, siga a seção "Antes de
remover ou simplificar" antes de sequer cogitar).

## Deploy e segurança

- A sdic_api **implantada** (Cloud Run, `sdicapi.dados.ninja`) frequentemente fica atrás do código
  commitado no repositório `sdic_api` — não assuma que uma mudança de schema/parâmetro já está no
  ar; teste com uma chamada real antes de declarar algo corrigido.
- Nunca commite arquivo de credencial (`*.json` de conta de serviço GCP) — já aconteceu uma vez
  (`fast-sdic-833465e6eb39.json`, chave destruída e removida em 2026-09-28) e o `.gitignore` do
  repositório `sdic_api` foi ajustado para isso. Autenticação local usa ADC
  (`gcloud auth application-default login`), nunca arquivo de chave versionado.

## Ao terminar qualquer mudança

Rode as duas suítes antes de considerar terminado:

```bash
cd python && python -m pytest tests/ -q --ignore=tests/test_emprego_cobertura_completa.py
cd ../r  && Rscript -e 'testthat::test_local(".", reporter="summary")'
```

Testes marcados como pulados ("sdic_api indisponível em 127.0.0.1:8123") são esperados sem uma
API local rodando — não são falha.
