# Lovable.dev Design System & AI Web Design Research

**Compiled:** 2026-03-04  
**Purpose:** Foundation for AI-powered web design skill

---

## Table of Contents

1. [Lovable's Tech Stack Integration](#1-lovables-tech-stack-integration)
2. [Lovable's Design System](#2-lovables-design-system)
3. [How Lovable Trains AI for Design](#3-how-lovable-trains-ai-for-design)
4. [Best Practices for AI-Generated Web Design](#4-best-practices-for-ai-generated-web-design)

---

## 1. Lovable's Tech Stack Integration

### Core Stack

Lovable.dev uses a modern, production-grade stack optimized for rapid iteration and professional output:

- **React** — Component-based UI library
- **Vite** — Fast build tool and dev server
- **TypeScript** — Type-safe JavaScript for reliability
- **Tailwind CSS** — Utility-first CSS framework
- **shadcn/ui** — Copy-paste component collection (not an npm package)
- **Radix UI** — Accessible, unstyled primitive components
- **class-variance-authority (CVA)** — Type-safe component variants
- **Framer Motion** — Production-ready animation library
- **Supabase** (backend) — Auth, database, and API management

### How the Pieces Fit Together

#### Foundation Layer: Radix UI Primitives

Radix UI provides **unstyled, accessible components** with built-in:
- Keyboard navigation
- ARIA patterns
- Focus management
- Screen reader support

These are **headless components** — they handle behavior and accessibility, not appearance.

**Key Radix primitives used:**
- Dialog (modals)
- DropdownMenu
- Select
- Tabs
- Tooltip
- Accordion
- RadioGroup
- Checkbox
- Slider

#### Styling Layer: shadcn/ui + Tailwind

**shadcn/ui is NOT a component library** — it's a distribution system. You copy components directly into your codebase, giving you full ownership and customization.

Each shadcn component:
1. Wraps a Radix primitive
2. Applies Tailwind classes for styling
3. Uses CVA for variant management
4. Exports TypeScript types

**Example structure:**
```tsx
// shadcn/ui Button component
import { cva, type VariantProps } from "class-variance-authority"
import * as React from "react"

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/90",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
        outline: "border border-input bg-background hover:bg-accent",
        ghost: "hover:bg-accent hover:text-accent-foreground",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm: "h-9 px-3",
        lg: "h-11 px-8",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)
```

#### The components.json Configuration

This file (optional, but recommended) tells the CLI:
- **Style variant** (`new-york` is standard)
- **Tailwind config location**
- **CSS variables vs utility classes** (most use CSS variables)
- **TypeScript vs JavaScript**
- **Import aliases** for clean imports
- **Base color** (gray, slate, zinc, neutral, stone)
- **React Server Components** support

**Example:**
```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "app/globals.css",
    "baseColor": "zinc",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui"
  }
}
```

#### Variant Management: class-variance-authority (CVA)

CVA solves the problem of **managing multiple component states** without className hell.

**Core concept:**
```tsx
import { cva } from "class-variance-authority"

const button = cva(
  // Base classes (always applied)
  ["font-semibold", "border", "rounded"],
  {
    variants: {
      intent: {
        primary: ["bg-blue-500", "text-white", "border-transparent"],
        secondary: ["bg-white", "text-gray-800", "border-gray-400"],
      },
      size: {
        small: ["text-sm", "py-1", "px-2"],
        medium: ["text-base", "py-2", "px-4"],
      },
    },
    // Variants that apply when multiple conditions are met
    compoundVariants: [
      {
        intent: "primary",
        size: "medium",
        class: "uppercase",
      },
    ],
    defaultVariants: {
      intent: "primary",
      size: "medium",
    },
  }
)

// Usage
<button className={button({ intent: "secondary", size: "small" })}>
  Click me
</button>
```

**TypeScript integration:**
```tsx
import { type VariantProps } from "class-variance-authority"

interface ButtonProps 
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  // Custom props
}
```

#### Animation Layer: Framer Motion

Framer Motion adds **declarative animations** without managing CSS transitions manually.

**Key patterns:**

1. **Gesture animations** (hover, tap, drag):
```tsx
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  transition={{ type: "spring", stiffness: 400, damping: 17 }}
>
  Click me
</motion.button>
```

2. **Enter/exit animations** with AnimatePresence:
```tsx
<AnimatePresence>
  {isOpen && (
    <motion.div
      initial={{ opacity: 0, y: -20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
    >
      Content
    </motion.div>
  )}
</AnimatePresence>
```

3. **Variants** for coordinated animations:
```tsx
const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1
    }
  }
}

const item = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0 }
}

<motion.ul variants={container} initial="hidden" animate="show">
  <motion.li variants={item} />
  <motion.li variants={item} />
</motion.ul>
```

4. **Layout animations** (automatic position transitions):
```tsx
<motion.div layout>
  {/* Content that can reorder or resize */}
</motion.div>
```

**Common transition configs:**
```tsx
// Spring (natural feel)
{ type: "spring", stiffness: 400, damping: 17 }

// Tween (precise timing)
{ duration: 0.3, ease: "easeInOut" }

// Stagger (sequential animations)
{ staggerChildren: 0.1, delayChildren: 0.2 }
```

#### Build Tool: Vite

Vite provides:
- **Instant dev server** start (no bundling in dev)
- **Hot Module Replacement** (HMR) for live updates
- **Optimized production builds** (Rollup-based)
- **TypeScript/JSX** support out of the box
- **Fast** — 10-100x faster than Webpack for dev

**Why Vite matters for AI generation:**
- Changes appear instantly
- No build step wait during iteration
- Easy to verify AI-generated code works

---

## 2. Lovable's Design System

### Design Tokens Architecture

#### Primitive Tokens (Foundation)

Base values that never change:

**Colors:**
```css
/* Numeric scale 50-950 */
--gray-50: #fafafa;
--gray-100: #f4f4f5;
--gray-200: #e4e4e7;
--gray-500: #71717a;  /* Base shade */
--gray-900: #18181b;
--gray-950: #09090b;

/* Brand colors */
--blue-500: #3b82f6;
--green-500: #22c55e;
--red-500: #ef4444;
```

**Spacing:**
```css
/* 4px base unit, 8px grid */
--spacing-0: 0;
--spacing-1: 0.25rem;  /* 4px */
--spacing-2: 0.5rem;   /* 8px */
--spacing-3: 0.75rem;  /* 12px */
--spacing-4: 1rem;     /* 16px */
--spacing-6: 1.5rem;   /* 24px */
--spacing-8: 2rem;     /* 32px */
--spacing-12: 3rem;    /* 48px */
--spacing-16: 4rem;    /* 64px */
```

#### Semantic Tokens (Context-Aware)

Purpose-based tokens that map to primitives:

```css
/* Text colors */
--text-primary: var(--gray-950);
--text-secondary: var(--gray-700);
--text-tertiary: var(--gray-500);
--text-inverse: var(--gray-50);

/* Background colors */
--bg-primary: #ffffff;
--bg-secondary: var(--gray-50);
--bg-tertiary: var(--gray-100);

/* Interactive colors */
--color-primary: var(--blue-500);
--color-primary-hover: var(--blue-600);
--color-secondary: var(--gray-500);
--color-accent: var(--blue-500);
--color-destructive: var(--red-500);

/* Borders */
--border-default: var(--gray-200);
--border-strong: var(--gray-300);
```

**Why semantic tokens matter:**
- Dark mode = swap semantic mappings, not every component
- Rebrand = change primitive values once
- Consistency = designers/devs use same vocabulary

### Tailwind CSS Configuration

**Default breakpoints:**
```js
{
  'sm': '640px',
  'md': '768px',
  'lg': '1024px',
  'xl': '1280px',
  '2xl': '1536px',
}
```

**Mobile-first approach:**
```tsx
// Default = mobile, then override upward
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4">
```

**Tailwind v4 enhancements:**
- CSS-first configuration
- 100x faster builds
- Native CSS variables
- No PostCSS required

### Typography System

Lovable likely uses a **modular scale** for consistent hierarchy.

**Common scales:**
- **1.125 (Major Second)** — Subtle hierarchy
- **1.25 (Major Third)** — Balanced (recommended for most UIs)
- **1.333 (Perfect Fourth)** — Strong hierarchy
- **1.5 (Perfect Fifth)** — Editorial/dramatic

**Example Major Third (1.25) scale:**
```css
--font-size-xs: 0.64rem;    /* 10.24px */
--font-size-sm: 0.8rem;     /* 12.8px */
--font-size-base: 1rem;     /* 16px */
--font-size-lg: 1.25rem;    /* 20px */
--font-size-xl: 1.563rem;   /* 25px */
--font-size-2xl: 1.953rem;  /* 31.25px */
--font-size-3xl: 2.441rem;  /* 39.06px */
--font-size-4xl: 3.052rem;  /* 48.83px */
```

**Line heights:**
```css
/* Tight for headings */
--leading-tight: 1.25;

/* Normal for body */
--leading-normal: 1.5;

/* Relaxed for large text */
--leading-relaxed: 1.625;
```

**Font weights:**
```css
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

**Letter spacing:**
```css
--tracking-tight: -0.025em;
--tracking-normal: 0;
--tracking-wide: 0.025em;
```

### Color System

#### Contrast Requirements (WCAG 2.1 AA)

- **Normal text (< 18px):** 4.5:1 minimum
- **Large text (≥ 18px or ≥ 14px bold):** 3:1 minimum
- **UI components & focus states:** 3:1 minimum

#### Semantic Color Roles

```css
/* State colors */
--color-success: var(--green-500);
--color-warning: var(--yellow-500);
--color-error: var(--red-500);
--color-info: var(--blue-500);

/* Interactive states */
--color-focus: var(--blue-500);
--color-hover: var(--gray-100);
--color-active: var(--gray-200);
--color-disabled: var(--gray-400);
```

#### Dark Mode with next-themes

**Setup:**
```tsx
// app/providers.tsx
import { ThemeProvider } from 'next-themes'

export function Providers({ children }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
      {children}
    </ThemeProvider>
  )
}

// tailwind.config.js
module.exports = {
  darkMode: 'class',
  // ...
}
```

**Usage:**
```tsx
import { useTheme } from 'next-themes'

export function ThemeToggle() {
  const { theme, setTheme } = useTheme()
  
  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      Toggle theme
    </button>
  )
}
```

**CSS variables approach:**
```css
:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 221.2 83.2% 53.3%;
}

[data-theme="dark"] {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --primary: 217.2 91.2% 59.8%;
}

/* Apply with Tailwind */
.bg-background { background-color: hsl(var(--background)); }
```

**Benefits:**
- Single source of truth for colors
- Automatic system preference detection
- No flash of unstyled content (FOUC)
- Persistent user preference

### Spacing System

**Principle:** Consistent rhythm creates visual harmony.

**4px/8px grid system:**
- **Base unit:** 4px (0.25rem)
- **Primary increment:** 8px (0.5rem)
- **Larger gaps:** 16px, 24px, 32px, 48px, 64px

**Common patterns:**
```tsx
// Card padding
<div className="p-6">  {/* 24px */}

// Section spacing
<section className="py-12 md:py-16">  {/* 48px → 64px */}

// Component gaps
<div className="flex gap-4">  {/* 16px */}

// Text spacing
<p className="mb-4">  {/* 16px */}
```

**Max-width containers:**
```tsx
// Prevent excessively wide content
<div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  {/* Content */}
</div>
```

**Common max-widths:**
- `max-w-sm` (384px) — Cards, forms
- `max-w-prose` (65ch) — Readable text
- `max-w-4xl` (896px) — Content pages
- `max-w-7xl` (1280px) — Full layouts

---

## 3. How Lovable Trains AI for Design

### Key Principles

While Lovable's exact training methods are proprietary, we can infer from their output:

#### 1. **Component-First Thinking**

AI is trained to:
- Recognize common UI patterns (cards, forms, navigation)
- Compose layouts from reusable components
- Apply consistent styling within each component type

**Pattern recognition:**
- User describes "dashboard with metrics cards"
- AI generates: Grid layout + Card component × 4 + consistent spacing

#### 2. **Design System Constraints**

AI operates within guardrails:
- **Limited color palette** — Use semantic tokens, not arbitrary colors
- **Spacing scale** — Only use values from the system
- **Typography scale** — Pre-defined sizes and weights
- **Component variants** — Predefined CVA variants

**This prevents:**
- Inconsistent spacing (e.g., 13px margin)
- Random colors (e.g., #7A3F9D)
- Mismatched font sizes

#### 3. **Accessibility by Default**

AI is prompted to always include:
- Semantic HTML (`<nav>`, `<main>`, `<article>`)
- ARIA labels where needed
- Focus states on interactive elements
- Proper heading hierarchy
- Sufficient contrast ratios

**Example prompt guidance (inferred):**
> "When generating a button, always include:
> - Clear focus-visible state
> - Sufficient contrast (4.5:1 for text)
> - Disabled state styling
> - ARIA label if icon-only"

#### 4. **Responsive by Default**

AI generates mobile-first layouts:
```tsx
// AI learns this pattern
<div className="
  grid 
  grid-cols-1           // Mobile: 1 column
  md:grid-cols-2        // Tablet: 2 columns
  lg:grid-cols-3        // Desktop: 3 columns
  gap-4                 // Consistent gap
">
```

#### 5. **Micro-interactions**

AI includes subtle animations:
- Hover states (`hover:bg-gray-100`)
- Focus states (`focus-visible:ring-2`)
- Transitions (`transition-colors duration-200`)
- Loading states (skeleton screens)

**Training data likely includes:**
- "Good" examples with smooth transitions
- "Bad" examples with jarring jumps
- User feedback on generated UIs

#### 6. **Semantic Naming**

AI generates meaningful variable names:
```tsx
// Good (AI-generated)
const [isMenuOpen, setIsMenuOpen] = useState(false)

// Bad (what untrained AI might do)
const [x, setX] = useState(false)
```

### Prompting Strategy (Inferred)

Based on Lovable's output quality, their AI likely receives:

**System prompt layers:**
1. **Role definition:** "You are an expert full-stack developer..."
2. **Tech stack rules:** "Always use React + TypeScript + Tailwind..."
3. **Design principles:** "Follow these accessibility guidelines..."
4. **Component patterns:** "Use these shadcn/ui components..."
5. **Best practices:** "Mobile-first, semantic HTML, consistent spacing..."

**User prompt enhancement:**
- Raw input: "Build a login page"
- Enhanced: "Create a responsive login page with email/password fields, validation, error states, loading state, and a 'forgot password' link. Use shadcn/ui Form and Input components. Follow WCAG 2.1 AA standards."

**Iterative refinement:**
- User: "Make it more modern"
- AI interprets: Add gradient backgrounds, smooth animations, subtle shadows
- AI generates: Updated component with `bg-gradient-to-r`, `shadow-lg`, Framer Motion

---

## 4. Best Practices for AI-Generated Web Design

### Typography

#### Font Pairing

**System font stacks (fast, reliable):**
```css
/* Sans-serif */
font-family: ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif;

/* Serif */
font-family: ui-serif, Georgia, Cambria, 'Times New Roman', serif;

/* Monospace */
font-family: ui-monospace, 'Cascadia Code', 'Source Code Pro', monospace;
```

**Google Fonts pairings:**
- **Inter** (sans) + **Lora** (serif)
- **Poppins** (sans) + **Merriweather** (serif)
- **Work Sans** (sans) + **Bitter** (serif)

**Rules:**
- **Headings:** Bold, distinctive (serif or geometric sans)
- **Body:** Readable, neutral (humanist sans or traditional serif)
- **Code:** Monospace with ligatures

#### Scale Implementation

Use a **modular scale calculator** or implement with CSS:

```css
:root {
  --ratio: 1.25; /* Major Third */
  --base-size: 1rem; /* 16px */
}

/* Calculate with calc() */
--text-sm: calc(var(--base-size) / var(--ratio));
--text-base: var(--base-size);
--text-lg: calc(var(--base-size) * var(--ratio));
--text-xl: calc(var(--base-size) * var(--ratio) * var(--ratio));
```

**Or use Tailwind's defaults:**
```tsx
<h1 className="text-4xl font-bold">   {/* 2.25rem / 36px */}
<h2 className="text-3xl font-semibold"> {/* 1.875rem / 30px */}
<h3 className="text-2xl font-semibold"> {/* 1.5rem / 24px */}
<p className="text-base">              {/* 1rem / 16px */}
<small className="text-sm">            {/* 0.875rem / 14px */}
```

#### Line Height & Letter Spacing

**Line height (leading):**
- **1.25** — Tight headings
- **1.5** — Body text (default)
- **1.75** — Relaxed paragraphs

**Letter spacing (tracking):**
- **-0.025em** — Large headings
- **0** — Body text
- **0.05em** — All-caps labels
- **0.1em** — Small text (< 12px)

**Tailwind:**
```tsx
<h1 className="leading-tight tracking-tight">
<p className="leading-relaxed">
<span className="text-xs uppercase tracking-wider">
```

### Color

#### Building a Palette

**Start with:**
1. **Primary** (brand color) — buttons, links, active states
2. **Neutral** (gray scale) — text, backgrounds, borders
3. **Semantic** — success, warning, error, info

**Generate shades:**
- Use tools like [Tailwind Shades](https://www.tailwindshades.com/)
- Generate 50-950 scale from a base color
- Ensure sufficient contrast between adjacent shades

**Example palette:**
```css
/* Primary (brand blue) */
--primary-50: #eff6ff;
--primary-100: #dbeafe;
--primary-500: #3b82f6;  /* Base */
--primary-900: #1e3a8a;

/* Neutral (zinc) */
--neutral-50: #fafafa;
--neutral-500: #71717a;
--neutral-900: #18181b;
```

#### Contrast Ratios

**Test every color combination:**
- Use [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- Or browser DevTools (Chrome: Inspect → Accessibility pane)

**Quick checks:**
- White text on your primary-500: ≥ 4.5:1?
- Primary-500 button on white background: ≥ 3:1 (for border)?
- Gray-500 text on white: ≥ 4.5:1?

**If failing:**
- Darken text color
- Lighten background
- Add a border or shadow for UI components

#### Semantic Color Usage

```tsx
// Success
<div className="bg-green-50 text-green-900 border border-green-200">
  Success message
</div>

// Warning
<div className="bg-yellow-50 text-yellow-900 border border-yellow-200">
  Warning message
</div>

// Error
<div className="bg-red-50 text-red-900 border border-red-200">
  Error message
</div>

// Info
<div className="bg-blue-50 text-blue-900 border border-blue-200">
  Info message
</div>
```

**Never:**
- Use red/green only to distinguish states (colorblind users)
- Use color alone for critical info (add icons or text)

#### Gradients

**Subtle, purposeful:**
```tsx
// Hero background
<div className="bg-gradient-to-r from-blue-500 to-purple-600">

// Button shine
<button className="bg-gradient-to-b from-blue-500 to-blue-600">

// Text gradient
<h1 className="bg-clip-text text-transparent bg-gradient-to-r from-pink-500 to-violet-500">
```

**Avoid:**
- Overly vibrant gradients (distracting)
- Text on gradient backgrounds (contrast issues)

### Spacing

#### Component Spacing

**Internal padding:**
```tsx
// Buttons
<button className="px-4 py-2">       {/* Compact */}
<button className="px-6 py-3">       {/* Standard */}
<button className="px-8 py-4">       {/* Large */}

// Cards
<div className="p-4">                {/* Tight */}
<div className="p-6">                {/* Standard */}
<div className="p-8">                {/* Spacious */}
```

**Between elements:**
```tsx
// Stack spacing
<div className="space-y-4">          {/* 16px gaps */}
  <div>Item 1</div>
  <div>Item 2</div>
</div>

// Grid gaps
<div className="grid grid-cols-3 gap-6">  {/* 24px gaps */}
```

**Section spacing:**
```tsx
// Mobile → Desktop
<section className="py-12 md:py-16 lg:py-20">
```

#### Rhythm & Consistency

**Rule:** Use values from the scale (4, 8, 12, 16, 24, 32, 48, 64).

**Don't:**
- `margin: 13px` ❌
- `padding: 17px` ❌

**Do:**
- `margin: 12px` (3 × 4) ✅
- `padding: 16px` (4 × 4) ✅

### Layout

#### Grid Patterns

**12-column grid (standard):**
```tsx
<div className="grid grid-cols-12 gap-4">
  <div className="col-span-12 md:col-span-8">Main</div>
  <div className="col-span-12 md:col-span-4">Sidebar</div>
</div>
```

**Auto-fit/auto-fill (responsive cards):**
```tsx
<div className="grid grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-6">
  <Card />
  <Card />
  <Card />
</div>
```

**Common layouts:**
```tsx
// Holy Grail
<div className="grid grid-rows-[auto_1fr_auto] min-h-screen">
  <header>Header</header>
  <main className="grid md:grid-cols-[200px_1fr_200px] gap-4">
    <aside>Left</aside>
    <article>Content</article>
    <aside>Right</aside>
  </main>
  <footer>Footer</footer>
</div>

// Centered content
<div className="min-h-screen grid place-items-center">
  <div className="max-w-md w-full">Content</div>
</div>
```

#### Max-Width Containers

**Prevent ultra-wide layouts:**
```tsx
<div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
  {/* Content constrained to 1280px, centered, with responsive padding */}
</div>
```

**Text content:**
```tsx
<article className="max-w-prose mx-auto">
  {/* 65 characters per line = optimal readability */}
</article>
```

#### Responsive Breakpoints

**Tailwind defaults (mobile-first):**
```tsx
<div className="
  text-sm          // Mobile
  md:text-base     // ≥ 768px
  lg:text-lg       // ≥ 1024px
">
```

**Strategic breakpoints:**
- **sm (640px):** Large phones
- **md (768px):** Tablets
- **lg (1024px):** Laptops
- **xl (1280px):** Desktops
- **2xl (1536px):** Large screens

**Common responsive patterns:**
```tsx
// Stack → Side-by-side
<div className="flex flex-col md:flex-row gap-4">

// 1 → 2 → 4 columns
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">

// Hide on mobile
<div className="hidden md:block">

// Show only on mobile
<div className="md:hidden">
```

### Micro-interactions

#### Hover States

**Buttons:**
```tsx
<button className="
  bg-blue-500 
  hover:bg-blue-600 
  transition-colors 
  duration-200
">
```

**Cards:**
```tsx
<div className="
  border 
  hover:border-blue-500 
  hover:shadow-lg 
  transition-all 
  duration-300
">
```

**Links:**
```tsx
<a className="
  text-blue-600 
  hover:text-blue-800 
  underline 
  underline-offset-4
  hover:underline-offset-2
  transition-all
">
```

#### Loading States

**Button loading:**
```tsx
<button disabled={isLoading}>
  {isLoading ? (
    <span className="flex items-center gap-2">
      <Loader2 className="animate-spin" />
      Loading...
    </span>
  ) : (
    'Submit'
  )}
</button>
```

**Skeleton screens:**
```tsx
function Skeleton() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-4 bg-gray-200 rounded w-3/4"></div>
      <div className="h-4 bg-gray-200 rounded"></div>
      <div className="h-4 bg-gray-200 rounded w-5/6"></div>
    </div>
  )
}
```

**Spinner:**
```tsx
<div className="flex justify-center">
  <div className="
    w-8 h-8 
    border-4 border-gray-200 
    border-t-blue-500 
    rounded-full 
    animate-spin
  "></div>
