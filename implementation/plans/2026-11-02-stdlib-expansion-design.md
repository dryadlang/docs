# Expansão da Standard Library — Design

**Data:** 2026-11-02  
**Estado:** Proposta para aprovação  
**Âmbito:** `src/stdlib/@std`, documentação em `docs/stdlib`, testes e fronteira de intrinsics  
**Relação com outros documentos:** complementa [STDLIB_ARCHITECTURE.md](../architecture/STDLIB_ARCHITECTURE.md) e substitui a ordem de implementação do plano antigo; a especificação da linguagem continua a ser a fonte de verdade para sintaxe e semântica.

---

## 1. Contexto

A stdlib tem hoje 46 módulos e cerca de 4.9k linhas de Dryad. O que existe:

| Domínio | Estado actual |
|---------|---------------|
| `@std/core` | `IDisposable`, `IEnumerable`, erros como strings |
| `@std/buffers` | `Buffer` gerido, slice zero-copy, resize, conversão UTF-8 |
| `@std/collections` | `List`, `Map` (procura linear), `Set`, `Queue` |
| `@std/io` | VFS com `MemoryBackend`/`NativeBackend`, `Stream`, `FileStream`, `MemoryStream`, `Path`, `FileHandle` |
| `@std/async` | `Promise` por microtasks, event loop, threads, thread pool |
| `@std/net` | `Socket`, TCP/UDP, DNS via `getaddrinfo`, TLS via OpenSSL, cliente HTTP mínimo |

O que falta em relação à arquitectura documentada:

- `@std/text` (operações de string, `StringBuilder`), `@std/encoding` (UTF-8, base64, hex, percent-encoding), `@std/json`, `@std/regex`.
- `@std/time`, `@std/math`, `@std/random`.
- `@std/fs` (`FileInfo`, `DirectoryInfo`, stat completo), `@std/os` (env, args, cwd), `@std/process`.
- `@std/diagnostics` (console, debug, stopwatch), `@std/log`.
- `@std/crypto`/`@std/hash` (SHA-256, HMAC, CRC32, random).
- Servidor HTTP, WebSocket, compressão, `@std/testing`, `@std/uuid`, `@std/uri`/`@std/url`.

O que existe está também demasiado dependente de C++ para operações que não são hardware: `resolve_host` (`getaddrinfo`), `tls_*` (OpenSSL), `send`/`recv` (variantes de string), `filesize`, `readdir`, `normalize_path`, `string_*` e `int_to_string`.

O resultado é uma stdlib com buracos nas bases e com dependências altas no runtime. A expansão tem de resolver as duas coisas sem transformar o C++ na implementação da biblioteca.

---

## 2. Intenção

A ordem escolhida é:

1. **Bases funcionais** — criar os módulos Dryad de que todos os outros dependem.
2. **Contratos** — definir e testar as interfaces entre esses módulos e entre módulos e consumidores.
3. **Expansão por domínios** — construir os domínios de alto nível sobre bases e contratos estáveis.

A regra transversal é: **intrinsics servem apenas para comunicação primária com hardware/OS que Dryad não consegue executar sozinho**. Tudo o que é protocolo, formato, parsing, gestão de buffers, calendário, texto ou política de erros pertence à stdlib em Dryad.

---

## 3. Objectivos

- Criar as bases funcionais que desbloqueiam JSON, HTTP, DNS, ficheiros, logging, testes e futuras bibliotecas de utilizador.
- Definir contratos explícitos e testáveis entre módulos: bytes, texto, streams, iteradores, encoding, relógio, erros, ownership e comparação/hash.
- Expandir a stdlib por domínios, com dependências acíclicas e uma ordem clara.
- Reduzir progressivamente os intrinsics de camada alta existentes, sem bloquear a expansão.
- Garantir que cada novo módulo é 100% Dryad e não acrescenta lógica ao C++.
- Manter a suite de testes verde e os exemplos executáveis nos três modos (interpreter, bytecode, AOT quando aplicável).

## 4. Não-objectivos

- Genéricos reificados ou tipos paramétricos na linguagem. As colecções continuam dinâmicas.
- `try`/`catch`/`throw`. O modelo de erro continua a ser por valor.
- TLS/HTTPS completo em Dryad neste ciclo. Fica explicitamente em quarentena.
- Portabilidade Windows completa. O alvo principal é POSIX/Linux; o código Windows continua a compilar.
- Sistema de pacotes, registry ou ferramentas de build.
- Substituir a especificação da linguagem ou introduzir novas formas de FFI.

## 5. Anti-objectivos

