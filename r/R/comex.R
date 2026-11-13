#' Cliente da sdic_api para comércio exterior (ComexStat)
#'
#' Classe R6 de baixo nível: uma requisição por chamada (com todas as páginas) e resposta
#' como lista de registros, com as colunas como a API devolve. Para tabelas (`tibble`) no
#' esquema padrão da biblioteca, use as funções `get_*` de comex (veja
#' `listar_bases(tema = "comex")`). A biblioteca só consulta a sdic_api, nunca o ComexStat
#' diretamente.
#'
#' Endereço, chave e tempo limite vêm de [sdic_config()] (`SDIC_API_URL`, `SDIC_API_KEY`,
#' `SDIC_TIMEOUT`, em variável de ambiente ou `.env.local`); os argumentos de `$new()` têm
#' precedência. A chave fica em campo privado e não aparece em `print()`.
#'
#' @docType class
#' @importFrom R6 R6Class
#' @importFrom httr2 request req_url_query req_headers req_timeout req_perform resp_body_json resp_status req_body_json
#' @export
#' @keywords comex, comercio exterior, dados, api
#' @return Objeto R6 para interagir com as rotas de comex da sdic_api
#' @format Classe [R6::R6Class], herdeira de `ClienteAPI`.
#' @examples
#' \dontrun{
#' api <- Comex$new()
#'
#' # Exportações nacionais por divisão ISIC, seção C, 2023 em diante
#' dados <- api$get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2023, secao = "Indústria de Transformação")
#'
#' # Exportações por UF/país, recorte União Europeia (bloco 22)
#' dados_ue <- api$get_exportacao_isic_divisao_estadual_mensal(ano_minimo = 2023, bloco = 22)
#' }
Comex <- R6::R6Class(
  "Comex",
  inherit = ClienteAPI,
  public = list(
    # ========== CATÁLOGO NCM -> ISIC ==========

    #' @description
    #' Catálogo NCM -> ISIC (divisão e seção), `/ncm_isic_mapa`.
    #' Catálogo estático (~13 mil códigos) — buscado uma vez e cacheado em
    #' memória na instância.
    get_ncm_isic_mapa = function() {
      if (is.null(private$.ncm_isic_mapa_cache)) {
        private$.ncm_isic_mapa_cache <- self$.fetch_all_paginated_get("/ncm_isic_mapa", list())
      }
      return(private$.ncm_isic_mapa_cache)
    },

    # ========== AGRUPAMENTOS ==========
    #
    # `agrupamento` é um nome de estudo setorial pré-definido no BigQuery
    # (`parametros_unidade`), com um Departamento e Coordenação-Geral (CG) responsáveis
    # — não um filtro livre. Descubra o nome com `get_agrupamentos_disponiveis()`. O
    # mesmo nome pode existir sob departamentos/CGs diferentes (não ocorre hoje nos
    # dados, mas o retorno sempre traz as duas colunas para desambiguar no seu código;
    # filtre por `departamento`/`cg` se já souber qual).
    # PENDENTE DE DEPLOY (2026-09-29): a sdic_api ainda não tem essas colunas/parâmetros
    # em produção — ver TODO.md.

    #' @description
    #' Exportações anuais por Agrupamento/Setor/Subsetor/Produto (`/exportacao_agrupamentos`)
    #' @param agrupamento Nome do agrupamento (ver `get_agrupamentos_disponiveis()`)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param anos Vetor de anos específicos (opcional)
    #' @param departamento Filtro por departamento responsável (opcional)
    #' @param cg Filtro por coordenação-geral responsável (opcional)
    get_exportacao_agrupamentos = function(agrupamento, ano_minimo = NULL, anos = NULL, departamento = NULL, cg = NULL) {
      self$.movimentacoes_agrupamentos("/exportacao_agrupamentos", agrupamento, ano_minimo, anos, departamento, cg)
    },

    #' @description
    #' Importações anuais por Agrupamento/Setor/Subsetor/Produto (`/importacao_agrupamentos`). Ver `get_exportacao_agrupamentos`.
    #' @param agrupamento Nome do agrupamento
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param anos Vetor de anos específicos (opcional)
    #' @param departamento Filtro por departamento responsável (opcional)
    #' @param cg Filtro por coordenação-geral responsável (opcional)
    get_importacao_agrupamentos = function(agrupamento, ano_minimo = NULL, anos = NULL, departamento = NULL, cg = NULL) {
      self$.movimentacoes_agrupamentos("/importacao_agrupamentos", agrupamento, ano_minimo, anos, departamento, cg)
    },

    #' @param endpoint Endpoint (interno)
    #' @param agrupamento Nome do agrupamento (interno)
    #' @param ano_minimo Ano mínimo (interno)
    #' @param anos Vetor de anos (interno)
    #' @param departamento Departamento (interno)
    #' @param cg CG (interno)
    .movimentacoes_agrupamentos = function(endpoint, agrupamento, ano_minimo, anos, departamento, cg) {
      params <- list(agrupamento = agrupamento)
      if (!is.null(ano_minimo)) params$ano_minimo <- ano_minimo
      if (!is.null(anos)) params$anos <- paste(anos, collapse = ",")
      if (!is.null(departamento)) params$departamento <- departamento
      if (!is.null(cg)) params$cg <- cg
      self$.fetch_all_paginated_get(endpoint, params)
    },

    #' @description
    #' Exportações por Agrupamento, desagregadas por país e NCM (`/exportacao_agrupamentos_pais_ncm`).
    #' `nivel_agregacao`: NULL (detalhe completo, com país e NCM) ou "setor"/"subsetor"/"produto"
    #' (soma nesse nível, sem país nem NCM). `posicao`: ranking por VLFob dentro de cada grupo.
    #' @param agrupamento Nome do agrupamento
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param nivel_agregacao NULL, "setor", "subsetor" ou "produto" (opcional)
    #' @param agregado_ano Se TRUE, soma no BigQuery (1 linha por ano) (opcional)
    #' @param posicao Ranking por VLFob dentro de cada grupo (opcional)
    #' @param departamento Filtro por departamento responsável (opcional)
    #' @param cg Filtro por coordenação-geral responsável (opcional)
    get_exportacao_agrupamentos_pais_ncm = function(agrupamento, ano_minimo = NULL, mes_maximo = NULL,
                                                     nivel_agregacao = NULL, agregado_ano = FALSE, posicao = NULL,
                                                     departamento = NULL, cg = NULL) {
      self$.movimentacoes_agrupamentos_pais_ncm("/exportacao_agrupamentos_pais_ncm", agrupamento, ano_minimo,
                                                mes_maximo, nivel_agregacao, agregado_ano, posicao, departamento, cg)
    },

    #' @description
    #' Importações por Agrupamento, desagregadas por país e NCM (`/importacao_agrupamentos_pais_ncm`). Ver `get_exportacao_agrupamentos_pais_ncm`.
    #' @param agrupamento Nome do agrupamento
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param nivel_agregacao NULL, "setor", "subsetor" ou "produto" (opcional)
    #' @param agregado_ano Se TRUE, soma no BigQuery (1 linha por ano) (opcional)
    #' @param posicao Ranking por VLFob dentro de cada grupo (opcional)
    #' @param departamento Filtro por departamento responsável (opcional)
    #' @param cg Filtro por coordenação-geral responsável (opcional)
    get_importacao_agrupamentos_pais_ncm = function(agrupamento, ano_minimo = NULL, mes_maximo = NULL,
                                                     nivel_agregacao = NULL, agregado_ano = FALSE, posicao = NULL,
                                                     departamento = NULL, cg = NULL) {
      self$.movimentacoes_agrupamentos_pais_ncm("/importacao_agrupamentos_pais_ncm", agrupamento, ano_minimo,
                                                mes_maximo, nivel_agregacao, agregado_ano, posicao, departamento, cg)
    },

    #' @param endpoint Endpoint (interno)
    #' @param agrupamento Nome do agrupamento (interno)
    #' @param ano_minimo Ano mínimo (interno)
    #' @param mes_maximo Mês máximo (interno)
    #' @param nivel_agregacao Nível de agregação (interno)
    #' @param agregado_ano Agregar por ano (interno)
    #' @param posicao Posição/ranking (interno)
    #' @param departamento Departamento (interno)
    #' @param cg CG (interno)
    .movimentacoes_agrupamentos_pais_ncm = function(endpoint, agrupamento, ano_minimo, mes_maximo, nivel_agregacao,
                                                     agregado_ano, posicao, departamento, cg) {
      params <- list(agrupamento = agrupamento, agregado_ano = agregado_ano)
      if (!is.null(ano_minimo)) params$ano_minimo <- ano_minimo
      if (!is.null(mes_maximo)) params$mes_maximo <- mes_maximo
      if (!is.null(nivel_agregacao)) params$nivel_agregacao <- nivel_agregacao
      if (!is.null(posicao)) params$posicao <- posicao
      if (!is.null(departamento)) params$departamento <- departamento
      if (!is.null(cg)) params$cg <- cg
      self$.fetch_all_paginated_get(endpoint, params)
    },

    #' @description
    #' Catálogo de agrupamentos de comex (`/agrupamentos_disponiveis`), 1 registro por
    #' (Agrupamento, Departamento, CG) — use para descobrir o nome a passar em
    #' `agrupamento=` nos outros métodos de agrupamentos, opcionalmente já filtrado.
    #' @param departamento Filtro por departamento responsável (opcional)
    #' @param cg Filtro por coordenação-geral responsável (opcional)
    get_agrupamentos_disponiveis = function(departamento = NULL, cg = NULL) {
      params <- list()
      if (!is.null(departamento)) params$departamento <- departamento
      if (!is.null(cg)) params$cg <- cg
      response <- self$.make_request("/agrupamentos_disponiveis", params)
      self$.extract_items(response)
    },

    #' @description
    #' Códigos NCM pertencentes a uma seção ISIC (aceita a letra, ex. `C`,
    #' ou o nome por extenso, ex. `Indústria de Transformação`).
    #' @param secao Seção ISIC (letra ou nome por extenso)
    .ncms_da_secao = function(secao) {
      mapa <- self$get_ncm_isic_mapa()
      Filter(function(linha) {
        any(vapply(list(linha$SecaoISIC, linha$NomeSecaoISIC, linha$CodigoSecaoISIC), identical, logical(1), secao))
      }, mapa) |> sapply(function(linha) linha$NCM)
    },

    # ========== NCM (nacional) ==========

    #' @description
    #' Exportações nacionais agregadas por NCM (`/exportacao_agregada_ncm`).
    #' `secao`, quando informada, filtra os NCMs pela seção ISIC correspondente
    #' (via `get_ncm_isic_mapa`, cacheado em memória) — o endpoint de origem
    #' não carrega essa informação.
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param anos Vetor de anos específicos (opcional)
    #' @param lista_ncms Vetor de códigos NCM (opcional)
    #' @param secao Seção ISIC para filtrar (opcional)
    #' @param agregado_ano Se TRUE, soma no BigQuery e devolve 1 linha por
    #'   (ano, NCM) em vez de por (ano, mês, NCM) — bem mais barato quando só
    #'   o total anual interessa.
    get_exportacao_ncm_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, anos = NULL, lista_ncms = NULL, secao = NULL, agregado_ano = FALSE) {
      private$.get_ncm_nacional_mensal("/exportacao_agregada_ncm", ano_minimo, mes_maximo, anos, lista_ncms, secao, agregado_ano)
    },

    #' @description
    #' Importações nacionais agregadas por NCM (`/importacao_agregada_ncm`). Ver `get_exportacao_ncm_nacional_mensal`.
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param anos Vetor de anos específicos (opcional)
    #' @param lista_ncms Vetor de códigos NCM (opcional)
    #' @param secao Seção ISIC para filtrar (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_ncm_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, anos = NULL, lista_ncms = NULL, secao = NULL, agregado_ano = FALSE) {
      private$.get_ncm_nacional_mensal("/importacao_agregada_ncm", ano_minimo, mes_maximo, anos, lista_ncms, secao, agregado_ano)
    },

    # ========== ISIC DIVISÃO (nacional) ==========

    #' @description
    #' Exportações nacionais por divisão ISIC (`/exportacao_isic_divisao`).
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_exportacao_isic_divisao_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      self$.fetch_all_paginated_get("/exportacao_isic_divisao", params)
    },

    #' @description
    #' Importações nacionais por divisão ISIC (`/importacao_isic_divisao`).
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_isic_divisao_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      self$.fetch_all_paginated_get("/importacao_isic_divisao", params)
    },

    # ========== ISIC DIVISÃO (estadual, por país) ==========

    #' @description
    #' Exportações por UF, país e divisão ISIC (`/exportacao_uf_isic_divisao`).
    #' `bloco`: código de bloco econômico (`pais_bloco.CO_BLOCO`, ex. `22`
    #' para União Europeia) para filtrar por um recorte de países.
    #' @param estado Nome da UF (opcional)
    #' @param pais Nome do país (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param bloco Código de bloco econômico (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    #' @param agregado_pais Se TRUE, soma entre países (sem a coluna Pais)
    get_exportacao_isic_divisao_estadual_mensal = function(estado = NULL, pais = NULL, ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, bloco = NULL, agregado_ano = FALSE, agregado_pais = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, estado = estado %||% "", pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano, agregado_pais = agregado_pais)
      if (!is.null(divisao)) params$divisao <- divisao
      if (!is.null(bloco)) params$bloco <- bloco
      self$.fetch_all_paginated_get("/exportacao_uf_isic_divisao", params)
    },

    #' @description
    #' Importações por UF, país e divisão ISIC (`/importacao_uf_isic_divisao`). Ver `get_exportacao_isic_divisao_estadual_mensal`.
    #' @param estado Nome da UF (opcional)
    #' @param pais Nome do país (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param bloco Código de bloco econômico (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    #' @param agregado_pais Se TRUE, soma entre países (sem a coluna Pais)
    get_importacao_isic_divisao_estadual_mensal = function(estado = NULL, pais = NULL, ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, bloco = NULL, agregado_ano = FALSE, agregado_pais = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, estado = estado %||% "", pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano, agregado_pais = agregado_pais)
      if (!is.null(divisao)) params$divisao <- divisao
      if (!is.null(bloco)) params$bloco <- bloco
      self$.fetch_all_paginated_get("/importacao_uf_isic_divisao", params)
    },

    # ========== PAÍS (nacional) ==========

    #' @description
    #' Exportações nacionais por país (`/exportacao_pais`).
    #' @param pais Nome do país (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_exportacao_pais_nacional_mensal = function(pais = NULL, secao = NULL, ano_minimo = NULL, mes_maximo = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      self$.fetch_all_paginated_get("/exportacao_pais", params)
    },

    #' @description
    #' Importações nacionais por país (`/importacao_pais`).
    #' @param pais Nome do país (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_pais_nacional_mensal = function(pais = NULL, secao = NULL, ano_minimo = NULL, mes_maximo = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      self$.fetch_all_paginated_get("/importacao_pais", params)
    }
  ),
  private = list(
    .ncm_isic_mapa_cache = NULL,
    multi = "comma",            # vetor em parâmetro de query vira "a,b"
    paginacao_no_corpo = TRUE,  # `/exportacao_agregada_ncm` espera `pagina`/`tamanho_pagina` também no corpo

    .get_ncm_nacional_mensal = function(endpoint, ano_minimo, mes_maximo, anos, lista_ncms, secao, agregado_ano = FALSE) {
      body <- list(
        ano_minimo = ano_minimo %||% 0,
        mes_maximo = mes_maximo %||% 0,
        anos = anos %||% list(),
        # NCM como texto de 8 dígitos (CO_NCM é STRING no BigQuery desde 08/10/2026);
        # aceita 4032000 ou "04032000" e funciona com a sdic_api 2.x e 3.x.
        lista_ncms = if (is.null(lista_ncms)) list() else as.list(sprintf("%08.0f", as.numeric(lista_ncms))),
        agregado_ano = agregado_ano
      )
      items <- self$.fetch_all_paginated_post(endpoint, body, list())
      if (!is.null(secao) && nzchar(secao)) {
        ncms_da_secao <- self$.ncms_da_secao(secao)
        items <- Filter(function(item) !is.null(item$NCM) && item$NCM %in% ncms_da_secao, items)
      }
      return(items)
    }
  )
)


