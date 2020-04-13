FROM jekyll/jekyll AS builder

WORKDIR /build
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY package.json package-lock.json ./
RUN npm i

COPY . .
RUN npx webpack
RUN mkdir ./_site
RUN mkdir ./src/.jekyll-cache/
RUN chmod 777 ./src/.jekyll-cache/
RUN JEKYLL_ENV=production jekyll build --future --trace


FROM nginx:alpine AS runner

COPY deploy/nginx.conf /etc/nginx/nginx.conf

WORKDIR /app
COPY --from=builder /build/_site ./
COPY /assinaturas ./assinaturas

EXPOSE 5000
