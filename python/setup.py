#!/usr/bin/env python3
"""
Setup.py para instalação da biblioteca SDIC via pip + GitHub
Compatibilidade total com: pip install git+https://github.com/sdic-org/sdic_libraries.git
"""

from setuptools import setup, find_packages
import os
from pathlib import Path

# Ler descrição do README
def read_long_description():
    readme_path = Path(__file__).parent.parent / "README.md"
    if readme_path.exists():
        with open(readme_path, "r", encoding="utf-8") as f:
            return f.read()
    return "Utility libraries for Brazilian employment data access"

# Ler versão do arquivo
def read_version():
    # Tentativa de ler versão do __init__.py ou usar padrão
    try:
        version_file = Path(__file__).parent / "sdic_libraries" / "__init__.py"
        if version_file.exists():
            with open(version_file, "r") as f:
                for line in f:
                    if line.startswith("__version__"):
                        return line.split("=")[1].strip().strip('"').strip("'")
    except:
        pass
    return "0.3.2"

setup(
    name="sdic-libraries",
    version=read_version(),
    author="SDIC Team",
    author_email="sdic.dados@mdic.gov.br",
    description="Utility libraries for Brazilian employment balance data access",
    long_description=read_long_description(),
    long_description_content_type="text/markdown",
    url="https://github.com/sdic-org/sdic_libraries",
    project_urls={
        "Bug Reports": "https://github.com/sdic-org/sdic_libraries/issues",
        "Source": "https://github.com/sdic-org/sdic_libraries",
        "Documentation": "https://github.com/sdic-org/sdic_libraries#readme",
    },
    packages=find_packages(),
    package_data={
        "sdic_libraries": ["py.typed"],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Scientific/Engineering :: Information Analysis",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Typing :: Typed",
    ],
    python_requires=">=3.8",
    install_requires=[
        "requests>=2.28.0",
        "pandas>=1.5.0",
        "numpy>=1.24.0",  
        "python-dotenv>=1.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=22.0.0",
            "isort>=5.10.0",
            "flake8>=5.0.0",
            "mypy>=1.0.0",
        ],
        "docs": [
            "sphinx>=5.0.0",
            "sphinx-rtd-theme>=1.0.0",
        ],
    },
    keywords=["employment", "statistics", "brazil", "data-access", "government-data", "emprego"],
    include_package_data=True,
    zip_safe=False,
)