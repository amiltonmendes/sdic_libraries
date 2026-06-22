#' Emprego API Client para R
#'
#' Uma classe R6 para acessar dados de saldo de emprego
#' de fontes estatísticas governamentais brasileiras.
#'
#' @docType class
#' @importFrom R6 R6Class
#' @importFrom httr2 request req_url_query req_headers req_timeout req_perform resp_body_json resp_status req_body_json
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows
#' @importFrom tibble as_tibble tibble
#' @importFrom lubridate as_date
#' @importFrom cli cli_abort cli_inform
#' @importFrom rlang abort inform
#' @export
#' @keywords emprego, dados, api, saldo
#' @return Objeto R6 para interagir com APIs de saldo de emprego
#' @format \code{\link{R6Class}} object.
#' @examples
#' \dontrun{
#' # Criar cliente da API
#' api <- Emprego$new()
#' 
#' # Obter dados nacionais de saldo de emprego
#' dados <- api$get_saldo_emprego_detalhado("nacional")
#' 
#' # Obter dados estaduais para São Paulo
#' dados_sp <- api$get_saldo_emprego_detalhado("estadual", sigla_uf = "SP")
#' }
Emprego <- R6::R6Class(
  "Emprego", 
  public = list(
    #' @field base_url A URL base para a API de emprego
    base_url = NULL,
    
    #' @field timeout Timeout das requisições em segundos
    timeout = NULL,
    
    #' @field api_key Chave da API para autenticação
    api_key = NULL,
    
    #' @description
    #' Inicializar cliente da API de Emprego com configuração automática
    #' Variáveis de ambiente são carregadas automaticamente - nenhuma ação do usuário necessária!
    #' @param base_url Sobrescrever URL base da API auto-detectada
    #' @param timeout Timeout das requisições. Padrão 30 segundos.
    #' @param api_key Sobrescrever chave da API auto-detectada
    initialize = function(base_url = NULL, timeout = 30, api_key = NULL) {
      # Carregar arquivos de ambiente automaticamente (funciona pronto para uso)
      self$.load_env_files()
      
      # Configuração inteligente com fallbacks
      self$base_url <- base_url %||%
                       Sys.getenv("EMPLOYMENT_API_BASE_URL",
                                  "https://api.example.com")  # Configure via env EMPLOYMENT_API_BASE_URL
      
      self$timeout <- as.numeric(Sys.getenv("API_TIMEOUT", as.character(timeout)))
      self$api_key <- api_key %||% Sys.getenv("EMPLOYMENT_API_KEY", "")
      
      # Mostrar mensagem de inicialização
      version <- Sys.getenv("SDIC_VERSION", "0.3.1")
      cli::cli_alert_success(
        "API de Emprego inicializada (v{version}) - configuração carregada automaticamente"
      )
    },
    
    #' @description
    #' Carregar automaticamente arquivos .env (experiência fluida)
    .load_env_files = function() {
      env_locations <- c(
        file.path(getwd(), ".env"),          # Diretório atual
        file.path(Sys.getenv("HOME"), ".env"), # Home do usuário
        "/etc/sdic/.env"                      # Sistema
      )
      
      for (env_file in env_locations) {
        if (file.exists(env_file)) {
          self$.load_env_file(env_file)
          break  # Usar o primeiro encontrado
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
      }, error = function(e) {
        invisible(NULL)
      })
    },
    
    #' @description
    #' Fazer uma requisição HTTP para a API usando httr2 moderno
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
        "User-Agent" = paste0("sdic-libraries-r/", Sys.getenv("SDIC_VERSION", "0.3.1")),
        "Accept" = "application/json",
        "Content-Type" = "application/json"
      )
      
      if (!is.null(self$api_key)) {
        req <- httr2::req_headers(req, "Authorization" = paste("Bearer", self$api_key))
      }
      
      req <- httr2::req_timeout(req, self$timeout)
      
      tryCatch({
        resp <- httr2::req_perform(req)
        
        if (httr2::resp_status(resp) != 200) {
          cli::cli_abort(
            "Falha na requisição da API com código: {httr2::resp_status(resp)}"
          )
        }
        
        result <- httr2::resp_body_json(resp)
        return(result)
        
      }, error = function(e) {
        cli::cli_abort("Falha na requisição da API: {e$message}")
      })
    },
    
    #' @description
    #' Obter dados detalhados de saldo de emprego - SEMPRE RETORNA TODOS OS REGISTROS
    #' Loop automático através de todas as páginas
    #' @param nivel_agregacao Nível de agregação ('nacional', 'estadual', 'municipal')
    #' @param sigla_uf Código do estado (ex.: 'SP', 'RJ') - opcional
    #' @param uf Alias legado para sigla_uf (opcional)
    #' @param municipio Código IBGE municipal - opcional
    #' @param codigo_cnae Código de atividade econômica CNAE - opcional
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo, NULL=subclasse) - opcional
    #' @param data_minima Data mínima em formato YYYY-MM-DD - opcional
    #' @return Lista com TODOS os dados de saldo de emprego
    get_saldo_emprego_detalhado = function(nivel_agregacao,
                        sigla_uf = NULL,
                        uf = NULL,
                                          municipio = NULL,
                                          codigo_cnae = NULL,
                                          nivel_cnae = NULL,
                                          data_minima = NULL) {
      
      # Validar parâmetros obrigatórios
      valid_levels <- c("nacional", "estadual", "municipal")
      if (!nivel_agregacao %in% valid_levels) {
        stop(paste("nivel_agregacao deve ser um de:", paste(valid_levels, collapse = ", ")))
      }
      
      if (!is.null(nivel_cnae) && !nivel_cnae %in% c(2, 3)) {
        stop("nivel_cnae deve ser 2 (divisão) ou 3 (grupo), ou NULL para subclasse")
      }
      
      if (!is.null(data_minima)) {
        if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", data_minima)) {
          stop("data_minima deve estar no formato YYYY-MM-DD")
        }
      }

      nivel_endpoint <- if (is.null(nivel_cnae)) {
        "subclasse"
      } else if (nivel_cnae == 2) {
        "divisao"
      } else {
        "grupo"
      }

      endpoint <- paste0("/saldo_caged/", nivel_agregacao, "/", nivel_endpoint)
      params <- list(tamanho_pagina = 1000)

      resolved_sigla_uf <- sigla_uf %||% uf
      if (nivel_agregacao == "estadual") {
        if (is.null(resolved_sigla_uf)) {
          stop("sigla_uf é obrigatória para nível estadual")
        }
        params$siglas_uf <- as.character(resolved_sigla_uf)
      }

      if (nivel_agregacao == "municipal") {
        if (is.null(municipio)) {
          stop("municipio é obrigatório para nível municipal")
        }
        params$codigos_municipio <- as.integer(municipio)
        if (!is.null(resolved_sigla_uf)) {
          params$siglas_uf <- as.character(resolved_sigla_uf)
        }
      }

      if (!is.null(codigo_cnae)) {
        params$codigos <- as.character(codigo_cnae)
      }
      if (!is.null(data_minima)) {
        params$data_minima <- data_minima
      }

      return(self$.fetch_all_paginated_get(endpoint, params))
    },
    
    #' @description
    #' Método de conveniência para obter dados de saldo de emprego como tibble
    #' SEMPRE RETORNA TODOS OS DADOS - sem paginação para o usuário
    #' @param ... Argumentos para passar para get_saldo_emprego_detalhado()
    #' @return Um tibble com todos os dados de saldo de emprego
    get_saldo_emprego_as_tibble = function(...) {
      items <- self$get_saldo_emprego_detalhado(...)
      
      if (length(items) > 0) {
        return(tibble::as_tibble(dplyr::bind_rows(items)))
      } else {
        return(tibble::tibble())
      }
    },
    
    #' @description
    #' Alias para compatibilidade - agora todas as funções sempre retornam todos os dados
    #' @param ... Argumentos para passar para get_saldo_emprego_detalhado()
    #' @return Um tibble com todos os dados de saldo de emprego
    get_all_pages = function(...) {
      return(self$get_saldo_emprego_as_tibble(...))
    },
    
    #' @description
    #' Obter dados detalhados de saldo de emprego para lista de códigos CNAE
    #' SEMPRE RETORNA TODOS OS REGISTROS - loop automático através de todas as páginas
    #' @param lista_cnae Vetor de códigos CNAE de atividade econômica
    #' @param nome_grupo Nome/rótulo para o grupo CNAE
    #' @param nivel_agregacao Nível de agregação ('nacional', 'estadual', 'municipal')
    #' @param sigla_uf Código do estado (ex.: 'SP', 'RJ') - opcional
    #' @param uf Alias legado para sigla_uf (opcional)
    #' @param municipio Código IBGE municipal - opcional
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo, NULL=subclasse) - opcional
    #' @param data_minima Data mínima em formato YYYY-MM-DD - opcional
    #' @return Lista com todos os registros de saldo de emprego
    get_saldo_emprego_detalhado_lista_cnae = function(lista_cnae,
                                                      nome_grupo,
                                                      nivel_agregacao,
                                                      sigla_uf = NULL,
                                                      uf = NULL,
                                                      municipio = NULL,
                                                      nivel_cnae = NULL,
                                                      data_minima = NULL) {
      
      # Validar parâmetros obrigatórios
      if (is.null(lista_cnae) || length(lista_cnae) == 0) {
        stop("lista_cnae deve conter pelo menos um código CNAE")
      }
      
      valid_levels <- c("nacional", "estadual", "municipal")
      if (!nivel_agregacao %in% valid_levels) {
        stop(paste("nivel_agregacao deve ser um de:", paste(valid_levels, collapse = ", ")))
      }
      
      if (!is.null(nivel_cnae) && !nivel_cnae %in% c(2, 3)) {
        stop("nivel_cnae deve ser 2 (divisão) ou 3 (grupo), ou NULL para subclasse")
      }
      
      if (!is.null(data_minima)) {
        if (!grepl("^\\d{4}-\\d{2}-\\d{2}$", data_minima)) {
          stop("data_minima deve estar no formato YYYY-MM-DD")
        }
      }

      nivel_endpoint <- if (is.null(nivel_cnae)) {
        "subclasse"
      } else if (nivel_cnae == 2) {
        "divisao"
      } else {
        "grupo"
      }

      body <- list(codigos = as.character(lista_cnae))
      resolved_sigla_uf <- sigla_uf %||% uf
      if (!is.null(resolved_sigla_uf)) body$siglas_uf <- as.character(resolved_sigla_uf)
      if (!is.null(municipio)) body$codigos_municipio <- as.integer(municipio)
      if (!is.null(data_minima)) body$data_minima <- data_minima

      return(self$.fetch_all_paginated_post(
        paste0("/saldo_caged/", nivel_agregacao, "/", nivel_endpoint, "/lista_codigos"),
        body,
        list(tamanho_pagina = 1000)
      ))
    },
    
    #' @description
    #' Método de conveniência para obter dados de saldo de emprego para lista CNAE como tibble
    #' @param ... Argumentos para passar para get_saldo_emprego_detalhado_lista_cnae()
    #' @return Um tibble com dados de saldo de emprego
    get_saldo_emprego_lista_cnae_as_tibble = function(...) {
      items <- self$get_saldo_emprego_detalhado_lista_cnae(...)
      
      if (length(items) > 0) {
        return(tibble::as_tibble(dplyr::bind_rows(items)))
      } else {
        return(tibble::tibble())
      }
    },
    
    #' @description
    #' Fazer uma requisição HTTP POST para a API usando httr2 moderno
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
        "User-Agent" = paste0("sdic-libraries-r/", Sys.getenv("SDIC_VERSION", "0.3.1")),
        "Accept" = "application/json",
        "Content-Type" = "application/json"
      )
      
      if (!is.null(self$api_key)) {
        req <- httr2::req_headers(req, "Authorization" = paste("Bearer", self$api_key))
      }
      
      req <- httr2::req_timeout(req, self$timeout)
      
      if (!is.null(body)) {
        req <- httr2::req_body_json(req, body)
      }
      
      tryCatch({
        resp <- httr2::req_perform(req)
        
        if (httr2::resp_status(resp) != 200) {
          cli::cli_abort(
            "Falha na requisição da API com código: {httr2::resp_status(resp)}"
          )
        }
        
        result <- httr2::resp_body_json(resp)
        return(result)
        
      }, error = function(e) {
        cli::cli_abort("Falha na requisição da API: {e$message}")
      })
    },

    #' @description
    #' Normalizar aliases de campos para manter compatibilidade entre versões da API
    #' @param item Item individual da resposta
    #' @return Item normalizado
    .normalize_response_item = function(item) {
      if (!is.list(item)) {
        return(item)
      }

      if (!is.null(item$mes_referencia) && is.null(item$competencia)) {
        item$competencia <- item$mes_referencia
      }
      if (!is.null(item$competencia) && is.null(item$mes_referencia)) {
        item$mes_referencia <- item$competencia
      }

      if (!is.null(item$ano) && is.null(item$Ano)) {
        item$Ano <- item$ano
      }
      if (!is.null(item$Ano) && is.null(item$ano)) {
        item$ano <- item$Ano
      }

      if (!is.null(item$cod_municipio) && is.null(item$codigo_municipio)) {
        item$codigo_municipio <- item$cod_municipio
      }
      if (!is.null(item$cod_uf) && is.null(item$codigo_uf)) {
        item$codigo_uf <- item$cod_uf
      }

      return(item)
    },

    #' @description
    #' Extrair itens de respostas paginadas e não paginadas
    #' @param response Resposta da API
    #' @return Lista de itens
    .extract_items = function(response) {
      if (is.list(response) && !is.null(response$items)) {
        return(lapply(response$items %||% list(), self$.normalize_response_item))
      }

      if (is.list(response) && !is.null(response$data)) {
        return(lapply(response$data %||% list(), self$.normalize_response_item))
      }

      if (is.list(response) && !is.null(response$results)) {
        return(lapply(response$results %||% list(), self$.normalize_response_item))
      }

      if (is.list(response) && !is.null(response$records)) {
        return(lapply(response$records %||% list(), self$.normalize_response_item))
      }

      if (is.list(response) && is.null(names(response))) {
        return(lapply(response, self$.normalize_response_item))
      }

      return(list())
    },

    #' @description
    #' Ler total de páginas quando disponível
    #' @param response Resposta da API
    #' @return Número total de páginas ou NULL
    .get_total_pages = function(response) {
      if (!is.list(response)) return(NULL)

      for (key in c("pages", "total_pages", "paginas", "totalPaginas")) {
        value <- response[[key]]
        if (!is.null(value) && is.numeric(value) && value > 0) {
          return(as.integer(value))
        }
      }

      return(NULL)
    },

    #' @description
    #' Ler total de registros quando disponível (API 2.0 usa count/items)
    #' @param response Resposta da API
    #' @return Contagem total ou NULL
    .get_total_count = function(response) {
      if (!is.list(response)) return(NULL)

      value <- response$count
      if (!is.null(value) && is.numeric(value) && value >= 0) {
        return(as.integer(value))
      }

      return(NULL)
    },

    #' @description
    #' Consolidar automaticamente todas as páginas de endpoints GET
    #' @param endpoint Endpoint da API
    #' @param params Lista de parâmetros de query
    #' @return Lista consolidada de itens
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

        if (is.null(total_count)) {
          total_count <- self$.get_total_count(response)
        }

        total_pages <- self$.get_total_pages(response)
        if (!is.null(total_pages) && pagina >= total_pages) break
        if (!is.null(total_count) && length(all_items) >= total_count) break
        if (length(items) < page_size) break

        pagina <- pagina + 1
      }

      return(all_items)
    },

    #' @description
    #' Consolidar automaticamente todas as páginas de endpoints POST
    #' @param endpoint Endpoint da API
    #' @param body Corpo da requisição
    #' @param params Lista de parâmetros de query
    #' @return Lista consolidada de itens
    .fetch_all_paginated_post = function(endpoint, body, params = list()) {
      all_items <- list()
      pagina <- 1
      total_count <- NULL

      repeat {
        request_params <- params
        request_params$pagina <- pagina
        if (is.null(request_params$tamanho_pagina)) request_params$tamanho_pagina <- 1000
        page_size <- as.integer(request_params$tamanho_pagina %||% 1000)

        response <- self$.make_post_request(endpoint, body, request_params)
        items <- self$.extract_items(response)
        if (length(items) == 0) break

        all_items <- c(all_items, items)

        if (is.null(total_count)) {
          total_count <- self$.get_total_count(response)
        }

        total_pages <- self$.get_total_pages(response)
        if (!is.null(total_pages) && pagina >= total_pages) break
        if (!is.null(total_count) && length(all_items) >= total_count) break
        if (length(items) < page_size) break

        pagina <- pagina + 1
      }

      return(all_items)
    },

    #' @description
    #' Obter dados detalhados de saldo de emprego para grupos CNAE
    #' SEMPRE RETORNA TODOS OS REGISTROS - loop automático através de todas as páginas
    #' @param grupos_cnae Lista de grupos com nome_grupo e codigos_cnae
    #' @param nivel_agregacao Nível de agregação ('nacional', 'estadual', 'municipal')
    #' @param sigla_uf Código do estado (ex.: 'SP', 'RJ') - opcional
    #' @param uf Alias legado para sigla_uf (opcional)
    #' @param municipio Código IBGE municipal - opcional
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo, NULL=subclasse) - opcional
    #' @param data_minima Data mínima em formato YYYY-MM-DD - opcional
    #' @return Lista com todos os registros de saldo de emprego
    get_saldo_emprego_detalhado_grupos_cnae = function(grupos_cnae,
                                                       nivel_agregacao,
                                                       sigla_uf = NULL,
                                                       uf = NULL,
                                                       municipio = NULL,
                                                       nivel_cnae = NULL,
                                                       data_minima = NULL) {

      if (is.null(grupos_cnae) || length(grupos_cnae) == 0) {
        stop("grupos_cnae deve conter pelo menos um grupo")
      }

      valid_levels <- c("nacional", "estadual", "municipal")
      if (!nivel_agregacao %in% valid_levels) {
        stop(paste("nivel_agregacao deve ser um de:", paste(valid_levels, collapse = ", ")))
      }

      if (!is.null(nivel_cnae) && !nivel_cnae %in% c(2, 3)) {
        stop("nivel_cnae deve ser 2 (divisão) ou 3 (grupo), ou NULL para subclasse")
      }

      if (!is.null(data_minima) && !grepl("^\\d{4}-\\d{2}-\\d{2}$", data_minima)) {
        stop("data_minima deve estar no formato YYYY-MM-DD")
      }

      nivel_endpoint <- if (is.null(nivel_cnae)) {
        "subclasse"
      } else if (nivel_cnae == 2) {
        "divisao"
      } else {
        "grupo"
      }

      grupos_formatados <- lapply(grupos_cnae, function(grupo) {
        list(
          nome_grupo = grupo$nome_grupo %||% "Grupo",
          codigos = as.character(grupo$codigos_cnae %||% grupo$codigos %||% character(0))
        )
      })

      body <- list(grupos = grupos_formatados)

      resolved_sigla_uf <- sigla_uf %||% uf
      if (!is.null(resolved_sigla_uf)) body$siglas_uf <- as.character(resolved_sigla_uf)
      if (!is.null(municipio)) body$codigos_municipio <- as.integer(municipio)
      if (!is.null(data_minima)) body$data_minima <- data_minima

      return(self$.fetch_all_paginated_post(
        paste0("/saldo_caged/", nivel_agregacao, "/", nivel_endpoint, "/grupos_codigos"),
        body,
        list(tamanho_pagina = 1000)
      ))
    },
    
    #' @description
    #' Obter dados de estoque de emprego nacional - SEMPRE RETORNA TODOS OS REGISTROS
    #' Loop automático através de todas as páginas
    #' @param codigos_cnae Vetor de códigos CNAE (opcional)
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo)
    #' @param agregado Se TRUE, agrega todos os estados
    #' @return Lista com TODOS os dados de estoque de emprego nacional
    get_estoque_emprego_nacional = function(codigos_cnae = NULL,
                                           nivel_cnae = 2,
                                           agregado = FALSE) {
      
      # Parâmetros base
      params <- list(
        nivel_cnae = nivel_cnae,
        agregado = agregado,
        tamanho_pagina = 1000
      )
      
      if (!is.null(codigos_cnae)) {
        params$codigos_cnae <- paste(codigos_cnae, collapse = ",")
      }
      
      return(self$.fetch_all_paginated_get("/get_estoque_emprego_nacional/", params))
    },
    
    #' @description
    #' Obter dados de estoque de emprego estadual - SEMPRE RETORNA TODOS OS REGISTROS
    #' Loop automático através de todas as páginas
    #' @param sigla_uf Sigla da UF (ex: 'SP', 'RJ')
    #' @param uf Alias legado para sigla_uf
    #' @param codigos_cnae Vetor de códigos CNAE (opcional)
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo)
    #' @return Lista com TODOS os dados de estoque de emprego estadual
    get_estoque_emprego_estadual = function(sigla_uf = NULL,
                                           uf = NULL,
                                           ufs = NULL,
                                           codigos_cnae = NULL,
                                           nivel_cnae = 2) {

      resolved_ufs <- ufs %||% sigla_uf %||% uf
      if (is.null(resolved_ufs)) {
        stop("sigla_uf (ou ufs) deve ser informada")
      }
      
      ufs_str <- if (length(resolved_ufs) > 1) paste(resolved_ufs, collapse = ",") else resolved_ufs

      # Parâmetros base
      params <- list(
        ufs = ufs_str,
        nivel_cnae = nivel_cnae,
        tamanho_pagina = 1000
      )
      
      if (!is.null(codigos_cnae)) {
        params$codigos_cnae <- paste(codigos_cnae, collapse = ",")
      }
      
      return(self$.fetch_all_paginated_get("/get_estoque_emprego_estadual/", params))
    },
    
    #' @description
    #' Obter dados de estoque de emprego para lista de códigos CNAE
    #' SEMPRE RETORNA TODOS OS REGISTROS - loop automático através de todas as páginas
    #' @param codigos_cnae Vetor de códigos CNAE
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo)
    #' @param agregado Se TRUE, agrega todos os estados (nacional)
    #' @param sigla_uf Sigla da UF para consulta estadual (opcional)
    #' @return Lista com todos os registros de estoque de emprego
    get_estoque_emprego_lista_cnae_agregado = function(codigos_cnae,
                                                      nivel_cnae = 2,
                                                      agregado = FALSE,
                                                      sigla_uf = NULL,
                                                      ufs = NULL) {
      
      if (is.null(codigos_cnae) || length(codigos_cnae) == 0) {
        stop("codigos_cnae deve conter pelo menos um código CNAE")
      }

      resolved_ufs <- ufs %||% sigla_uf
      
      params <- list(
        nivel_cnae = nivel_cnae,
        agregado = agregado,
        tamanho_pagina = 1000
      )

      # Escolher endpoint e incluir ufs como query param
      if (!is.null(resolved_ufs)) {
        ufs_str <- if (length(resolved_ufs) > 1) paste(resolved_ufs, collapse = ",") else resolved_ufs
        params$ufs <- ufs_str
        endpoint <- "/get_estoque_emprego_estadual_lista_cnae/"
      } else {
        endpoint <- "/get_estoque_emprego_nacional_lista_cnae"
      }

      body <- list(codigos_cnae = as.list(codigos_cnae))
      return(self$.fetch_all_paginated_post(endpoint, body, params))
    },
    
    #' @description
    #' Obter dados de estoque de emprego para grupos de códigos CNAE
    #' SEMPRE RETORNA TODOS OS REGISTROS - loop automático através de todas as páginas
    #' @param grupos_cnae Lista de grupos com nome_grupo e codigos_cnae
    #' @param nivel_cnae Nível CNAE (2=divisão, 3=grupo)
    #' @param agregado Se TRUE, agrega todos os estados (nacional)
    #' @param sigla_uf Sigla da UF para consulta estadual (opcional)
    #' @return Lista com todos os registros de estoque de emprego
    get_estoque_emprego_grupos_cnae = function(grupos_cnae,
                                              nivel_cnae = 2,
                                              agregado = FALSE,
                                              sigla_uf = NULL,
                                              ufs = NULL) {
      
      if (is.null(grupos_cnae) || length(grupos_cnae) == 0) {
        stop("grupos_cnae deve conter pelo menos um grupo")
      }
      
      resolved_ufs <- ufs %||% sigla_uf

      body <- grupos_cnae
      
      params <- list(
        nivel_cnae = nivel_cnae,
        agregado = agregado,
        tamanho_pagina = 1000
      )

      # Escolher endpoint e incluir ufs como query param
      if (!is.null(resolved_ufs)) {
        ufs_str <- if (length(resolved_ufs) > 1) paste(resolved_ufs, collapse = ",") else resolved_ufs
        params$ufs <- ufs_str
        endpoint <- "/get_estoque_emprego_estadual_grupos_cnae/"
      } else {
        endpoint <- "/get_estoque_emprego_nacional_grupos_cnae"
      }
      
      return(self$.fetch_all_paginated_post(endpoint, body, params))
    },

    # ======================
    # MÉTODOS CAGED - FUNCIONAIS ✅
    # ======================
    
    #' @description
    #' Obter dados CAGED nacionais por divisão CNAE
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de divisão (opcional)
    #' @return Lista com dados CAGED nacionais por divisão
    get_saldo_caged_nacional_divisao = function(data_minima = NULL, codigos = NULL) {
      params <- list(tamanho_pagina = 1000)
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/nacional/divisao", params))
    },

    #' @description
    #' Obter dados CAGED nacionais por grupo CNAE
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de grupo (opcional)
    #' @return Lista com dados CAGED nacionais por grupo
    get_saldo_caged_nacional_grupo = function(data_minima = NULL, codigos = NULL) {
      params <- list(tamanho_pagina = 1000)
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/nacional/grupo", params))
    },

    #' @description
    #' Obter dados CAGED nacionais por subclasse CNAE
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de subclasse (opcional)
    #' @return Lista com dados CAGED nacionais por subclasse
    get_saldo_caged_nacional_subclasse = function(data_minima = NULL, codigos = NULL) {
      params <- list(tamanho_pagina = 1000)
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/nacional/subclasse", params))
    },

    #' @description
    #' Obter dados CAGED estaduais por divisão CNAE
    #' @param siglas_uf Vetor de siglas dos estados (ex: c("SP", "RJ"))
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de divisão (opcional)
    #' @return Lista com dados CAGED estaduais por divisão
    get_saldo_caged_estadual_divisao = function(siglas_uf, data_minima = NULL, codigos = NULL) {
      params <- list(
        siglas_uf = paste(siglas_uf, collapse = ","),
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/estadual/divisao", params))
    },

    #' @description
    #' Obter dados CAGED estaduais por grupo CNAE
    #' @param siglas_uf Vetor de siglas dos estados (ex: c("SP", "RJ"))
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de grupo (opcional)
    #' @return Lista com dados CAGED estaduais por grupo
    get_saldo_caged_estadual_grupo = function(siglas_uf, data_minima = NULL, codigos = NULL) {
      params <- list(
        siglas_uf = paste(siglas_uf, collapse = ","),
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/estadual/grupo", params))
    },

    #' @description
    #' Obter dados CAGED estaduais por subclasse CNAE
    #' @param siglas_uf Vetor de siglas dos estados (ex: c("SP", "RJ"))
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de subclasse (opcional)
    #' @return Lista com dados CAGED estaduais por subclasse
    get_saldo_caged_estadual_subclasse = function(siglas_uf, data_minima = NULL, codigos = NULL) {
      params <- list(
        siglas_uf = paste(siglas_uf, collapse = ","),
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/estadual/subclasse", params))
    },

    #' @description
    #' Obter dados CAGED municipais por divisão CNAE
    #' @param codigos_municipio Vetor de códigos IBGE dos municípios
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de divisão (opcional)
    #' @return Lista com dados CAGED municipais por divisão
    get_saldo_caged_municipal_divisao = function(codigos_municipio, data_minima = NULL, codigos = NULL) {
      params <- list(
        codigos_municipio = paste(as.character(codigos_municipio), collapse = ","),  # 🔥 Conversão para string
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/municipal/divisao", params))
    },

    #' @description
    #' Obter dados CAGED municipais por grupo CNAE
    #' @param codigos_municipio Vetor de códigos IBGE dos municípios
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de grupo (opcional)
    #' @return Lista com dados CAGED municipais por grupo
    get_saldo_caged_municipal_grupo = function(codigos_municipio, data_minima = NULL, codigos = NULL) {
      params <- list(
        codigos_municipio = paste(as.character(codigos_municipio), collapse = ","),  # 🔥 Conversão para string
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/municipal/grupo", params))
    },

    #' @description
    #' Obter dados CAGED municipais por subclasse CNAE
    #' @param codigos_municipio Vetor de códigos IBGE dos municípios
    #' @param data_minima Data mínima no formato YYYY-MM-DD (opcional)
    #' @param codigos Vetor de códigos de subclasse (opcional)
    #' @return Lista com dados CAGED municipais por subclasse
    get_saldo_caged_municipal_subclasse = function(codigos_municipio, data_minima = NULL, codigos = NULL) {
      params <- list(
        codigos_municipio = paste(as.character(codigos_municipio), collapse = ","),  # 🔥 Conversão para string
        tamanho_pagina = 1000
      )
      if (!is.null(data_minima)) params$data_minima <- data_minima
      if (!is.null(codigos)) params$codigos <- paste(codigos, collapse = ",")
      
      return(self$.fetch_all_paginated_get("/saldo_caged/municipal/subclasse", params))
    }
  )
)

# CAMADA DE ABSTRAÇÃO - Funções públicas simplificadas para usuários finais

# Operador null coalescing
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Validar e converter nível CNAE string para int da API
#' @param nivel_cnae String do nível CNAE ('subclasse', 'divisao', 'grupo') 
#' @return Valor inteiro ou NULL correspondente
.validate_cnae_level <- function(nivel_cnae) {
  nivel_map <- list(
    'subclasse' = NULL,
    'divisao' = 2,
    'divisão' = 2,
    'grupo' = 3
  )
  
  if (!nivel_cnae %in% names(nivel_map)) {
    stop("nivel_cnae deve ser: 'subclasse', 'divisao' ou 'grupo'")
  }
  
  return(nivel_map[[nivel_cnae]])
}

#' Validar códigos CNAE e determinar nível automaticamente
#' @param codigos_cnae Vetor de códigos CNAE
#' @return String do nível determinado
.validate_cnae_codes <- function(codigos_cnae) {
  if (is.null(codigos_cnae) || length(codigos_cnae) == 0) {
    stop("Lista de códigos CNAE não pode estar vazia")
  }
  
  # Verificar se todos os códigos têm o mesmo número de dígitos
  lengths <- nchar(trimws(codigos_cnae))
  if (length(unique(lengths)) > 1) {
    stop("Todos os códigos CNAE devem ter o mesmo número de dígitos")
  }
  
  length_val <- lengths[1]
  
  # Mapear número de dígitos para nível CNAE
  if (length_val == 2) {
    return('divisao')
  } else if (length_val == 3) {
    return('grupo')
  } else if (length_val == 7) {
    return('subclasse')
  } else {
    stop("Códigos CNAE devem ter 2 dígitos (divisão), 3 dígitos (grupo) ou 7 dígitos (subclasse)")
  }
}

#' Filtrar colunas baseado no nível de agregação geográfica
#' @param df Tibble com dados
#' @param nivel_agregacao Nível de agregação
#' @return Tibble filtrado
.filter_columns_by_aggregation <- function(df, nivel_agregacao) {
  if (nrow(df) == 0) {
    return(df)
  }
  
  # Colunas a serem removidas por nível
  columns_to_remove <- list(
    'nacional' = c('uf', 'municipio', 'nome_municipio', 'sigla_uf'),
    'estadual' = c('municipio', 'nome_municipio'),
    'municipal' = c()  # Manter todas as colunas para municipal
  )
  
  remove_cols <- columns_to_remove[[nivel_agregacao]] %||% c()
  
  # Filtrar apenas colunas que existem no tibble
  existing_cols_to_remove <- intersect(remove_cols, names(df))
  
  if (length(existing_cols_to_remove) > 0) {
    df <- df[, !names(df) %in% existing_cols_to_remove, drop = FALSE]
  }
  
  return(df)
}

#' Filtrar colunas CNAE específicas dos métodos agrupados
#' @param df Tibble com dados
#' @param nivel_agregacao Nível de agregação  
#' @return Tibble filtrado
.filter_cnae_columns_for_grouped_methods <- function(df, nivel_agregacao) {
  if (nrow(df) == 0) {
    return(df)
  }
  
  # Para métodos agrupados, remover códigos CNAE específicos (mantém apenas nome_grupo)
  # Incluir campos específicos de estoque
  cnae_columns_to_remove <- c(
    'codigo_divisao', 'codigo_grupo', 'subclasse', 'secao',
    'descricao_classe', 'descricao_secao', 'descricao_grupo', 
    'descricao_divisao', 'descricao_subclasse', 'GrupoAtividadeEconomica',
    'DescricaoCnae'
  )
  
  # Filtrar apenas colunas que existem no tibble
  existing_cnae_cols_to_remove <- intersect(cnae_columns_to_remove, names(df))
  
  if (length(existing_cnae_cols_to_remove) > 0) {
    df <- df[, !names(df) %in% existing_cnae_cols_to_remove, drop = FALSE]
  }
  
  # Aplicar também filtros geográficos
  df <- .filter_columns_by_aggregation(df, nivel_agregacao)
  
  return(df)
}

#' Filtrar colunas CNAE específicas baseado no nível CNAE selecionado
#' @param df Tibble com dados
#' @param nivel_cnae Nível CNAE
#' @return Tibble filtrado
.filter_cnae_columns_by_level <- function(df, nivel_cnae) {
  if (nrow(df) == 0) {
    return(df)
  }
  
  # Colunas que sempre devem ser removidas
  always_remove <- c('nome_grupo', 'descricao_classe')
  
  # Colunas a remover baseado no nível CNAE
  level_specific_remove <- list(
    'divisao' = c(
      'codigo_grupo', 'descricao_grupo',  # Remover dados de grupo
      'subclasse', 'descricao_subclasse'  # Remover dados de subclasse
    ),
    'grupo' = c(
      'subclasse', 'descricao_subclasse'  # Remover apenas dados de subclasse
    ),
    'subclasse' = c()  # Não remover nada específico (mantém tudo exceto always_remove)
  )
  
  # Combinar colunas a remover
  cols_to_remove <- c(always_remove, level_specific_remove[[nivel_cnae]] %||% c())
  
  # Filtrar apenas colunas que existem no tibble
  existing_cols_to_remove <- intersect(cols_to_remove, names(df))
  
  if (length(existing_cols_to_remove) > 0) {
    df <- df[, !names(df) %in% existing_cols_to_remove, drop = FALSE]
  }
  
  # Garantir que código de divisão e grupo estão presentes quando necessário
  if (nivel_cnae == 'subclasse') {
    # Para subclasse, garantir que código de divisão e grupo estão presentes
    required_cols <- c('codigo_divisao', 'codigo_grupo')
    missing_cols <- setdiff(required_cols, names(df))
    if (length(missing_cols) > 0) {
      cli::cli_inform("Aviso: Colunas CNAE hierárquicas faltando: {paste(missing_cols, collapse = ', ')}")
    }
  }
  
  return(df)
}

#' Garantir que códigos CNAE hierárquicos estejam presentes
#' @param df Tibble com dados
#' @param nivel_cnae Nível CNAE
#' @return Tibble verificado
.ensure_hierarchical_cnae_columns <- function(df, nivel_cnae) {
  if (nrow(df) == 0) {
    return(df)
  }
  
  # Mapear quais colunas CNAE devem estar presentes por nível
  required_columns <- list(
    'subclasse' = c('secao', 'codigo_divisao', 'codigo_grupo', 'subclasse'),
    'grupo' = c('secao', 'codigo_divisao', 'codigo_grupo'),
    'divisao' = c('secao', 'codigo_divisao')
  )
  
  required_cols <- required_columns[[nivel_cnae]] %||% c()
  
  # Verificar se colunas necessárias existem no tibble
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    cli::cli_inform("Aviso: Colunas CNAE hierárquicas faltando: {paste(missing_cols, collapse = ', ')}")
  }
  
  return(df)
}

#' Normalizar colunas temporais de saldo para compatibilidade entre versões da API
#' @param df Tibble com dados de saldo
#' @return Tibble com competencia/mes_referencia e ano padronizados
.ensure_temporal_columns_saldo <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }

  if (!'competencia' %in% names(df) && 'mes_referencia' %in% names(df)) {
    df$competencia <- df$mes_referencia
  }
  if (!'mes_referencia' %in% names(df) && 'competencia' %in% names(df)) {
    df$mes_referencia <- df$competencia
  }

  time_candidates <- intersect(c('competencia', 'mes_referencia'), names(df))
  if (length(time_candidates) > 0) {
    parsed <- lapply(time_candidates, function(col) suppressWarnings(lubridate::as_date(df[[col]])))
    valid_counts <- vapply(parsed, function(x) sum(!is.na(x)), integer(1))

    if (any(valid_counts > 0)) {
      best_idx <- which.max(valid_counts)
      best_dates <- parsed[[best_idx]]
      df$ano <- lubridate::year(best_dates)
      df <- df[!is.na(df$ano), , drop = FALSE]
      if (!'Ano' %in% names(df)) {
        df$Ano <- df$ano
      }
      return(df)
    }
  }

  if ('ano' %in% names(df) || 'Ano' %in% names(df)) {
    df <- .normalize_ano_column(df)
    if (!'Ano' %in% names(df)) {
      df$Ano <- df$ano
    }
    return(df)
  }

  stop('Coluna temporal não encontrada: esperado competencia/mes_referencia ou ano/Ano')
}

