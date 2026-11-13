# Configuração

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

## Variáveis

| Variável | Para quê | Padrão |
|---|---|---|
| `SDIC_API_KEY` | Chave individual da API | sem chave |
| `SDIC_AMBIENTE` | `producao` ou `homologacao` (seções publicadas e políticas) | `producao` |
| `SDIC_API_URL` | Endereço da sdic_api | https://sdicapi.dados.ninja |
| `SDIC_DADOS_URL` | Endereço dos JSON publicados | https://storage.googleapis.com/fast-sdic-dados |
| `SDIC_PAGES_URL` | Endereço dos JSON das políticas | https://amiltonmendes.github.io/sdic_libraries |
| `SDIC_TIMEOUT` | Segundos por requisição | 30 |
| `SDIC_CACHE_TTL` | Segundos de validade do cache em disco (0 desliga) | 0 |
| `SDIC_CACHE_DIR` | Pasta do cache | `~/.cache/sdic_libraries` |


Cada valor é procurado nesta ordem, e o primeiro encontrado vale: argumento da função, variável de ambiente,
`.env.local` e `.env` da pasta atual, `~/.env`, `/etc/sdic/.env`, padrão. Os arquivos são apenas lidos: a
biblioteca não altera o ambiente do processo nem a configuração de log de quem a usa. `sdic_config()` mostra
o que está valendo e de onde veio (a chave nunca é exibida).

Nomes antigos ainda aceitos, com aviso de depreciação: `EMPLOYMENT_API_KEY` e `COMEX_API_KEY` (use
`SDIC_API_KEY`), `EMPLOYMENT_API_BASE_URL` e `COMEX_API_BASE_URL` (`SDIC_API_URL`), `PORTAL_EMPREGO_BASE_URL`
(`SDIC_PAGES_URL`), `PORTAL_EMPREGO_AMBIENTE` (`SDIC_AMBIENTE`), `API_TIMEOUT` (`SDIC_TIMEOUT`).

## Se o endereço mudar

Quem usa a biblioteca não muda nada no código: as funções recebem nomes (`"sidra_producao"`, `"SP"`,
`"emprego"`), nunca endereços.

| Mudança | O que fazer |
|---|---|
| A API, o bucket ou o Pages mudam de endereço | Atualizar a biblioteca (o endereço padrão está em `contrato/catalogo.json`). Até atualizar, definir a variável da origem (`SDIC_API_URL`, `SDIC_DADOS_URL`, `SDIC_PAGES_URL`) |
| Conferir dados antes da promoção | `SDIC_AMBIENTE=homologacao` ou `ambiente="homologacao"` |
| Uma base muda de origem (arquivo para API, por exemplo) | Nada: a função e as colunas continuam as mesmas |

## Segurança da chave

- A chave vai só no cabeçalho `Authorization`, e só para endereços `https://` (ou para a própria máquina, em teste).
- Não aparece em mensagens de erro, em `print()` dos clientes, em `sdic_config()` nem nos arquivos de cache.
- Guarde-a em `.env.local` (fora do git) ou em variável de ambiente; nunca em `.env` versionado.

## Cache

Desligado por padrão. `SDIC_CACHE_TTL=3600` guarda as respostas por uma hora em `SDIC_CACHE_DIR`
(padrão `~/.cache/sdic_libraries`). Use valores curtos: depois de uma carga, o cache serve o dado antigo até
expirar. Para limpar, apague a pasta.

## Erros comuns

| Mensagem | Causa | O que fazer |
|---|---|---|
| `Chave da API ausente, inválida ou sem acesso` (HTTP 401 ou 403) | Sem `SDIC_API_KEY`, ou chave revogada | Definir a chave; `sdic_config()` diz se ela está sendo encontrada |
| `não está publicada em 'producao'` | A seção ou as políticas ainda não foram promovidas | Usar `ambiente="homologacao"`, ou aguardar a promoção |
| `Parâmetros inválidos: ...` (HTTP 422) | Filtro desconhecido, obrigatório ausente ou valor em formato errado | A mensagem repete o que a API explicou; em séries, ver `listar_series()` |
| `Rota ou recurso não encontrado` (HTTP 404) | Série inexistente ou biblioteca desatualizada em relação à API | `listar_series()`; atualizar a biblioteca |
| `Muitas requisições` (HTTP 429), `erro interno` (HTTP 5xx) | Falha transitória; a biblioteca já repetiu 3 vezes | Tentar mais tarde |
| `Sem resposta da origem` | Rede ou tempo esgotado | Conferir a conexão; aumentar `SDIC_TIMEOUT` em consultas grandes |
| `A chave da API não é enviada para ...` | `SDIC_API_URL` não é `https://` | Corrigir a URL (`sdic_config()` mostra de onde ela veio) |
| Aviso `a API informou N registros e vieram M` | Paginação incompleta | Repetir a consulta |

Os erros têm `status_code` e `endpoint` (Python: exceção `SdicErro`; R: condição de classe `sdic_erro`), para
quem precisa tratá-los em código.