- Acrescentar wrappers C++ para texto, JSON, HTTP, DNS, TLS, paths ou parsing.
- Pôr lógica de protocolo no runtime e chamar-lhe “intrinsic básico”.
- Construir APIs de alto nível antes de existirem bytes/texto/encoding testados.
- Mudar APIs públicas existentes sem shim de compatibilidade e sem migração documentada.
- Criar um módulo novo sem testes, exemplo e entrada na matriz de dependências.

---

## 6. Restrições da linguagem e do runtime

| Restrição | Consequência no design |
|-----------|------------------------|
| Sem `try`/`catch`/`throw` | APIs devolvem erros por valor; contratos definem o formato exacto |
| Sem genéricos | Colecções e iteradores são dinâmicos; contratos usam duck typing verificado por testes |
| `&&` não faz short-circuit | Evitar cadeias de validação que dependam de curto-circuito; usar `if` aninhados |
| Strings são valores UTF-8 geridos pelo runtime | `@std/text` e `@std/encoding` usam `__string_to_bytes`/`__bytes_to_string` como ponte temporária |
| `Buffer` é o único contentor de bytes gerido | Não criar um segundo tipo de bytes; `@std/bytes` é um módulo de operações sobre `Buffer` |
| Sem operadores bitwise (`&`, `\|`, `^`, `~`, `<<`, `>>`) | Acrescentam-se à linguagem na Wave 0; não se emulam com aritmética nem se expõem como intrinsics |
| Não há conversão float→int nem formatação de floats | Acrescentam-se apenas `float_to_int`/`int_to_float` como T0; formatting e parsing ficam em Dryad |
| `__memcpy` não aceita offsets | Corrige-se na Wave 0 com `memmove(dest, destOffset, src, srcOffset, count)` (T0) |
| `stat`/`fstat` devolvem hoje apenas tamanho (ou um objecto vazio) | Correcção T0 na Wave 0/B: `stat` devolve objecto estruturado; `@std/fs` consome |
| `clock_gettime` devolve segundos em `double` | Correcção T0 na Wave 0/B: variante em nanossegundos inteiros; `@std/time` usa-a |
| Interfaces existem, mas não há verificação estrutural completa | Contratos são documentados e validados por testes de conformidade, não apenas pelo compilador |

---

## 7. Abordagens consideradas

### 7.1 DAG fundacional, de baixo para cima

Construir primeiro `bytes → text → encoding → math → time → collections`, depois JSON e os domínios. Vantagem: maximiza reutilização e desbloqueia muitos consumidores. Desvantagem: os benefícios visíveis demoram algumas semanas.

### 7.2 Verticais por domínio

Reescrever já DNS/HTTP/TLS e criar text/encoding à medida. Vantagem: demonstra cedo o objectivo na rede. Desvantagem: duplica helpers, gera retrabalho e cria dependências circulares.

### 7.3 Fronteira de intrinsics primeiro

Definir já o contrato mínimo definitivo e migrar todas as dependências altas do C++. Vantagem: arquitectura mais limpa de imediato. Desvantagem: bloqueia a expansão e é o caminho mais lento.

### 7.4 Abordagem escolhida: híbrido sequenciado

1. Bases funcionais em Dryad, usando apenas intrinsics T0 existentes.
2. Contratos entre módulos, com testes de conformidade e matriz de dependências.
3. Expansão por domínios.
4. Migração contínua dos intrinsics T1/T2, à medida que os módulos Dryad que os substituem ficam prontos.

Isto combina o valor de 7.1 com a disciplina de 7.3, sem pagar o custo de bloqueio de 7.2.

---

## 8. Contrato de intrinsics

### 8.1 Princípio

Um intrinsic só é admissível se satisfizer **uma** destas condições:

- É uma operação de memória ou de hardware/OS que Dryad não consegue exprimir sozinho (T0).
- É uma ponte de runtime necessária porque a linguagem ainda não expõe a capacidade (T1), e tem de estar documentada como dívida.
- É uma capacidade externa opcional, como OpenSSL (T2), explicitamente isolada e com plano de remoção.

Não é admissível um intrinsic que apenas evite escrever Dryad: parsing, formatação, protocolos, paths, texto, JSON, DNS, HTTP, TLS, calendário ou gestão de buffers de alto nível.

### 8.2 Camadas

