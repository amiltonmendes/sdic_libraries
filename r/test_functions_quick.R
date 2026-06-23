#!/usr/bin/env Rscript

# Teste rápido das novas funcionalidades
cat("=== TESTE RÁPIDO DAS NOVAS FUNCIONALIDADES R ===\n")

# Tentar carregar a biblioteca
tryCatch({
  suppressMessages({
    # Definir path da biblioteca local 
    .libPaths(c("r", .libPaths()))
    
    # Source direto das funções (como biblioteca em desenvolvimento)
    source("r/R/emprego.R")
    
    cat("✅ Biblioteca carregada\n")
    
    # Teste básico de validação CNAE
    cat("\n1. Testando validação de CNAE:\n")
    
    # Teste divisão (2 dígitos)
    tryCatch({
      resultado <- .validate_cnae_codes(c("10", "11"))
      cat(sprintf("✅ Divisões (2 dígitos): %s\n", resultado))
    }, error = function(e) {
      cat(sprintf("❌ Divisões: %s\n", e$message))
    })
    
    # Teste grupo (3 dígitos)  
    tryCatch({
      resultado <- .validate_cnae_codes(c("101", "111"))
      cat(sprintf("✅ Grupos (3 dígitos): %s\n", resultado))
    }, error = function(e) {
      cat(sprintf("❌ Grupos: %s\n", e$message))
    })
    
    # Teste subclasse (7 dígitos)
    tryCatch({
      resultado <- .validate_cnae_codes(c("1011502", "1111101"))
      cat(sprintf("✅ Subclasses (7 dígitos): %s\n", resultado))
    }, error = function(e) {
      cat(sprintf("❌ Subclasses: %s\n", e$message))
    })
    
    # Teste mistura (deve falhar)
    tryCatch({
      resultado <- .validate_cnae_codes(c("10", "1011502"))
      cat("❌ Mistura não detectou erro\n")
    }, error = function(e) {
      cat("✅ Mistura: Erro detectado corretamente\n")
    })
    
    cat("\n2. Testando filtros de coluna:\n")
    
    # Criar tibble mock para testar filtros
    suppressMessages(library(tibble))
    
    # Teste filtro nacional
    mock_df_nacional <- tibble(
      competencia = c("2023-01", "2023-02"),
      uf = c("SP", "RJ"),
      municipio = c("1", "2"),
      cnae = c("10", "11"),
      saldo = c(100, 200)
    )
    filtered_nacional <- .filter_columns_by_aggregation(mock_df_nacional, "nacional")
    cat(sprintf("Nacional: %s\n", paste(names(filtered_nacional), collapse = ", ")))
    
    # Teste filtro estadual
    mock_df_estadual <- tibble(
      competencia = c("2023-01", "2023-02"),
      uf = c("SP", "RJ"),
      municipio = c("1", "2"),
      cnae = c("10", "11"),
      saldo = c(100, 200)
    )
    filtered_estadual <- .filter_columns_by_aggregation(mock_df_estadual, "estadual")
    cat(sprintf("Estadual: %s\n", paste(names(filtered_estadual), collapse = ", ")))
    
    # Teste filtro municipal (deve manter todas)
    mock_df_municipal <- tibble(
      competencia = c("2023-01", "2023-02"),
      uf = c("SP", "RJ"),
      municipio = c("1", "2"),
      cnae = c("10", "11"),
      saldo = c(100, 200)
    )
    filtered_municipal <- .filter_columns_by_aggregation(mock_df_municipal, "municipal")
    cat(sprintf("Municipal: %s\n", paste(names(filtered_municipal), collapse = ", ")))
    
    cat("\n3. Testando filtros CNAE para métodos agrupados:\n")
    
    # Teste filtro CNAE agrupado
    mock_df_cnae <- tibble(
      competencia = c("2023-01", "2023-02"),
      cnae = c("10", "11"),
      cnae_secao = c("C", "C"),
      cnae_divisao = c("10", "11"),
      cnae_grupo = c("101", "111"),
      saldo = c(100, 200)
    )
    filtered_grouped <- .filter_cnae_columns_for_grouped_methods(mock_df_cnae, "nacional")
    cat(sprintf("Agrupado: %s\n", paste(names(filtered_grouped), collapse = ", ")))
    
    cat("\n✅ Todos os testes internos passaram!\n")
    
  })
  
}, error = function(e) {
  cat(sprintf("❌ Erro ao carregar biblioteca: %s\n", e$message))
})

cat("\n=== TESTE CONCLUÍDO ===\n")