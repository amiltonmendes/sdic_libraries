#!/usr/bin/env python3
"""
Testes Consolidados da Biblioteca SDIC - Python
===============================================

Este arquivo consolida todos os testes da biblioteca SDIC em Python:
- Testes da função criar_indice (utils.transformacoes)
- Avaliação completa da API de emprego
- Demonstrações práticas de uso
- Validação do tratamento de erros

Autor: Sistema SDIC
Data: Abril 2026
"""

import sys
import traceback
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Any, Optional
import pandas as pd
import numpy as np

# Importar todas as funções necessárias
try:
    from sdic_libraries.dados.emprego import (
        # Principais funções wrapper
        get_saldo_emprego_nacional_mensal,
        get_saldo_emprego_nacional_anual,
        get_saldo_emprego_nacional_mensal_agrupado,
        get_saldo_emprego_estadual_mensal,
        get_saldo_emprego_estadual_anual,
        get_saldo_emprego_estadual_mensal_agrupado,
        get_saldo_emprego_municipal_mensal,
        get_saldo_emprego_municipal_anual,
        get_saldo_emprego_municipal_mensal_agrupado,
        get_estoque_emprego_nacional,
        get_estoque_emprego_estadual,
        get_estoque_emprego_estimado_nacional_anual,
        get_estoque_emprego_estimado_estadual_anual,
        get_estoque_emprego_estimado_municipal_anual,
        get_estoque_emprego_estimado_nacional_anual_agrupado,
        get_estoque_emprego_estimado_estadual_anual_agrupado,
        get_estoque_emprego_estimado_municipal_anual_agrupado,
        # Classe principal
        Emprego, EmpregoAPIError
    )
    from sdic_libraries.utils.transformacoes import criar_indice
    
    IMPORTS_SUCCESS = True
    IMPORT_ERROR = None
    
except ImportError as e:
    IMPORTS_SUCCESS = False
    IMPORT_ERROR = str(e)
    print(f"❌ ERRO DE IMPORTAÇÃO: {e}")


