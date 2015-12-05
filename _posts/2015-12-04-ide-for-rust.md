---
title: "IDE для Rust"
categories: руководства
published: true
author: Олег В.
excerpt:
    На сегодня не существует общепризнанного лидера в IDE для Rust.<br/>
    Мнения расходятся, и это затрудняет быстрый старт для тех, кто начинает знакомиться с Rust.<br/>
    Это how-to для тех, кто начать работу с Rust быстро и в IDE с подсветкой, автодополнением и прочими печеньями.

---

_Это вики-статья. Примем Pull Request с описанием настройки других редакторов и IDE._

На сегодня не существует общепризнанного лидера в IDE для Rust. Мнения расходятся, и это затрудняет быстрый старт для тех, кто начинает знакомиться с Rust.

# \[Sublime Text 3\] Начать работу быстро (< 10m) с подсветкой, автодополнением и т.п.

0. Rust
  * Ставим [Rust](https://www.rust-lang.org/)
  * Путь к _bin_ должен быть добавлен в переменную окружения PATH
1. Sublime Text 3
  * [Загружаем Sublime 3](http://www.sublimetext.com/3), именно 3 версии, т.к. некоторые пакеты поддержки Rust существуют только для нее
  * Ставим Package Control. [Simple intallation](https://packagecontrol.io/installation#st3) ясно и коротко описывает как это сделать
2. Плагины для поддержки Rust
  * Ставим все перечисленные [здесь](http://areweideyet.com/#sublime). Обратите внимание, _SublimeLinter_ необходимо установить перед _SublimeLinter-contrib-rustc_
  * Перезапускаем Sublime
3. Build and Run
  * В меню редактора _Tools -> Build System_ выбираем Rust
  * Создаем файл с расширением __*.rs__, тогда Sublime включит подсветку синтаксиса
  * Пишем код порабощения мира или можно взять [пример с главной страницы Rust](https://www.rust-lang.org/)
  * В меню редактора _Tools -> Build With..._ и выбираем _Rust_
  * В меню редактора _Tools -> Build With..._ и выбираем _Rust - Run_
  * Profit!

![Sublime 3 with Rust](/images/2015-12-04-ide-for-rust/sublime-3-rust.png)

# References
* [Прекрасная табличка со статусом поддержки возможностей для всех IDE (или почти всех), которые умеют работать с Rust](http://areweideyet.com/)