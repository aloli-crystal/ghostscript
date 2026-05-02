module Ghostscript
  # Presets de qualité de compression PDF correspondant aux valeurs
  # `-dPDFSETTINGS=...` de Ghostscript.
  #
  # Documentation amont :
  # https://ghostscript.readthedocs.io/en/latest/VectorDevices.html#pdfwrite
  enum Quality
    # 72 dpi, plus petite taille — lecture écran uniquement
    Screen
    # 150 dpi — défaut, bon compromis taille/qualité
    Ebook
    # 300 dpi — impression bureautique
    Printer
    # 300 dpi, color-preserving — impression professionnelle
    Prepress
    # Laisse `gs` choisir (généralement équivalent à `:ebook`)
    Default

    # Convertit le preset en valeur attendue par `-dPDFSETTINGS=...`.
    def gs_setting : String
      case self
      in Screen   then "/screen"
      in Ebook    then "/ebook"
      in Printer  then "/printer"
      in Prepress then "/prepress"
      in Default  then "/default"
      end
    end

    # Construit un `Quality` depuis un Symbol (idiomatique Crystal) :
    # `:screen`, `:ebook`, `:printer`, `:prepress`, `:default`. Lève
    # `ArgumentError` pour une valeur inconnue.
    def self.from_symbol(sym : Symbol) : Quality
      case sym
      when :screen   then Screen
      when :ebook    then Ebook
      when :printer  then Printer
      when :prepress then Prepress
      when :default  then Default
      else
        raise ArgumentError.new(
          "Unknown quality symbol :#{sym}. Expected one of :screen, :ebook, :printer, :prepress, :default."
        )
      end
    end

    # Construit un `Quality` depuis une String (utile pour parser les
    # flags CLI). Lève `ArgumentError` pour une valeur inconnue.
    def self.parse(name : String) : Quality
      case name.downcase
      when "screen"   then Screen
      when "ebook"    then Ebook
      when "printer"  then Printer
      when "prepress" then Prepress
      when "default"  then Default
      else
        raise ArgumentError.new(
          "Unknown quality '#{name}'. Expected one of: screen, ebook, printer, prepress, default."
        )
      end
    end
  end
end
