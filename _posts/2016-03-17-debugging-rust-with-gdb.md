---
title: "Отладка приложений на Rust с помощью GDB"
author: Александр Яшкин
categories: обучение
excerpt:
    В этой статье мы рассмотрим как отлаживать программы на Rust с помощью
    отладчика GDB.

---

# Введение

__По мотивам статьи
[Михаэля Петерсона](http://thornydev.blogspot.ru/2014/01/debugging-rust-with-gdb.html),
которую переработали и сделали актуальной на данный момент.__

В этой статье мы рассмотрим, как можно использовать отладчик GDB с программами
на Rust. Для этого я использую:

```bash
$ rustc -V
rustc 1.7.0 (a5d1e7a59 2016-02-29)

$ gdb --version
GNU gdb (GDB) 7.11
```

Перед тем, как мы начнём, хочу сказать, что я не эксперт в отладчике GDB и я ещё
только изучаю Rust. С помощью таких статей я веду как бы конспект для себя.
Приветствую любые замечания и советы по поводу содержания этой статьи в
комментариях.

# Об отладчике GDB

Данная статья не является руководством по работе с GDB. Множество таких статей
можно найти в Интернете, например:

* http://betterexplained.com/articles/debugging-with-gdb/
* http://www.unknownroad.com/rtfm/gdbtut/gdbtoc.html
* http://beej.us/guide/bggdb

# Исходный код

Для изучения мы возьмём пример кода из Интернета, чтобы он был простой и в тоже
время был насыщен синтаксическими конструкциями, в т.ч. использовал замыкания и
анонимные функции. Наш пример будет состоять из двух файлов находящихся в одном
каталоге:

quux.rs:

```rust
pub fn quux00<F>(x: F) -> i32
    where F: Fn() -> i32 {

    println!("DEBUG 123");
    x()
}
```

и main.rs

```rust
mod quux;

fn main() {
    let mut y = 2;
    {
        let x = || {
            7 + y
        };
        let retval = quux::quux00(x);
        println!("retval: {:?}", retval);
    }
    y = 5;
    println!("y     : {:?}", y);
}
```

Напишем для нашего кода `Cargo.toml`, чтобы собирать его с помощью утилиты
Cargo:

```toml
[package]
name = "bar"
version = "1.0.0"
license = "GPLv3"
description = "Простой пример для отладки"

# Профиль dev используется по умолчанию при вызове команды cargo build
[profile.dev]
debug = true  # Добавляет флаг `-g` для компилятора;
opt-level = 0 # Отключаем оптимизацию кода;
```

А теперь соберём исполняемый файл для отладки:

```bash
$ cargo build
   Compiling bar v1.0.0 (...)
```

Начинаем отладку программы с помощью GDB и установим точки останова:

```
$ gdb target/debug/bar
(gdb) break bar::main
Breakpoint 1 at 0x40154c: file src/main.rs, line 4.
(gdb) rbreak quux00
Breakpoint 2 at 0x4017d3: file src/quux.rs, line 2.
static i32 bar::quux::quux00<closure>(struct closure);
(gdb) info breakpoints
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x000000000040154c in bar::main at src/main.rs:4
2       breakpoint     keep y   0x00000000004017d3 in bar::quux::quux00<closure> at src/quux.rs:2
```

Когда я ставил первую точку останова, то знал полный путь к функции:
`bar::main`.

Но иногда полный путь в Rust может быть очень длинным и сложным, например он
может быть параметризованным. Тогда проще использовать `rbreak`, который ставит
точку останова с помощью регулярного выражения. На все функции будут поставлены
точки останова если совпадут с регулярным выражением.

Вторую точку останова ставим на функции которые содержат "quux00" в своём имени.
Но таких функций может не оказаться, т.к. Rust может сам переименовывать имена
функций. Поговорим об этом позже, а пока продолжаем.

# Немного о rbreak

Вначале я не знал как поставить точку останова на функцию, которая находится не
в файле, где объявлена функция `main`.

Команда `rbreak` очень полезная. Если вы захотите поставить точки останова на
все-все функции в вашей программе, то команда `rbreak .` это сможет сделать, но
вряд ли это вам понадобится для  приложений на Rust, т.к. в исполняемом файле
могут быть сотни функций, которые создал компилятор.

Тогда можно ограничить область поиска функций с помощью регулярного выражения
только одним файлом:

```
(gdb) rbreak bar.rs:.
Breakpoint 1 at 0x40154c: file src/main.rs, line 4.
static void bar::main(void);
Breakpoint 2 at 0x40170c: file src/main.rs, line 6.
static i32 fnfn(void);
```

# Начинаем отладку

Сейчас у нас есть две точки останова:

```
(gdb) info breakpoints
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x000000000040154c in bar::main at src/main.rs:4
2       breakpoint     keep y   0x00000000004017d3 in bar::quux::quux00<closure> at src/quux.rs:2
```

Начинаем отладку:

```
(gdb) run
Starting program: D:\Code\Rust\debug\target\debug\bar.exe
[New Thread 14628.0x36d4]
[New Thread 14628.0x1be4]
[New Thread 14628.0x51c]
[New Thread 14628.0x2db0]

Thread 1 hit Breakpoint 1, bar::main () at src/main.rs:4
4           let mut y = 2;
(gdb) n
9               let retval = quux::quux00(x);
(gdb) list
4           let mut y = 2;
5           {
6               let x = || {
7                   7 + y
8               };
9               let retval = quux::quux00(x);
10              println!("retval: {:?}", retval);
11          }
12          y = 5;
13          println!("y     : {:?}", y);
(gdb) p y
$1 = 2
(gdb) p x
$2 = {__0 = 0x24fc8c}
```

Что интересно, мы одним шагом перешагнули с 5 по 8 строку, где присваиваем
переменной `x` адрес анонимной функции, который мы можем видеть в последней
строке вывода.

Сейчас мы остановились на строке 8 (в этом можно убедиться с помощью команды
`frame`). Теперь продолжим исполнение кода до следующей точки останова - функции
`quux00`:

```
(gdb) frame
#0  bar::main () at src/main.rs:9
9               let retval = quux::quux00(x);
(gdb) c
Continuing.

Thread 1 hit Breakpoint 2, bar::quux::quux00<closure> (x=...) at src/quux.rs:2
2               where F: Fn() -> i32 {
```

Отлично. Вторая точка останова сработала. Определим своё местоположение в коде:

```
(gdb) frame
#0  bar::quux::quux00<closure> (x=...) at src/quux.rs:2
2               where F: Fn() -> i32 {
(gdb) p x
$3 = {__0 = 0x24fc8c}
```

Теперь мы внутри метода `quux00` и остановились перед первой инструкцией,
посмотрев содержимое аргумента `x`, в которой хранится адрес нашей анонимной
функции. Далее мы войдём в эту анонимную функцию и посмотрим её работу:

```
(gdb) n
DEBUG 123
5           x()
(gdb) s
fnfn () at src/main.rs:7
7                   7 + y
(gdb) p y
$4 = 2
(gdb) n
8               };
(gdb) n
bar::quux::quux00<closure> (x=...) at src/quux.rs:6
6       }
(gdb) n
bar::main () at src/main.rs:10
10              println!("retval: {:?}", retval);
```

Превосходно! Мы пошагово посмотрели как работает анонимная функция и снова
вернулись в функцию `main`. Кстати, обратите внимание, что компилятор дал
анонимной функции имя `fnfn`. Запомним это имя, так как оно нам ещё пригодиться
в дальнейшем.

А теперь дойдём до последней строки:

```
(gdb) list
5           {
6               let x = || {
7                   7 + y
8               };
9               let retval = quux::quux00(x);
10              println!("retval: {:?}", retval);
11          }
12          y = 5;
13          println!("y     : {:?}", y);
14      }
(gdb) p retval
$5 = 9
(gdb) n
2       <std macros>: No such file or directory.
(gdb) p y
$6 = 2
(gdb) c
Continuing.
retval: 9
y     : 5
[Thread 8728.0x1a94 exited with code 0]
[Thread 8728.0x23b8 exited with code 0]
[Thread 8728.0x494 exited with code 0]
[Inferior 1 (process 8728) exited normally]
```

В сообщениях выше нам попалось сообщение
`<std macros>: No such file or directory`, на которое не стоит обращать
внимание. Разработчики уже в курсе проблемы:
[rust-lang/rust#17234](https://github.com/rust-lang/rust/issues/17234).

# Устанавливаем точки останова на все методы в main.rs

Давайте теперь поставим точки останова на все функции в файле `main.rs`:

```
$ gdb target/debug/bar
(gdb) rbreak main.rs:.
Breakpoint 1 at 0x40154c: file src/main.rs, line 4.
static void bar::main(void);
Breakpoint 2 at 0x40170c: file src/main.rs, line 7.
static i32 fnfn(void);
```

Хех, снова видим имя `fnfn`, которым названа наша анонимная функция. Таким
методом можно поставить точки останова на анонимные функции. Если мы начнём
процесс отладки, то остановимся лишь вначале функции `main` и вначале нашей
анонимной функции, которая вызывается из метода `quux00`:

```
(gdb) r
Starting program: D:\Code\Rust\debug\target\debug\bar.exe
[New Thread 2400.0x17a8]
[New Thread 2400.0x2154]
[New Thread 2400.0x3480]
[New Thread 2400.0x3ac]

Thread 1 hit Breakpoint 1, bar::main () at src/main.rs:4
4           let mut y = 2;
(gdb) c
Continuing.
DEBUG 123

Thread 1 hit Breakpoint 2, fnfn () at src/main.rs:7
7                   7 + y
(gdb) p y
$1 = 2
```

# Запрещаем компилятору изменять имена функций

Старые версии компилятора Rust изменяли в исполняемых файлах имена функций. В
данный момент (версия 1.7) такое не наблюдается, но можно явно указать
компилятору, чтобы он не изменял имена следующим образом:

```rust
#[no_mangle]
pub fn quux00<F>(x: F) -> i32
    where F: Fn() -> i32 {

    println!("DEBUG 123");
    x()
}
```