</div>
```

#### Transitions

**Common durations:**
- **75ms** — Instant feedback (hover)
- **150ms** — Quick (button press)
- **300ms** — Standard (page transitions)
- **500ms** — Slow (drawer open)

**Easing functions:**
```tsx
// CSS
transition: all 200ms ease-in-out;

// Tailwind
className="transition-all duration-200 ease-in-out"

// Framer Motion
transition={{ duration: 0.2, ease: "easeInOut" }}
```

**Best practices:**
- **Only animate what needs to move** (not `transition: all` unless necessary)
- **Prefer `transform`** over `top/left` (GPU-accelerated)
- **Use `will-change`** sparingly (only for known animations)

### Component Patterns

#### Cards

**Anatomy:**
```tsx
<div className="
  border border-gray-200 
  rounded-lg 
  shadow-sm 
  overflow-hidden
  hover:shadow-md 
  transition-shadow
">
  {/* Header */}
  <div className="px-6 py-4 border-b border-gray-200">
    <h3 className="text-lg font-semibold">Title</h3>
  </div>
  
  {/* Body */}
  <div className="px-6 py-4">
    <p className="text-gray-600">Content</p>
  </div>
  
  {/* Footer (optional) */}
  <div className="px-6 py-4 bg-gray-50 border-t border-gray-200">
    <button>Action</button>
  </div>