#' Converter dados mensais de estoque para anuais (último valor de dez/ano)
#' @param df Tibble com dados de estoque (coluna Ano como data)
#' @return Tibble com dados anuais
.convert_monthly_to_annual_estoque <- function(df) {
  if (nrow(df) == 0) {
    return(df)
  }

  # Identificar coluna de data (Ano ou ano)
  ano_col <- intersect(c('Ano', 'ano'), names(df))
  if (length(ano_col) == 0) {
    return(df)
  }
  ano_col <- ano_col[1]

  df[[ano_col]] <- lubridate::as_date(df[[ano_col]])

  # Extrair ano numérico para agrupamento
  df$.ano_num <- lubridate::year(df[[ano_col]])

  # Colunas de agrupamento: todas exceto numéricas e data
  cols_numericas <- names(df)[sapply(df, is.numeric) & !names(df) %in% c('.ano_num')]
  # Manter apenas o Estoque, agrupar por demais colunas não numéricas
  cols_non_num <- setdiff(names(df), c(cols_numericas, ano_col))

  df_anual <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(cols_non_num))) %>%
    dplyr::summarise(
      dplyr::across(dplyr::all_of(cols_numericas), \(x) last(x[!is.na(x)])),
      .groups = 'drop'
    ) %>%
    dplyr::rename(Ano = .ano_num)

  return(df_anual)
}

