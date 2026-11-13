# Cache local (em disco) das respostas lidas pela biblioteca.
#
# Desligado por padrão. Ligue com `SDIC_CACHE_TTL=<segundos>` (ex.: 3600) ou, num cliente,
# `api$cache_ttl <- 3600`. A chave do cache inclui método, URL completa (com a query), corpo da
# requisição e um resumo curto da chave da API (nunca a chave): a resposta de uma chave não
# serve a outra. Só o corpo JSON de respostas bem-sucedidas é gravado; a requisição (que
# carrega o cabeçalho de autenticação) nunca vai para o disco.
# Pasta: `SDIC_CACHE_DIR` ou `tools::R_user_dir("sdic.libraries", "cache")`, criada só para o
# usuário (0700). Apague-a para limpar.

# Devolve o texto em cache (se tiver menos de `ttl` segundos) ou chama `buscar()`.
# `requisicao` = list(método, url, corpo, identidade) identifica a resposta.
.sdic_com_cache <- function(ttl, requisicao, buscar) {
  if (is.null(ttl) || is.na(ttl) || ttl <= 0) return(buscar())
  pasta <- .sdic_pasta_cache()
  arquivo <- file.path(pasta, paste0(rlang::hash(requisicao), ".json"))
  if (file.exists(arquivo) && as.numeric(difftime(Sys.time(), file.mtime(arquivo), units = "secs")) < ttl) {
    texto <- tryCatch(paste(readLines(arquivo, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                      error = function(e) NULL)
    # corrompido ou truncado: busca de novo
    if (!is.null(texto) && nzchar(texto) && jsonlite::validate(texto)) return(texto)
  }
  texto <- buscar()  # erro nunca é gravado: `buscar()` lança antes
  tryCatch({  # cache é otimização: falha de disco nunca derruba a consulta
    dir.create(pasta, recursive = TRUE, showWarnings = FALSE, mode = "0700")
    temporario <- paste0(arquivo, ".tmp")
    writeLines(enc2utf8(texto), temporario, useBytes = TRUE)
    file.rename(temporario, arquivo)  # gravação atômica
  }, error = function(e) NULL, warning = function(w) NULL)
  texto
}
