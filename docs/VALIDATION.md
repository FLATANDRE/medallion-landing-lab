# Validação do pacote

O pacote passa por verificação estática de sintaxe Python, leitura do YAML, integridade dos dados de demonstração e hashes SHA-256. A integração Docker deve ser executada na máquina do usuário com `bash scripts/smoke-test.sh`.

O catálogo REST usa a fixture comunitária do Apache Iceberg, adequada ao exercício local. O laboratório não implementa alta disponibilidade, autenticação do catálogo, TLS, antivírus, classificação de dados sensíveis nem retenção de produção.
