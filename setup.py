#!/usr/bin/env python3
"""
Setup.py - Script de configuração e instalação completa da biblioteca SDIC
Automatiza todo o processo de instalação e configuração
"""

import os
import shlex
import subprocess
import sys
from pathlib import Path


def banner():
    print("🚀" + "=" * 60 + "🚀")
    print("       BIBLIOTECA SDIC - INSTALAÇÃO COMPLETA")
    print("    Dados de Emprego Brasileiros | Python + R")  
    print("🚀" + "=" * 60 + "🚀")


def run_command(command, description, continue_on_error=True):
    """Executa comando com feedback visual"""
    print(f"\n{description}...")
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            check=True, 
            capture_output=True, 
            text=True,
            cwd=Path(__file__).parent
        )
        print(f"✅ {description} - SUCESSO")
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} - FALHOU")
        if e.stdout:
            print(f"   Saída: {e.stdout[:200]}...")
        if e.stderr:
            print(f"   Erro: {e.stderr[:200]}...")
        
        if not continue_on_error:
            sys.exit(1)
        return False, None


def detect_environment():
    """Detecta o ambiente de execução"""
    print("\n🔍 DETECTANDO AMBIENTE")
    print("-" * 30)
    
    # Verificar Python
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    print(f"🐍 Python: {python_version}")
    
    # Verificar R
    r_available = False
    try:
        result = subprocess.run(
            'Rscript --version', 
            shell=True, 
            capture_output=True, 
            text=True
        )
        if result.returncode == 0:
            r_version = result.stderr.split('\n')[0] if result.stderr else "R disponível"
            print(f"📊 R: {r_version}")
            r_available = True
    except:
        print("❌ R: Não encontrado")
    
    # Verificar Make
    make_available = False
    try:
        result = subprocess.run('make --version', shell=True, capture_output=True)
        if result.returncode == 0:
            print("🔨 Make: Disponível")
            make_available = True
    except:
        print("❌ Make: Não encontrado")
    
    return {
        'python_version': python_version,
        'r_available': r_available,  
        'make_available': make_available
    }


def install_python_dependencies():
    """Instala dependências Python"""
    print("\n🐍 INSTALAÇÃO PYTHON")
    print("-" * 25)

    python_exec = shlex.quote(sys.executable)
    
    commands = [
        (f"{python_exec} -m pip install --upgrade pip", "Atualizando pip"),
        (f"cd python && {python_exec} -m pip install -r requirements.txt", "Instalando dependências principais"),
        (f"cd python && {python_exec} -m pip install -e .", "Instalando biblioteca em modo desenvolvimento"),
    ]
    
    success_count = 0
    for command, description in commands:
        success, _ = run_command(command, description)
        if success:
            success_count += 1
    
    return success_count == len(commands)


def install_r_dependencies():
    """Instala dependências R se disponível"""
    print("\n📊 INSTALAÇÃO R")
    print("-" * 20)
    
    import tempfile
    r_script = (
        'packages <- c("R6", "httr2", "jsonlite", "dplyr", "tibble", "lubridate", "cli", "rlang")\n'
        'missing <- packages[!packages %in% installed.packages()[,"Package"]]\n'
        'if (length(missing) > 0) {\n'
        '  install.packages(missing, quiet=TRUE)\n'
        '  cat("Pacotes instalados:", paste(missing, collapse=", "), "\\n")\n'
        '} else {\n'
        '  cat("Todos os pacotes ja instalados\\n")\n'
        '}\n'
    )
    with tempfile.NamedTemporaryFile(mode='w', suffix='.R', delete=False) as tmp:
        tmp.write(r_script)
        tmp_path = tmp.name

    success, output = run_command(
        f'Rscript {tmp_path}',
        "Instalando dependências R"
    )
    Path(tmp_path).unlink(missing_ok=True)

    return success


def test_installation():
    """Testa a instalação"""
    print("\n🧪 TESTE DA INSTALAÇÃO")
    print("-" * 25)
    
    # Teste Python
    python_test = (
        "from sdic_libraries.data_access.emprego import Emprego; "
        "api = Emprego(); "
        "print('Biblioteca Python funcionando!'); "
        "api.close()"
    )
    python_exec = shlex.quote(sys.executable)
    python_test_quoted = shlex.quote(python_test)

    success, _ = run_command(
        f"cd python && {python_exec} -c {python_test_quoted}",
        "Testando importação Python"
    )
    
    if success:
        print("🎉 Python: TODOS OS TESTES PASSARAM")
    else:
        print("⚠️ Python: Alguns problemas detectados")
    
    return success


def create_sample_env():
    """Cria arquivo .env de exemplo"""
    env_content = """# Configuração pública da API SDIC (sem segredos)
# Segredos (ex.: EMPLOYMENT_API_KEY) vão SOMENTE em .env.local (ignorado pelo git).
EMPLOYMENT_API_BASE_URL=https://sdicapi.dados.ninja
# API_TIMEOUT=30
# LOG_LEVEL=INFO
# SDIC_VERSION=0.3.1"""
    
    env_files = [".env.example", "python/.env.example", "r/.env.example"]
    
    for env_file in env_files:
        env_path = Path(env_file)
        if not env_path.exists():
            env_path.parent.mkdir(exist_ok=True, parents=True)
            env_path.write_text(env_content)
            print(f"📄 Criado: {env_file}")


def main():
    """Função principal"""
    banner()
    
    # Detectar ambiente
    env_info = detect_environment()
    
    # Instalar Python (obrigatório)
    print("\n" + "🐍" * 20)
    python_success = install_python_dependencies()
    
    # Instalar R (se disponível)
    r_success = True
    if env_info['r_available']:
        print("\n" + "📊" * 20)
        r_success = install_r_dependencies()
    else:
        print("\n❌ R não disponível - pulando instalação R")
    
    # Criar arquivos de configuração
    print("\n📁 CRIANDO ARQUIVOS DE CONFIGURAÇÃO")
    print("-" * 35)
    create_sample_env()
    
    # Testar instalação
    test_success = test_installation()
    
    # Resumo final
    print("\n" + "🎯" * 30 + "\n")
    print("             RESUMO DA INSTALAÇÃO")
    print("-" * 50)
    print(f"🐍 Python:      {'✅ SUCESSO' if python_success else '❌ FALHOU'}")
    print(f"📊 R:           {'✅ SUCESSO' if r_success else '❌ FALHOU' if env_info['r_available'] else '➖ N/A'}")
    print(f"🧪 Testes:      {'✅ SUCESSO' if test_success else '❌ FALHOU'}")
    
    if python_success and test_success:
        print(f"\n🎉 INSTALAÇÃO COMPLETA! Biblioteca SDIC pronta para uso!")
        print("\n📖 Próximos passos:")
        print("   1. Consulte README.md para documentação completa")
        print("   2. Execute exemplos em python/examples/ e r/examples/")  
        print("   3. Configure .env (opcional) com suas credenciais")
        print("\n💡 Uso rápido Python:")
        print("   from sdic_libraries.data_access.emprego import Emprego")
        print("   api = Emprego(); dados = api.get_saldo_emprego_detalhado('nacional')")
        print("\n💡 Uso rápido R:")
        print("   source('r/R/data_access/emprego.R')")
        print("   api <- Emprego$new(); dados <- api$get_saldo_emprego_detalhado('nacional')")
    else:
        print(f"\n⚠️ Instalação com problemas. Consulte mensagens de erro acima.")
        print("   Tente executar install.py ou install.R individualmente.")


if __name__ == "__main__":
    main()