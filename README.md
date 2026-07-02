# Redmine Issue Merge

Fuehrt ein Duplikat-Ticket in ein bestehendes Ticket ueber – gedacht fuer den
Dispatch-Workflow, wenn eine Mail ohne `[#Ticketnummer]` im Betreff ein zweites
Ticket zum selben Thema erzeugt hat.

Getestet gegen Redmine 6.1.x (Ruby 3.4 / Rails 7.2), CommonMark als Textformat.

## Was es tut

Beim Ueberfuehren von Quellticket -> Zielticket:

1. **Ein** Journal-Eintrag im Zielticket mit Beschreibung + (optional) allen
   Notizen des Duplikats. Erste Zeile ist eine frei editierbare Kopfzeile
   (Default aus den Einstellungen, z. B. `Eintrag/Merge aus Duplikat #123`).
   Der Eintrag wird in einem konfigurierbaren CSS-Kasten dargestellt.
2. **Anhaenge** werden vom Duplikat ins Zielticket umgehaengt (nur der
   Datenbank-Fremdschluessel wandert, die Dateien bleiben unberuehrt).
3. Beziehung **"Duplikat von"** zwischen Duplikat und Zielticket.
4. Das Duplikat wird **geschlossen** (nicht geloescht) und erhaelt einen
   Rueckverweis im Journal – so kann man jederzeit nachschauen.

Keine Schema-Migration, kein manuelles SQL, keine Aenderung an Redmine-Core-
Dateien. Es werden ausschliesslich die normalen Models verwendet.

## Wie der CSS-Kasten funktioniert

Redmine sanitized jede Journal-Notiz beim Anzeigen; Inline-HTML mit `style`
wuerde entfernt. Das Plugin loest das per JavaScript: ein kleines Skript wird
in den Seitenkopf injiziert (Hook `view_layouts_base_html_head`), findet die
Notiz an einem unsichtbaren Marker (`%%MERGE%%`) am Notizanfang, entfernt den
Marker und setzt die Klasse `redmine-merge-box` auf den Notiz-Container. Das
zugehoerige CSS (border/padding/background-color/color aus den
Plugin-Einstellungen) kommt aus demselben Hook. Dieser Weg ist unabhaengig
davon, ueber welchen internen Render-Pfad Redmine die Notiz ausgibt (in 6.1
wurde das mehrfach umgebaut).

## Installation (Docker-Volume-Mount)

Ordner `redmine_issue_merge` nach `plugins/` mounten/kopieren, dann:

    docker compose exec redmine bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    docker compose restart redmine

(Eine Migration existiert nicht; der Migrate-Task ist nur Konvention und
schadet nicht.) Anschliessend unter
**Administration -> Rollen** die Berechtigung *"Tickets zusammenfuehren"*
den gewuenschten Rollen geben und unter
**Administration -> Plugins -> Konfiguration** Kasten-Stil, Kopfzeilen-Vorlage
und Schliess-Status setzen.

## Benutzung

Auf der Ticketseite des Duplikats unten den Link **"In Ticket ueberfuehren"**
oeffnen, Zielticketnummer eingeben, Kopfzeile ggf. anpassen, absenden.

## Hinweise / Grenzen

- Die Mailverlaeufe werden 1:1 als Text uebernommen (keine Datumssortierung,
  bewusst so gewollt). Reihenfolge = chronologisch nach Erstellung.
- Inline im Quelltext per Dateiname referenzierte Bilder verlinken nach dem
  Umhaengen weiterhin korrekt, da die Anhaenge nun am Zielticket haengen.
- Der Merge ist in eine Transaktion gekapselt: schlaegt ein Schritt fehl
  (z. B. Pflichtfeld beim Schliessen), wird nichts veraendert.
- Das Schliessen des Duplikats respektiert eure Workflow-Pflichtfelder. Wenn
  euer Workflow beim Schliessen Felder erzwingt, kann der Merge daran
  scheitern – dann Pflichtfelder lockern oder Status entsprechend waehlen.
