---
title: >
  Как настроить сборку и тестирование для Open Source проекта на Rust под Windows
  с помощью AppVeyor
author: Михаил Панков
categories: обучение
---

{% img '2017-08-20-rust-appveyor/teaser.png' alt:'teaser' width:50% %}

Как зарегистрироваться на AppVeyor, подключить туда свой проект на Rust и
сделать первую сборку.

Это цикл статей:
* [Как настроить сборку и тестирование для Open Source проекта на Rust под Linux
  с помощью Travis](/%D0%BE%D0%B1%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5/2017/07/30/rust-travis.html)
* Как настроить сборку и тестирование для Open Source проекта на Rust под Windows
  с помощью AppVeyor (эта статья)

<!--cut-->

# Содержание

* TOC
{:toc}

# Требования

* Исходники проекта запушены на GitHub

# Настройка простейшего проекта

В качестве примера здесь фигурирует репозиторий простейшей
библиотеки [hello](https://github.com/mkpankov/hello), состоящей из одной
функции и одного теста.

## Регистрируемся на AppVeyor

Заходим на [AppVeyor](https://www.appveyor.com/). Нажимаем `Sign Up For Free`.

Открывается окно регистрации. Выбираем бесплатный тариф для проектов с открытыми
исходниками: в поле `1 - Plan` выбираем `Free for open-source projects`. Если не
хотите получать от AppVeyor новости на почту, снимите галочку `2 - Subscribe to
company news and platform updates`. Затем нажмите на кнопку `GitHub`, чтобы
войти на AppVeyor.

При желании можно зарегистрироваться по email, заполнив три поля справа.

{% img '2017-08-20-rust-appveyor/sign-up.png' alt:'регистрация' %}

После нажатия на кнопку `GitHub` откроется окно авторизации AppVeyor. Нажимаем
`Authorize AppVeyor`.

{% img '2017-08-20-rust-appveyor/github-auth.png' alt:'авторизация на GitHub' %}

После этого GitHub может запросить пароль, чтобы подтвердить предоставление
доступа AppVeyor.

{% img '2017-08-20-rust-appveyor/github-pass.png' alt:'ввод пароля от GitHub' %}

После этого вы должны увидеть панель управления AppVeyor.

{% img '2017-08-20-rust-appveyor/dashboard.png' alt:'ввод пароля от GitHub' %}

Если что-то пошло не так:

1. Отключите блокировку кук и скриптов в браузере.
2. Удалите куки.
3. Отзовите у AppVeyor доступ к GitHub
   на [странице настроек](https://github.com/settings/applications) (кнопка
   Revoke).
4. Попробуйте ещё раз.

## Добавляем проект

Нажимаем `New project`.

{% img '2017-08-20-rust-appveyor/dashboard.png' alt:'панель управления' %}

В окне добавления проекта слева (`1`) выбираем расположение репозитория - в
нашем случае `GitHub`. Если вы хотите подключить частный проект, выберите
`Private and public repositories` справа (`2`). Затем нажмите `Authorize GitHub`
(`3`).

{% img '2017-08-20-rust-appveyor/add-project.png' alt:'добавление проекта' %}

После авторизации GitHub на доступ к репозиториям ищем справа наш проект и
нажимаем кнопку `Add`.

{% img '2017-08-20-rust-appveyor/project-list.png' alt:'список проектов' %}

Теперь нужно настроить добавленный проект.

## Добавляем appveyor.yml

AppVeyor не поддерживает Rust из коробки, поэтому нам придётся установить его
самим.

Создаём в корне добавленного репозитория файл `appveyor.yml`.

``` yaml
# Выбираем контейнер с необходимыми Rust компонентами
os: Visual Studio 2015

# Устанавливаем Rust
install:
  # Скачиваем rustup
  - appveyor DownloadFile https://win.rustup.rs/ -FileName rustup-init.exe
  # Устанавливаем стабильный Rust с MSVC ABI
  # Если хотите другую версию - замените stable на версию
  # Если хотите GNU ABI - замените x86_64-pc-windows-msvc на x86_64-pc-windows-gnu
  - rustup-init -yv --default-toolchain stable --default-host x86_64-pc-windows-msvc
  # Устанавливаем пути до компонентов Rust
  - set PATH=%PATH%;%USERPROFILE%\.cargo\bin
  # Выводим версии
  - rustc -vV
  - cargo -vV

# Выключаем стандартный сборщик AppVeyor
build: false

# Используем специальный тестовый скрипт
test_script:
  # Собираем
  - cargo build --verbose
  # Запускаем тесты
  - cargo test --verbose
```

Коммитим его:

```shell
$ git add appveyor.yml
$ git commit -m "Добавляем AppVeyor"
```

## Пушим на GitHub

AppVeyor запускает сборки по пушу в репозиторий. Когда мы запушим наш коммит с
`appveyor.yml`, начнётся первая сборка. Сделаем это:

```shell
$ git push
```

и идём в панель управления AppVeyor. Находим там слева наш проект, кликаем по
нему.

Обычно нужно немного подождать, прежде чем начнётся сборка - в пределах
минуты.

Когда сборка запустится, вы увидите логи внизу:

{% img '2017-08-20-rust-appveyor/build.png' alt:'сборка' %}

AppVeyor собирает проект и запускает его тесты, аналогично тому, как это
делается на локальной машине.

Весь процесс занимает примерно 2 минуты для простейшего проекта.

Вот как выглядит
страница
[сборки](https://ci.appveyor.com/project/mkpankov/hello/build/1.0.2/job/61duw470evparlqj) для
моей библиотеки hello.

Если навести курсор на строку лога, во всплывающей подсказке будет показано, в
какое время от начала сборки была выполнена эта команда.

Чтобы получить полный лог в виде текстового файла, кликните по `Log` справа
вверху, над логом.

## Настраиваем уведомления по почте

Чтобы AppVeyor отправлял статус сборки по почте, настроим это в `appveyor.yml`.

``` yaml
notifications:
  - provider: Email
    # Список адресов
    to:
      - user1@host.com
      - user2@host.com
    # Отправлять ли письмо в случае успеха?
    on_build_success: false
    # Отправлять ли письмо в случае провала?
    on_build_failure: true
    # Отправлять ли письмо когда статус изменился?
    on_build_status_changed: true
```

## Настраиваем кэширование

Есть смысл кэшировать директорию с реестром cargo и директорию сборки проекта.

`appveyor.yml`

``` yaml
cache:
  - '%USERPROFILE%\.cargo'
  - target
```

## Добавляем индикатор статуса сборки

Формат URL для получения индикатора такой:

``` yaml
https://ci.appveyor.com/api/projects/status/{github|bitbucket}/{repository}
```

Для hello URL будет такой:

``` yaml
https://ci.appveyor.com/api/projects/status/github/mkpankov/hello
```

Добавляем его в качестве картинки в `README.md`.

``` markdown
[![Build Status](https://ci.appveyor.com/api/projects/status/github/mkpankov/hello)](https://ci.appveyor.com/api/projects/status/github/mkpankov/hello)
```

Результат:

{% img '2017-08-20-rust-appveyor/badge.png' alt:'индикатор' %}

## Готово!

Мы настроили сборку и тестирование проекта на Rust на AppVeyor. Он будет
тестироваться на каждый пуш в репозиторий.

# Продвинутые возможности

## Выбор версии Rust

Измените спецификатор версии в вызове `rustup-init`:

`appveyor.yml`

``` yaml
  - rustup-init -yv --default-toolchain nightly-2017-05-09 --default-host x86_64-pc-windows-msvc
```

## Тестирование с несколькими версиями

Можно добавить матричную конфигурацию. При этом можно разрешить провалы сборок
на nightly-версиях компилятора.

`appveyor.yml`

``` yaml
...

environment:
  matrix:
    - channel: stable
      target: x86_64-pc-windows-msvc
    - channel: stable
      target: x86_64-pc-windows-gnu
    - channel: nightly
      target: x86_64-pc-windows-msvc
    - channel: nightly
      target: x86_64-pc-windows-gnu

matrix:
  allow_failures:
    - channel: nightly

install:
  - appveyor DownloadFile https://win.rustup.rs/ -FileName rustup-init.exe
  - rustup-init -yv --default-toolchain %channel% --default-host %target%
  - set PATH=%PATH%;%USERPROFILE%\.cargo\bin
  - rustc -vV
  - cargo -vV

...
```


<hr/>

На этом всё. Успешных сборок!

<hr/>

Другие статьи цикла:
* [Как настроить сборку и тестирование для Open Source проекта на Rust под Linux
  с помощью Travis](/%D0%BE%D0%B1%D1%83%D1%87%D0%B5%D0%BD%D0%B8%D0%B5/2017/07/30/rust-travis.html)
* Как настроить сборку и тестирование для Open Source проекта на Rust под Windows
  с помощью AppVeyor (эта статья)

Задавайте вопросы
[на форуме](https://forum.rustycrate.ru/t/obsuzhdenie-stati-kak-nastroit-sborku-i-testirovanie-dlya-open-source-proekta-na-rust-pod-windows-s-pomoshhyu-appveyor/248).
