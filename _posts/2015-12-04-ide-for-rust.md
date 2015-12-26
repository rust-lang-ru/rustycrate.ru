---
title: "IDE для Rust"
categories: руководства
published: true
author: Олег В.
excerpt: >
    На сегодня не существует общепризнанного лидера в IDE для Rust.<br/>

    Мнения расходятся, и это затрудняет быстрый старт для тех, кто начинает
    знакомиться с Rust.<br/>

    Это руководство для тех, кто хочет быстро начать работу с Rust в IDE
    с подсветкой, автодополнением и прочими печеньями.
---

_Это вики-статья. Примем Pull Request с описанием настройки других
редакторов и IDE._

На сегодня не существует общепризнанного лидера в IDE для Rust. Мнения
расходятся, и это затрудняет быстрый старт для тех, кто начинает
знакомиться с Rust.

Это руководство для тех, кто хочет быстро начать работу с Rust в IDE с
подсветкой, автодополнением и прочими печеньями.

Ниже приведены способы настройки различных редакторов. Вам потребуется
меньше 10 минут!

# Sublime Text 3

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
4. Profit!

![Sublime 3 with Rust](/images/2015-12-04-ide-for-rust/sublime-3-rust.png)

# Visual Studio Code
_Проверено для Linux (ArchLinux) и для Mac OS X (El Capitan 10.11.2)_

0. Устанавливаем Rust и Cargo
  * [официальный сайт](https://www.rust-lang.org/)
1. Скачиваем исходный код Rust'a (необходим для racer'a)
  * Создаем директорию _.rust_ в домашней директории: _mkdir ~/.rust_
  * Заходим в созданную директорию: _cd ~/.rust_
  * Выполняем: _git_ _clone_ _https://github.com/rust-lang/rust.git_
2. Устанавливаем racer ([инструкция на github'e](https://github.com/phildawes/racer))
  * Выполняем: _git_ _clone_ _https://github.com/phildawes/racer.git_
  * Заходим в созданную директорию: _cd ./racer_
  * Собираем cargo: _cargo build --release_
  * Копируем исполняемый файл _.racer_ в _/usr/bin/_: _cp ./target/release/racer /usr/bin/_
3. Добавляем переменную окружения _RUST\_SRC\_PATH_
  * Н-р, для Linux выполняем: _export RUST\_SRC\_PATH=~/.rust/src_
  * Для Mac'a: добавляем строчку _export RUST\_SRC\_PATH=~/.rust/src_ в файл _.bash\_profile_
4. Устанавливаем [Visual Studio Code](https://code.visualstudio.com)
  * Для ArchLinux: _yaourt -Sy visual-studio-code_
5. Устанавливаем расширение rusty для Visual Studio Code
  * В редакторе нажимаем _Shift+Ctrl+P_ для Linux (для Mac'a - _Shift+Cmd+P_)
  * Набираем Install Extension
  * Затем: _ext install rusty_ (_ext install_ уже будет отображаться, осталось только набрать "rusty")
6. Настройка проекта в Visual Studio Code
  * Открываем директорию какого-либо проекта, созданного с помощью Cargo
  * В редакторе нажимаем _Shift+Ctrl+P_
  * Набираем Configure Task Runner
  * Закомментируем всё и вставляем следующее: [task.json](https://gist.github.com/kulinich/19ca430cffbad5caa551)
7. Назначаем сочетание клавиш для компиляции и запуска
  * В редакторе нажимаем _Shift+Ctrl+P_
  * Набираем Open Keyboard Shortcuts
  * Назначаем следующее сочетание:
  ```json
  {"key": "shift+cmd+b",           "command": "workbench.action.tasks.runTask"}
  ```
8. Всё готово
  * По _Shift+Ctrl+B_ можно собирать и запускать проект
  * По _F12_ - Go to Definition
  * При наведении на символ с зажатой клавишей Ctrl (Cmd) определение появится в удобном окне (см. на изображении ниже)

![Visual Studio Code with Rust](/images/2015-12-04-ide-for-rust/visual_studio_code_rust.png)

# Ссылки
* [Прекрасная табличка со статусом поддержки возможностей для всех IDE (или почти всех), которые умеют работать с Rust](http://areweideyet.com/)
