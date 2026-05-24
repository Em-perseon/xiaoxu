# Xiaoxu

This is the source code for my personal website:

https://em-perseon.github.io/xiaoxu/

The site is built with [Typst](https://typst.app/) and the [Tufted](https://typst.app/universe/package/tufted) template.

## Structure

```text
content/index.typ                  Home
content/docs/index.typ             Docs
content/blog/index.typ             Blog index
content/blog/hello-world/index.typ Blog post
content/cv/index.typ               CV
config.typ                         Site navigation and shared config
assets/                            CSS and static assets
```

## Local Preview

```shell
make html
python3 -m http.server 8000 --directory _site
```

Then open:

```text
http://127.0.0.1:8000/
```

## Deploy

The site is deployed with GitHub Pages through GitHub Actions.

After editing content:

```shell
make html
git add .
git commit -m "Update site"
git push
```
