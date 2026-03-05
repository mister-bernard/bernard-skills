# Web Design Skill

**Build professional, accessible, production-ready websites using modern standards.**

---

## 1. Default Stack

React + Vite + TypeScript + Tailwind CSS + shadcn/ui + Radix UI + Framer Motion + CVA

**Why:** AI-friendly (code in one place), fast dev server, accessible by default, production-proven.

---

## 2. Design Tokens

**Spacing (8px grid):** 4, 8, 12, 16, 24, 32, 48, 64, 96px → Tailwind: `p-1` `p-2` `p-3` `p-4` `p-6` `p-8` `p-12` `p-16` `p-24`

**Typography (Major Third 1.25):** xs: 0.64rem | sm: 0.8rem | base: 1rem | lg: 1.25rem | xl: 1.563rem | 2xl: 1.953rem | 3xl: 2.441rem | 4xl: 3.052rem

**Semantic Colors:** `--text-primary: gray-950` `--text-secondary: gray-700` `--text-tertiary: gray-500` `--bg-primary: white` `--bg-secondary: gray-50` `--border: gray-200` `--primary: blue-500` `--success: green-500` `--warning: yellow-500` `--error: red-500`

**Border Radius:** sm: 2px | md: 6px | lg: 8px | xl: 12px | 2xl: 16px

---

## 3. Typography

**Fonts:** Inter/Geist (sans), Lora/Merriweather (serif headers), Geist Mono (mono)  
**System:** `ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif`  
**Line heights:** 1.25 (headings), 1.5 (body), 1.75 (relaxed)  
**Letter spacing:** -0.025em (large headings), 0 (body), 0.05em (all-caps)  
**Responsive:** `text-2xl md:text-3xl lg:text-4xl`  
**Pro:** Smart quotes (""), em dash (—), ellipsis (…), optical alignment

---

## 4. Color System

**Palette:** Primary (brand), Neutral (gray 50-950), Semantic (success/warning/error/info). Generate with [Tailwind Shades](https://www.tailwindshades.com/).

**WCAG 2.1 AA:** Normal text < 18px: 4.5:1 | Large text ≥ 18px: 3:1 | UI/focus: 3:1  
**60-30-10:** 60% dominant (bg), 30% secondary (support), 10% accent (CTA)  
**Test:** [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker)

---

## 5. Layout Patterns

**Max-width:** `max-w-7xl mx-auto px-4 sm:px-6 lg:px-8` (1280px) | `max-w-prose` (65ch readable)  
**Grid:** `grid grid-cols-12 gap-4` (12-col) | `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6` (responsive)  
**Breakpoints (mobile-first):** sm: 640 | md: 768 | lg: 1024 | xl: 1280 | 2xl: 1536

---

## 6. Component Patterns

**Card:** `border border-gray-200 rounded-lg shadow-sm p-6 hover:shadow-md transition-shadow`

**Dialog (shadcn):** `<Dialog><DialogTrigger><Button /></DialogTrigger><DialogContent><DialogHeader><DialogTitle /></DialogHeader>{content}<DialogFooter /></DialogContent></Dialog>`

**Nav:** `<header className="border-b"><nav className="max-w-7xl mx-auto px-4 h-16 flex justify-between items-center"><Logo /><div className="hidden md:flex space-x-8"><a /></div></nav></header>`

**Form:** `<FormField name="..." render={({ field }) => (<FormItem><FormLabel /><FormControl><Input {...field} /></FormControl><FormMessage /></FormItem>)} />`

**CTA:** `px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors`

---

## 7. Animation

**When:** Feedback (confirm action), guidance (direct attention), relationship (show connection), hierarchy (stagger). Never decoration.

**Durations:** 75ms (instant hover), 150-300ms (standard), 500ms (slow modals)

**Framer Motion:**
- Hover: `<motion.button whileHover={{ scale: 1.05 }} whileTap={{ scale: 0.95 }}>`
- Enter/exit: `<AnimatePresence>{isOpen && <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} />}</AnimatePresence>`
- Stagger: `<motion.ul variants={{ show: { transition: { staggerChildren: 0.1 } } }} animate="show">`

**Easing:** Spring `{ type: "spring", stiffness: 400, damping: 17 }` or `ease-in-out`

---

## 8. Accessibility (WCAG 2.1)

- Semantic HTML: `<nav>` `<main>` `<article>` `<button>`, not `<div>` everywhere
- Heading hierarchy: h1 → h2 → h3 (no skipping)
- Alt text: Every `<img>` needs meaningful alt
- Focus: `focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2` (3:1 contrast, 2px min)
- Contrast: 4.5:1 text, 3:1 UI
- Keyboard: Tab through all features
- ARIA: Icon-only buttons need `aria-label`
- Labels: Every input has `<label>`
- Skip links: "Skip to main content"
- Color not sole indicator: Add icons/text

---

## 9. Performance

**Images:** WebP, `<img loading="lazy" />`, `srcset`, compress (TinyPNG/Sharp)

**Code splitting:** `const Heavy = lazy(() => import('./Heavy'))` + `<Suspense fallback={<Skeleton />}><Heavy /></Suspense>`

**Fonts:** `<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>` + `@font-face { font-display: swap; }`

---

## 10. Quality Checklist (Pre-Ship)

1. [ ] Mobile responsive (375px, 768px, 1280px)
2. [ ] Dark mode (if applicable)
3. [ ] Loading states (spinner/skeleton)
4. [ ] Empty states (message + action)
5. [ ] Error states (clear messages)
6. [ ] Focus states (visible)
7. [ ] Keyboard nav (tab through)
8. [ ] Contrast (WAVE/axe)
9. [ ] Images (WebP, lazy, alt)
10. [ ] Typography (consistent scale)
11. [ ] Spacing (8px grid only)
12. [ ] Animations (150-300ms smooth)
13. [ ] No layout shift
14. [ ] Fast load (< 3s FCP)
15. [ ] Semantic HTML + ARIA

---

## Quick Reference

**Icons:** [Lucide](https://lucide.dev) (default) | [Heroicons](https://heroicons.com) (Tailwind)  
**Colors:** [Tailwind Shades](https://www.tailwindshades.com) | [Coolors](https://coolors.co)  
**Contrast:** [WebAIM](https://webaim.org/resources/contrastchecker)  
**Typography:** [Type Scale](https://typescale.com)  
**A11y:** [WAVE](https://wave.webaim.org) | axe DevTools  
**Inspiration:** [Awwwards](https://www.awwwards.com) | [Linear](https://linear.app) | [Stripe](https://stripe.com) | [Vercel](https://vercel.com)

---

**Reference docs:** `skills/web-design/research.md` (stack details), `skills/web-design/design-references.md` (exemplary sites)

**Last updated:** 2026-03-04 | **Maintained by:** Mr. Bernard