# ========== FUNÇÕES NACIONAIS ==========

#' Obter dados mensais de saldo de emprego em nível nacional
#'
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)  
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais e informações CNAE filtradas:
#'   - Sempre remove: nome_grupo, descricao_classe
#'   - Para 'subclasse': mantém todos os códigos CNAE hierárquicos
#'   - Para 'grupo': remove código/descrição de subclasse
#'   - Para 'divisao': remove código/descrição de grupo e subclasse
#' @export
get_saldo_emprego_nacional_mensal <- function(nivel_cnae = 'subclasse', 
                                             codigo_cnae = NULL, 
                                             data_minima = NULL) {
  nivel_api <- .validate_cnae_level(nivel_cnae)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado(
    nivel_agregacao = 'nacional',
    codigo_cnae = codigo_cnae,
    nivel_cnae = nivel_api,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_columns_by_aggregation(df, 'nacional')
    df <- .filter_cnae_columns_by_level(df, nivel_cnae)
    return(df)
  } else {
    return(tibble::tibble())
  }
}

#' Obter dados anuais de saldo de emprego em nível nacional
#'
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @return Tibble com dados anuais agregados
#' @export
get_saldo_emprego_nacional_anual <- function(nivel_cnae = 'subclasse', 
                                            codigo_cnae = NULL, 
                                            ano_minimo = NULL) {
  data_minima <- if (!is.null(ano_minimo)) paste0(ano_minimo, "-01-01") else NULL
  df <- get_saldo_emprego_nacional_mensal(nivel_cnae, codigo_cnae, data_minima)
  
  if (nrow(df) == 0) {
    return(df)
  }

  df <- .ensure_temporal_columns_saldo(df)
  
  # Colunas numéricas para agregação
  cols_numericas <- names(df)[grepl("saldo|admissoes|desligamentos", names(df), ignore.case = TRUE)]
  
  # Colunas CNAE para agrupamento
  cols_cnae <- names(df)[grepl("cnae|nome|descricao|secao", names(df), ignore.case = TRUE)]
  cols_agrupamento <- c('ano', cols_cnae)
  
  # Agrupar por ano
  df_anual <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(cols_agrupamento))) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(cols_numericas), sum, na.rm = TRUE), .groups = 'drop')
  
  return(df_anual)
}

