"""Validação mínima de índice documental, links locais e fontes PlantUML."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOCS = [
    "README.md", "docs/projeto/ESPECIFICACAO.md", "docs/projeto/RISCOS.md",
    "docs/testes/PLANO_DE_TESTES.md", "docs/controle/VERSIONAMENTO.md",
    "docs/uml/README.md", "docs/seguranca/PERFIS_AUTORIZACAO.md",
]
UMLS = [
    "docs/uml/01_componentes.puml", "docs/uml/02_sequencia.puml",
    "docs/uml/03_sequencia_autorizacao_admin.puml",
    "docs/uml/04_migracao_rls_perfis.puml",
]

class DocumentacaoReproduzivel(unittest.TestCase):
    def test_existem_documentos_individuais(self):
        for path in DOCS:
            with self.subTest(path=path):
                self.assertTrue((ROOT / path).is_file(), path)

    def test_fontes_plantuml_sintaticamente_delimitadas(self):
        for path in UMLS:
            text = (ROOT / path).read_text(encoding="utf-8")
            with self.subTest(path=path):
                self.assertIn("@startuml", text)
                self.assertIn("@enduml", text)

    def test_links_relativos_dos_indices(self):
        for path in ("README.md", "docs/uml/README.md"):
            text = (ROOT / path).read_text(encoding="utf-8")
            for destination in re.findall(r"\]\(([^)]+)\)", text):
                if destination.startswith(("http:", "https:", "#")):
                    continue
                with self.subTest(source=path, destination=destination):
                    self.assertTrue((ROOT / path).parent.joinpath(destination).exists())

if __name__ == "__main__":
    unittest.main()