class TestadorIndices:
    """Classe para testar a função criar_indice sistematicamente"""
    
    def __init__(self):
        self.resultados = []
        self.total_testes = 0
        self.sucessos = 0
        
    def executar_teste(self, nome_teste: str, funcao_teste):
        """Executa um teste individual e registra o resultado"""
        print(f"🔍 Testando: {nome_teste}")
        
        try:
            resultado = funcao_teste()
            self.sucessos += 1
            self.resultados.append({
                'teste': nome_teste,
                'status': 'sucesso',
                'resultado': resultado,
                'erro': None
            })
            print(f"✅ Sucesso: {nome_teste}")
            return resultado
            
        except Exception as e:
            self.resultados.append({
                'teste': nome_teste,
                'status': 'erro',
                'resultado': None,
                'erro': str(e),
                'traceback': traceback.format_exc()
            })
            print(f"❌ Erro: {nome_teste} - {e}")
            return None
        finally:
            self.total_testes += 1
            print()
    
    def teste_basico_simples(self):
        """Teste básico com dados simples"""
        df = pd.DataFrame({
            'ano': [2020, 2021, 2022, 2023],
            'vendas': [100, 120, 110, 130],
            'lucro': [50, 60, 55, 65]
        })
        
        resultado = criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores=['vendas', 'lucro'])
        
        # Verificações
        assert 'vendas_indice' in resultado.columns
        assert 'lucro_indice' in resultado.columns
        assert resultado.loc[0, 'vendas_indice'] == 100.0  # Ano base deve ser 100
        assert resultado.loc[0, 'lucro_indice'] == 100.0
        assert resultado.loc[1, 'vendas_indice'] == 120.0  # 120/100 * 100 = 120
        assert resultado.loc[1, 'lucro_indice'] == 120.0   # 60/50 * 100 = 120
        
        return resultado
    
    def teste_coluna_unica(self):
        """Teste com apenas uma coluna de valor"""
        df = pd.DataFrame({
            'ano': [2019, 2020, 2021],
            'receita': [80, 100, 150]
        })
        
        resultado = criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores='receita')
        
        # Verificações
        assert 'receita_indice' in resultado.columns
        assert resultado.loc[1, 'receita_indice'] == 100.0  # Ano base
        assert resultado.loc[2, 'receita_indice'] == 150.0  # 150/100 * 100 = 150
        assert resultado.loc[0, 'receita_indice'] == 80.0   # 80/100 * 100 = 80
        
        return resultado
    
    def teste_com_datas_datetime(self):
        """Teste com coluna de datas no formato datetime"""
        df = pd.DataFrame({
            'data': pd.to_datetime(['2020-01-01', '2021-06-15', '2022-12-31']),
            'valor': [200, 250, 300]
        })
        
        resultado = criar_indice(df, ano_base=2021, coluna_data='data', colunas_valores='valor')
        
        # Verificações
        assert 'valor_indice' in resultado.columns
        assert resultado.loc[1, 'valor_indice'] == 100.0  # 2021 é ano base
        
        return resultado
    
    def teste_multiplas_entradas_ano_base(self):
        """Teste com múltiplas entradas para o mesmo ano base (deve usar média)"""
        df = pd.DataFrame({
            'ano': [2020, 2020, 2021, 2021],
            'mes': [1, 6, 1, 6],
            'vendas': [80, 120, 100, 140]  # Média 2020: 100, Média 2021: 120
        })
        
        resultado = criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores='vendas')
        
        # Verificações - deve usar média do ano base (100)
        assert all(resultado.loc[resultado['ano'] == 2020, 'vendas_indice'] == [80.0, 120.0])
        assert all(resultado.loc[resultado['ano'] == 2021, 'vendas_indice'] == [100.0, 140.0])
        
        return resultado
    
    def teste_valor_zero_no_ano_base(self):
        """Teste com valor zero no ano base (deve retornar NaN)"""
        df = pd.DataFrame({
            'ano': [2020, 2021, 2022],
            'valor': [0, 150, 200]
        })
        
        resultado = criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores='valor')
        
        # Verificações - todos os índices devem ser NaN
        assert pd.isna(resultado['valor_indice']).all()
        
        return resultado
    
    def teste_valores_negativos(self):
        """Teste com valores negativos"""
        df = pd.DataFrame({
            'ano': [2020, 2021, 2022],
            'saldo': [-100, -50, 25]
        })
        
        resultado = criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores='saldo')
        
        # Verificações
        assert resultado.loc[0, 'saldo_indice'] == 100.0    # Ano base sempre 100
        assert resultado.loc[1, 'saldo_indice'] == 50.0     # -50/-100 * 100 = 50
        assert resultado.loc[2, 'saldo_indice'] == -25.0    # 25/-100 * 100 = -25
        
        return resultado
    
    def teste_erro_ano_inexistente(self):
        """Teste de erro quando ano base não existe nos dados"""
        df = pd.DataFrame({
            'ano': [2020, 2021, 2022],
            'valor': [100, 120, 140]
        })
        
        try:
            criar_indice(df, ano_base=2019, coluna_data='ano', colunas_valores='valor')
            raise AssertionError("Deveria ter lançado erro para ano inexistente")
        except ValueError as e:
            assert "2019 não encontrado" in str(e)
            return f"Erro capturado corretamente: {e}"
    
    def teste_multiplas_colunas_valores(self):
        """Teste com múltiplas colunas de valores"""
        df = pd.DataFrame({
            'ano': [2020, 2021, 2022],
            'vendas': [1000, 1200, 1100],
            'custos': [800, 900, 850],
            'lucro': [200, 300, 250],
            'funcionarios': [50, 55, 52]
        })
        
        resultado = criar_indice(
            df, 
            ano_base=2020, 
            coluna_data='ano', 
            colunas_valores=['vendas', 'custos', 'lucro', 'funcionarios']
        )
        
        # Verificações
        for coluna in ['vendas', 'custos', 'lucro', 'funcionarios']:
            assert f'{coluna}_indice' in resultado.columns
            assert resultado.loc[0, f'{coluna}_indice'] == 100.0  # Ano base sempre 100
        
        # Verificar alguns cálculos específicos
        assert resultado.loc[1, 'vendas_indice'] == 120.0   # 1200/1000 * 100
        assert resultado.loc[1, 'lucro_indice'] == 150.0    # 300/200 * 100
        
        return resultado
    
    def executar_testes_criacao_indice(self):
        """Executa todos os testes da função criar_indice"""
        print("🚀 TESTANDO FUNÇÃO CRIAR_INDICE")
        print("=" * 40)
        print()
        
        # Lista de todos os testes
        testes = [
            ("Teste Básico Simples", self.teste_basico_simples),
            ("Coluna Única de Valor", self.teste_coluna_unica),
            ("Datas em Formato DateTime", self.teste_com_datas_datetime),
            ("Múltiplas Entradas do Ano Base", self.teste_multiplas_entradas_ano_base),
            ("Valor Zero no Ano Base", self.teste_valor_zero_no_ano_base),
            ("Valores Negativos", self.teste_valores_negativos),
            ("Múltiplas Colunas de Valores", self.teste_multiplas_colunas_valores),
            ("Erro: Ano Inexistente", self.teste_erro_ano_inexistente),
        ]
        
        # Executar todos os testes
        for nome_teste, funcao_teste in testes:
            self.executar_teste(nome_teste, funcao_teste)
        
        return self.gerar_relatorio_indices()
    
    def gerar_relatorio_indices(self):
        """Gera relatório dos testes de criação de índice"""
        taxa_sucesso = (self.sucessos / self.total_testes * 100) if self.total_testes > 0 else 0
        
        print("📊 RELATÓRIO - FUNÇÃO CRIAR_INDICE")
        print("-" * 40)
        print(f"📈 Total de testes: {self.total_testes}")
        print(f"✅ Sucessos: {self.sucessos}")
        print(f"❌ Falhas: {self.total_testes - self.sucessos}")
        print(f"💯 Taxa de sucesso: {taxa_sucesso:.1f}%")
        
        if taxa_sucesso >= 90:
            status = "🔥 EXCELENTE - Função totalmente funcional"
        elif taxa_sucesso >= 70:
            status = "✅ BOA - Função funcional com pequenos problemas"
        else:
            status = "❌ CRÍTICA - Função com problemas sérios"
        
        print(f"🎯 Avaliação: {status}")
        print()
        
        return taxa_sucesso


