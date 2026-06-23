#' Leitura dos artefatos de emprego publicados no GitHub Pages
#'
#' Lado leitor do pipeline de emprego. O projeto `cgid_cargas` busca CAGED/RAIS
#' (via a API desta biblioteca), gera dois artefatos por estado e os publica no
#' GitHub Pages, em dois ambientes (`producao` e `homologacao`):
#'
#' \preformatted{
#'   Portal    : <BASE>/{ambiente}/{UF}/emprego.json             (schema v1.1)
#'   Relatorio : <BASE>/{ambiente}/cache/{UF}/emprego_cache.json (schema 1.0)
#' }
#'
#' Estas funcoes leem esses JSONs de volta e os entregam como `tibble`/`list`:
#'   - Relatorio (cache 1.0): dados brutos `saldo` (CAGED mensal por divisao
#'     CNAE), `estoque` (RAIS por divisao) e `acum12m_total`. Para analise.
#'   - Portal (v1.1): payload pronto para apresentacao (`capa_kpi`, `kpis`,
#'     `charts`, `ranked_lists`, `breakdowns`), ja em pt-BR.
#'
#' Configuracao via variaveis de ambiente:
#'   `PORTAL_EMPREGO_BASE_URL` (URL base) e `PORTAL_EMPREGO_AMBIENTE` (ambiente).
#'
#' @importFrom httr2 request req_timeout req_headers req_error req_perform resp_status resp_body_json
#' @importFrom tibble as_tibble tibble
#' @importFrom rlang abort
#' @name portal_emprego
NULL

# URL publica base onde o cgid_cargas publica os artefatos de emprego.
.PORTAL_EMPREGO_BASE_URL_DEFAULT <- "https://amiltonmendes.github.io/sdic_libraries"
.PORTAL_EMPREGO_UFS_27 <- c(
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
  "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
  "SP", "SE", "TO"
)

# ── Helpers internos ──────────────────────────────────────────────────────────

.portal_emprego_base_url <- function() {
  url <- Sys.getenv("PORTAL_EMPREGO_BASE_URL", unset = "")
  if (!nzchar(url)) url <- .PORTAL_EMPREGO_BASE_URL_DEFAULT
  sub("/+$", "", url)
}

.portal_emprego_validar_ambiente <- function(ambiente) {
  amb <- tolower(trimws(ambiente %||% "producao"))
  if (!amb %in% c("producao", "homologacao")) {
    rlang::abort(sprintf(
      "ambiente invalido: '%s'. Use 'producao' ou 'homologacao'.", ambiente
    ))
  }
  amb
}

.portal_emprego_path_portal <- function(uf, ambiente) {
  sprintf("%s/%s/emprego.json", ambiente, toupper(uf))
}

.portal_emprego_path_relatorio <- function(uf, ambiente) {
  sprintf("%s/cache/%s/emprego_cache.json", ambiente, toupper(uf))
}

# GET de um JSON publicado. 404 -> NULL se opcional, senao erro.
.portal_emprego_fetch_json <- function(path, opcional = FALSE) {
  timeout <- as.integer(Sys.getenv("API_TIMEOUT", unset = "30"))
  version <- Sys.getenv("SDIC_VERSION", unset = "0.4.0")
  url <- paste0(.portal_emprego_base_url(), "/", sub("^/+", "", path))

  resp <- tryCatch(
    httr2::request(url) |>
      httr2::req_timeout(timeout) |>
      httr2::req_headers(
        Accept = "application/json",
        `User-Agent` = paste0("sdic-libraries/", version)
      ) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) {
      if (opcional) return(NULL)
      rlang::abort(paste0(
        "Problema de conectividade ao buscar dados publicados. ",
        "Verifique sua conexao e tente novamente."
      ))
    }
  )
  if (is.null(resp)) return(NULL)

  status <- httr2::resp_status(resp)
  if (status == 404) {
    if (opcional) return(NULL)
    rlang::abort(sprintf("Artefato nao encontrado (404): %s", path))
  }
  if (status >= 400) {
    rlang::abort(sprintf("Falha ao buscar artefato publicado (HTTP %s).", status))
  }
  httr2::resp_body_json(resp, simplifyVector = TRUE)
}

# Reforca dtypes do saldo (competencia/cnae_divisao como character com zero a esquerda).
.portal_emprego_df_saldo <- function(payload) {
  saldo <- if (is.null(payload)) NULL else payload$saldo
  if (is.null(saldo) || length(saldo) == 0) return(tibble::tibble())
  df <- tibble::as_tibble(saldo)
  if ("competencia" %in% names(df)) {
    df$competencia <- formatC(as.integer(df$competencia), width = 6, format = "d", flag = "0")
  }
  if ("cnae_divisao" %in% names(df)) {
    df$cnae_divisao <- formatC(as.integer(df$cnae_divisao), width = 2, format = "d", flag = "0")
  }
  df
}

