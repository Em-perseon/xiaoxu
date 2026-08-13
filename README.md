# Xiaoxu

This is the source code for my personal website:

https://em-perseon.github.io/xiaoxu/

The site is built with [Typst](https://typst.app/) and the [Tufted](https://typst.app/universe/package/tufted) template.

## Structure

```text
content/index.typ                  Home
content/docs/index.typ             Docs
content/docs/technical-docs/       Technical documentation
content/docs/course-notes/         Course notes
content/blog/index.typ             Blog index
content/blog/hello-world/index.typ Blog post
content/cv/index.typ               CV
config.typ                         Site navigation and shared config
assets/                            CSS and static assets
```

## Local Preview

```shell
make preview
```

Then open:

```text
http://127.0.0.1:8080/xiaoxu/
```

The preview command uses the same `/xiaoxu/` path prefix as GitHub Pages. Press `Ctrl+C` to stop the server. To use another port, run `make preview PREVIEW_PORT=9000`.

## Deploy

The site is deployed with GitHub Pages through GitHub Actions.

After editing content:

```shell
make html
git add .
git commit -m "Update site"
git push
```
