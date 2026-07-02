# frozen_string_literal: true

module RedmineIssueMerge
  # Unsichtbarer Marker am Anfang einer Merge-Notiz. Hat in CommonMark KEINE
  # Sonderbedeutung (anders als z. B. [[...]] = Wiki-Link). Er wird beim
  # Anzeigen per JavaScript entfernt und der Eintrag in die CSS-Box gehuellt
  # (siehe hooks.rb). Dieser Weg ist unabhaengig davon, ueber welchen internen
  # Render-Pfad Redmine die Notiz ausgibt.
  MARKER = '%%MERGE%%'
end

require_relative 'redmine_issue_merge/hooks'
