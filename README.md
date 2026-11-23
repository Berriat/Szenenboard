# Szenenboard

Browser-Tool für die szenische Grundstruktur eines Drehbuchs: Hauptstory als Fließtext, Szenenboard mit Verbindungen (therefore / because / but), Figuren, Projekte mit Versionen und PDF-Export.

Eine einzige statische Datei (`index.html`), kein Server. Läuft über GitHub Pages.

## Speichern

Mit eingerichteter Online-Speicherung (Supabase) landen alle Projekte in einer gemeinsamen Datenbank: Login per E-Mail-Link, alle Team-Mitglieder sehen denselben Stand live, frühere Stände lassen sich über **Verlauf** zurückholen. Eine Kopie bleibt zusätzlich im Browser, damit man auch offline weiterarbeiten kann.

Ohne Online-Speicherung liegen die Daten nur im Browser des Geräts. Über **Sichern** bekommst du eine JSON-Datei als Backup, über **Laden** holst du sie wieder zurück.

## Online-Speicherung einrichten (Supabase)

1. In Supabase im **SQL Editor** den Inhalt von `supabase.sql` einfügen, unten die E-Mail-Adressen des Teams eintragen und **Run** klicken.
2. Unter **Authentication → URL Configuration** die Adresse der Seite als **Site URL** eintragen und zusätzlich unter **Redirect URLs** hinzufügen.
3. In `index.html` bei `const CLOUD = { url: '', key: '' }` die Project URL und den Publishable (anon) Key eintragen.

Weitere Personen fügt man danach direkt im Tool hinzu: Klick auf den Speicher-Status neben dem Projektnamen → Team.

## GitHub Pages einschalten

Settings → Pages → Source: „Deploy from a branch“, Branch `main`, Ordner `/ (root)`.
