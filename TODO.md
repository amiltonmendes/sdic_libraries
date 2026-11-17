# TODO

Só o que falta; o que foi feito sai daqui (o histórico está no git e no [CHANGELOG.md](CHANGELOG.md)).
Regras gerais: [AGENTS.md](AGENTS.md).

## Interface

| Falta | Por quê não foi feito ainda |
|---|---|
| Nomes de parâmetro iguais em todas as funções (`uf`, `sigla_uf`, `siglas_uf`, `estado`; `nivel_cnae` número ou texto) | Muda a assinatura de dezenas de funções com consumidores: pede uma rodada própria, com depreciação |
| Resultado vazio com as colunas, nas funções antigas de emprego | As funções novas já devolvem as colunas; as antigas dependem de um esquema por rota que não existe no contrato |
| Exemplo e colunas no roxygen das funções antigas de R; assinatura `(...)` das funções de comex em R | Em Python o exemplo do catálogo já aparece no `help()`; em R ficou só nas funções novas |
| Colunas duplicadas do emprego (`ano` e `Ano`, `competencia` e `mes_referencia`) | O `carga_base/publicacao` depende delas |
| Paridade de assinaturas entre Python e R (há funções só em R e só em Python) | O teste de paridade cobre só o que está no catálogo |
| Avisos do `R CMD check` (texto não ASCII, arquivo de licença) | Não impedem instalar |
| `listar_indicadores()` e indicadores em `get_serie()` | Depende de a `sdic_api` publicar indicadores em `/series`; hoje ela só publica séries das bases |

## Comércio exterior por agrupamentos

As rotas estão no ar e as cinco funções, no catálogo. Falta:

| Falta | Detalhe |
|---|---|
| Padronizar a resposta na `sdic_api` | As rotas de agrupamentos devolvem só `QTEstat` (nas demais, o nome é `QuantidadeEstatistica` e `QTEstat` é obsoleto) e a chave `posicao` em minúsculas. A biblioteca já entrega `quantidade_estatistica` e `posicao`; quando a API mudar, recapturar as amostras de `contrato/comex_amostras.json` |
| Códigos de agrupamento sem NCM correspondente | Em 30/09/2026 havia 32 linhas do cadastro de agrupamentos sem NCM ou SH válido (Saúde, Automotivo, Liprode, entre outros). É decisão de quem mantém o cadastro; reconferir sobre a tabela atual (`ncm_agrupamento`, no `carga_base`) |
| Exemplo no README | Mostrar `get_agrupamentos_disponiveis()` para descobrir o nome antes de chamar as outras quatro |

## Repositório

- Apagar no GitHub os branches `api-4` e `biblioteca-0.6` (já estão no `main`).
- Revogar a chave `sdic-libraries-amostras` quando não for mais preciso recapturar amostras
  (`sdic_api/scripts/seguranca.sh revogar sdic-libraries-amostras`).
- Avisar quem usa R em outras máquinas: apagar a pasta de cache antiga (`~/.cache/R/sdic.libraries`).
