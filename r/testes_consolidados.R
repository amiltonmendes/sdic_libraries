#!/usr/bin/env Rscript

# =====================================================
# TESTES CONSOLIDADOS DA BIBLIOTECA SDIC - R
# =====================================================
#
# Este arquivo consolida todos os testes da biblioteca SDIC em R:
# - Testes da função criar_indice (utils/transformacoes)
# - Avaliação básica da API de emprego
# - Demonstrações práticas de uso
# - Validação do tratamento de erros
#
# Autor: Sistema SDIC
# Data: Abril 2026

# Carregar bibliotecas necessárias
suppressMessages({
  library(cli)
  library(dplyr)
  library(httr2)
})

# Configurar caminhos e carregar funções locais
if (file.exists("R/utils/transformacoes.R")) {
  source("R/utils/transformacoes.R")
} else if (file.exists("r/R/utils/transformacoes.R")) {
  source("r/R/utils/transformacoes.R")
} else {
  stop("Arquivo transformacoes.R não encontrado")
}

if (file.exists("R/emprego.R")) {
  source("R/emprego.R")
} else if (file.exists("r/R/emprego.R")) {
  source("r/R/emprego.R")
} else {
  stop("Arquivo emprego.R não encontrado")
}

# =====================================================
# CLASSE TESTADOR DE ÍNDICES
# =====================================================