</div>
```

**Principles:**
- **One card, one topic**
- **Consistent padding** (typically 16-24px)
- **Clear visual hierarchy**
- **Clickable area** should be obvious

#### Dialogs (Modals)

**Using Radix + shadcn:**
```tsx
<Dialog>
  <DialogTrigger asChild>
    <Button>Open</Button>
  </DialogTrigger>
  
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Title</DialogTitle>
      <DialogDescription>Description</DialogDescription>
    </DialogHeader>
    
    {/* Content */}
    
    <DialogFooter>
      <Button variant="outline">Cancel</Button>
      <Button>Confirm</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

**Accessibility built-in:**
- Focus trap
- Escape key closes
- Backdrop click closes
- Screen reader announcements
- Focus returns to trigger on close

#### Navigation

**Header navigation:**
```tsx
<header className="border-b border-gray-200">
  <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div className="flex justify-between h-16 items-center">
      {/* Logo */}
      <div className="flex-shrink-0">
        <Logo />
      </div>
      
      {/* Desktop nav */}
      <div className="hidden md:flex space-x-8">
        <a href="#" className="text-gray-900 hover:text-blue-600">Home</a>
        <a href="#" className="text-gray-600 hover:text-blue-600">About</a>
      </div>
      
      {/* Mobile menu button */}
      <div className="md:hidden">
        <button>Menu</button>
      </div>
    </div>
  </nav>
</header>
```

