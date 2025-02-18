# Etapa 1: Construção do ambiente Ruby (Jekyll)
FROM jekyll/jekyll AS builder

WORKDIR /build
COPY Gemfile Gemfile.lock ./

# Configuração do Bundler e instalação das dependências
RUN bundle config set path './.bundle' && \
    mkdir ./.bundle && \
    chmod -R 777 /build/.bundle && \
    bundle install

# Etapa 2: Instalação do Node.js e pacotes npm
FROM node:20 AS installer

WORKDIR /build
COPY package.json package-lock.json ./

# Instalação da versão mais recente do npm e das dependências
RUN npm install -g npm@latest && \
    npm install

# Etapa 3: Construção do Jekyll e execução do Webpack
FROM jekyll/jekyll AS builder2

WORKDIR /build

# Copiar arquivos do 'builder' que contém o Jekyll instalado
COPY --from=builder /build/.bundle ./ ./

# Copiar arquivos do 'installer' que contém as dependências do npm
COPY --from=installer /build/node_modules ./node_modules/

# Copiar o restante dos arquivos (o código-fonte, por exemplo)
COPY . .

# Definir variáveis de ambiente necessárias para o Webpack
# ENV NODE_OPTIONS=--openssl-legacy-provider

# Executando o Webpack
RUN npx webpack

# Criação de diretórios e permissões para o Jekyll
RUN mkdir ./_site && \
    mkdir ./src/.jekyll-cache/ && \
    chmod 777 ./src/.jekyll-cache/

# Construção do Jekyll para produção
RUN JEKYLL_ENV=production jekyll build --future --trace

# Etapa 4: Imagem final para execução com Nginx
FROM nginx:alpine AS runner

# Configuração do Nginx
COPY deploy/nginx.conf /etc/nginx/nginx.conf

WORKDIR /app

# Copiar os arquivos gerados pelo Jekyll e as assinaturas
COPY --from=builder2 /build/_site ./
COPY /assinaturas ./assinaturas

# Expor a porta 5000 para o Nginx
EXPOSE 5000
