import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "My Docs",
  description: "คู่มือการใช้งานเครื่องมือ",
  base: '/my-docs/', // ใส่ชื่อ Repository ของคุณระหว่างเครื่องหมายสแลช
  themeConfig: {
    nav: [
      { text: 'หน้าแรก', link: '/' },
      { text: 'คู่มือ', link: '/guide' }
    ],
    sidebar: [
      {
        text: 'การใช้งาน',
        items: [
          { text: 'เริ่มต้นใช้งาน', link: '/guide' }
        ]
      }
    ]
  }
})