TestadorIndices <- R6::R6Class("TestadorIndices",
  public = list(
    resultados = list(),
    total_testes = 0,
    sucessos = 0,
    
    initialize = function() {
      self$resultados <- list()
      self$total_testes <- 0
      self$sucessos <- 0
    },
    
    executar_teste = function(nome_teste, funcao_teste) {
      cli_h3(paste("🔍 Testando:", nome_teste))
      
      resultado <- list(
        teste = nome_teste,
        status = "erro",
        resultado = NULL,
        erro = NULL
      )
      
      tryCatch({
        resultado$resultado <- funcao_teste()
        resultado$status <- "sucesso"
        self$sucessos <- self$sucessos + 1
        cli_alert_success(paste("Sucesso:", nome_teste))
      }, error = function(e) {
        resultado$erro <- e$message
        cli_alert_danger(paste("Erro:", nome_teste, "-", e$message))
      })
      
      self$total_testes <- self$total_testes + 1
      self$resultados[[nome_teste]] <- resultado
      cat("\n")
      
      return(resultado$resultado)
    },
    
    teste_basico_simples = function() {
      # Teste básico com dados simples
      df <- data.frame(
        ano = c(2020, 2021, 2022, 2023),
        vendas = c(100, 120, 110, 130),
        lucro = c(50, 60, 55, 65)
      )
      
      resultado <- criar_indice(df, ano_base = 2020, coluna_data = 'ano', 
                               colunas_valores = c('vendas', 'lucro'))
      
      # Verificações
      stopifnot('vendas_indice' %in% names(resultado))
      stopifnot('lucro_indice' %in% names(resultado))
      stopifnot(abs(resultado$vendas_indice[1] - 100.0) < 0.01)  # Ano base deve ser 100
      stopifnot(abs(resultado$lucro_indice[1] - 100.0) < 0.01)
      stopifnot(abs(resultado$vendas_indice[2] - 120.0) < 0.01)  # 120/100 * 100 = 120
      stopifnot(abs(resultado$lucro_indice[2] - 120.0) < 0.01)   # 60/50 * 100 = 120
      
      return(resultado)
    },
    
    teste_coluna_unica = function() {
      # Teste com apenas uma coluna de valor
      df <- data.frame(
        ano = c(2019, 2020, 2021),
        receita = c(80, 100, 150)
      )
      
      resultado <- criar_indice(df, ano_base = 2020, coluna_data = 'ano', 
                               colunas_valores = 'receita')
      
      # Verificações
      stopifnot('receita_indice' %in% names(resultado))
      stopifnot(abs(resultado$receita_indice[2] - 100.0) < 0.01)  # Ano base
      stopifnot(abs(resultado$receita_indice[3] - 150.0) < 0.01)  # 150/100 * 100 = 150
      stopifnot(abs(resultado$receita_indice[1] - 80.0) < 0.01)   # 80/100 * 100 = 80
      
      return(resultado)
    },
    
    teste_com_datas_datetime = function() {
      # Teste com coluna de datas no formato Date
      df <- data.frame(
        data = as.Date(c('2020-01-01', '2021-06-15', '2022-12-31')),
        valor = c(200, 250, 300)
      )
      
      resultado <- criar_indice(df, ano_base = 2021, coluna_data = 'data', 
                               colunas_valores = 'valor')
      
      # Verificações
      stopifnot('valor_indice' %in% names(resultado))
      stopifnot(abs(resultado$valor_indice[2] - 100.0) < 0.01)  # 2021 é ano base
      
      return(resultado)
    },
    
    teste_multiplas_entradas_ano_base = function() {
      # Teste com múltiplas entradas para o mesmo ano base (deve usar média)
      df <- data.frame(
        ano = c(2020, 2020, 2021, 2021),
        mes = c(1, 6, 1, 6),
        vendas = c(80, 120, 100, 140)  # Média 2020: 100, Média 2021: 120
      )
      
      resultado <- criar_indice(df, ano_base = 2020, coluna_data = 'ano', 
                               colunas_valores = 'vendas')
      
      # Verificações - deve usar média do ano base (100)
      indices_2020 <- resultado$vendas_indice[resultado$ano == 2020]
      indices_2021 <- resultado$vendas_indice[resultado$ano == 2021]
      
      stopifnot(all(abs(indices_2020 - c(80.0, 120.0)) < 0.01))
      stopifnot(all(abs(indices_2021 - c(100.0, 140.0)) < 0.01))
      
      return(resultado)
    },
    
    teste_valor_zero_no_ano_base = function() {
      # Teste com valor zero no ano base (deve retornar NA)
      df <- data.frame(
        ano = c(2020, 2021, 2022),
        valor = c(0, 150, 200)
      )
      
      resultado <- criar_indice(df, ano_base = 2020, coluna_data = 'ano', 
                               colunas_valores = 'valor')
      
      # Verificações - todos os índices devem ser NA
      stopifnot(all(is.na(resultado$valor_indice)))
      
      return(resultado)
    },
    
    teste_valores_negativos = function() {
      # Teste com valores negativos
      df <- data.frame(
        ano = c(2020, 2021, 2022),
        saldo = c(-100, -50, 25)
      )
      
      resultado <- criar_indice(df, ano_base = 2020, coluna_data = 'ano', 
                               colunas_valores = 'saldo')
      
      # Verificações
      stopifnot(abs(resultado$saldo_indice[1] - 100.0) < 0.01)    # Ano base sempre 100
      stopifnot(abs(resultado$saldo_indice[2] - 50.0) < 0.01)     # -50/-100 * 100 = 50
      stopifnot(abs(resultado$saldo_indice[3] - (-25.0)) < 0.01)  # 25/-100 * 100 = -25
      
      return(resultado)
    },
    
    teste_erro_ano_inexistente = function() {
      # Teste de erro quando ano base não existe nos dados
      df <- data.frame(
        ano = c(2020, 2021, 2022),
        valor = c(100, 120, 140)
      )
      
      tryCatch({
        criar_indice(df, ano_base = 2019, coluna_data = 'ano', colunas_valores = 'valor')
        stop("Deveria ter lançado erro para ano inexistente")
      }, error = function(e) {
        if (!grepl("2019 não encontrado", e$message)) {
          stop("Erro não contém mensagem esperada")
        }
        return(paste("Erro capturado corretamente:", e$message))
      })
    },
    
    teste_multiplas_colunas_valores = function() {
      # Teste com múltiplas colunas de valores
      df <- data.frame(
        ano = c(2020, 2021, 2022),
        vendas = c(1000, 1200, 1100),
        custos = c(800, 900, 850),
        lucro = c(200, 300, 250),
        funcionarios = c(50, 55, 52)
      )
      
      resultado <- criar_indice(
        df, 
        ano_base = 2020, 
        coluna_data = 'ano', 
        colunas_valores = c('vendas', 'custos', 'lucro', 'funcionarios')
      )
      
      # Verificações
      colunas_esperadas <- c('vendas_indice', 'custos_indice', 'lucro_indice', 'funcionarios_indice')
      for (coluna in colunas_esperadas) {
        stopifnot(coluna %in% names(resultado))
        stopifnot(abs(resultado[[coluna]][1] - 100.0) < 0.01)  # Ano base sempre 100
      }
      
      # Verificar alguns cálculos específicos
      stopifnot(abs(resultado$vendas_indice[2] - 120.0) < 0.01)   # 1200/1000 * 100
      stopifnot(abs(resultado$lucro_indice[2] - 150.0) < 0.01)    # 300/200 * 100
      
      return(resultado)
    },
    
    executar_testes_criacao_indice = function() {
      cli_h1("🚀 TESTANDO FUNÇÃO CRIAR_INDICE")
      cli_rule()
      cat("\n")
      
      # Lista de todos os testes
      testes <- list(
        list("Teste Básico Simples", self$teste_basico_simples),
        list("Coluna Única de Valor", self$teste_coluna_unica),
        list("Datas em Formato Date", self$teste_com_datas_datetime),
        list("Múltiplas Entradas do Ano Base", self$teste_multiplas_entradas_ano_base),
        list("Valor Zero no Ano Base", self$teste_valor_zero_no_ano_base),
        list("Valores Negativos", self$teste_valores_negativos),
        list("Múltiplas Colunas de Valores", self$teste_multiplas_colunas_valores),
        list("Erro: Ano Inexistente", self$teste_erro_ano_inexistente)
      )
      
      # Executar todos os testes
      for (teste in testes) {
        nome_teste <- teste[[1]]
        funcao_teste <- teste[[2]]
        self$executar_teste(nome_teste, funcao_teste)
      }
      
      return(self$gerar_relatorio_indices())
    },
    
    gerar_relatorio_indices = function() {
      taxa_sucesso <- if (self$total_testes > 0) (self$sucessos / self$total_testes * 100) else 0
      
      cli_h2("📊 RELATÓRIO - FUNÇÃO CRIAR_INDICE")
      cli_rule()
      cat(sprintf("📈 Total de testes: %d\n", self$total_testes))
      cat(sprintf("✅ Sucessos: %d\n", self$sucessos))
      cat(sprintf("❌ Falhas: %d\n", self$total_testes - self$sucessos))
      cat(sprintf("💯 Taxa de sucesso: %.1f%%\n", taxa_sucesso))
      
      if (taxa_sucesso >= 90) {
        status <- "🔥 EXCELENTE - Função totalmente funcional"
      } else if (taxa_sucesso >= 70) {
        status <- "✅ BOA - Função funcional com pequenos problemas"
      } else {
        status <- "❌ CRÍTICA - Função com problemas sérios"
      }
      
      cat(sprintf("🎯 Avaliação: %s\n", status))
      cat("\n")
      
      return(taxa_sucesso)
    }
  )
)