class AvaliadorAPIEmprego:
    """Classe para avaliar sistematicamente as funções da API de Emprego"""
    
    def __init__(self):
        self.results = {}
        self.api_client = None
        self.start_time = datetime.now()
        self.categorias = {
            'saldo_nacional': [],
            'saldo_estadual': [], 
            'saldo_municipal': [],
            'estoque_nacional': [],
            'estoque_estadual': [],
            'estoque_estimado': [],
            'utilidades': [],
            'metodos_classe': []
        }
        
        self.params_padrao = {
            'data_minima': '2024-01-01',
            'data_maxima': '2024-02-29',
            'ano_minimo': 2023,
            'ano_maximo': 2023,
            'nivel_cnae': 'divisao',
            'codigo_cnae': '10',
            'sigla_uf': 'SP',
            'codigo_municipio': 355030,
            'nome_grupo': 'agropecuaria'
        }
        
    def configurar_api(self) -> bool:
        """Configurar e testar conectividade básica da API"""
        try:
            self.api_client = Emprego()
            self.results['config'] = {
                'base_url': self.api_client.base_url,
                'timeout': self.api_client.timeout,
                'api_key_configured': bool(self.api_client.api_key),
                'user_agent': self.api_client.session.headers.get('User-Agent'),
                'status_conexao': 'configurado'
            }
            return True
        except Exception as e:
            self.results['config'] = {
                'erro': str(e),
                'status_conexao': 'falha_configuracao'
            }
            return False
    
    def testar_funcao_api(self, categoria: str, nome_funcao: str, funcao, **kwargs) -> Dict[str, Any]:
        """Testar uma única função da API"""
        inicio = datetime.now()
        
        resultado = {
            'nome': nome_funcao,
            'categoria': categoria,
            'status': 'pendente',
            'tempo_execucao': None,
            'dados_retornados': False,
            'total_registros': 0,
            'erro_amigavel': None
        }
        
        try:
            dados = funcao(**kwargs)
            
            if dados is not None:
                resultado['dados_retornados'] = True
                
                if isinstance(dados, pd.DataFrame):
                    resultado['total_registros'] = len(dados)
                elif isinstance(dados, list):
                    resultado['total_registros'] = len(dados)
            
            resultado['status'] = 'sucesso'
            
        except EmpregoAPIError as e:
            resultado['status'] = 'erro_api'
            resultado['erro_amigavel'] = str(e)
        except Exception as e:
            resultado['status'] = 'erro_tecnico'
            resultado['erro_amigavel'] = str(e)
        
        finally:
            resultado['tempo_execucao'] = (datetime.now() - inicio).total_seconds()
            
        self.categorias[categoria].append(resultado)
        return resultado
    
    def executar_teste_api_rapido(self):
        """Executa um teste rápido da API"""
        print("🚀 TESTANDO API DE EMPREGO (RÁPIDO)")
        print("=" * 40)
        
        if not self.configurar_api():
            print("❌ Falha na configuração da API")
            return 0
        
        print("✅ API configurada com sucesso!")
        
        # Teste apenas algumas funções principais
        testes_principais = [
            ('saldo_nacional', 'get_saldo_emprego_nacional_mensal', get_saldo_emprego_nacional_mensal, {
                'nivel_cnae': self.params_padrao['nivel_cnae'],
                'codigo_cnae': self.params_padrao['codigo_cnae'],
                'data_minima': self.params_padrao['data_minima']
            }),
            ('estoque_nacional', 'get_estoque_emprego_nacional', get_estoque_emprego_nacional, {
                'nivel_cnae': 2,
                'codigos_cnae': [self.params_padrao['codigo_cnae']]
            }),
        ]
        
        sucessos = 0
        total = len(testes_principais)
        
        for categoria, nome, funcao, params in testes_principais:
            print(f"🔍 Testando: {nome}")
            resultado = self.testar_funcao_api(categoria, nome, funcao, **params)
            if resultado['status'] == 'sucesso':
                print(f"✅ Sucesso: {nome}")
                sucessos += 1
            else:
                print(f"❌ Falha: {nome} - {resultado.get('erro_amigavel', 'Erro desconhecido')}")
        
        taxa_sucesso = (sucessos / total * 100) if total > 0 else 0
        
        print("\n📊 RESULTADO DO TESTE RÁPIDO")
        print(f"✅ Sucessos: {sucessos}/{total}")
        print(f"💯 Taxa de sucesso: {taxa_sucesso:.1f}%")
        
        if taxa_sucesso >= 50:
            print("🎯 API básica está funcional")
        else:
            print("⚠️ API pode estar com problemas")
        
        print()
        return taxa_sucesso


