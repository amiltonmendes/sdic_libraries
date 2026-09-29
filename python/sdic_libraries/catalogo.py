"""Catálogo das funções públicas da biblioteca, por tema.

Não sabe qual função usar? ``listar_bases()`` devolve um DataFrame com uma linha por
função: tema, o que ela traz, nível de agregação e um exemplo mínimo de chamada. Todas
as funções listadas são de :mod:`sdic_libraries.dados.emprego`, :mod:`sdic_libraries.dados.comex`
ou :mod:`sdic_libraries.utils` — o catálogo só aponta para elas, não reimplementa nada.
"""
from __future__ import annotations

from typing import Optional

import pandas as pd

COLUNAS = ["tema", "subtema", "nivel", "funcao", "descricao", "exemplo"]

# tema, subtema, nivel, funcao, descricao, exemplo
_CATALOGO = [
    # ---- emprego / estoque (RAIS) ----
    ("emprego", "estoque", "nacional", "get_estoque_emprego_nacional",
     "Estoque de vínculos ativos (31/12) por divisão ou grupo CNAE.",
     "get_estoque_emprego_nacional(codigos_cnae=['10'], nivel_cnae=2)"),
    ("emprego", "estoque", "estadual", "get_estoque_emprego_estadual",
     "Igual ao nacional, por UF.",
     "get_estoque_emprego_estadual(uf='SP', codigos_cnae=['10'])"),
    ("emprego", "estoque", "nacional", "get_estoque_emprego_nacional_agrupado",
     "Estoque somado para uma lista de CNAEs sob um nome de grupo (ex.: 'TI').",
     "get_estoque_emprego_nacional_agrupado('TI', ['620', '631'])"),
    ("emprego", "estoque", "estadual", "get_estoque_emprego_estadual_agrupado",
     "Igual ao agrupado nacional, por UF.",
     "get_estoque_emprego_estadual_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])"),
    ("emprego", "estoque_estimado", "nacional", "get_estoque_emprego_estimado_nacional_anual",
     "Estoque real (RAIS) + projeção com o saldo CAGED acumulado até o ano corrente (coluna 'origem': Real/Estimação).",
     "get_estoque_emprego_estimado_nacional_anual(codigo_cnae='10')"),
    ("emprego", "estoque_estimado", "estadual", "get_estoque_emprego_estimado_estadual_anual",
     "Igual ao estimado nacional, por UF.",
     "get_estoque_emprego_estimado_estadual_anual(sigla_uf='SP', codigo_cnae='10')"),
    ("emprego", "estoque_estimado", "municipal", "get_estoque_emprego_estimado_municipal_anual",
     "Igual ao estimado nacional, por município.",
     "get_estoque_emprego_estimado_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, codigo_cnae='10')"),
    ("emprego", "estoque_porte", "nacional", "get_estoque_emprego_porte_nacional",
     "Estoque por porte do estabelecimento (Sebrae/DIEESE) e setor (Indústria x Comércio/Serviços).",
     "get_estoque_emprego_porte_nacional('divisao', codigos_cnae=['10'], setor='Indústria')"),
    ("emprego", "estoque_porte", "estadual", "get_estoque_emprego_porte_estadual",
     "Igual ao porte nacional, por UF.",
     "get_estoque_emprego_porte_estadual(uf='SP', nivel_cnae='divisao', porte=['Microempresa'])"),
    ("emprego", "estoque_classe", "nacional", "get_estoque_emprego_classe_cnae_nacional",
     "Estoque por classe CNAE (4 dígitos, mais fino que divisão/grupo).",
     "get_estoque_emprego_classe_cnae_nacional(codigos_classe=['1011'])"),
    ("emprego", "estoque_classe", "estadual", "get_estoque_emprego_classe_cnae_estadual",
     "Igual ao classe nacional, por UF.",
     "get_estoque_emprego_classe_cnae_estadual(uf='SP', codigos_classe=['1011'])"),
    ("emprego", "estoque_ocupacao", "estadual", "get_estoque_emprego_uf_cbo",
     "Estoque por UF, classe CNAE e ocupação (CBO). Endpoint pesado: sempre filtre siglas_uf e codigos_classe.",
     "get_estoque_emprego_uf_cbo(siglas_uf=['SP'], codigos_classe=['4711'])"),
    ("emprego", "renda", "nacional", "get_renda_media_emprego",
     "Remuneração média (RAIS) por divisão/grupo CNAE ou geral.",
     "get_renda_media_emprego(tipos=['Divisao'], codigos=['10'])"),
    ("emprego", "potec", "nacional", "get_potec_emprego",
     "Índice Potec: fração de pessoal ocupado técnico-científico por classe CNAE (proxy de P&D da PINTEC).",
     "get_potec_emprego(codigos_classe=['7210'])"),
    ("emprego", "metadados", "-", "get_date_bases",
     "Data da última atualização de cada base (CAGED, RAIS, ComexStat).",
     "get_date_bases()"),
    # ---- emprego / saldo (Novo CAGED) ----
    ("emprego", "saldo_caged", "nacional", "get_saldo_emprego_nacional_mensal",
     "Saldo mensal (admissões − desligamentos) por divisão/grupo/subclasse CNAE.",
     "get_saldo_emprego_nacional_mensal(nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "nacional", "get_saldo_emprego_nacional_anual",
     "Saldo somado por ano, mesmo recorte do mensal.",
     "get_saldo_emprego_nacional_anual(nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "nacional", "get_saldo_emprego_nacional_mensal_agrupado",
     "Saldo mensal somado para uma lista de CNAEs sob um nome de grupo.",
     "get_saldo_emprego_nacional_mensal_agrupado('TI', ['620', '631'])"),
    ("emprego", "saldo_caged", "estadual", "get_saldo_emprego_estadual_mensal",
     "Igual ao saldo mensal nacional, por UF.",
     "get_saldo_emprego_estadual_mensal(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "estadual", "get_saldo_emprego_estadual_anual",
     "Igual ao saldo anual nacional, por UF.",
     "get_saldo_emprego_estadual_anual(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "estadual", "get_saldo_emprego_estadual_mensal_agrupado",
     "Igual ao saldo agrupado nacional, por UF.",
     "get_saldo_emprego_estadual_mensal_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])"),
    ("emprego", "saldo_caged", "municipal", "get_saldo_emprego_municipal_mensal",
     "Igual ao saldo mensal nacional, por município.",
     "get_saldo_emprego_municipal_mensal(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "municipal", "get_saldo_emprego_municipal_anual",
     "Igual ao saldo anual nacional, por município.",
     "get_saldo_emprego_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')"),
    ("emprego", "saldo_caged", "municipal", "get_saldo_emprego_municipal_mensal_agrupado",
     "Igual ao saldo agrupado nacional, por município.",
     "get_saldo_emprego_municipal_mensal_agrupado(sigla_uf='SP', codigo_municipio=3550308, nome_grupo='TI', lista_cnae=['620'])"),
    # ---- emprego / portal (cache já publicado, sem chamar a API) ----
    ("emprego", "portal_cache", "estadual", "get_relatorio_emprego_saldo_estadual",
     "Saldo CAGED mensal por UF, lido do cache já publicado (GitHub Pages) — não chama a API ao vivo.",
     "get_relatorio_emprego_saldo_estadual(uf='SP')"),
    ("emprego", "portal_cache", "estadual", "get_relatorio_emprego_estoque_estadual",
     "Estoque RAIS por UF, lido do cache já publicado — não chama a API ao vivo.",
     "get_relatorio_emprego_estoque_estadual(uf='SP')"),
    # ---- comex ----
    ("comex", "comercio_ncm", "nacional", "get_exportacao_ncm_nacional_mensal",
     "Exportações mensais por NCM (produto), com filtro opcional por seção ISIC.",
     "get_exportacao_ncm_nacional_mensal(ano_minimo=2024, secao='Indústria de Transformação')"),
    ("comex", "comercio_ncm", "nacional", "get_importacao_ncm_nacional_mensal",
     "Igual ao NCM de exportação, para importações.",
     "get_importacao_ncm_nacional_mensal(ano_minimo=2024)"),
    ("comex", "comercio_isic", "nacional", "get_exportacao_isic_divisao_nacional_mensal",
     "Exportações mensais por divisão ISIC (setor) — a chave para juntar com emprego (juntar_emprego_comex).",
     "get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)"),
    ("comex", "comercio_isic", "nacional", "get_importacao_isic_divisao_nacional_mensal",
     "Igual ao ISIC de exportação, para importações.",
     "get_importacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)"),
    ("comex", "comercio_isic", "estadual", "get_exportacao_isic_divisao_estadual_mensal",
     "Igual ao ISIC nacional, por UF (e opcionalmente por país/bloco).",
     "get_exportacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)"),
    ("comex", "comercio_isic", "estadual", "get_importacao_isic_divisao_estadual_mensal",
     "Igual ao ISIC estadual de exportação, para importações.",
     "get_importacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)"),
    ("comex", "comercio_pais", "nacional", "get_exportacao_pais_nacional_mensal",
     "Exportações mensais por país de destino.",
     "get_exportacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)"),
    ("comex", "comercio_pais", "nacional", "get_importacao_pais_nacional_mensal",
     "Igual ao país de exportação, para importações (país de origem).",
     "get_importacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)"),
    ("comex", "comercio_mapa", "-", "get_ncm_isic_mapa",
     "De-para NCM → divisão/seção ISIC (catálogo estático, ~13 mil códigos).",
     "get_ncm_isic_mapa()"),
    # ---- utilitários (transformam o que as funções acima devolvem) ----
    ("utilitarios", "transformacao", "-", "criar_indice",
     "Índice-base (ano_base = 100) para colunas numéricas de uma série temporal.",
     "criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores=['estoque_trabalhadores'])"),
    ("utilitarios", "transformacao", "-", "juntar_emprego_comex",
     "Une emprego e comércio exterior por divisão CNAE/ISIC e ano.",
     "juntar_emprego_comex(df_emprego, df_comex)"),
]


def listar_bases(tema: Optional[str] = None, subtema: Optional[str] = None) -> pd.DataFrame:
    """Catálogo das funções públicas da biblioteca, opcionalmente filtrado.

    Args:
        tema (str, optional): 'emprego', 'comex' ou 'utilitarios'.
        subtema (str, optional): ex. 'estoque', 'saldo_caged', 'comercio_ncm' —
            veja ``listar_bases()['subtema'].unique()`` para todos os valores.

    Returns:
        pd.DataFrame: colunas tema, subtema, nivel, funcao, descricao, exemplo —
        uma linha por função pronta para usar (``from sdic_libraries.dados.emprego import
        <funcao>`` ou ``from sdic_libraries.dados.comex import <funcao>``; utilitários
        vêm de ``sdic_libraries.utils``).
    """
    df = pd.DataFrame(_CATALOGO, columns=COLUNAS)
    if tema:
        df = df[df["tema"] == tema]
    if subtema:
        df = df[df["subtema"] == subtema]
    return df.reset_index(drop=True)
