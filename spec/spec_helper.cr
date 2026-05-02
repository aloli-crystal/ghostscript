require "spec"
require "file_utils"
require "../src/ghostscript"

module SpecHelper
  TMP_DIR = File.join(__DIR__, "tmp")

  # Construit un PDF minimal valide (1 page A4, texte court) pour
  # les tests d'intégration. Pas de génération via une lib PDF —
  # un PDF 1.4 hand-rolled suffit pour `gs`.
  def self.write_minimal_pdf(path : String) : Nil
    Dir.mkdir_p(File.dirname(path))
    File.write(path, MINIMAL_PDF)
  end

  MINIMAL_PDF = <<-PDF
    %PDF-1.4
    1 0 obj
    <</Type/Catalog/Pages 2 0 R>>
    endobj
    2 0 obj
    <</Type/Pages/Kids[3 0 R]/Count 1>>
    endobj
    3 0 obj
    <</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>
    endobj
    4 0 obj
    <</Length 44>>
    stream
    BT /F1 24 Tf 100 700 Td (Hello Ghostscript) Tj ET
    endstream
    endobj
    5 0 obj
    <</Type/Font/Subtype/Type1/BaseFont/Helvetica>>
    endobj
    xref
    0 6
    0000000000 65535 f
    0000000009 00000 n
    0000000056 00000 n
    0000000099 00000 n
    0000000192 00000 n
    0000000284 00000 n
    trailer
    <</Size 6/Root 1 0 R>>
    startxref
    340
    %%EOF
    PDF
end

at_exit do
  FileUtils.rm_rf(SpecHelper::TMP_DIR) if Dir.exists?(SpecHelper::TMP_DIR)
end
