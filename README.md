# Kinsma Website

**Live:** https://www.kinsma.com

## Stack
- Static HTML/CSS/JS
- Hosted on Azure Static Web Apps (Free Tier — expires 2027-03-05)
- Deployed via GitHub Actions: push to `main` → live in ~60 seconds

## Deploy
```bash
git add -A
git commit -m "your message"
git push
```
That's it. GitHub Action handles the rest.

## Git Remote
- Repo: https://github.com/jordan-kinsma/kinsma-website (public)
- Identity: Jordan Kale / business@kinsma.com (not Jerret — privacy)
- Auth (new host, from 2026-09-28): PAT lives in repo-local `gh.txt` (gitignored, chmod 600). `~/.gitconfig` carries `[http "https://github.com/"] extraheader = Authorization: Basic <b64>` plus `http.sslCAInfo` — this box sits behind a Squid MITM proxy, so git needs the CA bundle and must send the credential on the first request (the 401→retry prompt path breaks through the proxy). Plain `git push origin main` works; no gh CLI required.

## DNS (name.com)
- `www` CNAME → `jolly-sea-0c9014b1e.2.azurestaticapps.net`
- `kinsma.com` → 301 URL redirect to `https://www.kinsma.com`

## Files
- `index.html` — main page
- `style.css` — stylesheet
- `hero.jpg` / `hero.webp` — hero background (Jerret working on final version)
- `deploy.sh` — **OBSOLETE**, kept for reference only

## Azure Resources
- Subscription: Kinsma - Free Trial
- Resource group: `kinsma-web-rg` (West US 2)
- Static Web App: `kinsma-website`
- Account: business@kinsma.com
