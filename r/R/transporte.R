# Transporte: o único lugar da biblioteca que faz HTTP.
#
# Dois tipos de origem (ver `inst/catalogo.json`):
#
# - api: a sdic_api, com chave individual (`Authorization: Bearer`), repetição em falha
#   transitória (429, 502, 503, 504), paginação e cache opcional;
# - arquivo: JSON públicos (bucket de dados, Pages das políticas), sem chave.
#
# Os clientes (`Emprego`, `Comex`) e as funções de séries, seções publicadas e políticas usam
# só o que está aqui. Trocar endereço, autenticação ou política de repetição é mexer neste
# arquivo e em `config.R`. Espelho de `python/sdic_libraries/transporte.py`.

.SDIC_TAMANHO_PAGINA <- 5000L  # máximo aceito pela sdic_api
.SDIC_REPETIR <- c(429L, 502L, 503L, 504L)

# Erro de leitura: classe `sdic_erro`, com `status_code` e `endpoint` (NULL em falha de rede).
# `rlang::abort` e não `cli::cli_abort`: o cli quebra a mensagem em linhas na largura do
# console, partindo a URL e os textos que o usuário procura.
.sdic_abortar <- function(mensagem, status_code = NULL, endpoint = NULL, classe = NULL, ...) {
  rlang::abort(mensagem, class = c(classe, "sdic_erro"), status_code = status_code, endpoint = endpoint,
               ..., call = NULL)
}

# `detail` de uma resposta de erro da sdic_api, como texto; NULL se não houver. O FastAPI
# devolve texto (erros da própria API) ou lista de `{loc, msg}` (validação de parâmetros).
.sdic_detalhe_api <- function(resp) {
  detalhe <- tryCatch(httr2::resp_body_json(resp, check_type = FALSE)$detail, error = function(e) NULL)
  if (is.list(detalhe)) {
    detalhe <- paste(vapply(detalhe, function(d) {
      if (!is.list(d)) return(paste(as.character(d), collapse = " "))
      campo <- paste(unlist(d$loc)[-1], collapse = ".")
      paste0(if (nzchar(campo)) campo else "parâmetro", ": ", d$msg %||% "")
    }, character(1)), collapse = "; ")
  }
  if (is.character(detalhe) && length(detalhe) == 1 && nzchar(trimws(detalhe))) detalhe else NULL
}

# Mensagem para quem usa: o que houve, em qual rota e o que fazer. Decide só pelo código HTTP
# (ou pelo tipo da falha, quando não houve resposta). Mesmos textos do Python.
.sdic_mensagem_de_erro <- function(endpoint, status = NULL, detalhe = NULL, falha = NULL) {
  sufixo <- paste0(" [", endpoint, if (!is.null(status)) paste0(", HTTP ", status), "]")
  texto <- if (is.null(status)) {
    if (identical(falha, "json")) {
      "A resposta não é um JSON válido."
    } else if (inherits(falha, c("httr2_failure", "curl_error"))) {
      sprintf("Sem resposta da origem (rede ou tempo esgotado): %s.", class(falha)[1])
    } else {
      sprintf("Falha na requisição: %s.", class(falha)[1])
    }
  } else if (status %in% c(400, 422)) {
    sprintf("Parâmetros inválidos: %s.", detalhe %||% "confira códigos e datas informados")
  } else if (status %in% c(401, 403)) {
    sprintf("Chave da API ausente, inválida ou sem acesso (%s). Defina SDIC_API_KEY (sdic_config() mostra o que está valendo).",
            detalhe %||% "sem detalhe")
  } else if (status == 404) {
    sprintf("Rota ou recurso não encontrado%s. Confira o nome e se a biblioteca está atualizada.",
            if (is.null(detalhe)) "" else paste0(": ", detalhe))
  } else if (status == 429) {
    "Muitas requisições em pouco tempo; a biblioteca já tentou de novo. Aguarde e repita."
  } else if (status >= 500) {
    "A API respondeu com erro interno depois das novas tentativas. Tente mais tarde."
  } else {
    sprintf("Falha na requisição: HTTP %s.", status)
  }
  paste0(texto, sufixo)
}