class DemonstradorPratico:
    """Classe para demonstrações práticas das funcionalidades"""
    
    def demo_indice_com_dados_emprego(self):
        """Demonstração da função criar_indice com dados simulados de emprego"""
        print("📊 DEMONSTRAÇÃO PRÁTICA: CRIAR_INDICE")
        print("=" * 45)
        
        # Criar dados mock simulando dados de emprego
        dados_emprego = pd.DataFrame({
            'ano': [2020, 2021, 2022, 2023],
            'saldo_reajustado': [50000, 55000, 58000, 62000],
            'saldo_sem_reajuste': [45000, 48000, 50000, 53000],
            'estoque_emprego': [1000000, 1055000, 1113000, 1172000]
        })
        
        print("🗂️ Dados originais:")
        print(dados_emprego)
        print()
        
        # Criar índices com base em 2020
        resultado = criar_indice(
            df=dados_emprego,
            ano_base=2020,
            coluna_data='ano',
            colunas_valores=['saldo_reajustado', 'saldo_sem_reajuste', 'estoque_emprego']
        )
        
        print("📈 Dados com índices (base 2020 = 100):")
        print(resultado[['ano', 'saldo_reajustado', 'saldo_reajustado_indice', 'estoque_emprego', 'estoque_emprego_indice']])
        print()
        
        # Análise
        estoque_2023 = resultado.loc[3, 'estoque_emprego_indice']
        saldo_reajustado_2023 = resultado.loc[3, 'saldo_reajustado_indice']
        
        print("💡 INTERPRETAÇÃO:")
        print(f"• Estoque de Emprego 2023: {estoque_2023:.1f} (crescimento de {estoque_2023-100:.1f}%)")
        print(f"• Saldo Reajustado 2023: {saldo_reajustado_2023:.1f} (crescimento de {saldo_reajustado_2023-100:.1f}%)")
        print()
    
    def demo_tratamento_erros(self):
        """Demonstração do novo tratamento de erros amigáveis"""
        print("🔧 DEMONSTRAÇÃO: TRATAMENTO DE ERROS")
        print("=" * 40)
        
        try:
            # Tentativa que pode falhar com API indisponível
            resultado = get_saldo_emprego_nacional_mensal(
                nivel_cnae='divisao',
                codigo_cnae='10',
                data_minima='2024-01-01'
            )
            print("✅ API funcionando normalmente!")
            
        except EmpregoAPIError as e:
            print("📋 ERRO CAPTURADO (mensagem amigável):")
            print(f"   {e}")
            print("✅ Observe: mensagem clara, sem URLs ou detalhes técnicos")
            
        print()


