# Impostazioni

ID: `IOS-090`…`099` · Label: `mod:impostazioni` · Parità: `AUTH-001`

Le Impostazioni hanno solo l'accesso. Le sezioni di prima (Aspetto,
Dashboard, Moduli, Navigazione, Formati, Notifiche, Salute, Integrazioni,
Backup, Account) sono uscite con la riscrittura (IOS-100).

## Requisiti

### IOS-090 · Accesso e informazioni

Stato: in corso

Accettazione:

- [ ] In cima l'indirizzo del server e la versione dell'app, scritta dal
      builder nell'`Info.plist` (`0.1.N (N)`).
- [ ] Il service token di Cloudflare Access si incolla e si salva nel
      Portachiavi (IOS-004); si elimina con `Elimina`.
- [ ] Il login di ron1nOS (IOS-019) si fa con la password: `Entra`,
      `Ricorda con Face ID` e `Esci`, come descritto in IOS-019.
- [ ] La riga Login dice: sessione valida, spento, da accedere, sessione
      scaduta.
- [ ] I segreti non si rileggono mai a schermo.
- [ ] Chi era già entrato prima della riscrittura resta entrato: le voci
      del Portachiavi non cambiano.
- [ ] Un pannello Avvisi mostra il permesso di iOS (`consentite`, `negate`,
      `da chiedere`), quanti avvisi dei download sono programmati e fra
      quanto parte il prossimo. `Prova` chiede il permesso se serve e manda
      un avviso fra 10 secondi, per provare gli avvisi in background
      (IOS-075).