#' Obter dados mensais agrupados para lista de códigos CNAE em nível nacional
#'
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais agrupados (sem colunas CNAE específicas)
#' @export
get_saldo_emprego_nacional_mensal_agrupado <- function(nome_grupo, 
                                                      lista_cnae,
                                                      data_minima = NULL) {
  nivel_cnae_str <- .validate_cnae_codes(lista_cnae)
  nivel_cnae <- .validate_cnae_level(nivel_cnae_str)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = lista_cnae,
    nome_grupo = nome_grupo,
    nivel_agregacao = 'nacional',
    nivel_cnae = nivel_cnae,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_cnae_columns_for_grouped_methods(df, 'nacional')
    return(df)
  } else {
    return(tibble::tibble())
  }
}

# ========== FUNÇÕES ESTADUAIS ==========

#' Obter dados mensais de saldo de emprego em nível estadual
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais e informações CNAE filtradas:
#'   - Sempre remove: nome_grupo, descricao_classe
#'   - Para 'subclasse': mantém todos os códigos CNAE hierárquicos
#'   - Para 'grupo': remove código/descrição de subclasse
#'   - Para 'divisao': remove código/descrição de grupo e subclasse
#' @export
get_saldo_emprego_estadual_mensal <- function(sigla_uf,
                                             nivel_cnae = 'subclasse', 
                                             codigo_cnae = NULL, 
                                             data_minima = NULL) {
  nivel_api <- .validate_cnae_level(nivel_cnae)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado(
    nivel_agregacao = 'estadual',
    sigla_uf = sigla_uf,
    codigo_cnae = codigo_cnae,
    nivel_cnae = nivel_api,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_columns_by_aggregation(df, 'estadual')
    df <- .filter_cnae_columns_by_level(df, nivel_cnae)
    return(df)
  } else {
    return(tibble::tibble())
  }
}

