# Configuração da biblioteca: o único lugar que lê variável de ambiente e arquivo `.env`.
#
# Cada valor é resolvido nesta ordem: argumento da função, variável de ambiente, `.env.local`,
# `.env` (diretório atual), `~/.env`, `/etc/sdic/.env`, padrão do catálogo. Os arquivos são só
# lidos: nada é gravado no ambiente do processo (`Sys.setenv`), e só os nomes desta biblioteca
# são considerados. `sdic_config()` mostra o que está valendo e de onde veio.
# Espelho de `python/sdic_libraries/config.py`.

# Estado do pacote: catálogo já lido e nomes antigos que já geraram aviso.
.sdic_estado <- new.env(parent = emptyenv())

# nome atual -> nomes antigos ainda aceitos (com aviso de depreciação)
.SDIC_LEGADOS <- list(
  SDIC_API_KEY = c("EMPLOYMENT_API_KEY", "COMEX_API_KEY"),
  SDIC_API_URL = c("EMPLOYMENT_API_BASE_URL", "COMEX_API_BASE_URL"),
  SDIC_PAGES_URL = "PORTAL_EMPREGO_BASE_URL",
  SDIC_AMBIENTE = "PORTAL_EMPREGO_AMBIENTE",
  SDIC_TIMEOUT = "API_TIMEOUT"
)
.SDIC_PADROES <- list(SDIC_TIMEOUT = "30", SDIC_CACHE_TTL = "0", SDIC_AMBIENTE = "producao")

`%||%` <- function(x, y) if (is.null(x)) y else x

# Erro de argumento ou configuração inválidos (o `ValueError` do Python). Sem `cli`: ele
# quebraria a mensagem em linhas, partindo URLs e textos que os testes e os usuários procuram.
.sdic_invalido <- function(mensagem) {
  rlang::abort(mensagem, class = "sdic_valor_invalido", call = NULL)
}

# `contrato/catalogo.json` (fonte única, a mesma do Python), copiado em `inst/catalogo.json`.
.sdic_catalogo <- function() {
  if (is.null(.sdic_estado$catalogo)) {
    arquivo <- system.file("catalogo.json", package = "sdic.libraries")
    if (!nzchar(arquivo)) arquivo <- file.path("inst", "catalogo.json")  # rodando do código-fonte
    .sdic_estado$catalogo <- jsonlite::fromJSON(arquivo, simplifyVector = FALSE)
  }
  .sdic_estado$catalogo
}

.sdic_origens <- function() .sdic_catalogo()$origens
.sdic_ambientes <- function() unlist(.sdic_catalogo()$ambientes)

.sdic_home <- function() {
  # `path.expand("~")` guarda o primeiro valor de HOME; a variável é lida a cada chamada.
  home <- Sys.getenv("HOME")
  if (nzchar(home)) home else path.expand("~")
}

.sdic_arquivos_env <- function() {
  c(file.path(getwd(), ".env.local"), file.path(getwd(), ".env"),
    file.path(.sdic_home(), ".env"), "/etc/sdic/.env")
}

# Lê um `.env` e devolve os pares nome/valor. Nunca altera o ambiente do processo.
.sdic_ler_env <- function(arquivo) {
  valores <- list()
  linhas <- tryCatch(suppressWarnings(readLines(arquivo, warn = FALSE, encoding = "UTF-8")),
                     error = function(e) character())
  for (linha in trimws(linhas)) {
    if (!nzchar(linha) || startsWith(linha, "#") || !grepl("=", linha, fixed = TRUE)) next
    corte <- regexpr("=", linha, fixed = TRUE)
    nome <- trimws(substr(linha, 1, corte - 1))
    valor <- trimws(substr(linha, corte + 1, nchar(linha)))
    if (startsWith(nome, "export ")) nome <- trimws(substring(nome, 8))
    n <- nchar(valor)
    if (n >= 2 && substr(valor, 1, 1) == substr(valor, n, n) && substr(valor, 1, 1) %in% c("\"", "'")) {
      valor <- substr(valor, 2, n - 1)
    }
    if (nzchar(nome)) valores[[nome]] <- valor
  }
  valores
}

# Valor de uma configuração e de onde veio (`argumento`, `variável de ambiente`, caminho do
# arquivo ou `padrão`). Devolve `list(valor, de_onde)`; `valor` é NULL quando não há nada.
.sdic_valor <- function(nome, explicito = NULL) {
  if (!is.null(explicito) && length(explicito) == 1 && !is.na(explicito) && nzchar(as.character(explicito))) {
    return(list(valor = as.character(explicito), de_onde = "argumento"))
  }
  nomes <- c(nome, .SDIC_LEGADOS[[nome]])
  arquivos <- .sdic_arquivos_env()
  fontes <- c(list(as.list(Sys.getenv(nomes, unset = "", names = TRUE))), lapply(arquivos, .sdic_ler_env))
  rotulos <- c("variável de ambiente", arquivos)
  for (i in seq_along(fontes)) {
    for (candidato in nomes) {
      valor <- fontes[[i]][[candidato]]
      if (is.null(valor) || !nzchar(valor)) next
      if (candidato != nome && !isTRUE(.sdic_estado$avisados[[candidato]])) {
        .sdic_estado$avisados[[candidato]] <- TRUE
        warning(structure(
          class = c("deprecatedWarning", "warning", "condition"),
          list(message = sprintf("%s foi substituída por %s; a antiga continua valendo por enquanto.", candidato, nome),
               call = NULL)
        ))
      }
      return(list(valor = valor, de_onde = sprintf("%s (%s)", rotulos[i], candidato)))
    }
  }
  list(valor = .SDIC_PADROES[[nome]], de_onde = "padrão")
}

