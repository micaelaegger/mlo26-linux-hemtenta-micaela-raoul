# Kartan över hemtentan

> **Dokument från din teammate — lägesbild 6 november 2026.**  
> Detta är en Markdown-formatering av den tidigare delade texten. Planerade steg och dåvarande status har behållits som i originalet; dokumentet är **inte** en uppdaterad statusrapport för servern den 8 november.

Ni ska hyra en dator hos AWS, köra ert API där så att vem som helst kan öppna `https://er-doman/docs`, och på video visa att ni förstår varje steg.

## Innehåll

1. [Du är här](#du-är-här)
2. [Uppgiften, nerbruten](#uppgiften-nerbruten)
3. [Så hänger allt ihop](#så-hänger-allt-ihop)
4. [Vad Docker är](#vad-docker-är)
5. [Docker eller systemd?](#docker-eller-systemd)
6. [Domän, DNS och HTTPS](#domän-dns-och-https)
7. [Vilka användare ni behöver](#vilka-användare-ni-behöver)
8. [SSH-nycklarna](#ssh-nycklarna)
9. [Viktiga platser på servern](#viktiga-platser-på-servern)
10. [Portar](#portar)
11. [Ordningen, steg för steg](#ordningen-steg-för-steg)
12. [När något strular](#när-något-strular)
13. [Inför videon](#inför-videon)
14. [Kan du svara på det här är du på god väg](#kan-du-svara-på-det-här-är-du-på-god-väg)

---

## Du är här

API:et och databasen fungerar i Docker på din Mac, koden ligger på GitHub, och du övar på en EC2-server. Där finns användaren `book-api` och en nyckel. Nästa konkreta steg är att lägga in nyckeln som deploy key på GitHub och klona repot. Se steg 4 och 5.

> **Tidsnotering:** Ovanstående beskriver läget när originaltexten skrevs, inte nödvändigtvis det aktuella läget.

## Uppgiften, nerbruten

Ni betygsätts individuellt på en gemensam video på max **60 minuter**. Hela miljön ska byggas från scratch under inspelningen. Servern du har nu är alltså bara övning. Ni får använda AI-genererad kod, men ni måste förstå och kunna förklara det mesta.

| Krav | Nivå | På vanlig svenska |
|---|---|---|
| EC2, security group, Elastic IP | G | Hyr datorn, bestäm vem som släpps in, ge den en fast adress. |
| SSH-nycklar för båda | G | Båda ska kunna logga in på samma server från varsin dator. |
| Bash-script, kopierat med `scp` | G | Ett script installerar paket, alias och eventuell extra användare, så att servern alltid blir likadan. |
| Klona repot till en hemkatalog | G | Koden hamnar i en användares hemkatalog. För er: `/home/book-api`. |
| Backup med cron | G | Databas och loggar sparas automatiskt på bestämda tider. |
| Övervakning med notis | G | Ett script kollar till exempel disk, CPU och SSH och skickar en notis till Discord. |
| API via systemd eller supervisor | G / VG | En process manager håller API:et igång. Krävs även för VG, så det ska visas. |
| Nginx och Postgres | G | Nginx tar emot trafiken, och API:et sparar i en Postgres-databas. |
| Dockerfile och Compose | VG | API och Postgres ska köras i containrar på servern. Det här är huvudfokus för VG. |
| HTTPS med egen domän och certbot | VG | Köp ett domännamn, peka det mot servern och hämta ett certifikat. |
| RDS och GitHub Actions | Bonus | Frivilligt. Ni har valt bort RDS, och Actions kan också vänta. |

Att göra VG-stegen garanterar inte VG. Läraren bedömer också er förståelse och tekniska känsla.

## Så hänger allt ihop

Det finns **två resor** att hålla isär. Den ena är hur **en besökare når API:et**. Den andra är hur **din kod hamnar på servern**.

### Resa 1: Ett anrop från internet

```text
Webbläsaren
  └─ Öppnar https://er-doman/docs
       ↓ DNS översätter domänen till er Elastic IP
AWS Security Group
  └─ AWS brandvägg utanför servern. Släpper igenom 80 och 443.
       ↓ port 443
EC2-server (Ubuntu)
  └─ Nginx
       └─ Dörren in. Hanterar HTTPS och skickar vidare.
            ↓ 127.0.0.1:8000
       Docker Compose: api
         └─ FastAPI-kod, körd av Uvicorn
              ↓ db:5432, internt nätverk
       Docker Compose: db
         └─ Postgres. Datan ligger i volymen db_data.
```

### Resa 2: Din kod

```text
Din Mac
  └─ Du ändrar och testar
       ↓ git push
GitHub
  └─ Gemensam källa
       ↓ git pull
Servern
  └─ docker compose up -d --build
```

Ändra helst inte kod direkt på servern. Då blir servern och GitHub olika, och nästa `git pull` kan krångla.

`api/.env` är undantaget: den finns aldrig i Git och skapas på varje dator.

## Vad Docker är

Docker paketerar ett program tillsammans med allt det behöver, till exempel rätt Python-version och paket. Paketet körs likadant på din Mac och på servern. Det löser problemet **”det fungerar på min dator”**.

Det fungerar som en lättviktig, isolerad miljö som delar operativsystemets kärna med datorn, så en container är mindre och snabbare att starta än en hel virtuell dator.

| Ord | Vad det är | Hos er |
|---|---|---|
| **Image** | Det färdiga paketet. Ändras inte när det körs. | Byggs från `api/Dockerfile`, och `postgres:17-alpine` hämtas färdig. |
| **Container** | En körande kopia av en image. Kan tas bort och skapas igen. | `api` och `db` |
| **Volym** | Lagring som lever utanför containern. | `db_data`, därför finns böckerna kvar efter en omstart. |
| **Nätverk** | Compose kopplar ihop containrarna, och de hittar varandra via namn. | Därför är `DB_HOST=db`. |

### Era Docker-filer

| Fil | Vad den används till |
|---|---|
| `api/Dockerfile` | Receptet för hur API-imagen byggs. |
| `api/.dockerignore` | Vad som inte får följa med in i imagen, till exempel `.env`. |
| `docker-compose.yml` | Vilka containrar som ska köras och hur de hänger ihop. |
| `api/.env` | Inställningar och lösenord. `DB_*` läses av API:et och `POSTGRES_*` av databasen. |

## Docker eller systemd?

Båda håller API:et igång, och ni ska visa båda. Med **systemd** kör servern Python direkt, medan Docker kör samma API i en container. Nginx märker ingen skillnad eftersom båda lyssnar på `127.0.0.1:8000`.

Därför kan de inte köra samtidigt: **stoppa den ena innan du startar den andra**.

## Domän, DNS och HTTPS

HTTP skickar trafiken i klartext, så den som sitter på vägen kan läsa och ändra den. HTTPS är samma sak, men krypterad. Webbläsaren kan också kontrollera att den pratar med rätt server.

| Del | Vad den gör |
|---|---|
| **Domän** | Ett namn ni köper, till exempel `er-doman.se`. |
| **DNS och A-post** | Adressboken. En A-post säger att domänen pekar på er Elastic IP. |
| **Certifikat** | Ett bevis på att servern får använda domänen. Det utfärdas av Let's Encrypt och gäller i 90 dagar. |
| **Certbot** | Verktyget som hämtar certifikatet, ändrar Nginx-konfigurationen och kan förnya det. |

1. Skapa en A-post som pekar domänen mot Elastic IP.
2. Kontrollera att `http://er-doman/docs` fungerar. Port 80 måste vara öppen.
3. Kör `sudo certbot --nginx -d er-doman`.
4. Kontrollera att `https://er-doman/docs` fungerar och att port 443 är öppen.

HTTPS avslutas i Nginx. Därefter går trafiken okrypterad till API:et, men bara inuti samma server. När ni övar, använd `certbot --dry-run` så att ni inte slår i Let's Encrypts gränser.

## Vilka användare ni behöver

”Användare” betyder tre olika saker här, och det är lätt att blanda ihop dem. Ni behöver bara skapa en ny Linux-användare: `book-api`.

| Användare | Typ | Används till |
|---|---|---|
| `root` | Linux | Systemets högsta konto. Ni kör det via sudo, inte genom att logga in. |
| `ubuntu` | Linux | Skapas av AWS. Ert administratörskonto: ni loggar in hit och installerar saker. |
| `book-api` | Linux | Tjänstens konto. Äger repot, `.env` och deploy key. Ni går in med `sudo -iu book-api`. |
| `books_user` | Postgres | Finns bara inne i databasen. Det är inget konto på servern. |
| `micaelaegger` | GitHub | Ditt GitHub-konto. Finns inte på servern. |

Det enklaste är att båda lägger sina publika nycklar hos `ubuntu`. Egna Linux-konton för er två är också okej om ni kan motivera dem, men det är inget krav.

## SSH-nycklarna

Ett nyckelpar består av en **privat nyckel** som aldrig lämnar sin dator, och en **publik nyckel** som fungerar som ett lås. Du kan sätta låset på andra datorer, och den som har den privata nyckeln kommer in.

**Regeln:** Publik nyckel läggs på målet, privat nyckel stannar på avsändaren.

| Nyckel | Från | Till | Publika delen ligger |
|---|---|---|---|
| Din inloggning | Din Mac | `ubuntu` på EC2 | `/home/ubuntu/.ssh/authorized_keys` |
| Din kollegas inloggning | Din kollegas dator | `ubuntu` på EC2 | Samma fil, på en egen rad |
| Deploy key | `book-api` på EC2 | Ett repo på GitHub | Repots **Settings → Deploy keys** |
| Din GitHub-nyckel | Din Mac | Ditt GitHub-konto | GitHub-profilens SSH-nycklar |

Deploy key ska bara ha läsrätt. Servern ska kunna hämta kod, men inte kunna ändra repot.

## Viktiga platser på servern

Läraren vill se att ni vet var filerna ligger, så öva på att navigera dit själva. `ls -la`, `cat` och `nano` tar er långt.

| Plats | Vad som finns där |
|---|---|
| `/home/book-api/mlo26-linux-hemtenta-micaela-raoul` | Repot. |
| `.../api/.env` | Lösenord och inställningar. Använd `chmod 600`. |
| `/home/book-api/.ssh/` | Deploy key och SSH-konfiguration för GitHub. |
| `/home/ubuntu/.ssh/authorized_keys` | Vilka publika nycklar som får logga in som `ubuntu`. |
| `/etc/nginx/sites-available/` | Era Nginx-konfigurationer. |
| `/etc/nginx/sites-enabled/` | Länkar till konfigurationer som är aktiva. |
| `/var/log/nginx/` | `access.log` och `error.log`. |
| `/etc/systemd/system/` | Er tjänstefil, till exempel `book-api.service`. |
| `/etc/letsencrypt/live/` | Certifikaten från certbot. |
| `/var/log/auth.log` | Inloggningar och SSH-försök. Bra för övervakningen. |
| `/var/lib/docker/volumes/` | Dockers volymer, inklusive databasen. Rör dem inte för hand. |
| `/home/book-api/backups/` | Förslag på plats för era backuper. |

Grovt sett ligger **inställningar i `/etc`**, **loggar i `/var/log`** och **användarens egna filer i `/home`**. Cron-jobb redigerar ni med `crontab -e`.

## Portar

En IP-adress pekar ut datorn. En port pekar ut vilket program på datorn som ska ta emot trafiken.

| Port | Program | Öppen utifrån? |
|---|---|---|
| `22` | SSH | Ja, men bara från era IP-adresser |
| `80` | Nginx, HTTP | Ja, behövs också när certbot verifierar domänen |
| `443` | Nginx, HTTPS | Ja |
| `8000` | API:et | Nej, bara via `127.0.0.1` |
| `5432` | Postgres | Nej, aldrig |

## Ordningen, steg för steg

**Testa efter varje steg och gå inte vidare förrän det fungerar.** Minuterna är mina uppskattningar för inspelningen. Ta tid när ni övar, så vet ni vad som gäller för er.

1. **Skapa EC2, security group och Elastic IP — ~5 min**  
   Datorn behöver finnas, kunna nås och ha en adress som inte ändras.  
   **Test:** Instansen är `running` och IP-adressen är kopplad.

2. **Logga in och lägg till SSH-nycklar — ~3 min**  
   Båda ska kunna arbeta på servern från sin egen dator.  
   **Test:** Båda kan köra `ssh ubuntu@<elastic-ip>` med sin nyckel.

3. **Kopiera och kör `setup.sh` — ~5 min**  
   Installerar Docker, Nginx och alias, och skapar `book-api`.  
   **Test:** `docker --version`, `nginx -v` och `id book-api` fungerar.

4. **Skapa deploy key — ~2 min**  
   Låter servern läsa repot utan att använda dina egna nycklar.  
   **Test:** `ssh -T git@github.com` nämner repots namn.

5. **Klona repot och skapa `api/.env` — ~3 min**  
   Koden kommer från GitHub, men hemligheterna skapas här.  
   **Test:** `ls -la` visar filerna och `book-api` som ägare.

6. **Kör API:et med systemd och Nginx (G) — ~8 min**  
   Visar kravet på process manager och reverse proxy. API:et behöver också en databas här.  
   **Test:** `http://<elastic-ip>/docs` öppnas.

7. **Byt till Docker Compose (VG) — ~7 min**  
   Stoppa systemd-tjänsten, starta containrarna och skapa tabellen med `init_db.py`. Nginx-konfigurationen kan vara kvar.  
   **Test:** `docker compose ps` och `GET /books` via Nginx ger fem böcker.

8. **Peka domänen och kör certbot (VG) — ~6 min**  
   Ger riktig adress och krypterad trafik.  
   **Test:** `https://er-doman/docs` visar giltigt certifikat.

9. **Lägg in backup i cron (G) — ~4 min**  
   Skyddar mot förlorad data. Säg att backupen egentligen också bör finnas utanför servern.  
   **Test:** Kör scriptet för hand och kontrollera att filen skapas.

10. **Lägg in övervakning i cron (G) — ~4 min**  
    Ni får veta om något är fel utan att sitta och titta.  
    **Test:** En notis kommer fram i Discord.

11. **Avsluta rätt — ~2 min**  
    Visa hela kedjan en gång till. När videon är kontrollerad stänger ni av instansen, släpper Elastic IP och tar bort deploy key.

**Det som kräver förberedelser före inspelningen:** domänen, Discord-webhooken, era script och en enkel checklista. Filerna `setup.sh`, `book-api.service`, Nginx-konfigurationen, `backup.sh` och `monitor.sh` finns inte än (enligt originalets status).

## När något strular

Följ kedjan **inifrån och ut**, en länk i taget. Då vet du snabbt vilken del som är trasig. Det här är också ett bra sätt att visa teknisk känsla i videon.

```bash
# 1. Körs containrarna?
docker compose ps
docker compose logs api --tail=30

# 2. Svarar API:et på servern?
curl http://localhost:8000/status

# 3. Är Nginx rätt inställd och igång?
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 30 /var/log/nginx/error.log

# 4. Svarar servern via Nginx?
curl -I http://localhost/docs

# 5. Pekar domänen rätt?
dig +short er-doman

# Med systemd i stället för Docker:
sudo systemctl status book-api
sudo journalctl -u book-api -n 30
```

| Du ser | Det betyder oftast |
|---|---|
| `Permission denied (publickey)` | Fel nyckel, fel användare eller att den publika delen saknas. |
| Webbläsaren laddar tills den ger upp | Security group släpper inte igenom porten. |
| `502 Bad Gateway` | Nginx fungerar, men API:et svarar inte på port 8000. |
| `500` på `/books` | Kolla API-loggen. Ett vanligt fel är att tabellen saknas, och då kör du `init_db.py`. |
| `password authentication failed` | `DB_PASSWORD` skiljer sig från lösenordet som volymen skapades med. |

## Inför videon

- Båda ska synas, prata och arbeta på varsin dator.
- Terminaltexten ska gå att läsa. Testa på hög zoomnivå.
- Skriv enkla kommandon för hand. Klistra bara in längre innehåll, som en konfiguration.
- Navigera till rätt mapp och öppna filen med `nano`. Använd inte långa one-liners som läser in filer åt er.
- Använd en checklista, men läs inget manus. Öva tills ni klarar det från scratch.

## Kan du svara på det här är du på god väg

### Varför behövs Nginx framför API:et?

Den tar emot all trafik på en plats och hanterar HTTPS. API:et behöver inte exponeras direkt mot internet.

### Vad är skillnaden mellan image och container?

En image är det färdiga paketet. En container är en körande kopia av det.

### Varför finns datan kvar när containern tas bort?

Den ligger i volymen `db_data`, utanför containern. Bara `docker compose down -v` tar bort volymen. *(Originalets formulering.)*

### Varför är `DB_HOST=db`?

Compose låter containrarna hitta varandra via tjänstnamn. `localhost` skulle peka på API-containern själv.

### Varför används användaren `book-api`?

Tjänsten får tydligt ägarskap och är inte knuten till en person. Eftersom den är med i docker-gruppen har den i praktiken root-rättigheter, så det är ingen stark säkerhetsgräns.

### Varför sparar man backup utanför servern?

Om servern försvinner eller disken går sönder förlorar ni annars både databasen och backupen.

---

*Originalets slutnotering: Bygger på `uppgift.txt` och läget i repot den 6 november 2026. Stegen på servern har inte körts i den här ordningen än, så justera efter era övningar.*
