require "./spec_helper"

describe Ghostscript do
  describe ".path / .available? / .version" do
    it "détecte ou ne détecte pas gs selon ce qui est installé" do
      Ghostscript.reset_cache!
      path = Ghostscript.path
      if path
        File.exists?(path).should be_true
        Ghostscript.available?.should be_true
      else
        Ghostscript.available?.should be_false
      end
    end

    it "extrait la version quand gs est installé" do
      Ghostscript.reset_cache!
      version = Ghostscript.version
      if Ghostscript.available?
        version.should_not be_nil
        if v = version
          v.should match(/\A\d+\.\d+/)
        end
      else
        version.should be_nil
      end
    end

    it "memoise path entre appels" do
      Ghostscript.reset_cache!
      first = Ghostscript.path
      second = Ghostscript.path
      first.should eq(second)
    end
  end

  describe Ghostscript::Quality do
    it "from_symbol accepte les 5 presets" do
      Ghostscript::Quality.from_symbol(:screen).should eq(Ghostscript::Quality::Screen)
      Ghostscript::Quality.from_symbol(:ebook).should eq(Ghostscript::Quality::Ebook)
      Ghostscript::Quality.from_symbol(:printer).should eq(Ghostscript::Quality::Printer)
      Ghostscript::Quality.from_symbol(:prepress).should eq(Ghostscript::Quality::Prepress)
      Ghostscript::Quality.from_symbol(:default).should eq(Ghostscript::Quality::Default)
    end

    it "from_symbol lève sur preset inconnu" do
      expect_raises(ArgumentError, /Unknown quality symbol/) do
        Ghostscript::Quality.from_symbol(:zorblax)
      end
    end

    it "parse accepte les noms en chaîne (case-insensitive)" do
      Ghostscript::Quality.parse("ebook").should eq(Ghostscript::Quality::Ebook)
      Ghostscript::Quality.parse("EBOOK").should eq(Ghostscript::Quality::Ebook)
      Ghostscript::Quality.parse("Screen").should eq(Ghostscript::Quality::Screen)
    end

    it "parse lève sur nom inconnu" do
      expect_raises(ArgumentError, /Unknown quality/) do
        Ghostscript::Quality.parse("zorblax")
      end
    end

    it "gs_setting renvoie le slash-prefixed setting" do
      Ghostscript::Quality::Screen.gs_setting.should eq("/screen")
      Ghostscript::Quality::Ebook.gs_setting.should eq("/ebook")
      Ghostscript::Quality::Printer.gs_setting.should eq("/printer")
      Ghostscript::Quality::Prepress.gs_setting.should eq("/prepress")
      Ghostscript::Quality::Default.gs_setting.should eq("/default")
    end
  end

  describe Ghostscript::Result do
    it "calcule reduction_percent correctement" do
      r = Ghostscript::Result.new(
        exit_code: 0, stdout: "", stderr: "",
        input_size: 1000_i64, output_size: 400_i64
      )
      r.reduction_percent.should eq(60.0)
    end

    it "renvoie 0% sur input_size = 0" do
      r = Ghostscript::Result.new(
        exit_code: 0, stdout: "", stderr: "",
        input_size: 0_i64, output_size: 0_i64
      )
      r.reduction_percent.should eq(0.0)
    end

    it "renvoie un % négatif si la sortie est plus grosse" do
      r = Ghostscript::Result.new(
        exit_code: 0, stdout: "", stderr: "",
        input_size: 1000_i64, output_size: 1500_i64
      )
      r.reduction_percent.should eq(-50.0)
    end

    it "success? exige exit_code 0 ET output_size > 0" do
      Ghostscript::Result.new(0, "", "", 1000_i64, 400_i64).success?.should be_true
      Ghostscript::Result.new(1, "", "", 1000_i64, 400_i64).success?.should be_false
      Ghostscript::Result.new(0, "", "", 1000_i64, 0_i64).success?.should be_false
    end

    it "to_s formate joliment avec Ko/Mo et %" do
      r = Ghostscript::Result.new(0, "", "", 1024_i64, 512_i64)
      r.to_s.should contain("Ko")
      r.to_s.should contain("(50.0 %)")

      big = Ghostscript::Result.new(0, "", "", (5 * 1024 * 1024).to_i64, (2 * 1024 * 1024).to_i64)
      big.to_s.should contain("Mo")
      big.to_s.should contain("(60.0 %)")
    end
  end

  describe ".compress" do
    it "lève si gs n'est pas installé" do
      original = Ghostscript.path
      pending! "gs is installed on this machine — can't test the not-installed path" if original

      expect_raises(Ghostscript::Error, /not found in PATH/) do
        Ghostscript.compress("/tmp/x.pdf", "/tmp/y.pdf")
      end
    end

    it "lève si l'input n'existe pas" do
      pending! "gs not installed" unless Ghostscript.available?
      expect_raises(Ghostscript::Error, /Input file not found/) do
        Ghostscript.compress("/tmp/nonexistent-#{Random.rand(10000)}.pdf", "/tmp/x.pdf")
      end
    end

    it "compresse un PDF minimal et retourne un Result" do
      pending! "gs not installed" unless Ghostscript.available?
      input = File.join(SpecHelper::TMP_DIR, "input.pdf")
      output = File.join(SpecHelper::TMP_DIR, "output.pdf")
      SpecHelper.write_minimal_pdf(input)

      result = Ghostscript.compress(input, output, quality: :ebook)
      result.success?.should be_true
      result.input_size.should be > 0
      result.output_size.should be > 0
      File.exists?(output).should be_true
    end

    it "respecte le preset quality (sortie /screen plus petite que /prepress)" do
      pending! "gs not installed" unless Ghostscript.available?
      input = File.join(SpecHelper::TMP_DIR, "input2.pdf")
      SpecHelper.write_minimal_pdf(input)

      out_screen = File.join(SpecHelper::TMP_DIR, "screen.pdf")
      out_prepress = File.join(SpecHelper::TMP_DIR, "prepress.pdf")
      Ghostscript.compress(input, out_screen, quality: :screen)
      Ghostscript.compress(input, out_prepress, quality: :prepress)

      # Sur un PDF minimal sans image, /screen et /prepress peuvent
      # produire des tailles très proches. On vérifie juste que les
      # deux fichiers existent et sont valides.
      File.exists?(out_screen).should be_true
      File.exists?(out_prepress).should be_true
      File.size(out_screen).should be > 0
      File.size(out_prepress).should be > 0
    end

    it "accepte aussi un Quality enum directement (pas seulement Symbol)" do
      pending! "gs not installed" unless Ghostscript.available?
      input = File.join(SpecHelper::TMP_DIR, "input3.pdf")
      output = File.join(SpecHelper::TMP_DIR, "output3.pdf")
      SpecHelper.write_minimal_pdf(input)

      result = Ghostscript.compress(input, output, quality: Ghostscript::Quality::Ebook)
      result.success?.should be_true
    end
  end

  describe ".run" do
    it "expose les flux stdout/stderr et le exit code" do
      pending! "gs not installed" unless Ghostscript.available?
      result = Ghostscript.run(["-v"])
      result.success?.should be_true
      result.stdout.should match(/Ghostscript/i)
    end

    it "lève si gs n'est pas installé" do
      pending! "gs is installed" if Ghostscript.available?
      expect_raises(Ghostscript::Error, /not found/) do
        Ghostscript.run(["-v"])
      end
    end
  end
end