**Sidebar navigation:**
```tsx
<aside className="w-64 border-r border-gray-200 p-4">
  <nav className="space-y-1">
    <a href="#" className="
      flex items-center gap-3 
      px-3 py-2 
      rounded-md 
      bg-blue-50 text-blue-700  // Active
      font-medium
    ">
      <Icon />
      Dashboard
    </a>
    
    <a href="#" className="
      flex items-center gap-3 
      px-3 py-2 
      rounded-md 
      text-gray-700 hover:bg-gray-100
    ">
      <Icon />
      Settings
    </a>
  </nav>
</aside>
```

#### Forms

**Using shadcn Form (React Hook Form + Zod):**
```tsx
const formSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
})

<Form {...form}>
  <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
    <FormField
      control={form.control}
      name="email"
      render={({ field }) => (
        <FormItem>
          <FormLabel>Email</FormLabel>
          <FormControl>
            <Input placeholder="you@example.com" {...field} />
          </FormControl>
          <FormDescription>We'll never share your email.</FormDescription>
          <FormMessage />
        </FormItem>
      )}
    />
    
    <Button type="submit">Submit</Button>
  </form>
</Form>
```

**Best practices:**
- **Label every input** (accessibility)
- **Inline validation** (on blur or change)
- **Clear error messages** (specific, actionable)
- **Disabled submit** until valid
- **Loading state** on submit