# Requisição pronta: identificação do cliente, tempo limite, repetição em falha transitória e,
# só quando há chave, `Authorization: Bearer`. Nenhum cabeçalho próprio leva a chave: o curl
# retira o `Authorization` num redirecionamento para outro host; um `x-api-key` seguiria junto.
.sdic_requisicao <- function(url, timeout, chave = NULL) {
  req <- httr2::request(url)
  req <- httr2::req_headers(
    req,
    `User-Agent` = paste0("sdic-libraries-r/", utils::packageVersion("sdic.libraries")),
    Accept = "application/json"
  )
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_retry(req, max_tries = 4,
                          is_transient = function(resp) httr2::resp_status(resp) %in% .SDIC_REPETIR)
  # O erro HTTP é tratado aqui (com o `detail` da API), não pelo httr2, que descarta o corpo.
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  if (!is.null(chave)) req <- httr2::req_auth_bearer_token(req, chave)
  req
}

# Executa a requisição e devolve o TEXTO do corpo (JSON). Com `ttl` > 0, usa o cache local.
# Falha de rede e resposta >= 400 viram `sdic_erro` (ou `classe_404` para 403/404, quando dada).
.sdic_executar <- function(req, metodo, endpoint, corpo = NULL, ttl = 0, identidade = NULL, classe_404 = NULL,
                           mensagem_404 = NULL) {
  buscar <- function() {
    resp <- tryCatch(httr2::req_perform(req), error = function(e) e)
    if (inherits(resp, "error")) {
      # A mensagem original pode trazer a URL completa: fica em `causa`, fora do texto do erro.
      .sdic_abortar(.sdic_mensagem_de_erro(endpoint, falha = resp), endpoint = endpoint,
                    causa = conditionMessage(resp))
    }
    status <- httr2::resp_status(resp)
    if (status >= 400) {
      if (!is.null(classe_404) && status %in% c(403L, 404L)) {  # o bucket responde 403 ou 404 para objeto inexistente
        .sdic_abortar(mensagem_404, status_code = status, endpoint = endpoint, classe = classe_404)
      }
      .sdic_abortar(.sdic_mensagem_de_erro(endpoint, status, .sdic_detalhe_api(resp)),
                    status_code = status, endpoint = endpoint)
    }
    httr2::resp_body_string(resp)
  }
  .sdic_com_cache(ttl, list(metodo, req$url, corpo, identidade), buscar)
}

.sdic_json <- function(texto, endpoint, simplifyVector = FALSE) {
  tryCatch(jsonlite::fromJSON(texto, simplifyVector = simplifyVector),
           error = function(e) .sdic_abortar(.sdic_mensagem_de_erro(endpoint, falha = "json"), endpoint = endpoint))
}

# ---- paginação ---------------------------------------------------------------------------

.sdic_e_objeto <- function(x) is.list(x) && !is.null(names(x))

# Lista de itens de uma resposta: a própria lista, ou a chave `items`/`data`/`results`/`records`.
# Página sem a lista é erro, não "fim dos dados".
.sdic_extrair_itens <- function(resposta, normalizar = identity) {
  if (.sdic_e_objeto(resposta)) {
    itens <- NULL
    for (chave in c("items", "data", "results", "records")) {
      valor <- resposta[[chave]]
      if (is.list(valor) && !.sdic_e_objeto(valor)) {
        itens <- valor
        break
      }
    }
    if (is.null(itens)) .sdic_abortar("Formato de resposta inesperado da API: página sem a lista de itens.")
  } else if (is.list(resposta)) {
    itens <- resposta
  } else {
    .sdic_abortar("Formato de resposta inesperado da API")
  }
  lapply(Filter(is.list, itens), normalizar)
}

.sdic_inteiro_da_resposta <- function(resposta, chaves) {
  if (!.sdic_e_objeto(resposta)) return(NULL)
  for (chave in chaves) {
    v <- resposta[[chave]]
    if (is.numeric(v) && length(v) == 1 && !is.na(v) && v >= 0 && v == trunc(v)) return(as.numeric(v))
  }
  NULL
}

