require "./spec_helper"

describe "Ghostscript.to_postscript" do
  it "convertit un PDF en PostScript (device ps2write)" do
    pending! "gs not installed" unless Ghostscript.available?

    input = File.join(SpecHelper::TMP_DIR, "in.pdf")
    output = File.join(SpecHelper::TMP_DIR, "out.ps")
    SpecHelper.write_minimal_pdf(input)

    result = Ghostscript.to_postscript(input, output)
    result.success?.should be_true
    File.exists?(output).should be_true
    File.read(output).should start_with("%!PS-Adobe")
  end

  it "produit de l'EPS avec eps: true et une plage de pages" do
    pending! "gs not installed" unless Ghostscript.available?

    input = File.join(SpecHelper::TMP_DIR, "in2.pdf")
    output = File.join(SpecHelper::TMP_DIR, "out.eps")
    SpecHelper.write_minimal_pdf(input)

    result = Ghostscript.to_postscript(input, output, first_page: 1, last_page: 1, eps: true)
    result.success?.should be_true
    # Un EPS déclare une BoundingBox.
    File.read(output).should contain("%%BoundingBox")
  end

  it "lève si le fichier d'entrée est introuvable" do
    pending! "gs not installed" unless Ghostscript.available?
    expect_raises(Ghostscript::Error, /not found/) do
      Ghostscript.to_postscript("/inexistant.pdf", File.join(SpecHelper::TMP_DIR, "x.ps"))
    end
  end
end
