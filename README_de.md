# Redmine Issue Merge

Führt ein Duplikat-Ticket in ein bestehendes Ticket über – gedacht für den
Dispatch-Workflow, wenn eine Mail ohne `[#Ticketnummer]` im Betreff ein zweites
Ticket zum selben Thema erzeugt hat.

Getestet gegen Redmine 6.1.x (Ruby 3.4 / Rails 7.2), CommonMark als Textformat.

> English version: siehe [README.md](README.md).

## Was es tut

Beim Überführen von Quellticket → Zielticket:

1. **Ein** Journal-Eintrag im Zielticket mit Beschreibung + (optional) allen
   Notizen des Duplikats. Die erste Zeile ist eine frei editierbare Kopfzeile
   (Default aus den Einstellungen, z. B. `Eintrag/Merge aus Duplikat #123`).
   Der Eintrag wird in einem konfigurierbaren CSS-Kasten dargestellt.
2. **Anhänge** werden vom Duplikat ins Zielticket umgehängt (nur der
   Datenbank-Fremdschlüssel wandert, die Dateien bleiben unberührt).
3. Beziehung **„Dupliziert durch"** zwischen Duplikat und Zielticket.
4. Das Duplikat wird **geschlossen** (nicht gelöscht) und erhält einen
   Rückverweis im Journal – so kann man jederzeit nachschauen.

**Hinweis**: Der Inhalt des Duplikats wird nicht zeitlich zwischensortiert.

Keine Schema-Migration, kein manuelles SQL, keine Änderung an
Redmine-Core-Dateien. Es werden ausschließlich die normalen Models verwendet.

## Installation (Docker-Volume-Mount)

`git clone` das `redmine_issue_merge` Repository nach `plugins/` kopiere das
Package dorthin, dann:

```bash
docker compose exec redmine-container-name \
  bundle exec rake redmine:plugins:migrate RAILS_ENV=production
docker compose restart redmine-container-name
```

Es existiert keine Migration; der Migrate-Task ist nur Konvention und schadet
nicht. Entscheidend ist der Restart, damit der Plugin-Code geladen wird.
Ein `bundle install` ist nicht nötig (keine zusätzlichen Gems).

## Konfiguration

Nach dem Restart zwei Dinge einstellen:

**1. Berechtigung** unter **Administration → Rollen und Rechte**: Den Rollen,
die mergen dürfen, das Recht **„Tickets zusammenführen"** geben. Ohne dieses
Recht erscheint der Aktionslink nicht.

**2. Plugin-Einstellungen** unter **Administration → Plugins → Konfiguration**
(beim Plugin „Redmine Issue Merge"):

<!-- Screenshot der Konfigurationsseite -->
![Plugin-Konfiguration](doc/configuration.png)

| Einstellung | Bedeutung |
|---|---|
| **Vorlage Kopfzeile** | Default-Text der ersten Zeile des Merge-Eintrags. Platzhalter `%{source}` wird durch die Nummer des Duplikats ersetzt. Beim Merge im Formular noch überschreibbar. |
| **Notizen des Duplikats mit übernehmen** | Wenn aktiv, werden alle Notizen (Mailverlauf) des Duplikats in den Eintrag aufgenommen. Wenn inaktiv, nur die Beschreibung. |
| **Status für geschlossenes Duplikat** | Status, der beim Überführen auf das Duplikat gesetzt wird (Auswahl nur aus geschlossenen Status). Tipp: eigenen geschlossenen Status „Dupliziert" anlegen. |
| **border** | CSS-Rahmen des Kastens, z. B. `1px solid #c9a227`. |
| **padding** | CSS-Innenabstand, z. B. `10px 12px`. |
| **background-color** | Hintergrundfarbe, z. B. `#fff8e1`. |
| **color** | Textfarbe, z. B. `#1a1a1a`. |

## Benutzung

![Dialog Zusammenführung](doc/merge-dialog.png)

Auf der Ticketseite des **Duplikats** in der Aktionsleiste (oben
und unten, jeweils vor dem „Mehr"-Menü), den Link **„In anderes Ticket
überführen"** anklicken. Zielticketnummer eingeben, Kopfzeile ggf. anpassen,
absenden. Das Duplikat wird geschlossen, der Inhalt landet im Zielticket.

## Wie der CSS-Kasten funktioniert

Redmine sanitized jede Journal-Notiz beim Anzeigen; Inline-HTML mit `style`
würde entfernt. Das Plugin löst das per JavaScript: Ein kleines Skript wird in
den Seitenkopf injiziert (Hook `view_layouts_base_html_head`), findet die Notiz
an einem unsichtbaren Marker (zwei Unicode-Zeichen U+2063 um `MERGE`) am
Notizanfang, entfernt den Marker
und setzt die Klasse `redmine-merge-box` auf den Notiz-Container. Das zugehörige
CSS (border/padding/background-color/color aus den Einstellungen) kommt aus
demselben Hook. Dieser Weg ist unabhängig davon, über welchen internen
Render-Pfad Redmine die Notiz ausgibt (in 6.1 mehrfach umgebaut).

Das Icon nutzt Redmines `sprite_icon` (Inline-SVG), damit es wie die übrigen 
Aktionlinks aussieht.

## Hinweise / Grenzen

- Ab v1.3.0 ist **Bearbeitungsrecht (`edit_issues`) auf beiden Projekten** nötig – 
  dem des Duplikats und dem des Zieltickets. Private Notizen des Duplikats werden 
  bewusst **nicht** übernommen.
- Die Mailverläufe werden 1:1 als Text übernommen (keine Datumssortierung,
  bewusst so gewollt). Reihenfolge = chronologisch nach Erstellung.
- Inline per Dateiname referenzierte Bilder verlinken nach dem Umhängen
  weiterhin korrekt, da die Anhänge nun am Zielticket hängen.
- Der Merge ist in eine Transaktion gekapselt: Schlägt ein Schritt fehl
  (z. B. Pflichtfeld beim Schließen), wird nichts verändert.
- Das Schließen des Duplikats respektiert Workflow-Pflichtfelder. Erzwingt
  ein Workflow beim Schließen Felder, kann der Merge daran scheitern – dann
  die Pflichtfelder lockern oder passenden Status wählen.
- Die Kasten-Darstellung und der contextual-Link benötigen aktiviertes
  JavaScript. Der eigentliche Merge (Datenübernahme) läuft rein serverseitig.

## Deinstallation

Plugin-Ordner entfernen und Redmine neu starten. Da keine Migration existiert,
sind keine DB-Schritte nötig. Bereits erfolgte Merges bleiben erhalten; der
unsichtbare Marker wird dann nicht mehr per JavaScript entfernt, bleibt aber
wegen der unsichtbaren Unicode-Zeichen unsichtbar am Anfang der jeweiligen
Notiz.
