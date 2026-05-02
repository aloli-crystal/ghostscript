module Ghostscript
  # Résultat d'une opération de compression PDF via `gs`.
  #
  # Contient :
  # * Les codes de retour et flux du process (`exit_code`, `stdout`,
  #   `stderr`) pour le diagnostic.
  # * Les tailles avant/après pour le calcul du gain.
  # * Un helper `reduction_percent` et un `to_s` formaté.
  struct Result
    getter exit_code : Int32
    getter stdout : String
    getter stderr : String
    getter input_size : Int64
    getter output_size : Int64

    def initialize(
      @exit_code : Int32,
      @stdout : String,
      @stderr : String,
      @input_size : Int64,
      @output_size : Int64,
    )
    end

    def success? : Bool
      @exit_code == 0 && @output_size > 0
    end

    # Pourcentage de réduction (peut être négatif si la sortie est
    # plus grosse que l'entrée, cas rare mais possible si le PDF
    # d'entrée utilisait déjà une compression plus efficace que ce
    # que `gs` produit pour ce preset).
    def reduction_percent : Float64
      return 0.0 if @input_size == 0
      (1.0 - @output_size.to_f64 / @input_size.to_f64) * 100.0
    end

    def to_s(io : IO) : Nil
      io << format_size(@input_size) << " → " << format_size(@output_size)
      io << " (" << ("%.1f" % reduction_percent) << " %)"
    end

    private def format_size(bytes : Int64) : String
      kb = bytes / 1024.0
      return "%.1f Ko" % kb if kb < 1024
      "%.2f Mo" % (kb / 1024.0)
    end
  end
end
