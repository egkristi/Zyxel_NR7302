# backup/

Her legger `scripts/40-zyxel-ta-backup.sh` og fase 6-skriptene backup fra enheten, én mappe per kjøring.

**Innholdet er personlig og kommer aldri med i git** (se `.gitignore`): rå flash-dumper med
eID/ROM-D, fabrikkdata, sertifikater og nøkler, og konfigurasjonsfiler med krypterte passord.

Ta en kopi av hele mappen til et annet sted (minnepenn, sky) etter første backup.
Uten den kan du ikke gå tilbake hvis noe går galt.
