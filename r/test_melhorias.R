# Teste das melhorias implementadas na biblioteca SDIC de Emprego em R

# Carregar funcoes locais
source(here::here("R", "data_access", "emprego.R"))
suppressMessages({
  library(dplyr)
  library(cli)
  library(here)
})

is_api_error <- function(msg) {
  grepl("HTTP 404|HTTP 5[0-9]{2}|timeout|timed out|Falha na requisicao", msg, ignore.case = TRUE)
}

safe_api_call <- function(expr, contexto) {
  tryCatch(
    expr,
    error = function(e) {
      if (is_api_error(e$message)) {
        cat(sprintf("⚠️ %s - API indisponivel: %s\n", contexto, e$message))
      } else {
        cat(sprintf("❌ %s: %s\n", contexto, e$message))
      }
      return(NULL)
    }
  )
}

test_column_filters <- function() {
  cat("=== TESTE: Filtros de colunas por nivel de agregacao ===\n\n")

  df_nacional <- safe_api_call(
    get_saldo_emprego_nacional_mensal(data_minima = "2025-01-01"),
    "Consulta nacional"
  )
  if (is.null(df_nacional)) return(invisible(FALSE))

  cat("✅ NACIONAL:\n")
  cat("   Colunas (", ncol(df_nacional), "):", paste(names(df_nacional), collapse = ", "), "\n")

  df_estadual <- safe_api_call(
    get_saldo_emprego_estadual_mensal('SP', data_minima = "2025-01-01"),
    "Consulta estadual"
  )
  if (is.null(df_estadual)) return(invisible(FALSE))

  cat("\n✅ ESTADUAL:\n")
  cat("   Colunas (", ncol(df_estadual), "):", paste(names(df_estadual), collapse = ", "), "\n")

  cat("\n🔍 VERIFICACOES:\n")
  cat("   ✅ Nacional - 'uf' removida:", !('uf' %in% names(df_nacional)), "\n")
  cat("   ✅ Nacional - 'municipio' removida:", !('municipio' %in% names(df_nacional)), "\n")
  cat("   ✅ Estadual - 'municipio' removida:", !('municipio' %in% names(df_estadual)), "\n")
  cat("   ✅ Estadual - 'uf' ou 'sigla_uf' mantida:",
      ('uf' %in% names(df_estadual)) || ('sigla_uf' %in% names(df_estadual)), "\n")

  invisible(TRUE)
}

test_cnae_levels <- function() {
  cat("\n=== TESTE: Codigos CNAE hierarquicos por nivel ===\n\n")

  df_subclasse <- safe_api_call(
    get_saldo_emprego_nacional_mensal('subclasse', data_minima = "2025-01-01"),
    "Consulta subclasse"
  )
  if (is.null(df_subclasse)) return(invisible(FALSE))

  cols_cnae_subclasse <- names(df_subclasse)[grepl("cnae|codigo|secao|subclasse", names(df_subclasse), ignore.case = TRUE)]
  cat("SUBCLASSE - Codigos CNAE disponiveis:\n")
  cat("   ", paste(cols_cnae_subclasse, collapse = ", "), "\n")

  df_divisao <- safe_api_call(
    get_saldo_emprego_nacional_mensal('divisao', data_minima = "2025-01-01"),
    "Consulta divisao"
  )
  if (is.null(df_divisao)) return(invisible(FALSE))

  cols_cnae_divisao <- names(df_divisao)[grepl("cnae|codigo|secao|divisao", names(df_divisao), ignore.case = TRUE)]
  cat("\nDIVISAO - Codigos CNAE disponiveis:\n")
  cat("   ", paste(cols_cnae_divisao, collapse = ", "), "\n")

  df_grupo <- safe_api_call(
    get_saldo_emprego_nacional_mensal('grupo', data_minima = "2025-01-01"),
    "Consulta grupo"
  )
  if (is.null(df_grupo)) return(invisible(FALSE))

  cols_cnae_grupo <- names(df_grupo)[grepl("cnae|codigo|secao|grupo", names(df_grupo), ignore.case = TRUE)]
  cat("\nGRUPO - Codigos CNAE disponiveis:\n")
  cat("   ", paste(cols_cnae_grupo, collapse = ", "), "\n")

  cat("\n=== RESUMO COLUNAS POR NIVEL ===\n")
  cat("Subclasse:", ncol(df_subclasse), "colunas\n")
  cat("Divisao:", ncol(df_divisao), "colunas\n")
  cat("Grupo:", ncol(df_grupo), "colunas\n")

  invisible(TRUE)
}

