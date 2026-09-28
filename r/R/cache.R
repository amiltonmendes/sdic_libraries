# Cache local (em disco) das respostas da sdic_api.
#
# Desligado por padrão. Ligue com `Sys.setenv(SDIC_CACHE_TTL = 3600)` (segundos). A chave
# inclui método, URL completa (host da sdic_api, com a query) e corpo da requisição; só
# respostas bem-sucedidas são gravadas (erro do httr2 lança exceção antes). Os clientes só
# chamam a sdic_api, então o cache nunca guarda dado de outra fonte.
# Pasta: `SDIC_CACHE_DIR` ou `tools::R_user_dir("sdic.libraries", "cache")` (apague-a para limpar).

#' Executa `httr2::req_perform(req)` com cache local opcional
#' @param req Requisição httr2
#' @return Resposta httr2
#' @keywords internal
#' @noRd
.req_perform_cache <- function(req) {
  ttl <- suppressWarnings(as.numeric(Sys.getenv("SDIC_CACHE_TTL", "0")))
  if (is.na(ttl) || ttl <= 0) return(httr2::req_perform(req))

  pasta <- Sys.getenv("SDIC_CACHE_DIR", unset = tools::R_user_dir("sdic.libraries", "cache"))
  arquivo <- file.path(pasta, paste0(rlang::hash(list(req$method, req$url, req$body)), ".rds"))

  if (file.exists(arquivo) && as.numeric(difftime(Sys.time(), file.mtime(arquivo), units = "secs")) < ttl) {
    em_cache <- tryCatch(readRDS(arquivo), error = function(e) NULL)  # corrompido: busca de novo
    if (!is.null(em_cache)) return(em_cache)
  }

  resposta <- httr2::req_perform(req)
  tryCatch({  # cache é otimização: falha de disco nunca derruba a consulta
    dir.create(pasta, recursive = TRUE, showWarnings = FALSE)
    temporario <- paste0(arquivo, ".tmp")
    saveRDS(resposta, temporario)
    file.rename(temporario, arquivo)  # gravação atômica
  }, error = function(e) NULL, warning = function(w) NULL)
  resposta
}
