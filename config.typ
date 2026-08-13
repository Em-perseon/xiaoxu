#import "@preview/tufted:0.1.1"

#let template = tufted.tufted-web.with(
  header-links: (
    "/xiaoxu/": "Home",
    "/xiaoxu/docs/": "Docs",
    "/xiaoxu/blog/": "Blog",
    "/xiaoxu/essays/": "Essays",
    "/xiaoxu/timeline/": "Timeline",
    "/xiaoxu/cv/": "CV",
  ),
  title: "Xiaoxu",
  css: (
    "https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",
    "/xiaoxu/assets/tufted.css",
    "/xiaoxu/assets/custom.css?v=20260813h",
  ),
)
