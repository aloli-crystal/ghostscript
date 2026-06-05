require "./ghostscript/version"
require "./ghostscript/quality"
require "./ghostscript/result"

# Crystal wrapper around the `gs` (Ghostscript) binary.
#
# Pure shell-out via `Process.run` — no FFI, no C bindings. The
# wrapper stays MIT ; only the upstream `gs` binary on disk is
# AGPL-licensed and remains the user's responsibility (same legal
# footing as calling `tar` or `git` from your code).
#
# ```
# # Detection
# Ghostscript.available? # => true / false
# Ghostscript.version    # => "10.04.0" | nil
# Ghostscript.path       # => "/opt/homebrew/bin/gs" | nil
#
# # Typical use
# result = Ghostscript.compress("in.pdf", "out.pdf", quality: :ebook)
# result.success?          # => true
# result.reduction_percent # => 65.3
# puts result              # => "in.pdf: 12.0 Mo → 4.2 Mo (-65.3 %)"
#
# # Low-level escape hatch
# Ghostscript.run([
#   "-sDEVICE=pdfwrite",
#   "-sOutputFile=out.pdf",
#   "-dPDFSETTINGS=/screen",
#   "-dNOPAUSE",
#   "-dBATCH",
#   "in.pdf",
# ])
# ```
module Ghostscript
  extend self

  # Cached path to `gs` (lookup happens once per program run).
  @@cached_path : String?? = nil

  # Returns the absolute path to the `gs` executable, or `nil` if
  # not found in `$PATH`. Result is memoised — call `reset_cache!`
  # to force a fresh lookup.
  def path : String?
    @@cached_path ||= Process.find_executable("gs")
  end

  # Returns `true` when a usable `gs` binary is installed.
  def available? : Bool
    !path.nil?
  end

  # Returns the parsed version string (e.g. `"10.04.0"`), or `nil`
  # if `gs` is not installed or its `-v` output can't be parsed.
  #
  # `gs -v` typically prints :
  #
  # ```
  # GPL Ghostscript 10.04.0 (2024-09-18)
  # ...
  # ```
  def version : String?
    bin = path
    return nil unless bin
    stdout_buf = IO::Memory.new
    stderr_buf = IO::Memory.new
    status = Process.run(bin, ["-v"], output: stdout_buf, error: stderr_buf)
    return nil unless status.success?
    text = stdout_buf.to_s
    return nil if text.empty?
    if md = text.match(/Ghostscript\s+([\d.]+)/i)
      md[1]
    end
  end

  # Vide le cache du chemin `gs` (utile pour les tests qui modifient
  # `$PATH` à la volée).
  def reset_cache! : Nil
    @@cached_path = nil
  end

  # Compresse un PDF en réduisant la résolution des images et en
  # ré-encodant les flux selon le preset `quality` :
  #
  # * `:screen`   — 72 dpi, plus petite taille (lecture écran)
  # * `:ebook`    — 150 dpi, défaut (bon compromis taille/qualité)
  # * `:printer`  — 300 dpi (impression bureautique)
  # * `:prepress` — 300 dpi, color-preserving (impression pro)
  # * `:default`  — laisse `gs` choisir (rare ; généralement = ebook)
  #
  # Lève `Error` si `gs` n'est pas installé ou si l'invocation
  # échoue. La sortie est toujours un PDF valide quand `Result#success?`.
  def compress(input : String, output : String, quality : Quality | Symbol = :ebook) : Result
    raise Error.new("Ghostscript binary `gs` not found in PATH") unless available?
    raise Error.new("Input file not found: #{input}") unless File.exists?(input)

    q = quality.is_a?(Symbol) ? Quality.from_symbol(quality) : quality
    args = [
      "-sDEVICE=pdfwrite",
      "-dCompatibilityLevel=1.7",
      "-dPDFSETTINGS=#{q.gs_setting}",
      "-dNOPAUSE",
      "-dQUIET",
      "-dBATCH",
      "-sOutputFile=#{output}",
      input,
    ]

    input_size = File.size(input).to_i64
    res = run(args)
    output_size = File.exists?(output) ? File.size(output).to_i64 : 0_i64

    Result.new(
      exit_code: res.exit_code,
      stdout: res.stdout,
      stderr: res.stderr,
      input_size: input_size,
      output_size: output_size,
    )
  end

  # Convertit un PDF en PostScript via le device `ps2write` (ou
  # `eps2write` quand `eps: true`). C'est le moteur de l'utilitaire
  # `pdftops` : une génération PostScript native serait disproportionnée,
  # on délègue donc à `gs`.
  #
  # * `first_page` / `last_page` — plage de pages (1-based), optionnelle.
  # * `eps` — produit de l'EPS plutôt que du PostScript multipage.
  # * `level` — niveau PostScript (2 ou 3 ; toute autre valeur → 2).
  # * `password` — mot de passe du document chiffré, le cas échéant.
  #
  # Lève `Error` si `gs` est absent ou l'entrée introuvable. La sortie
  # est un PostScript valide quand `Result#success?`.
  def to_postscript(
    input : String,
    output : String,
    first_page : Int32? = nil,
    last_page : Int32? = nil,
    eps : Bool = false,
    level : Int32 = 2,
    password : String? = nil,
  ) : Result
    raise Error.new("Ghostscript binary `gs` not found in PATH") unless available?
    raise Error.new("Input file not found: #{input}") unless File.exists?(input)

    device = eps ? "eps2write" : "ps2write"
    args = [
      "-q", "-dNOPAUSE", "-dBATCH", "-dSAFER",
      "-sDEVICE=#{device}",
      "-dLanguageLevel=#{level == 3 ? 3 : 2}",
      "-sOutputFile=#{output}",
    ]
    args << "-dFirstPage=#{first_page}" if first_page
    args << "-dLastPage=#{last_page}" if last_page
    args << "-sPDFPassword=#{password}" if password
    args << input

    input_size = File.size(input).to_i64
    res = run(args)
    output_size = File.exists?(output) ? File.size(output).to_i64 : 0_i64

    Result.new(
      exit_code: res.exit_code,
      stdout: res.stdout,
      stderr: res.stderr,
      input_size: input_size,
      output_size: output_size,
    )
  end

  # Bas-niveau : invoque `gs` avec les arguments donnés. Retourne
  # un `RunResult` avec `exit_code`, `stdout`, `stderr`. N'effectue
  # AUCUN traitement de fichier (taille, validation) — utile quand
  # vous appelez `gs` pour autre chose que la compression PDF.
  def run(args : Array(String)) : RunResult
    bin = path
    raise Error.new("Ghostscript binary `gs` not found in PATH") unless bin
    stdout_buf = IO::Memory.new
    stderr_buf = IO::Memory.new
    status = Process.run(bin, args, output: stdout_buf, error: stderr_buf)
    RunResult.new(status.exit_code, stdout_buf.to_s, stderr_buf.to_s)
  end

  # Erreur levée par les méthodes du module quand `gs` n'est pas
  # disponible ou qu'une invocation échoue de manière irrécupérable.
  class Error < Exception
  end

  # Retour brut d'un appel `gs` (sans traitement de fichier).
  struct RunResult
    getter exit_code : Int32
    getter stdout : String
    getter stderr : String

    def initialize(@exit_code : Int32, @stdout : String, @stderr : String)
    end

    def success? : Bool
      @exit_code == 0
    end
  end
end
