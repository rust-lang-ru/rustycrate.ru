---
title: "Большие бинари в моем Rust? (Why is a Rust executable large?)"
author: lifthrasiir (адаптация от kitsu)
categories: обучение
---

Это статья - перевод статьи [Why is a Rust executable large?](https://lifthrasiir.github.io/rustlog/why-is-a-rust-executable-large.html)

# Большие бинари в моем Rust?

Бороздя просторы интернета вы наверняка уже успели услышать про Rust. После всех красноречивых отзывов и расхваливаний вы, конечно же, не смогли не потрогать это чудо. Первая программа выглядела не иначе как:

```rust
fn main() {
    println!("Hello, world!");
}
```

Скомпилировав получим соответствующий исполняемый файл:

```sh
$ rustc hello.rs
$ du -h hello
632K hello
```

632 килобайт для простого принта?! Rust позиционируется как системный язык, который имеет потенциал для замены C/C++, верно? Так почему бы не проверить аналогичную программу на ближайшем конкуренте?

<cut/>

```bash
$ cat hello.c
#include <stdio.h>
int main() {
    printf("Hello, World!\n");
}
$ gcc hello.c -ohello
$ du -h hello
6.7K hello
```

Более безопасные и громоздкие iostream-ы C++ выдают не сильно иной результат:

```bash
$ cat hello.cpp
#include <iostream>
int main() {
    std::cout << "Hello, World!" << std::endl;
}
$ g++ hello.cpp -ohello
$ du -h hello
8.3K hello
```

> Флаги -O3/-Os практически не меняют конечного размера

# Так что не так с Rust?

Кажется, что необычный размер исполняемых файлов Rust интересует много кого, и вопрос этот совершенно не нов. Взять, к примеру, [этот](https://stackoverflow.com/questions/29008127/why-are-rust-executables-so-huge) вопрос на stackoverflow, или множество [других](https://is.gd/m3YfDN). Даже немного странно, что все еще не было статей или каких-либо заметок описывающих эту проблему.

> Все примеры были перетестированы на Rust 1.11.0-nightly (1ab87b65a 2016-07-02) на Linux 4.4.14 x86_64 без использования cargo и stable-ветки в отличии от оригинальной статьи.

# Уровень оптимизации

Любой опытный программист конечно же воскликнет, что дебаг билд на то и дебаг, и нередко его размер значительно превышает релиз-версию. Rust в данном случае не исключение и [достаточно гибко](http://doc.crates.io/manifest.html#the-profile-sections) позволяет настраивать параметры сборки. Уровни оптимизации аналогичны gcc, задать его можно с помощью параметра `-C opt-level=x`, где вместо x число от _0_-_3_, либо _s_ для минимизации размера. Ну что же, посмотрим что из этого выйдет:

```bash
$ rustc helloworld.rs -C opt-level=s
$ du -h helloworld                 
630K helloworld
``` 

Что удивительно, каких-либо значительных изменений нет. На самом деле это происходит из-за того, что оптимизация применяется лишь к пользовательскому коду, а не к уже скомпонованной среде исполнения Rust.

# Оптимизация линковки (LTO)

Rust по стандартному поведению к каждому исполняемому файлу линкует всю свою стандартную библиотеку. Так что мы можем избавиться и от этого, ведь глупый линковщик не понимает, что нам не очень нужно взаимодействие с сетью.

На самом деле есть хорошая причина для такого поведения. Как вы наверное знаете языки C и C++ компилируют каждый файл по отдельности. Rust же поступает немного иначе, где единицей компиляции выступает [крейт](http://doc.crates.io/index.html)(crate). Не трудно догадаться, что вызов функций из других файлов компилятор не сможет оптимизировать, так как он попросту работает с одним большим файлом.

Изначально в C/C++ компилятор производил оптимизацию независимо каждого файла. Со временем появилась технология оптимизации при линковке. Хоть это и стало занимать значительно больше времени, зато в результате получались исполняемые файлы куда лучше, чем раньше. Посмотрим как изменит положение дел эта функциональность в Rust:

```bash
$ rustc helloworld.rs -C opt-level=s -C lto
$ du -h helloworld
604K helloworld
```

# Так что же внутри?

Первое, чем наверное стоит воспользоваться - это небезызвестная утилита `strings` из набора [GNU Binutils](https://www.gnu.org/software/binutils/). Вывод ее достаточно большой (порядка 6 тыс. строк), так что приводить его полностью не имеет смысла. Вот самое интересное:

```bash
$ strings helloworld
capacity overflow
attempted to calculate the remainder with a divisor of zero
<jemalloc>: Error in atexit()
<jemalloc>: Error in pthread_atfork()
DW_AT_member
DW_AT_explicit
_ZN4core3fmt5Write9write_fmt17ha0cd161a5f40c4adE # или core::fmt::Write::write_fmt::ha0cd161a5f40c4ad
_ZN4core6result13unwrap_failed17h072f7cd97aa67a9cE # или core::result::unwrap_failed::h072f7cd97aa67a9c
```

На основе этого результата можно сделать несколько выводов: 
- К исполняемым файлам Rust статически линкуется вся стандартная библиотека.
- Rust использует [jemalloc](http://www.canonware.com/jemalloc/) вместо системного аллокатора.
- К файлам также статически линкуется библиотека libbacktrace, которая нужна для трассировки стека.

Все это, как вы понимаете, для обычного `println` не очень то и нужно. Значит самое время от них всех избавиться!

# Отладочные символы и libbacktrace

Начнем с простого - убрать из исполняемого файла отладочные символы. 

```bash
$ strip hello
# du -h hello
356K helloworld
```

Очень неплохой результат, почти половину исходного размера занимают отладочные символы. Хотя в этом случае удобочитаемого вывода при ошибках, вроде `panic!` нам не получить:

```bash
$ cat helloworld.rs 
fn main() {
    panic!("Hello, world!");
}
$ rustc helloworld.rs && RUST_BACKTRACE=1 ./helloworld 
thread 'main' panicked at 'Hello, world!', helloworld.rs:2
stack backtrace:
   1:     0x556536e40e7f - std::sys::backtrace::tracing::imp::write::h6528da8103c51ab9
   2:     0x556536e4327b - std::panicking::default_hook::_$u7b$$u7b$closure$u7d$$u7d$::hbe741a5cc3c49508
   3:     0x556536e42eff - std::panicking::default_hook::he0146e6a74621cb4
   4:     0x556536e3d73e - std::panicking::rust_panic_with_hook::h983af77c1a2e581b
   5:     0x556536e3c433 - std::panicking::begin_panic::h0bf39f6d43ab9349
   6:     0x556536e3c3a9 - helloworld::main::h6d97ffaba163087d
   7:     0x556536e42b38 - std::panicking::try::call::h852b0d5f2eec25e4
   8:     0x556536e4aadb - __rust_try
   9:     0x556536e4aa7e - __rust_maybe_catch_panic
  10:     0x556536e425de - std::rt::lang_start::hfe4efe1fc39e4a30
  11:     0x556536e3c599 - main
  12:     0x7f490342b740 - __libc_start_main
  13:     0x556536e3c268 - _start
  14:                0x0 - <unknown>
$ strip helloworld && RUST_BACKTRACE=1 ./helloworld
thread 'main' panicked at 'Hello, world!', helloworld.rs:2
stack backtrace:
   1:     0x55ae4686ae7f - <unknown>
...
  11:     0x55ae46866599 - <unknown>
  12:     0x7f70a7cd9740 - __libc_start_main
  13:     0x55ae46866268 - <unknown>
  14:                0x0 - <unknown>
```

Вытащить целиком _libbacktrace_ из линковки без последствий не получится, он сильно связан со стандартной библиотекой. Но зато размотка для паники из libunwind нам не нужна, и мы можем ее выкинуть. Незначительные улучшения мы все-таки получим:

```bash
$ rustc helloworld.rs -C lto -C panic=abort -C opt-level=s
$ du -h helloworld
592K helloworld
```

# Убираем jemalloc

Компилятор Rust стандартной сборки чаще всего [использует](http://rurust.github.io/rust_book_ru/src/custom-allocators.html) jemalloc вместо системного аллокатора. Изменить это поведение очень просто: нужно всего лишь вставить макро и импортировать нужный крейт аллокатора.

```
$ cat helloworld.rs 
#![feature(alloc_system)]
extern crate alloc_system;

fn main() {
    println!("Hello, world!");
}
$ rustc helloworld.rs && du -h helloworld
235K helloworld
$ strip helloworld && du -h helloworld 
133K helloworld
```

# Небольшой вывод

Завершающим штрихом в нашем шаманстве могло быть удаление из исполняемого файла всей стандартной библиотеки. В большинстве случаев это не нужно, да и к тому же в [офф.книге](https://doc.rust-lang.org/book/no-stdlib.html) (или в [переводе](http://rurust.github.io/rust_book_ru/src/no-stdlib.html)) все шаги подробно описаны. Этим способом можно получить файл размером, сопоставимым с аналогом на Си.

Стоит также отметить, что размер стандартного набора библиотек постоянен, и сами линковочные файлы (перечисленные в статье) не увеличиваются в зависимости от вашего кода, а значит вам скорее всего не придется беспокоится о размерах. На крайний случай вы всегда можете использовать упаковщики кода вроде upx
