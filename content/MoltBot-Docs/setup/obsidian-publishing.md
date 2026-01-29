---
publish: true
created: 2026-01-28T23:30:52.040-06:00
modified: 2026-01-29T01:32:29.420-06:00
cssclasses: ""
---

# Obsidian → Quartz Publishing Setup

Publish Obsidian notes to a static website using [Quartz Syncer](https://github.com/saberzero1/quartz-syncer) and GitHub Pages.

**Docs:** https://saberzero1.github.io/quartz-syncer-docs/

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Obsidian Vault │────▶│  Quartz Syncer   │────▶│  GitHub Repo    │
│                 │     │  (plugin)        │     │  (Quartz)       │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                        ┌─────────────────┐               │ auto-deploy
                        │  GitHub Pages   │◀──────────────┘
                        │  (Actions)      │
                        └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │  Your Website   │
                        │  notes.you.com  │
                        └─────────────────┘
```

**Flow:**
1. Write notes in Obsidian with `publish: true` in frontmatter
2. Open Quartz Syncer publication center
3. Select notes → click "Publish Selected Changes"
4. GitHub Actions auto-builds and deploys
5. Site is live

---

## Prerequisites

- **Obsidian** (desktop or mobile)
- **GitHub account**
- **Custom domain** (optional)

---

## Step 1: Create Quartz Repository

**Quick start:** [Click here to create from template](https://github.com/new?template_name=quartz&template_owner=jackyzha0)

Or manually:
```bash
git clone https://github.com/jackyzha0/quartz.git
cd quartz
npm install
```

---

## Step 2: Configure GitHub Pages

### Enable Pages
1. Go to your repo → **Settings** → **Pages**
2. Under "Source", select **GitHub Actions**

### Add Deploy Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Quartz site to GitHub Pages

on:
  push:
    branches:
      - v4

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install Dependencies
        run: npm ci

      - name: Build Quartz
        run: npx quartz build

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: public

  deploy:
    needs: build
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

Commit and push. Site deploys to `<username>.github.io/<repo-name>`.

---

## Step 3: Generate GitHub Token

### Fine-grained Token (Recommended)

1. Go to [GitHub Token Settings](https://github.com/settings/personal-access-tokens/new)
2. **Token name:** `Quartz Syncer`
3. **Expiration:** Set a date (max 1 year)
4. **Repository access:** Select "Only select repositories" → choose your Quartz repo
5. **Permissions → Repository permissions:** Set **Contents** to "Read and write"
6. Click **Generate token**
7. **Copy immediately** (won't be shown again)

---

## Step 4: Install Quartz Syncer Plugin

1. In Obsidian: **Settings** → **Community Plugins** → **Browse**
2. Search "Quartz Syncer"
3. **Install** → **Enable**

Or install via [BRAT](https://github.com/TfTHacker/obsidian42-brat) for beta versions.

---

## Step 5: Configure Quartz Syncer

In Obsidian: **Settings** → **Community Plugins** → **Quartz Syncer**

### Git Settings Tab

| Setting | Value |
|---------|-------|
| **Remote URL** | `https://github.com/YOUR_USERNAME/YOUR_REPO.git` |
| **Branch** | `v4` (or your branch) |
| **Provider** | GitHub |
| **Authentication Type** | Username & Token/Password |
| **Username** | Your GitHub username |
| **Access Token** | Paste your token |

✅ Green checkmark = successful connection

---

## Step 6: Configure Quartz

Edit `quartz.config.ts` in your repo:

```typescript
const config: QuartzConfig = {
  configuration: {
    pageTitle: "Your Site Name",
    pageTitleSuffix: " | Your Site",
    baseUrl: "notes.yourdomain.com",  // No https://, no trailing slash
    defaultDateType: "modified",
    // ...
  },
  plugins: {
    transformers: [
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      // Match your Obsidian link settings
    ],
  },
}
```

### Add OpenGraph Image (optional)

Replace `quartz/static/og-image.png` with your image (1200x630px).

---

## Step 7: Custom Domain (Optional)

### For Subdomain (e.g., notes.yourdomain.com)

**DNS:** Add CNAME record
```
Type: CNAME
Name: notes
Value: YOUR_USERNAME.github.io
```

**GitHub:** Settings → Pages → Custom domain → enter `notes.yourdomain.com`

### For Apex Domain (e.g., yourdomain.com)

**DNS:** Add A records
```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

---

## Usage

### Mark Notes for Publishing

Add frontmatter property to any note:

```yaml
---
publish: true
---
```

**Quick ways to add:**
- Command palette: `Quartz Syncer: add publication flag`
- Properties panel (`Cmd+;`) → Add checkbox `publish`
- Set up hotkey via MetaEdit plugin for one-key toggle

### Publish Notes

1. **Open Publication Center:**
   - Command palette: `Quartz Syncer: Open publication center`
   - Or click the Quartz crystal icon in sidebar

2. **Review changes:**
   - **Unpublished notes:** New notes to add
   - **Changed notes:** Modified notes to update
   - **Published notes:** Check to unpublish/remove
   - Click any file to see diff

3. **Click "PUBLISH SELECTED CHANGES"**

4. Site updates automatically (~1-2 min)

---

## Agent Instructions

**For AI agents setting this up:**

### Quick Setup Checklist

```
□ Fork/clone Quartz repo to GitHub
□ Add .github/workflows/deploy.yml
□ Settings → Pages → Source: GitHub Actions
□ Generate fine-grained token (Contents: Read/write)
□ Install Quartz Syncer plugin in Obsidian
□ Configure plugin with repo URL + token
□ Update quartz.config.ts (pageTitle, baseUrl)
□ (Optional) Configure custom domain
```

### Key Paths & URLs

| Item | Location |
|------|----------|
| Plugin docs | https://saberzero1.github.io/quartz-syncer-docs/ |
| Quartz template | https://github.com/new?template_name=quartz&template_owner=jackyzha0 |
| Token settings | https://github.com/settings/personal-access-tokens/new |
| Quartz config | `quartz.config.ts` in repo root |
| Deploy workflow | `.github/workflows/deploy.yml` |
| Static assets | `quartz/static/` |

### Troubleshooting Commands

```bash
# Check if repo exists and is accessible
gh repo view YOUR_USERNAME/quartz

# Check recent workflow runs
gh run list -R YOUR_USERNAME/quartz --limit 5

# Check DNS propagation
dig notes.yourdomain.com

# Test Quartz build locally
cd ~/Code/quartz && npx quartz build --serve
```

### Common Issues

**"Connection failed" in plugin settings**
- Verify repo URL format: `https://github.com/user/repo.git`
- Check token has "Contents: Read and write" permission
- Token must be scoped to the correct repository

**GitHub Actions fails**
- Settings → Pages → Source must be "GitHub Actions"
- Delete existing `github-pages` environment if permission errors
- Check Actions tab for specific error

**Custom domain not working**
- DNS propagation can take up to 48h (usually <1h)
- Verify: `dig notes.yourdomain.com`
- Ensure CNAME points to `username.github.io` (not the repo URL)

**Notes not appearing in publication center**
- Must have `publish: true` in frontmatter (not `"true"`, not `yes`)
- Property name is case-sensitive
- Check plugin settings for custom publish key

**Changes not appearing on site**
- Wait for GitHub Actions to complete (~1-2 min)
- Check Actions tab for build status
- Hard refresh browser (`Cmd+Shift+R`)

### Testing Flow

1. Create test note with `publish: true`
2. Open publication center
3. Note should appear under "Unpublished notes"
4. Click "Publish Selected Changes"
5. Check GitHub repo for new commit
6. Check Actions tab for deployment
7. Visit site to verify

---

## Quartz Layout & Styling Customization

### Key Files

| File | Purpose |
|------|---------|
| `quartz.config.ts` | Site settings, plugins, theme colors |
| `quartz.layout.ts` | Component placement (left/right sidebars, beforeBody, afterBody) |
| `quartz/styles/custom.scss` | Custom CSS overrides |

### Conditional Rendering for Index Page

Quartz uses `data-slug="index"` on the body for the homepage. Use this to hide/show elements conditionally.

**In `quartz.layout.ts`** — wrap components with `ConditionalRender`:

```typescript
// Hide Backlinks on index page
Component.ConditionalRender({
  component: Component.Backlinks(),
  condition: (page) => page.fileData.slug !== "index",
}),

// Also commonly hidden on index:
Component.ConditionalRender({
  component: Component.Breadcrumbs(),
  condition: (page) => page.fileData.slug !== "index",
}),
Component.ConditionalRender({
  component: Component.ArticleTitle(),
  condition: (page) => page.fileData.slug !== "index",
}),
Component.ConditionalRender({
  component: Component.ContentMeta(),
  condition: (page) => page.fileData.slug !== "index",
}),
```

**In `quartz/styles/custom.scss`** — use CSS for visual tweaks:

```scss
// Hide "Home" link on homepage (avoid recursive link)
[data-slug="index"] .page-title {
  display: none;
}

// Remove image margins on index
[data-slug="index"] article img {
  margin: 0;
}

// Hide HR separator on index (no afterBody content)
[data-slug="index"] .center > hr {
  display: none;
}

// Add separator above footer
footer {
  border-top: 1px solid var(--lightgray);
  padding-top: 1rem;
  margin-top: 2rem;
}
```

### Understanding the HR Separator

Quartz renders an `<hr>` between content and `afterBody` components (defined in `quartz/components/renderPage.tsx`). If your layout has no `afterBody` components, you get a lonely HR. Hide it with CSS on specific pages.

### Automatic Backlinks to Index

A GitHub Action automatically adds backlinks to the index page on every deploy. This ensures:
- All published notes appear in the index's Backlinks section
- Graph View shows connections between notes and the index
- No manual linking required

**How it works:**

1. Script runs during deploy: `scripts/add-backlinks.sh`
2. Finds all markdown files in `content/` (except `index.md`)
3. If file doesn't already link to `[[index`, appends a backlink
4. Commits changes automatically before building

**The script** (`scripts/add-backlinks.sh`):

```bash
#!/bin/bash
# Adds backlink to index on all published markdown files that don't have one

CONTENT_DIR="content"
BACKLINK_PATTERN="\[\[index"
BACKLINK_TEXT=$'\n---\n*Part of [[index|Jonokasten]]*'

find "$CONTENT_DIR" -name "*.md" ! -name "index.md" -type f | while read -r file; do
  if ! grep -q "$BACKLINK_PATTERN" "$file"; then
    echo "$BACKLINK_TEXT" >> "$file"
    echo "Added backlink to: $file"
  fi
done
```

**Deploy workflow addition** (`.github/workflows/deploy.yml`):

```yaml
- name: Add backlinks to index
  run: |
    chmod +x scripts/add-backlinks.sh
    ./scripts/add-backlinks.sh
- name: Commit backlink changes
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git add -A
    git diff --staged --quiet || git commit -m "Auto-add backlinks to index"
    git push || true
```

**Note:** The workflow needs `contents: write` permission to push the backlink commits.

### Manual Graph Connections (Alternative)

For hidden links that don't render visibly, use:

```markdown
<!-- Hidden links for graph connections -->
<div style="display:none">
[[path/to/note|Display Name]]
[[another/note|Another Note]]
</div>
```

This creates backlinks and graph connections without cluttering the page.

### Local Development

```bash
cd ~/Code/quartz-notes
npx quartz build --serve
```

Site runs at http://localhost:8080 with hot reload. Changes to content, config, layout, and styles auto-rebuild.

**Port conflicts:** If you see `EADDRINUSE` errors, kill stale processes:

```bash
/usr/sbin/lsof -i :3001  # Find process using websocket port
kill <PID>               # Kill it
```

---

## Advanced Features

Quartz Syncer supports:

- **Dataview integration** — Pre-renders Dataview queries
- **Embeds** — Processes Obsidian embeds for Quartz
- **Folder filtering** — Publish only specific folders
- **Multiple providers** — GitHub, GitLab, Codeberg, Bitbucket, self-hosted

See [plugin docs](https://saberzero1.github.io/quartz-syncer-docs/Settings/) for configuration.

---

*Last updated: 2026-01-29*
