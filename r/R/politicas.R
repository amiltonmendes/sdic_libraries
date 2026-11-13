# Políticas da SDIC publicadas pelo `gaia_nib/politicas_sdic` (só leitura).
#
# O `gaia_nib` é o dono do conteúdo, da ordem e do que é permitido mostrar; aqui os JSON
# publicados viram tabelas. Regras que a biblioteca respeita e quem usa também deve respeitar:
#
# - a ordem é a do catálogo publicado; nenhuma função reordena políticas entre si;
# - políticas têm unidades diferentes (R$, atendimentos, projetos): não some nem compare
#   valores de políticas ou de indicadores com unidades diferentes;
# - campo ausente fica NA; nenhum texto é inventado aqui.
#
# Origem `politicas` do catálogo (`SDIC_PAGES_URL`), ambiente de `SDIC_AMBIENTE`.
# Espelho de `python/sdic_libraries/politicas.py`.

.politicas_catalogo <- function(ambiente) {
  amb <- .sdic_ambiente(ambiente)
  catalogo <- tryCatch(
    .sdic_json_publicado("politicas", paste0(amb, "/politicas_catalogo.json")),
    sdic_nao_publicado = function(e) {
      .sdic_abortar(sprintf(paste0("As políticas não estão publicadas em '%s' (%s). ",
                                   "Em homologação elas podem existir: ambiente = 'homologacao'."), amb, e$endpoint),
                    status_code = e$status_code, endpoint = e$endpoint, classe = "sdic_nao_publicado")
    }
  )
  .sdic_versao_suportada(catalogo,
    "O catálogo de políticas está no esquema %s, que esta versão da biblioteca não lê. Atualize-a.")
  catalogo
}

.politicas_pasta <- function(uf) {
  u <- .sdic_unidade(uf)
  if (u == "BRASIL") "nacional" else u
}

.politicas_linhas <- function(payload, uf) {
  itens <- c(list(list(papel = "capa", k = payload$capa_kpi), list(papel = "secundario", k = payload$capa_kpi_secundario)),
             lapply(payload$capa_kpi_modalidades, function(m) list(papel = "modalidade", k = m)))
  itens <- Filter(function(item) .sdic_e_objeto(item$k), itens)
  lapply(itens, function(item) {
    k <- item$k
    list(policy_id = payload$policy_id, nome = payload$nome, sigla = payload$sigla, uf = .sdic_unidade(uf),
         papel = item$papel, id = k$id, rotulo = k$label, valor = .sdic_numero(k$value),
         valor_exibido = k$display_value, unidade = if (is.character(k$unit) && nzchar(k$unit)) k$unit else NULL,
         periodo = k$period, variacao_rotulo = k$delta$label, fonte = payload$source,
         referencia = payload$reference, atualizado_em = payload$updated_at)
  })
}

.politicas_tabela <- function(linhas) .publicados_tabela(linhas, "get_politica")

#' Políticas publicadas, na ordem do catálogo publicado pelo gaia_nib
#'
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @return tibble com uma linha por política e as colunas `id`, `nome`, `sigla`,
#'   `departamento`, `categoria`, `regionalizavel`, `ordem`, `file`, mais os outros campos que
#'   o gaia_nib publicar, e `permitida` (se está em `politicas_permitidas.json`, o recorte dos
#'   subsídios). A ordem das linhas é a publicada; não reordene. Ambiente sem políticas
#'   publicadas gera erro da classe `sdic_nao_publicado`.
#' @examples
#' \dontrun{
#' listar_politicas(ambiente = "homologacao")[, c("id", "sigla", "permitida")]
#' }
#' @export
listar_politicas <- function(ambiente = NULL) {
  amb <- .sdic_ambiente(ambiente)
  entradas <- .politicas_catalogo(amb)$politicas_catalogo
  permitidas <- unlist(.sdic_json_publicado("politicas", paste0(amb, "/politicas_permitidas.json"))$politicas)
  primeiras <- setdiff(.sdic_colunas_de("listar_politicas"), "permitida")
  df <- .sdic_tabela(entradas)
  for (coluna in setdiff(primeiras, names(df))) df[[coluna]] <- rep(NA, nrow(df))
  df$id <- as.character(df$id)
  df <- df[, c(primeiras, setdiff(names(df), c(primeiras, "permitida")))]
  df$permitida <- df$id %in% permitidas
  df
}