# Junta todas as páginas. Para, nesta ordem, por: `proxima_pagina` nulo (rotas `/series`),
# total de páginas, total de registros (`count`), página menor que a pedida.
# `pedir(params)` faz a requisição de uma página; `extrair(resposta)` devolve os itens.
.sdic_paginar <- function(pedir, extrair, params = NULL, endpoint = "") {
  paginas <- list()
  lidos <- 0
  pagina <- 1L
  total <- NULL
  repeat {
    p <- as.list(params)
    p$pagina <- pagina
    if (is.null(p$tamanho_pagina)) p$tamanho_pagina <- .SDIC_TAMANHO_PAGINA
    tamanho <- as.integer(p$tamanho_pagina)
    resposta <- pedir(p)
    itens <- extrair(resposta)
    paginas[[pagina]] <- itens
    lidos <- lidos + length(itens)
    if (is.null(total)) total <- .sdic_inteiro_da_resposta(resposta, "count")
    if (.sdic_e_objeto(resposta) && "proxima_pagina" %in% names(resposta)) {
      if (is.null(resposta$proxima_pagina)) break
    } else if (length(itens) == 0) {
      break
    } else {
      total_paginas <- .sdic_inteiro_da_resposta(resposta, c("pages", "total_pages", "paginas", "totalPaginas"))
      if (!is.null(total_paginas) && total_paginas > 0 && pagina >= total_paginas) break
      if (!is.null(total) && lidos >= total) break
      if (length(itens) < tamanho) break
    }
    pagina <- pagina + 1L
  }
  if (!is.null(total) && lidos != total) {
    warning(sprintf("%s: a API informou %s registros e vieram %s. O resultado pode estar incompleto; repita a consulta.",
                    endpoint, format(total, scientific = FALSE), lidos), call. = FALSE)
  }
  do.call(c, c(list(list()), paginas))
}

# ---- cliente da sdic_api -----------------------------------------------------------------

