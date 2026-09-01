# Erstveröffentlichung auf GitHub

## 1. Leeres Repository anlegen

Auf GitHub ein neues öffentliches Repository mit dem Namen `seifert-security-reader` erstellen. Beim Anlegen keine zusätzliche README-, `.gitignore`- oder Lizenzdatei erzeugen, da diese Dateien bereits lokal vorhanden sind.

## 2. Git-Identität festlegen

Falls auf dem Mac noch keine Git-Identität eingerichtet ist:

```bash
git config --global user.name "DEIN NAME"
git config --global user.email "DEINE GITHUB-E-MAIL"
```

Die von GitHub bereitgestellte Noreply-Adresse kann ebenfalls verwendet werden.

## 3. Ersten Commit erstellen

Im Repository-Ordner:

```bash
git commit -m "Release 1.0"
```

Die Dateien sind in der vorbereiteten lokalen Version bereits zum Commit vorgemerkt.

## 4. GitHub verbinden und hochladen

`DEIN-KONTO` durch den eigenen GitHub-Namen ersetzen:

```bash
git remote add origin https://github.com/DEIN-KONTO/seifert-security-reader.git
git push -u origin main
```

## 5. Version 1.0 veröffentlichen

```bash
git tag -a v1.0 -m "seifert-it Security Reader 1.0"
git push origin v1.0
```

Der Tag startet `.github/workflows/release.yml`. GitHub führt die Tests aus, baut das App-Archiv und erstellt daraus automatisch den Release `v1.0`.

## Vor der öffentlichen Freigabe

- Unter **Settings → Security → Code security and analysis** das private Melden von Sicherheitslücken aktivieren.
- Eine Open-Source- oder proprietäre Lizenz auswählen und als `LICENSE` ergänzen.
- Für Downloads ohne Gatekeeper-Warnung eine Apple Developer ID und Notarisierung einrichten.