# ========== FUNÇÕES DE CONVENIÊNCIA (tibble) ==========
#
# A classe `Comex` devolve os registros crus da sdic_api (lista de listas, colunas em
# PascalCase). As funções abaixo — mesmos nomes e parâmetros dos métodos — devolvem
# um tibble com o esquema padrão da biblioteca (snake_case, tipos fixos), o mesmo do
# Python. Contrato: `contrato/comex_amostras.json`.

.comex_colunas <- c(
  Ano = "ano", Mes = "mes",
  NCM = "ncm", DescricaoNCM = "ncm_desc",
  DivisaoISIC = "divisao_isic_cod", NomeDivisaoISIC = "divisao_isic_desc",
  SecaoISIC = "secao_isic_desc",  # nos fluxos vem o NOME da seção; no mapa, a letra
  NomeSecaoISIC = "secao_isic_desc",
  QTEstat = "quantidade_estatistica", QuantidadeEstatistica = "quantidade_estatistica",
  KgLiquido = "kg_liquido", KGLiquido = "kg_liquido", VLFob = "vl_fob",
  UF = "uf", Pais = "pais", Regiao = "regiao",
  Agrupamento = "agrupamento", Setor = "setor", Subsetor = "subsetor", Produto = "produto",
  Departamento = "departamento", CoordenacaoGeral = "coordenacao_geral"
)