| Camada | Definição | Exemplos | Política |
|--------|-----------|----------|----------|
| **T0 — Hardware/OS** | 1:1 com uma syscall ou operação de memória/CPU | `alloc_bytes`, `buffer_get/set`, `memcpy`, `read/write`, `open_*`, `close`, `socket/connect/bind/listen/accept`, `send_buffer/recv_buffer`, `clock_gettime`, `thread_*` | Permitido; é a base da stdlib |
| **T1 — Ponte de linguagem** | Necessário porque a linguagem ainda não expõe bytes, propriedades ou arrays de outra forma | `string_to_bytes`, `bytes_to_string`, `string_length`, `runtime.object_get/set`, `runtime.array_push`, `value_kind` | Permitido temporariamente; documentar e reduzir quando a linguagem evoluir |
| **T2 — Capacidade externa** | Libc/OpenSSL ou conveniência que não é 1:1 com hardware | `resolve_host`, `tls_*`, `filesize`, `readdir`, `normalize_path`, `int_to_string`, `string_starts_with` | Proibido criar novos; migrar para Dryad por ondas |

> **Operadores vs intrinsics.** Bitwise e truncagem float→int são semântica de CPU, mas não são intrinsics: pertencem à linguagem ou ao mínimo T0. Operadores bitwise (`&`, `|`, `^`, `~`, `<<`, `>>`) entram na linguagem. Só `float_to_int`/`int_to_float` ficam como T0, porque exprimem uma instrução de CPU que Dryad não tem forma de escrever. Formatação e parsing de floats são Dryad.

### 8.3 Inventário actual e destino

| Intrinsic atual | Classificação | Destino |
|-----------------|---------------|---------|
| `alloc_bytes`, `free_bytes`, `buffer_get`, `buffer_set`, `memcpy`, `memset`, `realloc` | T0 | Mantém-se; `memcpy` ganha variante `memmove` com offsets |
| `float_to_int`, `int_to_float` | T0 (novo) | Adicionar para truncagem/arredondamento 1:1 com a CPU; restante em Dryad |
| `open_read/write/append/readwrite`, `read`, `write`, `read_buffer`, `write_buffer`, `close`, `lseek`, `fsync` | T0 | Mantém-se |
| `fstat`, `stat` | T0 incompleto | Corrigir para devolver campos estruturados; `@std/fs` consome |
| `exists`, `unlink`, `mkdir`, `rmdir`, `rename`, `getcwd`, `chdir` | T0 | Mantém-se |
| `readdir` | T1 | Migrar para protocolo de listagem em Dryad ou para `getdents`-style buffer |
| `filesize` | T2 | Substituir por `stat`; remover |
| `normalize_path` | T2 | Mover para `@std/io/path` |
| `string_length`, `string_to_bytes`, `bytes_to_string` | T1 | Manter como ponte; `@std/text`/`@std/encoding` isolam o uso |
| `string_starts_with`, `int_to_string` | T2 | Mover para `@std/text` |
| `socket`, `connect`, `bind`, `listen`, `accept`, `shutdown`, `getsockname`, `set_reuseaddr`, `set_nonblocking`, `get_errno` | T0 | Mantém-se |
| `send_buffer`, `recv_buffer`, `sendto_buffer`, `recvfrom_buffer` | T0 | Mantém-se; são I/O de bytes |
| `send`, `recv` | T2 | Remover; usar variantes de buffer |
| `resolve_host` | T2 | Substituir por DNS em Dryad (`@std/net/dns`) |
| `tls_*` | T2 | Quarentena; substituir apenas quando existir crypto Dryad suficiente |
| `thread_*` | T0 | Mantém-se |
| `runtime.*` (object/array/promise/event loop/io poller) | T1 | Ponte de runtime; documentar e reduzir quando a linguagem expuser equivalentes |

### 8.4 Regra de admissão de novos intrinsics

Qualquer novo intrinsic exige:

1. Uma entrada no inventário T0/T1/T2.
2. Justificação de que não é exprimível em Dryad com os intrinsics existentes.
3. Um teste C++ mínimo e um teste Dryad que o consuma.
4. Um plano de remoção se for T1/T2.
5. Aprovação num ADR curto em `docs/implementation/architecture/`.

Na dúvida, implementa-se em Dryad.

---

## 9. Arquitectura em camadas

```
Aplicação / bibliotecas de utilizador
        ↓
L5  APIs de domínio        json, http, fs, crypto, regex, log, testing
        ↓
L4  Contratos              IStream, IEnumerable, IEncoding, IClock, Result, IHashable
        ↓
L3  Bases funcionais       bytes, text, encoding, math, time, collections
        ↓
L2  Ponte de bytes         Buffer, TextBytes/TextView, ownership
        ↓
L1  Intrinsics T0          memória, fds, sockets, threads, relógio
        ↓
L0  Runtime C++            VM, GC, syscalls, scheduler
```

Regras:

- L3 não importa L4/L5.
- L4 não importa L5.
- Um domínio só importa bases e contratos; nunca importa outro domínio de nível superior.
- Nenhuma camada acima de L1 pode introduzir C++.
- A matriz de dependências é documentada e verificada por um teste/script.

---

## 10. Fase A — Bases funcionais