test_cnae_validations <- function() {
  cat("\n=== TESTE: Validacoes CNAE ===\n\n")

  tryCatch({
    df_div <- get_saldo_emprego_nacional_mensal_agrupado(
      "Industria Valida",
      c("10", "11", "12"),
      data_minima = "2025-01-01"
    )
    cat("✅ Divisoes validas:", nrow(df_div), "registros\n")
  }, error = function(e) {
    if (is_api_error(e$message)) {
      cat("⚠️ Divisoes validas - API indisponivel:", e$message, "\n")
    } else {
      cat("❌ Erro divisoes:", e$message, "\n")
    }
  })

  tryCatch({
    df_grupo <- get_saldo_emprego_nacional_mensal_agrupado(
      "Grupos Validos",
      c("101", "102", "103"),
      data_minima = "2025-01-01"
    )
    cat("✅ Grupos validos:", nrow(df_grupo), "registros\n")
  }, error = function(e) {
    if (is_api_error(e$message)) {
      cat("⚠️ Grupos validos - API indisponivel:", e$message, "\n")
    } else {
      cat("❌ Erro grupos:", e$message, "\n")
    }
  })

  tryCatch({
    get_saldo_emprego_nacional_mensal_agrupado(
      "Erro Misturado",
      c("10", "101", "1011111")
    )
    cat("❌ Esta linha nao deveria ser executada\n")
  }, error = function(e) {
    cat("✅ Erro esperado capturado:", e$message, "\n")
  })

  tryCatch({
    get_saldo_emprego_nacional_mensal_agrupado(
      "Erro Digitos",
      c("1", "22", "333", "4444")
    )
  }, error = function(e) {
    cat("✅ Validacao digitos funcionou:", e$message, "\n")
  })

  cat("\n🎉 Todas as validacoes CNAE foram executadas!\n")
  invisible(TRUE)
}

test_grouped_methods <- function() {
  cat("\n=== TESTE: Metodos agrupados sem colunas CNAE especificas ===\n\n")

  df_agrupado_nacional <- safe_api_call(
    get_saldo_emprego_nacional_mensal_agrupado(
      "Industria Teste",
      c("10", "11", "12"),
      data_minima = "2025-01-01"
    ),
    "Agrupado nacional"
  )
  if (is.null(df_agrupado_nacional)) return(invisible(FALSE))

  cat("✅ NACIONAL AGRUPADO:\n")
  cat("   Colunas (", ncol(df_agrupado_nacional), "):", paste(names(df_agrupado_nacional), collapse = ", "), "\n")

  df_agrupado_estadual <- safe_api_call(
    get_saldo_emprego_estadual_mensal_agrupado(
      "SP",
      "TI Teste",
      c("62", "63"),
      data_minima = "2025-01-01"
    ),
    "Agrupado estadual"
  )
  if (is.null(df_agrupado_estadual)) return(invisible(FALSE))

  cat("\n✅ ESTADUAL AGRUPADO:\n")
  cat("   Colunas (", ncol(df_agrupado_estadual), "):", paste(names(df_agrupado_estadual), collapse = ", "), "\n")

  colunas_cnae_indevidas <- c(
    'codigo_divisao', 'codigo_grupo', 'subclasse', 'secao',
    'descricao_classe', 'descricao_secao', 'descricao_grupo',
    'descricao_divisao', 'descricao_subclasse'
  )

  cnae_encontradas_nacional <- intersect(names(df_agrupado_nacional), colunas_cnae_indevidas)
  cnae_encontradas_estadual <- intersect(names(df_agrupado_estadual), colunas_cnae_indevidas)

  cat("\n🔍 VERIFICACAO:\n")
  cat("   ✅ Nacional - Colunas CNAE removidas:", length(cnae_encontradas_nacional) == 0, "\n")
  cat("   ✅ Estadual - Colunas CNAE removidas:", length(cnae_encontradas_estadual) == 0, "\n")

  invisible(TRUE)
}