# =====================================================
# CLASSE AVALIADOR API EMPREGO  
# =====================================================

AvaliadorAPIEmprego <- R6::R6Class("AvaliadorAPIEmprego",
  public = list(
    result = list(),
    api_client = NULL,
    start_time = NULL,
    params_padrao = list(),
    
    initialize = function() {
      self$start_time <- Sys.time()
      self$params_padrao <- list(
        data_minima = '2024-01-01',
        ano_minimo = 2023,
        nivel_cnae = 'divisao',
        codigo_cnae = '10',
        sigla_uf = 'SP',
        codigo_municipio = 355030
      )
    },
    
    configurar_api = function() {
      tryCatch({
        self$api_client <- Emprego$new()
        self$result$config <- list(
          base_url = self$api_client$base_url,
          timeout = self$api_client$timeout,
          api_key_configured = !is.null(self$api_client$api_key),
          status_conexao = 'configurado'
        )
        return(TRUE)
      }, error = function(e) {
        self$result$config <- list(
          erro = e$message,
          status_conexao = 'falha_configuracao'
        )
        return(FALSE)
      })
    },
    
    executar_teste_api_rapido = function() {
      cli_h1("🚀 TESTANDO API DE EMPREGO (RÁPIDO)")
      cli_rule()
      
      if (!self$configurar_api()) {
        cli_alert_danger("❌ Falha na configuração da API")
        return(0)
      }
      
      cli_alert_success("✅ API configurada com sucesso!")
      
      # Teste básico de conectividade
      sucessos <- 0
      total <- 0
      
      # Teste 1: Verificar se a API responde
      tryCatch({
        # Tentar uma chamada básica
        test_response <- self$api_client$.make_request('/saldo_caged/nacional/divisao', 
                                                     list(pagina = 1, tamanho_pagina = 1))
        cli_alert_success("🔍 API respondendo normalmente")
        sucessos <- sucessos + 1
      }, error = function(e) {
        cli_alert_danger(paste("❌ Erro na conectividade:", e$message))
      })
      total <- total + 1
      
      # Teste 2: Verificar se métodos da classe existem
      metodos_esperados <- c(
        "get_saldo_emprego_detalhado", 
        "get_estoque_emprego_nacional",
        "get_saldo_caged_nacional_divisao"
      )
      
      for (metodo in metodos_esperados) {
        if (exists(metodo, envir = as.environment(self$api_client))) {
          cli_alert_success(paste("✅ Método encontrado:", metodo))
          sucessos <- sucessos + 1
        } else {
          cli_alert_warning(paste("⚠️ Método não encontrado:", metodo))
        }
        total <- total + 1
      }
      
      taxa_sucesso <- if (total > 0) (sucessos / total * 100) else 0
      
      cat("\n")
      cli_h2("📊 RESULTADO DO TESTE RÁPIDO")
      cat(sprintf("✅ Sucessos: %d/%d\n", sucessos, total))
      cat(sprintf("💯 Taxa de sucesso: %.1f%%\n", taxa_sucesso))
      
      if (taxa_sucesso >= 50) {
        cli_alert_success("🎯 API básica está funcional")
      } else {
        cli_alert_warning("⚠️ API pode estar com problemas")
      }
      
      cat("\n")
      return(taxa_sucesso)
    }
  )
)