#' Base dos clientes da sdic_api
#'
#' Configuração, requisição, paginação e cache comuns a [Emprego] e [Comex]. Não é exportada:
#' use uma das duas classes, ou as funções `get_*`.
#'
#' @docType class
#' @format Classe [R6::R6Class].
#' @keywords internal
ClienteAPI <- R6::R6Class(
  "ClienteAPI",
  public = list(
    #' @field base_url URL base da sdic_api (argumento, `SDIC_API_URL` ou o padrão do catálogo)
    base_url = NULL,

    #' @field timeout Tempo limite das requisições, em segundos (argumento ou `SDIC_TIMEOUT`)
    timeout = NULL,

    #' @field cache_ttl Validade do cache local, em segundos (`SDIC_CACHE_TTL`; 0 = sem cache)
    cache_ttl = NULL,

    #' @description
    #' Criar o cliente. Cada valor vem, nesta ordem, do argumento, da variável de ambiente, de
    #' `.env.local`/`.env` e do padrão (veja [sdic_config()]). A chave fica guardada em campo
    #' privado e só é enviada por `https://` (ou para a própria máquina).
    #' @param base_url URL base da API (padrão: `SDIC_API_URL`)
    #' @param timeout Tempo limite em segundos (padrão: `SDIC_TIMEOUT`, depois 30)
    #' @param api_key Chave individual da API (padrão: `SDIC_API_KEY`)
    initialize = function(base_url = NULL, timeout = NULL, api_key = NULL) {
      self$base_url <- .sdic_url("api", base_url)
      self$timeout <- .sdic_timeout(timeout)
      self$cache_ttl <- .sdic_cache_ttl()
      private$api_key <- .sdic_chave(api_key)
      if (!is.null(private$api_key)) .sdic_conferir_destino_da_chave(self$base_url)
      invisible(self)
    },

    #' @description
    #' Texto que descreve o cliente (usado por `print()` e `format()`). A chave nunca aparece:
    #' só se está definida.
    #' @param ... Ignorado
    format = function(...) {
      c(sprintf("<%s>", class(self)[1]),
        paste0("  url: ", self$base_url),
        paste0("  chave: ", if (is.null(private$api_key)) "não definida" else "definida"),
        sprintf("  timeout: %s s", self$timeout))
    },

    #' @description
    #' Mostrar o cliente (URL, se há chave e tempo limite).
    #' @param ... Ignorado
    print = function(...) {
      cat(self$format(), sep = "\n")
      invisible(self)
    },

    #' @description
    #' Requisição GET à API; devolve o JSON da resposta como lista.
    #' @param endpoint Caminho da rota
    #' @param params Parâmetros de query (opcional)
    .make_request = function(endpoint, params = NULL) {
      private$requisitar("GET", endpoint, params)
    },

    #' @description
    #' Requisição POST à API; devolve o JSON da resposta como lista.
    #' @param endpoint Caminho da rota
    #' @param body Corpo da requisição (convertido para JSON)
    #' @param params Parâmetros de query (opcional)
    .make_post_request = function(endpoint, body = NULL, params = NULL) {
      private$requisitar("POST", endpoint, params, body)
    },

    #' @description
    #' Ajuste de cada item da resposta (as subclasses podem redefinir).
    #' @param item Item da resposta
    .normalize_response_item = function(item) item,

    #' @description
    #' Itens de uma resposta, paginada ou não. Resposta sem a lista de itens é erro.
    #' @param response Resposta da API
    .extract_items = function(response) {
      .sdic_extrair_itens(response, self$.normalize_response_item)
    },

    #' @description
    #' Total de páginas informado pela resposta, ou NULL.
    #' @param response Resposta da API
    .get_total_pages = function(response) {
      n <- .sdic_inteiro_da_resposta(response, c("pages", "total_pages", "paginas", "totalPaginas"))
      if (is.null(n) || n == 0) NULL else as.integer(n)
    },

    #' @description
    #' Total de registros informado pela resposta (`count`), ou NULL.
    #' @param response Resposta da API
    .get_total_count = function(response) {
      n <- .sdic_inteiro_da_resposta(response, "count")
      if (is.null(n)) NULL else as.integer(n)
    },

    #' @description
    #' Todas as páginas de uma rota GET, numa lista só.
    #' @param endpoint Caminho da rota
    #' @param params Parâmetros de query
    .fetch_all_paginated_get = function(endpoint, params = list()) {
      .sdic_paginar(function(p) self$.make_request(endpoint, p), self$.extract_items, params, endpoint)
    },

    #' @description
    #' Todas as páginas de uma rota POST, numa lista só.
    #' @param endpoint Caminho da rota
    #' @param body Corpo da requisição
    #' @param params Parâmetros de query
    .fetch_all_paginated_post = function(endpoint, body, params = list()) {
      pedir <- function(p) {
        corpo <- body
        if (private$paginacao_no_corpo && (is.null(body) || is.list(body))) {
          corpo$pagina <- p$pagina
          if (is.null(corpo$tamanho_pagina)) corpo$tamanho_pagina <- p$tamanho_pagina
        }
        self$.make_post_request(endpoint, corpo, p)
      }
      .sdic_paginar(pedir, self$.extract_items, params, endpoint)
    }
  ),
  private = list(
    api_key = NULL,
    multi = "explode",           # como um vetor vira parâmetro de query (Comex: "comma")
    paginacao_no_corpo = FALSE,  # Comex: `/exportacao_agregada_ncm` espera a página também no corpo

    # Entra na chave do cache: resposta de uma chave não serve a outra (nem a quem não tem).
    identidade = function() {
      if (is.null(private$api_key)) NULL else substr(rlang::hash(private$api_key), 1, 12)
    },

    requisitar = function(metodo, endpoint, params = NULL, corpo = NULL) {
      url <- paste0(sub("/+$", "", self$base_url), "/", sub("^/+", "", endpoint))
      req <- .sdic_requisicao(url, self$timeout, private$api_key)
      if (length(params) > 0) req <- httr2::req_url_query(req, !!!params, .multi = private$multi)
      if (identical(metodo, "POST")) {
        if (!is.null(corpo)) req <- httr2::req_body_json(req, corpo)
        req <- httr2::req_method(req, "POST")
      }
      texto <- .sdic_executar(req, metodo, endpoint, corpo, ttl = self$cache_ttl, identidade = private$identidade())
      .sdic_json(texto, endpoint)
    }
  )
)