#' JSON completo de uma política para uma UF ou para o Brasil
#'
#' Baixo nível: devolve a lista como publicada (inclui `story`, `ressalvas`, `charts`).
#'
#' @param id Id da política (veja `listar_politicas()$id`), ex.: `"b_mais_p"`.
#' @param uf Sigla da UF; `NULL` ou `"BRASIL"` para o recorte nacional.
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @return Lista com o conteúdo do arquivo, ou `NULL` quando a política não publica dado para
#'   essa unidade, o que é esperado (nem toda política é regionalizável).
#' @examples
#' \dontrun{
#' get_politica_publicada("b_mais_p", uf = "SP", ambiente = "homologacao")$ressalvas
#' }
#' @export
get_politica_publicada <- function(id, uf = NULL, ambiente = NULL) {
  amb <- .sdic_ambiente(ambiente)
  tryCatch(.sdic_json_publicado("politicas", sprintf("%s/%s/politicas/%s.json", amb, .politicas_pasta(uf), id)),
           sdic_nao_publicado = function(e) NULL)
}

#' Indicadores de uma política
#'
#' Um indicador por linha: o de capa, o secundário e as modalidades.
#'
#' @inheritParams get_politica_publicada
#' @return tibble com as colunas `policy_id`, `nome`, `sigla`, `uf`, `papel` (`"capa"`,
#'   `"secundario"` ou `"modalidade"`), `id`, `rotulo`, `valor`, `valor_exibido`, `unidade`,
#'   `periodo`, `variacao_rotulo`, `fonte`, `referencia`, `atualizado_em`. Tabela vazia (com as
#'   colunas) se a política não publica dado para essa unidade. As unidades variam entre
#'   linhas: não some a coluna `valor`.
#' @examples
#' \dontrun{
#' get_politica("b_mais_p", uf = "SP", ambiente = "homologacao")[, c("papel", "rotulo", "valor_exibido")]
#' }
#' @export
get_politica <- function(id, uf = NULL, ambiente = NULL) {
  payload <- get_politica_publicada(id, uf, ambiente)
  .politicas_tabela(if (is.null(payload)) list() else .politicas_linhas(payload, uf))
}

#' Indicadores de todas as políticas publicadas para uma UF ou para o Brasil
#'
#' @param uf Sigla da UF; `NULL` ou `"BRASIL"` para o recorte nacional.
#' @param ambiente `"producao"` ou `"homologacao"` (padrão: `SDIC_AMBIENTE`, depois
#'   `"producao"`).
#' @param so_permitidas Se `TRUE`, só as políticas de `politicas_permitidas.json` (recorte dos
#'   subsídios).
#' @return tibble com as colunas de [get_politica()] (`policy_id`, `nome`, `sigla`, `uf`,
#'   `papel`, `id`, `rotulo`, `valor`, `valor_exibido`, `unidade`, `periodo`,
#'   `variacao_rotulo`, `fonte`, `referencia`, `atualizado_em`), política após política na
#'   ordem publicada. Políticas sem dado para a unidade ficam de fora. Não some nem ordene por
#'   `valor`: as unidades são diferentes.
#' @examples
#' \dontrun{
#' get_politicas_estado("SP", ambiente = "homologacao")
#' }
#' @export
get_politicas_estado <- function(uf, ambiente = NULL, so_permitidas = FALSE) {
  catalogo <- listar_politicas(ambiente)
  if (isTRUE(so_permitidas)) catalogo <- catalogo[catalogo$permitida, ]
  linhas <- list()
  for (pid in catalogo$id) {
    payload <- get_politica_publicada(pid, uf, ambiente)
    if (!is.null(payload)) linhas <- c(linhas, .politicas_linhas(payload, uf))
  }
  .politicas_tabela(linhas)
}

