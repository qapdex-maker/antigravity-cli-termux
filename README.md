<p align="center">
  <img src="https://antigravity.google/assets/image/product/antigravity-cli/hero.png" alt="Antigravity CLI" width="100%">
</p>

# Antigravity CLI - Termux Native

**Für die Interaktion mit autonomen Coding-Agenten in Termux.** 

Bleibe im Flow, ohne den Kontext zu wechseln. Die Antigravity CLI bringt die Core-Funktionalitäten von Antigravity 2.0 – wie mehrstufige Logikketten, paralleles Bearbeiten mehrerer Dateien und asynchrone Subagenten – direkt in dein Terminal. Entwickelt für Tastatur-zentrierte Workflows, Entwickler-Geschwindigkeit und Remote-SSH-Sitzungen mit minimalem Overhead.

---

## ✨ Hauptmerkmale

* **Natürliche Sprache**: Steuere, editiere und baue deine gesamte Codebasis rein über Chat-Prompts direkt in der Shell.
* **Asynchrone Workflows**: Starte rechenintensive Aufgaben (wie Refactoring oder Deep Research) im Hintergrund, ohne dein aktives Terminal zu blockieren.
* **Werkzeug-Berechtigungen**: Volle Kontrolle über die Sandbox. Entscheide selbst, wie viel Autonomie du deinen Agenten für Systemzugriffe gewährst.
* **Nahtlose Ökosystem-Synchronisation**: Exportiere komplexe Terminal-Sitzungen bei Bedarf mit nur einem Befehl in die Antigravity 2.0 Desktop-GUI.

---

##  Installation

```bash
git clone https://github.com/qapdex-maker/antigravity-cli-termux
cd antigravity-cli-termux
chmod +x install.sh
./install.sh
```

---

## 🛠️ Erste Schritte

   **Authentifizierung**: Antigravity startet nach der Installation automatisch und meldet dich über OAuth sicher mit deinem Google-Konto an
   ```bash
   agy --help

Available subcommands:
  changelog       Show changelog and release notes
  help            Show help for subcommands
  install         Configure environment paths and shell settings
  models          List available models
  plugin          Manage plugins (install, uninstall, list, enable, disable)
  plugins         Alias for plugin
  update          Update CLI
   ```
---

## 🤝 Beitragen

Wir freuen uns über Community-Erweiterungen (Custom Agent Skills, MCP-Server-Anbindungen)! 
1. Forke dieses Repository.
2. Erstelle deine Workflows basierend auf unseren [offiziellen Styleguides](https://antigravity.google/docs).
3. Reiche einen Pull Request ein.

---

<p align="center">
  <sub>Built with ❤️ </sub>
</p>