### Accessibility (WCAG 2.1 Compliance)

#### Focus States

**Always visible:**
```tsx
<button className="
  focus-visible:outline-none 
  focus-visible:ring-2 
  focus-visible:ring-blue-500 
  focus-visible:ring-offset-2
">
```

**Requirements:**
- **3:1 contrast** against background
- **2px minimum** thickness
- **Offset** from element (not overlapping text)

#### ARIA Labels

**Icon-only buttons:**
```tsx
<button aria-label="Close dialog">
  <X className="w-4 h-4" />
</button>
```

**Landmarks:**
```tsx
<nav aria-label="Main navigation">
<aside aria-label="Sidebar">
<form aria-label="Search">
```

**Live regions:**
```tsx
<div role="alert" aria-live="assertive">
  Error: Invalid email
</div>

<div aria-live="polite" aria-atomic="true">
  Loading...
</div>
```

#### Semantic HTML

**Use the right element:**
```tsx
// ❌ Bad
<div onClick={handleClick}>Click me</div>

// ✅ Good
<button onClick={handleClick}>Click me</button>

// ✅ Navigation
<nav>
  <ul>
    <li><a href="/">Home</a></li>
  </ul>
</nav>

// ✅ Heading hierarchy
<h1>Page Title</h1>
<h2>Section</h2>
<h3>Subsection</h3>
```