#' Registros da sdic_api -> tibble com colunas snake_case e tipos fixos
#'
#' `ncm` (8 dígitos) e `divisao_isic_cod` (2 dígitos) viram texto com zeros à
#' esquerda; `ano`/`mes` são inteiros (`mes` é NA quando `agregado_ano = TRUE`).
#' @param itens Lista de registros (resposta crua de um método de `Comex`)
#' @param mapa `TRUE` para o catálogo NCM x ISIC (`SecaoISIC` é a letra da seção)
#' @return tibble
#' @keywords internal
#' @noRd
.comex_para_tibble <- function(itens, mapa = FALSE) {
  if (length(itens) == 0) return(tibble::tibble())
  df <- .lista_para_tibble(itens)
  mapeamento <- .comex_colunas
  if ("QTEstat" %in% names(df) && "QuantidadeEstatistica" %in% names(df)) df$QTEstat <- NULL  # obsoleto na API nova
  if (mapa) {
    if ("CodigoSecaoISIC" %in% names(df)) {  # API nova: `SecaoISIC` já é o nome; a letra vem em `CodigoSecaoISIC`
      df$NomeSecaoISIC <- NULL
      mapeamento[["CodigoSecaoISIC"]] <- "secao_isic_cod"
    } else {  # API antiga: `SecaoISIC` é a letra
      mapeamento[["SecaoISIC"]] <- "secao_isic_cod"
    }
  }
  renomear <- names(df) %in% names(mapeamento)
  names(df)[renomear] <- unname(mapeamento[names(df)[renomear]])
  # nulo (ex.: `nivel_agregacao` sem NCM) continua NA, não vira "      NA"
  if ("ncm" %in% names(df)) df$ncm <- ifelse(is.na(df$ncm), NA_character_, sprintf("%08.0f", as.numeric(df$ncm)))
  if ("divisao_isic_cod" %in% names(df)) df$divisao_isic_cod <- ifelse(is.na(df$divisao_isic_cod), NA_character_, sprintf("%02.0f", as.numeric(df$divisao_isic_cod)))
  if ("ano" %in% names(df)) {  # o mapa NCM x ISIC é um catálogo, sem período
    if (!"mes" %in% names(df)) df$mes <- NA
    df$ano <- as.integer(df$ano)
    df$mes <- as.integer(df$mes)
  }
  for (col in intersect(c("vl_fob", "kg_liquido", "quantidade_estatistica"), names(df))) {
    df[[col]] <- as.numeric(df[[col]])
  }
  df
}