# =====================================================
# CLASSE DEMONSTRADOR PRÁTICO
# =====================================================

DemonstradorPratico <- R6::R6Class("DemonstradorPratico",
  public = list(
    demo_indice_com_dados_emprego = function() {
      cli_h1("📊 DEMONSTRAÇÃO PRÁTICA: CRIAR_INDICE")
      cli_rule()
      
      # Criar dados mock simulando dados de emprego
      dados_emprego <- data.frame(
        ano = c(2020, 2021, 2022, 2023),
        admissoes = c(50000, 55000, 58000, 62000),
        desligamentos = c(45000, 48000, 50000, 53000),
        estoque_emprego = c(1000000, 1055000, 1113000, 1172000)
      )
      
      cat("🗂️ Dados originais:\n")
      print(dados_emprego)
      cat("\n")
      
      # Criar índices com base em 2020
      resultado <- criar_indice(
        df = dados_emprego,
        ano_base = 2020,
        coluna_data = 'ano',
        colunas_valores = c('admissoes', 'desligamentos', 'estoque_emprego')
      )
      
      cat("📈 Dados com índices (base 2020 = 100):\n")
      print(resultado[, c('ano', 'admissoes', 'admissoes_indice', 'estoque_emprego', 'estoque_emprego_indice')])
      cat("\n")
      
      # Análise
      estoque_2023 <- resultado$estoque_emprego_indice[resultado$ano == 2023]
      admissoes_2023 <- resultado$admissoes_indice[resultado$ano == 2023]
      
      cat("💡 INTERPRETAÇÃO:\n")
      cat(sprintf("• Estoque de Emprego 2023: %.1f (crescimento de %.1f%%)\n", 
                  estoque_2023, estoque_2023 - 100))
      cat(sprintf("• Admissões 2023: %.1f (crescimento de %.1f%%)\n", 
                  admissoes_2023, admissoes_2023 - 100))
      cat("\n")
    }
  )
)

# =====================================================
# CLASSE TESTADOR CONSOLIDADO
# =====================================================

