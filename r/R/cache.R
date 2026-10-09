# Cache local (em disco) das respostas da sdic_api.
#
# Desligado por padrão. Ligue com `Sys.setenv(SDIC_CACHE_TTL = 3600)` (segundos). A chave
# inclui método, URL completa (host da sdic_api, com a query) e corpo da requisição; só
# respostas bem-sucedidas são gravadas (`.erro_api` lança exceção antes). Os clientes só
# chamam a sdic_api, então o cache nunca guarda dado de outra fonte.
# Pasta: `SDIC_CACHE_DIR` ou `tools::R_user_dir("sdic.libraries", "cache")` (apague-a para limpar).

#' Executa `httr2::req_perform(req)` com cache local opcional
#' @param req Requisição httr2
#' @return Resposta httr2
#' @keywords internal
#' @noRd
.req_perform_cache <- function(req) {
  # Erro HTTP tratado em .erro_api (com o `detail` da sdic_api), não pelo httr2,
  # que descarta o corpo da resposta ("HTTP 422 Unprocessable Entity.").
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  ttl <- suppressWarnings(as.numeric(Sys.getenv("SDIC_CACHE_TTL", "0")))
  if (is.na(ttl) || ttl <= 0) return(.erro_api(httr2::req_perform(req)))

  pasta <- Sys.getenv("SDIC_CACHE_DIR", unset = tools::R_user_dir("sdic.libraries", "cache"))
  arquivo <- file.path(pasta, paste0(rlang::hash(list(req$method, req$url, req$body)), ".rds"))

  if (file.exists(arquivo) && as.numeric(difftime(Sys.time(), file.mtime(arquivo), units = "secs")) < ttl) {
    em_cache <- tryCatch(readRDS(arquivo), error = function(e) NULL)  # corrompido: busca de novo
    if (!is.null(em_cache)) return(em_cache)
  }

  resposta <- .erro_api(httr2::req_perform(req))  # antes do cache: erro nunca é gravado
  tryCatch({  # cache é otimização: falha de disco nunca derruba a consulta
    dir.create(pasta, recursive = TRUE, showWarnings = FALSE)
    temporario <- paste0(arquivo, ".tmp")
    saveRDS(resposta, temporario)
    file.rename(temporario, arquivo)  # gravação atômica
  }, error = function(e) NULL, warning = function(w) NULL)
  resposta
}

# Resposta >= 400 vira erro com o `detail` da sdic_api (texto ou lista {loc, msg} do
# FastAPI), ex.: "HTTP 422: data_minima: '2025-01' inválida; use o formato AAAA-MM-DD ...".
.erro_api <- function(resp) {
  status <- httr2::resp_status(resp)
  if (status < 400) return(resp)
  detalhe <- tryCatch(httr2::resp_body_json(resp)$detail, error = function(e) NULL)
  if (is.list(detalhe)) {
    detalhe <- paste(vapply(detalhe, function(d) {
      campo <- paste(unlist(d$loc)[-1], collapse = ".")
      paste0(if (nzchar(campo)) campo else "parâmetro", ": ", d$msg %||% "")
    }, character(1)), collapse = "; ")
  }
  sufixo <- if (is.character(detalhe) && length(detalhe) == 1 && nzchar(detalhe)) paste0(": ", detalhe) else ""
  stop(sprintf("HTTP %d%s", status, sufixo), call. = FALSE)
}