# URL base de uma origem do catálogo (`api`, `dados`, `politicas`), sem barra no fim.
.sdic_url <- function(origem, explicita = NULL) {
  origens <- .sdic_origens()
  if (!is.character(origem) || length(origem) != 1 || !origem %in% names(origens)) {
    .sdic_invalido(sprintf("Origem desconhecida: '%s'. Origens: %s.", paste(origem, collapse = ", "),
                           paste(sort(names(origens)), collapse = ", ")))
  }
  base <- .sdic_valor(origens[[origem]]$variavel, explicita)$valor %||% origens[[origem]]$url
  sub("/+$", "", base)
}

# Chave individual da sdic_api (`SDIC_API_KEY`); NULL se não houver.
.sdic_chave <- function(explicita = NULL) .sdic_valor("SDIC_API_KEY", explicita)$valor

# `producao` ou `homologacao` (`SDIC_AMBIENTE`; padrão `producao`).
.sdic_ambiente <- function(explicito = NULL) {
  amb <- tolower(trimws(.sdic_valor("SDIC_AMBIENTE", explicito)$valor %||% "producao"))
  if (!amb %in% .sdic_ambientes()) {
    .sdic_invalido(sprintf("Ambiente inválido: '%s'. Use %s.", amb, paste(.sdic_ambientes(), collapse = " ou ")))
  }
  amb
}

.sdic_inteiro <- function(nome, explicito = NULL) {
  v <- .sdic_valor(nome, explicito)
  numero <- suppressWarnings(as.numeric(v$valor))
  if (length(numero) != 1 || is.na(numero)) {
    .sdic_invalido(sprintf("%s deve ser um número de segundos; veio '%s' (%s).", nome, v$valor %||% "", v$de_onde))
  }
  as.integer(trunc(numero))
}

.sdic_timeout <- function(explicito = NULL) .sdic_inteiro("SDIC_TIMEOUT", explicito)
.sdic_cache_ttl <- function() .sdic_inteiro("SDIC_CACHE_TTL")

.sdic_pasta_cache <- function() {
  .sdic_valor("SDIC_CACHE_DIR")$valor %||% tools::R_user_dir("sdic.libraries", "cache")
}

# A chave só viaja por HTTPS (ou para a própria máquina, em teste).
.sdic_conferir_destino_da_chave <- function(base_url) {
  partes <- tryCatch(httr2::url_parse(base_url), error = function(e) list())
  locais <- c("localhost", "127.0.0.1", "::1", "[::1]")
  if (!identical(partes$scheme, "https") && !isTRUE(partes$hostname %in% locais)) {
    .sdic_invalido(sprintf(paste0(
      "A chave da API não é enviada para '%s': a URL precisa ser https://. ",
      "Confira SDIC_API_URL (sdic_config() mostra de onde o valor veio)."), base_url))
  }
  invisible(NULL)
}

#' O que a biblioteca está usando agora e de onde veio cada valor
#'
#' Cada configuração é resolvida nesta ordem: argumento da função, variável de ambiente,
#' `./.env.local`, `./.env`, `~/.env`, `/etc/sdic/.env`, padrão do catálogo. Os arquivos são
#' só lidos (o ambiente do processo não é alterado). Variáveis: `SDIC_API_KEY`,
#' `SDIC_API_URL`, `SDIC_DADOS_URL`, `SDIC_PAGES_URL`, `SDIC_AMBIENTE`, `SDIC_TIMEOUT`,
#' `SDIC_CACHE_TTL` e `SDIC_CACHE_DIR`. Os nomes antigos (`EMPLOYMENT_API_KEY`,
#' `COMEX_API_KEY`, `EMPLOYMENT_API_BASE_URL`, `COMEX_API_BASE_URL`,
#' `PORTAL_EMPREGO_BASE_URL`, `PORTAL_EMPREGO_AMBIENTE`, `API_TIMEOUT`) continuam valendo,
#' com aviso de depreciação.
#'
#' @return tibble com as colunas `item`, `valor`, `variavel`, `de_onde`. A chave nunca é
#'   mostrada: só se existe.
#' @examples
#' \dontrun{
#' sdic_config()
#' }
#' @export
sdic_config <- function() {
  linhas <- list()
  acrescentar <- function(item, valor, variavel, de_onde) {
    linhas[[length(linhas) + 1]] <<- list(item = item, valor = valor, variavel = variavel, de_onde = de_onde)
  }
  origens <- .sdic_origens()
  for (origem in names(origens)) {
    v <- .sdic_valor(origens[[origem]]$variavel)
    acrescentar(paste("origem", origem), sub("/+$", "", v$valor %||% origens[[origem]]$url),
                origens[[origem]]$variavel, v$de_onde)
  }
  k <- .sdic_valor("SDIC_API_KEY")
  tem_chave <- !is.null(k$valor)
  acrescentar("chave da API", if (tem_chave) "definida" else "não definida", "SDIC_API_KEY",
              if (tem_chave) k$de_onde else "-")
  itens <- c(ambiente = "SDIC_AMBIENTE", `timeout (s)` = "SDIC_TIMEOUT", `cache (s)` = "SDIC_CACHE_TTL")
  for (item in names(itens)) {
    v <- .sdic_valor(itens[[item]])
    acrescentar(item, v$valor %||% NA_character_, itens[[item]], v$de_onde)
  }
  v <- .sdic_valor("SDIC_CACHE_DIR")
  acrescentar("pasta do cache", .sdic_pasta_cache(), "SDIC_CACHE_DIR", v$de_onde)
  tibble::as_tibble(dplyr::bind_rows(linhas))
}
