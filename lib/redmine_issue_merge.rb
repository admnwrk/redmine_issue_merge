# frozen_string_literal: true

module RedmineIssueMerge
  # Unsichtbarer Marker am Anfang einer Merge-Notiz, aus Unicode
  # Wortzwischenraum-Zeichen (U+2063 INVISIBLE SEPARATOR) statt Prozentzeichen.
  # "%%MERGE%%" hat in CommonMark keine Sonderbedeutung, wird aber in Textile
  # als Span-Syntax "%(...)...%"' interpretiert (die inneren % werden
  # konsumiert), sodass am Ende ein sichtbares "%MERGE%" uebrig bleibt. Die
  # U+2063-Variante hat in KEINEM der beiden Formatter eine Sonderbedeutung
  # und bleibt zudem unsichtbar, selbst falls die JS-Entfernung fehlschlaegt.
  # Er wird beim Anzeigen per JavaScript entfernt und der Eintrag in die
  # CSS-Box gehuellt (siehe hooks.rb). Dieser Weg ist unabhaengig davon,
  # ueber welchen internen Render-Pfad Redmine die Notiz ausgibt.
  MARKER = "⁣⁣MERGE⁣⁣"
end

require_relative 'redmine_issue_merge/hooks'
