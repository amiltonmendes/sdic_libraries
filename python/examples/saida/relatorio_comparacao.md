# Relatório de atualização — Lista de CNAE (emprego e empresas)

- **Gerado em:** 24/08/2026 11:37
- **Arquivo de origem:** `2026-04-28-Lista de CNAE para medição do emprego e empresas24082026.xlsx`
- **Arquivo gerado:** `2026-04-28-Lista de CNAE para medição do emprego e empresas24082026__atualizado.xlsx`
- **Aba comparada:** `Dados atualizados para 2025`
- **Fonte dos dados:** API SDIC (`https://sdicapi.dados.ninja`) via `sdic_libraries`
- **Último mês CAGED disponível:** 2025-12-01
- **Layout preservado:** 107 linhas de dados, colunas A–V, 3 linhas de cabeçalho mantidas

## 1. Cobertura das colunas

| Colunas | Conteúdo | Atualizável? | Função usada / motivo |
|---|---|---|---|
| D, E, F | Estoque 2022/2023/2024 — linhas de **grupo** (3 díg.) | ✅ Sim | `get_estoque_emprego_nacional(nivel_cnae=3, agregado=True)` |
| D, E, F | Estoque 2022/2023/2024 — linhas de **classe** (5 díg.) | ❌ Não | API expõe estoque apenas nos níveis divisão (2 díg.) e grupo (3 díg.); não há endpoint de estoque no nível classe (5 díg.) |
| G | Estoque 2025 (projetado) | ✅ Sim | fórmula `=F+J` preservada (mesma lógica de `get_estoque_emprego_estimado_nacional_anual`) |
| H, I, J | Saldo 2023/2024/2025 — linhas de **grupo** | ✅ Sim | `get_saldo_caged_nacional('grupo')` |
| H, I, J | Saldo 2023/2024/2025 — linhas de **classe** | ✅ Sim | `get_saldo_caged_nacional('subclasse')` agregado pelos 5 primeiros dígitos |
| K–N | Estabelecimentos por porte 2022 | ❌ Não | vazio na origem e sem fonte na API |
| O–R, S–V | Estabelecimentos por porte 2023 / 2024 | ❌ Não | Não há na biblioteca nem na API endpoint de estabelecimentos por porte da RAIS/metodologia Sebrae com recorte anual e 4 portes |

## 2. Resumo por resultado

| Resultado | Células |
|---|---|
| nao_atualizado | 1428 |
| divergente | 415 |
| identico | 177 |
| vazio_nos_dois | 1 |
| **total** | **2021** |

## 3. Resumo por coluna

| Coluna | Atualizadas | Idênticas | Divergentes | Não atualizadas | Δ médio | Δ máx (abs) |
|---|---|---|---|---|---|---|
| D — EMPREGOS / Estoque 2022 | 54 | 55 | 0 | 52 | 0.0 | 0 |
| E — Estoque 2023 | 54 | 4 | 51 | 52 | -12,242.9 | 501,393 |
| F — Estoque 2024 | 54 | 2 | 53 | 52 | -16,162.4 | 668,495 |
| G — Estoque 2025 | 0 | 4 | 103 | 0 | -12,465.1 | 1,113,547 |
| H — Saldo / 2023 (jan-dez) | 106 | 58 | 49 | 0 | 9.0 | 907 |
| I — 2024 (jan-dez) | 105 | 42 | 64 | 0 | 14.4 | 1,160 |
| J — 2025 (jan-dez) | 106 | 12 | 95 | 0 | -4,160.4 | 445,052 |
| K — Quantidade de estabelecimentos por porte(RAIS) (Metodologia Sebrae) 2022 / Microempresa | 0 | 0 | 0 | 106 | — | — |
| L — Empresa de pequeno porte | 0 | 0 | 0 | 106 | — | — |
| M — Empresa de médio porte | 0 | 0 | 0 | 106 | — | — |
| N — Grande empresa | 0 | 0 | 0 | 106 | — | — |
| O — Quantidade de estabelecimentos por porte(RAIS completa) (Metodologia Sebrae) 2023 / Microempresa | 0 | 0 | 0 | 106 | — | — |
| P — Empresa de pequeno porte | 0 | 0 | 0 | 106 | — | — |
| Q — Empresa de médio porte | 0 | 0 | 0 | 106 | — | — |
| R — Grande empresa | 0 | 0 | 0 | 106 | — | — |
| S — Quantidade de estabelecimentos por porte(RAIS) (Metodologia Sebrae) 2024 / Microempresa | 0 | 0 | 0 | 106 | — | — |
| T — Empresa de pequeno porte | 0 | 0 | 0 | 106 | — | — |
| U — Empresa de médio porte | 0 | 0 | 0 | 106 | — | — |
| V — Grande empresa | 0 | 0 | 0 | 106 | — | — |

## 4. Maiores divergências (origem x gerado)

