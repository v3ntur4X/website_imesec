# IMEsec Website

The website for the infosec group IMEsec. [https://imesec.ime.usp.br](https://imesec.ime.usp.br).

### To develop the front-end

After cloning the repository, run
```
npm i
bundle install
```

To develop, run
```
npx webpack -w
```
In one console, and
```
bundle exec jekyll serve
```
in another.

### To build for production

The nginx deploy config is on `deploy/nginx.conf`.
You can run the production deployment like so:

```
docker build . -t imesec/website
docker run -p 5000:5000 imesec/website
```