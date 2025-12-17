# Personal Website

A modern, maintainable personal website built with Astro and deployed on GitHub Pages.

## Features

- **Modern Design**: Clean, responsive layout with smooth animations
- **Easy Content Updates**: All content managed through YAML and Markdown files
- **GitHub Pages Ready**: Automatic deployment via GitHub Actions
- **Fully Customizable**: Easy to update colors, content, and structure

## Project Structure

```
PersonalSite/
├── src/
│   ├── components/      # Reusable UI components
│   ├── layouts/         # Page layouts
│   ├── pages/           # Routes (auto-generated)
│   ├── content/         # Content files (YAML/Markdown)
│   └── config.ts        # Site configuration
├── public/              # Static assets
└── .github/workflows/   # GitHub Actions
```

## Getting Started

### Development

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the development server:
   ```bash
   npm run dev
   ```

3. Open [http://localhost:4321](http://localhost:4321) in your browser

### Building

Build the site for production:
```bash
npm run build
```

Preview the production build:
```bash
npm run preview
```

## Content Management

### Social Links

Edit `src/content/social.yaml` to add, update, or remove social links:

```yaml
links:
  - name: "LinkedIn"
    url: "https://linkedin.com/in/yourprofile"
    icon: "linkedin"
    display: true
```

### About Text

Edit `src/content/about.md` to update your about section.

### Resume

Edit `src/content/resume.yaml` to update your resume information.

### Publications

Edit `src/content/publications.yaml` to add or update publications.

### Talks

Edit `src/content/talks.yaml` to add or update talks.

### GPG Keys

1. Export your GPG public key:
   ```bash
   gpg --armor --export YOUR_KEY_ID > public/gpg/current.asc
   ```

2. Update `src/content/gpg.yaml` with key information.

### Articles

Create new articles by adding Markdown files to `src/content/articles/`:

```markdown
---
title: "My Article"
description: "Article description"
date: "2024-01-01"
tags: ["tag1", "tag2"]
---

Your article content here...
```

## Deployment

The site is configured to automatically deploy to GitHub Pages when you push to the `main` branch.

1. Push your changes to GitHub
2. GitHub Actions will automatically build and deploy the site
3. Your site will be available at your GitHub Pages URL

### Custom Domain

The `public/CNAME` file is configured for `www.iampedro.com`. Update it if you need a different domain.

## Configuration

Edit `src/config.ts` to update:
- Site title and description
- Author information
- Gravatar email
- Color scheme

## License

MIT