Objectivo: ter um conjunto pequeno, testado e reutilizável de módulos que os domínios possam consumir. Todos usam apenas T0 existentes mais os quatro T0 aditivos da Wave 0; zero lógica de stdlib em C++.

### A1. `@std/buffers` + `@std/bytes`

**Problema actual:** `Buffer_CopyTo` copia byte a byte; não há concatenação, comparação, procura, trim de bytes nem conversão hex.

**Decisão:** `Buffer` continua a ser o contentor canónico. `@std/bytes` é um módulo de funções, não um segundo tipo.

API mínima:

- `Bytes_Copy(dst, dstOffset, src, srcOffset, count)` — usa `__memmove` (T0, seguro com sobreposição).
- `Bytes_Fill`, `Bytes_Compare`, `Bytes_Equals`.
- `Bytes_IndexOf`, `Bytes_LastIndexOf`, `Bytes_Contains`.
- `Bytes_StartsWith`, `Bytes_EndsWith`.
- `Bytes_Concat(a, b)`, `Bytes_Repeat(buf, count)`.
- `Bytes_Trim`, `Bytes_TrimStart`, `Bytes_TrimEnd` (bytes ASCII de espaço).
- `Bytes_ToHex`, `Bytes_FromHex`.
- `Bytes_ToBase64`, `Bytes_FromBase64` (pode viver em `@std/encoding`; aqui só o contrato).

Critérios de aceitação:

- `Buffer_CopyTo` passa a usar `__memmove` com offsets; deixa de haver loop byte a byte.
- Testes de limites, buffers vazios, slices e sobreposição.
- Benchmarks demonstram ganho sobre o loop actual.

### A2. `@std/text`

**Problema actual:** cada helper de string cria buffers temporários por carácter; não há `StringBuilder`; `Http_*` e `Path_*` duplicam parsing.

**Decisão:** criar `@std/text` com uma `TextView` (vista sobre `Buffer` + offsets) para operações repetidas, e funções de conveniência que convertem uma vez.

API mínima:

- Comprimento, `charAt`, `codePointAt`, `fromCodePoint`.
- `substring`, `slice`, `indexOf`, `lastIndexOf`, `includes`.
- `startsWith`, `endsWith`, `equals`, `compare`.
- `trim`, `trimStart`, `trimEnd`.
- `split`, `join`, `replace`, `replaceAll`, `repeat`.
- `padStart`, `padEnd`, `toLowerAscii`, `toUpperAscii`.
- `parseInt`, `parseFloat`, `formatInt` (base 2/8/10/16), `formatFloat` — `formatFloat`/`parseFloat` são Dryad sobre `float_to_int`, sem formatação em C++.
- `StringBuilder`: `append`, `appendChar`, `appendBuffer`, `toString`, `clear`, `length`.

**Semântica de índices (decidida):** todas as APIs de `@std/text` usam **índices de byte** em UTF-8, coerentes com `__string_length` e com `Buffer`. Operações por code point (`codePointAt`, `Text_CodePoints`, `charCount`) existem como funções explícitas que percorrem a string; nenhuma API mistura as duas unidades.

Critérios de aceitação:

- Nenhuma função converte a string mais de uma vez por operação.
- Testes com ASCII, UTF-8 multi-byte e strings vazias.
- `StringBuilder` evita O(n²) em concatenações repetidas.
- `Path_*`, `Http_*`, `Net_*` e `Dns_*` passam a reutilizar `@std/text` (migração incremental).

### A3. `@std/encoding`

**Problema actual:** conversão UTF-8 está espalhada por `Buffer`, `text` e `http`; não há base64/hex/percent.

**API mínima:**

- `Encoding_Utf8_Encode(text) -> Buffer`
- `Encoding_Utf8_Decode(buffer) -> string`
- `Encoding_Utf8_Validate(buffer) -> bool`
- `Encoding_Ascii_Encode/Decode`
- `Encoding_Base64_Encode/Decode`
- `Encoding_Hex_Encode/Decode`
- `Encoding_Percent_Encode/Decode` (URL)
- Contrato `IEncoding` com `encode`/`decode`.

Critérios:

- UTF-8 inválido devolve erro, não substituição silenciosa.
- Base64/hex testados contra vectores conhecidos.
- `@std/net/http`, `@std/io` e `@std/json` usam estes módulos.

### A4. `@std/math`

**API mínima:**