.portal_emprego_df_estoque <- function(payload) {
  estoque <- if (is.null(payload)) NULL else payload$estoque
  if (is.null(estoque) || length(estoque) == 0) return(tibble::tibble())
  df <- tibble::as_tibble(estoque)
  if ("cnae_divisao" %in% names(df)) {
    df$cnae_divisao <- formatC(as.integer(df$cnae_divisao), width = 2, format = "d", flag = "0")
  }
  df
}

# Lista de objetos (ranked_lists/breakdowns) -> lista nomeada de tibbles.
# `simplifyVector` entrega um data.frame com `items` como list-column de data.frames.
.portal_emprego_named_tibbles <- function(itens, campo_itens, prefixo) {
  out <- list()
  if (is.null(itens) || length(itens) == 0) return(out)
  if (is.data.frame(itens)) {
    n <- nrow(itens)
    ids <- if (!is.null(itens$id)) as.character(itens$id) else rep(NA_character_, n)
    conteudos <- itens[[campo_itens]]
    for (i in seq_len(n)) {
      id <- if (!is.na(ids[i]) && nzchar(ids[i])) ids[i] else sprintf("%s_%d", prefixo, i)
      conteudo <- if (is.list(conteudos)) conteudos[[i]] else conteudos
      out[[id]] <- if (is.null(conteudo) || length(conteudo) == 0) tibble::tibble() else tibble::as_tibble(conteudo)
    }
  } else {
    for (i in seq_along(itens)) {
      el <- itens[[i]]
      id <- el$id %||% sprintf("%s_%d", prefixo, i)
      conteudo <- el[[campo_itens]]
      out[[id]] <- if (is.null(conteudo) || length(conteudo) == 0) tibble::tibble() else tibble::as_tibble(conteudo)
    }
  }
  out
}

# ── RELATORIO (cache 1.0 — dados brutos) ──────────────────────────────────────

#' Relatorio completo de emprego de uma UF (cache 1.0)
#'
#' @param uf Sigla da UF (ex.: "SP").
#' @param ambiente "producao" (default) ou "homologacao".
#' @return `list(saldo, estoque, acum12m_total, metadata)`.
#' @export
get_relatorio_emprego_estadual <- function(uf, ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb))
  acum <- if (is.null(payload$acum12m_total)) NULL else as.integer(payload$acum12m_total)
  list(
    saldo = .portal_emprego_df_saldo(payload),
    estoque = .portal_emprego_df_estoque(payload),
    acum12m_total = acum,
    metadata = payload$metadata %||% list()
  )
}

#' Saldo CAGED mensal por divisao CNAE (cache) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble com o saldo mensal.
#' @export
get_relatorio_emprego_saldo_estadual <- function(uf, ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb))
  .portal_emprego_df_saldo(payload)
}

#' Estoque RAIS por divisao CNAE (cache) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble com o estoque.
#' @export
get_relatorio_emprego_estoque_estadual <- function(uf, ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb))
  .portal_emprego_df_estoque(payload)
}

#' Metadados do relatorio (reference, fonte, gerado_em, ...) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista de metadados.
#' @export
get_relatorio_emprego_metadata_estadual <- function(uf, ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb))
  payload$metadata %||% list()
}

#' Saldo de todas as UFs disponiveis, empilhado, com coluna `uf`
#' @param ambiente "producao" (default) ou "homologacao".
#' @return Tibble empilhado.
#' @export
get_relatorio_emprego_saldo_todos_estados <- function(ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  frames <- list()
  for (uf in .PORTAL_EMPREGO_UFS_27) {
    payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb), opcional = TRUE)
    df <- .portal_emprego_df_saldo(payload)
    if (nrow(df) > 0) {
      df <- cbind(uf = uf, df)
      frames[[length(frames) + 1]] <- df
    }
  }
  if (length(frames) == 0) return(tibble::tibble())
  tibble::as_tibble(dplyr::bind_rows(frames))
}

#' Estoque de todas as UFs disponiveis, empilhado, com coluna `uf`
#' @param ambiente "producao" (default) ou "homologacao".
#' @return Tibble empilhado.
#' @export
get_relatorio_emprego_estoque_todos_estados <- function(ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  frames <- list()
  for (uf in .PORTAL_EMPREGO_UFS_27) {
    payload <- .portal_emprego_fetch_json(.portal_emprego_path_relatorio(uf, amb), opcional = TRUE)
    df <- .portal_emprego_df_estoque(payload)
    if (nrow(df) > 0) {
      df <- cbind(uf = uf, df)
      frames[[length(frames) + 1]] <- df
    }
  }
  if (length(frames) == 0) return(tibble::tibble())
  tibble::as_tibble(dplyr::bind_rows(frames))
}

# ── PORTAL (payload v1.1) ─────────────────────────────────────────────────────

#' Payload completo do portal (v1.1) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista com o payload do portal, como publicado.
#' @export
get_portal_emprego_estadual <- function(uf, ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  .portal_emprego_fetch_json(.portal_emprego_path_portal(uf, amb)) %||% list()
}

