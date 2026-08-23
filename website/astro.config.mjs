import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const site = 'https://ccl-gleam.netlify.app';

export default defineConfig({
  site,
  integrations: [
    starlight({
      title: 'ccl',
      description: 'Read and edit CCL configuration from Gleam.',
      favicon: '/favicon.svg',
      customCss: ['./src/styles/custom.css'],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/tylerbutler/ccl_gleam',
        },
      ],
      sidebar: [
        {
          label: 'Start',
          items: [{ label: 'Quickstart', slug: 'quickstart' }],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Parsing and options', slug: 'guides/parsing-options' },
            { label: 'Typed access', slug: 'guides/typed-access' },
            { label: 'Editing and round trips', slug: 'guides/editing' },
            { label: 'Dynamic decoding', slug: 'guides/decoding' },
          ],
        },
        {
          label: 'Concepts',
          items: [
            {
              label: 'Document, Value, and Model',
              slug: 'concepts/document-value-model',
            },
            { label: 'Errors', slug: 'concepts/errors' },
          ],
        },
        {
          label: 'API reference',
          link: 'https://hexdocs.pm/ccl/',
        },
      ],
      head: [
        {
          tag: 'meta',
          attrs: { name: 'theme-color', content: '#f4f1e8' },
        },
        {
          tag: 'meta',
          attrs: { property: 'og:image', content: `${site}/og-image.png` },
        },
        {
          tag: 'meta',
          attrs: { property: 'og:image:width', content: '1200' },
        },
        {
          tag: 'meta',
          attrs: { property: 'og:image:height', content: '630' },
        },
        {
          tag: 'meta',
          attrs: { name: 'twitter:card', content: 'summary_large_image' },
        },
        {
          tag: 'meta',
          attrs: { name: 'twitter:image', content: `${site}/og-image.png` },
        },
      ],
    }),
  ],
});
