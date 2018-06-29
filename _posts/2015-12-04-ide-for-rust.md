---
title: "IDE для Rust"
categories: руководства
tags: [ эксклюзивы ]
published: true
author: Олег В. и Norman Ritchie
---

_Это вики-статья. Последнее обновление: 16 ноября 2017._

Это руководство для тех, кто хочет быстро начать работу с Rust в IDE с
подсветкой синтаксиса, автодополнением и прочими возможностями.

<!--cut-->

# Содержание

* TOC
{:toc}

## Установка Rust

Официальный способ установки --- `rustup`:
```
$ curl https://sh.rustup.rs -sSf | sh
```

С настройками по умолчанию эта команда:
  * установит `rustup`, стабильную 
  версию компилятора `rustc` и менеджер пакетов `cargo`;
  * пропишет их в окружение.

Вам нужно будет перезайти в своего пользователя, чтобы изменения 
окружения вступили в силу.

Проверьте версию языка Rust и cargo:
```
$ rustc -V && cargo -V
rustc 1.21.0 (3b72af97e 2017-10-09)
cargo 0.22.0 (3423351a5 2017-10-06)
```

[Подробнее об установке](https://www.rust-lang.org/ru-RU/other-installers.html).

## Visual Studio Code

### Установка Visual Studio Code

Зайдите на [сайт редактора](https://code.visualstudio.com/) и скачайте 
установочный пакет для вашей платформы. Установите его.

### Установка расширения для Visual Studio Code

1. Нажмите `Ctrl+P` и вставьте эту команду:
   ```
   ext install rust-lang.rust
   ```
   
   Она устанавливает это [расширение](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust).
2. Откройте директорию проекта на Rust (`Файл -> Открыть папку`). 
   Выберите директорию, в которой находится `Cargo.toml`.

3. Откройте файл с исходным кодом на Rust (например, `src/main.rs`).
   Расширение запустится и предложит установить ночную версию компилятора, а 
   затем Rust Language Server.
   
   После завершения установки всё готово к работе!

[Подробнее о возможностях расширения](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust).

#### Поддержка TOML

Используйте [расширение](https://marketplace.visualstudio.com/items?itemName=bungcip.better-toml).

### Результат настройки

{% img '2015-12-04-ide-for-rust/visual_studio_code_rust.png' alt:'Visual Studio Code with Rust' %}

Далее приведены шаги настройки других редакторов.

## Другие редакторы

### Ночная версия компилятора

```text
$ rustup install nightly
$ rustup default nightly
```

[Подробнее об установке ночной версии](https://github.com/rust-lang-nursery/rustup.rs#working-with-nightly-rust).

### Установка дополнительных компонентов

0. [Racer](https://github.com/racer-rust/racer) --- автодополнение кода для Rust
   ```bash
   cargo install racer
   ```
1. [RLS](https://github.com/rust-lang-nursery/rls) --- Rust Language Server 
   (сервер поддержки IDE)
   ```bash
   rustup component add rls-preview --toolchain nightly
   rustup component add rust-analysis --toolchain nightly
   rustup component add rust-src --toolchain nightly
   ```
2. [Rustfmt](https://github.com/rust-lang-nursery/rustfmt) --- форматирование кода
   ```bash
   cargo install rustfmt-nightly
   ```
3. [Clippy](https://github.com/rust-lang-nursery/rust-clippy) --- линтер
   ```bash
   cargo install clippy
   ```

Дальнейшие шаги зависят от конкретного редактора.

### Настройка редактора

{% spoiler IntelliJ IDEA %}

0. Устанавливаем [расширение](https://intellij-rust.github.io/)

{% img '2015-12-04-ide-for-rust/intellij-rust.png' alt:'Intellij-Rust' %} 

{% endspoiler %}

{% spoiler Sublime Text 3 %}

0. Устанавливаем расширение [Rust Enhanced](https://packagecontrol.io/packages/Rust%20Enhanced)
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
3. Дополнительные расширения:
  * [RustFmt](https://packagecontrol.io/packages/RustFmt)
  * [TOML](https://packagecontrol.io/packages/TOML)

{% img '2015-12-04-ide-for-rust/sublime-3-rust.png' alt:'Sublime 3 with Rust' %}
{% endspoiler %}

{% spoiler Emacs %}

1. Устанавливаем расширение [Rust-mode](https://github.com/rust-lang/rust-mode)
2. Дополнительные расширения:
   * [cargo.el](https://github.com/kwrooijen/cargo.el)
   * [lsp-mode](https://github.com/emacs-lsp/lsp-rust)
   * [flycheck](http://www.flycheck.org/en/latest/user/installation.html)
   * [flycheck-rust](http://www.flycheck.org/en/latest/community/extensions.html#rust)

{% img '2015-12-04-ide-for-rust/emacs_rust.png' alt:'Emacs with Rust' %}

{% endspoiler %}

{% spoiler Vim %}

1. Устанавливаем расширение [Rust.vim](https://github.com/rust-lang/rust.vim), 
используя Vundle:
   ```text
   Plugin 'rust-lang/rust.vim'
   :PluginInstall
   ```

2. Настраиваем форматирование кода `:RustFmt` с помощью `rustfmt`:
   ```text
   let g:rustfmt_autosave = 1
   ```

{% img '2015-12-04-ide-for-rust/vim_rust.gif' alt:'Vim with Rust' %}

{% endspoiler %}

# Ссылки
* [Прекрасная табличка со статусом поддержки возможностей для всех IDE (или почти всех), которые умеют работать с Rust](http://areweideyet.com/)
