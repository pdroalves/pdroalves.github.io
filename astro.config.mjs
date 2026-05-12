// @ts-check
import { defineConfig } from 'astro/config';
import remarkGfm from 'remark-gfm';

// https://astro.build/config
export default defineConfig({
  site: 'https://www.iampedro.com',
  base: '/',
  integrations: [],
  markdown: {
    remarkPlugins: [remarkGfm],
    rehypePlugins: [],
  },
  output: 'static',
});