#' Obter dados anuais de saldo de emprego em nível estadual
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @return Tibble com dados anuais agregados
#' @export
get_saldo_emprego_estadual_anual <- function(sigla_uf,
                                            nivel_cnae = 'subclasse', 
                                            codigo_cnae = NULL, 
                                            ano_minimo = NULL) {
  data_minima <- if (!is.null(ano_minimo)) paste0(ano_minimo, "-01-01") else NULL
  df <- get_saldo_emprego_estadual_mensal(sigla_uf, nivel_cnae, codigo_cnae, data_minima)
  
  if (nrow(df) == 0) {
    return(df)
  }

  df <- .ensure_temporal_columns_saldo(df)
  
  # Colunas numéricas para agregação
  cols_numericas <- names(df)[grepl("saldo|admissoes|desligamentos", names(df), ignore.case = TRUE)]
  
  # Colunas CNAE e geográficas para agrupamento
  cols_cnae <- names(df)[grepl("cnae|nome|descricao|secao", names(df), ignore.case = TRUE)]
  cols_geo <- names(df)[grepl("uf|estado", names(df), ignore.case = TRUE)]
  cols_agrupamento <- c('ano', cols_cnae, cols_geo)
  
  # Agrupar por ano
  df_anual <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(cols_agrupamento))) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(cols_numericas), sum, na.rm = TRUE), .groups = 'drop')
  
  return(df_anual)
}

#' Obter dados mensais agrupados para lista de códigos CNAE em nível estadual
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais agrupados (sem colunas CNAE específicas)
#' @export
get_saldo_emprego_estadual_mensal_agrupado <- function(sigla_uf,
                                                      nome_grupo, 
                                                      lista_cnae,
                                                      data_minima = NULL) {
  nivel_cnae_str <- .validate_cnae_codes(lista_cnae)
  nivel_cnae <- .validate_cnae_level(nivel_cnae_str)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = lista_cnae,
    nome_grupo = nome_grupo,
    nivel_agregacao = 'estadual',
    sigla_uf = sigla_uf,
    nivel_cnae = nivel_cnae,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_cnae_columns_for_grouped_methods(df, 'estadual')
    return(df)
  } else {
    return(tibble::tibble())
  }
}

# ========== FUNÇÕES MUNICIPAIS ==========

#' Obter dados mensais de saldo de emprego em nível municipal
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param codigo_municipio Código IBGE do município
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais e informações CNAE filtradas:
#'   - Sempre remove: nome_grupo, descricao_classe
#'   - Para 'subclasse': mantém todos os códigos CNAE hierárquicos
#'   - Para 'grupo': remove código/descrição de subclasse
#'   - Para 'divisao': remove código/descrição de grupo e subclasse
#' @export
get_saldo_emprego_municipal_mensal <- function(sigla_uf,
                                              codigo_municipio,
                                              nivel_cnae = 'subclasse', 
                                              codigo_cnae = NULL, 
                                              data_minima = NULL) {
  nivel_api <- .validate_cnae_level(nivel_cnae)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado(
    nivel_agregacao = 'municipal',
    sigla_uf = sigla_uf,
    municipio = codigo_municipio,
    codigo_cnae = codigo_cnae,
    nivel_cnae = nivel_api,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_columns_by_aggregation(df, 'municipal')
    df <- .filter_cnae_columns_by_level(df, nivel_cnae)
    return(df)
  } else {
    return(tibble::tibble())
  }
}

#' Obter dados anuais de saldo de emprego em nível municipal
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param codigo_municipio Código IBGE do município
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @return Tibble com dados anuais agregados
#' @export
get_saldo_emprego_municipal_anual <- function(sigla_uf,
                                             codigo_municipio,
                                             nivel_cnae = 'subclasse', 
                                             codigo_cnae = NULL, 
                                             ano_minimo = NULL) {
  data_minima <- if (!is.null(ano_minimo)) paste0(ano_minimo, "-01-01") else NULL
  df <- get_saldo_emprego_municipal_mensal(sigla_uf, codigo_municipio, nivel_cnae, codigo_cnae, data_minima)
  
  if (nrow(df) == 0) {
    return(df)
  }

  df <- .ensure_temporal_columns_saldo(df)
  
  # Colunas numéricas para agregação
  cols_numericas <- names(df)[grepl("saldo|admissoes|desligamentos", names(df), ignore.case = TRUE)]
  
  # Colunas CNAE e geográficas para agrupamento
  cols_cnae <- names(df)[grepl("cnae|nome|descricao|secao", names(df), ignore.case = TRUE)]
  cols_geo <- names(df)[grepl("uf|estado|municipio|cidade", names(df), ignore.case = TRUE)]
  cols_agrupamento <- c('ano', cols_cnae, cols_geo)
  
  # Agrupar por ano
  df_anual <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(cols_agrupamento))) %>%
    dplyr::summarise(dplyr::across(dplyr::all_of(cols_numericas), sum, na.rm = TRUE), .groups = 'drop')
  
  return(df_anual)
}

#' Obter dados mensais agrupados para lista de códigos CNAE em nível municipal
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param codigo_municipio Código IBGE do município
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais agrupados (sem colunas CNAE específicas)
#' @export
get_saldo_emprego_municipal_mensal_agrupado <- function(sigla_uf,
                                                       codigo_municipio,
                                                       nome_grupo, 
                                                       lista_cnae,
                                                       data_minima = NULL) {
  nivel_cnae_str <- .validate_cnae_codes(lista_cnae)
  nivel_cnae <- .validate_cnae_level(nivel_cnae_str)
  
  api <- Emprego$new()
  dados <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = lista_cnae,
    nome_grupo = nome_grupo,
    nivel_agregacao = 'municipal',
    sigla_uf = sigla_uf,
    municipio = codigo_municipio,
    nivel_cnae = nivel_cnae,
    data_minima = data_minima
  )
  
  if (length(dados) > 0) {
    df <- tibble::as_tibble(dplyr::bind_rows(dados))
    df <- .filter_cnae_columns_for_grouped_methods(df, 'municipal')
    return(df)
  } else {
    return(tibble::tibble())
  }
}

#' Obter Dados de Saldo de Emprego (Função de Conveniência)
#'
#' Função de conveniência para obter rapidamente TODOS os dados de saldo de emprego 
#' sem criar explicitamente um objeto Emprego.
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado()
#' @return Lista com todos os dados de saldo de emprego
#' @export
#' @examples
#' \dontrun{
#' # Obter dados nacionais de saldo de emprego
#' dados <- get_saldo_emprego_detalhado("nacional")
#' 
#' # Obter dados estaduais para São Paulo
#' dados_sp <- get_saldo_emprego_detalhado("estadual", sigla_uf = "SP")
#' }
get_saldo_emprego_detalhado <- function(...) {
  api <- Emprego$new()
  return(api$get_saldo_emprego_detalhado(...))
}

#' Obter Dados de Saldo de Emprego como Tibble (Função de Conveniência)
#'
#' Função de conveniência para obter rapidamente TODOS os dados de saldo de emprego 
#' como tibble sem criar explicitamente um objeto Emprego.
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado()
#' @return Um tibble com todos os dados de saldo de emprego
#' @export
#' @examples
#' \dontrun{
#' # Obter dados municipais para uma cidade específica
#' dados_cidade <- get_saldo_emprego_as_tibble("municipal", sigla_uf = "SP", municipio = 3550308)
#' }
get_saldo_emprego_as_tibble <- function(...) {
  api <- Emprego$new()
  return(api$get_saldo_emprego_as_tibble(...))
}

#' Obter Dados de Saldo de Emprego para Lista CNAE (Função de Conveniência)
#'
#' Função de conveniência para obter rapidamente TODOS os dados de saldo de emprego 
#' para uma lista de códigos CNAE sem criar explicitamente um objeto Emprego.
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado_lista_cnae()
#' @return Lista com todos os dados de saldo de emprego para os códigos CNAE especificados
#' @export
#' @examples
#' \dontrun{
#' # Obter dados de emprego de TI para o estado de São Paulo
#' dados_ti <- get_saldo_emprego_detalhado_lista_cnae(
#'   lista_cnae = c("62", "63"),
#'   nome_grupo = "Tecnologia da Informação",
#'   nivel_agregacao = "estadual",
#'   sigla_uf = "SP",
#'   nivel_cnae = 2
#' )
#' }
get_saldo_emprego_detalhado_lista_cnae <- function(...) {
  api <- Emprego$new()
  return(api$get_saldo_emprego_detalhado_lista_cnae(...))
}

#' Obter Dados de Saldo de Emprego para Lista CNAE como Tibble (Função de Conveniência)
#'
#' Função de conveniência para obter rapidamente TODOS os dados de saldo de emprego 
#' para uma lista de códigos CNAE como tibble sem criar explicitamente um objeto Emprego.
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado_lista_cnae()
#' @return Um tibble com dados de saldo de emprego para os códigos CNAE especificados
#' @export
#' @examples
#' \dontrun{
#' # Obter dados de emprego de alimentos e bebidas como tibble
#' tibble_comida <- get_saldo_emprego_lista_cnae_as_tibble(
#'   lista_cnae = c("10", "11", "12"),
#'   nome_grupo = "Alimentos e Bebidas",
#'   nivel_agregacao = "municipal",
#'   sigla_uf = "MG"
#' )
#' }
get_saldo_emprego_lista_cnae_as_tibble <- function(...) {
  api <- Emprego$new()
  return(api$get_saldo_emprego_lista_cnae_as_tibble(...))
}

#' Obter Dados de Saldo de Emprego para Grupos CNAE (Função de Conveniência)
#'
#' Função de conveniência para obter rapidamente TODOS os dados de saldo de emprego
#' para grupos nomeados de códigos CNAE sem criar explicitamente um objeto Emprego.
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado_grupos_cnae()
#' @return Lista com todos os dados de saldo de emprego para os grupos CNAE especificados
#' @export
get_saldo_emprego_detalhado_grupos_cnae <- function(...) {
  api <- Emprego$new()
  return(api$get_saldo_emprego_detalhado_grupos_cnae(...))
}

#' Obter Dados de Saldo de Emprego para Grupos CNAE como Tibble
#'
#' @param ... Argumentos para passar para Emprego$get_saldo_emprego_detalhado_grupos_cnae()
#' @return Um tibble com dados de saldo de emprego para os grupos CNAE especificados
#' @export
get_saldo_emprego_grupos_cnae_as_tibble <- function(...) {
  api <- Emprego$new()
  items <- api$get_saldo_emprego_detalhado_grupos_cnae(...)

  if (length(items) > 0) {
    return(tibble::as_tibble(dplyr::bind_rows(items)))
  }

  return(tibble::tibble())
}


# ========== FUNÇÕES DE ESTOQUE NACIONAL ==========

#' Obter dados anuais de estoque de emprego em nível nacional
#'
#' @param nivel_cnae Nível CNAE ('divisao', 'grupo')
#' @param codigos_cnae Vetor de códigos CNAE específicos (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param agregado Se TRUE, agrega todos os estados
#' @return Tibble com dados anuais de estoque de emprego
#' @export
get_estoque_emprego_nacional <- function(codigos_cnae = NULL,
                                        nivel_cnae = 2,
                                        agregado = FALSE) {
  if (!is.numeric(nivel_cnae) || !nivel_cnae %in% c(2, 3)) {
    stop("nivel_cnae deve ser 2 (divisao) ou 3 (grupo)")
  }
  
  api <- Emprego$new()
  dados <- api$get_estoque_emprego_nacional(
    codigos_cnae = codigos_cnae,
    nivel_cnae = nivel_cnae,
    agregado = agregado
  )
  
  if (length(dados) == 0) {
    return(tibble::tibble())
  }
  
  df <- tibble::as_tibble(dplyr::bind_rows(dados))
  
  # Aplicar filtros de coluna
  df <- .filter_columns_by_aggregation(df, 'nacional')
  df <- .filter_cnae_columns_by_level(df, ifelse(nivel_cnae == 2, 'divisao', 'grupo'))
  
  return(df)
}

