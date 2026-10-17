# Tomato UI docs (VitePress)

Documentation site for [Tomato UI](https://github.com/smilemssz/tomato-ui).

## Local development

```bash
npm install
npm run docs:dev
```

## Build

```bash
npm run docs:build
npm run docs:preview
```

## Deploy to GitHub Pages

1. Copy `docs/`, `package.json`, `.gitignore` and `.github/` into the repository root (next to `main.lua`).
2. In the repository settings open **Pages** and set **Source** to **GitHub Actions**.
3. Push to `main`. The workflow builds and publishes the site at `https://smilemssz.github.io/tomato-ui/`.

The site base path is `/tomato-ui/` (see `docs/.vitepress/config.mts`). Change `base` if the repository name changes.