- `Math_Abs`, `Min`, `Max`, `Clamp`, `Sign`.
- `Floor`, `Ceil`, `Round`, `Trunc` — em Dryad sobre `float_to_int`.
- `Pow`, `Sqrt` (implementação Dryad se não houver primitiva; documentar precisão).
- `Gcd`, `Lcm`, `IsEven`, `IsOdd`.
- `ParseInt`/`FormatInt` partilhados com `@std/text`.
- `Random`: PRNG determinístico (xorshift/PCG) sobre operadores bitwise, semeado por `clock_gettime`; `Random_Bytes(buffer)`, `Random_Int(min,max)`, `Random_Seed`.

**Pré-requisito:** operadores bitwise da Wave 0. Sem eles, A4 e C3 não começam.

Critérios:

- Testes de limites, negativos, zero e overflow.
- PRNG reproduzível com a mesma seed.
- Nenhum C++ novo.

### A5. `@std/time`

**API mínima:**

- `Duration`: nanossegundos, milissegundos, segundos, minutos, horas; `add`, `sub`, `compare`.
- `Instant`: epoch em nanossegundos inteiros (`__clock_gettime_ns`), `now`, `elapsed`; a variante em `double` mantém-se só como compatibilidade.
- `DateTime`: conversão civil UTC (algoritmo `civil_from_days` em Dryad), ano/mês/dia/hora/minuto/segundo.
- `DateTime_FormatIso`, `DateTime_ParseIso`.
- `Clock` contract: `now()`, `monotonic()`.

**Pré-requisito:** correcção T0 do relógio para nanossegundos inteiros (Wave 0/B).

Critérios:

- Testes de anos bissextos, fronteiras de mês/ano, epoch e ISO-8601.
- Sem dependência de `localtime`/`strftime` em C++.
- Timezone local fica para um domínio posterior.

### A6. `@std/collections` reforçado

**Problema actual:** `Map` é O(n); `List` não tem sort/search; iteradores são só `forEach`.

**Trabalho:**

- `Map`: índice hash para chaves string/número, mantendo igualdade por `==`; fallback linear para outros tipos. Manter API.
- `List`: `sort` (merge sort estável), `binarySearch`, `slice`, `splice`, `reverse`, `any`, `all`, `find`, `findIndex`, `join`, `clone`.
- `Deque`: fila dupla sobre array circular (base para `Queue` e futuros consumidores).
- `Iterator`/`Iterable`: contracto `next() -> { done, value }`, `iterator()`; helpers `iter`, `collect`, `map`, `filter`, `take`, `skip`.
- `Set` e `Queue` migram para os novos contratos.

Critérios:

- `Map` mantém semântica e melhora complexidade para chaves comuns.
- Testes de colisões, resize, remoção e iteração durante mutação (documentar comportamento).
- Sort estável e comparador por função.

---

## 11. Fase B — Contratos

Objectivo: fixar as interfaces que os domínios vão consumir, sem as mudar a cada módulo novo.

### B1. Contratos base

| Contrato | Métodos | Implementado por |
|----------|---------|------------------|
| `IDisposable` | `dispose()` | Buffer, Stream, Socket, FileHandle |
| `IEnumerable` | `forEach(cb)` | List, Set, Queue, Deque |
| `IIterator` | `next() -> { done, value }` | List, Map, Set, Queue, Deque |
| `IReadable` | `read(buffer, offset, count)` | FileStream, MemoryStream, NetworkStream, TlsStream |
| `IWritable` | `write(buffer, offset, count)` | idem |
| `ISeekable` | `seek(offset, origin)`, `position` | FileStream, MemoryStream |
| `IStream` | `IReadable + IWritable + ISeekable + IDisposable` | FileStream, MemoryStream, NetworkStream |
| `IEncoding` | `encode(text)`, `decode(buffer)` | Utf8, Ascii, Base64, Hex |
| `IClock` | `now()`, `monotonic()` | SystemClock, FakeClock |
| `IComparable` | `compare(other)` | números, strings, DateTime |
| `IHashable` | `hash()` | strings, números, chaves de Map |
| `IError`/`Result` | `[value, error]` ou `null | error` | todos os novos módulos |

### B2. Convenção de erro

Para manter compatibilidade e evitar uma migração massiva:

- Operações que produzem valor: `[value, error]`, com `error == null` em sucesso.
- Operações de efeito (write, close, dispose): `null` em sucesso, string de erro em falha.
- APIs antigas que devolvem string directamente mantêm-se; novos módulos usam a convenção acima.
- Nunca se lança uma excepção através da fronteira da linguagem.

### B3. Ownership e lifecycle

- `Buffer` gerido é dono da memória; `dispose` liberta.
- `Buffer_Slice` é uma vista não-dona; o pai tem de viver mais.
- `FileStream`/`Socket` fecham o recurso no `close`/`dispose`.
- `NetworkStream`/`TlsStream` não são donos do socket subjacente, salvo indicação explícita.
- Documentar em cada módulo quem liberta o quê.