#' Obter dados anuais de estoque agrupados para lista de códigos CNAE em nível nacional
#'
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param agregado Se TRUE, agrega todos os estados
#' @return Tibble com dados anuais agrupados por CNAE
#' @export
get_estoque_emprego_nacional_agrupado <- function(nome_grupo,
                                                 lista_cnae,
                                                 agregado = TRUE) {
  nivel_cnae_str <- .validate_cnae_codes(lista_cnae)
  nivel_cnae <- .validate_cnae_level(nivel_cnae_str)
  
  # Preparar grupos no formato esperado pela API
  grupos_cnae <- list(
    list(
      nome_grupo = nome_grupo,
      codigos_cnae = lista_cnae
    )
  )
  
  api <- Emprego$new()
  dados <- api$get_estoque_emprego_grupos_cnae(
    grupos_cnae = grupos_cnae,
    nivel_cnae = nivel_cnae,
    agregado = agregado
  )
  
  if (length(dados) == 0) {
    return(tibble::tibble())
  }
  
  df <- tibble::as_tibble(dplyr::bind_rows(dados))
  
  # Aplicar filtros de colunas específicos para métodos agrupados
  df <- .filter_cnae_columns_for_grouped_methods(df, 'nacional')
  
  return(df)
}


# ========== FUNÇÕES DE ESTOQUE ESTADUAL ==========

#' Obter dados anuais de estoque de emprego em nível estadual
#'
#' @param sigla_uf Sigla da UF ('SP', 'RJ', etc.)
#' @param nivel_cnae Nível CNAE ('divisao', 'grupo')
#' @param codigos_cnae Vetor de códigos CNAE específicos (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @return Tibble com dados anuais de estoque de emprego
#' @export
get_estoque_emprego_estadual <- function(sigla_uf,
                                        codigos_cnae = NULL,
                                        nivel_cnae = 2) {
  if (!is.numeric(nivel_cnae) || !nivel_cnae %in% c(2, 3)) {
    stop("nivel_cnae deve ser 2 (divisao) ou 3 (grupo)")
  }
  
  api <- Emprego$new()
  dados <- api$get_estoque_emprego_estadual(
    sigla_uf = sigla_uf,
    codigos_cnae = codigos_cnae,
    nivel_cnae = nivel_cnae
  )
  
  if (length(dados) == 0) {
    return(tibble::tibble())
  }
  
  df <- tibble::as_tibble(dplyr::bind_rows(dados))
  
  # Aplicar filtros de coluna
  df <- .filter_columns_by_aggregation(df, 'estadual')
  df <- .filter_cnae_columns_by_level(df, ifelse(nivel_cnae == 2, 'divisao', 'grupo'))
  
  return(df)
}

#' Obter dados anuais de estoque agrupados para lista de códigos CNAE em nível estadual
#'
#' @param sigla_uf Sigla da UF ('SP', 'RJ', etc.)
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @return Tibble com dados anuais agrupados por CNAE
#' @export
get_estoque_emprego_estadual_agrupado <- function(sigla_uf,
                                                 nome_grupo,
                                                 lista_cnae) {
  nivel_cnae_str <- .validate_cnae_codes(lista_cnae)
  nivel_cnae <- .validate_cnae_level(nivel_cnae_str)
  
  # Preparar grupos no formato esperado pela API
  grupos_cnae <- list(
    list(
      nome_grupo = nome_grupo,
      codigos_cnae = lista_cnae
    )
  )
  
  api <- Emprego$new()
  dados <- api$get_estoque_emprego_grupos_cnae(
    grupos_cnae = grupos_cnae,
    nivel_cnae = nivel_cnae,
    agregado = FALSE,
    sigla_uf = sigla_uf
  )
  
  if (length(dados) == 0) {
    return(tibble::tibble())
  }
  
  df <- tibble::as_tibble(dplyr::bind_rows(dados))
  
  # Aplicar filtros de colunas específicos para métodos agrupados
  df <- .filter_cnae_columns_for_grouped_methods(df, 'estadual')
  
  return(df)
}


# ========== FUNÇÕES DE ESTOQUE ESTIMADO ==========