#' Resumo publicado das políticas de uma UF ou do Brasil
#'
#' @inheritParams get_politicas_estado
#' @return tibble de uma linha com as colunas `uf`, `nome_uf`, `n_politicas`, `recursos`,
#'   `recursos_exibido`, `atendimentos`, `atendimentos_exibido`, `ranking_posicao`,
#'   `ranking_de`, `ranking_exibido`, `nota_agregacao`. Leia `nota_agregacao` antes de usar os
#'   totais. Tabela vazia (com as colunas) se a unidade não tem resumo publicado.
#' @examples
#' \dontrun{
#' get_resumo_politicas("SP", ambiente = "homologacao")
#' }
#' @export
get_resumo_politicas <- function(uf = NULL, ambiente = NULL) {
  amb <- .sdic_ambiente(ambiente)
  r <- tryCatch(.sdic_json_publicado("politicas", sprintf("%s/%s/resumo_politicas.json", amb, .politicas_pasta(uf))),
                sdic_nao_publicado = function(e) NULL)
  linhas <- if (is.null(r)) list() else list(list(
    uf = .sdic_unidade(uf), nome_uf = r$nome_uf, n_politicas = r$n_politicas,
    recursos = .sdic_numero(r$recursos$value), recursos_exibido = r$recursos$display_value,
    atendimentos = .sdic_numero(r$atendimentos$value), atendimentos_exibido = r$atendimentos$display_value,
    ranking_posicao = r$ranking_nacional$posicao, ranking_de = r$ranking_nacional$de,
    ranking_exibido = r$ranking_nacional$display, nota_agregacao = r$nota_agregacao))
  .publicados_tabela(linhas, "get_resumo_politicas", numericas = c("recursos", "atendimentos"),
                     inteiras = c("n_politicas", "ranking_posicao", "ranking_de"))
}

#' Municípios com políticas publicadas
#'
#' @inheritParams listar_politicas
#' @return tibble com as colunas `ibge` (texto, 7 dígitos), `municipio`, `uf`.
#' @examples
#' \dontrun{
#' m <- get_municipios_elegiveis(ambiente = "homologacao")
#' m[m$uf == "AC", ]
#' }
#' @export
get_municipios_elegiveis <- function(ambiente = NULL) {
  .publicados_tabela(.politicas_catalogo(ambiente)$municipios_elegiveis, "get_municipios_elegiveis",
                     numericas = character())
}

#' Rótulo da fonte, diretorias exibidas e notas publicadas junto com as políticas
#'
#' @inheritParams listar_politicas
#' @return tibble com as colunas `campo` (`"rotulo_fonte"`, `"diretoria"` ou `"nota"`), `id`
#'   (das notas) e `valor`. Vazia (com as colunas) se o catálogo publicado não tiver manifesto.
#' @examples
#' \dontrun{
#' get_manifesto_politicas(ambiente = "homologacao")
#' }
#' @export
get_manifesto_politicas <- function(ambiente = NULL) {
  m <- .politicas_catalogo(ambiente)$manifesto
  linhas <- list()
  if (is.character(m$rotulo_fonte) && nzchar(m$rotulo_fonte)) {
    linhas[[1]] <- list(campo = "rotulo_fonte", id = NULL, valor = m$rotulo_fonte)
  }
  linhas <- c(linhas, lapply(m$diretorias_exibidas, function(d) list(campo = "diretoria", id = NULL, valor = d)))
  linhas <- c(linhas, lapply(Filter(.sdic_e_objeto, m$notas), function(n) list(campo = "nota", id = n$id, valor = n$texto)))
  .publicados_tabela(linhas, "get_manifesto_politicas", numericas = character())
}
