# PromptBar site

Static, single-file landing page for [promptbar.peterdsp.dev](https://promptbar.peterdsp.dev/).

## Files

- `index.html` — the whole page. Tailwind via CDN, no build step.
- `404.html` — glassy 404 fallback.
- `CNAME` — apex hostname for GitHub Pages / Cloudflare Pages custom domain.
- `robots.txt`, `sitemap.xml` — search hygiene.
- `assets/` — marketing screenshots and app icons (copied from `../marketing` and `../PromptBar/PromptBar/Assets.xcassets/AppIcon.appiconset`).

## Local preview

```bash
cd site
python3 -m http.server 4000
open http://localhost:4000
```

Any static server will do. There is no build step.

## Deploy: GitHub Pages

1. Push `site/` on `main`.
2. Repo Settings → Pages → **Source: Deploy from a branch** → **Branch: `main` / folder: `/site`**.
3. Pages picks up the `CNAME` and issues a certificate for `promptbar.peterdsp.dev`.
4. Add a CNAME DNS record: `promptbar` → `peterdsp.github.io`.

## Deploy: Cloudflare Pages / Netlify

- **Build command:** _(none)_
- **Publish directory:** `site`
- Add `promptbar.peterdsp.dev` as a custom domain.

## Editing assets

Marketing screenshots come from `../marketing/hero_*.png`. If you regenerate them, re-run:

```bash
cp ../marketing/hero_01_native_chat.png    assets/native-chat.png
cp ../marketing/hero_02_web_chats.png       assets/web-chats.png
cp ../marketing/hero_03_api_endpoints.png   assets/api-endpoints.png
cp ../marketing/hero_04_mcp_servers.png     assets/mcp-servers.png
cp ../marketing/hero_05_prompt_library.png  assets/prompt-library.png
```

## Notes

- The Ko-fi link is `https://ko-fi.com/peterdsp`.
- The App Store link uses id `6746917172` — if that id changes, update every occurrence in `index.html`.
- The site respects `prefers-reduced-motion`.