#' Obter dados anuais de estoque de emprego estimado em nível nacional
#'
#' O estoque estimado combina dados reais de estoque com projeções baseadas 
#' no saldo de emprego acumulado a partir do último ano de dados reais.
#'
#' @param nivel_cnae Nível CNAE ('divisao' ou 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param ano_maximo Ano máximo para projeção (opcional, se não informado usa dados disponíveis)
#' @return Data frame com coluna 'origem' indicando 'Real' ou 'Estimação'
#' @export
get_estoque_emprego_estimado_nacional_anual <- function(nivel_cnae = 'divisao',
                                                        codigo_cnae = NULL,
                                                        ano_minimo = NULL,
                                                        ano_maximo = NULL) {
  # Validar nível CNAE
  nivel_api <- .validate_cnae_level(nivel_cnae)
  if (is.null(nivel_api)) {
    stop("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")
  }

  # 1. Obter dados reais de estoque
  nivel_num <- ifelse(nivel_cnae == 'divisao', 2, 3)
  df_estoque <- get_estoque_emprego_nacional(
    codigos_cnae = if (!is.null(codigo_cnae)) c(codigo_cnae) else NULL,
    nivel_cnae = nivel_num,
    agregado = TRUE
  )
  if (!is.null(ano_minimo) && 'Ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$Ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  if (!is.null(ano_minimo) && 'ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  
  if (nrow(df_estoque) == 0) {
    return(tibble::tibble())
  }
  
  # Padronizar coluna de ano
  if ('Ano' %in% names(df_estoque)) {
    df_estoque$ano <- lubridate::year(lubridate::as_date(df_estoque$Ano))
    df_estoque <- df_estoque[, !names(df_estoque) %in% 'Ano', drop = FALSE]
  } else if (!'ano' %in% names(df_estoque)) {
    stop("Coluna de ano não encontrada nos dados de estoque")
  }
  
  df_estoque$origem <- 'Real'
  
  # 2. Encontrar último ano de estoque real
  ultimo_ano_real <- max(df_estoque$ano, na.rm = TRUE)
  
  # 3. Obter dados de saldo a partir do ano seguinte
  ano_inicio_saldo <- ultimo_ano_real + 1
  if (!is.null(ano_maximo) && ano_inicio_saldo > ano_maximo) {
    return(df_estoque)
  }
  
  ano_limite <- if (!is.null(ano_maximo)) ano_maximo else ultimo_ano_real + 10
  
  # Obter dados de saldo anual usando função helper
  df_saldo <- .get_annual_saldo_data('nacional', nivel_cnae, codigo_cnae, 
                                     ano_inicio_saldo, ano_limite, sigla_uf = NULL)
  
  if (nrow(df_saldo) == 0) {
    return(df_estoque)
  }
  
  # 4. Calcular estoque estimado ano a ano
  df_resultado <- .calculate_cumulative_stock(df_estoque, df_saldo)
  
  return(df_resultado)
}

#' Obter dados anuais de estoque de emprego estimado em nível estadual
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param nivel_cnae Nível CNAE ('divisao' ou 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param ano_maximo Ano máximo para projeção (opcional)
#' @return Data frame com coluna 'origem' indicando 'Real' ou 'Estimação'
#' @export
get_estoque_emprego_estimado_estadual_anual <- function(sigla_uf,
                                                        nivel_cnae = 'divisao',
                                                        codigo_cnae = NULL,
                                                        ano_minimo = NULL,
                                                        ano_maximo = NULL) {
  # Validação similar à nacional
  nivel_api <- .validate_cnae_level(nivel_cnae)
  if (is.null(nivel_api)) {
    stop("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")
  }

  nivel_num <- ifelse(nivel_cnae == 'divisao', 2, 3)
  df_estoque <- get_estoque_emprego_estadual(
    sigla_uf = sigla_uf,
    codigos_cnae = if (!is.null(codigo_cnae)) c(codigo_cnae) else NULL,
    nivel_cnae = nivel_num
  )
  if (!is.null(ano_minimo) && 'Ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$Ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  if (!is.null(ano_minimo) && 'ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  
  if (nrow(df_estoque) == 0) {
    return(tibble::tibble())
  }
  
  # Padronizar coluna de ano
  if ('Ano' %in% names(df_estoque)) {
    df_estoque$ano <- lubridate::year(lubridate::as_date(df_estoque$Ano))
    df_estoque <- df_estoque[, !names(df_estoque) %in% 'Ano', drop = FALSE]
  }
  
  df_estoque$origem <- 'Real'
  ultimo_ano_real <- max(df_estoque$ano, na.rm = TRUE)
  ano_inicio_saldo <- ultimo_ano_real + 1
  
  if (!is.null(ano_maximo) && ano_inicio_saldo > ano_maximo) {
    return(df_estoque)
  }
  
  ano_limite <- if (!is.null(ano_maximo)) ano_maximo else ultimo_ano_real + 10
  
  df_saldo <- .get_annual_saldo_data('estadual', nivel_cnae, codigo_cnae, 
                                     ano_inicio_saldo, ano_limite, sigla_uf)
  
  if (nrow(df_saldo) == 0) {
    return(df_estoque)
  }
  
  df_resultado <- .calculate_cumulative_stock(df_estoque, df_saldo)
  
  return(df_resultado)
}

#' Obter dados anuais de estoque de emprego estimado em nível municipal
#'
#' NOTA: Dados de estoque em nível municipal não estão disponíveis na base atual.
#' Esta função está disponível para compatibilidade futura.
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param codigo_municipio Código IBGE do município
#' @param nivel_cnae Nível CNAE ('divisao' ou 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param ano_maximo Ano máximo para projeção (opcional)
#' @return Data frame vazio com mensagem informativa
#' @export
get_estoque_emprego_estimado_municipal_anual <- function(sigla_uf,
                                                         codigo_municipio,
                                                         nivel_cnae = 'divisao',
                                                         codigo_cnae = NULL,
                                                         ano_minimo = NULL,
                                                         ano_maximo = NULL) {
  stop(paste(
    "Dados de estoque em nível municipal não estão disponíveis na base atual.",
    "A funcionalidade de estoque estimado municipal será implementada quando",
    "os dados municipais de estoque estiverem disponíveis."
  ))
}

#' Obter dados anuais de estoque de emprego estimado agrupado por lista CNAE em nível nacional
#'
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param ano_maximo Ano máximo para projeção (opcional)
#' @return Data frame agrupado com coluna 'origem' indicando 'Real' ou 'Estimação'
#' @export
get_estoque_emprego_estimado_nacional_anual_agrupado <- function(nome_grupo,
                                                                lista_cnae,
                                                                ano_minimo = NULL,
                                                                ano_maximo = NULL) {
  df_estoque <- get_estoque_emprego_nacional_agrupado(nome_grupo, lista_cnae)
  if (!is.null(ano_minimo) && 'Ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$Ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  if (!is.null(ano_minimo) && 'ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  
  if (nrow(df_estoque) == 0) {
    return(tibble::tibble())
  }
  
  # Padronizar ano e adicionar origem
  if ('Ano' %in% names(df_estoque)) {
    df_estoque$ano <- lubridate::year(lubridate::as_date(df_estoque$Ano))
    df_estoque <- df_estoque[, !names(df_estoque) %in% 'Ano', drop = FALSE]
  }
  
  df_estoque$origem <- 'Real'
  ultimo_ano_real <- max(df_estoque$ano, na.rm = TRUE)
  ano_inicio_saldo <- ultimo_ano_real + 1
  
  if (!is.null(ano_maximo) && ano_inicio_saldo > ano_maximo) {
    return(df_estoque)
  }
  
  ano_limite <- if (!is.null(ano_maximo)) ano_maximo else ultimo_ano_real + 10
  
  # Obter saldos agrupados ano a ano
  df_saldo <- .get_grouped_annual_saldo_data('nacional', nome_grupo, lista_cnae, 
                                             ano_inicio_saldo, ano_limite, sigla_uf = NULL)
  
  if (nrow(df_saldo) == 0) {
    return(df_estoque)
  }
  
  df_resultado <- .calculate_cumulative_stock_grouped(df_estoque, df_saldo, nome_grupo)
  
  return(df_resultado)
}

#' Obter dados anuais de estoque de emprego estimado agrupado por lista CNAE em nível estadual
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.')
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE (mesmo número de dígitos)
#' @param ano_minimo Ano mínimo para filtrar dados (opcional)
#' @param ano_maximo Ano máximo para projeção (opcional)
#' @return Data frame agrupado com coluna 'origem' indicando 'Real' ou 'Estimação'
#' @export
get_estoque_emprego_estimado_estadual_anual_agrupado <- function(sigla_uf,
                                                                nome_grupo,
                                                                lista_cnae,
                                                                ano_minimo = NULL,
                                                                ano_maximo = NULL) {
  df_estoque <- get_estoque_emprego_estadual_agrupado(sigla_uf, nome_grupo, lista_cnae)
  if (!is.null(ano_minimo) && 'Ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$Ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  if (!is.null(ano_minimo) && 'ano' %in% names(df_estoque)) {
    anos <- suppressWarnings(as.integer(df_estoque$ano))
    df_estoque <- df_estoque[!is.na(anos) & anos >= ano_minimo, , drop = FALSE]
  }
  
  if (nrow(df_estoque) == 0) {
    return(tibble::tibble())
  }
  
  if ('Ano' %in% names(df_estoque)) {
    df_estoque$ano <- lubridate::year(lubridate::as_date(df_estoque$Ano))
    df_estoque <- df_estoque[, !names(df_estoque) %in% 'Ano', drop = FALSE]
  }
  
  df_estoque$origem <- 'Real'
  ultimo_ano_real <- max(df_estoque$ano, na.rm = TRUE)
  ano_inicio_saldo <- ultimo_ano_real + 1
  
  if (!is.null(ano_maximo) && ano_inicio_saldo > ano_maximo) {
    return(df_estoque)
  }
  
  ano_limite <- if (!is.null(ano_maximo)) ano_maximo else ultimo_ano_real + 10
  
  df_saldo <- .get_grouped_annual_saldo_data('estadual', nome_grupo, lista_cnae, 
                                             ano_inicio_saldo, ano_limite, sigla_uf)
  
  if (nrow(df_saldo) == 0) {
    return(df_estoque)
  }
  
  df_resultado <- .calculate_cumulative_stock_grouped(df_estoque, df_saldo, nome_grupo)
  
  return(df_resultado)
}

#' Obter dados anuais de estoque de emprego estimado agrupado em nível municipal
#'
#' @param sigla_uf Sigla do estado
#' @param codigo_municipio Código IBGE do município  
#' @param nome_grupo Nome para o grupo CNAE
#' @param lista_cnae Vetor de códigos CNAE
#' @param ano_minimo Ano mínimo (opcional)
#' @param ano_maximo Ano máximo (opcional)
#' @return Data frame vazio com mensagem informativa
#' @export
get_estoque_emprego_estimado_municipal_anual_agrupado <- function(sigla_uf,
                                                                 codigo_municipio,
                                                                 nome_grupo,
                                                                 lista_cnae,
                                                                 ano_minimo = NULL,
                                                                 ano_maximo = NULL) {
  stop(paste(
    "Dados de estoque em nível municipal não estão disponíveis na base atual.",
    "A funcionalidade de estoque estimado municipal será implementada quando",
    "os dados municipais de estoque estiverem disponíveis."
  ))
}


# ========== FUNÇÕES AUXILIARES PARA ESTOQUE ESTIMADO ==========

# Função auxiliar para obter dados anuais de saldo
.get_annual_saldo_data <- function(nivel_agregacao, nivel_cnae, codigo_cnae, 
                                   ano_inicio, ano_limite, sigla_uf = NULL) {
  dfs_saldo <- list()
  
  for (ano in ano_inicio:ano_limite) {
    tryCatch({
      if (nivel_agregacao == 'nacional') {
        df_saldo_anual <- get_saldo_emprego_nacional_anual(nivel_cnae, codigo_cnae, ano)
      } else if (nivel_agregacao == 'estadual') {
        df_saldo_anual <- get_saldo_emprego_estadual_anual(sigla_uf, nivel_cnae, codigo_cnae, ano)
      }
      
      if (nrow(df_saldo_anual) > 0) {
        df_saldo_anual <- df_saldo_anual[df_saldo_anual$ano == ano, ]
        if (nrow(df_saldo_anual) > 0) {
          dfs_saldo[[length(dfs_saldo) + 1]] <- df_saldo_anual
        }
      }
    }, error = function(e) {
      # Se falhar para algum ano, continua
    })
  }
  
  if (length(dfs_saldo) == 0) {
    return(tibble::tibble())
  }
  
  return(dplyr::bind_rows(dfs_saldo))
}

# Função auxiliar para obter dados anuais agrupados de saldo
.get_grouped_annual_saldo_data <- function(nivel_agregacao, nome_grupo, lista_cnae, 
                                           ano_inicio, ano_limite, sigla_uf = NULL) {
  dfs_saldo <- list()
  
  for (ano in ano_inicio:ano_limite) {
    tryCatch({
      if (nivel_agregacao == 'nacional') {
        df_mensal <- get_saldo_emprego_nacional_mensal_agrupado(nome_grupo, lista_cnae, 
                                                               paste0(ano, "-01-01"))
      } else if (nivel_agregacao == 'estadual') {
        df_mensal <- get_saldo_emprego_estadual_mensal_agrupado(sigla_uf, nome_grupo, lista_cnae, 
                                                              paste0(ano, "-01-01"))
      }
      
      if (nrow(df_mensal) > 0) {
        # Filtrar apenas o ano atual e agregar para anual
        df_mensal$competencia <- lubridate::as_date(df_mensal$competencia)
        df_mensal <- df_mensal[lubridate::year(df_mensal$competencia) == ano, ]
        
        if (nrow(df_mensal) > 0) {
          # Agregar para anual
          df_mensal$ano <- ano
          cols_numericas <- names(df_mensal)[grepl("(saldo|admiss|deslig)", tolower(names(df_mensal)))]
          cols_agrupamento <- c('ano', 'nome_grupo')
          if ('sigla_uf' %in% names(df_mensal)) {
            cols_agrupamento <- c(cols_agrupamento, 'sigla_uf')
          }
          
          df_anual <- df_mensal %>%
            dplyr::group_by_at(cols_agrupamento) %>%
            dplyr::summarise_at(cols_numericas, sum, na.rm = TRUE) %>%
            dplyr::ungroup()
          
          dfs_saldo[[length(dfs_saldo) + 1]] <- df_anual
        }
      }
    }, error = function(e) {
      # Continue on error
    })
  }
  
  if (length(dfs_saldo) == 0) {
    return(tibble::tibble())
  }
  
  return(dplyr::bind_rows(dfs_saldo))
}

# Função auxiliar para calcular estoque acumulado

.normalize_ano_column <- function(df) {
  if (nrow(df) == 0) return(df)

  if ('ano' %in% names(df)) {
    ano_num <- suppressWarnings(as.numeric(df$ano))
    if (all(is.na(ano_num))) {
      ano_num <- lubridate::year(lubridate::as_date(df$ano))
    }
    df$ano <- as.integer(ano_num)
  } else if ('Ano' %in% names(df)) {
    ano_num <- suppressWarnings(as.numeric(df$Ano))
    if (all(is.na(ano_num))) {
      ano_num <- lubridate::year(lubridate::as_date(df$Ano))
    }
    df$ano <- as.integer(ano_num)
    df <- df[, !names(df) %in% 'Ano', drop = FALSE]
  } else {
    stop('Coluna de ano não encontrada')
  }

  df <- df[!is.na(df$ano), , drop = FALSE]
  return(df)
}

.normalize_estoque_column <- function(df) {
  if (nrow(df) == 0) return(df)
  if ('estoque_trabalhadores' %in% names(df)) return(df)
  if ('EstoqueTrabalhadores' %in% names(df)) {
    names(df)[names(df) == 'EstoqueTrabalhadores'] <- 'estoque_trabalhadores'
    return(df)
  }
  stop('Coluna de estoque_trabalhadores não encontrada nos dados')
}

.get_saldo_column <- function(df_saldo) {
  col <- names(df_saldo)[grepl('saldo_reajustado', names(df_saldo), ignore.case = TRUE)][1]
  if (!is.na(col)) return(col)
  col <- names(df_saldo)[grepl('SaldoEmprego', names(df_saldo), ignore.case = TRUE)][1]
  if (!is.na(col)) return(col)
  stop('Coluna de saldo não encontrada nos dados')
}

.drop_saldo_columns <- function(df) {
  if (nrow(df) == 0) return(df)
  cols_drop <- names(df)[grepl('saldo_reajustado', names(df), ignore.case = TRUE)]
  if (length(cols_drop) > 0) {
    df <- df[, !names(df) %in% cols_drop, drop = FALSE]
  }
  return(df)
}

.calculate_cumulative_stock <- function(df_estoque, df_saldo) {
  df_real <- .normalize_estoque_column(.normalize_ano_column(df_estoque))
  df_real$origem <- 'Real'

  if (nrow(df_saldo) == 0) {
    return(.drop_saldo_columns(df_real[order(df_real$ano), , drop = FALSE]))
  }

  df_saldo <- .normalize_ano_column(df_saldo)
  col_saldo <- .get_saldo_column(df_saldo)

  ultimo_ano_real <- max(df_real$ano, na.rm = TRUE)
  df_saldo <- df_saldo[df_saldo$ano > ultimo_ano_real, , drop = FALSE]
  if (nrow(df_saldo) == 0) {
    return(.drop_saldo_columns(df_real[order(df_real$ano), , drop = FALSE]))
  }

  cols_agrupamento <- intersect(
    setdiff(names(df_real), c('ano', 'origem', 'estoque_trabalhadores')),
    names(df_saldo)
  )
  cols_agrupamento <- cols_agrupamento[
    !grepl('desc|descricao', cols_agrupamento, ignore.case = TRUE)
  ]

  df_base <- df_real[df_real$ano == ultimo_ano_real, , drop = FALSE]

  if (length(cols_agrupamento) > 0) {
    df_base <- df_base %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(cols_agrupamento))) %>%
      dplyr::summarise(estoque_trabalhadores = sum(estoque_trabalhadores, na.rm = TRUE), .groups = 'drop')

    df_proj <- dplyr::inner_join(df_saldo, df_base, by = cols_agrupamento)
    if (nrow(df_proj) == 0) {
      return(.drop_saldo_columns(df_real[order(df_real$ano), , drop = FALSE]))
    }

    df_proj <- df_proj %>%
      dplyr::arrange(dplyr::across(dplyr::all_of(c(cols_agrupamento, 'ano')))) %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(cols_agrupamento))) %>%
      dplyr::mutate(
        estoque_trabalhadores = pmax(0, estoque_trabalhadores + cumsum(.data[[col_saldo]])),
        origem = 'Estimação'
      ) %>%
      dplyr::ungroup()
  } else {
    estoque_base <- sum(df_base$estoque_trabalhadores, na.rm = TRUE)
    df_proj <- df_saldo %>%
      dplyr::arrange(.data$ano) %>%
      dplyr::mutate(
        estoque_trabalhadores = pmax(0, estoque_base + cumsum(.data[[col_saldo]])),
        origem = 'Estimação'
      )
  }

  df_resultado <- dplyr::bind_rows(df_real, df_proj)

  if (length(cols_agrupamento) > 0) {
    df_resultado <- df_resultado %>%
      dplyr::arrange(dplyr::across(dplyr::all_of(c('ano', cols_agrupamento))))
  } else {
    df_resultado <- df_resultado %>% dplyr::arrange(.data$ano)
  }

  return(.drop_saldo_columns(df_resultado))
}

