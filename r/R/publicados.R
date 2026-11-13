# Seções publicadas em JSON (as mesmas que o portal e os subsídios mostram).
#
# Os arquivos são gerados do BigQuery pelo job `publicar-dados` (`carga_base/publicacao`) no
# contrato v1.1 e ficam na origem `dados` do catálogo. Aqui eles viram tabelas. O local e o
# ambiente vêm de `config.R` (`SDIC_DADOS_URL`, `SDIC_AMBIENTE`).
# Espelho de `python/sdic_libraries/publicados.py`.

.SDIC_UFS <- c("AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT", "PA", "PB", "PE",
               "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO")
.SDIC_SCHEMA_MAIOR <- "1"  # contrato v1.x; uma versão 2 muda o formato e precisa de biblioteca nova

# Normaliza a unidade: sigla da UF em maiúsculas, ou `BRASIL` para NULL, "BR", "brasil", "nacional".
.sdic_unidade <- function(uf) {
  if (is.null(uf) || length(uf) == 0 || is.na(uf)) return("BRASIL")
  u <- toupper(trimws(uf))
  if (u %in% c("", "BR", "BRASIL", "NACIONAL")) return("BRASIL")
  if (!u %in% .SDIC_UFS) .sdic_invalido(sprintf("UF inválida: '%s'. Use a sigla (ex.: 'SP') ou 'BRASIL'.", uf))
  u
}

.sdic_versao_suportada <- function(payload, mensagem) {
  versao <- as.character(payload$schema_version %||% "1")
  if (strsplit(versao, ".", fixed = TRUE)[[1]][1] != .SDIC_SCHEMA_MAIOR) .sdic_invalido(sprintf(mensagem, versao))
  invisible(TRUE)
}

# Número de verdade (não texto, não lógico) ou NA.
.sdic_numero <- function(v) if (is.numeric(v) && length(v) == 1) as.numeric(v) else NA_real_

# Registros -> tibble com as colunas que o catálogo declara para `funcao`, com os tipos fixos.
.publicados_tabela <- function(linhas, funcao, numericas = "valor", logicas = character(), inteiras = character()) {
  df <- .sdic_tabela(linhas, .sdic_colunas_de(funcao))
  for (coluna in names(df)) {
    df[[coluna]] <- if (coluna %in% numericas) {
      .sdic_numerico(df[[coluna]])
    } else if (coluna %in% logicas) {
      as.logical(df[[coluna]])
    } else if (coluna %in% inteiras) {
      as.integer(df[[coluna]])
    } else {
      as.character(df[[coluna]])
    }
  }
  df
}

#' Seções publicadas em JSON e para quais unidades existem
#'
#' @return tibble com as colunas `secao`, `titulo`, `unidades`, `fonte`.
#' @examples
#' \dontrun{
#' listar_secoes_publicadas()
#' }
#' @export
listar_secoes_publicadas <- function() {
  secoes <- .sdic_catalogo()$secoes
  linhas <- lapply(names(secoes), function(nome) {
    list(secao = nome, titulo = secoes[[nome]]$titulo, unidades = secoes[[nome]]$unidades, fonte = secoes[[nome]]$fonte)
  })
  .publicados_tabela(linhas, "listar_secoes_publicadas", numericas = character())
}

