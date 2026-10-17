import { defineConfig } from 'vitepress'

// Docs are published at https://smilemssz.github.io/tomato-ui/
export default defineConfig({
  title: 'Tomato GUI',
  description: 'A Roblox executor UI library: windows, tabs, 25+ components, stacking, cookies and an error log.',
  base: '/tomato-ui/',
  cleanUrls: true,
  lastUpdated: true,
  head: [['meta', { name: 'theme-color', content: '#e5402f' }]],

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Components', link: '/components/' },
      { text: 'Systems', link: '/systems/instance-guard' },
      { text: 'v2.3', items: [
        { text: 'Changelog', link: '/changelog' },
        { text: 'Troubleshooting', link: '/troubleshooting' }
      ] }
    ],

    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Getting started', link: '/guide/getting-started' },
          { text: 'Core concepts', link: '/guide/concepts' },
          { text: 'CreateWindow config', link: '/guide/config' },
          { text: 'Window API', link: '/guide/window-api' },
          { text: 'Lock, Round and Save', link: '/guide/common-options' },
          { text: 'Page lock', link: '/guide/page-lock' },
          { text: 'Popups and notifications', link: '/guide/popups' },
          { text: 'Icons (Lucide)', link: '/guide/icons' },
          { text: 'Cross-window communication', link: '/guide/hub' },
          { text: 'Settings page', link: '/guide/settings' }
        ]
      },
      {
        text: 'components',
        items: [
          { text: 'Overview and support matrix', link: '/components/' },
          { text: 'Text and layout', link: '/components/text-layout' },
          { text: 'Buttons', link: '/components/buttons' },
          { text: 'Switches and values', link: '/components/values' },
          { text: 'Text input', link: '/components/inputs' },
          { text: 'Pickers', link: '/components/pickers' },
          { text: 'Containers', link: '/components/containers' }
        ]
      },
      {
        text: 'Systems',
        items: [
          { text: 'Instance Guard', link: '/systems/instance-guard' },
          { text: 'Whitelist', link: '/systems/whitelist' },
          { text: 'Key system', link: '/systems/key-system' },
          { text: 'Cookies', link: '/systems/cookies' },
          { text: 'Error Log', link: '/systems/error-log' }
        ]
      },
      {
        text: 'More',
        items: [
          { text: 'Changelog', link: '/changelog' },
          { text: 'Troubleshooting', link: '/troubleshooting' }
        ]
      }
    ],

    socialLinks: [{ icon: 'github', link: 'https://github.com/smilemssz/tomato-ui' }],
    search: { provider: 'local' },
    editLink: {
      pattern: 'https://github.com/smilemssz/tomato-ui/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },
    outline: [2, 3],
    footer: { message: 'Tomato GUI documentation', copyright: 'Made with VitePress' }
  }
})