### B4. Matriz de dependências e conformidade

- `docs/stdlib/dependency-graph.md` com a matriz e regras de camadas.
- `src/tests/stdlib/contracts/` com testes reutilizáveis para cada contrato.
- Um teste/script que falha se um módulo importar uma camada superior.
- Versionamento de contratos: mudanças incompatíveis exigem nota de migração.

---

## 12. Fase C — Expansão por domínios

A ordem abaixo respeita a DAG. Cada domínio só começa quando as suas dependências estão verdes.

### C1. Serialização e texto estruturado

- `@std/json`: parser/serializer, valores null/bool/número/string/array/object, erros com posição, pretty print, streaming para grandes entradas.
- `@std/url`/`@std/uri`: parsing, normalização, query string, percent-encoding.
- `@std/csv`: parser/serializer com quoting.
- `@std/toml`: primeiro subconjunto para `dryad.toml` (strings, números, bool, arrays, tabelas).
- `@std/regex`: motor Dryad (Thompson NFA primeiro; backtracking depois, se necessário).

Dependências: `text`, `encoding`, `collections`, `bytes`.  
Critérios: JSON round-trip, vectores de teste, erros posicionais, sem C++.

### C2. Sistema, ficheiros e diagnóstico

- `@std/fs`: `FileInfo`, `DirectoryInfo`, `stat` completo (tamanho, tipo, mtime), `walk`, `copy`, `move`, `tempDir`.
- `@std/os`: `env`, `args`, `cwd`, `platform`, `homeDir`.
- `@std/process`: spawn/exec/wait, pipes, exit codes (sobre `fork/exec` T0).
- `@std/diagnostics`: `Console` (stdout/stderr/stdin), `Debug`, `assert`, `Stopwatch`.
- `@std/log`: níveis, sinks text/JSON, logger estruturado.

Dependências: `text`, `time`, `io`, `json` (para log).  
Critérios: `stat` corrigido em T0; listagem de diretórios sem `readdir` de camada alta, ou com T1 documentado e migração.

### C3. Crypto e hash

- `@std/hash`: SHA-256, SHA-1, HMAC-SHA256, CRC32, FNV-1a.
- `@std/crypto`: `randomBytes` (PRNG + entropia T0 quando disponível), comparação constante, utilitários.
- `@std/encoding` já cobre base64/hex.

Dependências: `bytes`, `math`, `encoding`.  
Critérios: vectores NIST/RFC, testes de streaming, nenhum C++ novo.  
Nota: SHA-1 é necessário para WebSocket; SHA-256 para integridade e futura TLS.

### C4. Rede em Dryad

- DNS:
  - Parse de `/etc/resolv.conf` e `/etc/hosts` com `@std/fs`/`@std/text`.
  - Query DNS over UDP (A/AAAA/CNAME), retries, timeout, cache.
  - Remover `resolve_host` do caminho da stdlib.
- HTTP:
  - Client HTTP/1.1 completo: `Content-Length`, chunked, keep-alive, redirects, timeouts, streaming.
  - Servidor HTTP/1.1: listener, parser de requests, router simples, respostas.
  - `@std/uri` para parsing.
- WebSocket: handshake (SHA-1/base64), frames, ping/pong, close.
- TLS: **quarentena**. O `tls_*` actual (OpenSSL) permanece como T2 isolado; a substituição por Dryad só acontece quando `@std/crypto` tiver primitivas suficientes (SHA-256, AES-GCM, ECDHE, X.509). Não é objectivo deste ciclo.

Dependências: `text`, `encoding`, `json`, `fs`, `crypto`, `async`.  
Critérios: echo server/client em Dryad; DNS local testável; HTTP com testes de chunked/keep-alive; TLS documentado como dívida.

### C5. Ferramentas de desenvolvimento

- `@std/testing`: `assert`, `assertEqual`, `assertThrows` (por valor), runner, mocks/fakes, `FakeClock`.
- `@std/terminal`: cores, detecção de TTY, largura.
- `@std/uuid`: v4/v7 sobre random.
- `@std/compression`: gzip/deflate (necessário para HTTP completo); pode ficar para depois de C4.
- `@std/glob`: padrões de caminho.

Dependências: `text`, `fs`, `crypto`, `time`.  
Critérios: a própria stdlib passa a usar `@std/testing` nos testes novos.

---

## 13. Migração de intrinsics

