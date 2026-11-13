# portal.R — DEPRECIADO: leitura do cache de emprego no layout antigo do GitHub Pages.
#
# Estes arquivos eram publicados pelo `cgid_cargas`, que foi desligado; o pipeline novo
# (`carga_base/publicacao`) não produz `cache/{UF}/emprego_cache.json`. As funções continuam
# funcionando enquanto os arquivos antigos existirem, com aviso de depreciação.
#
# Use no lugar: `get_kpis_publicados(uf, "emprego")`, `get_series_publicadas`,
# `get_ranking_publicado`, `get_detalhamento_publicado` e `get_secao_publicada`. Para saldo e
# estoque por divisão CNAE, use as funções da API (`get_saldo_emprego_estadual_mensal`,
# `get_estoque_emprego_estadual`). O arquivo `{UF}/emprego_relatorio.json` do bucket de dados
# não tem função: leia com `ler_json_publicado("dados", "<ambiente>/<UF>/emprego_relatorio.json")`.
# Espelho de `python/sdic_libraries/dados/emprego/portal.py`.

.PORTAL_EMPREGO_UFS_27 <- c(
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
  "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
  "SP", "SE", "TO"
)
.PORTAL_SUBSTITUTA_RELATORIO <- paste0(
  "get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ",
  "ler_json_publicado(\"dados\", \".../emprego_relatorio.json\")")
.PORTAL_SUBSTITUTA_PORTAL <- "get_kpis_publicados(uf, \"emprego\") e as demais funções de seções publicadas"

# ── Helpers internos ──────────────────────────────────────────────────────────

.portal_depreciada <- function(funcao, substituta) {
  .Deprecated(msg = sprintf("%s lê o layout antigo do Pages e será removida. Use %s.", funcao, substituta))
}

# GET de um JSON publicado (origem `politicas`, sem chave). Arquivo inexistente -> NULL se
# `opcional`; qualquer outra falha (rede, 5xx) é sempre erro.
.portal_emprego_fetch_json <- function(path, opcional = FALSE) {
  tryCatch(
    .sdic_json_publicado("politicas", path, simplifyVector = TRUE),
    sdic_nao_publicado = function(e) if (opcional) NULL else stop(e)
  )
}

.portal_emprego_relatorio <- function(uf, ambiente, opcional = FALSE) {
  .portal_emprego_fetch_json(sprintf("%s/cache/%s/emprego_cache.json", ambiente, toupper(uf)), opcional)
}

.portal_emprego_portal <- function(uf, ambiente, opcional = FALSE) {
  .portal_emprego_fetch_json(sprintf("%s/%s/emprego.json", ambiente, toupper(uf)), opcional)
}

# Empilha as UFs que têm arquivo, com a coluna `uf`, e avisa quais faltaram.
.portal_emprego_todos_estados <- function(por_uf) {
  frames <- list()
  for (uf in .PORTAL_EMPREGO_UFS_27) {
    df <- por_uf(uf)
    if (!is.null(df) && nrow(df) > 0) frames[[uf]] <- cbind(uf = uf, df)
  }
  if (length(frames) == 0) return(tibble::tibble())
  faltam <- sort(setdiff(.PORTAL_EMPREGO_UFS_27, names(frames)))
  if (length(faltam) > 0) {
    warning(sprintf("Sem arquivo publicado para %d UF(s): %s. O resultado não cobre o país inteiro.",
                    length(faltam), paste(faltam, collapse = ", ")), call. = FALSE)
  }
  tibble::as_tibble(dplyr::bind_rows(frames))
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

#' Relatório completo de emprego de uma UF (cache 1.0) — depreciada
#'
#' Lê o layout antigo do Pages e será removida. Use [get_saldo_emprego_estadual_mensal()] e
#' [get_estoque_emprego_estadual()] (API) ou
#' `ler_json_publicado("dados", "<ambiente>/<UF>/emprego_relatorio.json")`.
#'
#' @param uf Sigla da UF (ex.: "SP").
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @return `list(saldo, estoque, acum12m_total, metadata)`.
#' @export
get_relatorio_emprego_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_estadual", .PORTAL_SUBSTITUTA_RELATORIO)
  payload <- .portal_emprego_relatorio(uf, .sdic_ambiente(ambiente))
  acum <- if (is.null(payload$acum12m_total)) NULL else as.integer(payload$acum12m_total)
  list(
    saldo = .portal_emprego_df_saldo(payload),
    estoque = .portal_emprego_df_estoque(payload),
    acum12m_total = acum,
    metadata = payload$metadata %||% list()
  )
}

#' Saldo CAGED mensal por divisão CNAE (cache) de uma UF — depreciada
#'
#' Use [get_saldo_emprego_estadual_mensal()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble com o saldo mensal.
#' @export
get_relatorio_emprego_saldo_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_saldo_estadual", .PORTAL_SUBSTITUTA_RELATORIO)
  .portal_emprego_df_saldo(.portal_emprego_relatorio(uf, .sdic_ambiente(ambiente)))
}

#' Estoque RAIS por divisão CNAE (cache) de uma UF — depreciada
#'
#' Use [get_estoque_emprego_estadual()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble com o estoque.
#' @export
get_relatorio_emprego_estoque_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_estoque_estadual", .PORTAL_SUBSTITUTA_RELATORIO)
  .portal_emprego_df_estoque(.portal_emprego_relatorio(uf, .sdic_ambiente(ambiente)))
}

#' Metadados do relatório (reference, fonte, gerado_em, ...) de uma UF — depreciada
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista de metadados.
#' @export
get_relatorio_emprego_metadata_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_metadata_estadual", .PORTAL_SUBSTITUTA_RELATORIO)
  .portal_emprego_relatorio(uf, .sdic_ambiente(ambiente))$metadata %||% list()
}