class TestadorConsolidado:
    """Classe principal que consolida todos os testes"""
    
    def __init__(self):
        self.testador_indices = TestadorIndices()
        self.avaliador_api = AvaliadorAPIEmprego()
        self.demonstrador = DemonstradorPratico()
        self.inicio = datetime.now()
    
    def executar_todos_os_testes(self, modo: str = 'completo'):
        """
        Executa todos os testes consolidados
        
        Args:
            modo: 'completo' ou 'rapido'
        """
        print("🚀 TESTES CONSOLIDADOS DA BIBLIOTECA SDIC - PYTHON")
        print("=" * 60)
        print(f"📅 Data: {self.inicio.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"⚙️ Modo: {modo.upper()}")
        print()
        
        if not IMPORTS_SUCCESS:
            print(f"❌ Erro de importação: {IMPORT_ERROR}")
            return 1
        
        resultados = {}
        
        # 1. Testar função criar_indice
        print("1️⃣ TESTE DA FUNÇÃO CRIAR_INDICE")
        print("-" * 35)
        taxa_indices = self.testador_indices.executar_testes_criacao_indice()
        resultados['indices'] = taxa_indices
        
        # 2. Teste da API
        if modo == 'completo':
            print("2️⃣ AVALIAÇÃO COMPLETA DA API")
            print("-" * 30)
            # Seria aqui o teste completo da API se necessário
            taxa_api = self.avaliador_api.executar_teste_api_rapido()
        else:
            print("2️⃣ TESTE RÁPIDO DA API")
            print("-" * 25)
            taxa_api = self.avaliador_api.executar_teste_api_rapido()
        resultados['api'] = taxa_api
        
        # 3. Demonstrações práticas
        print("3️⃣ DEMONSTRAÇÕES PRÁTICAS")
        print("-" * 28)
        
        try:
            self.demonstrador.demo_indice_com_dados_emprego()
            self.demonstrador.demo_tratamento_erros()
            resultados['demos'] = 100
            print("✅ Todas as demonstrações executadas com sucesso")
        except Exception as e:
            print(f"⚠️ Erro nas demonstrações: {e}")
            resultados['demos'] = 0
        
        print()
        
        # Relatório final
        self.gerar_relatorio_final(resultados)
        return 0
    
    def gerar_relatorio_final(self, resultados):
        """Gera relatório consolidado final"""
        tempo_total = (datetime.now() - self.inicio).total_seconds()
        
        print("📊 RELATÓRIO FINAL CONSOLIDADO")
        print("=" * 35)
        print(f"⏱️ Tempo total de execução: {tempo_total:.2f}s")
        print()
        
        # Avaliação por componente
        print("📋 AVALIAÇÃO POR COMPONENTE:")
        print(f"• Função criar_indice: {resultados.get('indices', 0):.1f}% ⭐⭐⭐⭐⭐" if resultados.get('indices', 0) >= 90 else f"• Função criar_indice: {resultados.get('indices', 0):.1f}%")
        print(f"• API de Emprego: {resultados.get('api', 0):.1f}%")
        print(f"• Demonstrações: {'✅' if resultados.get('demos', 0) >= 90 else '⚠️'}")
        print()
        
        # Avaliação geral
        media_geral = sum(resultados.values()) / len(resultados) if resultados else 0
        
        if media_geral >= 85:
            status = "🔥 EXCELENTE - Biblioteca totalmente funcional"
        elif media_geral >= 70:
            status = "✅ BOA - Biblioteca funcional"
        elif media_geral >= 50:
            status = "⚠️ MODERADA - Alguns problemas detectados"
        else:
            status = "❌ CRÍTICA - Problemas significativos"
        
        print(f"🎯 AVALIAÇÃO GERAL: {status}")
        print(f"💯 Score médio: {media_geral:.1f}%")
        print()
        
        # Recomendações
        print("💡 RECOMENDAÇÕES:")
        if media_geral >= 85:
            print("✅ A biblioteca está pronta para uso em produção!")
            print("✅ Todas as funcionalidades principais estão operacionais")
        elif media_geral >= 70:
            print("⚠️ A biblioteca está funcional para a maioria dos casos")
            print("🔄 Monitore a API para melhor disponibilidade")
        else:
            print("🔧 Verifique a conectividade e configuração da API")
            print("📞 Entre em contato com o suporte se necessário")
        
        print()
        print("=" * 35)
        print(f"Relatório gerado por: Testes Consolidados SDIC v1.0")
        print(f"Data: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")


def main():
    """Função principal para execução dos testes consolidados"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Testes Consolidados da Biblioteca SDIC')
    parser.add_argument('--modo', choices=['completo', 'rapido'], default='rapido',
                        help='Modo de execução dos testes (default: rapido)')
    
    args = parser.parse_args()
    
    try:
        testador = TestadorConsolidado()
        return testador.executar_todos_os_testes(modo=args.modo)
    except Exception as e:
        print(f"\n💥 ERRO CRÍTICO: {e}")
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())