.comex_tibble <- function(metodo, ..., mapa = FALSE) {
  api <- Comex$new()
  .comex_para_tibble(api[[metodo]](...), mapa = mapa)
}

#' Exportações nacionais por NCM como tibble
#'
#' Atalho de `Comex$get_exportacao_ncm_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_exportacao_ncm_nacional_mensal()`
#' @return tibble
#' @export
get_exportacao_ncm_nacional_mensal <- function(...) .comex_tibble("get_exportacao_ncm_nacional_mensal", ...)

#' Importações nacionais por NCM como tibble
#'
#' Atalho de `Comex$get_importacao_ncm_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_importacao_ncm_nacional_mensal()`
#' @return tibble
#' @export
get_importacao_ncm_nacional_mensal <- function(...) .comex_tibble("get_importacao_ncm_nacional_mensal", ...)

#' Exportações nacionais por divisão ISIC como tibble
#'
#' Atalho de `Comex$get_exportacao_isic_divisao_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_exportacao_isic_divisao_nacional_mensal()`
#' @return tibble
#' @export
get_exportacao_isic_divisao_nacional_mensal <- function(...) .comex_tibble("get_exportacao_isic_divisao_nacional_mensal", ...)

#' Importações nacionais por divisão ISIC como tibble
#'
#' Atalho de `Comex$get_importacao_isic_divisao_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_importacao_isic_divisao_nacional_mensal()`
#' @return tibble
#' @export
get_importacao_isic_divisao_nacional_mensal <- function(...) .comex_tibble("get_importacao_isic_divisao_nacional_mensal", ...)