#' Saldo de todas as UFs disponíveis, empilhado, com coluna `uf` — depreciada
#'
#' Avisa quais UFs não têm arquivo publicado. Falha de rede é erro (só arquivo inexistente é
#' tratado como UF ausente).
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble empilhado.
#' @export
get_relatorio_emprego_saldo_todos_estados <- function(ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_saldo_todos_estados", .PORTAL_SUBSTITUTA_RELATORIO)
  amb <- .sdic_ambiente(ambiente)
  .portal_emprego_todos_estados(function(uf) .portal_emprego_df_saldo(.portal_emprego_relatorio(uf, amb, opcional = TRUE)))
}

#' Estoque de todas as UFs disponíveis, empilhado, com coluna `uf` — depreciada
#'
#' Avisa quais UFs não têm arquivo publicado. Falha de rede é erro.
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble empilhado.
#' @export
get_relatorio_emprego_estoque_todos_estados <- function(ambiente = NULL) {
  .portal_depreciada("get_relatorio_emprego_estoque_todos_estados", .PORTAL_SUBSTITUTA_RELATORIO)
  amb <- .sdic_ambiente(ambiente)
  .portal_emprego_todos_estados(function(uf) .portal_emprego_df_estoque(.portal_emprego_relatorio(uf, amb, opcional = TRUE)))
}

# ── PORTAL (payload v1.1) ─────────────────────────────────────────────────────

#' Payload completo do portal (v1.1) de uma UF — depreciada
#'
#' Use [get_secao_publicada()] e as demais funções de seções publicadas.
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista com o payload do portal, como publicado.
#' @export
get_portal_emprego_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  .portal_emprego_portal(uf, .sdic_ambiente(ambiente)) %||% list()
}

#' KPI de capa (`capa_kpi`) de uma UF — depreciada
#'
#' Use [get_kpis_publicados()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista com o KPI de capa.
#' @export
get_portal_emprego_capa_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_capa_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  .portal_emprego_portal(uf, .sdic_ambiente(ambiente))$capa_kpi %||% list()
}

#' KPIs do portal de uma UF como tibble — depreciada
#'
#' Use [get_kpis_publicados()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble de KPIs.
#' @export
get_portal_emprego_kpis_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_kpis_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  payload <- .portal_emprego_portal(uf, .sdic_ambiente(ambiente))
  if (is.null(payload$kpis) || length(payload$kpis) == 0) return(tibble::tibble())
  tibble::as_tibble(payload$kpis)
}

#' Séries dos gráficos do portal de uma UF — depreciada
#'
#' Use [get_series_publicadas()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{chart_id: tibble(competencia, valor)}`.
#' @export
get_portal_emprego_charts_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_charts_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  payload <- .portal_emprego_portal(uf, .sdic_ambiente(ambiente))
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

#' Rankings do portal (maiores saldos/estoques) de uma UF — depreciada
#'
#' Use [get_ranking_publicado()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{list_id: tibble(items)}`.
#' @export
get_portal_emprego_ranked_lists_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_ranked_lists_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  payload <- .portal_emprego_portal(uf, .sdic_ambiente(ambiente))
  .portal_emprego_named_tibbles(payload$ranked_lists, "items", "rank")
}

#' Composições do portal (ex.: intensidade tecnológica) de uma UF — depreciada
#'
#' Use [get_detalhamento_publicado()].
#' @inheritParams get_relatorio_emprego_estadual
#' @return Lista nomeada `{id: tibble(items)}`.
#' @export
get_portal_emprego_breakdowns_estadual <- function(uf, ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_breakdowns_estadual", .PORTAL_SUBSTITUTA_PORTAL)
  payload <- .portal_emprego_portal(uf, .sdic_ambiente(ambiente))
  .portal_emprego_named_tibbles(payload$breakdowns, "items", "breakdown")
}

#' KPIs de todas as UFs disponíveis, empilhados, com coluna `uf` — depreciada
#'
#' Avisa quais UFs não têm arquivo publicado. Falha de rede é erro.
#' @inheritParams get_relatorio_emprego_estadual
#' @return Tibble empilhado — comparação entre estados.
#' @export
get_portal_emprego_kpis_todos_estados <- function(ambiente = NULL) {
  .portal_depreciada("get_portal_emprego_kpis_todos_estados", .PORTAL_SUBSTITUTA_PORTAL)
  amb <- .sdic_ambiente(ambiente)
  .portal_emprego_todos_estados(function(uf) {
    kpis <- .portal_emprego_portal(uf, amb, opcional = TRUE)$kpis
    if (is.null(kpis) || length(kpis) == 0) NULL else tibble::as_tibble(kpis)
  })
}

# ── Descoberta ────────────────────────────────────────────────────────────────

#' Lista as UFs com artefato publicado — depreciada
#'
#' Use [listar_secoes_publicadas()].
#' @inheritParams get_relatorio_emprego_estadual
#' @param tipo "portal" (emprego.json) ou "relatorio" (cache).
#' @return Vetor de siglas de UF disponíveis.
#' @export
listar_estados_disponiveis <- function(ambiente = NULL, tipo = "portal") {
  .portal_depreciada("listar_estados_disponiveis", "listar_secoes_publicadas()")
  amb <- .sdic_ambiente(ambiente)
  ler <- if (identical(tipo, "relatorio")) .portal_emprego_relatorio else .portal_emprego_portal
  Filter(function(uf) !is.null(ler(uf, amb, opcional = TRUE)), .PORTAL_EMPREGO_UFS_27)
}
