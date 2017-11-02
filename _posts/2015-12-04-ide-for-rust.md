---
title: "IDE для Rust"
categories: руководства
published: true
author: Олег В. и Norman Ritchie
---

_Это вики-статья. Последнее обновление: 15 октября 2017._

На сегодня не существует общепризнанного лидера в IDE для Rust. Мнения
расходятся, и это затрудняет быстрый старт для тех, кто начинает
знакомиться с Rust.

Это руководство для тех, кто хочет быстро начать работу с Rust в IDE с
подсветкой синтаксиса, автодополнением и т.д.

Перед тем как приступить к настройке редакторов, необходимо установить сам язык программирования Rust и необходимые утилиты для работы с ним:

{% spoiler Установка Rust и Rust nightly %}

0. Rust
  * Откройте эмулятор терминала и вставьте данную команду для установки компилятора 
  и менеджера пакетов [cargo][carg].
  [carg]: https://rurust.github.io/cargo-docs-ru/
  * Следуйте инструкциям (при необходимости, установите утилиту `curl` с помощью пакетного менеджера вашего дистрибутива):
  ```bash
  $ curl https://sh.rustup.rs -sSf | sh
  ```
  * После успешной установки, настройте переменные окружения для `cargo`.
  * В зависимости от вашей оболочки (bash, zsh, etc), отредактируйте файл `.bash_profile` и вставьте:
  ```bash
  $ export PATH="$HOME/.cargo/bin:$PATH"
  ```
  * Проверьте версию языка Rust и cargo:
  ```bash
  $ rustc -V && cargo -V

  rustc 1.21.0 (3b72af97e 2017-10-09)
  cargo 0.22.0 (3423351a5 2017-10-06)
  ```
  * Более подробная информации по установке для вашей OS находиться [здесь][install].
  [install]: https://www.rust-lang.org/ru-RU/other-installers.html
  * Далее необходимо установить ночную версию Rust, т.к. большинству пакетов необходима ночная сборка компилятора.

1. Rust nightly
  * Установка ночной версии позволит пользоваться экспериментальными функциями, а главное использовать необходимые пакеты для редакторов и не только:
  ```bash
  $ rustup install nightly

  info: syncing channel updates for 'nightly'
  info: downloading toolchain manifest
  info: downloading component 'rustc'
  info: downloading component 'rust-std'
  info: downloading component 'rust-docs'
  info: downloading component 'cargo'
  info: installing component 'rustc'
  info: installing component 'rust-std'
  info: installing component 'rust-docs'
  info: installing component 'cargo'

  nightly installed: rustc 1.22.0-nightly (7778906be 2017-10-14)
  ```
  * Теперь Rust Nightly установлен, но не активирован. Чтобы активировать и сменить версию на ночную по умолчанию, используйте команду ниже:
  ```bash
  $ rustup default nightly

  info: using existing install for 'nightly-x86_64-unknown-linux-gnu'
  info: default toolchain set to 'nightly-x86_64-unknown-linux-gnu'

  nightly-x86_64-unknown-linux-gnu unchanged - rustc 1.22.0-nightly (7778906be 2017-10-14)
  ``` 
  * Более подробная информации по установке находиться [здесь][rustup].
  [rustup]: https://github.com/rust-lang-nursery/rustup.rs

{% endspoiler %}

Инструкция по установке необходимых пакетов, используя менеджер пакетов cargo.
**Внимание**: Под спойлером приведен список наиболее популярных пакетов.
Устанавливайте только те, которые необходимые вам или вашему редактору.

{% spoiler Установка необходимых пакетов с помощью cargo %}

0. [Racer](https://github.com/racer-rust/racer) — автодополнение кода для Rust
```bash
cargo install racer
```
1. [RLS](https://github.com/rust-lang-nursery/rls) — Rust Language Server
```bash
rustup component add rls-preview --toolchain nightly
rustup component add rust-analysis --toolchain nightly
rustup component add rust-src --toolchain nightly
```
2. [Rustfmt](https://github.com/rust-lang-nursery/rustfmt) — форматирование кода
```bash
cargo install rustfmt-nightly
```
3. [Clippy](https://github.com/rust-lang-nursery/rust-clippy) — коллекция линтов, для нахождения ошибок и улучшения кода
```bash
cargo install clippy
```

{% endspoiler %}


Ниже приведены способы настройки различных редакторов.

{% spoiler Sublime Text 3 %}

0. Плагин для поддержки Rust в Sublime
  * [Rust Enhanced](https://packagecontrol.io/packages/Rust%20Enhanced)
1. Build With
  * Отключаем стандартный пакет Rust и выбираем синтаксис: ```Rust Enhanced```
  * Собрать программу: _CTRL+SHIFT+P_ -> ```Build With: RustEnhanced```
  * Собрать и запустить: _CTRL+SHIFT+P_ -> ```Build With: RustEnhanced - Run```
2. Настройка Rust Enhanced:
  * Clippy для проверки синтаксиса
```bash
{
  "rust_syntax_checking": true,
  "rust_syntax_checking_method": "clippy",
}
```
3. Дополнительные плагины:
  * [RustFmt](https://packagecontrol.io/packages/RustFmt)
  * [TOML](https://packagecontrol.io/packages/TOML)

{% img '2015-12-04-ide-for-rust/sublime-3-rust.png' alt:'Sublime 3 with Rust' %}
{% endspoiler %}

{% spoiler IntelliJ IDEA %}

0. Плагин Rust для [IntelliJ IDEA](https://intellij-rust.github.io/)

{% img '2015-12-04-ide-for-rust/intellij-rust.png' alt: 'Intellij-Rust' %} 

{% endspoiler %}

{% spoiler Visual Studio Code %}

0. Плагин для поддержки Rust в VSCode
  * [Rust for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust)
1. Сбор и запуск
  * Собрать программу: _CTRL+SHIFT+P_ -> Cargo Build
  * Собрать и запустить: _CTRL+SHIFT+P_ -> Cargo Run
2. Дополнительные плагины:
  * [TOML](https://marketplace.visualstudio.com/items?itemName=bungcip.better-toml)

{% img '2015-12-04-ide-for-rust/visual_studio_code_rust.png' alt:'Visual Studio Code with Rust' %}

{% endspoiler %}

<!--cut-->

{% spoiler Emacs %}

1. Emacs для редактирования кода на Rust
  * [Rust-mode](https://github.com/rust-lang/rust-mode)

{% img '2015-12-04-ide-for-rust/emacs_rust.png' alt:'Emacs with Rust' %}

{% endspoiler %}

{% spoiler Vim %}

Конфигурация Vim для языка Rust.

1. Плагин Vim, который обеспечивает обнаружение файлов Rust, подсветку синтаксиса, форматирование, интеграцию [Syntastic](https://github.com/vim-syntastic/syntastic) и другое.
  * [Rust.vim](https://github.com/rust-lang/rust.vim)
  * Установка, используя Vundle:
```bash
Plugin 'rust-lang/rust.vim'
:PluginInstall
```
  * Форматирование кода `:RustFmt` с помощью `rustfmt`:
```bash
let g:rustfmt_autosave = 1
```

{% img '2015-12-04-ide-for-rust/vim_rust.gif' alt:'Vim with Rust' %}

{% endspoiler %}

# Ссылки
* [Прекрасная табличка со статусом поддержки возможностей для всех IDE (или почти всех), которые умеют работать с Rust](http://areweideyet.com/)