# Função auxiliar para calcular estoque acumulado para dados agrupados
.calculate_cumulative_stock_grouped <- function(df_estoque, df_saldo, nome_grupo) {
  .calculate_cumulative_stock(df_estoque, df_saldo)
}

# ==============================================
# FUNÇÕES CAGED - HARMONIZAÇÃO COM PYTHON ✅
# ==============================================

#' Obter dados CAGED nacionais
#'
#' @param nivel_cnae Nível CNAE ('divisao', 'grupo', 'subclasse')
#' @param codigos Vetor de códigos CNAE opcionais
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados CAGED nacionais
#' @export
#' @examples
#' \dontrun{
#' # Dados nacionais por divisão
#' dados <- get_saldo_caged_nacional("divisao", c("10", "62"))
#' 
#' # Todos os grupos a partir de 2024
#' dados <- get_saldo_caged_nacional("grupo", data_minima = "2024-01-01")
#' }
get_saldo_caged_nacional <- function(nivel_cnae, 
                                    codigos = NULL, 
                                    data_minima = NULL) {
  api <- Emprego$new()
  
  switch(nivel_cnae,
    "divisao" = {
      dados <- api$get_saldo_caged_nacional_divisao(
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "grupo" = {
      dados <- api$get_saldo_caged_nacional_grupo(
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "subclasse" = {
      dados <- api$get_saldo_caged_nacional_subclasse(
        data_minima = data_minima,
        codigos = codigos
      )
    },
    stop("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
  )
  
  if (length(dados) > 0) {
    return(tibble::as_tibble(dplyr::bind_rows(dados)))
  } else {
    return(tibble::tibble())
  }
}

#' Obter dados CAGED estaduais
#'
#' @param nivel_cnae Nível CNAE ('divisao', 'grupo', 'subclasse')
#' @param siglas_uf Vetor de siglas dos estados (ex: c("SP", "RJ"))
#' @param codigos Vetor de códigos CNAE opcionais
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados CAGED estaduais
#' @export
#' @examples
#' \dontrun{
#' # Dados de São Paulo por grupo
#' dados_sp <- get_saldo_caged_estadual("grupo", c("SP"))
#' 
#' # Múltiplos estados por divisão
#' dados_sudeste <- get_saldo_caged_estadual("divisao", c("SP", "RJ", "MG"))
#' }
get_saldo_caged_estadual <- function(nivel_cnae,
                                    siglas_uf, 
                                    codigos = NULL, 
                                    data_minima = NULL) {
  api <- Emprego$new()
  
  switch(nivel_cnae,
    "divisao" = {
      dados <- api$get_saldo_caged_estadual_divisao(
        siglas_uf = siglas_uf,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "grupo" = {
      dados <- api$get_saldo_caged_estadual_grupo(
        siglas_uf = siglas_uf,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "subclasse" = {
      dados <- api$get_saldo_caged_estadual_subclasse(
        siglas_uf = siglas_uf,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    stop("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
  )
  
  if (length(dados) > 0) {
    return(tibble::as_tibble(dplyr::bind_rows(dados)))
  } else {
    return(tibble::tibble())
  }
}

#' Obter dados CAGED municipais
#'
#' @param nivel_cnae Nível CNAE ('divisao', 'grupo', 'subclasse')
#' @param codigos_municipio Vetor de códigos IBGE dos municípios
#' @param codigos Vetor de códigos CNAE opcionais
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados CAGED municipais
#' @export
#' @examples
#' \dontrun{
#' # São Paulo capital por divisão
#' dados_sp <- get_saldo_caged_municipal("divisao", 3550308)
#' 
#' # Múltiplas cidades por grupo
#' dados_cidades <- get_saldo_caged_municipal("grupo", c(3550308, 3304557))
#' }
get_saldo_caged_municipal <- function(nivel_cnae,
                                     codigos_municipio, 
                                     codigos = NULL, 
                                     data_minima = NULL) {
  api <- Emprego$new()
  
  switch(nivel_cnae,
    "divisao" = {
      dados <- api$get_saldo_caged_municipal_divisao(
        codigos_municipio = codigos_municipio,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "grupo" = {
      dados <- api$get_saldo_caged_municipal_grupo(
        codigos_municipio = codigos_municipio,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    "subclasse" = {
      dados <- api$get_saldo_caged_municipal_subclasse(
        codigos_municipio = codigos_municipio,
        data_minima = data_minima,
        codigos = codigos
      )
    },
    stop("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
  )
  
  if (length(dados) > 0) {
    return(tibble::as_tibble(dplyr::bind_rows(dados)))
  } else {
    return(tibble::tibble())
  }
}

# ==============================================
# MIGRAÇÃO AUTOMÁTICA - USAR CAGED NO LUGAR DE EMPREGO DETALHADO
# ==============================================

#' Obter dados mensais de saldo de emprego em nível nacional (USA CAGED - FUNCIONAL ✅)
#'
#' MIGRADO AUTOMATICAMENTE: Agora usa dados CAGED em vez de saldo_emprego_detalhado
#' 
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)  
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais CAGED nacionais
#' @export
get_saldo_emprego_nacional_mensal_caged <- function(nivel_cnae = 'divisao', 
                                                   codigo_cnae = NULL, 
                                                   data_minima = NULL) {
  # Mapear do sistema antigo para CAGED
  if (nivel_cnae == 'subclasse') {
    nivel_caged <- 'subclasse'
  } else if (nivel_cnae %in% c('divisao', 'divisão')) {
    nivel_caged <- 'divisao'
  } else if (nivel_cnae == 'grupo') {
    nivel_caged <- 'grupo'
  } else {
    stop("nivel_cnae deve ser: 'subclasse', 'divisao' ou 'grupo'")
  }
  
  # Usar função CAGED funcional
  codigos <- if (!is.null(codigo_cnae)) c(codigo_cnae) else NULL
  
  return(get_saldo_caged_nacional(
    nivel_cnae = nivel_caged,
    codigos = codigos,
    data_minima = data_minima
  ))
}

#' Obter dados mensais de saldo de emprego em nível estadual (USA CAGED - FUNCIONAL ✅)
#'
#' MIGRADO AUTOMATICAMENTE: Agora usa dados CAGED em vez de saldo_emprego_detalhado
#'
#' @param sigla_uf Sigla do estado ('SP', 'RJ', etc.)
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais CAGED estaduais
#' @export
get_saldo_emprego_estadual_mensal_caged <- function(sigla_uf,
                                                   nivel_cnae = 'divisao', 
                                                   codigo_cnae = NULL, 
                                                   data_minima = NULL) {
  # Mapear do sistema antigo para CAGED
  if (nivel_cnae == 'subclasse') {
    nivel_caged <- 'subclasse'
  } else if (nivel_cnae %in% c('divisao', 'divisão')) {
    nivel_caged <- 'divisao'
  } else if (nivel_cnae == 'grupo') {
    nivel_caged <- 'grupo'
  } else {
    stop("nivel_cnae deve ser: 'subclasse', 'divisao' ou 'grupo'")
  }
  
  # Usar função CAGED funcional
  codigos <- if (!is.null(codigo_cnae)) c(codigo_cnae) else NULL
  
  return(get_saldo_caged_estadual(
    nivel_cnae = nivel_caged,
    siglas_uf = c(sigla_uf),  # Converter string única para vetor
    codigos = codigos,
    data_minima = data_minima
  ))
}

#' Obter dados mensais de saldo de emprego em nível municipal (USA CAGED - FUNCIONAL ✅)
#'
#' MIGRADO AUTOMATICAMENTE: Agora usa dados CAGED em vez de saldo_emprego_detalhado
#'
#' @param sigla_uf Sigla do estado - NÃO USADO NA API CAGED
#' @param codigo_municipio Código IBGE do município
#' @param nivel_cnae Nível CNAE ('subclasse', 'divisao', 'grupo')
#' @param codigo_cnae Filtro por código CNAE específico (opcional)
#' @param data_minima Data mínima em formato YYYY-MM-DD (opcional)
#' @return Tibble com dados mensais CAGED municipais
#' @export
get_saldo_emprego_municipal_mensal_caged <- function(sigla_uf,  # Ignorado na API CAGED
                                                    codigo_municipio,
                                                    nivel_cnae = 'divisao', 
                                                    codigo_cnae = NULL, 
                                                    data_minima = NULL) {
  # Mapear do sistema antigo para CAGED
  if (nivel_cnae == 'subclasse') {
    nivel_caged <- 'subclasse'
  } else if (nivel_cnae %in% c('divisao', 'divisão')) {
    nivel_caged <- 'divisao'
  } else if (nivel_cnae == 'grupo') {
    nivel_caged <- 'grupo'
  } else {
    stop("nivel_cnae deve ser: 'subclasse', 'divisao' ou 'grupo'")
  }
  
  # Usar função CAGED funcional
  codigos <- if (!is.null(codigo_cnae)) c(codigo_cnae) else NULL
  
  # Nota: sigla_uf é ignorada pois a API CAGED municipal usa apenas codigo_municipio
  return(get_saldo_caged_municipal(
    nivel_cnae = nivel_caged,
    codigos_municipio = c(codigo_municipio),  # Converter para vetor
    codigos = codigos,
    data_minima = data_minima
  ))
}