#' KPI de capa (`capa_kpi`) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista com o KPI de capa.
#' @export
get_portal_emprego_capa_estadual <- function(uf, ambiente = "producao") {
  payload <- get_portal_emprego_estadual(uf, ambiente)
  payload$capa_kpi %||% list()
}

#' KPIs do portal de uma UF como tibble
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble de KPIs.
#' @export
get_portal_emprego_kpis_estadual <- function(uf, ambiente = "producao") {
  payload <- get_portal_emprego_estadual(uf, ambiente)
  if (is.null(payload$kpis) || length(payload$kpis) == 0) return(tibble::tibble())
  tibble::as_tibble(payload$kpis)
}

#' Series dos graficos do portal de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{chart_id: tibble(competencia, valor)}`.
#' @export
get_portal_emprego_charts_estadual <- function(uf, ambiente = "producao") {
  payload <- get_portal_emprego_estadual(uf, ambiente)
  charts <- payload$charts
  out <- list()
  if (is.null(charts) || length(charts) == 0) return(out)

  # `series` é list-column; cada elemento é um data.frame de séries, cuja
  # coluna `points` é, por sua vez, um data.frame com colunas t/v.
  primeira_serie_points <- function(serie) {
    if (is.null(serie)) return(NULL)
    if (is.data.frame(serie)) {
      pts <- serie$points
      if (is.list(pts)) pts[[1]] else pts
    } else {
      s1 <- serie[[1]]
      s1$points
    }
  }
  monta_pts <- function(pts) {
    if (is.null(pts) || length(pts) == 0) return(tibble::tibble())
    p <- tibble::as_tibble(pts)
    tibble::tibble(competencia = p$t, valor = p$v)
  }

  if (is.data.frame(charts)) {
    n <- nrow(charts)
    ids <- if (!is.null(charts$id)) as.character(charts$id) else rep(NA_character_, n)
    series_col <- charts$series
    for (i in seq_len(n)) {
      id <- if (!is.na(ids[i]) && nzchar(ids[i])) ids[i] else sprintf("chart_%d", i)
      serie <- if (is.list(series_col)) series_col[[i]] else series_col
      out[[id]] <- monta_pts(primeira_serie_points(serie))
    }
  } else {
    for (i in seq_along(charts)) {
      ch <- charts[[i]]
      id <- ch$id %||% sprintf("chart_%d", i)
      out[[id]] <- monta_pts(primeira_serie_points(ch$series))
    }
  }
  out
}

#' Rankings do portal (maiores saldos/estoques) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{list_id: tibble(items)}`.
#' @export
get_portal_emprego_ranked_lists_estadual <- function(uf, ambiente = "producao") {
  payload <- get_portal_emprego_estadual(uf, ambiente)
  .portal_emprego_named_tibbles(payload$ranked_lists, "items", "rank")
}

#' Composicoes do portal (ex.: intensidade tecnologica) de uma UF
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{id: tibble(items)}`.
#' @export
get_portal_emprego_breakdowns_estadual <- function(uf, ambiente = "producao") {
  payload <- get_portal_emprego_estadual(uf, ambiente)
  .portal_emprego_named_tibbles(payload$breakdowns, "items", "breakdown")
}

#' KPIs de todas as UFs disponiveis, empilhados, com coluna `uf`
#' @param ambiente "producao" (default) ou "homologacao".
#' @return Tibble empilhado — comparacao entre estados.
#' @export
get_portal_emprego_kpis_todos_estados <- function(ambiente = "producao") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  frames <- list()
  for (uf in .PORTAL_EMPREGO_UFS_27) {
    payload <- .portal_emprego_fetch_json(.portal_emprego_path_portal(uf, amb), opcional = TRUE)
    if (!is.null(payload$kpis) && length(payload$kpis) > 0) {
      df <- cbind(uf = uf, tibble::as_tibble(payload$kpis))
      frames[[length(frames) + 1]] <- df
    }
  }
  if (length(frames) == 0) return(tibble::tibble())
  tibble::as_tibble(dplyr::bind_rows(frames))
}

# ── Descoberta ────────────────────────────────────────────────────────────────

#' Lista as UFs com artefato publicado
#'
#' @param ambiente "producao" (default) ou "homologacao".
#' @param tipo "portal" (emprego.json) ou "relatorio" (cache).
#' @return Vetor de siglas de UF disponiveis.
#' @export
listar_estados_disponiveis <- function(ambiente = "producao", tipo = "portal") {
  amb <- .portal_emprego_validar_ambiente(ambiente)
  disponiveis <- character(0)
  for (uf in .PORTAL_EMPREGO_UFS_27) {
    path <- if (identical(tipo, "relatorio")) {
      .portal_emprego_path_relatorio(uf, amb)
    } else {
      .portal_emprego_path_portal(uf, amb)
    }
    payload <- .portal_emprego_fetch_json(path, opcional = TRUE)
    if (!is.null(payload)) disponiveis <- c(disponiveis, uf)
  }
  disponiveis
}
