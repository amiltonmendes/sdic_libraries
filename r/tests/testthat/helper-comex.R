# Helpers de mock de `httr2::req_perform` para os testes de Comex (R6) — sem rede real.
# `helper-*.R` é carregado pelo testthat antes de qualquer `test-*.R`, então fica
# disponível independentemente da ordem alfabética entre arquivos de teste (ao
# contrário de defini-los dentro de um test-comex*.R específico).

mock_response <- function(json_data, status_code = 200) {
  httr2::response(
    status_code = status_code,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw(jsonlite::toJSON(json_data, auto_unbox = TRUE, null = "null"))
  )
}

# Cria uma função substituta para `httr2::req_perform` que devolve as
# respostas em `respostas`, em sequência, e registra os requests recebidos
# em `registro$chamadas`.
mock_req_perform <- function(respostas, registro) {
  idx <- 0
  function(req, ...) {
    idx <<- idx + 1
    registro$chamadas[[idx]] <- req
    respostas[[idx]]
  }
}