#### Keyboard Navigation

**Ensure all interactive elements:**
- Receive focus (use `tabindex="0"` if custom element)
- Have visible focus state
- Respond to Enter/Space
- Support arrow keys (for menus, tabs)

**Skip links:**
```tsx
<a href="#main" className="sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0">
  Skip to main content
</a>

<main id="main">
  {/* Content */}
</main>
```

---

## Summary Checklist for AI-Generated Designs

When generating or evaluating a web design, ensure:

### Technical
- [ ] Uses React + TypeScript + Tailwind + shadcn/ui
- [ ] Components have proper TypeScript types
- [ ] Uses CVA for component variants
- [ ] Animations use Framer Motion (declarative)
- [ ] Mobile-first responsive design

### Design Tokens
- [ ] Colors from defined palette (no arbitrary values)
- [ ] Spacing from scale (4/8/12/16/24/32/48/64)
- [ ] Typography from modular scale
- [ ] Semantic color naming (primary, secondary, success, etc.)

### Typography
- [ ] Modular scale (1.25 recommended)
- [ ] Line heights: 1.25 (headings), 1.5 (body)
- [ ] Readable font pairing
- [ ] Proper heading hierarchy (h1 → h6)

### Color & Contrast
- [ ] WCAG AA: 4.5:1 text, 3:1 UI components
- [ ] Dark mode support (if applicable)
- [ ] Color not sole indicator of state
- [ ] Semantic colors for success/warning/error

