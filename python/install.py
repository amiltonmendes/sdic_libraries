#!/usr/bin/env python3
"""
Script de instalação automática da biblioteca SDIC Python
Instala automaticamente todas as dependências necessárias
"""

import subprocess
import sys
from pathlib import Path


def run_command(command, description):
    """Executa um comando e mostra o resultado"""
    print(f"\n🔧 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} concluído com sucesso")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Erro em {description}: {e}")
        print(f"Output: {e.stdout}")
        print(f"Error: {e.stderr}")
        return False


def main():
    """Função principal de instalação"""
    print("🚀 Instalação Automática da Biblioteca SDIC Python")
    print("=" * 55)
    
    # Verificar se Python está disponível
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    print(f"📋 Python detectado: {python_version}")
    
    # Diretório atual
    current_dir = Path(__file__).parent
    print(f"📁 Diretório: {current_dir}")
    
    # Lista de comandos para execução
    commands = [
        # Atualizar pip
        ("python -m pip install --upgrade pip", 
         "Atualizando pip"),
        
        # Instalar dependências de produção  
        ("pip install -r requirements.txt",
         "Instalando dependências de produção"),
        
        # Instalar dependências de desenvolvimento (opcional)
        ("pip install -r requirements-dev.txt",
         "Instalando dependências de desenvolvimento"),
        
        # Instalar a biblioteca em modo editável
        ("pip install -e .",
         "Instalando biblioteca SDIC em modo desenvolvimento"),
    ]
    
    success_count = 0
    total_commands = len(commands)
    
    for command, description in commands:
        if run_command(command, description):
            success_count += 1
        else:
            print(f"⚠️ Falha em: {description}")
    
    print("\n" + "=" * 55)
    print(f"📊 Resumo da Instalação: {success_count}/{total_commands} comandos executados com sucesso")
    
    if success_count == total_commands:
        print("🎉 Instalação da biblioteca SDIC Python concluída com SUCESSO!")
        print("\n📖 Como usar:")
        print("   from sdic_libraries.data_access.emprego import Emprego")
        print("   api = Emprego()")
        print("   dados = api.get_saldo_emprego_detalhado('nacional')")
        
        # Teste básico
        print("\n🧪 Teste básico...")
        try:
            from sdic_libraries.data_access.emprego import Emprego
            api = Emprego()
            api.close()
            print("✅ Importação da biblioteca funcionou perfeitamente!")
        except Exception as e:
            print(f"❌ Erro na importação: {e}")
            
    else:
        print("⚠️ Algumas dependências falharam. Verifique os erros acima.")
        

if __name__ == "__main__":
    main()