TestadorConsolidado <- R6::R6Class("TestadorConsolidado",
  public = list(
    testador_indices = NULL,
    avaliador_api = NULL,
    demonstrador = NULL,
    inicio = NULL,
    
    initialize = function() {
      self$testador_indices <- TestadorIndices$new()
      self$avaliador_api <- AvaliadorAPIEmprego$new()
      self$demonstrador <- DemonstradorPratico$new()
      self$inicio <- Sys.time()
    },
    
    executar_todos_os_testes = function(modo = 'rapido') {
      cli_h1("🚀 TESTES CONSOLIDADOS DA BIBLIOTECA SDIC - R")
      cli_rule()
      cat(sprintf("📅 Data: %s\n", format(self$inicio, "%Y-%m-%d %H:%M:%S")))
      cat(sprintf("⚙️ Modo: %s\n", toupper(modo)))
      cat("\n")
      
      resultados <- list()
      
      # 1. Testar função criar_indice
      cat("1️⃣ TESTE DA FUNÇÃO CRIAR_INDICE\n")
      cli_rule()
      taxa_indices <- self$testador_indices$executar_testes_criacao_indice()
      resultados$indices <- taxa_indices
      
      # 2. Teste da API
      cat("2️⃣ TESTE RÁPIDO DA API\n")
      cli_rule()
      taxa_api <- self$avaliador_api$executar_teste_api_rapido()
      resultados$api <- taxa_api
      
      # 3. Demonstrações práticas
      cat("3️⃣ DEMONSTRAÇÕES PRÁTICAS\n")
      cli_rule()
      
      tryCatch({
        self$demonstrador$demo_indice_com_dados_emprego()
        resultados$demos <- 100
        cli_alert_success("✅ Todas as demonstrações executadas com sucesso")
      }, error = function(e) {
        cli_alert_warning(paste("⚠️ Erro nas demonstrações:", e$message))
        resultados$demos <- 0
      })
      
      cat("\n")
      
      # Relatório final
      self$gerar_relatorio_final(resultados)
      return(0)
    },
    
    gerar_relatorio_final = function(resultados) {
      tempo_total <- as.numeric(difftime(Sys.time(), self$inicio, units = "secs"))
      
      cli_h1("📊 RELATÓRIO FINAL CONSOLIDADO")
      cli_rule()
      cat(sprintf("⏱️ Tempo total de execução: %.2fs\n", tempo_total))
      cat("\n")
      
      # Avaliação por componente
      cat("📋 AVALIAÇÃO POR COMPONENTE:\n")
      cat(sprintf("• Função criar_indice: %.1f%%", resultados$indices))
      if (resultados$indices >= 90) cat(" ⭐⭐⭐⭐⭐")
      cat("\n")
      cat(sprintf("• API de Emprego: %.1f%%\n", resultados$api))
      demo_status <- if (resultados$demos >= 90) "✅" else "⚠️"
      cat(sprintf("• Demonstrações: %s\n", demo_status))
      cat("\n")
      
      # Avaliação geral
      media_geral <- if (length(resultados) > 0) mean(unlist(resultados)) else 0
      
      if (media_geral >= 85) {
        status <- "🔥 EXCELENTE - Biblioteca totalmente funcional"
      } else if (media_geral >= 70) {
        status <- "✅ BOA - Biblioteca funcional"
      } else if (media_geral >= 50) {
        status <- "⚠️ MODERADA - Alguns problemas detectados"
      } else {
        status <- "❌ CRÍTICA - Problemas significativos"
      }
      
      cat(sprintf("🎯 AVALIAÇÃO GERAL: %s\n", status))
      cat(sprintf("💯 Score médio: %.1f%%\n", media_geral))
      cat("\n")
      
      # Recomendações
      cat("💡 RECOMENDAÇÕES:\n")
      if (media_geral >= 85) {
        cat("✅ A biblioteca está pronta para uso em produção!\n")
        cat("✅ Todas as funcionalidades principais estão operacionais\n")
      } else if (media_geral >= 70) {
        cat("⚠️ A biblioteca está funcional para a maioria dos casos\n")
        cat("🔄 Monitore a API para melhor disponibilidade\n")
      } else {
        cat("🔧 Verifique a conectividade e configuração da API\n")
        cat("📞 Entre em contato com o suporte se necessário\n")
      }
      
      cat("\n")
      cli_rule()
      cat(sprintf("Relatório gerado por: Testes Consolidados SDIC v1.0\n"))
      cat(sprintf("Data: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
    }
  )
)

# =====================================================
# FUNCÃO PRINCIPAL
# =====================================================

main <- function() {
  # Parse argumentos de linha de comando
  args <- commandArgs(trailingOnly = TRUE)
  modo <- if (length(args) > 0 && args[1] %in% c('completo', 'rapido')) args[1] else 'rapido'
  
  tryCatch({
    testador <- TestadorConsolidado$new()
    return(testador$executar_todos_os_testes(modo = modo))
  }, error = function(e) {
    cat(sprintf("\n💥 ERRO CRÍTICO: %s\n", e$message))
    cat("Stack trace:\n")
    traceback()
    return(1)
  })
}

# Verificar se estamos executando como script principal
if (!interactive()) {
  if (!require(R6, quietly = TRUE)) {
    install.packages("R6")
    library(R6)
  }
  
  quit(save = "no", status = main())
}