#!/usr/bin/env Rscript

# Teste das funções de estoque de emprego 
cat("=== TESTE DAS FUNÇÕES DE ESTOQUE DE EMPREGO ===\n")

is_api_error <- function(msg) {
  grepl("HTTP 5[0-9]{2}|timeout|timed out|Falha na requisição", msg, ignore.case = TRUE)
}

run_with_time_limit <- function(expr, seconds = 60) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
  force(expr)
}

run_grouped_online_tests <- identical(tolower(Sys.getenv("SDIC_RUN_ONLINE_GROUPED", "false")), "true")

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

# Tentar carregar a biblioteca
tryCatch({
  suppressMessages({
    # Definir path da biblioteca local 
    .libPaths(c("r", .libPaths()))
    
    # Source direto das funções (como biblioteca em desenvolvimento)
    source("r/R/data_access/emprego.R")
    
    cat("✅ Biblioteca carregada\n")
    
    # Teste 1: Função de estoque nacional básica
    cat("\n1. Testando estoque nacional anual:\n")
    tryCatch({
      # Teste básico com poucos dados
      resultado <- run_with_time_limit(
        filtrar_por_ano(
          get_estoque_emprego_nacional(
            nivel_cnae = 3
          ),
          2022
        )
      )
      cat(sprintf("✅ Estoque nacional: %d registros carregados\n", nrow(resultado)))
      
      # Mostrar estrutura se houver dados
      if (nrow(resultado) > 0) {
        cat("   Colunas:", paste(names(resultado), collapse = ", "), "\n")
        cat("   Primeira linha:\n")
        print(head(resultado, 1))
      }
    }, error = function(e) {
      cat(sprintf("❌ Estoque nacional: %s\n", e$message))
    })
    
    # Teste 2: Função de estoque estadual 
    cat("\n2. Testando estoque estadual anual:\n")
    tryCatch({
      # Teste para São Paulo
      resultado <- run_with_time_limit(
        filtrar_por_ano(get_estoque_emprego_estadual(
          sigla_uf = 'SP',
          nivel_cnae = 3
        ), 2022)
      )
      cat(sprintf("✅ Estoque estadual SP: %d registros carregados\n", nrow(resultado)))
      
      # Mostrar estrutura se houver dados
      if (nrow(resultado) > 0) {
        cat("   Colunas:", paste(names(resultado), collapse = ", "), "\n")
      }
    }, error = function(e) {
      cat(sprintf("❌ Estoque estadual SP: %s\n", e$message))
    })
    
    # Teste 3: Função de estoque agrupado nacional
    cat("\n3. Testando estoque nacional agrupado:\n")
    if (!run_grouped_online_tests) {
      cat("⚠️ Teste agrupado nacional ignorado (defina SDIC_RUN_ONLINE_GROUPED=true para habilitar)\n")
    } else {
      tryCatch({
        # Teste com setores de TI
        resultado <- run_with_time_limit(
          filtrar_por_ano(get_estoque_emprego_nacional_agrupado(
            nome_grupo = 'TI',
            lista_cnae = c('620', '621')
          ), 2022)
        )
        cat(sprintf("✅ Estoque agrupado nacional: %d registros carregados\n", nrow(resultado)))

        # Verificar se contém nome_grupo
        if (nrow(resultado) > 0 && 'nome_grupo' %in% names(resultado)) {
          grupos_unicos <- unique(resultado$nome_grupo)
          cat("   Grupos encontrados:", paste(grupos_unicos, collapse = ", "), "\n")
        }
      }, error = function(e) {
        if (is_api_error(e$message)) {
          cat(sprintf("⚠️ Estoque agrupado nacional (API indisponível): %s\n", e$message))
        } else {
          cat(sprintf("❌ Estoque agrupado nacional: %s\n", e$message))
        }
      })
    }

    # Teste 4: Função de estoque agrupado estadual
    cat("\n4. Testando estoque estadual agrupado:\n")
    if (!run_grouped_online_tests) {
      cat("⚠️ Teste agrupado estadual ignorado (defina SDIC_RUN_ONLINE_GROUPED=true para habilitar)\n")
    } else {
      tryCatch({
        # Teste com setores financeiros
        resultado <- run_with_time_limit(
          filtrar_por_ano(get_estoque_emprego_estadual_agrupado(
            sigla_uf = 'RJ',
            nome_grupo = 'Financeiro',
            lista_cnae = c('640', '641')
          ), 2022)
        )
        cat(sprintf("✅ Estoque agrupado estadual: %d registros carregados\n", nrow(resultado)))
      }, error = function(e) {
        if (is_api_error(e$message)) {
          cat(sprintf("⚠️ Estoque agrupado estadual (API indisponível): %s\n", e$message))
        } else {
          cat(sprintf("❌ Estoque agrupado estadual: %s\n", e$message))
        }
      })
    }
    
    # Teste 5: Validação de parâmetros
    cat("\n5. Testando validação de parâmetros:\n")
    
    # Teste parâmetro nivel_cnae inválido
    tryCatch({
      resultado <- get_estoque_emprego_nacional(nivel_cnae = 99)
      cat("❌ Validação nivel_cnae: Não detectou erro\n")
    }, error = function(e) {
      cat("✅ Validação nivel_cnae: Erro detectado corretamente\n")
    })
    
    # Teste lista CNAE vazia
    tryCatch({
      resultado <- get_estoque_emprego_nacional_agrupado(
        nome_grupo = 'Teste',
        lista_cnae = c()
      )
      cat("❌ Validação lista vazia: Não detectou erro\n")
    }, error = function(e) {
      cat("✅ Validação lista vazia: Erro detectado corretamente\n")
    })
    
    cat("\n=== TESTE COMPLETADO ===\n")
    
  })
}, error = function(e) {
  cat(sprintf("❌ Erro ao carregar biblioteca: %s\n", e$message))
})
# Teste 6 adicionado: Verificar filtragem de colunas CNAE por nivel
test_cnae_column_filtering <- function() {
  cat("\n=== TESTE 6: Filtragem de colunas CNAE por nivel ===\n")

  source("r/R/data_access/emprego.R")

  # Nivel divisao: nao deve conter colunas de grupo/subclasse
  tryCatch({
    resultado_div <- run_with_time_limit(
      filtrar_por_ano(get_estoque_emprego_nacional(
        nivel_cnae = 2
      ), 2022)
    )
    colunas_indevidas <- intersect(
      names(resultado_div),
      c('codigo_grupo', 'descricao_grupo', 'subclasse', 'descricao_subclasse',
        'nome_grupo', 'descricao_classe')
    )
    if (length(colunas_indevidas) == 0) {
      cat("OK Divisao - colunas de grupo/subclasse corretamente removidas\n")
    } else {
      cat(sprintf("FALHOU Divisao - colunas indevidas presentes: %s\n",
                  paste(colunas_indevidas, collapse = ", ")))
    }
  }, error = function(e) {
    cat(sprintf("ERRO Filtragem divisao: %s\n", e$message))
  })

  # Nivel grupo: nao deve conter colunas de subclasse
  tryCatch({
    resultado_grp <- run_with_time_limit(
      filtrar_por_ano(get_estoque_emprego_estadual(
        sigla_uf = 'SP',
        nivel_cnae = 3
      ), 2022)
    )
    colunas_indevidas <- intersect(
      names(resultado_grp),
      c('subclasse', 'descricao_subclasse', 'nome_grupo', 'descricao_classe')
    )
    if (length(colunas_indevidas) == 0) {
      cat("OK Grupo - colunas de subclasse corretamente removidas\n")
    } else {
      cat(sprintf("FALHOU Grupo - colunas indevidas presentes: %s\n",
                  paste(colunas_indevidas, collapse = ", ")))
    }
    if (nrow(resultado_grp) == 0) {
      cat("AVISO Grupo - sem linhas para validar presenca de codigo_divisao\n")
    } else if ('codigo_divisao' %in% names(resultado_grp)) {
      cat("OK Grupo - colunas de divisao corretamente mantidas\n")
    } else {
      cat("FALHOU Grupo - colunas de divisao ausentes\n")
    }
  }, error = function(e) {
    cat(sprintf("ERRO Filtragem grupo: %s\n", e$message))
  })

  # Funcoes agrupadas: nao devem conter nenhuma coluna CNAE especifica
  if (!run_grouped_online_tests) {
    cat("AVISO Filtragem agrupado ignorada (defina SDIC_RUN_ONLINE_GROUPED=true para habilitar)\n")
  } else {
    tryCatch({
      resultado_agr <- run_with_time_limit(
        filtrar_por_ano(get_estoque_emprego_nacional_agrupado(
          nome_grupo = 'TI',
          lista_cnae = c('620', '621')
        ), 2022)
      )
      colunas_cnae_especificas <- intersect(
        names(resultado_agr),
        c('codigo_divisao', 'descricao_divisao', 'codigo_grupo', 'descricao_grupo',
          'subclasse', 'descricao_subclasse', 'secao', 'descricao_secao',
          'descricao_classe')
      )
      if (length(colunas_cnae_especificas) == 0) {
        cat("OK Agrupado - colunas CNAE especificas corretamente removidas\n")
      } else {
        cat(sprintf("FALHOU Agrupado - colunas CNAE especificas presentes: %s\n",
                    paste(colunas_cnae_especificas, collapse = ", ")))
      }
    }, error = function(e) {
      if (is_api_error(e$message)) {
        cat(sprintf("AVISO Filtragem agrupado (API indisponivel): %s\n", e$message))
      } else {
        cat(sprintf("ERRO Filtragem agrupado: %s\n", e$message))
      }
    })
  }

  cat("=== TESTE 6 CONCLUIDO ===\n")
}

# Executar teste 6 se chamado diretamente
if (!interactive()) {
  test_cnae_column_filtering()
}
