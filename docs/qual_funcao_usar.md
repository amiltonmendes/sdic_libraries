# Qual função usar

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

| Preciso de | Use | Exemplo |
|---|---|---|
| Um número que o portal também mostra (indicadores, séries dos gráficos, rankings das seções) | Seções publicadas | `get_kpis_publicados("SP", "emprego")` |
| Uma política da SDIC | Políticas | `get_politicas_estado("SP")` |
| Uma série de uma base (SIDRA, Contas Regionais, comex por UF e ISIC) ou um indicador oficial | Séries da API | `get_serie("sidra_producao", cod_tabela=8888, cod_localidade="35")` |
| Emprego formal com recorte próprio (CNAE, município, porte, ocupação) | Emprego | `get_saldo_emprego_estadual_mensal(sigla_uf="SP", codigo_cnae="10")` |
| Comércio exterior com recorte próprio (NCM, país, ISIC, agrupamentos) | Comex | `get_exportacao_isic_divisao_estadual_mensal(estado="São Paulo")` |
| Saber o que existe | `listar_bases()`, `listar_series()`, `listar_secoes_publicadas()`, `listar_politicas()` | |
| Saber de onde vem um dado e que colunas ele tem | `descrever(nome)` | `descrever("get_kpis_publicados")` |
| Saber de onde a biblioteca está lendo | `sdic_config()` | |
| Um arquivo publicado que não tem função (último recurso) | `ler_json_publicado(origem, caminho)` | `ler_json_publicado("dados", "homologacao/SP/emprego_relatorio.json")` |

Regras que valem para qualquer relatório ou análise:

- **Leia só pela biblioteca.** Nada de HTTP próprio, planilha local ou cópia de arquivo: é isso que permite
  trocar o endereço da API ou o local dos arquivos sem mexer no seu código.
- **Não some nem compare políticas ou indicadores de unidades diferentes** (R$ com atendimentos, por exemplo).
  A ordem das políticas é a publicada; não reordene.
- **Diga o ambiente quando não for produção**: `ambiente="homologacao"` ou `SDIC_AMBIENTE=homologacao`.
- **Número que não existe em lugar nenhum** vira um indicador (`cgid_reports/indicadores`), não uma conta dentro
  do relatório. Depois de oficial e publicado na API, ele é lido com `get_serie(id)`.