#' Exportações por UF e divisão ISIC como tibble
#'
#' Atalho de `Comex$get_exportacao_isic_divisao_estadual_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_exportacao_isic_divisao_estadual_mensal()`
#' @return tibble
#' @export
get_exportacao_isic_divisao_estadual_mensal <- function(...) .comex_tibble("get_exportacao_isic_divisao_estadual_mensal", ...)

#' Importações por UF e divisão ISIC como tibble
#'
#' Atalho de `Comex$get_importacao_isic_divisao_estadual_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_importacao_isic_divisao_estadual_mensal()`
#' @return tibble
#' @export
get_importacao_isic_divisao_estadual_mensal <- function(...) .comex_tibble("get_importacao_isic_divisao_estadual_mensal", ...)

#' Exportações nacionais por país como tibble
#'
#' Atalho de `Comex$get_exportacao_pais_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_exportacao_pais_nacional_mensal()`
#' @return tibble
#' @export
get_exportacao_pais_nacional_mensal <- function(...) .comex_tibble("get_exportacao_pais_nacional_mensal", ...)

#' Importações nacionais por país como tibble
#'
#' Atalho de `Comex$get_importacao_pais_nacional_mensal()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_importacao_pais_nacional_mensal()`
#' @return tibble
#' @export
get_importacao_pais_nacional_mensal <- function(...) .comex_tibble("get_importacao_pais_nacional_mensal", ...)

