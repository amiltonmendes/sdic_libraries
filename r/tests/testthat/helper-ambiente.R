# Apoio dos testes de configuração, transporte, séries, seções publicadas e políticas:
# ambiente limpo e origens servidas pelas amostras de contrato/ (sem rede). Espelho de
# python/tests/conftest.py.

.variaveis_sdic <- c(
  "SDIC_API_KEY", "SDIC_API_URL", "SDIC_DADOS_URL", "SDIC_PAGES_URL", "SDIC_AMBIENTE", "SDIC_TIMEOUT",
  "SDIC_CACHE_TTL", "EMPLOYMENT_API_KEY", "COMEX_API_KEY", "EMPLOYMENT_API_BASE_URL",
  "COMEX_API_BASE_URL", "PORTAL_EMPREGO_BASE_URL", "PORTAL_EMPREGO_AMBIENTE", "API_TIMEOUT"
)

# Nenhum teste depende do ambiente ou do .env de quem roda: variáveis apagadas, diretório de
# trabalho e HOME temporários, cache em pasta própria. Devolve a pasta temporária.
ambiente_limpo <- function(env = parent.frame()) {
  pasta <- withr::local_tempdir(.local_envir = env)
  limpas <- stats::setNames(rep(NA_character_, length(.variaveis_sdic)), .variaveis_sdic)
  withr::local_envvar(c(limpas, HOME = pasta, SDIC_CACHE_DIR = file.path(pasta, "cache")), .local_envir = env)
  withr::local_dir(pasta, .local_envir = env)
  assign("avisados", NULL, envir = sdic.libraries:::.sdic_estado)
  pasta
}

amostras <- function(nome) {
  arquivo <- testthat::test_path("..", "..", "..", "contrato", paste0(nome, "_amostras.json"))
  if (!file.exists(arquivo)) return(NULL)
  jsonlite::fromJSON(arquivo, simplifyVector = FALSE)
}

resposta_json <- function(corpo, status = 200L, url = "https://x/") {
  texto <- jsonlite::toJSON(corpo, auto_unbox = TRUE, null = "null", digits = NA)
  httr2::response(status_code = status, url = url, headers = list("Content-Type" = "application/json"),
                  body = charToRaw(enc2utf8(as.character(texto))))
}

cabecalhos_da_requisicao <- function(req) {
  if (exists("req_get_headers", envir = asNamespace("httr2"))) httr2::req_get_headers(req, "reveal") else as.list(req$headers)
}

# Respostas em fila (uma por requisição; uma condição na fila é lançada). Devolve o registro
# das requisições (`$chamadas`).
responde <- function(respostas, env = parent.frame()) {
  registro <- new.env()
  registro$chamadas <- list()
  fila <- respostas
  httr2::local_mocked_responses(function(req) {
    registro$chamadas[[length(registro$chamadas) + 1]] <- req
    r <- fila[[1]]
    fila <<- fila[-1]
    if (inherits(r, "condition")) stop(r)
    r
  }, env = env)
  registro
}

# Serve `arquivos` (caminho -> JSON) no lugar do HTTP; o resto responde 404. Devolve o
# registro com as URLs pedidas (`$urls`).
origem_falsa <- function(arquivos, env = parent.frame()) {
  registro <- new.env()
  registro$urls <- character()
  httr2::local_mocked_responses(function(req) {
    registro$urls <- c(registro$urls, req$url)
    caminho <- httr2::url_parse(req$url)$path
    for (nome in names(arquivos)) {
      if (endsWith(caminho, paste0("/", sub("^/+", "", nome)))) return(resposta_json(arquivos[[nome]], url = req$url))
    }
    resposta_json(list(detail = "Not Found"), 404L, req$url)
  }, env = env)
  registro
}

`%||%` <- function(x, y) if (is.null(x)) y else x