| Fase | Intrinsic | Acção | Compatibilidade |
|------|-----------|-------|-----------------|
| Wave 0 | `memmove` com offsets | Novo T0 `(dest, destOffset, src, srcOffset, count)` | Aditivo; `memcpy` mantém-se |
| Wave 0 | `float_to_int`, `int_to_float` | Novos T0 de conversão | Aditivo |
| Wave 0 | `clock_gettime_ns` | Novo T0 com nanossegundos inteiros | `clock_gettime` em double mantém-se |
| Wave 0/B | `stat`/`fstat` | Devolver objecto com campos (size, mode, mtime, tipo) | Manter retorno antigo temporariamente ou adapter |
| C2 | `filesize` | Substituir por `stat` em `@std/fs` | Deprecar; manter até C2 estar verde |
| C2 | `readdir` | Mover listagem para `@std/fs`; avaliar `getdents`-style buffer | Manter T1 durante a migração |
| A2/A3 | `string_length`, `string_to_bytes`, `bytes_to_string`, `string_starts_with`, `int_to_string` | Isolar em `@std/text`/`@std/encoding`; remover `string_starts_with`/`int_to_string` | Manter ponte T1 até a linguagem expor bytes |
| A2 | `normalize_path` | Mover para `@std/io/path` | Remover após migração |
| C4 | `send`, `recv` | Remover; usar `send_buffer`/`recv_buffer` | Actualizar `@std/net` |
| C4 | `resolve_host` | Substituir por DNS Dryad | Manter fallback T2 durante a transição |
| Futuro | `tls_*` | Quarentena; substituir só com crypto Dryad | Documentar como capacidade opcional |

Regra: nenhuma migração pode quebrar a suite; usa-se shim e um período de depreciação.

---

## 14. Testes e qualidade

- **Unitários Dryad:** `src/tests/stdlib/<domínio>/` para cada módulo novo.
- **Contratos:** `src/tests/stdlib/contracts/` com suites reutilizáveis.
- **Integração:** `src/tests/integration/` para fluxos completos (JSON→HTTP, DNS→TCP, fs→log).
- **Triple:** exemplos novos correm em interpreter e bytecode; AOT quando suportado.
- **Benchmarks:** texto, JSON, buffer, Map; comparar com baseline.
- **Documentação:** `docs/stdlib/<módulo>.md`, exemplos em `docs/examples/`, actualização do `SITEMAP.md`.
- **Gate:** `ctest` verde, sem novos warnings, sem ciclos de importação, sem C++ novo para lógica de stdlib.

---

## 15. Métricas de sucesso

- Bases funcionais (A1–A6) implementadas e testadas.
- Contratos (B1–B4) documentados com testes de conformidade.
- Pelo menos JSON, fs/os, diagnostics/log, crypto/hash e DNS/HTTP Dryad em C.
- Zero novos intrinsics T2; todos os T2 existentes mapeados com plano de remoção.
- Zero dependências cíclicas na matriz.
- Suite existente continua verde; novos módulos com cobertura de testes e exemplos.
- Nenhum ficheiro C++ novo para lógica de stdlib.

---

## 16. Riscos e mitigação

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Falta de genéricos | APIs menos tipadas | Contratos + testes de conformidade; documentar limites |
| Performance de parsing em Dryad | JSON/HTTP lentos | `Buffer` com `memcpy`, `TextView`, `StringBuilder`, benchmarks e optimização incremental |
| `Map` sem hash para objectos | Complexidade inesperada | Fast path string/número; fallback linear documentado; `value_hash` T1 se necessário |
| `clock_gettime` impreciso | Time/ISO com perda | Correcção T0 para nanossegundos numa fase própria |
| TLS grande e complexo | Bloqueia HTTPS | Quarentena explícita; OpenSSL T2 isolado; não prometer TLS Dryad neste ciclo |
| Scope creep | Bases atrasadas | Ondas com gates; domínios só começam com dependências verdes |
| Migração de intrinsics quebra testes | Regressões | Shims, depreciação, testes de compatibilidade |
| Docs em submódulo | Deriva de documentação | Actualizar `SITEMAP.md` e docs no mesmo PR/wave |

---

## 17. Decisões tomadas (calls do autor)