#' Catálogo NCM x ISIC (divisão e seção) como tibble
#'
#' Atalho de `Comex$get_ncm_isic_mapa()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão (colunas snake_case, tipos fixos; ver `contrato/comex_amostras.json`).
#' @param ... Argumentos de `Comex$get_ncm_isic_mapa()`
#' @return tibble
#' @export
get_ncm_isic_mapa <- function(...) .comex_tibble("get_ncm_isic_mapa", ..., mapa = TRUE)

#' Exportações por Agrupamento como tibble
#'
#' Atalho de `Comex$get_exportacao_agrupamentos()`: mesmos argumentos, mas devolve um tibble
#' com o esquema padrão. Sempre traz `departamento`/`coordenacao_geral` na saída — descubra o
#' nome do agrupamento com `get_agrupamentos_disponiveis()`.
#' @param ... Argumentos de `Comex$get_exportacao_agrupamentos()`
#' @return tibble
#' @export
get_exportacao_agrupamentos <- function(...) .comex_tibble("get_exportacao_agrupamentos", ...)

#' Importações por Agrupamento como tibble
#'
#' Atalho de `Comex$get_importacao_agrupamentos()`. Ver `get_exportacao_agrupamentos()`.
#' @param ... Argumentos de `Comex$get_importacao_agrupamentos()`
#' @return tibble
#' @export
get_importacao_agrupamentos <- function(...) .comex_tibble("get_importacao_agrupamentos", ...)

#' Exportações por Agrupamento, país e NCM como tibble
#'
#' Atalho de `Comex$get_exportacao_agrupamentos_pais_ncm()`. Ver `get_exportacao_agrupamentos()`.
#' @param ... Argumentos de `Comex$get_exportacao_agrupamentos_pais_ncm()`
#' @return tibble
#' @export
get_exportacao_agrupamentos_pais_ncm <- function(...) .comex_tibble("get_exportacao_agrupamentos_pais_ncm", ...)

#' Importações por Agrupamento, país e NCM como tibble
#'
#' Atalho de `Comex$get_importacao_agrupamentos_pais_ncm()`. Ver `get_exportacao_agrupamentos()`.
#' @param ... Argumentos de `Comex$get_importacao_agrupamentos_pais_ncm()`
#' @return tibble
#' @export
get_importacao_agrupamentos_pais_ncm <- function(...) .comex_tibble("get_importacao_agrupamentos_pais_ncm", ...)

#' Catálogo de agrupamentos de comex como tibble
#'
#' Atalho de `Comex$get_agrupamentos_disponiveis()`: 1 linha por (Agrupamento, Departamento, CG)
#' — use para descobrir o nome a passar em `agrupamento =` nas demais funções de agrupamentos.
#' @param ... Argumentos de `Comex$get_agrupamentos_disponiveis()` (`departamento`/`cg`, opcionais)
#' @return tibble
#' @export
get_agrupamentos_disponiveis <- function(...) .comex_tibble("get_agrupamentos_disponiveis", ...)
