#' sdic.libraries: leitura dos dados da plataforma da SDIC, em tabelas
#'
#' Uma porta única, com o mesmo nome de função em R e em Python (`sdic_libraries`):
#'
#' - emprego (RAIS, Novo CAGED) e comércio exterior (ComexStat), pela sdic_api;
#' - séries das bases do `carga_base` e indicadores oficiais ([listar_series()],
#'   [get_serie()]) e tabelas de de-para ([listar_referencias()], [get_referencia()]);
#' - seções publicadas em JSON, as mesmas do portal ([get_kpis_publicados()] e afins);
#' - políticas da SDIC publicadas pelo `gaia_nib` ([listar_politicas()], [get_politica()]).
#'
#' @section Por onde começar:
#' - [listar_bases()]: o que existe (uma linha por função, com exemplo);
#' - [descrever()]: de onde vem um dado e que colunas ele tem;
#' - [sdic_config()]: de onde a biblioteca está lendo (endereços, ambiente, se há chave).
#'
#' @section Como configurar a chave:
#' A sdic_api exige uma chave individual. Coloque-a em `SDIC_API_KEY`, numa variável de
#' ambiente (por exemplo no `~/.Renviron`) ou num arquivo `.env.local` na pasta do projeto
#' (não versione esse arquivo):
#'
#' ```
#' SDIC_API_KEY=sua-chave
#' ```
#'
#' Cada configuração é resolvida nesta ordem: argumento da função, variável de ambiente,
#' `./.env.local`, `./.env`, `~/.env`, `/etc/sdic/.env`, padrão. Os arquivos são só lidos. As
#' seções publicadas e as políticas não usam chave; o ambiente (`"producao"` ou
#' `"homologacao"`) vem de `SDIC_AMBIENTE` ou do argumento `ambiente`.
#'
#' @section Erros:
#' Falhas de leitura têm a classe `sdic_erro` (campos `status_code` e `endpoint`); arquivo
#' ainda não publicado, `sdic_nao_publicado`; argumento ou configuração inválidos,
#' `sdic_valor_invalido`. Use `tryCatch(..., sdic_nao_publicado = function(e) ...)`.
#'
#' @examples
#' \dontrun{
#' listar_bases()
#' descrever("get_kpis_publicados")
#' sdic_config()
#' get_kpis_publicados("SP", "emprego")
#' }
#' @importFrom dplyr %>%
#' @importFrom cli cli_inform
#' @keywords internal
"_PACKAGE"
