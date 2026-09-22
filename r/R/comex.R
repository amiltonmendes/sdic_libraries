#' Comex API Client para R
#'
#' Uma classe R6 para acessar dados de comércio exterior (comex) da sdic_api,
#' centralizando o acesso que hoje está espalhado em chamadas diretas à API
#' pública do MDIC (ComexStat) em múltiplos consumidores da unidade.
#'
#' Mesma estrutura de \code{\link{Emprego}} (mesmo padrão de configuração via
#' \code{.env}, tratamento de erro e paginação automática).
#'
#' @docType class
#' @importFrom R6 R6Class
#' @importFrom httr2 request req_url_query req_headers req_timeout req_perform resp_body_json resp_status req_body_json
#' @importFrom cli cli_abort cli_alert_success
#' @export
#' @keywords comex, comercio exterior, dados, api
#' @return Objeto R6 para interagir com a API de comex
#' @format \code{\link{R6Class}} object.
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
  public = list(
    #' @field base_url A URL base para a sdic_api
    base_url = NULL,

    #' @field timeout Timeout das requisições em segundos
    timeout = NULL,

    #' @field api_key Chave da API para autenticação
    api_key = NULL,

    #' @description
    #' Inicializar cliente da API de Comex com configuração automática.
    #' Variáveis de ambiente são carregadas automaticamente - nenhuma ação do usuário necessária.
    #' @param base_url Sobrescrever URL base da API auto-detectada
    #' @param timeout Timeout das requisições. Padrão 30 segundos.
    #' @param api_key Sobrescrever chave da API auto-detectada
    initialize = function(base_url = NULL, timeout = 30, api_key = NULL) {
      self$.load_env_files()

      self$base_url <- base_url %||%
                       Sys.getenv("COMEX_API_BASE_URL",
                                  "https://sdicapi.dados.ninja")

      self$timeout <- as.numeric(Sys.getenv("API_TIMEOUT", as.character(timeout)))
      resolved_api_key <- api_key %||% Sys.getenv("COMEX_API_KEY", "")
      self$api_key <- if (nzchar(resolved_api_key)) resolved_api_key else NULL

      version <- Sys.getenv("SDIC_VERSION", "0.4.0")
      cli::cli_alert_success(
        "API de Comex inicializada (v{version}) - configuração carregada automaticamente"
      )

      private$.ncm_isic_mapa_cache <- NULL
    },

    #' @description
    #' Carregar automaticamente arquivos .env (experiência fluida)
    .load_env_files = function() {
      env_locations <- c(
        file.path(getwd(), ".env"),
        file.path(Sys.getenv("HOME"), ".env"),
        "/etc/sdic/.env"
      )
      for (env_file in env_locations) {
        if (file.exists(env_file)) {
          self$.load_env_file(env_file)
          break
        }
      }
    },

    #' @description
    #' Carregar arquivo .env único
    .load_env_file = function(env_file_path) {
      tryCatch({
        lines <- readLines(env_file_path, warn = FALSE)
        for (line in lines) {
          line <- trimws(line)
          if (nchar(line) > 0 && !startsWith(line, "#") && grepl("=", line)) {
            parts <- strsplit(line, "=", fixed = TRUE)[[1]]
            if (length(parts) >= 2) {
              key <- trimws(parts[1])
              value <- trimws(paste(parts[-1], collapse = "="))
              if ((startsWith(value, '"') && endsWith(value, '"')) ||
                  (startsWith(value, "'") && endsWith(value, "'"))) {
                value <- substr(value, 2, nchar(value) - 1)
              }
              if (Sys.getenv(key, "") == "") {
                Sys.setenv(setNames(value, key))
              }
            }
          }
        }
      }, error = function(e) invisible(NULL))
    },

    #' @description
    #' Fazer uma requisição HTTP GET para a API usando httr2
    #' @param endpoint Caminho do endpoint da API
    #' @param params Parâmetros de query (opcional)
    .make_request = function(endpoint, params = NULL) {
      url <- paste0(gsub("/$", "", self$base_url), "/", gsub("^/", "", endpoint))
      req <- httr2::request(url)
      if (!is.null(params)) {
        req <- httr2::req_url_query(req, !!!params, .multi = "comma")
      }
      req <- httr2::req_headers(
        req,
        "User-Agent" = paste0("sdic-libraries-r/", Sys.getenv("SDIC_VERSION", "0.4.0")),
        "Accept" = "application/json",
        "Content-Type" = "application/json"
      )
      if (!is.null(self$api_key)) {
        req <- httr2::req_headers(req,
          "Authorization" = paste("Bearer", self$api_key),
          "x-api-key" = self$api_key
        )
      }
      req <- httr2::req_timeout(req, self$timeout)

      tryCatch({
        resp <- httr2::req_perform(req)
        if (httr2::resp_status(resp) != 200) {
          cli::cli_abort("Falha na requisição da API com código: {httr2::resp_status(resp)}")
        }
        httr2::resp_body_json(resp)
      }, error = function(e) {
        cli::cli_abort("Falha na requisição da API: {e$message}")
      })
    },

    #' @description
    #' Fazer uma requisição HTTP POST para a API usando httr2
    #' @param endpoint Caminho do endpoint da API
    #' @param body Corpo da requisição (será convertido para JSON)
    #' @param params Parâmetros de query (opcional)
    .make_post_request = function(endpoint, body = NULL, params = NULL) {
      url <- paste0(gsub("/$", "", self$base_url), "/", gsub("^/", "", endpoint))
      req <- httr2::request(url)
      if (!is.null(params)) {
        req <- httr2::req_url_query(req, !!!params, .multi = "comma")
      }
      req <- httr2::req_headers(
        req,
        "User-Agent" = paste0("sdic-libraries-r/", Sys.getenv("SDIC_VERSION", "0.4.0")),
        "Accept" = "application/json",
        "Content-Type" = "application/json"
      )
      if (!is.null(self$api_key)) {
        req <- httr2::req_headers(req,
          "Authorization" = paste("Bearer", self$api_key),
          "x-api-key" = self$api_key
        )
      }
      req <- httr2::req_timeout(req, self$timeout)
      if (!is.null(body)) {
        req <- httr2::req_body_json(req, body)
      }

      tryCatch({
        resp <- httr2::req_perform(req)
        if (httr2::resp_status(resp) != 200) {
          cli::cli_abort("Falha na requisição da API com código: {httr2::resp_status(resp)}")
        }
        httr2::resp_body_json(resp)
      }, error = function(e) {
        cli::cli_abort("Falha na requisição da API: {e$message}")
      })
    },

    #' @description
    #' Extrair itens de respostas paginadas
    #' @param response Resposta da API
    .extract_items = function(response) {
      if (is.list(response) && !is.null(response$items)) {
        return(response$items %||% list())
      }
      if (is.list(response) && is.null(names(response))) {
        return(response)
      }
      return(list())
    },

    #' @description
    #' Ler total de registros quando disponível (`count`)
    #' @param response Resposta da API
    .get_total_count = function(response) {
      if (!is.list(response)) return(NULL)
      value <- response$count
      if (!is.null(value) && is.numeric(value) && value >= 0) return(as.integer(value))
      return(NULL)
    },

    #' @description
    #' Consolidar automaticamente todas as páginas de endpoints GET
    #' @param endpoint Endpoint da API
    #' @param params Lista de parâmetros de query
    .fetch_all_paginated_get = function(endpoint, params = list()) {
      all_items <- list()
      pagina <- 1
      total_count <- NULL

      repeat {
        request_params <- params
        request_params$pagina <- pagina
        if (is.null(request_params$tamanho_pagina)) request_params$tamanho_pagina <- 1000
        page_size <- as.integer(request_params$tamanho_pagina %||% 1000)

        response <- self$.make_request(endpoint, request_params)
        items <- self$.extract_items(response)
        if (length(items) == 0) break

        all_items <- c(all_items, items)

        if (is.null(total_count)) total_count <- self$.get_total_count(response)
        if (!is.null(total_count) && length(all_items) >= total_count) break
        if (length(items) < page_size) break

        pagina <- pagina + 1
      }

      return(all_items)
    },

    #' @description
    #' Consolidar automaticamente todas as páginas de endpoints POST.
    #' A paginação é embutida tanto no corpo quanto nos parâmetros de query —
    #' o endpoint de NCM (`/exportacao_agregada_ncm`) espera `pagina`/
    #' `tamanho_pagina` dentro do corpo JSON, diferente do padrão GET.
    #' @param endpoint Endpoint da API
    #' @param body Corpo da requisição
    #' @param params Lista de parâmetros de query
    .fetch_all_paginated_post = function(endpoint, body, params = list()) {
      all_items <- list()
      pagina <- 1
      total_count <- NULL

      repeat {
        request_params <- params
        request_params$pagina <- pagina
        if (is.null(request_params$tamanho_pagina)) request_params$tamanho_pagina <- 1000
        page_size <- as.integer(request_params$tamanho_pagina %||% 1000)

        request_body <- body
        request_body$pagina <- pagina
        if (is.null(request_body$tamanho_pagina)) request_body$tamanho_pagina <- page_size

        response <- self$.make_post_request(endpoint, request_body, request_params)
        items <- self$.extract_items(response)
        if (length(items) == 0) break

        all_items <- c(all_items, items)

        if (is.null(total_count)) total_count <- self$.get_total_count(response)
        if (!is.null(total_count) && length(all_items) >= total_count) break
        if (length(items) < page_size) break

        pagina <- pagina + 1
      }

      return(all_items)
    },

    # ========== CATÁLOGO NCM -> ISIC ==========

    #' @description
    #' Catálogo NCM -> ISIC (divisão e seção), `/ncm_isic_mapa_gcloud`.
    #' Catálogo estático (~13 mil códigos) — buscado uma vez e cacheado em
    #' memória na instância.
    get_ncm_isic_mapa = function() {
      if (is.null(private$.ncm_isic_mapa_cache)) {
        private$.ncm_isic_mapa_cache <- self$.fetch_all_paginated_get("/ncm_isic_mapa_gcloud", list())
      }
      return(private$.ncm_isic_mapa_cache)
    },

    #' @description
    #' Códigos NCM pertencentes a uma seção ISIC (aceita a letra, ex. `C`,
    #' ou o nome por extenso, ex. `Indústria de Transformação`).
    #' @param secao Seção ISIC (letra ou nome por extenso)
    .ncms_da_secao = function(secao) {
      mapa <- self$get_ncm_isic_mapa()
      Filter(function(linha) {
        !is.null(linha$SecaoISIC) && (identical(linha$SecaoISIC, secao) || identical(linha$NomeSecaoISIC, secao))
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
    get_exportacao_ncm_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, anos = NULL, lista_ncms = NULL, secao = NULL) {
      private$.get_ncm_nacional_mensal("/exportacao_agregada_ncm", ano_minimo, mes_maximo, anos, lista_ncms, secao)
    },

    #' @description
    #' Importações nacionais agregadas por NCM (`/importacao_agregada_ncm`). Ver `get_exportacao_ncm_nacional_mensal`.
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param anos Vetor de anos específicos (opcional)
    #' @param lista_ncms Vetor de códigos NCM (opcional)
    #' @param secao Seção ISIC para filtrar (opcional)
    get_importacao_ncm_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, anos = NULL, lista_ncms = NULL, secao = NULL) {
      private$.get_ncm_nacional_mensal("/importacao_agregada_ncm", ano_minimo, mes_maximo, anos, lista_ncms, secao)
    },

    # ========== ISIC DIVISÃO (nacional) ==========

    #' @description
    #' Exportações nacionais por divisão ISIC (`/exportacao_isic_divisao_gcloud`).
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_exportacao_isic_divisao_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      self$.fetch_all_paginated_get("/exportacao_isic_divisao_gcloud", params)
    },

    #' @description
    #' Importações nacionais por divisão ISIC (`/importacao_isic_divisao_gcloud`).
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_isic_divisao_nacional_mensal = function(ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      self$.fetch_all_paginated_get("/importacao_isic_divisao_gcloud", params)
    },

    # ========== ISIC DIVISÃO (estadual, por país) ==========

    #' @description
    #' Exportações por UF, país e divisão ISIC (`/exportacao_uf_isic_divisao_gcloud`).
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
    get_exportacao_isic_divisao_estadual_mensal = function(estado = NULL, pais = NULL, ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, bloco = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, estado = estado %||% "", pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      if (!is.null(bloco)) params$bloco <- bloco
      self$.fetch_all_paginated_get("/exportacao_uf_isic_divisao_gcloud", params)
    },

    #' @description
    #' Importações por UF, país e divisão ISIC (`/importacao_uf_isic_divisao_gcloud`). Ver `get_exportacao_isic_divisao_estadual_mensal`.
    #' @param estado Nome da UF (opcional)
    #' @param pais Nome do país (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param divisao Código de divisão ISIC (opcional)
    #' @param bloco Código de bloco econômico (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_isic_divisao_estadual_mensal = function(estado = NULL, pais = NULL, ano_minimo = NULL, mes_maximo = NULL, secao = NULL, divisao = NULL, bloco = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, estado = estado %||% "", pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      if (!is.null(divisao)) params$divisao <- divisao
      if (!is.null(bloco)) params$bloco <- bloco
      self$.fetch_all_paginated_get("/importacao_uf_isic_divisao_gcloud", params)
    },

    # ========== PAÍS (nacional) ==========

    #' @description
    #' Exportações nacionais por país (`/exportacao_pais_gcloud`).
    #' @param pais Nome do país (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_exportacao_pais_nacional_mensal = function(pais = NULL, secao = NULL, ano_minimo = NULL, mes_maximo = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      self$.fetch_all_paginated_get("/exportacao_pais_gcloud", params)
    },

    #' @description
    #' Importações nacionais por país (`/importacao_pais_gcloud`).
    #' @param pais Nome do país (opcional)
    #' @param secao Seção ISIC (opcional)
    #' @param ano_minimo Ano mínimo (opcional)
    #' @param mes_maximo Mês máximo (opcional)
    #' @param agregado_ano Se TRUE, agrega por ano (sem mês)
    get_importacao_pais_nacional_mensal = function(pais = NULL, secao = NULL, ano_minimo = NULL, mes_maximo = NULL, agregado_ano = FALSE) {
      params <- list(ano_minimo = ano_minimo %||% 0, mes_maximo = mes_maximo %||% 0, pais = pais %||% "", secao = secao %||% "", agregado_ano = agregado_ano)
      self$.fetch_all_paginated_get("/importacao_pais_gcloud", params)
    }
  ),
  private = list(
    .ncm_isic_mapa_cache = NULL,

    .get_ncm_nacional_mensal = function(endpoint, ano_minimo, mes_maximo, anos, lista_ncms, secao) {
      body <- list(
        ano_minimo = ano_minimo %||% 0,
        mes_maximo = mes_maximo %||% 0,
        anos = anos %||% list(),
        lista_ncms = lista_ncms %||% list()
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