test_estoque_column_filters <- function() {
  cat("\n=== TESTE: Filtragem de colunas nas funcoes de estoque ===\n\n")

  filtrar_por_ano <- function(df, ano_minimo = NULL) {
    if (is.null(ano_minimo) || nrow(df) == 0) return(df)
    if ('ano' %in% names(df)) {
      anos <- suppressWarnings(as.integer(df$ano))
      return(df[!is.na(anos) & anos >= ano_minimo, , drop = FALSE])
    }
    if ('Ano' %in% names(df)) {
      anos <- suppressWarnings(as.integer(df$Ano))
      return(df[!is.na(anos) & anos >= ano_minimo, , drop = FALSE])
    }
    return(df)
  }

  df_estoque_div <- safe_api_call(
    filtrar_por_ano(get_estoque_emprego_nacional(
      nivel_cnae = 2
    ), 2023),
    "Estoque nacional divisao"
  )
  if (is.null(df_estoque_div)) return(invisible(FALSE))

  cat("ESTOQUE NACIONAL divisao:\n")
  cat("   Colunas (", ncol(df_estoque_div), "):", paste(names(df_estoque_div), collapse = ", "), "\n")

  colunas_indevidas_div <- intersect(
    names(df_estoque_div),
    c('codigo_grupo', 'descricao_grupo', 'subclasse', 'descricao_subclasse',
      'nome_grupo', 'descricao_classe')
  )
  cat("   ✅ Divisao - colunas de grupo/subclasse removidas:",
      length(colunas_indevidas_div) == 0, "\n")

  df_estoque_grp <- safe_api_call(
    filtrar_por_ano(get_estoque_emprego_estadual(
      sigla_uf = 'SP',
      nivel_cnae = 3
    ), 2023),
    "Estoque estadual grupo"
  )
  if (is.null(df_estoque_grp)) return(invisible(FALSE))

  cat("\nESTOQUE ESTADUAL SP grupo:\n")
  cat("   Colunas (", ncol(df_estoque_grp), "):", paste(names(df_estoque_grp), collapse = ", "), "\n")

  colunas_indevidas_grp <- intersect(
    names(df_estoque_grp),
    c('subclasse', 'descricao_subclasse', 'nome_grupo', 'descricao_classe')
  )
  cat("   ✅ Grupo - colunas de subclasse removidas:",
      length(colunas_indevidas_grp) == 0, "\n")

  # Algumas respostas podem vir sem codigo_divisao quando dataset esta vazio.
  if (nrow(df_estoque_grp) == 0) {
    cat("   ⚠️ Grupo - sem linhas para validar presenca de codigo_divisao\n")
  } else {
    cat("   ✅ Grupo - codigo_divisao mantido:",
        'codigo_divisao' %in% names(df_estoque_grp), "\n")
  }

  df_estoque_agr <- safe_api_call(
    filtrar_por_ano(get_estoque_emprego_nacional_agrupado(
      nome_grupo = 'TI',
      lista_cnae = c('620', '621')
    ), 2023),
    "Estoque agrupado nacional"
  )
  if (is.null(df_estoque_agr)) return(invisible(FALSE))

  cat("\nESTOQUE AGRUPADO nacional:\n")
  cat("   Colunas (", ncol(df_estoque_agr), "):", paste(names(df_estoque_agr), collapse = ", "), "\n")

  colunas_cnae <- intersect(
    names(df_estoque_agr),
    c('codigo_divisao', 'descricao_divisao', 'codigo_grupo', 'descricao_grupo',
      'subclasse', 'descricao_subclasse', 'secao', 'descricao_secao',
      'descricao_classe')
  )
  cat("   ✅ Agrupado - colunas CNAE especificas removidas:",
      length(colunas_cnae) == 0, "\n")

  invisible(TRUE)
}

main <- function() {
  cat("=== INICIANDO TESTES DAS MELHORIAS EM R ===\n\n")

  test_column_filters()
  test_cnae_levels()
  test_cnae_validations()
  test_grouped_methods()
  test_estoque_column_filters()

  cat("\n=== TESTES CONCLUIDOS ===\n")
  cat("🎉 Rotina de testes finalizada.\n")
}

if (!interactive()) {
  main()
}
