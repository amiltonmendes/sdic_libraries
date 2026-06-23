#!/usr/bin/env python3
"""
Instalação da Biblioteca SDIC-Libraries via GitHub (Python)
Script automatizado para instalar diretamente do repositório com pip
"""

import subprocess
import sys
import os


def banner():
    print("🚀" + "=" * 64 + "🚀")
    print("       BIBLIOTECA SDIC - INSTALAÇÃO VIA GITHUB (Python)")
    print("    Dados de Emprego Brasileiros | Instalação Automática")
    print("🚀" + "=" * 64 + "🚀")


def run_command(command, description):
    """Executa comando com feedback visual"""
    print(f"\n📦 {description}...")
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            check=True, 
            capture_output=True, 
            text=True
        )
        print(f"✅ {description} - Sucesso!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} - Erro:")
        print(f"   Comando: {command}")
        print(f"   Saída: {e.output}")
        print(f"   Erro: {e.stderr}")
        return False


def check_python_version():
    """Verifica se a versão do Python é compatível"""
    if sys.version_info < (3, 8):
        print(f"❌ Python {sys.version_info.major}.{sys.version_info.minor} não é compatível.")
        print("   Biblioteca requer Python 3.8+")
        return False
    print(f"✅ Python {sys.version_info.major}.{sys.version_info.minor} é compatível")
    return True


def install_from_github():
    """Instala biblioteca diretamente do GitHub via pip"""
    banner()
    
    # Verificar versão Python
    if not check_python_version():
        sys.exit(1)
    
    # URLs de instalação
    github_urls = [
        "git+https://github.com/sdic-org/sdic_libraries.git#subdirectory=python",
        "git+https://github.com/sdic-org/sdic_libraries.git",  # Fallback
    ]
    
    # Tentar atualizar pip primeiro
    run_command(
        f"{sys.executable} -m pip install --upgrade pip",
        "Atualizando pip"
    )
    
    # Tentar instalação do GitHub
    for i, url in enumerate(github_urls, 1):
        print(f"\n🚀 Tentativa {i}: Instalando do GitHub...")
        print(f"   URL: {url}")
        
        success = run_command(
            f"{sys.executable} -m pip install '{url}'",
            f"Instalação da biblioteca (tentativa {i})"
        )
        
        if success:
            print("✅ Instalação do GitHub bem-sucedida!")
            break
    else:
        print("\n❌ Todas as tentativas de instalação falharam.")
        print("💡 ALTERNATIVAS:")
        print("   1. Clone manual:")
        print("      git clone https://github.com/sdic-org/sdic_libraries.git")
        print("      cd sdic_libraries/python")
        print("      pip install .")
        print("   2. Download direto:")
        print("      pip install https://github.com/sdic-org/sdic_libraries/archive/main.zip#subdirectory=python")
        return False
    
    # Teste de importação
    print("\n🧪 Testando instalação...")
    test_success = run_command(
        f"{sys.executable} -c \"from sdic_libraries.dados.emprego import Emprego; print('✅ Import bem-sucedido')\"",
        "Teste de importação"
    )
    
    if test_success:
        print("\n🎉 INSTALAÇÃO CONCLUÍDA COM SUCESSO!")
        print("\n📖 EXEMPLOS DE USO:")
        print("=" * 50)
        print("from sdic_libraries.dados.emprego import Emprego")
        print("")
        print("# Usar a biblioteca:")
        print("with Emprego() as api:")
        print("    dados = api.get_saldo_emprego_detalhado('nacional')")
        print("    print(f'Registros: {len(dados)}')")
        print("")
        print("📖 Documentação: https://github.com/sdic-org/sdic_libraries#readme")
    else:
        print("⚠️ Instalação aparentemente bem-sucedida, mas teste de importação falhou.")
        print("   Pode haver problemas de dependências.")
    
    return test_success


def main():
    """Função principal"""
    try:
        install_from_github()
    except KeyboardInterrupt:
        print("\n❌ Instalação cancelada pelo usuário.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Erro inesperado: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()