#' JSON completo de uma seção publicada (contrato v1.1)
#'
#' Baixo nível: devolve a lista como publicada. Para tabelas, use [get_kpis_publicados()],
#' [get_series_publicadas()], [get_ranking_publicado()], [get_detalhamento_publicado()] e
#' [get_destaques_publicados()].
#'
#' @param uf Sigla da UF, ou `"BRASIL"` (ou `NULL`) para o país.
#' @param secao Uma de `listar_secoes_publicadas()$secao`, ex.: `"emprego"`, `"comercio"`,
#'   `"pib_estadual"`, `"producao_industrial"`.
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @return Lista com o conteúdo do arquivo (`capa_kpi`, `kpis`, `charts`, `ranked_lists`,
#'   `breakdowns`, `story`, `source`, `reference`, `updated_at`). Arquivo que não existe nesse
#'   ambiente para essa unidade gera erro da classe `sdic_nao_publicado`; seção, UF ou
#'   ambiente inválidos e versão do contrato não suportada, erro `sdic_valor_invalido`.
#' @examples
#' \dontrun{
#' get_secao_publicada("SP", "emprego", ambiente = "homologacao")$reference
#' }
#' @export
get_secao_publicada <- function(uf, secao, ambiente = NULL) {
  secoes <- .sdic_catalogo()$secoes
  if (!is.character(secao) || length(secao) != 1 || !secao %in% names(secoes)) {
    .sdic_invalido(sprintf("Seção desconhecida: '%s'. Seções: %s.", paste(secao, collapse = ", "),
                           paste(sort(names(secoes), method = "radix"), collapse = ", ")))
  }
  u <- .sdic_unidade(uf)
  amb <- .sdic_ambiente(ambiente)
  if (secoes[[secao]]$unidades == "BRASIL" && u != "BRASIL") {
    .sdic_invalido(sprintf("A seção '%s' só existe para o Brasil (uf = 'BRASIL').", secao))
  }
  payload <- tryCatch(
    .sdic_json_publicado("dados", sprintf("%s/%s/%s.json", amb, u, secoes[[secao]]$arquivo)),
    sdic_nao_publicado = function(e) {
      .sdic_abortar(sprintf(paste0("A seção '%s' de %s não está publicada em '%s' (%s). ",
                                   "Em homologação ela pode existir: ambiente = 'homologacao'."),
                            secao, u, amb, e$endpoint),
                    status_code = e$status_code, endpoint = e$endpoint, classe = "sdic_nao_publicado")
    }
  )
  .sdic_versao_suportada(payload, paste0("A seção '", secao,
    "' está no contrato %s, que esta versão da biblioteca não lê. Atualize-a."))
  payload
}

#' Indicadores de uma seção publicada
#'
#' Um indicador por linha, o de capa primeiro.
#'
#' @inheritParams get_secao_publicada
#' @return tibble com as colunas `secao`, `uf`, `id`, `rotulo`, `valor`, `valor_exibido`,
#'   `unidade`, `periodo`, `capa`, `variacao_direcao`, `variacao_rotulo`, `fonte`,
#'   `referencia`, `atualizado_em`. `valor_exibido` é o texto formatado que o portal mostra.
#' @examples
#' \dontrun{
#' get_kpis_publicados("SP", "emprego")[, c("rotulo", "valor_exibido", "periodo")]
#' }
#' @export
get_kpis_publicados <- function(uf, secao, ambiente = NULL) {
  p <- get_secao_publicada(uf, secao, ambiente)
  itens <- c(if (.sdic_e_objeto(p$capa_kpi)) list(list(k = p$capa_kpi, capa = TRUE)),
             lapply(p$kpis, function(k) list(k = k, capa = FALSE)))
  linhas <- lapply(itens, function(item) {
    k <- item$k
    list(secao = secao, uf = .sdic_unidade(uf), id = k$id, rotulo = k$label, valor = .sdic_numero(k$value),
         valor_exibido = k$display_value, unidade = k$unit, periodo = k$period, capa = item$capa,
         variacao_direcao = k$delta$dir, variacao_rotulo = k$delta$label, fonte = p$source,
         referencia = p$reference, atualizado_em = p$updated_at)
  })
  .publicados_tabela(linhas, "get_kpis_publicados", logicas = "capa")
}

#' Séries dos gráficos de uma seção publicada, em formato longo
#'
#' @inheritParams get_secao_publicada
#' @return tibble com as colunas `secao`, `uf`, `grafico`, `grafico_titulo`, `unidade`,
#'   `serie`, `serie_rotulo`, `t` (período como publicado), `v` (valor).
#' @examples
#' \dontrun{
#' s <- get_series_publicadas("SP", "emprego")
#' s[s$grafico == "saldo_mensal_serie", ]
#' }
#' @export
get_series_publicadas <- function(uf, secao, ambiente = NULL) {
  p <- get_secao_publicada(uf, secao, ambiente)
  u <- .sdic_unidade(uf)
  linhas <- list()
  for (g in p$charts) for (s in g$series) for (ponto in s$points) {
    linhas[[length(linhas) + 1]] <- list(
      secao = secao, uf = u, grafico = g$id, grafico_titulo = g$title, unidade = g$unit, serie = s$id,
      serie_rotulo = s$label, t = if (is.null(ponto$t)) NA else as.character(ponto$t), v = .sdic_numero(ponto$v))
  }
  .publicados_tabela(linhas, "get_series_publicadas", numericas = "v")
}

#' Listas ordenadas de uma seção publicada
#'
#' Um item por linha, na ordem publicada.
#'
#' @inheritParams get_secao_publicada
#' @return tibble com as colunas `secao`, `uf`, `lista`, `titulo`, `metrica`, `unidade`,
#'   `tom`, `posicao`, `nome`, `valor`, `valor_exibido`.
#' @examples
#' \dontrun{
#' get_ranking_publicado("SP", "emprego")
#' }
#' @export
get_ranking_publicado <- function(uf, secao, ambiente = NULL) {
  p <- get_secao_publicada(uf, secao, ambiente)
  u <- .sdic_unidade(uf)
  linhas <- list()
  for (l in p$ranked_lists) for (n in seq_along(l$items)) {
    i <- l$items[[n]]
    linhas[[length(linhas) + 1]] <- list(
      secao = secao, uf = u, lista = l$id, titulo = l$title, metrica = l$metric_label, unidade = l$unit,
      tom = l$tone, posicao = n, nome = i$name, valor = .sdic_numero(i$value), valor_exibido = i$display_value)
  }
  .publicados_tabela(linhas, "get_ranking_publicado", inteiras = "posicao")
}

#' Composições de uma seção publicada
#'
#' Ex.: emprego por intensidade tecnológica.
#'
#' @inheritParams get_secao_publicada
#' @return tibble com as colunas `secao`, `uf`, `detalhamento`, `titulo`, `dimensao`,
#'   `unidade`, `periodo`, `nome`, `valor`, `valor_exibido`, `participacao` (fração de 0 a 1,
#'   se publicada).
#' @examples
#' \dontrun{
#' get_detalhamento_publicado("SP", "emprego")
#' }
#' @export
get_detalhamento_publicado <- function(uf, secao, ambiente = NULL) {
  p <- get_secao_publicada(uf, secao, ambiente)
  u <- .sdic_unidade(uf)
  linhas <- list()
  for (b in p$breakdowns) for (i in b$items) {
    linhas[[length(linhas) + 1]] <- list(
      secao = secao, uf = u, detalhamento = b$id, titulo = b$title, dimensao = b$dimension_label,
      unidade = b$unit, periodo = b$period, nome = i$name, valor = .sdic_numero(i$value),
      valor_exibido = i$display_value, participacao = .sdic_numero(i$share))
  }
  .publicados_tabela(linhas, "get_detalhamento_publicado", numericas = c("valor", "participacao"))
}

# Troca `{{kpis[id].campo}}` pelo valor do indicador; marcador sem valor fica como está.
.publicados_preencher <- function(texto, payload) {
  if (!is.character(texto) || length(texto) != 1) return(NA_character_)
  padrao <- "\\{\\{\\s*kpis\\[([^]]+)\\]\\.(\\w+)\\s*\\}\\}"
  achados <- regmatches(texto, gregexpr(padrao, texto, perl = TRUE))[[1]]
  for (marcador in unique(achados)) {
    partes <- regmatches(marcador, regexec(padrao, marcador, perl = TRUE))[[1]]
    kpi <- Filter(function(k) identical(k$id, partes[2]), payload$kpis)
    valor <- if (length(kpi) > 0) kpi[[1]][[partes[3]]] else NULL
    if (is.null(valor) || length(valor) != 1 || is.list(valor)) next
    if (is.numeric(valor)) valor <- format(valor, scientific = FALSE, trim = TRUE, digits = 15)
    texto <- gsub(marcador, as.character(valor), texto, fixed = TRUE)
  }
  texto
}

#' Título, linha de apoio e destaques do texto de uma seção publicada
#'
#' @inheritParams get_secao_publicada
#' @return tibble com as colunas `secao`, `uf`, `tipo` (`"titulo"`, `"apoio"` ou
#'   `"destaque"`), `tom`, `texto` (com os marcadores `{{kpis[...]}}` já trocados pelos
#'   valores).
#' @examples
#' \dontrun{
#' get_destaques_publicados("SP", "emprego")$texto
#' }
#' @export
get_destaques_publicados <- function(uf, secao, ambiente = NULL) {
  p <- get_secao_publicada(uf, secao, ambiente)
  u <- .sdic_unidade(uf)
  historia <- p$story
  linhas <- list()
  campos <- c(titulo = "headline", apoio = "lede")
  for (tipo in names(campos)) {
    texto <- historia[[campos[[tipo]]]]
    if (is.null(texto) || !nzchar(as.character(texto))) next
    linhas[[length(linhas) + 1]] <- list(secao = secao, uf = u, tipo = tipo, tom = NA,
                                         texto = .publicados_preencher(texto, p))
  }
  for (h in Filter(.sdic_e_objeto, historia$highlights)) {
    linhas[[length(linhas) + 1]] <- list(secao = secao, uf = u, tipo = "destaque", tom = h$tone,
                                         texto = .publicados_preencher(h$text, p))
  }
  .publicados_tabela(linhas, "get_destaques_publicados", numericas = character())
}

#' Quando cada carga foi publicada pela última vez nos JSON do ambiente
#'
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @return tibble com as colunas `carga`, `publicado_em` (data e hora UTC da carga publicada),
#'   `ambiente`.
#' @examples
#' \dontrun{
#' get_atualizacao_publicada(ambiente = "homologacao")
#' }
#' @export
get_atualizacao_publicada <- function(ambiente = NULL) {
  amb <- .sdic_ambiente(ambiente)
  marcas <- .sdic_json_publicado("dados", paste0(amb, "/_publicado.json"))
  linhas <- lapply(sort(names(marcas), method = "radix"), function(carga) {
    list(carga = carga, publicado_em = marcas[[carga]], ambiente = amb)
  })
  .publicados_tabela(linhas, "get_atualizacao_publicada", numericas = character())
}