# ---- arquivos publicados (sem chave) -------------------------------------------------------

.sdic_json_publicado <- function(origem, caminho, base_url = NULL, timeout = NULL, simplifyVector = FALSE) {
  url <- paste0(.sdic_url(origem, base_url), "/", sub("^/+", "", caminho))
  req <- .sdic_requisicao(url, .sdic_timeout(timeout))  # nunca leva a chave
  texto <- .sdic_executar(
    req, "GET", url, ttl = .sdic_cache_ttl(), classe_404 = "sdic_nao_publicado",
    mensagem_404 = sprintf("Arquivo não publicado: %s. Confira o ambiente (SDIC_AMBIENTE) e a unidade.", url)
  )
  .sdic_json(texto, url, simplifyVector = simplifyVector)
}

#' Ler um JSON público de uma origem do catálogo
#'
#' É o nível mais baixo de leitura de arquivos publicados: prefira [get_secao_publicada()],
#' [get_politica()] e as demais funções de seções publicadas e de políticas. Nenhuma chave é
#' enviada.
#'
#' @param origem Origem do catálogo: `"dados"` (bucket das seções publicadas) ou
#'   `"politicas"` (Pages das políticas). O endereço em uso aparece em [sdic_config()].
#' @param caminho Caminho do arquivo dentro da origem, ex.: `"homologacao/SP/emprego.json"`.
#' @param base_url URL base, para ler de outro lugar (padrão: `SDIC_DADOS_URL` ou
#'   `SDIC_PAGES_URL`, conforme a origem).
#' @param timeout Tempo limite em segundos (padrão: `SDIC_TIMEOUT`, depois 30).
#' @return Lista com o conteúdo do JSON, como publicado (não é uma tabela). Arquivo inexistente
#'   (HTTP 403 ou 404) gera erro da classe `sdic_nao_publicado`, com a URL pedida na mensagem;
#'   as outras falhas, erro da classe `sdic_erro` (campos `status_code` e `endpoint`).
#' @examples
#' \dontrun{
#' ler_json_publicado("dados", "homologacao/SP/emprego.json")
#' }
#' @export
ler_json_publicado <- function(origem, caminho, base_url = NULL, timeout = NULL) {
  .sdic_json_publicado(origem, caminho, base_url = base_url, timeout = timeout)
}

# ---- tabelas a partir de registros ---------------------------------------------------------

# Coluna `nome` de uma lista de registros: nulo vira NA; valor composto vira texto.
.sdic_coluna <- function(linhas, nome) {
  valores <- lapply(linhas, function(l) {
    v <- l[[nome]]
    if (is.null(v) || length(v) == 0) NA else if (length(v) > 1 || is.list(v)) paste(unlist(v), collapse = ", ") else v
  })
  if (length(valores) == 0) character() else unlist(valores, use.names = FALSE)
}

# Registros -> tibble com exatamente `colunas`, nessa ordem (sem registros: tabela vazia com
# as mesmas colunas). Sem `colunas`: a união dos campos, na ordem em que aparecem.
.sdic_tabela <- function(linhas, colunas = NULL) {
  if (is.null(colunas)) colunas <- unique(unlist(lapply(linhas, names), use.names = FALSE))
  dados <- lapply(colunas, function(coluna) .sdic_coluna(linhas, coluna))
  names(dados) <- colunas
  tibble::as_tibble(dados, .name_repair = "minimal")
}

.sdic_numerico <- function(x) suppressWarnings(as.numeric(x))
