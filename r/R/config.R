# Configuração da biblioteca: o único lugar que lê variável de ambiente e arquivo `.env`.
#
# Cada valor é resolvido nesta ordem: argumento da função, variável de ambiente, `.env.local`,
# `.env` (diretório atual), o arquivo do usuário gravado por `salvar_chave()` (`~/.config/sdic/.env`),
# `~/.env`, `/etc/sdic/.env`, padrão do catálogo. Fora `salvar_chave()`, os arquivos são só lidos:
# nada é gravado no ambiente do processo (`Sys.setenv`), e só os nomes desta biblioteca são considerados. `sdic_config()` mostra o que está valendo e de onde veio.
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
  c(file.path(getwd(), ".env.local"), file.path(getwd(), ".env"), .sdic_arquivo_do_usuario(),
    file.path(.sdic_home(), ".env"), "/etc/sdic/.env")
}

# Arquivo de configuração do usuário, o que `salvar_chave()` grava. O mesmo do Python:
# `%APPDATA%/sdic/.env` no Windows; `$XDG_CONFIG_HOME/sdic/.env` (padrão `~/.config/sdic/.env`) nos demais.
.sdic_arquivo_do_usuario <- function() {
  appdata <- Sys.getenv("APPDATA")
  if (.Platform$OS.type == "windows" && nzchar(appdata)) return(file.path(appdata, "sdic", ".env"))
  xdg <- Sys.getenv("XDG_CONFIG_HOME")
  file.path(if (nzchar(xdg)) xdg else file.path(.sdic_home(), ".config"), "sdic", ".env")
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
#' `./.env.local`, `./.env`, `~/.config/sdic/.env` (gravado por [salvar_chave()]), `~/.env`,
#' `/etc/sdic/.env`, padrão do catálogo. Os arquivos são
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

# Pede a chave sem mostrar o que é digitado, quando há como (RStudio ou pacote askpass).
.sdic_perguntar_chave <- function() {
  if (!interactive()) .sdic_invalido("Informe a chave: salvar_chave(\"...\") (sessão não interativa).")
  pergunta <- "Chave da sdic_api (não aparece na tela): "
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    return(rstudioapi::askForPassword(pergunta))
  }
  if (requireNamespace("askpass", quietly = TRUE)) return(askpass::askpass(pergunta))
  cli::cli_alert_warning("Sem RStudio nem o pacote askpass, a chave aparece na tela enquanto é digitada.")
  readline(pergunta)
}

.sdic_testar_chave <- function(chave) {
  base <- .sdic_url("api")
  .sdic_conferir_destino_da_chave(base)
  resp <- tryCatch(httr2::req_perform(.sdic_requisicao(paste0(base, "/series"), .sdic_timeout(), chave)),
                   error = function(e) e)
  if (inherits(resp, "error")) {
    .sdic_abortar(sprintf(paste0("Não foi possível falar com a API (%s) para conferir a chave. Nada foi salvo. ",
                                 "Sem rede, use salvar_chave(..., testar = FALSE)."), base), endpoint = "/series")
  }
  status <- httr2::resp_status(resp)
  if (status %in% c(401L, 403L)) .sdic_invalido(sprintf("A API recusou a chave (HTTP %s). Nada foi salvo.", status))
  if (status >= 400) {
    .sdic_abortar(sprintf("A API respondeu HTTP %s ao conferir a chave. Nada foi salvo.", status),
                  status_code = status, endpoint = "/series")
  }
  invisible(TRUE)
}

#' Guarda a chave da sdic_api no arquivo de configuração do usuário
#'
#' Sem `chave`, pergunta sem mostrar o que é digitado (no RStudio ou com o pacote `askpass`):
#' é melhor do que escrever a chave no código, que fica no histórico. Com `testar = TRUE`, confere
#' a chave na API antes de gravar; chave recusada não é salva. O arquivo é
#' `~/.config/sdic/.env` (`%APPDATA%/sdic/.env` no Windows), legível só pelo dono, e vale para R
#' e para Python. Chamar de novo troca a chave. Uma `SDIC_API_KEY` em variável de ambiente ou no
#' `.env.local`/`.env` da pasta atual continua tendo precedência (há aviso quando isso acontece).
#'
#' @param chave A chave individual. Se omitida, é pedida.
#' @param testar Conferir a chave na API antes de salvar.
#' @return O caminho do arquivo gravado, invisível.
#' @examples
#' \dontrun{
#' salvar_chave()   # pergunta a chave
#' sdic_config()    # "chave da API: definida", com o arquivo de onde veio
#' }
#' @export
salvar_chave <- function(chave = NULL, testar = TRUE) {
  if (is.null(chave)) chave <- .sdic_perguntar_chave()
  chave <- trimws(as.character(chave %||% ""))
  if (length(chave) != 1 || is.na(chave) || nchar(chave) < 16 || grepl("[[:space:]=#\"']", chave)) {
    .sdic_invalido("Chave inválida: esperava o texto recebido do dono do projeto, sem espaços. Nada foi salvo.")
  }
  if (isTRUE(testar)) .sdic_testar_chave(chave)
  arquivo <- .sdic_arquivo_do_usuario()
  pasta <- dirname(arquivo)
  dir.create(pasta, recursive = TRUE, showWarnings = FALSE, mode = "0700")
  Sys.chmod(pasta, "0700")
  linhas <- if (file.exists(arquivo)) readLines(arquivo, warn = FALSE, encoding = "UTF-8") else character()
  nomes <- trimws(sub("=.*$", "", sub("^\\s*export\\s+", "", linhas)))
  linhas <- c(linhas[nomes != "SDIC_API_KEY"], paste0("SDIC_API_KEY=", chave))
  temporario <- paste0(arquivo, ".tmp")
  file.create(temporario)
  Sys.chmod(temporario, "0600")  # antes de escrever: a chave nunca fica num arquivo aberto a outros
  writeLines(linhas, temporario, useBytes = TRUE)
  if (!file.rename(temporario, arquivo)) .sdic_invalido(sprintf("Não foi possível gravar %s.", arquivo))
  Sys.chmod(arquivo, "0600")
  de_onde <- .sdic_valor("SDIC_API_KEY")$de_onde
  if (!startsWith(de_onde, arquivo)) {
    warning(sprintf("Chave salva em %s, mas vale a de %s, que tem precedência. Apague-a de lá para usar a salva.",
                    arquivo, de_onde), call. = FALSE)
  }
  cli::cli_alert_success("Chave salva em {.path {arquivo}} (só você pode ler). {.code sdic_config()} mostra de onde ela vem.")
  invisible(arquivo)
}