### Spacing & Layout
- [ ] Consistent spacing rhythm
- [ ] Max-width containers (prevent ultra-wide)
- [ ] Responsive breakpoints (mobile-first)
- [ ] Grid/Flexbox for layout (not floats/tables)

### Components
- [ ] Cards: border, shadow, padding, hover state
- [ ] Buttons: hover, focus, disabled, loading states
- [ ] Forms: labels, validation, error messages
- [ ] Navigation: responsive, accessible, clear hierarchy

### Micro-interactions
- [ ] Hover states on interactive elements
- [ ] Transitions (150-300ms standard)
- [ ] Loading states (skeleton or spinner)
- [ ] Smooth animations (spring physics preferred)

### Accessibility
- [ ] Semantic HTML (nav, main, article, etc.)
- [ ] ARIA labels where needed
- [ ] Focus states (3:1 contrast, visible)
- [ ] Keyboard navigation support
- [ ] Skip links for screen readers

### Performance
- [ ] Optimized images (WebP, lazy loading)
- [ ] Minimal bundle size (tree-shaking)
- [ ] Fast First Contentful Paint
- [ ] No layout shift (CLS)

---

## Resources

### Tools
- **[shadcn/ui](https://ui.shadcn.com/)** — Component collection
- **[Tailwind CSS](https://tailwindcss.com/)** — Utility CSS framework
- **[Radix UI](https://www.radix-ui.com/)** — Headless primitives
- **[CVA Docs](https://cva.style/docs)** — Variant management
- **[Framer Motion](https://www.framer.com/motion/)** — Animation library
- **[Type Scale](https://typescale.com/)** — Typography calculator
- **[Coolors](https://coolors.co/)** — Color palette generator
- **[WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)** — Contrast testing
- **[WAVE](https://wave.webaim.org/)** — Accessibility checker

### References
- **[Tailwind UI](https://tailwindui.com/)** — Premium component examples
- **[shadcn/ui Themes](https://ui.shadcn.com/themes)** — Pre-built themes
- **[Component Gallery](https://component.gallery/)** — Design system inspiration
- **[WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)** — Accessibility standards

---

**Last Updated:** 2026-03-04  
**Maintained by:** Mr. Bernard (Guido)  
**Purpose:** Foundation for `skills/web-design` implementation
