require "option_parser"
require "../ghostscript"

# pdftops — convertit un PDF en PostScript (port Crystal de
# l'utilitaire poppler-utils du même nom).
#
# Contrairement aux autres outils poppler de la suite ALOLI (pdfinfo,
# pdffonts, pdfdetach, pdfimages, pdfattach — natifs dans le shard
# `pdf`), la génération PostScript native serait un chantier
# disproportionné. `pdftops` est donc un **relais ghostscript** : il
# pilote `gs` (device `ps2write` / `eps2write`), cohérent avec la
# stratégie ALOLI de report du rendu (cf. linéarisation via qpdf).
#
# Conventions UX ALOLI (cf. feedback_cli_help_subcommand.md +
# feedback_cli_short_flags.md) : `help [<sub>]` positionnel +
# `-h` / `--help` global ; tout flag long a un short.

usage = <<-USAGE
  Usage : pdftops <fichier.pdf> [<sortie.ps>] [options]
          pdftops help [<sous-commande>]
          pdftops --version | -V

  Options :
    -o, --output FICHIER  Fichier PostScript de sortie
    -f, --first N         Première page à convertir
    -l, --last N          Dernière page à convertir
    -e, --eps             Produire de l'EPS (device eps2write)
    -L, --level N         Niveau PostScript (2 ou 3 ; défaut 2)
    -p, --password MDP    Mot de passe du document chiffré
    -V, --version         Affiche la version
    -h, --help            Affiche cette aide

  Convertit un PDF en PostScript via ghostscript (`gs`). Nécessite un
  `gs` installé et accessible dans le PATH. La sortie par défaut est
  <fichier>.ps (ou .eps avec --eps).
  USAGE

output : String? = nil
first_page : Int32? = nil
last_page : Int32? = nil
eps = false
level = 2
password : String? = nil

parser = OptionParser.new do |op|
  op.banner = usage
  op.on("-o FICHIER", "--output FICHIER", "Output PostScript file") { |v| output = v }
  op.on("-f N", "--first N", "First page") { |v| first_page = v.to_i? }
  op.on("-l N", "--last N", "Last page") { |v| last_page = v.to_i? }
  op.on("-e", "--eps", "Produce EPS") { eps = true }
  op.on("-L N", "--level N", "PostScript level (2 or 3)") { |v| level = v.to_i? || 2 }
  op.on("-p MDP", "--password MDP", "Document password") { |v| password = v }
  op.on("-V", "--version", "Show version") do
    puts "pdftops #{Ghostscript::VERSION}"
    exit 0
  end
  op.on("-h", "--help", "Show this help") do
    puts usage
    exit 0
  end
  op.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts usage
    exit 1
  end
end

positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

# Convention ALOLI : `help [<sous-commande>]` positionnel.
if !positional.empty? && positional.first == "help"
  puts usage
  exit 0
end

if positional.empty?
  STDERR.puts "Erreur : aucun fichier PDF spécifié."
  STDERR.puts usage
  exit 1
end

input = positional[0]

unless File.exists?(input)
  STDERR.puts "Erreur : fichier introuvable : #{input}"
  exit 2
end

unless Ghostscript.available?
  STDERR.puts "Erreur : `gs` (ghostscript) introuvable dans le PATH."
  STDERR.puts "  Installez-le (`brew install ghostscript`, `apt install ghostscript`…)."
  exit 5
end

# Déterminer la sortie : -o, sinon 2e positionnel, sinon <base>.<ext>.
ext = eps ? "eps" : "ps"
out_opt = output
positional_out = positional[1]?
dest = out_opt || positional_out || begin
  base_ext = File.extname(input)
  base = input[0, input.size - base_ext.size]
  "#{base}.#{ext}"
end

result = Ghostscript.to_postscript(
  input, dest,
  first_page: first_page,
  last_page: last_page,
  eps: eps,
  level: level,
  password: password,
)

unless result.success?
  STDERR.puts "Erreur : la conversion ghostscript a échoué (code #{result.exit_code})."
  STDERR.puts result.stderr unless result.stderr.empty?
  exit 3
end

puts "PostScript écrit → #{dest}"