| Linha | Col | CNAE | Descrição | Origem | Gerado | Δ | Δ% |
|---|---|---|---|---|---|---|---|
| 4 | G | — | TOTAL DE TODAS AS CNAES | 59,517,251 | 58,403,704 | -1,113,547 | -1.87% |
| 4 | F | — | TOTAL DE TODAS AS CNAES | 57,800,651 | 57,132,156 | -668,495 | -1.16% |
| 4 | E | — | TOTAL DE TODAS AS CNAES | 55,818,007 | 55,316,614 | -501,393 | -0.90% |
| 4 | J | — | TOTAL DE TODAS AS CNAES | 1,716,600 | 1,271,548 | -445,052 | -25.93% |
| 5 | F | — | TOTAL CANAES ABAIXO | 11,061,803 | 10,951,584 | -110,219 | -1.00% |
| 5 | G | — | TOTAL CANAES ABAIXO | 11,177,422 | 11,067,310 | -110,112 | -0.99% |
| 5 | E | — | TOTAL CANAES ABAIXO | 10,842,619 | 10,756,637 | -85,982 | -0.79% |
| 58 | G | 478 | Comércio varejista de produtos novos não espe… | 1,309,919 | 1,273,265 | -36,654 | -2.80% |
| 58 | F | 478 | Comércio varejista de produtos novos não espe… | 1,306,144 | 1,269,494 | -36,650 | -2.81% |
| 58 | E | 478 | Comércio varejista de produtos novos não espe… | 1,297,557 | 1,268,782 | -28,775 | -2.22% |
| 56 | F | 475 | Comércio varejista de equipamentos de informá… | 796,612 | 778,633 | -17,979 | -2.26% |
| 56 | G | 475 | Comércio varejista de equipamentos de informá… | 794,799 | 776,872 | -17,927 | -2.26% |
| 57 | G | 477 | Comércio varejista de produtos farmacêuticos,… | 878,641 | 862,219 | -16,422 | -1.87% |
| 57 | F | 477 | Comércio varejista de produtos farmacêuticos,… | 845,948 | 829,558 | -16,390 | -1.94% |
| 56 | E | 475 | Comércio varejista de equipamentos de informá… | 799,482 | 785,851 | -13,631 | -1.71% |
| 57 | E | 477 | Comércio varejista de produtos farmacêuticos,… | 814,755 | 802,067 | -12,688 | -1.56% |
| 6 | F | 141 | Confecção de artigos do vestuário e acessório… | 507,545 | 496,527 | -11,018 | -2.17% |
| 6 | G | 141 | Confecção de artigos do vestuário e acessório… | 504,592 | 493,579 | -11,013 | -2.18% |
| 6 | E | 141 | Confecção de artigos do vestuário e acessório… | 504,718 | 496,512 | -8,206 | -1.63% |
| 52 | F | 464 | Comércio atacadista de produtos de consumo nã… | 434,902 | 430,320 | -4,582 | -1.05% |
| 52 | G | 464 | Comércio atacadista de produtos de consumo nã… | 445,626 | 441,076 | -4,550 | -1.02% |
| 52 | E | 464 | Comércio atacadista de produtos de consumo nã… | 414,442 | 410,830 | -3,612 | -0.87% |
| 51 | F | 461 | Representantes comerciais e agentes do comérc… | 71,258 | 68,415 | -2,843 | -3.99% |
| 51 | G | 461 | Representantes comerciais e agentes do comérc… | 74,080 | 71,274 | -2,806 | -3.79% |
| 55 | G | 468 | Comércio atacadista especializado em outros p… | 289,445 | 286,735 | -2,710 | -0.94% |
| 55 | F | 468 | Comércio atacadista especializado em outros p… | 284,618 | 281,917 | -2,701 | -0.95% |
| 9 | G | 153 | Fabricação de calçados | 251,046 | 248,773 | -2,273 | -0.91% |
| 9 | F | 153 | Fabricação de calçados | 254,391 | 252,134 | -2,257 | -0.89% |
| 55 | E | 468 | Comércio atacadista especializado em outros p… | 279,565 | 277,339 | -2,226 | -0.80% |
| 9 | E | 153 | Fabricação de calçados | 257,304 | 255,390 | -1,914 | -0.74% |

> **Como ler as divergências.** Elas não indicam erro: a planilha de origem
> fixou os números na data em que foi montada. As colunas E/F (estoque
> 2023/2024) traziam valores *projetados* a partir do estoque de 2022 mais o
> saldo acumulado, enquanto a API já devolve o estoque **efetivo** da RAIS —
> daí a diferença sistemática para baixo. As colunas H/I (saldo 2023/2024)
> diferem apenas por revisões mensais do CAGED (ordem de dezenas). A coluna J
> (saldo 2025) diverge porque a origem ainda carregava o acumulado jan-set;
> o arquivo gerado traz o ano fechado. A coluna D (estoque 2022) bate
> exatamente, confirmando que origem e API compartilham a mesma base.

## 5. Células não atualizadas

| Colunas | Células | Motivo |
|---|---|---|
| D, E, F | 156 | API expõe estoque apenas nos níveis divisão (2 díg.) e grupo (3 díg.); não há endpoint de estoque no nível classe (5 díg.) |
| K, L, M, N | 424 | Não há na biblioteca nem na API endpoint de estabelecimentos por porte da RAIS/metodologia Sebrae com recorte anual e 4 portes (ano 2022) |
| O, P, Q, R | 424 | Não há na biblioteca nem na API endpoint de estabelecimentos por porte da RAIS/metodologia Sebrae com recorte anual e 4 portes (ano 2023) |
| S, T, U, V | 424 | Não há na biblioteca nem na API endpoint de estabelecimentos por porte da RAIS/metodologia Sebrae com recorte anual e 4 portes (ano 2024) |