1. `Buffer` continua a ser o contentor canónico de bytes; `@std/bytes` é um módulo de funções.
2. A convenção de erro para novos módulos é `[value, error]` para valores e `null | error` para efeitos; APIs antigas não mudam já.
3. A Fase A não introduz lógica C++; só são permitidas as correcções T0 decididas na Wave 0 (`memmove` com offsets, `float_to_int`/`int_to_float`, `clock_gettime_ns`, `stat` estruturado).
4. TLS/HTTPS fica em quarentena neste ciclo; OpenSSL permanece T2 isolado.
5. `@std/text` usa `TextView` para evitar conversões repetidas; `StringBuilder` é classe.
6. `Map` é melhorado no local (hash para chaves comuns) em vez de criar um tipo concorrente.
7. Unicode começa por UTF-8 e ASCII; tabelas completas e case folding Unicode ficam para C5.
8. A ordem dos domínios é C1 → C2 → C3 → C4 → C5; dentro de C4, DNS antes de HTTP, HTTP antes de WebSocket.
9. A documentação de contratos vive em `docs/stdlib/contracts.md` e a matriz em `docs/stdlib/dependency-graph.md`.
10. Operadores bitwise entram na linguagem (Wave 0), não como intrinsics.
11. `float_to_int`/`int_to_float` são os únicos bridges numéricos novos; formatação e parsing de floats são Dryad.
12. `@std/text` usa índices de byte em UTF-8; operações por code point são funções explícitas.
13. `@std/fs` é a API pública de ficheiros; `@std/io` mantém streams/VFS por baixo, sem duplicação.
14. `@std/toml` começa pelo subconjunto necessário ao `dryad.toml` (strings, números, bool, arrays, tabelas).
15. Compressão (gzip/deflate) fica em C5, depois de C4; só entra antes se o cliente HTTP precisar de `Content-Encoding`.
16. As regras de camadas são verificadas por script/teste; excepções exigem nota na matriz de dependências.
17. O plano detalhado de tarefas será derivado deste design após aprovação.

---

## 18. O que fica para o builder

- Escolher algoritmos concretos (hash map, merge sort, PRNG, parser JSON, NFA) e justificá-los.
- Definir assinaturas exactas e nomes de ficheiros dentro das convenções existentes.
- Decidir a forma exacta de `TextView` e `StringBuilder` face às limitações da linguagem.
- Desenhar os casos de teste e vectores de referência.
- Escolher a estratégia de migração de `stat`/`readdir` sem quebrar APIs.
- Estimar esforço por tarefa e dividir em PRs pequenos.
- Identificar a primeira correcção T0 necessária e o momento de a fazer.

---

## 19. Sequência resumida

| Wave | Conteúdo | Depende de |
|------|----------|------------|
| L | Operadores bitwise na linguagem (`& \| ^ ~ << >>`) com testes de lexer/parser/VM/AOT | — |
| 0 | Inventário, contrato de intrinsics, matriz, harness; T0 `memmove`, `float_to_int`/`int_to_float`, `clock_gettime_ns`, `stat` estruturado | — (paralelo com L) |
| A | bytes, text, encoding, math, time, collections | Wave 0; A4 precisa também de L |
| B | contratos, conformidade, ownership, documentação | A |
| C1 | JSON, URL, CSV, TOML, regex | A+B |
| C2 | fs, os, process, diagnostics, log | A+B+C1 (log) |
| C3 | hash, crypto, random | A+B |
| C4 | DNS Dryad, HTTP client/server, WebSocket | A+B+C1+C2+C3 |
| C5 | testing, terminal, uuid, compression, glob | A+B+C2 |

**Próximo passo após aprovação:** derivar o plano de implementação tarefa-a-tarefa com o skill de planeamento, começando pela Wave L, Wave 0 e A1.

---

## 20. Respostas ao builder-check

Estas eram as dúvidas levantadas por uma revisão independente do design. Ficam resolvidas aqui para não bloquear o plano.

| # | Dúvida | Resolução |
|---|--------|-----------|
| 1 | Operadores bitwise | Entram na linguagem na Wave L: `&`, `\|`, `^`, `~`, `<<`, `>>` com semântica de 64 bits e shift mascarado. Não são intrinsics nem emulação aritmética. |
| 2 | Conversão e formatação numérica | Apenas `float_to_int`/`int_to_float` como T0. `Floor`/`Ceil`/`Round`/`Trunc`, `formatFloat`, `parseFloat` e JSON numérico são Dryad. |
| 3 | Novos T0/T1 | Permitidos os quatro T0 da Wave 0 (`memmove`, conversões, `clock_gettime_ns`, `stat`). Nenhum T1 novo. Tudo o resto em Dryad. |
| 4 | Índices de texto | Bytes UTF-8 por omissão; operações por code point explícitas. |
| 5 | Regras de camadas | Documentadas na matriz e verificadas por script no CI; excepções exigem nota. |
| 6 | `__memcpy` sem offsets | Resolvido com `memmove(dest, destOffset, src, srcOffset, count)`. |
| 7 | `@std/fs` vs `@std/io/file` | `@std/fs` é a API pública; `@std/io` fica por baixo. `FileStream` não é duplicado. |
| 8 | Compressão | C5, depois de C4; entra antes apenas se o cliente HTTP exigir `Content-Encoding`. |
| 9 | `@std/toml` | Subconjunto do `dryad.toml`; sem datas, inline tables complexas ou multi-line strings na primeira versão. |
