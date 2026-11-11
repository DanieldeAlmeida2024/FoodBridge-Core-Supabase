import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]

class TestesDocumentacao(unittest.TestCase):
    def test_documentos_basicos(self):
        for arquivo in ('README.md','AGENTS.md','docs/REQUISITOS.md','docs/ARQUITETURA.md','docs/UML.puml','docs/PLANO_TESTES.md'):
            with self.subTest(arquivo=arquivo):
                self.assertTrue((RAIZ / arquivo).is_file(), arquivo)

    def test_diagrama_delimitado(self):
        conteudo = (RAIZ / 'docs/UML.puml').read_text(encoding='utf-8')
        self.assertIn('@startuml', conteudo)
        self.assertIn('@enduml', conteudo)
