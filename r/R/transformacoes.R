#' Funções de transformação e manipulação de dados
#'
#' Este módulo contém funções para transformar dados, calcular índices,
#' e realizar outras operações estatísticas.

#' Criar índices para colunas de valores baseado em um ano de referência
#' 
#' Esta função calcula índices relativos ao ano base para as colunas especificadas,
#' adicionando novas colunas com sufixo '_indice' ao dataframe original.
#' 
#' @param df Data frame com os dados a serem transformados
#' @param ano_base Ano de referência para o cálculo do índice (base = 100)
#' @param coluna_data Nome da coluna que contém as datas/anos
#' @param colunas_valores Nome da coluna ou vetor de colunas para calcular índice
#' 
#' @return Data frame com as colunas originais mais as novas colunas de índice
#' 
#' @examples
#' df <- data.frame(
#'   ano = c(2020, 2021, 2022),
#'   vendas = c(100, 120, 110),
#'   lucro = c(50, 60, 55)
#' )
#' df_com_indice <- criar_indice(df, 2020, 'ano', c('vendas', 'lucro'))
#' print(df_com_indice)
#' #    ano vendas lucro vendas_indice lucro_indice
#' # 1 2020    100    50         100.0        100.0
#' # 2 2021    120    60         120.0        120.0
#' # 3 2022    110    55         110.0        110.0
#' 
#' @export
criar_indice <- function(df, ano_base, coluna_data, colunas_valores) {
  # Validações de entrada
  if (nrow(df) == 0) {
    stop("Data frame não pode estar vazio")
  }
  
  if (!coluna_data %in% names(df)) {
    stop(paste("Coluna de data '", coluna_data, "' não encontrada no data frame", sep = ""))
  }
  
  # Converte colunas_valores para vetor se for string única
  if (is.character(colunas_valores) && length(colunas_valores) == 1) {
    colunas_valores <- c(colunas_valores)
  }
  
  # Verifica se todas as colunas de valores existem
  colunas_inexistentes <- setdiff(colunas_valores, names(df))
  if (length(colunas_inexistentes) > 0) {
    stop(paste("Colunas não encontradas no data frame:", paste(colunas_inexistentes, collapse = ", ")))
  }
  
  # Cria uma cópia do data frame para não modificar o original
  df_resultado <- df
  
  # Tenta extrair o ano da coluna de data
  tryCatch({
    if (is.character(df_resultado[[coluna_data]])) {
      # Se for string, tenta converter para Date primeiro
      df_resultado[["_ano_temp"]] <- as.numeric(format(as.Date(df_resultado[[coluna_data]]), "%Y"))
    } else if (inherits(df_resultado[[coluna_data]], c("Date", "POSIXct", "POSIXt"))) {
      # Se já for Date/POSIXct, extrai o ano
      df_resultado[["_ano_temp"]] <- as.numeric(format(df_resultado[[coluna_data]], "%Y"))
    } else if (is.numeric(df_resultado[[coluna_data]])) {
      # Se for numérico, assume que já são anos
      df_resultado[["_ano_temp"]] <- as.integer(df_resultado[[coluna_data]])
    } else {
      stop(paste("Tipo de dados da coluna '", coluna_data, "' não suportado para extração do ano", sep = ""))
    }
  }, error = function(e) {
    stop(paste("Erro ao extrair ano da coluna '", coluna_data, "':", e$message, sep = " "))
  })
  
  # Verifica se o ano base existe nos dados
  anos_disponiveis <- unique(df_resultado[["_ano_temp"]])
  anos_disponiveis <- anos_disponiveis[!is.na(anos_disponiveis)]
  
  if (!ano_base %in% anos_disponiveis) {
    stop(paste(
      "Ano base", ano_base, "não encontrado nos dados.",
      "Anos disponíveis:", paste(sort(anos_disponiveis), collapse = ", ")
    ))
  }
  
  # Calcula os índices para cada coluna especificada
  for (coluna in colunas_valores) {
    # Encontra os valores do ano base
    mask_ano_base <- df_resultado[["_ano_temp"]] == ano_base & !is.na(df_resultado[["_ano_temp"]])
    
    if (sum(mask_ano_base) == 0) {
      stop(paste("Nenhum dado encontrado para o ano base", ano_base))
    } else if (sum(mask_ano_base) == 1) {
      valor_base <- df_resultado[mask_ano_base, coluna]
    } else {
      # Múltiplas entradas para o ano base - usa média
      valor_base <- mean(df_resultado[mask_ano_base, coluna], na.rm = TRUE)
    }
    
    # Evita divisão por zero
    if (is.na(valor_base) || valor_base == 0) {
      # Se valor base é zero ou NA, índice será NA para todos os anos
      df_resultado[[paste(coluna, "indice", sep = "_")]] <- NA
    } else {
      # Calcula o índice: (valor_atual / valor_base) * 100
      df_resultado[[paste(coluna, "indice", sep = "_")]] <- (df_resultado[[coluna]] / valor_base) * 100
    }
  }
  
  # Remove coluna temporária
  df_resultado[["_ano_temp"]] <- NULL
  
  return(df_resultado)
}