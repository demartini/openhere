// Renders the localized pages from one template. No framework: `{{key}}` placeholders and
// `<!--EACH list-->…<!--/EACH-->` blocks with `{{item.field}}`.
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, "dist");
const SITE_URL = "https://demartini.dev/openhere/";

const svg = (body) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" class="size-5" aria-hidden="true">${body}</svg>`;

const icons = {
  toolbar: svg('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18M7 6.5h.01M10 6.5h.01"/>'),
  terminal: svg('<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M7 9l3 3-3 3M12.5 15H17"/>'),
  keyboard: svg('<rect x="2.5" y="6" width="19" height="12" rx="3"/><path d="M6.5 10h.01M10 10h.01M14 10h.01M17.5 10h.01M7.5 14h9"/>'),
  copy: svg('<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>'),
  apps: svg('<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><path d="M17.5 14v7M14 17.5h7"/>'),
  shield: svg('<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6l7-3z"/><path d="M9 12l2 2 4-4"/>'),
};

function renderEach(html, data) {
  return html.replace(/<!--EACH (\w+)-->([\s\S]*?)<!--\/EACH-->/g, (_, key, block) =>
    (data[key] ?? [])
      .map((item) =>
        block.replace(/\{\{item\.(\w+)\}\}/g, (_, field) =>
          field === "icon" ? (icons[item.icon] ?? "") : String(item[field] ?? ""),
        ),
      )
      .join(""),
  );
}

function render(template, data, extra) {
  const values = { ...data, ...extra };
  return renderEach(template, values).replace(/\{\{(\w+)\}\}/g, (_, key) => {
    if (!(key in values)) throw new Error(`Missing translation key: ${key}`);
    return values[key];
  });
}

const template = await readFile(join(here, "src/index.template.html"), "utf8");
const pages = [
  { lang: "en", file: "i18n/en.json", out: "index.html", root: "", alt: "pt-br/", canonical: SITE_URL },
  { lang: "pt-BR", file: "i18n/pt-BR.json", out: "pt-br/index.html", root: "../", alt: "../", canonical: `${SITE_URL}pt-br/` },
];

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
await cp(join(here, "public"), dist, { recursive: true });

for (const page of pages) {
  const data = JSON.parse(await readFile(join(here, page.file), "utf8"));
  const html = render(template, data, {
    lang: page.lang,
    root: page.root,
    altHref: page.alt,
    altLang: page.lang === "en" ? "pt-BR" : "en",
    canonical: page.canonical,
    siteUrl: SITE_URL,
    year: String(new Date().getFullYear()),
  });
  await mkdir(dirname(join(dist, page.out)), { recursive: true });
  await writeFile(join(dist, page.out), html);
}
console.log(`Rendered ${pages.length} pages into dist/`);
